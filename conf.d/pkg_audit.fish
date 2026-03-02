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

apt   '^(sudo\s+)?apt\s+(install|remove|purge|upgrade|full-upgrade|dist-upgrade|autoremove)\b'    1
apt   '^(sudo\s+)?apt-get\s+(install|remove|purge|upgrade|dist-upgrade|autoremove)\b'              5
dpkg  '^(sudo\s+)?dpkg\s+-(i|r|P|-install|-remove|-purge|-configure)\b'                           1
snap  '^(sudo\s+)?snap\s+(install|remove|refresh|revert|enable|disable)\b'                         1
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
