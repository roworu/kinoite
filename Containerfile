ARG FEDORA_VERSION=43

FROM scratch AS ctx
COPY build_scripts /

###
### base plasma image
###

FROM ghcr.io/ublue-os/kinoite-main:${FEDORA_VERSION} AS kinoite

COPY system_files/base /

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/var \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/00-base.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/30-plasma.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/90-finilize.sh

RUN bootc container lint

###
### plasma-nvidia desktop image
###

FROM ghcr.io/ublue-os/kinoite-nvidia:${FEDORA_VERSION} AS kinoite-nvidia

COPY system_files/base /

COPY --from=ghcr.io/ublue-os/akmods-nvidia-open:main-${FEDORA_VERSION}-x86_64 / /tmp/akmods-nvidia
RUN find /tmp/akmods-nvidia

RUN dnf5 -y copr enable bieszczaders/kernel-cachyos-lto "fedora-${FEDORA_VERSION}-x86_64" \
    dnf5 -y copr enable bieszczaders/kernel-cachyos-addons "fedora-${FEDORA_VERSION}-x86_64" \
    dnf5 -y config-manager setopt "*fedora*".exclude="kernel-core-* kernel-modules-* kernel-uki-virt-*" \
    dnf5 -y config-manager setopt "*updates*".exclude="kernel-core-* kernel-modules-* kernel-uki-virt-*" \
    dnf5 -y install zsh git \
    dnf5 -y remove --no-autoremove kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra \
    rm -rf /usr/lib/modules/* \
    rm -rf /boot/* \
    dnf5 -y install kernel-cachyos-lto kernel-cachyos-lto-core kernel-cachyos-lto-devel-matched kernel-cachyos-lto-modules \
    dnf5 versionlock add kernel-cachyos-lto kernel-cachyos-lto-core kernel-cachyos-lto-devel-matched kernel-cachyos-lto-modules \
    KERNEL_VERSION=$(ls /usr/lib/modules | head -n1) \
    akmods --force --kernels "${KERNEL_VERSION}" --kmod "nvidia"

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/30-plasma.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/90-finilize.sh

RUN bootc container lint
