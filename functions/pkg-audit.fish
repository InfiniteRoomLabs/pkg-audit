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
            printf "%-10s %-6s %s\n" SOURCE WEIGHT MATCHER
            printf "%-10s %-6s %s\n" ------ ------ -------
            for i in $_pkg_audit_sorted_indices
                printf "%-10s %-6s %s\n" $_pkg_audit_names[$i] $_pkg_audit_weights[$i] $_pkg_audit_matchers[$i]
            end

        case reload
            _pkg_audit_load_config
            echo "Reloaded: "(count $_pkg_audit_names)" matchers from config"

        case ''
            echo "Usage: pkg-audit <command>"
            echo ""
            echo "Commands:"
            echo "  log [--follow]   Show the audit log (pretty-printed with jq if available)"
            echo "  list             Show loaded matchers sorted by weight"
            echo "  reload           Reload matcher configs"

        case '*'
            echo "pkg-audit: unknown command '$subcmd'" >&2
            echo "Run 'pkg-audit' for usage." >&2
            return 1
    end
end
