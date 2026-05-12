FROM ubuntu:24.04

RUN yes | unminimize

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    coreutils \
    findutils \
    grep \
    less \
    man-db \
    manpages \
    sudo \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash traveler

COPY engine/ /opt/quest-engine/engine/
COPY adventures/shell-quest/theme/ /opt/quest-engine/theme/

RUN chmod +x /opt/quest-engine/engine/bin/* \
    && ln -s /opt/quest-engine/engine/bin/quest /usr/local/bin/quest \
    && if [ -d /opt/quest-engine/theme/hooks ]; then chmod +x /opt/quest-engine/theme/hooks/*.sh 2>/dev/null || true; fi

COPY adventures/shell-quest/docker/sudoers.d/quest-user /etc/sudoers.d/quest-user
RUN chmod 440 /etc/sudoers.d/quest-user

COPY adventures/shell-quest/docker/skel/.bashrc /home/traveler/.bashrc
COPY adventures/shell-quest/docker/skel/.profile /home/traveler/.profile
RUN chown traveler:traveler /home/traveler/.bashrc /home/traveler/.profile

COPY adventures/shell-quest/docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /home/traveler
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash", "--login", "-i"]
