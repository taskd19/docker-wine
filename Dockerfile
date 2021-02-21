# [begin of base image]
# Build xrdp pulseaudio modules in builder container
# See https://github.com/neutrinolabs/pulseaudio-module-xrdp/wiki/README
ARG TAG=rolling
FROM ubuntu:$TAG as builder

RUN sed -i -E 's/^# deb-src /deb-src /g' /etc/apt/sources.list \
    && apt-get update \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
    build-essential \
    dpkg-dev \
    git \
    libpulse-dev \
    pulseaudio \
    && apt-get build-dep -y pulseaudio \
    && apt-get source pulseaudio \
    && rm -rf /var/lib/apt/lists/*

RUN cd /pulseaudio-$(pulseaudio --version | awk '{print $2}') \
    && ./configure

RUN git clone https://github.com/neutrinolabs/pulseaudio-module-xrdp.git /pulseaudio-module-xrdp \
    && cd /pulseaudio-module-xrdp \
    && ./bootstrap \
    && ./configure PULSE_DIR=/pulseaudio-$(pulseaudio --version | awk '{print $2}') \
    && make \
    && make install

# Build the final image
FROM ubuntu:$TAG

RUN apt-get update \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
    dbus-x11 \
    firefox \
    git \
    pavucontrol \
    pulseaudio \
    pulseaudio-utils \
    x11-xserver-utils \
    xfce4 \
    xfce4-goodies \
    xfce4-pulseaudio-plugin \
    xorgxrdp \
    xrdp \
    xubuntu-icon-theme \
    && rm -rf /var/lib/apt/lists/*

RUN sed -i -E 's/^; autospawn =.*/autospawn = yes/' /etc/pulse/client.conf \
    && [ -f /etc/pulse/client.conf.d/00-disable-autospawn.conf ] && sed -i -E 's/^(autospawn=.*)/# \1/' /etc/pulse/client.conf.d/00-disable-autospawn.conf || :

COPY --from=builder /usr/lib/pulse-*/modules/module-xrdp-sink.so /usr/lib/pulse-*/modules/module-xrdp-source.so /var/lib/xrdp-pulseaudio-installer/
# COPY entrypoint.sh /usr/bin/entrypoint
EXPOSE 3389/tcp
# ENTRYPOINT ["/usr/bin/entrypoint"]
# [end of base image]

# ARG BASE_IMAGE="scottyhardy/docker-remote-desktop"
# ARG TAG="latest"
# FROM ${BASE_IMAGE}:${TAG}

# Install prerequisites
RUN apt-get update \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    cabextract \
    git \
    gosu \
    gpg-agent \
    p7zip \
    pulseaudio \
    pulseaudio-utils \
    software-properties-common \
    tzdata \
    unzip \
    wget \
    winbind \
    xvfb \
    zenity \
    && rm -rf /var/lib/apt/lists/*

# Install wine
ARG WINE_BRANCH="stable"
RUN wget -nv -O- https://dl.winehq.org/wine-builds/winehq.key | APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add - \
    && apt-add-repository "deb https://dl.winehq.org/wine-builds/ubuntu/ $(grep VERSION_CODENAME= /etc/os-release | cut -d= -f2) main" \
    && dpkg --add-architecture i386 \
    && apt-get update \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y --install-recommends winehq-${WINE_BRANCH} \
    && rm -rf /var/lib/apt/lists/*

# Install winetricks
RUN wget -nv -O /usr/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
    && chmod +x /usr/bin/winetricks

# Download gecko and mono installers
COPY download_gecko_and_mono.sh /root/download_gecko_and_mono.sh
RUN chmod +x /root/download_gecko_and_mono.sh \
    && /root/download_gecko_and_mono.sh "$(dpkg -s wine-${WINE_BRANCH} | grep "^Version:\s" | awk '{print $2}' | sed -E 's/~.*$//')"

# [begin of japanese config]
RUN apt-get update \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
    language-pack-ja-base \
    language-pack-ja \
    fonts-takao \
    && rm -rf /var/lib/apt/lists/*
RUN update-locale LANG=ja_JP.UTF-8 LANGUAGE=ja_JP.UTF-8
# [end of japanese config]

COPY pulse-client.conf /root/pulse/client.conf
COPY entrypoint.sh /usr/bin/entrypoint
ENTRYPOINT ["/usr/bin/entrypoint"]
