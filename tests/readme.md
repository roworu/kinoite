# Functional / Integration Tests

Build checks alone are not enough to verify that an OS image actually works at runtime.

For example:
- Steam could crash on launch after an upstream regression
- a dependency update could break desktop startup
- Flatpak integration could silently stop working

Traditional build validation mainly confirms that:
- the image builds successfully
- dependencies resolve correctly
- packages install without conflicts

Fedora already provides strong guarantees in those areas. However, those checks do not validate the final integrated system behavior.

These tests add runtime validation for the produced image itself, helping catch regressions that only appear after boot.

Current coverage includes:
1. SSH connectivity and correct user context

2. CachyOS kernel is installed and present in the boot cmdline

3. Plasma desktop session
   - graphical.target is the default systemd target
   - display-manager.service is active
   - plasmalogin.service is active and selected as the display manager
   - Wayland session is running
   - Required plasma packages are installed

4. Flatpak functionality
   - flatpak command is available
   - remote add/remove works
   - application install/uninstall works

5. Basic CLI file operations (create, touch, test, rm, rmdir)

6. IPv4 network connectivity (outbound ping)

The long-term goal is to expand coverage for critical user workflows and common failure scenarios.