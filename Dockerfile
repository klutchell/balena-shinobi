FROM balenalib/jetson-nano-ubuntu:bionic-build as drivers

WORKDIR /usr/src/app

ADD l4t-32.3.1/Jetson-210_Linux_R32.3.1_aarch64.tbz2 .

RUN mkdir /opt/drivers \
    && tar xjf Linux_for_Tegra/nv_tegra/nvidia_drivers.tbz2 -C /opt/drivers \
    && tar xjf Linux_for_Tegra/nv_tegra/config.tbz2 --exclude=etc/hosts --exclude=etc/hostname -C /opt/drivers \
    && rm -rf Linux_for_Tegra

# ----------------------------------------------------------------------------

FROM balenalib/jetson-nano-ubuntu:bionic-build as ffmpeg

WORKDIR /usr/src/app

COPY --from=drivers /opt/drivers/ /

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
    cuda-cublas-dev-10-0 \
    cuda-cudart-dev-10-0 \
    cuda-cufft-dev-10-0 \
    cuda-curand-dev-10-0 \
    cuda-cusolver-dev-10-0 \
    cuda-cusparse-dev-10-0 \
    cuda-driver-dev-10-0 \
    cuda-npp-dev-10-0 \
    cuda-nvcc-10-0 \
    cuda-nvgraph-dev-10-0 \
    cuda-nvrtc-dev-10-0 \
    libegl1-mesa-dev \
    libmp3lame-dev \
    libopus-dev \
    libtheora-dev \
    libvorbis-dev \
    libvpx-dev \
    libx264-dev \
    libx265-dev \
    && rm -rf ./*.deb \
    && dpkg --purge cuda-repo-l4t-10-0-local-10.0.326 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
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
    --enable-gpl \
    --enable-libmp3lame \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libvpx \
    --enable-libtheora \
    --enable-libvorbis \
    --enable-libopus \
    --enable-libfreetype \
    --disable-doc \
    --disable-debug \
    && make -j 8 \
    && make install \
    && rm -rf /usr/local/cuda-10.0/doc \
    && rm -rf /usr/local/cuda-10.0/samples \
    && rm -rf /usr/local/cuda-10.0/targets

# ----------------------------------------------------------------------------

FROM balenalib/jetson-nano-ubuntu-node:12-bionic-build as run

WORKDIR /opt/shinobi

COPY --from=drivers /opt/drivers/ /
COPY --from=ffmpeg /usr/local/cuda-10.0 /usr/local/cuda-10.0
COPY --from=ffmpeg /usr/lib/aarch64-linux-gnu/tegra* /usr/lib/aarch64-linux-gnu/
COPY --from=ffmpeg /usr/local/lib/libnvmpi* /usr/local/lib/
COPY --from=ffmpeg /opt/ffmpeg/ /

ENV UDEV 1
ENV PATH /usr/local/cuda-10.0/bin:${PATH}
ENV NODE_ENV production
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    jq \
    mariadb-client \
    libegl1-mesa \
    libxcb-shape0 \
    libmp3lame0 \
    libopus0 \
    libtheora0 \
    libvorbis0a \
    libvpx5 \
    x264 \
    x265 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && git clone https://gitlab.com/Shinobi-Systems/Shinobi.git . \
    && git -c advice.detachedHead=false checkout abd40e178a06512f8eec87591289903f79a59779 \
    && npm install npm@latest -g \
    && npm install pm2@3.0.0 -g \
    && npm install --unsafe-perm \
    && npm audit fix --force \
    && echo "/usr/lib/aarch64-linux-gnu/tegra" > /etc/ld.so.conf.d/nvidia-tegra.conf \
    && ldconfig

COPY entrypoint.sh pm2Shinobi.yml h264_nvmpi.patch cpu_usage.patch /opt/shinobi/

RUN git apply h264_nvmpi.patch \
    && git apply cpu_usage.patch

ENTRYPOINT ["/opt/shinobi/entrypoint.sh"]

CMD ["pm2-docker", "/opt/shinobi/pm2Shinobi.yml"]
