# pkg-audit Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Fisher plugin that monitors successful shell commands against configurable matchers and writes a JSONL audit log of package management operations.

**Architecture:** A `fish_postexec` event handler checks each command against matchers loaded from tabular config files. Config lines are `eval`'d by fish for variable/command expansion. Matchers are stored in parallel global lists sorted by weight; highest weight wins on conflict. Audit entries are appended as JSONL.

**Tech Stack:** Fish shell 4.3+, Fisher plugin manager, JSONL for log format.

---

### Task 1: Scaffold the plugin repo

**Files:**
- Create: `~/projects/pkg-audit/conf.d/pkg_audit.fish`
- Create: `~/projects/pkg-audit/functions/_pkg_audit_load_config.fish`
- Create: `~/projects/pkg-audit/functions/_pkg_audit_match.fish`
- Create: `~/projects/pkg-audit/functions/_pkg_audit_log.fish`
- Create: `~/projects/pkg-audit/functions/pkg-audit.fish`
- Create: `~/projects/pkg-audit/completions/pkg-audit.fish`

**Step 1: Create directory structure**

```bash
mkdir -p ~/projects/pkg-audit/{conf.d,functions,completions}
```

**Step 2: Initialize git repo**

```bash
cd ~/projects/pkg-audit && git init
```

**Step 3: Create empty placeholder files**

```bash
touch conf.d/pkg_audit.fish
touch functions/_pkg_audit_load_config.fish
touch functions/_pkg_audit_match.fish
touch functions/_pkg_audit_log.fish
touch functions/pkg-audit.fish
touch completions/pkg-audit.fish
```

**Step 4: Commit scaffold**

```bash
git add -A && git commit -m "chore: scaffold plugin structure"
```

---

### Task 2: Implement the config loader

**Files:**
- Create: `~/projects/pkg-audit/functions/_pkg_audit_load_config.fish`

**Step 1: Write the config loader**

```fish
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
            string match -qr '^\s*(#|$)' -- $line; and continue

            # Eval the line — fish expands $vars, (commands), ~, and strips quotes
            set -l parts
            eval set -l parts $line 2>/dev/null; or continue

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
```

**Step 2: Verify it loads by sourcing manually**

```bash
cd ~/projects/pkg-audit
source functions/_pkg_audit_load_config.fish
# Create a test config
mkdir -p /tmp/pkg-audit-test
echo "testpkg '^echo hello' 5" > /tmp/pkg-audit-test/test.conf
set __fish_config_dir /tmp/pkg-audit-test
_pkg_audit_load_config
echo $_pkg_audit_names    # expect: testpkg
echo $_pkg_audit_matchers # expect: ^echo hello
echo $_pkg_audit_weights  # expect: 5
echo $_pkg_audit_sorted_indices # expect: 1
```

**Step 3: Commit**

```bash
git add functions/_pkg_audit_load_config.fish && git commit -m "feat: implement config loader with eval expansion and weight sorting"
```

---

### Task 3: Implement the matcher

**Files:**
- Create: `~/projects/pkg-audit/functions/_pkg_audit_match.fish`

**Step 1: Write the matcher function**

The matcher iterates the sorted indices and tests each matcher against the command line. Returns 0 on match and sets `_pkg_audit_last_match_name` to the source-name. Returns 1 on no match.

```fish
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
            string match -rq -- $matcher $cmdline; and set matched 1
        else if test -f "$matcher"
            # Script file — source it and call its entry point
            source $matcher 2>/dev/null
            if type -q pkg_audit_match
                pkg_audit_match $cmdline; and set matched 1
                functions -e pkg_audit_match
            end
        else if type -q $matcher
            # Function name
            $matcher $cmdline; and set matched 1
        end

        if test $matched -eq 1
            set -g _pkg_audit_last_match_name $name
            return 0
        end
    end

    return 1
end
```

**Step 2: Test with a regex matcher**

```bash
source functions/_pkg_audit_load_config.fish
source functions/_pkg_audit_match.fish
# Reuse the test config from Task 2
set __fish_config_dir /tmp/pkg-audit-test
_pkg_audit_load_config
_pkg_audit_match "echo hello world"; echo $status  # expect: 0
echo $_pkg_audit_last_match_name                     # expect: testpkg
_pkg_audit_match "ls -la"; echo $status              # expect: 1
```

**Step 3: Commit**

```bash
git add functions/_pkg_audit_match.fish && git commit -m "feat: implement matcher with regex, function, and script-file support"
```

---

### Task 4: Implement the log writer

**Files:**
- Create: `~/projects/pkg-audit/functions/_pkg_audit_log.fish`

**Step 1: Write the log function**

```fish
function _pkg_audit_log --argument-names source_name cmdline
    set -l log_dir ~/.local/share/fish
    set -l log_file $log_dir/pkg-audit.log

    # Ensure log directory exists
    test -d $log_dir; or command mkdir -p $log_dir

    # ISO 8601 timestamp
    set -l ts (date -u +"%Y-%m-%dT%H:%M:%S")

    # Escape double quotes and backslashes in command for valid JSON
    set -l escaped_cmd (string replace -a '\\' '\\\\' -- $cmdline | string replace -a '"' '\\"')
    set -l escaped_source (string replace -a '\\' '\\\\' -- $source_name | string replace -a '"' '\\"')

    echo "{\"ts\":\"$ts\",\"source\":\"$escaped_source\",\"cmd\":\"$escaped_cmd\"}" >>$log_file
end
```

**Step 2: Test it writes valid JSONL**

```bash
source functions/_pkg_audit_log.fish
_pkg_audit_log "apt" "sudo apt install neovim"
tail -1 ~/.local/share/fish/pkg-audit.log
# expect: {"ts":"2026-03-02T...","source":"apt","cmd":"sudo apt install neovim"}
```

**Step 3: Commit**

```bash
git add functions/_pkg_audit_log.fish && git commit -m "feat: implement JSONL audit log writer"
```

---

### Task 5: Wire up the postexec handler and install/uninstall events

**Files:**
- Create: `~/projects/pkg-audit/conf.d/pkg_audit.fish`

This is the bootstrap file. Fisher uses the filename (`pkg_audit`) as the event name prefix, so `pkg_audit_install`, `pkg_audit_update`, and `pkg_audit_uninstall` events fire automatically.

**Step 1: Write the conf.d bootstrap**

```fish
# pkg-audit: audit log for system package management commands
set -g _pkg_audit_version 0.1.0

function _pkg_audit_postexec --on-event fish_postexec
    # Capture status immediately — any command we run overwrites it
    set -l exit_code $status

    # Only log successful commands
    test $exit_code -eq 0; or return

    # Skip if no matchers loaded
    test (count $_pkg_audit_sorted_indices) -gt 0; or return

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
```

**Step 2: Test by sourcing the full plugin locally**

```bash
cd ~/projects/pkg-audit
# Source all functions
for f in functions/*.fish; source $f; end
# Source the conf.d bootstrap
source conf.d/pkg_audit.fish
# Check matchers loaded
echo (count $_pkg_audit_names) matchers loaded  # expect: 4 matchers loaded
```

**Step 3: Commit**

```bash
git add conf.d/pkg_audit.fish && git commit -m "feat: wire up postexec handler and install/uninstall lifecycle events"
```

---

### Task 6: Implement the CLI helper

**Files:**
- Create: `~/projects/pkg-audit/functions/pkg-audit.fish`

**Step 1: Write the CLI function**

```fish
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
```

**Step 2: Verify subcommands work**

```bash
source functions/pkg-audit.fish
pkg-audit           # expect: usage message
pkg-audit list      # expect: table of loaded matchers
pkg-audit reload    # expect: "Reloaded: 4 matchers from config"
```

**Step 3: Commit**

```bash
git add functions/pkg-audit.fish && git commit -m "feat: add CLI helper with log, list, and reload subcommands"
```

---

### Task 7: Add completions

**Files:**
- Create: `~/projects/pkg-audit/completions/pkg-audit.fish`

**Step 1: Write completions**

```fish
complete -c pkg-audit -f
complete -c pkg-audit -n "not __fish_seen_subcommand_from log list reload" -a log -d "Show the audit log"
complete -c pkg-audit -n "not __fish_seen_subcommand_from log list reload" -a list -d "Show loaded matchers"
complete -c pkg-audit -n "not __fish_seen_subcommand_from log list reload" -a reload -d "Reload matcher configs"
complete -c pkg-audit -n "__fish_seen_subcommand_from log" -l follow -d "Follow the log (tail -f)"
```

**Step 2: Commit**

```bash
git add completions/pkg-audit.fish && git commit -m "feat: add tab completions for pkg-audit subcommands"
```

---

### Task 8: Integration test via Fisher install

**Step 1: Install from local path**

```bash
fisher install ~/projects/pkg-audit
```

**Step 2: Verify install event fired**

```bash
test -f ~/.config/fish/pkg_audit.conf; and echo "Default config created"
test -d ~/.config/fish/pkg_audit.d; and echo "Extension dir created"
pkg-audit list  # expect: table with 4 default matchers
```

**Step 3: Test the postexec hook end-to-end**

```bash
# Run a command that should match
sudo apt install --dry-run cowsay
# Check the log
pkg-audit log
# expect: JSONL entry with source "apt" if dry-run exits 0
```

**Step 4: Test user extension config**

```bash
echo "custom '^echo audit-test\$' 10" > ~/.config/fish/pkg_audit.d/test.conf
pkg-audit reload
pkg-audit list   # expect: custom matcher at top (weight 10)
echo audit-test  # should trigger
pkg-audit log    # expect: entry with source "custom"
# Clean up
rm ~/.config/fish/pkg_audit.d/test.conf
pkg-audit reload
```

**Step 5: Commit any fixes from integration testing**

```bash
cd ~/projects/pkg-audit
git add -A && git commit -m "fix: adjustments from integration testing"
```
