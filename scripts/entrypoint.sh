#!/bin/bash
# 실패 시 종료, 정의되지 않은 변수 사용 시 에러, 파이프 중간 단계가 실패해도 전체 실패로 간주
set -euo pipefail

# agent-app 동작에 필요한 환경 변수는 docker 가 주입한다 (Dockerfile ENV 또는 docker run -e).
for v in AGENT_HOME AGENT_PORT AGENT_UPLOAD_DIR AGENT_KEY_PATH AGENT_LOG_DIR AGENT_API_KEY AGENT_USER_PASSWORD; do
    [ -n "${!v:-}" ] || { echo "[entrypoint] ERROR: $v 환경변수가 필요합니다" >&2; exit 1; }
done

# ssh 설정

mkdir -p /etc/ssh/sshd_config.d
if [ ! -e /etc/ssh/sshd_config.d/10-agent.conf ]; then
  cat > /etc/ssh/sshd_config.d/10-agent.conf <<'EOF'
Port 20022
PermitRootLogin no
PasswordAuthentication yes
EOF
fi

# 기존에 있던 설정 주석처리
sed -i -E 's/^[#[:space:]]*Port[[:space:]]+22/#Port 22/' /etc/ssh/sshd_config || echo "[entrypoint] WARN: sed failed" >&2
sed -i -E 's/^[#[:space:]]*PermitRootLogin.*/#PermitRootLogin prohibit-password/' /etc/ssh/sshd_config || echo "[entrypoint] WARN: sed failed" >&2

service ssh start

# 방화벽 설정

ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw allow 20022/tcp
ufw allow "${AGENT_PORT}/tcp"
ufw --force enable || echo "[entrypoint] WARN: failed to enable ufw" >&2
ufw status verbose || true

# 그룹 설정/계정 생성

# 그룹이 이미 있어도 그냥 무시
groupadd -f agent-common
groupadd -f agent-core

for u in agent-admin agent-dev agent-test; do
    if ! id "$u" >/dev/null 2>&1; then
        useradd -m -s /bin/bash "$u"
        echo "$u:$AGENT_USER_PASSWORD" | chpasswd
    fi
done

# agent-common: admin, dev, test
usermod -aG agent-common agent-admin
usermod -aG agent-common agent-dev
usermod -aG agent-common agent-test

# agent-core: admin, dev
usermod -aG agent-core agent-admin
usermod -aG agent-core agent-dev

# 디렉토리/권한/ACL

# AGENT_KEY_PATH 는 api_keys 디렉토리. agent_app 바이너리가 이 안에서 secret.key 를 읽는다.
mkdir -p "$AGENT_HOME" "$AGENT_UPLOAD_DIR" "$AGENT_KEY_PATH" "$AGENT_HOME/bin" "$AGENT_LOG_DIR"

# AGENT_HOME 자체는 agent-admin 소유, 그룹 멤버가 진입 가능해야 함
chown -R agent-admin:agent-common "$AGENT_HOME"
chmod 750 "$AGENT_HOME"

# upload_files : agent-common R/W 공유 (setgid 로 그룹 상속)
chown agent-admin:agent-common "$AGENT_UPLOAD_DIR"
chmod 2770 "$AGENT_UPLOAD_DIR"

# api_keys : agent-core ONLY
chown agent-admin:agent-core "$AGENT_KEY_PATH"
chmod 2770 "$AGENT_KEY_PATH"

# log dir : agent-core ONLY
chown agent-admin:agent-core "$AGENT_LOG_DIR"
chmod 2770 "$AGENT_LOG_DIR"

# ACL부여

setfacl -m g:agent-common:rwx "$AGENT_UPLOAD_DIR"
setfacl -d -m g:agent-common:rwx "$AGENT_UPLOAD_DIR"

setfacl -m g:agent-core:rwx "$AGENT_KEY_PATH"
setfacl -d -m g:agent-core:rwx "$AGENT_KEY_PATH"
setfacl -m o::--- "$AGENT_KEY_PATH"

setfacl -m g:agent-core:rwx "$AGENT_LOG_DIR"
setfacl -d -m g:agent-core:rwx "$AGENT_LOG_DIR"
setfacl -m o::--- "$AGENT_LOG_DIR"

# 키 값도 docker 주입 환경변수에서 가져온다. (바이너리는 secret.key 를 요구)
KEY_FILE="$AGENT_KEY_PATH/secret.key"
printf '%s' "$AGENT_API_KEY" > "$KEY_FILE"
chown agent-admin:agent-core "$KEY_FILE"
chmod 640 "$KEY_FILE"

# monitor.sh 배치
# -m: mode, -o: owner, -g: group -d: 디렉터리 만들기
install -m 750 -o agent-dev -g agent-core \
    /opt/setup/monitor.sh "$AGENT_HOME/bin/monitor.sh"

install -d -m 700 -o agent-admin -g agent-admin "$AGENT_HOME/etc"

cat > "$AGENT_HOME/etc/agent.env" <<EOF
AGENT_HOME='$AGENT_HOME'
AGENT_PORT='$AGENT_PORT'
AGENT_UPLOAD_DIR='$AGENT_UPLOAD_DIR'
AGENT_KEY_PATH='$AGENT_KEY_PATH'
AGENT_LOG_DIR='$AGENT_LOG_DIR'
EOF

chown agent-admin:agent-admin "$AGENT_HOME/etc/agent.env"
chmod 600 "$AGENT_HOME/etc/agent.env"

CRON_LINE="* * * * * $AGENT_HOME/bin/monitor.sh $AGENT_HOME/etc/agent.env >> $AGENT_LOG_DIR/monitor.cron.log 2>&1"
echo "$CRON_LINE" | crontab -u agent-admin -

# monitor.log 회전은 logrotate 가 담당 (자체 회전 로직 제거)
cat > /etc/logrotate.d/agent-monitor <<EOF
$AGENT_LOG_DIR/monitor.log {
    size 10M
    rotate 10
    missingok
    notifempty
    copytruncate
    su agent-admin agent-core
}
EOF
chmod 644 /etc/logrotate.d/agent-monitor

service cron start

# agent_app 을 agent-admin 권한으로 포그라운드 실행 (= 컨테이너 PID 1)
# - exec 으로 띄워 PID 1 을 그대로 agent_app 에 넘겨 신호 처리/종료가 정상적으로 동작하게 함
# - runuser 는 부모 환경변수를 그대로 상속시키므로 docker 주입값이 그대로 전달됨
cd "$AGENT_HOME"
exec runuser -u agent-admin -- /opt/agent_app/bin/agent_app
