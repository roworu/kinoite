
#def test_ipv4_connectivity(ssh_command):
#    ssh_command("ping 8.8.8.8 -c 3 -4")


def test_flatpak_available(ssh_command):
    ssh_command("flatpak --version")


def test_flatpak_remote_management(ssh_command):

    # add/delete test
    ssh_command(
            "sudo flatpak remote-add --if-not-exists test-flathub https://dl.flathub.org/repo/flathub.flatpakrepo"
    )
    ssh_command(
        "flatpak remotes | grep test-flathub"
    )
    ssh_command(
        "sudo flatpak remote-delete test-flathub"
    )


def test_flatpak_app_management(ssh_command):

    ssh_command(
            "sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo"
    )
    ssh_command(
        "flatpak remotes | grep flathub"
    )

    app = "org.kde.okular"

    ssh_command(
        f"flatpak install --user --assumeyes flathub {app}"
    )
    ssh_command(
        f"flatpak list | grep {app}"
    )
    ssh_command(
        f"flatpak uninstall -y {app}"
    )


def test_basic_cli_file_operations(ssh_command):

    ssh_command(
        (
            "mkdir -p /tmp/test-dir && "
            "touch /tmp/test-dir/test-file && "
            "test -f /tmp/test-dir/test-file && "
            "rm -f /tmp/test-dir/test-file && "
            "rmdir /tmp/test-dir"
        )
    )