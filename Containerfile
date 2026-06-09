ARG FEDORA_VERSION=44

FROM scratch AS ctx
COPY build_scripts /

###
### base plasma image
###
FROM ghcr.io/ublue-os/kinoite-main:${FEDORA_VERSION} AS kinoite
COPY system_files/base /

ARG TESTING_ENVIRONMENT="FALSE"

RUN if [ "${TESTING_ENVIRONMENT}" = "TRUE" ]; then \
    echo "That is testing image!" && \
    systemctl enable sshd.service && \
    echo "test_user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/test_user && \
    chmod 0440 /etc/sudoers.d/test_user; \
    fi

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

ENV INSTALL_NVIDIA="TRUE"

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
