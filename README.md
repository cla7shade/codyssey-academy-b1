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

### 쉘 스크립트로 프로세스/포트/리소스를 수집·로깅하여 운영 문제 추적하는 흐름

장애는 갑자기 오지 않는다. 보통 CPU/메모리가 서서히 차오르거나, 프로세스가 죽은 채로 한참 방치되거나, 포트가 막혀 있는 상태로 운영된다. 사람이 매번 들여다보지 못하니 자동화가 필요하다.

monitor.sh는 먼저 Health Check로 대상 프로세스(`agent_app`)가 살아있는지, 포트 15034가 LISTEN 중인지 확인하고 둘 중 하나라도 실패하면 `exit 1`로 즉시 알린다. UFW가 켜져있는지도 보지만 비활성이면 `[WARNING]`만 출력하고 계속 진행한다. 관제 자체가 멈추면 안 되기 때문이다. 그 뒤 CPU/MEM/DISK 사용률을 수치로 뽑고, 정해둔 한계(CPU>20, MEM>10, DISK>80)를 넘으면 `[WARNING]`을 찍는다. 마지막에 `/var/log/agent-app/monitor.log`로 `[YYYY-MM-DD HH:MM:SS] PID:.. CPU:..% MEM:..% DISK_USED:..%` 한 줄을 append 한다.

로그는 "지금 이 순간"의 상태가 아니라 "시간에 따른 변화"를 봐야 의미가 있기 때문에 누적 기록이 핵심이다. 장애가 났을 때 로그를 뒤져 추세를 보고 원인을 추적한다.

### crontab 주기 실행 및 로그 보존 정책(압축/삭제) 필요성

사람이 매분 monitor.sh를 손으로 돌릴 순 없다. crontab에 `* * * * *`로 등록해서 매분 자동 실행한다. 그러면 사람이 자는 동안에도 시스템 상태가 기록된다.

다만 로그는 가만히 두면 무한히 쌓인다. monitor.log가 매분 한 줄씩, 한 줄당 70바이트만 잡아도 1년이면 ~37MB. 여러 종류의 로그가 합쳐지면 디스크가 차서 서비스 자체가 죽는다 (disk full → 앱이 로그 못 써서 죽는 케이스 흔함).

그래서 보존 정책이 같이 필요하다. 일정 크기(10MB)를 넘으면 새 파일로 회전하고(logrotate가 담당), 최대 10개까지만 보관해 가장 오래된 것부터 삭제한다. 보너스로 시간 기반 정책(7일 경과 압축, 30일 경과 아카이브 삭제)을 추가하면 디스크 공간을 더 안정적으로 관리할 수 있다.

운영 가시성을 유지하면서도 디스크가 차지 않게 하는 균형이다.


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