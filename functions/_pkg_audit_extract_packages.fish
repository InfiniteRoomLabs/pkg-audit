function _pkg_audit_extract_packages --argument-names source cmd
    # Extract package names from a command, given its source.
    # Outputs one package name per line.

    # Strip leading sudo
    set -l c (string replace -r '^\s*sudo\s+' '' -- $cmd)
    set -l words (string split -n ' ' -- $c)

    # Determine where packages start based on source command structure
    set -l pkg_start 0

    switch $source
        # Simple: <mgr> <verb> [flags] <packages>
        case apt apt-get snap flatpak dnf yum zypper brew cargo pip pipx gem fisher
            set pkg_start 3

        # dpkg uses flag-style verbs: dpkg -i <packages>
        case dpkg apk
            set pkg_start 3

        # Arch: pacman -S [flags] <packages>
        case pacman yay paru
            set pkg_start 3

        # nix-env -i [flags] <packages>
        case nix-env
            set pkg_start 3

        # Two-word sub-command: <mgr> <sub> <verb> [flags] <packages>
        case nix
            # nix profile install <pkg>
            set pkg_start 4

        case rustup
            # rustup toolchain install <name> / rustup component add <name>
            set pkg_start 4

        case uv
            # uv tool install <pkg> / uv pip install <pkg>
            set pkg_start 4

        case composer
            # composer global require <pkg>
            set pkg_start 4

        case yarn
            # yarn global add <pkg>
            set pkg_start 4

        case sdkman
            # sdk install <candidate> [version] — combine as "candidate version"
            if test (count $words) -ge 4
                echo "$words[3] $words[4]"
            else if test (count $words) -ge 3
                echo $words[3]
            end
            return

        case go
            # go install <pkg@version> — strip @version
            set pkg_start 3

        # npm-style: flag can be before or after verb
        # npm install -g <pkg> / npm -g install <pkg>
        case npm pnpm bun
            # Find the verb by skipping flags, then packages start after it
            set -l found_verb 0
            for i in (seq 2 (count $words))
                set -l w $words[$i]
                if string match -qr '^-' -- $w
                    continue
                end
                if test $found_verb -eq 0
                    # This is the verb (install/uninstall/add/remove)
                    set found_verb 1
                    continue
                end
                # This is a package name
                echo $w
            end
            return

        case '*'
            set pkg_start 3
    end

    # Generic extraction: collect non-flag args from pkg_start onward
    if test $pkg_start -gt 0
        for i in (seq $pkg_start (count $words))
            set -l w $words[$i]
            if not string match -qr '^-' -- $w
                if test "$source" = go
                    # Strip @version suffix for go packages
                    echo (string replace -r '@.*' '' -- $w)
                else
                    echo $w
                end
            end
        end
    end
end
