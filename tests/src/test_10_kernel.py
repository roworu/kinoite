
def test_cachy_kernel(ssh_command):
    result = ssh_command("uname --kernel-release")
    assert result.returncode == 0, \
        f"Command returned bad returncode: {result.returncode}. Full response: {result}"

    assert result.stdout.strip() == "cachy", \
        f"Cachy kernel not used. Full response {result.stdout}"
