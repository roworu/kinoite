EXPECTED_XDG_DIRS = (
    "Desktop",
    "Documents",
    "Downloads",
    "Music",
    "Pictures",
    "Public",
    "Templates",
    "Videos",
)

PLASMA_PACKAGES = (
    "plasma-desktop",
    "plasma-workspace",
    "sddm",
    "xdg-user-dirs",
)


def test_graphical_target_is_default(ssh_command):
    result = ssh_command("systemctl get-default")
    assert result.returncode == 0, \
        f"Command returned bad returncode: {result.returncode}. Full response: {result}"

    assert result.stdout.strip() == "graphical.target", \
        f"Graphical.target not found as systemctl default. Full response {result.stdout}"


def test_display_manager_is_active(ssh_command):
    result = ssh_command("systemctl is-active display-manager.service")
    actual_state = result.stdout.strip()

    assert result.returncode == 0, \
        f"Command returned bad returncode: {result.returncode}. Full response: {result}"

    assert actual_state == "active", \
        f"display-manager.service expected to be active, actual state: {actual_state}. Full response: {result.stdout}"


def test_sddm_is_active(ssh_command):
    result = ssh_command("systemctl is-active sddm.service")
    actual_state = result.stdout.strip()

    assert result.returncode == 0, \
        f"Command returned bad returncode: {result.returncode}. Full response: {result}"

    assert actual_state == "active", \
        f"sddm.service expected to be active, actual state: {actual_state}. Full response: {result.stdout}"


def test_sddm_is_selected_display_manager(ssh_command):
    result = ssh_command("readlink -f /etc/systemd/system/display-manager.service")
    actual_unit = result.stdout.strip()

    assert result.returncode == 0, \
        f"Command returned bad returncode: {result.returncode}. Full response: {result}"

    assert actual_unit.endswith("/sddm.service"), \
        f"display-manager.service expected to point to sddm.service, actual target: {actual_unit}"


def test_plasma_desktop_packages_installed(ssh_command):
    packages = " ".join(PLASMA_PACKAGES)
    result = ssh_command(f"rpm -q {packages}")

    assert result.returncode == 0, \
        f"Expected Plasma packages to be installed: {packages}. Missing package details: {result.stdout}{result.stderr}"


def test_xdg_user_dirs_exist(ssh_command):
    dirs = " ".join(EXPECTED_XDG_DIRS)
    result = ssh_command(
        f"missing=0; for dir in {dirs}; do "
        f"if ! test -d \"$HOME/$dir\"; then "
        f"printf 'missing xdg dir: %s\\n' \"$dir\"; missing=1; "
        f"fi; "
        f"done; "
        f"exit \"$missing\""
    )

    assert result.returncode == 0, \
        f"Expected XDG user directories to exist: {dirs}. Missing directories: {result.stdout}"
