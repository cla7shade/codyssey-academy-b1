## A. 최종 결과물 (산출물)

- [x] `[file]` 요구사항 수행 내역서 (README.md)
- [x] `[file]` 자동화 스크립트 소스코드 `monitor.sh`

## B. 필수 증거 자료 (수행 로그)

수집 결과: [b1-1/evidence/](../evidence/)

- [x] `[log]` SSH 포트 20022 변경 및 Root 원격 접속 차단 설정 확인 내역 → [evidence/01_ssh.txt](../evidence/01_ssh.txt)
- [x] `[log]` 방화벽(UFW) 활성화 및 20022/tcp, 15034/tcp 만 허용 확인 내역 → [evidence/02_ufw.txt](../evidence/02_ufw.txt)
- [x] `[log]` 계정(agent-admin/dev/test) 및 그룹(agent-common/core) 생성 확인 내역 → [evidence/03_accounts.txt](../evidence/03_accounts.txt)
- [x] `[log]` 디렉토리 구조 및 권한(ACL 포함) 확인 내역 → [evidence/04_dirs_acl.txt](../evidence/04_dirs_acl.txt)
- [x] `[log]` 앱 Boot Sequence 5단계 `[OK]` 및 "Agent READY" 확인 내역 → [evidence/05_boot_sequence.txt](../evidence/05_boot_sequence.txt)
- [x] `[log]` `monitor.sh` 실행 결과(프로세스/포트/리소스/경고) 내역 → [evidence/06_monitor_run.txt](../evidence/06_monitor_run.txt)
- [x] `[log]` `/var/log/agent-app/monitor.log` 누적 기록(최근 라인) 확인 내역 → [evidence/08_monitor_log_tail.txt](../evidence/08_monitor_log_tail.txt)
- [x] `[log]` crontab 매분 실행 등록 및 1분 후 로그 증가 확인 내역 → [evidence/07_crontab.txt](../evidence/07_crontab.txt), [evidence/08_monitor_log_tail.txt](../evidence/08_monitor_log_tail.txt)

## C. 기능 요구사항

### C-1. 기본 보안 / 네트워크
- [x] `[requirements]` SSH 포트 20022 로 변경
- [x] `[requirements]` Root 원격 로그인 차단 (`PermitRootLogin no`)
- [x] `[requirements]` UFW 활성화 및 inbound 20022/tcp, 15034/tcp 만 허용

### C-2. 계정 / 그룹 / 권한
- [x] `[requirements]` 계정 생성: agent-admin, agent-dev, agent-test
- [x] `[requirements]` 그룹 생성: agent-common(admin/dev/test), agent-core(admin/dev)
- [x] `[requirements]` 디렉토리 생성: `$AGENT_HOME`, `$AGENT_HOME/upload_files`, `$AGENT_HOME/api_keys`, `/var/log/agent-app`
- [x] `[requirements]` `upload_files` : group=agent-common, R/W
- [x] `[requirements]` `api_keys`, `/var/log/agent-app` : group=agent-core ONLY, R/W

### C-3. 애플리케이션 실행 환경
- [x] `[requirements]` 환경변수 설정: `AGENT_HOME`, `AGENT_PORT=15034`, `AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files`, `AGENT_KEY_PATH=$AGENT_HOME/api_keys` (디렉토리; 미션 PDF는 파일 경로로 적혀 있으나 제공 바이너리는 디렉토리를 기대), `AGENT_LOG_DIR=/var/log/agent-app`
- [x] `[requirements]` 키 파일 `$AGENT_KEY_PATH/secret.key` 내용 `agent_api_key_test` (1줄) — 미션 PDF의 `t_secret.key` 와 다르게 제공 바이너리는 `secret.key` 를 요구함
- [x] `[requirements]` 앱을 일반 계정(agent-admin) 으로 실행 (root 금지)
- [x] `[requirements]` Boot Sequence 5단계 `[OK]`, "Agent READY", `0.0.0.0:15034` LISTEN

### C-4. monitor.sh
- [x] `[requirements]` 경로 `$AGENT_HOME/bin/monitor.sh`, 소유=agent-dev, 그룹=agent-core, 권한 750
- [x] `[requirements]` cron 실행 계정 = agent-admin (agent-core 멤버)
- [x] `[requirements]` Health Check: agent_app 프로세스/포트 15034 LISTEN, 실패 시 `exit 1`
- [x] `[requirements]` 방화벽 비활성 시 `[WARNING]` 출력 (스크립트는 종료하지 않음)
- [x] `[requirements]` 자원 수집: CPU%, MEM%, DISK Used%
- [x] `[requirements]` 임계값 경고: CPU>20, MEM>10, DISK_USED>80 → `[WARNING]`
- [x] `[requirements]` 로그 기록: `/var/log/agent-app/monitor.log`, 포맷 `[YYYY-MM-DD HH:MM:SS] PID:.. CPU:..% MEM:..% DISK_USED:..%`
- [x] `[requirements]` 로그 보존: 최대 10MB / 10개 파일 유지

### C-5. cron 자동 실행
- [x] `[requirements]` agent-admin 의 crontab 으로 monitor.sh 매분 실행
- [x] `[requirements]` 등록 후 1~2분 내 monitor.log 누적 확인

## D. 과제 목표 (README 에 설명문으로 작성)

작성 위치: [../README.md#과제-목표-설명](../README.md#과제-목표-설명)

- [x] `[description]` SSH 포트 변경 / Root 원격 차단이 기본 보안인 이유
- [x] `[description]` UFW "필요 포트만 허용" 정책 구성과 검증 방법
- [x] `[description]` 역할 기반 계정/그룹/ACL 로 "공유" 와 "보안" 디렉토리를 분리하는 이유
- [x] `[description]` 환경변수(AGENT_HOME 등) 로 실행 환경을 고정하는 이유와 검증 방법
- [x] `[description]` 쉘 스크립트로 프로세스/포트/리소스를 수집·로깅하여 운영 문제 추적하는 흐름
- [x] `[description]` crontab 주기 실행 및 로그 보존 정책(압축/삭제) 필요성

## E. 제약 사항
- [x] `[requirements]` 자동화 스크립트는 Bash 로만 작성 (Python 등 금지)
- [x] `[requirements]` 가능한 일반 계정 사용, 필요할 때만 sudo
- [x] 실행 환경: Ubuntu 24.04 컨테이너 (Docker, --privileged)
