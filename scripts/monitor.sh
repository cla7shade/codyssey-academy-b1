#!/usr/bin/env bash
# monitor.sh
# 시스템 관제 자동화 스크립트
# - 대상 프로세스/포트 Health Check
# - UFW 방화벽 상태 점검 (경고만)
# - CPU/MEM/DISK 자원 수집 & 임계값 경고
# - $AGENT_LOG_DIR/monitor.log 누적 기록
#
# 사용법: monitor.sh <agent.env 경로>

set -euo pipefail

. "${1:?usage: monitor.sh <agent.env path>}"

APP_NAME="agent_app"
LOG_FILE="$AGENT_LOG_DIR/monitor.log"

CPU_LIMIT=20
MEM_LIMIT=10
DISK_LIMIT=80

echo "[HEALTH CHECK]"

# Health Check : 프로세스
PID=$(pgrep -x "$APP_NAME" | head -n 1 || true)

if [ -z "$PID" ]; then
    echo "Checking process '$APP_NAME'... [FAIL]"
    echo "[ERROR] $APP_NAME process is not running"
    exit 1
fi

echo "Checking process '$APP_NAME'... [OK] (PID: $PID)"

# Health Check : 포트 LISTEN
if ss -ltn "( sport = :$AGENT_PORT )" 2>/dev/null | grep -q ":$AGENT_PORT"; then
    echo "Checking port $AGENT_PORT... [OK]"
else
    echo "Checking port $AGENT_PORT... [FAIL]"
    echo "[ERROR] port $AGENT_PORT is not in LISTEN state"
    exit 1
fi

# 상태 점검 : UFW 방화벽 (경고만)
ufw_active=0

if command -v ufw >/dev/null 2>&1; then
    if ufw status 2>/dev/null | grep -qi 'Status: active'; then
        ufw_active=1
    elif [ -r /etc/ufw/ufw.conf ] && grep -q '^ENABLED=yes' /etc/ufw/ufw.conf; then
        ufw_active=1
    fi
fi

if [ "$ufw_active" -ne 1 ]; then
    echo "[WARNING] UFW firewall is not active"
fi

echo
echo "[RESOURCE MONITORING]"

# CPU 사용률
# cpu  12000 35 4300 900000 250 0 800 0 0 0
read _ user nice system idle iowait irq softirq steal _ < /proc/stat
CPU_TOTAL_1=$((user + nice + system + idle + iowait + irq + softirq + steal))
CPU_IDLE_1=$((idle + iowait))

sleep 1

read _ user nice system idle iowait irq softirq steal _ < /proc/stat
CPU_TOTAL_2=$((user + nice + system + idle + iowait + irq + softirq + steal))
CPU_IDLE_2=$((idle + iowait))

CPU_USAGE=$(
    awk -v total1="$CPU_TOTAL_1" -v total2="$CPU_TOTAL_2" \
        -v idle1="$CPU_IDLE_1" -v idle2="$CPU_IDLE_2" \
        'BEGIN {
            total = total2 - total1
            idle = idle2 - idle1
            if (total == 0) {
                printf "0"
            } else {
                printf "%.1f", (1 - idle / total) * 100
            }
        }'
)

# MEM 사용률
MEM_USAGE=$(free | awk '/^Mem:/ { printf "%.1f", ($3 / $2) * 100 }')

# DISK 사용률
DISK_USED=$(df -P / | awk 'NR==2 { gsub("%", "", $5); print $5 }')

printf "CPU Usage : %.1f%%\n" "$CPU_USAGE"
printf "MEM Usage : %.1f%%\n" "$MEM_USAGE"
printf "DISK Used : %.1f%%\n" "$DISK_USED"

echo

# 임계값 경고 (경고만)
awk -v v="$CPU_USAGE" -v limit="$CPU_LIMIT" 'BEGIN { if (v > limit) printf "[WARNING] CPU threshold exceeded (%.1f%% > %d%%)\n", v, limit }'
awk -v v="$MEM_USAGE" -v limit="$MEM_LIMIT" 'BEGIN { if (v > limit) printf "[WARNING] MEM threshold exceeded (%.1f%% > %d%%)\n", v, limit }'
awk -v v="$DISK_USED" -v limit="$DISK_LIMIT" 'BEGIN { if (v > limit) printf "[WARNING] DISK threshold exceeded (%.1f%% > %d%%)\n", v, limit }'

# 로그 기록
TS=$(date '+%Y-%m-%d %H:%M:%S')

printf '[%s] PID:%s CPU:%.1f%% MEM:%.1f%% DISK_USED:%.1f%%\n' \
    "$TS" "$PID" "$CPU_USAGE" "$MEM_USAGE" "$DISK_USED" >> "$LOG_FILE"

echo
echo "[INFO] Log appended: $LOG_FILE"