# B1-1 시스템 관제 자동화 스크립트 개발

- 미션 요구사항 체크리스트: [docs/CHECKLISTS.md](./docs/CHECKLISTS.md)
- 수집된 수행 증거(필수 증거 자료 B 섹션): [evidence/](./evidence/) — 각 파일에 사용한 명령어 함께 기록
- 자동화 스크립트: [scripts/monitor.sh](./scripts/monitor.sh), [scripts/entrypoint.sh](./scripts/entrypoint.sh), [scripts/collect-evidence.sh](./scripts/collect-evidence.sh)
- 실행: [start.sh](./start.sh)

---

- 실행 환경: macOS + Docker ubuntu:24.04
- 필요 패키지 목록
    - openssh-server (ssh)
    - ufw (ubuntu firewall)
    - cron (일정 주기마다 실행 자동화)
    - acl (파일 권한 부여. 특정 사용자에게 권한 줄 때 유용)
    - procps (CPU/mem/process 확인)
    - iproute2 (포트 listen 상태 확인)
    - sudo (혹시몰라서)
    - logrotate (로그 파일 회전용)

## 주요 이슈

> Missing privilege separation directory: /run/sshd
[
https://github.com/dev-sec/ansible-collection-hardening/issues/752](https://github.com/dev-sec/ansible-collection-hardening/issues/752)


> /run/sshd
> chroot(2) directory used by sshd during privilege separation in the pre-authentication phase. The 
> directory should not contain any files and must be owned by root and not group or world-writable.
> [text](http://manpages.ubuntu.com/manpages/noble/man8/sshd.8.html)

/run/sshd는 sshd가 사전 인증 단계의 privilege separation에서 사용하는 chroot 디렉터리이다.
이게 없으면 ssh서버 시작이 안된다.

> 시크릿 파일명 불일치

바이너리에서는 AGENT_KEY_PATH로 secret.key를 요구한다. 미션 문서와는 다르다. (미션 문서: t_secret.key)

>[3/5] Checking Required Files             [FAIL]
>   >>> Missing File: secret.key
>   >>>    (Expected location: /home/agent-admin/agent-app/api_keys/secret.key)


## 과제 목표 설명

### SSH 포트 변경과 Root 원격 차단이 기본 보안인 이유

22번은 공격자들이 가장 먼저 두드리는 포트이다. 자동 스캐너는 22/tcp에 brute-force 시도를 끊임없이 던진다. 포트를 20022로 옮기면 무차별 시도 트래픽 자체가 줄어든다 (security by obscurity, 단독 방어는 아니지만 1차 노이즈 차단).

Root는 모든 권한을 가진 계정이라 비밀번호 하나만 뚫리면 서버 전체가 넘어간다. `PermitRootLogin no`로 원격 root 로그인을 막으면, 공격자는 일반 계정 → sudo 라는 2단계를 거쳐야 권한 상승이 가능해진다. 일반 계정명까지 추측해야 하니 공격 비용이 올라간다.

검증: sshd config에 `Port 20022`, `PermitRootLogin no`가 적용됐는지 보고, `ss -tulnp`로 sshd가 20022에서 리슨하는지 확인한다.

### UFW "필요 포트만 허용" 정책 구성과 검증 방법

방화벽의 기본 원칙은 default deny이다. 모두 막고, 필요한 것만 명시적으로 연다 (whitelist 방식). 이렇게 하면 의도하지 않은 포트가 외부로 노출되는 일을 막을 수 있다.

이 미션에선 SSH(20022)와 앱(15034) 두 포트만 인바운드 허용한다.

```
ufw default deny incoming
ufw default allow outgoing
ufw allow 20022/tcp
ufw allow 15034/tcp
ufw --force enable
```

검증: `ufw status verbose`로 Default가 deny (incoming)인지, ALLOW IN 라인에 20022/15034만 떠있는지 확인한다.

### 역할 기반 계정/그룹/ACL로 "공유"와 "보안" 디렉토리를 분리하는 이유

서비스에는 역할이 다른 사람이 같이 들어온다. 운영자(admin), 개발자(dev), QA(test). 모두 같은 계정을 쓰면 누가 무엇을 했는지 추적이 불가능하고, 권한도 과도하게 부여된다 (최소 권한 원칙 위배).

그래서 계정은 역할별로 나누고, 권한은 그룹으로 묶어 부여한다.

| 디렉토리 | 그룹 | 정책 |
| --- | --- | --- |
| `upload_files` | `agent-common` (admin/dev/test) | 셋 다 R/W. 협업용 공유 디렉토리 |
| `api_keys`, `/var/log/agent-app` | `agent-core` (admin/dev) | 운영 권한이 있는 둘만 접근. test는 차단 |

`chmod 2770`(setgid + rwxrwx---)로 그룹 외부는 완전히 차단하고, 신규 파일이 자동으로 그룹을 상속하게 한다. ACL은 그룹 단위 권한을 디렉토리에 추가로 못박는 용도이다. mask와 default ACL이 같이 설정되면 새로 만들어지는 파일에도 같은 권한이 적용된다.

검증: `id agent-*`로 그룹 멤버십, `ls -ld`와 `getfacl`로 디렉토리 권한/ACL을 본다.

### 환경변수(AGENT_HOME 등)로 실행 환경을 고정하는 이유와 검증 방법

코드에 경로를 박아두면 (`/home/agent-admin/agent-app/...`) 환경이 바뀔 때마다 코드를 수정해야 한다. 환경변수로 빼두면 같은 바이너리/스크립트가 어디서든 동작한다.

또한 환경변수는 부팅 시 1회 검증으로 "실행 환경이 올바른가"를 단정할 수 있게 해준다. agent_app의 Boot Sequence 2/5단계가 정확히 그 역할이다 — 필요한 env가 다 있는지, 값이 올바른지 검사하고 틀리면 즉시 종료한다.

검증: `printenv`로 5개 변수(AGENT_HOME, AGENT_PORT, AGENT_UPLOAD_DIR, AGENT_KEY_PATH, AGENT_LOG_DIR)가 설정됐는지, 앱 부팅 로그의 `[2/5] Verifying Environment Variables [OK]`로 통과 여부를 확인한다.

### 앱 Boot Sequence 5단계와 "Agent READY" 출력

agent_app은 기동 직후 5단계의 자가 진단(Boot Sequence)을 돌리고, 5단계가 모두 `[OK]`여야만 `Agent READY`를 출력하고 포트 15034를 LISTEN한다. 한 단계라도 실패하면 그 자리에서 종료하므로, "READY"가 떴다는 것은 곧 실행 환경(계정·환경변수·키파일·포트·로그 권한)이 모두 정상이라는 뜻이다. 실제 출력은 [evidence/05_boot_sequence.txt](./evidence/05_boot_sequence.txt) 에 수집돼 있다.

```
>>> Starting Agent Boot Sequence...
[1/5] Checking User Account               [OK]
   ... Running as service user 'agent-admin' (uid=1001)
[2/5] Verifying Environment Variables     [OK]
   ... All required Envs correct
[3/5] Checking Required Files             [OK]
   ... Verified 'secret.key' with correct key string.
[4/5] Checking Port Availability          [OK]
   ... Port 15034 is available.
[5/5] Verifying Log Permission            [OK]
   ... Log directory is writable: /var/log/agent-app
------------------------------------------------------------
All Boot Checks Passed!
Agent READY
```

| 단계 | 검사 내용 | 통과 근거 |
| --- | --- | --- |
| 1/5 User Account | root 가 아닌 서비스 계정으로 실행 중인가 | `runuser -u agent-admin` 으로 기동 (uid=1001) |
| 2/5 Environment Variables | 필수 env 5개가 모두 올바른가 | docker 가 주입한 AGENT_* 값 |
| 3/5 Required Files | `$AGENT_KEY_PATH/secret.key` 가 올바른 키 값으로 존재하는가 | entrypoint 가 `secret.key` 생성 (640) |
| 4/5 Port Availability | 15034 포트를 바인딩할 수 있는가 | 다른 프로세스가 점유하지 않음 |
| 5/5 Log Permission | 로그 디렉토리에 쓸 수 있는가 | `/var/log/agent-app` 가 agent-core 그룹에 rwx |

검증: `docker logs b1-1-agent` 에서 `[1/5]`~`[5/5]` 가 전부 `[OK]` 이고 마지막에 `Agent READY` 가 찍히는지, 이어서 `ss -tulnp | grep :15034` 로 `0.0.0.0:15034` LISTEN 을 확인한다.

### 쉘 스크립트로 프로세스/포트/리소스를 수집·로깅하여 운영 문제 추적하는 흐름

장애는 갑자기 오지 않는다. 보통 CPU/메모리가 서서히 차오르거나, 프로세스가 죽은 채로 한참 방치되거나, 포트가 막혀 있는 상태로 운영된다. 사람이 매번 들여다보지 못하니 자동화가 필요하다.

monitor.sh는 먼저 Health Check로 대상 프로세스(`agent_app`)가 살아있는지, 포트 15034가 LISTEN 중인지 확인하고 둘 중 하나라도 실패하면 `exit 1`로 즉시 알린다. UFW가 켜져있는지도 보지만 비활성이면 `[WARNING]`만 출력하고 계속 진행한다. 관제 자체가 멈추면 안 되기 때문이다. 그 뒤 CPU/MEM/DISK 사용률을 수치로 뽑고, 정해둔 한계(CPU>20, MEM>10, DISK>80)를 넘으면 `[WARNING]`을 찍는다. 마지막에 `/var/log/agent-app/monitor.log`로 `[YYYY-MM-DD HH:MM:SS] PID:.. CPU:..% MEM:..% DISK_USED:..%` 한 줄을 append 한다.

로그는 "지금 이 순간"의 상태가 아니라 "시간에 따른 변화"를 봐야 의미가 있기 때문에 누적 기록이 핵심이다. 장애가 났을 때 로그를 뒤져 추세를 보고 원인을 추적한다.

### 프로세스 식별 / 포트 확인에 쓴 명령과 선택 이유

프로세스 식별 — `pgrep`

```bash
PID=$(pgrep -x "$APP_NAME" | head -n 1 || true)
```

- `pgrep -x agent_app` : `-x`는 프로세스 이름이 정확히 일치할 때만 매칭한다. `agent_app_helper` 같은 유사 이름을 오탐하지 않는다. 대상 바이너리 이름이 `agent_app`로 고정돼 있으므로 정확 매칭 한 번으로 충분하다.
- `ps -ef | grep agent_app` 대신 `pgrep`을 쓴 이유: grep 자기 자신이 결과에 끼어드는 문제(`grep agent_app` 라인)가 없고, PID만 깔끔히 반환해 후처리가 단순하다. `head -n 1`로 첫 PID만 취한다.

포트 확인 — `ss`

```bash
ss -ltn "( sport = :$AGENT_PORT )" | grep -q ":$AGENT_PORT"
```

- `ss`는 iproute2의 기본 도구로, 커널 소켓 정보를 직접 조회해 `netstat`보다 빠르다. `netstat`(net-tools)은 deprecated 라 최신 Ubuntu에 기본 설치되지 않는다.
- 플래그 의미: `-l` LISTEN 상태만, `-t` TCP만, `-n` 포트를 숫자 그대로(이름 변환 안 함). 필요한 정보만 좁혀서 본다.
- `( sport = :PORT )` 필터로 해당 포트의 소켓만 직접 거른다. "프로세스가 살아있다"와 "포트가 실제로 열려 LISTEN 중이다"는 별개 상태이므로 둘을 따로 검사한다(→ 트러블슈팅의 "프로세스는 살아있는데 포트가 안 열림" 참고).

### CPU/MEM/DISK 추출·파싱 방식과 로그 포맷을 고정한 이유

CPU — `/proc/stat` 2회 샘플링

```bash
read _ user nice system idle iowait irq softirq steal _ < /proc/stat   # 1차
sleep 1
read _ user nice system idle iowait irq softirq steal _ < /proc/stat   # 2차
# usage = (1 - Δidle / Δtotal) * 100   (awk 로 계산)
```

CPU 사용률은 누적 tick 값이라 "순간값"이 없다. 그래서 1초 간격으로 두 번 읽어 그 사이의 증가분(Δ)으로 구간 사용률을 구한다. `(1 - idle증가/total증가)×100`. 부동소수 계산이라 bash 산술 대신 `awk`로 처리한다.

MEM — `free` + `awk`

```bash
free | awk '/^Mem:/ { printf "%.1f", ($3 / $2) * 100 }'
```

`Mem:` 줄에서 `$2`(total), `$3`(used)를 뽑아 used/total 백분율을 낸다.

DISK — `df -P` + `awk`

```bash
df -P / | awk 'NR==2 { gsub("%","",$5); print $5 }'
```

루트(`/`) 파티션의 사용률 필드(`$5`)를 취하고 `gsub`로 `%` 기호를 제거해 숫자만 남긴다. `df`에 `-P`(POSIX 출력)를 준 이유: 장치명이 길면 줄이 두 줄로 깨지는데, `-P`는 한 줄로 고정해줘 `NR==2`/`$5` 필드 위치가 항상 일정하다.

로그 포맷을 한 줄·고정 필드로 박은 이유

```
[2026-05-26 11:44:02] PID:314 CPU:2.7% MEM:10.2% DISK_USED:1.0%
```

`[시각] PID:.. CPU:..% MEM:..% DISK_USED:..%` 로 한 줄 = 한 시점, 필드 순서를 고정했다. 이렇게 해야 나중에 `grep`/`awk`/`cut`으로 특정 시간대나 특정 지표만 뽑아 추세를 분석하기 쉽다(머신 파싱 친화). 시각을 맨 앞에 둔 것도 시간순 정렬·구간 추출을 자연스럽게 하기 위함이다.

### 소유자(agent-dev)와 실행자(agent-admin, cron) 권한 정책

monitor.sh는 [entrypoint.sh](./scripts/entrypoint.sh)에서 다음과 같이 배치된다.

```bash
install -m 750 -o agent-dev -g agent-core /opt/setup/monitor.sh "$AGENT_HOME/bin/monitor.sh"
```

| 비트 | 대상 | 권한 | 의미 |
| --- | --- | --- | --- |
| `7` | owner = agent-dev | rwx | 스크립트를 작성·수정하는 개발자가 소유 |
| `5` | group = agent-core | r-x | 그룹 멤버는 읽기·실행만 (수정 불가) |
| `0` | other | --- | 무관 계정 완전 차단 |

- 소유자(agent-dev): 스크립트의 작성/유지보수 주체가 개발자이므로 소유권을 가져 변경할 수 있다.
- 실행자(agent-admin, cron): 운영자 agent-admin은 `agent-core` 그룹 멤버라 그룹 `r-x` 비트로 스크립트를 실행할 수 있지만(쓰기는 불가) 내용은 못 바꾼다 — 운영자가 멋대로 로직을 수정하는 것을 막는다. cron은 agent-admin의 crontab으로 등록돼 동일 권한으로 매분 실행한다.
- 로그 기록 연결: monitor.log가 있는 `/var/log/agent-app`는 `agent-core` 그룹 소유에 `2770`(setgid)이라, agent-core 멤버인 agent-admin이 로그를 append할 수 있다. agent-test는 agent-core가 아니므로 실행·로그 접근 모두 차단된다(최소 권한).

검증: `ls -l $AGENT_HOME/bin/monitor.sh` 로 `-rwxr-x--- agent-dev agent-core` 확인, `crontab -u agent-admin -l` 로 실행 주체 확인, `id agent-admin` 으로 agent-core 멤버십 확인.

### 파일·디렉토리별 소유자/그룹/권한/ACL 일람

[entrypoint.sh](./scripts/entrypoint.sh)의 `chown` / `chmod` / `setfacl` 설정을 경로별로 정리한 표다. (경로는 env 기준값으로 표기)

| 경로 | 종류 | 소유자 | 그룹 | 권한 | ACL(setfacl) | 결과(접근 정책) |
| --- | --- | --- | --- | --- | --- | --- |
| `$AGENT_HOME` (`/home/agent-admin/agent-app`) | dir | agent-admin | agent-common | `750` | — | 소유자 rwx, common 그룹 r-x(진입), 그 외 차단 |
| `$AGENT_HOME/bin` | dir | agent-admin | agent-common | `755` (mkdir 기본, 별도 chmod 없음) | — | 소유자(agent-admin) rwx → **이 디렉토리 안 파일 생성·삭제·교체 가능** |
| `$AGENT_HOME/bin/monitor.sh` | file | agent-dev | agent-core | `750` | — | owner(dev) rwx, core 그룹(admin 포함) r-x(실행), other 차단. 단 상위 `bin`을 admin이 소유 → admin이 rm 후 교체는 가능 |
| `$AGENT_HOME/etc` | dir | agent-admin | agent-admin | `700` | — | admin 전용 |
| `$AGENT_HOME/etc/agent.env` | file | agent-admin | agent-admin | `600` | — | admin만 R/W (env 비밀값 보호) |
| `$AGENT_UPLOAD_DIR` (`upload_files`) | dir | agent-admin | agent-common | `2770` | `g:agent-common:rwx` + default 동일 | common(admin/dev/test) 공유 R/W, setgid+default ACL로 새 파일도 그룹/권한 상속, other 차단 |
| `$AGENT_KEY_PATH` (`api_keys`) | dir | agent-admin | agent-core | `2770` | `g:agent-core:rwx` + default 동일 + `o::---` | core(admin/dev)만 R/W, test/other 완전 차단 |
| `$AGENT_KEY_PATH/secret.key` | file | agent-admin | agent-core | `640` | 상위 default ACL 상속(`g:agent-core:rwx`)하나 `640` mask로 그룹 실효권한 `r--` | owner rw, core 그룹 r, other 차단 |
| `$AGENT_LOG_DIR` (`/var/log/agent-app`) | dir | agent-admin | agent-core | `2770` | `g:agent-core:rwx` + default 동일 + `o::---` | core만 R/W, 로그 보호 |
| `$AGENT_LOG_DIR/monitor.log` | file | agent-admin | agent-core | 런타임 생성 | 상위 default ACL 상속(`g:agent-core:rwx`) | monitor.sh 실행 중 첫 append 시 생성, setgid로 그룹=core 상속 → core 멤버가 기록 |

참고: `secret.key`와 `monitor.log`는 ACL을 직접 부여하지 않고, 상위 디렉토리의 **default ACL**과 **setgid**로 소유 그룹/권한을 자동 상속받는다. 즉 디렉토리에 한 번 정책을 박아두면 그 안에 생기는 새 파일에도 동일 정책이 적용된다.

### crontab 주기 실행 및 로그 보존 정책(압축/삭제) 필요성

사람이 매분 monitor.sh를 손으로 돌릴 순 없다. crontab에 `* * * * *`로 등록해서 매분 자동 실행한다. 그러면 사람이 자는 동안에도 시스템 상태가 기록된다.

다만 로그는 가만히 두면 무한히 쌓인다. monitor.log가 매분 한 줄씩, 한 줄당 70바이트만 잡아도 1년이면 ~37MB. 여러 종류의 로그가 합쳐지면 디스크가 차서 서비스 자체가 죽는다 (disk full → 앱이 로그 못 써서 죽는 케이스 흔함).

그래서 보존 정책이 같이 필요하다. 일정 크기(10MB)를 넘으면 새 파일로 회전하고(logrotate가 담당), 최대 10개까지만 보관해 가장 오래된 것부터 삭제한다. 보너스로 시간 기반 정책(7일 경과 압축, 30일 경과 아카이브 삭제)을 추가하면 디스크 공간을 더 안정적으로 관리할 수 있다.

운영 가시성을 유지하면서도 디스크가 차지 않게 하는 균형이다.


## 운영 시나리오 / 트러블슈팅

### 모니터링 대상이 웹 서버(Nginx)로 바뀐다면 monitor.sh에서 바꿀 핵심 포인트

monitor.sh의 골격(Health Check → 자원 수집 → 임계값 경고 → 로그 append)은 그대로 두고, "무엇을 보는가"에 해당하는 4가지만 바꾸면 된다.

| 포인트 | 현재(agent_app) | Nginx로 변경 시 |
| --- | --- | --- |
| 프로세스 | `APP_NAME=agent_app` | `nginx`. 단 Nginx는 master + 다수 worker 구조라 `pgrep -x nginx`가 여러 PID를 반환한다 → master만 보려면 `pgrep -x nginx | head -n 1` 또는 master 프로세스를 기준으로 판정 |
| 포트 | `$AGENT_PORT`(15034) | `80`(HTTP) / `443`(HTTPS). 둘 다 검사하려면 포트 확인을 두 번 돌린다 |
| 로그 | `$AGENT_LOG_DIR/monitor.log`에 관제 결과 기록 | 관제 결과 경로는 유지하되, 점검 대상 앱 로그는 `/var/log/nginx/access.log`·`error.log`. 필요 시 error.log의 최근 에러도 같이 수집 |
| 임계값 | CPU>20 MEM>10 DISK>80 | 웹 트래픽 특성에 맞게 재조정(상시 높은 CPU/커넥션 수 등). 5xx 비율·동시 커넥션 같은 웹 전용 지표를 추가할 수도 있음 |

핵심은 "프로세스 이름 / 포트 / 로그 경로 / 임계값"이 대상에 종속된 값이고, 수집·판정·기록 로직은 재사용된다는 점이다. 그래서 이런 값들은 스크립트 상단 변수로 빼두는 게 유지보수에 유리하다.

### "프로세스는 살아있는데 포트가 안 열리는" 상황 — 원인 후보와 확인 순서

monitor.sh는 프로세스 검사와 포트 검사를 일부러 분리한다. 둘은 별개 상태라, 프로세스는 `[OK]`인데 포트가 `[FAIL]`인 경우가 실제로 생긴다.

원인 후보

1. 앱이 아직 초기화 중 — 프로세스는 떴지만 소켓 바인딩 전(기동 지연).
2. 바인딩 주소가 다름 — `127.0.0.1`(루프백)에만 바인딩돼 외부/0.0.0.0에서 안 보임.
3. 포트 충돌 — 다른 프로세스가 포트를 선점해 바인딩 실패했지만 프로세스 본체는 죽지 않고 잔존.
4. 방화벽 차단 — 앱은 LISTEN 중인데 UFW가 해당 포트를 막아 외부에서 닫힌 것처럼 보임.
5. 설정상 다른 포트 — 설정 파일의 포트 값이 기대값과 달라 엉뚱한 포트로 리슨.

확인 순서(싼·빠른 것부터)

1. `ss -ltnp` — 실제로 LISTEN 중인지, 바인딩 주소가 `0.0.0.0`인지 `127.0.0.1`인지, 어떤 PID가 잡고 있는지 한 번에 본다.
2. 앱 로그 확인 — `bind: Address already in use` / `permission denied` 같은 바인딩 에러가 있는지.
3. 포트 점유 프로세스 확인 — `ss -ltnp 'sport = :PORT'`로 다른 프로세스가 선점했는지(원인 3).
4. `ufw status` — 포트가 ALLOW 목록에 있는지(원인 4).
5. 앱 설정 파일의 포트/바인딩 주소 값 확인(원인 2·5).

### 로그 급증으로 디스크가 찰 위험 — 운영자의 단기/중기 대응

로그가 폭주하면 디스크가 차고, 앱이 로그를 못 써서 죽는 연쇄 장애로 이어진다(disk full). 대응은 "지금 불 끄기(단기)"와 "재발 방지(중기)"로 나눈다.

단기 (즉시 디스크 확보 — 서비스 정지 방지)

1. `df -h`로 어느 파티션이 찼는지, `du -sh /var/log/* | sort -h`로 어떤 디렉토리/파일이 범인인지 식별.
2. 안전하게 지워도 되는 오래된 회전 로그(`*.1`, `*.gz`)부터 삭제/압축.
3. `logrotate -f /etc/logrotate.d/agent-monitor`로 즉시 강제 회전.
4. 가동 중이라 삭제해도 공간이 안 돌아오는(열린 파일) 경우 `truncate -s 0` 또는 logrotate의 `copytruncate`로 파일을 비운다 — 프로세스 재시작 없이 공간 회수.

중기 (재발 방지)

1. logrotate 정책 강화 — `size`/`rotate` 값과 회전 주기 조정, `compress`로 보관본 압축.
2. 로그 발생량 자체 줄이기 — 앱 로그 레벨을 DEBUG→INFO/WARN으로 낮춰 불필요한 로그 억제.
3. 중앙 로그 수집 — 로그를 원격(로그 서버/수집기)으로 전송해 로컬 디스크 의존을 끊는다.
4. 디스크 사용률 알람 — monitor.sh의 DISK 임계값 경고처럼, 디스크가 차기 전에 미리 경보가 울리도록 모니터링을 둔다.


## Linux pipes, redirections

| 기호     | 이름             | 의미                                  | 예시                   |
| ------ | -------------- | ----------------------------------- | -------------------- |
| `<`    | 입력 리다이렉션       | `stdin` 대상 변경                       | `cmd < input.txt`    |
| `>`    | 출력 리다이렉션       | `stdout` 대상 변경                      | `cmd > output.txt`   |
| `>>`   | 출력 리다이렉션 (append)   | `stdout` 대상을 추가 모드로 변경              | `cmd >> output.txt`  |
| `2>`   | 에러 리다이렉션       | `stderr` 대상 변경                      | `cmd 2> error.txt`   |
| `2>>`  | 에러 리다이렉션 (append)   | `stderr` 대상을 추가 모드로 변경              | `cmd 2>> error.txt`  |
| `2>&1` | 에러 출력 병합       | `stderr`를 현재 `stdout` 대상과 같은 곳으로 연결 | `cmd > all.log 2>&1` |
| `1>&2` | 출력 에러 병합       | `stdout`을 현재 `stderr` 대상과 같은 곳으로 연결 | `echo error 1>&2`    |
| `&>`   | 출력·에러 동시 리다이렉션 | `stdout`과 `stderr` 대상 동시 변경         | `cmd &> all.log`     |

| 기호   | 이름  | 의미                                   | 예시               |
| ---- | --- | ------------------------------------ | ---------------- |
| `\|` | 파이프 | 앞 명령어의 `stdout`을 뒤 명령어의 `stdin`으로 연결 | `ls \| grep txt` |

| 기호     | 이름          | 의미                  | 예시                      |
| ------ | ----------- | ------------------- | ----------------------- |
| `&&`   | AND 리스트 연산자 | 앞 명령어 성공 시 뒤 명령어 실행 | `mkdir test && cd test` |
| `\|\|` | OR 리스트 연산자  | 앞 명령어 실패 시 뒤 명령어 실행 | `cmd \|\| echo fail`    |

명령어의 결과값의 출력을 변경하거나, 다른 명령어의 입력으로 사용할 때 리다이렉션과 파이프를 사용한다.
기타 쉘 문법은 [shell_syntax](./docs/SHELL_SYNTAX.md)에 정리해뒀다.

## chmod의 특수 권한

owner, group, other user로 구분되는 3자리 비트 맨 앞에다 숫자를 하나 더 적으면, chmod의 특수 권한으로 작동한다.

|  숫자 |   이진값 | 특수 권한                    | 의미                   |
| --: | ----: | ------------------------ | -------------------- |
| `0` | `000` | 없음                       | 특수 권한 없음             |
| `1` | `001` | sticky bit               | 공유 디렉터리 삭제 제한        |
| `2` | `010` | setgid                   | 그룹 권한 상속 또는 그룹 권한 실행 |
| `3` | `011` | setgid + sticky          | setgid와 sticky 동시 적용 |
| `4` | `100` | setuid                   | 파일 소유자 권한으로 실행       |
| `5` | `101` | setuid + sticky          | setuid와 sticky 동시 적용 |
| `6` | `110` | setuid + setgid          | setuid와 setgid 동시 적용 |
| `7` | `111` | setuid + setgid + sticky | 세 특수 권한 모두 적용        |

## ACL syntax

[acl_syntax](./docs/ACL_SYNTAX.md)

## AWK syntax

[awk_syntax](./docs/AWK_SYNTAX.md)