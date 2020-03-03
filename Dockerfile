FROM balenalib/jetson-nano-ubuntu:bionic-build as drivers

WORKDIR /usr/src/app

ADD l4t-32.3.1/Jetson-210_Linux_R32.3.1_aarch64.tbz2 .

RUN mkdir /opt/drivers \
    && tar xjf Linux_for_Tegra/nv_tegra/nvidia_drivers.tbz2 -C /opt/drivers \
    && tar xjf Linux_for_Tegra/nv_tegra/config.tbz2 --exclude=etc/hosts --exclude=etc/hostname -C /opt/drivers \
    && rm -rf Linux_for_Tegra

# ----------------------------------------------------------------------------

FROM balenalib/jetson-nano-ubuntu:bionic-build as cuda

WORKDIR /usr/src/app

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
    cuda-compiler-10-0 \
    cuda-samples-10-0 \
    && rm -rf ./*.deb \
    && dpkg --purge cuda-repo-l4t-10-0-local-10.0.326 \
    && rm -rf /usr/local/cuda-10.0/doc \
    && rm -rf /usr/local/cuda-10.0/samples
    # && rm -rf /usr/local/cuda-10.0/targets

# ----------------------------------------------------------------------------

# FROM balenalib/jetson-nano-ubuntu:bionic-build as nvmpi

# WORKDIR /usr/src/app

# COPY --from=drivers /opt/drivers/ /
# COPY --from=cuda /usr/local/cuda-10.0 /usr/local/cuda-10.0
# COPY --from=cuda /usr/lib/aarch64-linux-gnu /usr/lib/aarch64-linux-gnu
# COPY --from=cuda /usr/local/lib /usr/local/lib

# ENV PATH /usr/local/cuda-10.0/bin:${PATH}
# RUN echo "/usr/lib/aarch64-linux-gnu/tegra" > /etc/ld.so.conf.d/nvidia-tegra.conf \
#     && ldconfig

# ENV DEBIAN_FRONTEND noninteractive

# RUN apt-get update \
#     && apt-get install --no-install-recommends -y cmake \
#     && apt-get clean \
#     && rm -rf /var/lib/apt/lists/* \
#     && git -c advice.detachedHead=false clone https://github.com/jocover/jetson-ffmpeg.git . \
#     && sed 's|v4l2|libv4l2.so.0|' -i CMakeLists.txt

# WORKDIR /usr/src/app/build

# RUN cmake .. \
#     && make \
#     && make install \
#     && ldconfig

# RUN git -c advice.detachedHead=false clone git://source.ffmpeg.org/ffmpeg.git -b release/4.2 --depth 1 . \
#     && wget https://github.com/jocover/jetson-ffmpeg/raw/master/ffmpeg_nvmpi.patch \
#     && git apply ffmpeg_nvmpi.patch \
#     && ./configure \
#     --prefix=/opt/ffmpeg/usr \
#     --enable-nvmpi \
#     --enable-nonfree \
#     && make -j 8 \
#     && make install

# ----------------------------------------------------------------------------

FROM balenalib/jetson-nano-ubuntu:bionic-build as ffmpeg

WORKDIR /usr/src/app

COPY --from=drivers /opt/drivers/ /
COPY --from=cuda /usr/local/cuda-10.0 /usr/local/cuda-10.0
COPY --from=cuda /usr/lib/aarch64-linux-gnu /usr/lib/aarch64-linux-gnu
COPY --from=cuda /usr/local/lib /usr/local/lib
# COPY --from=nvmpi /usr/local/lib/libnvmpi* /usr/local/lib/

ENV PATH /usr/local/cuda-10.0/bin:${PATH}
RUN echo "/usr/lib/aarch64-linux-gnu/tegra" > /etc/ld.so.conf.d/nvidia-tegra.conf \
    && ldconfig

RUN git -c advice.detachedHead=false clone https://git.ffmpeg.org/ffmpeg.git -b release/4.2 --depth 1 . \
    && ./configure \
    # --pkg-config-flags=--static \
    # --extra-libs=-static \
    # --extra-cflags=--static \
    --extra-cflags=-I/usr/local/cuda-10.0/include \
    --extra-ldflags=-L/usr/local/cuda-10.0/lib64 \
    --prefix=/opt/ffmpeg/usr \
    --enable-cuda-nvcc \
    --enable-nonfree \
    --enable-libnpp \
    --enable-openssl \
    && make -j 8 \
    && make install

# ----------------------------------------------------------------------------

FROM balenalib/jetson-nano-ubuntu-node:12-bionic-build as shinobi

WORKDIR /usr/src/app

ENV NODE_ENV production

RUN git clone https://gitlab.com/Shinobi-Systems/Shinobi.git --depth 1 . \
    && git -c advice.detachedHead=false checkout f1f32c4ee109836398776f35a1aa05f0e76972df \
    && npm install npm@latest -g \
    && npm install --unsafe-perm \
    && npm audit fix --force

# ----------------------------------------------------------------------------

FROM balenalib/jetson-nano-ubuntu-node:12-bionic as final

WORKDIR /opt/shinobi

COPY --from=drivers /opt/drivers/ /
COPY --from=cuda /usr/local/cuda-10.0 /usr/local/cuda-10.0
COPY --from=cuda /usr/lib/aarch64-linux-gnu /usr/lib/aarch64-linux-gnu
COPY --from=cuda /usr/local/lib /usr/local/lib
# COPY --from=nvmpi /usr/local/lib/libnvmpi* /usr/local/lib/
COPY --from=ffmpeg /opt/ffmpeg/ /
COPY --from=shinobi /usr/src/app /opt/shinobi
COPY entrypoint.sh pm2Shinobi.yml /opt/shinobi/

ENV UDEV 1
ENV NODE_ENV production
ENV DEBIAN_FRONTEND noninteractive
ENV PATH /usr/local/cuda-10.0/bin:${PATH}

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    jq \
    mariadb-client \
    libbsd0 \
    # libegl1-mesa \
    # libxcb-shm0 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && npm install npm@latest -g \
    && npm install pm2@3.0.0 -g \
    && echo "/usr/lib/aarch64-linux-gnu/tegra" > /etc/ld.so.conf.d/nvidia-tegra.conf \
    && ldconfig \
    && rm -rf /usr/local/cuda-10.0/doc \
    && rm -rf /usr/local/cuda-10.0/samples \
    && rm -rf /usr/local/cuda-10.0/targets

ENTRYPOINT ["/opt/shinobi/entrypoint.sh"]

CMD ["pm2-docker", "/opt/shinobi/pm2Shinobi.yml"]

RUN ffmpeg -version