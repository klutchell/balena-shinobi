
FROM balenalib/jetson-nano-ubuntu-node:12-bionic-build

WORKDIR /opt/shinobi

ENV NODE_ENV production
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    jq mariadb-client ffmpeg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && git clone https://gitlab.com/Shinobi-Systems/Shinobi.git . \
    && git -c advice.detachedHead=false checkout c2b393b86de5511d6d2d60dfe5548fe0f2889793 \
    && npm install npm@latest -g \
    && npm install pm2@3.0.0 -g \
    && npm install --unsafe-perm

COPY entrypoint.sh pm2Shinobi.yml /opt/shinobi/

ENTRYPOINT ["/opt/shinobi/entrypoint.sh"]

CMD ["pm2-docker", "/opt/shinobi/pm2Shinobi.yml"]
