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
        _pkg_audit_write_default_config >$conf
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
