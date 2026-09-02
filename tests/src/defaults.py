PLASMA_DE_PACKAGES = [
    "plasma-desktop",
    "plasma-workspace",
    "plasma-login-manager",
    "xdg-user-dirs",
    "dolphin",
    "konsole",
    "kde-settings",
]

KERNEL_VERSION = "cachy"
TEST_USER = "test_user"

# a sample of build_scripts/00-base.sh's packages_to_remove -- not exhaustive,
# just enough to catch a regression where the removal step silently no-ops
REMOVED_PACKAGES_SAMPLE = [
    "firefox",
    "kmines",
    "kdeconnect",
    "k3b",
]
