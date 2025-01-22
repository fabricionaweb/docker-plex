# syntax=docker/dockerfile:1-labs
FROM public.ecr.aws/docker/library/alpine:3.21 AS base
ENV TZ=UTC
WORKDIR /src

# source backend stage =========================================================
FROM base AS source-app

# get and extract source from git
ARG TARGETARCH
ARG VERSION
ADD https://downloads.plex.tv/plex-media-server-new/$VERSION/debian/plexmediaserver_${VERSION}_${TARGETARCH}.deb ./plexmediaserver.deb

# build stage ==================================================================
FROM base AS build-app

# dependencies
RUN apk add --no-cache dpkg binutils

# unpack
COPY --from=source-app /src/plexmediaserver.deb ./
RUN dpkg-deb -x ./plexmediaserver.deb ./ && \
    mv ./usr/lib/plexmediaserver /build && \
    # the same file
    ln -sf ld-musl-$(uname -m).so.1 /build/lib/libc.so && \
    # small clean up
    rm -rf /build/etc /build/Resources/start.sh /build/lib/plexmediaserver.* && \
    strip /build/Plex* /build/CrashUploader

# runtime stage ================================================================
FROM base

ENV S6_VERBOSITY=0 S6_BEHAVIOUR_IF_STAGE2_FAILS=2 PUID=65534 PGID=65534
ENV PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR=/config
ENV PLEX_CLAIM=
WORKDIR /config
VOLUME /config
EXPOSE 32400

# copy files
COPY --from=build-app /build /app
COPY ./rootfs/. /

# runtime dependencies
RUN apk add --no-cache tzdata s6-overlay uuidgen bash curl

# run using s6-overlay
ENTRYPOINT ["/init"]
