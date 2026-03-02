# pkg-audit: audit log for system package management commands
set -g _pkg_audit_version 0.1.0

function _pkg_audit_postexec --on-event fish_postexec
    # Capture status immediately — any command we run overwrites it
    set -l exit_code $status

    # Only log successful commands
    test $exit_code -eq 0; or return

    # Skip if no matchers loaded
    if test (count $_pkg_audit_sorted_indices) -eq 0
        return
    end

    # Check if command matches any pattern
    if _pkg_audit_match "$argv"
        _pkg_audit_log $_pkg_audit_last_match_name $_pkg_audit_last_match_event "$argv"
    end
end

function _pkg_audit_install --on-event pkg_audit_install
    # Write default config if it doesn't already exist
    set -l conf $__fish_config_dir/pkg_audit.conf
    if not test -f $conf
        echo "\
# pkg-audit matcher configuration
# Format: source-name  'matcher'  weight  event
#
# event is one of: install, remove, upgrade, other
# Lines are eval'd by fish — \$variables, (commands), and ~ are expanded.
# Matcher types (detected by convention):
#   ^pattern  → fish regex (string match -rq)
#   /path     → fish script file (must define pkg_audit_match function)
#   name      → fish function name (called with command line as \$argv)
#
# When multiple matchers match, highest weight wins.
# The event field is optional — defaults to 'other' if omitted.
# Drop extra configs in ~/.config/fish/pkg_audit.d/*.conf

# --- Debian / Ubuntu ---
apt       '^(sudo\s+)?apt\s+install\b'                                    1  install
apt       '^(sudo\s+)?apt\s+(remove|purge|autoremove)\b'                  1  remove
apt       '^(sudo\s+)?apt\s+(upgrade|full-upgrade|dist-upgrade)\b'        1  upgrade
apt-get   '^(sudo\s+)?apt-get\s+install\b'                                5  install
apt-get   '^(sudo\s+)?apt-get\s+(remove|purge|autoremove)\b'              5  remove
apt-get   '^(sudo\s+)?apt-get\s+(upgrade|dist-upgrade)\b'                 5  upgrade
dpkg      '^(sudo\s+)?dpkg\s+-(i|-install)\b'                             1  install
dpkg      '^(sudo\s+)?dpkg\s+-(r|P|-remove|-purge)\b'                     1  remove
dpkg      '^(sudo\s+)?dpkg\s+--configure\b'                               1  other

# --- Snap / Flatpak ---
snap      '^(sudo\s+)?snap\s+install\b'                                   1  install
snap      '^(sudo\s+)?snap\s+remove\b'                                    1  remove
snap      '^(sudo\s+)?snap\s+refresh\b'                                   1  upgrade
snap      '^(sudo\s+)?snap\s+(revert|enable|disable)\b'                   1  other
flatpak   '^(sudo\s+)?flatpak\s+install\b'                                1  install
flatpak   '^(sudo\s+)?flatpak\s+uninstall\b'                              1  remove
flatpak   '^(sudo\s+)?flatpak\s+update\b'                                 1  upgrade

# --- Arch ---
pacman    '^(sudo\s+)?pacman\s+-(S|U)\b'                                  1  install
pacman    '^(sudo\s+)?pacman\s+-R\b'                                      1  remove
yay       '^yay\s+-(S|U)\b'                                               1  install
yay       '^yay\s+-R\b'                                                   1  remove
paru      '^paru\s+-(S|U)\b'                                              1  install
paru      '^paru\s+-R\b'                                                  1  remove

# --- Fedora / RHEL ---
dnf       '^(sudo\s+)?dnf\s+(install|reinstall)\b'                        1  install
dnf       '^(sudo\s+)?dnf\s+(remove|autoremove)\b'                        1  remove
dnf       '^(sudo\s+)?dnf\s+(upgrade|downgrade)\b'                        1  upgrade
yum       '^(sudo\s+)?yum\s+(install|reinstall)\b'                        1  install
yum       '^(sudo\s+)?yum\s+(remove|autoremove)\b'                        1  remove
yum       '^(sudo\s+)?yum\s+(update|downgrade)\b'                         1  upgrade

# --- openSUSE ---
zypper    '^(sudo\s+)?zypper\s+install\b'                                 1  install
zypper    '^(sudo\s+)?zypper\s+remove\b'                                  1  remove
zypper    '^(sudo\s+)?zypper\s+(update|dist-upgrade|patch)\b'             1  upgrade

# --- Alpine ---
apk       '^(sudo\s+)?apk\s+add\b'                                        1  install
apk       '^(sudo\s+)?apk\s+del\b'                                        1  remove
apk       '^(sudo\s+)?apk\s+upgrade\b'                                    1  upgrade

# --- Nix ---
nix       '^nix\s+profile\s+install\b'                                    1  install
nix       '^nix\s+profile\s+remove\b'                                     1  remove
nix       '^nix\s+(shell|run|build)\b'                                    1  other
nix-env   '^nix-env\s+-(i|iA|-install)\b'                                 1  install
nix-env   '^nix-env\s+-(e|-uninstall)\b'                                  1  remove
nix-env   '^nix-env\s+-(u|-upgrade)\b'                                    1  upgrade

# --- Homebrew ---
brew      '^brew\s+(install|reinstall)\b'                                  1  install
brew      '^brew\s+uninstall\b'                                           1  remove
brew      '^brew\s+upgrade\b'                                             1  upgrade

# --- Rust ---
rustup    '^rustup\s+toolchain\s+install\b'                               1  install
rustup    '^rustup\s+toolchain\s+uninstall\b'                             1  remove
rustup    '^rustup\s+component\s+add\b'                                   1  install
rustup    '^rustup\s+component\s+remove\b'                                1  remove
rustup    '^rustup\s+(update|self\s+update)\b'                            1  upgrade
cargo     '^cargo\s+install\b'                                            1  install
cargo     '^cargo\s+uninstall\b'                                          1  remove

# --- Node.js ---
npm       '^(sudo\s+)?npm\s+install\s+(-g|--global)\b'                    1  install
npm       '^(sudo\s+)?npm\s+uninstall\s+(-g|--global)\b'                  1  remove
npm       '^(sudo\s+)?npm\s+update\s+(-g|--global)\b'                     1  upgrade
npm       '^(sudo\s+)?npm\s+(-g|--global)\s+install\b'                    2  install
npm       '^(sudo\s+)?npm\s+(-g|--global)\s+uninstall\b'                  2  remove
npm       '^(sudo\s+)?npm\s+(-g|--global)\s+update\b'                     2  upgrade
pnpm      '^(sudo\s+)?pnpm\s+add\s+(-g|--global)\b'                       1  install
pnpm      '^(sudo\s+)?pnpm\s+remove\s+(-g|--global)\b'                    1  remove
pnpm      '^(sudo\s+)?pnpm\s+update\s+(-g|--global)\b'                    1  upgrade
pnpm      '^(sudo\s+)?pnpm\s+(-g|--global)\s+add\b'                       2  install
pnpm      '^(sudo\s+)?pnpm\s+(-g|--global)\s+remove\b'                    2  remove
pnpm      '^(sudo\s+)?pnpm\s+(-g|--global)\s+update\b'                    2  upgrade
yarn      '^yarn\s+global\s+add\b'                                        1  install
yarn      '^yarn\s+global\s+remove\b'                                     1  remove
yarn      '^yarn\s+global\s+upgrade\b'                                    1  upgrade
bun       '^(sudo\s+)?bun\s+(install|add)\s+(-g|--global)\b'              1  install
bun       '^(sudo\s+)?bun\s+remove\s+(-g|--global)\b'                     1  remove
bun       '^(sudo\s+)?bun\s+(-g|--global)\s+(install|add)\b'              2  install
bun       '^(sudo\s+)?bun\s+(-g|--global)\s+remove\b'                     2  remove

# --- Python ---
pip       '^(sudo\s+)?pip3?\s+install\b'                                  1  install
uv        '^uv\s+(tool\s+install|pip\s+install)\b'                        1  install
uv        '^uv\s+(tool\s+uninstall|pip\s+uninstall)\b'                    1  remove
pipx      '^pipx\s+(install|reinstall)\b'                                  1  install
pipx      '^pipx\s+uninstall\b'                                           1  remove
pipx      '^pipx\s+upgrade\b'                                             1  upgrade

# --- Ruby ---
gem       '^(sudo\s+)?gem\s+install\b'                                    1  install
gem       '^(sudo\s+)?gem\s+uninstall\b'                                  1  remove
gem       '^(sudo\s+)?gem\s+update\b'                                     1  upgrade

# --- Go ---
go        '^go\s+install\b'                                               1  install

# --- Java / JVM ---
sdkman    '^sdk\s+install\b'                                              1  install
sdkman    '^sdk\s+uninstall\b'                                            1  remove
sdkman    '^sdk\s+upgrade\b'                                              1  upgrade
sdkman    '^sdk\s+(use|default)\b'                                        1  other

# --- PHP ---
composer  '^composer\s+global\s+require\b'                                1  install
composer  '^composer\s+global\s+remove\b'                                 1  remove
composer  '^composer\s+global\s+update\b'                                 1  upgrade

# --- Fish ---
fisher    '^fisher\s+install\b'                                           1  install
fisher    '^fisher\s+remove\b'                                            1  remove
fisher    '^fisher\s+update\b'                                            1  upgrade
" >$conf
    end

    # Create user extension directory
    command mkdir -p $__fish_config_dir/pkg_audit.d

    # Load matchers
    _pkg_audit_load_config
end

function _pkg_audit_update --on-event pkg_audit_update
    _pkg_audit_load_config
end

function _pkg_audit_uninstall --on-event pkg_audit_uninstall
    set -e _pkg_audit_version
    set -e _pkg_audit_names
    set -e _pkg_audit_matchers
    set -e _pkg_audit_weights
    set -e _pkg_audit_sorted_indices
    set -e _pkg_audit_last_match_name
    set -e _pkg_audit_last_match_event
    set -e _pkg_audit_events
    # Intentionally leave config files and log — user data
end

# Load matchers on shell startup (for shells that start after initial install)
if status is-interactive
    _pkg_audit_load_config
end
