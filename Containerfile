### determine current fedora version:
ARG FEDORA_VERSION=44

FROM scratch AS ctx
COPY build_scripts /


###
### overrides shared by both flavors
###

FROM ghcr.io/ublue-os/brew:latest AS brew
FROM scratch AS overrides
COPY system_files/base /
COPY cosign.pub /etc/pki/containers/kinoite.pub
# pre-built Linuxbrew prefix from ublue
COPY --from=brew /system_files/usr/share/homebrew.tar.zst /usr/share/homebrew.tar.zst
# one-shot systemd unit to unpack homebrew.tar.zst
COPY --from=brew /system_files/usr/lib/systemd/system/brew-setup.service /usr/lib/systemd/system/brew-setup.service
# add brew packages to PATH
COPY --from=brew /system_files/etc/profile.d/brew.sh /etc/profile.d/brew.sh
# bash completions
COPY --from=brew /system_files/etc/profile.d/brew-bash-completion.sh /etc/profile.d/brew-bash-completion.sh
# fish completions
COPY --from=brew /system_files/usr/share/fish/vendor_conf.d/ublue-brew.fish /usr/share/fish/vendor_conf.d/ublue-brew.fish

###
### base plasma image
###
FROM quay.io/fedora-ostree-desktops/kinoite:${FEDORA_VERSION} AS kinoite
COPY --from=overrides / /

ARG TESTING_ENVIRONMENT="FALSE"
ARG IMAGE_VERSION=""

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
    /ctx/50-brew.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/60-updates.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/70-fonts.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/75-tailscale.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    IMAGE_VERSION="${IMAGE_VERSION}" /ctx/80-finilize.sh

RUN bootc container lint

###
### plasma-nvidia image
###
FROM quay.io/fedora-ostree-desktops/kinoite:${FEDORA_VERSION} AS kinoite-nvidia
COPY --from=overrides / /
COPY system_files/nvidia /

ARG TESTING_ENVIRONMENT="FALSE"
ARG IMAGE_VERSION=""

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

COPY system_files/nvidia /

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/50-brew.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/60-updates.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/70-fonts.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/75-tailscale.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    IMAGE_VERSION="${IMAGE_VERSION}" /ctx/80-finilize.sh

RUN bootc container lint
