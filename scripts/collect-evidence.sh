#!/usr/bin/env bash
# 컨테이너 b1-1-agent 에서 체크리스트 B 섹션의 증거 자료를 수집한다.
# 각 파일은 "$ <명령>" 줄과 그 출력 형식으로 저장된다.
set -euo pipefail

CONTAINER="${CONTAINER:-b1-1-agent}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/evidence"
mkdir -p "$OUT"

# 컨테이너 안에서 명령을 실행하고, 명령 자체와 출력을 함께 파일로 저장
# 사용법: capture <파일명> <명령>
capture() {
    local file="$1"; shift
    local cmd="$*"
    {
        echo "\$ docker exec $CONTAINER bash -c '$cmd'"
        docker exec "$CONTAINER" bash -c "$cmd" 2>&1 || true
    } > "$OUT/$file"
    echo "  wrote $file"
}

# 호스트에서 실행한 명령도 동일 포맷으로 저장
capture_host() {
    local file="$1"; shift
    local cmd="$*"
    {
        echo "\$ $cmd"
        eval "$cmd" 2>&1 || true
    } > "$OUT/$file"
    echo "  wrote $file"
}

echo "[evidence] container = $CONTAINER"
echo "[evidence] output    = $OUT"

# 1) SSH 포트 20022 / PermitRootLogin no / 리슨 상태
capture 01_ssh.txt \
    "cat /etc/ssh/sshd_config.d/10-agent.conf; echo; echo '--- ss -tulnp | grep sshd ---'; ss -tulnp | grep -E 'sshd|:20022'"

# 2) UFW 활성 + 허용 포트
capture 02_ufw.txt "ufw status verbose"

# 3) 계정 / 그룹
capture 03_accounts.txt \
    "for u in agent-admin agent-dev agent-test; do id \$u; done; echo; echo '--- getent group ---'; getent group agent-common agent-core"

# 4) 디렉토리 / 권한 / ACL / 키파일 / monitor.sh
capture 04_dirs_acl.txt \
    "ls -ld \$AGENT_HOME \$AGENT_HOME/upload_files \$AGENT_HOME/api_keys \$AGENT_HOME/bin \$AGENT_LOG_DIR; echo; echo '--- key file ---'; ls -l \$AGENT_HOME/api_keys/secret.key; echo; echo '--- monitor.sh ---'; ls -l \$AGENT_HOME/bin/monitor.sh; echo; echo '--- getfacl ---'; getfacl \$AGENT_HOME/upload_files \$AGENT_HOME/api_keys \$AGENT_LOG_DIR"

# 5) Boot Sequence — 컨테이너 stdout 로그에서 추출 (호스트에서 docker logs)
capture_host 05_boot_sequence.txt \
    "docker logs $CONTAINER 2>&1 | sed -n '/Starting Agent Boot Sequence/,/Agent READY/p'"

# 6) monitor.sh 수동 실행 결과 (cron 과 동일 사용자/경로)
capture 06_monitor_run.txt \
    "sudo -u agent-admin \$AGENT_HOME/bin/monitor.sh \$AGENT_HOME/etc/agent.env"

# 7) agent-admin crontab
capture 07_crontab.txt "crontab -u agent-admin -l"

# 8) monitor.log 누적 — 80초 대기해 cron 한 번 더 돌게 한 뒤 캡쳐
echo "[evidence] waiting 80s for cron tick..."
sleep 80
capture 08_monitor_log_tail.txt \
    "echo '--- monitor.log ---'; cat \$AGENT_LOG_DIR/monitor.log; echo; echo '--- 누적 라인 수 ---'; wc -l \$AGENT_LOG_DIR/monitor.log"

# 인덱스
cat > "$OUT/README.md" <<EOF
# B1-1 Evidence

수집 시각: $(date)
컨테이너: $CONTAINER

| # | 파일 | 체크리스트 항목 |
|---|------|-----------------|
| 01 | 01_ssh.txt | SSH 포트 20022 + PermitRootLogin no + ss 리슨 |
| 02 | 02_ufw.txt | UFW 활성 + 20022/15034 만 허용 |
| 03 | 03_accounts.txt | agent-admin/dev/test 계정, agent-common/core 그룹 |
| 04 | 04_dirs_acl.txt | 디렉토리 구조 / 권한 / ACL / 키 파일 / monitor.sh |
| 05 | 05_boot_sequence.txt | Boot 5/5 [OK] + Agent READY |
| 06 | 06_monitor_run.txt | monitor.sh 실행 결과 |
| 07 | 07_crontab.txt | agent-admin crontab 매분 등록 |
| 08 | 08_monitor_log_tail.txt | monitor.log 누적 (cron 매분 자동 실행 증거) |

각 파일 첫 줄에 사용한 명령(\`\$ ...\`)이 함께 기록되어 있다.
EOF

echo "[evidence] done"
ls -la "$OUT"
