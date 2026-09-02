from defaults import KERNEL_VERSION


def test_kernel(ssh_command):

    result = ssh_command("uname --kernel-release")
    cmdline = result.stdout.strip()
    assert KERNEL_VERSION in cmdline, (
        f"{KERNEL_VERSION} kernel not used. Full response {result.stdout}"
    )

    result = ssh_command("cat /proc/cmdline")
    cmdline = result.stdout.strip()
    assert KERNEL_VERSION in cmdline, f"Kernel not mentioned in boot cmdline: {cmdline}"


def test_kernel_versionlock(ssh_command):
    result = ssh_command("dnf5 versionlock list")
    assert "kernel-cachyos-lto" in result.stdout, (
        f"expected kernel-cachyos-lto to be versionlocked, actual: {result.stdout}"
    )
