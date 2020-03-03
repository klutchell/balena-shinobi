FROM balenalib/jetson-nano-ubuntu:bionic-build as build

WORKDIR /usr/src/app

ADD l4t-32.3.1/Jetson-210_Linux_R32.3.1_aarch64.tbz2 .
COPY l4t-32.3.1/cuda-repo-l4t-10-0-local-10.0.326_1.0-1_arm64.deb .
COPY l4t-32.3.1/libcudnn7_7.6.3.28-1+cuda10.0_arm64.deb .
COPY l4t-32.3.1/libcudnn7-dev_7.6.3.28-1+cuda10.0_arm64.deb .

ENV DEBIAN_FRONTEND noninteractive

RUN dpkg -i \
    cuda-repo-l4t-10-0-local-10.0.326_1.0-1_arm64.deb \
    libcudnn7_7.6.3.28-1+cuda10.0_arm64.deb \
    libcudnn7-dev_7.6.3.28-1+cuda10.0_arm64.deb \
    && apt-key add /var/cuda-repo-10-0-local-10.0.326/*.pub \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
    cmake \
    cuda-compiler-10-0 \
    cuda-samples-10-0 \
    # cuda-npp-dev-10-0 \
    # cuda-nvcc-10-0 \
    libegl1-mesa-dev \
    && rm -rf ./*.deb \
    && dpkg --purge cuda-repo-l4t-10-0-local-10.0.326 \
    && mkdir /opt/drivers \
    && tar xjf Linux_for_Tegra/nv_tegra/nvidia_drivers.tbz2 -C /opt/drivers \
    && tar xjf Linux_for_Tegra/nv_tegra/config.tbz2 --exclude=etc/hosts --exclude=etc/hostname -C /opt/drivers \
    && rm -rf Linux_for_Tegra \
    && echo "/usr/lib/aarch64-linux-gnu/tegra" > /etc/ld.so.conf.d/nvidia-tegra.conf \
    && ldconfig

ENV PATH /usr/local/cuda-10.0/bin:${PATH}

WORKDIR /usr/src/nvmpi

RUN git -c advice.detachedHead=false clone https://github.com/jocover/jetson-ffmpeg.git . \
    && sed 's|v4l2|libv4l2.so.0|' -i CMakeLists.txt

WORKDIR /usr/src/nvmpi/build

RUN cmake .. \
    && make \
    && make install \
    && ldconfig

WORKDIR /usr/src/ffmpeg

RUN git -c advice.detachedHead=false clone https://git.ffmpeg.org/ffmpeg.git -b release/4.2 --depth 1 . \
    && git apply /usr/src/nvmpi/ffmpeg_nvmpi.patch \
    && ./configure \
    --extra-cflags=-I/usr/local/cuda-10.0/include \
    --extra-ldflags=-L/usr/local/cuda-10.0/lib64 \
    --prefix=/opt/ffmpeg/usr \
    --enable-cuda-nvcc \
    --enable-nonfree \
    --enable-libnpp \
    --enable-openssl \
    --enable-nvmpi \
    && make -j 8 \
    && make install \
    && rm -rf /usr/local/cuda-10.0/doc \
    && rm -rf /usr/local/cuda-10.0/samples \
    && rm -rf /usr/local/cuda-10.0/targets

# ----------------------------------------------------------------------------

FROM balenalib/jetson-nano-ubuntu-node:12-bionic-build as run

WORKDIR /opt/shinobi

COPY --from=build /opt/drivers/ /
COPY --from=build /usr/local/cuda-10.0 /usr/local/cuda-10.0
COPY --from=build /usr/lib/aarch64-linux-gnu /usr/lib/aarch64-linux-gnu
COPY --from=build /usr/local/lib /usr/local/lib
COPY --from=build /opt/ffmpeg/ /
COPY --from=build /usr/local/lib/libnvmpi* /usr/local/lib/

ENV UDEV 1
ENV PATH /usr/local/cuda-10.0/bin:${PATH}
ENV NODE_ENV production
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    # ffmpeg \
    jq \
    mariadb-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && git clone https://gitlab.com/Shinobi-Systems/Shinobi.git --depth 1 . \
    && git -c advice.detachedHead=false checkout f1f32c4ee109836398776f35a1aa05f0e76972df \
    && npm install npm@latest -g \
    && npm install pm2@3.0.0 -g \
    && npm install --unsafe-perm \
    && npm audit fix --force

COPY entrypoint.sh pm2Shinobi.yml /opt/shinobi/

ENTRYPOINT ["/opt/shinobi/entrypoint.sh"]

CMD ["pm2-docker", "/opt/shinobi/pm2Shinobi.yml"]
