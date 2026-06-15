FROM ubuntu:24.04

RUN apt-get update
# iptables는 ufw의 Dependency이기 때문에 항상 같이 설치됨.
# no-install-recommends는 이미지 크기를 줄이기 위해 Recommends 패키지 설치를 막음
RUN apt-get install -y --no-install-recommends \
    mawk \
    grep \
    openssh-server \
    ufw \
    cron \
    acl \
    sudo \
    procps \
    iproute2 \
    logrotate \
    vim

RUN mkdir -p /run/sshd

# https://refspecs.linuxfoundation.org/FHS_3.0/fhs/ch03s13.html
RUN mkdir -p /opt/agent_app/bin
COPY agent-app/agent-app-linux-x86 /opt/agent_app/bin/agent_app
RUN chmod -R 755 /opt/agent_app

# entrypoint 가 install 로 옮길 원본 monitor.sh
RUN mkdir -p /opt/setup
COPY scripts/monitor.sh /opt/setup/monitor.sh
RUN chmod 755 /opt/setup/monitor.sh

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

