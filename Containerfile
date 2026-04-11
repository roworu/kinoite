FROM scratch AS ctx
COPY build_scripts /

###
### base plasma image
###
FROM ghcr.io/ublue-os/kinoite-main:43 AS kinoite
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
    /ctx/90-finilize.sh

RUN bootc container lint

###
### plasma-nvidia desktop image
###
FROM ghcr.io/ublue-os/kinoite-nvidia:43 AS kinoite-nvidia
#COPY --from=ghcr.io/ublue-os/akmods-nvidia-open:main-43-x86_64 / /tmp/akmods-nvidia
#RUN find /tmp/akmods-nvidia

COPY system_files/base /

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/00-base-nvidia.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/90-finilize.sh

RUN bootc container lint
