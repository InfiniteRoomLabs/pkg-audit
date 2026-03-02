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
        _pkg_audit_log $_pkg_audit_last_match_name "$argv"
    end
end

function _pkg_audit_install --on-event pkg_audit_install
    # Write default config if it doesn't already exist
    set -l conf $__fish_config_dir/pkg_audit.conf
    if not test -f $conf
        echo "\
# pkg-audit matcher configuration
# Format: source-name  'regex-or-function-or-script-path'  weight
#
# Lines are eval'd by fish — \$variables, (commands), and ~ are expanded.
# Matcher types (detected by convention):
#   ^pattern  → fish regex (string match -rq)
#   /path     → fish script file (must define pkg_audit_match function)
#   name      → fish function name (called with command line as \$argv)
#
# When multiple matchers match, highest weight wins.
# Drop extra configs in ~/.config/fish/pkg_audit.d/*.conf

# --- Debian / Ubuntu ---
apt       '^(sudo\s+)?apt\s+(install|remove|purge|upgrade|full-upgrade|dist-upgrade|autoremove)\b'       1
apt-get   '^(sudo\s+)?apt-get\s+(install|remove|purge|upgrade|dist-upgrade|autoremove)\b'                5
dpkg      '^(sudo\s+)?dpkg\s+-(i|r|P|-install|-remove|-purge|-configure)\b'                              1

# --- Snap / Flatpak ---
snap      '^(sudo\s+)?snap\s+(install|remove|refresh|revert|enable|disable)\b'                            1
flatpak   '^(sudo\s+)?flatpak\s+(install|uninstall|update)\b'                                             1

# --- Arch ---
pacman    '^(sudo\s+)?pacman\s+-(S|R|U)\b'                                                                1
yay       '^yay\s+-(S|R|U)\b'                                                                             1
paru      '^paru\s+-(S|R|U)\b'                                                                            1

# --- Fedora / RHEL ---
dnf       '^(sudo\s+)?dnf\s+(install|remove|upgrade|downgrade|reinstall|autoremove)\b'                    1
yum       '^(sudo\s+)?yum\s+(install|remove|update|downgrade|reinstall|autoremove)\b'                     1

# --- openSUSE ---
zypper    '^(sudo\s+)?zypper\s+(install|remove|update|dist-upgrade|patch)\b'                              1

# --- Alpine ---
apk       '^(sudo\s+)?apk\s+(add|del|upgrade)\b'                                                          1

# --- Nix ---
nix       '^nix\s+(profile\s+install|profile\s+remove|shell|run|build)\b'                                 1
nix-env   '^nix-env\s+-(i|e|u|iA|-install|-uninstall|-upgrade)\b'                                         1

# --- Homebrew ---
brew      '^brew\s+(install|uninstall|reinstall|upgrade)\b'                                                1

# --- Rust ---
rustup    '^rustup\s+(toolchain\s+(install|uninstall)|component\s+(add|remove)|update|self\s+update)\b'   1
cargo     '^cargo\s+(install|uninstall)\b'                                                                 1

# --- Node.js ---
npm       '^(sudo\s+)?npm\s+(install|uninstall|update)\s+(-g|--global)\b'                                 1
npm       '^(sudo\s+)?npm\s+(-g|--global)\s+(install|uninstall|update)\b'                                  2
pnpm      '^(sudo\s+)?pnpm\s+(add|remove|update)\s+(-g|--global)\b'                                       1
pnpm      '^(sudo\s+)?pnpm\s+(-g|--global)\s+(add|remove|update)\b'                                        2
yarn      '^yarn\s+global\s+(add|remove|upgrade)\b'                                                        1
bun       '^(sudo\s+)?bun\s+(install|add|remove)\s+(-g|--global)\b'                                        1
bun       '^(sudo\s+)?bun\s+(-g|--global)\s+(install|add|remove)\b'                                         2

# --- Python ---
pip       '^(sudo\s+)?pip3?\s+install\b'                                                                   1
uv        '^uv\s+(tool\s+install|tool\s+uninstall|pip\s+install|pip\s+uninstall)\b'                        1
pipx      '^pipx\s+(install|uninstall|upgrade|reinstall)\b'                                                 1

# --- Ruby ---
gem       '^(sudo\s+)?gem\s+(install|uninstall|update)\b'                                                  1

# --- Go ---
go        '^go\s+install\b'                                                                                 1

# --- Java / JVM ---
sdkman    '^sdk\s+(install|uninstall|upgrade|use|default)\b'                                                1

# --- PHP ---
composer  '^composer\s+global\s+(require|remove|update)\b'                                                  1

# --- Fish ---
fisher    '^fisher\s+(install|remove|update)\b'                                                             1
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
    # Intentionally leave config files and log — user data
end

# Load matchers on shell startup (for shells that start after initial install)
if status is-interactive
    _pkg_audit_load_config
end
