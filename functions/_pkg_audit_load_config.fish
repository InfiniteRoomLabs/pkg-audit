function _pkg_audit_load_config
    # Clear any existing state
    set -g _pkg_audit_names
    set -g _pkg_audit_matchers
    set -g _pkg_audit_weights

    set -l config_files

    # Default config
    set -l default_conf $__fish_config_dir/pkg_audit.conf
    test -f $default_conf; and set -a config_files $default_conf

    # User extension configs
    set -l ext_dir $__fish_config_dir/pkg_audit.d
    if test -d $ext_dir
        for f in $ext_dir/*.conf
            test -f $f; and set -a config_files $f
        end
    end

    if test (count $config_files) -eq 0
        return 0
    end

    for config_file in $config_files
        while read -l line
            # Skip blank lines and comments
            if string match -qr '^\s*(#|$)' -- $line
                continue
            end

            # Eval the line — fish expands $vars, (commands), ~, and strips quotes
            set -l parts
            if not eval set -l parts $line 2>/dev/null
                continue
            end

            # Need exactly 3 parts: name, matcher, weight
            if test (count $parts) -ne 3
                continue
            end

            set -a _pkg_audit_names $parts[1]
            set -a _pkg_audit_matchers $parts[2]
            set -a _pkg_audit_weights $parts[3]
        end <$config_file
    end

    # Build a weight-sorted index (descending) so matching iterates highest-first
    set -g _pkg_audit_sorted_indices
    if test (count $_pkg_audit_weights) -gt 0
        # Create index:weight pairs, sort descending by weight, extract indices
        set -l pairs
        for i in (seq (count $_pkg_audit_weights))
            set -a pairs $i:$_pkg_audit_weights[$i]
        end
        for pair in (printf '%s\n' $pairs | sort -t: -k2 -rn)
            set -a _pkg_audit_sorted_indices (string replace -r ':.*' '' -- $pair)
        end
    end
end
