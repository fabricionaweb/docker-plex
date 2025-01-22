# syntax=docker/dockerfile:1-labs
FROM public.ecr.aws/docker/library/ubuntu:22.04 AS base
ENV TZ=UTC DEBIAN_FRONTEND=noninteractive
WORKDIR /src

# source backend stage =========================================================
FROM base AS source-app

# get package
ARG TARGETARCH
ARG VERSION
ADD https://downloads.plex.tv/plex-media-server-new/$VERSION/debian/plexmediaserver_${VERSION}_${TARGETARCH}.deb ./plexmediaserver.deb

# build stage ==================================================================
FROM base AS build-app

# prepare s6
ARG S6_OVERLAY_VERSION=3.2.0.2
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-arch.tar.xz /tmp
RUN apt update && \
    apt install -y xz-utils && \
    mkdir /s6 && \
    ls /tmp/s6-overlay-*.tar.xz | xargs -n1 tar -C /s6 -Jxpf

# unpack package
COPY --from=source-app /src/plexmediaserver.deb ./
RUN dpkg-deb -x ./plexmediaserver.deb ./ && \
    mv ./usr/lib/plexmediaserver /build && \
    # small clean up
    rm -rf /build/etc /build/Resources/start.sh /build/lib/plexmediaserver.*

# runtime stage ================================================================
FROM base

ENV S6_VERBOSITY=0 S6_BEHAVIOUR_IF_STAGE2_FAILS=2 PUID=65534 PGID=65534
ENV PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR=/config
ENV PLEX_CLAIM=
WORKDIR /config
VOLUME /config
EXPOSE 32400

# copy files
COPY --from=build-app /s6/. /
COPY --from=build-app /build /app
COPY ./rootfs/. /

# runtime dependencies
RUN apt update && \
    apt install -y tzdata uuid-runtime curl && \
    rm -rf /var/lib/apt/lists/*

# run using s6-overlay
ENTRYPOINT ["/init"]
