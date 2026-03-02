function _pkg_audit_match --argument-names cmdline
    if test -z "$cmdline"
        return 1
    end

    for i in $_pkg_audit_sorted_indices
        set -l name $_pkg_audit_names[$i]
        set -l matcher $_pkg_audit_matchers[$i]

        set -l matched 0

        # Detect matcher type by convention:
        # Starts with ^ → regex
        # Is an existing file path → source it and call pkg_audit_match
        # Otherwise → fish function name
        if string match -qr '^\^' -- $matcher
            # Regex matcher
            if string match -rq -- $matcher $cmdline
                set matched 1
            end
        else if test -f "$matcher"
            # Script file — source it and call its entry point
            source $matcher 2>/dev/null
            if type -q pkg_audit_match
                if pkg_audit_match $cmdline
                    set matched 1
                end
                functions -e pkg_audit_match
            end
        else if type -q $matcher
            # Function name
            if $matcher $cmdline
                set matched 1
            end
        end

        if test $matched -eq 1
            set -g _pkg_audit_last_match_name $name
            set -g _pkg_audit_last_match_event $_pkg_audit_events[$i]
            return 0
        end
    end

    return 1
end
