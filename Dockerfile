FROM ubuntu:24.04
ARG THEME=medieval
RUN apt-get update && apt-get install -y bash coreutils findutils grep less man-db manpages sudo gettext-base && rm -rf /var/lib/apt/lists/*
RUN useradd -m -s /bin/bash traveler
COPY engine /opt/shell-quest/engine
COPY themes/${THEME} /opt/shell-quest/theme
COPY docker/skel/.bashrc /home/traveler/.bashrc
COPY docker/skel/.profile /home/traveler/.profile
COPY docker/sudoers.d/quest-user /etc/sudoers.d/quest-user
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /opt/shell-quest/engine/bin/* \
    && chmod 440 /etc/sudoers.d/quest-user \
    && chown traveler:traveler /home/traveler/.bashrc /home/traveler/.profile
USER traveler
WORKDIR /home/traveler
ENTRYPOINT ["/entrypoint.sh"]
