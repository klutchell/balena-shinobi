
FROM balenalib/jetson-nano-ubuntu-node:12-bionic-build as run

WORKDIR /opt/shinobi

ENV NODE_ENV production
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    jq mariadb-client ffmpeg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && git clone https://gitlab.com/Shinobi-Systems/Shinobi.git . \
    && git -c advice.detachedHead=false checkout abd40e178a06512f8eec87591289903f79a59779 \
    && npm install npm@latest -g \
    && npm install pm2@3.0.0 -g \
    && npm install --unsafe-perm \
    && npm audit fix --force \
    && wget https://gitlab.com/Shinobi-Systems/Shinobi/-/commit/fb3a0300129f41d7d16c7f598f22e8d67c1fdc46.diff \
    && git apply fb3a0300129f41d7d16c7f598f22e8d67c1fdc46.diff \
    && wget https://gitlab.com/Shinobi-Systems/Shinobi/-/commit/294c6f7e29ff7f09b91bb35128711c76986da23a.diff \
    && git apply 294c6f7e29ff7f09b91bb35128711c76986da23a.diff

COPY entrypoint.sh pm2Shinobi.yml /opt/shinobi/

ENTRYPOINT ["/opt/shinobi/entrypoint.sh"]

CMD ["pm2-docker", "/opt/shinobi/pm2Shinobi.yml"]
