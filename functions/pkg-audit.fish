function pkg-audit -d "Package installation audit log manager"
    set -l subcmd $argv[1]

    switch "$subcmd"
        case log
            set -l log_file ~/.local/share/fish/pkg-audit.log
            if not test -f $log_file
                echo "No audit log found at $log_file"
                return 1
            end
            if isatty stdout; and type -q jq
                # Pretty-print if interactive and jq is available
                if test (count $argv) -ge 2; and test "$argv[2]" = --follow
                    tail -f $log_file
                else
                    jq '.' <$log_file
                end
            else
                if test (count $argv) -ge 2; and test "$argv[2]" = --follow
                    tail -f $log_file
                else
                    cat $log_file
                end
            end

        case list
            if test (count $_pkg_audit_names) -eq 0
                echo "No matchers loaded."
                return 0
            end
            printf "%-10s %-8s %-6s %s\n" SOURCE EVENT WEIGHT MATCHER
            printf "%-10s %-8s %-6s %s\n" ------ ----- ------ -------
            for i in $_pkg_audit_sorted_indices
                printf "%-10s %-8s %-6s %s\n" $_pkg_audit_names[$i] $_pkg_audit_events[$i] $_pkg_audit_weights[$i] $_pkg_audit_matchers[$i]
            end

        case reload
            _pkg_audit_load_config
            echo "Reloaded: "(count $_pkg_audit_names)" matchers from config"

        case report
            set -l log_file ~/.local/share/fish/pkg-audit.log
            if not test -f $log_file
                echo "No audit log found at $log_file"
                return 1
            end
            if not type -q jq
                echo "pkg-audit report requires jq."
                return 1
            end

            # Process log chronologically: installs add packages, removes subtract them
            set -l tmpdir (command mktemp -d)
            jq -r '.source, .event, .cmd' <$log_file | while read -l source; and read -l event; and read -l cmd
                set -l pkgs (_pkg_audit_extract_packages $source $cmd)
                switch "$event"
                    case install
                        for pkg in $pkgs
                            # Add if not already present
                            if not command grep -qxF -- $pkg $tmpdir/$source 2>/dev/null
                                echo $pkg >>$tmpdir/$source
                            end
                        end
                    case remove
                        if test -f $tmpdir/$source
                            for pkg in $pkgs
                                command grep -vxF -- $pkg $tmpdir/$source >$tmpdir/$source.tmp 2>/dev/null
                                command mv $tmpdir/$source.tmp $tmpdir/$source
                            end
                        end
                end
            end

            # Output report grouped by source, sorted alphabetically
            set -l has_output 0
            for source_file in (command ls $tmpdir/ 2>/dev/null | command sort)
                if test -s $tmpdir/$source_file
                    if test $has_output -eq 1
                        echo ""
                    end
                    echo $source_file
                    command sort -u <$tmpdir/$source_file | while read -l entry
                        echo "  $entry"
                    end
                    set has_output 1
                end
            end

            if test $has_output -eq 0
                echo "No installed packages found in audit log."
            end

            command rm -rf $tmpdir

        case ''
            echo "Usage: pkg-audit <command>"
            echo ""
            echo "Commands:"
            echo "  log [--follow]   Show the audit log (pretty-printed with jq if available)"
            echo "  list             Show loaded matchers sorted by weight"
            echo "  report           Show installed packages grouped by source"
            echo "  reload           Reload matcher configs"

        case '*'
            echo "pkg-audit: unknown command '$subcmd'" >&2
            echo "Run 'pkg-audit' for usage." >&2
            return 1
    end
end
