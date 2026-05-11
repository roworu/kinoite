# ublue kinoite image + cachyos kernel


### install
to use it firstly install fedora kinoite, and switch to unsigned image first:

```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/roworu/kinoite
```

and then after reboot switch to signed version:
```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/roworu/kinoite
```

#### nvidia
for nvidia version, use nvidia image name:

```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/roworu/kinoite-nvidia
```

reboot, and then:
```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/roworu/kinoite-nvidia
```