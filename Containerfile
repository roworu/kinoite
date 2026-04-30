ARG FEDORA_VERSION=43

FROM scratch AS ctx
COPY build_scripts /

###
### base plasma image
###
FROM ghcr.io/ublue-os/kinoite-main:${FEDORA_VERSION} AS kinoite
COPY system_files/base /

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/00-base.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/80-finilize.sh

RUN bootc container lint

###
### plasma-nvidia image
###
FROM ghcr.io/ublue-os/kinoite-main:${FEDORA_VERSION} AS kinoite-nvidia
COPY system_files/base /
COPY system_files/nvidia /

ARG INSTALL_NVIDIA="TRUE"
ENV INSTALL_NVIDIA=${INSTALL_NVIDIA}

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/00-base.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/80-finilize.sh

RUN bootc container lint
