FROM balenalib/jetson-nano-ubuntu:bionic-build as l4t

WORKDIR /usr/src/app

ADD Jetson-210_Linux_R32.3.1_aarch64.tbz2 .

RUN mkdir /opt/drivers \
    && tar xjf Linux_for_Tegra/nv_tegra/nvidia_drivers.tbz2 -C /opt/drivers \
    && tar xjf Linux_for_Tegra/nv_tegra/config.tbz2 --exclude=etc/hosts --exclude=etc/hostname -C /opt/drivers \
    && rm -rf Linux_for_Tegra

# ----------------------------------------------------------------------------

FROM balenalib/jetson-nano-ubuntu:bionic-build as ffmpeg

COPY --from=l4t /opt/drivers/ /

WORKDIR /usr/src/nvmpi

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    libegl1-mesa-dev=19.2.8-0ubuntu0~18.04.2 \
    cmake=3.10.2-1ubuntu2.18.04.1 \
    libx264-dev=2:0.152.2854+gite9a5903-2 \
    libx265-dev=2.6-3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && echo "/usr/lib/aarch64-linux-gnu/tegra" > /etc/ld.so.conf.d/nvidia-tegra.conf \
    && ldconfig \
    && git -c advice.detachedHead=false clone https://github.com/jocover/jetson-ffmpeg.git . \
    && sed 's|v4l2|libv4l2.so.0|' -i CMakeLists.txt

WORKDIR /usr/src/nvmpi/build

RUN cmake .. \
    && make \
    && make install \
    && ldconfig

WORKDIR /usr/src/ffmpeg

RUN git -c advice.detachedHead=false clone git://source.ffmpeg.org/ffmpeg.git -b release/4.2 --depth=1 . \
    && git apply /usr/src/nvmpi/ffmpeg_nvmpi.patch \
    && ./configure --enable-nvmpi --enable-nonfree --enable-openssl --enable-libx264 --enable-libx265 --enable-gpl --prefix=/opt/ffmpeg/usr \
    && make -j 8 \
    && make install

# ----------------------------------------------------------------------------

FROM balenalib/jetson-nano-ubuntu-node:12-bionic-build as shinobi

WORKDIR /opt/shinobi

ENV NODE_ENV production

RUN git clone https://gitlab.com/Shinobi-Systems/Shinobi.git --depth 1 . \
    && git -c advice.detachedHead=false checkout f1f32c4ee109836398776f35a1aa05f0e76972df \
    && npm install npm@latest -g \
    && npm install --unsafe-perm \
    && npm audit fix --force

# ----------------------------------------------------------------------------

FROM balenalib/jetson-nano-ubuntu-node:12-bionic as final

COPY --from=l4t /opt/drivers/ /
COPY --from=ffmpeg /usr/local/lib/libnvmpi.so* /usr/local/lib/
COPY --from=ffmpeg /opt/ffmpeg/ /
COPY --from=shinobi /opt/shinobi /opt/shinobi

ENV UDEV 1

ENV NODE_ENV production

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    mariadb-client=1:10.1.44-0ubuntu0.18.04.1 \
    libegl1-mesa-dev=19.2.8-0ubuntu0~18.04.2 \
    x264=2:0.152.2854+gite9a5903-2 \
    x265=2.6-3 \
    libxcb-shm0=1.13-2~ubuntu18.04 \
    jq=1.5+dfsg-2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && npm install npm@latest -g \
    && npm install pm2@3.0.0 -g \
    && echo "/usr/lib/aarch64-linux-gnu/tegra" > /etc/ld.so.conf.d/nvidia-tegra.conf \
    && ldconfig

WORKDIR /opt/shinobi

COPY entrypoint.sh pm2Shinobi.yml /opt/shinobi/

ENTRYPOINT ["/opt/shinobi/entrypoint.sh"]

CMD ["pm2-docker", "/opt/shinobi/pm2Shinobi.yml"]
# CMD [ "sleep", "infinity" ]
