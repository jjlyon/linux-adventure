FROM ubuntu:24.04

ARG THEME=medieval

# Restore documentation and manual-page support in the Ubuntu base image.
# This keeps commands like `man cut` available for learners.
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

# Create quest user
RUN useradd -m -s /bin/bash traveler

# Install engine and theme
COPY engine/ /opt/shell-quest/engine/
COPY themes/${THEME}/ /opt/shell-quest/theme/

# Make engine scripts executable, symlink quest into PATH
RUN chmod +x /opt/shell-quest/engine/bin/* \
    && ln -s /opt/shell-quest/engine/bin/quest /usr/local/bin/quest

# Set up sudoers for permission quest (quest 6)
COPY docker/sudoers.d/quest-user /etc/sudoers.d/quest-user
RUN chmod 440 /etc/sudoers.d/quest-user

# Copy shell config
COPY docker/skel/.bashrc /home/traveler/.bashrc
COPY docker/skel/.profile /home/traveler/.profile
RUN chown traveler:traveler /home/traveler/.bashrc /home/traveler/.profile

# Entrypoint handles first-run init and permission setup
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /home/traveler
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash", "--login", "-i"]
