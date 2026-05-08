FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    less \
    sudo \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash traveler

COPY engine/ /opt/quest-engine/engine/
COPY adventures/code-quest/theme/ /opt/quest-engine/theme/

RUN chmod +x /opt/quest-engine/engine/bin/* \
    && ln -s /opt/quest-engine/engine/bin/quest /usr/local/bin/quest \
    && if [ -d /opt/quest-engine/theme/hooks ]; then chmod +x /opt/quest-engine/theme/hooks/*.sh 2>/dev/null || true; fi

COPY adventures/code-quest/docker/skel/.bashrc /home/traveler/.bashrc
COPY adventures/code-quest/docker/skel/.profile /home/traveler/.profile
RUN chown traveler:traveler /home/traveler/.bashrc /home/traveler/.profile

COPY adventures/code-quest/docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN mkdir -p /home/traveler/project && chown traveler:traveler /home/traveler/project

EXPOSE 5173

WORKDIR /home/traveler
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash", "--login", "-i"]
