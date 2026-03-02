# pkg-audit

A [Fisher](https://github.com/jorgebucaran/fisher) plugin for [fish shell](https://fishshell.com) that silently monitors your shell and logs package management commands to a JSONL audit trail.

Every time you run `apt install`, `snap remove`, `dpkg -i`, or any other command that matches a configurable pattern, pkg-audit appends a timestamped entry to a local log file. Only successful commands (exit code 0) are recorded.

## Install

```fish
fisher install InfiniteRoomLabs/pkg-audit
```

Requires fish 4.0+ and [Fisher](https://github.com/jorgebucaran/fisher) 4.x.

## How It Works

pkg-audit hooks into fish's `fish_postexec` event. After every command you run:

1. Checks if the command exited successfully
2. Tests the command line against loaded matchers (highest weight first)
3. On match, appends a JSONL entry to `~/.local/share/fish/pkg-audit.log`

Log entries look like:

```json
{"ts":"2026-03-02T21:48:35","source":"apt","cmd":"sudo apt install neovim"}
```

## CLI

```
pkg-audit <command>
```

| Command | Description |
|---------|-------------|
| `log` | Show the audit log. Pretty-prints with `jq` if available and stdout is a terminal. |
| `log --follow` | Tail the log in real time (`tail -f`). |
| `list` | Show all loaded matchers sorted by weight (highest first). |
| `reload` | Reload matcher configs from disk. |

Tab completions are included for all subcommands and flags.

## Configuration

### Default Config

On install, pkg-audit writes a default config to `~/.config/fish/pkg_audit.conf` with matchers for common Debian/Ubuntu package managers:

| Source | Pattern | Weight |
|--------|---------|--------|
| `apt` | `apt install\|remove\|purge\|upgrade\|...` | 1 |
| `apt` | `apt-get install\|remove\|purge\|upgrade\|...` | 5 |
| `dpkg` | `dpkg -i\|-r\|-P\|--install\|--remove\|...` | 1 |
| `snap` | `snap install\|remove\|refresh\|revert\|...` | 1 |

All patterns handle an optional `sudo` prefix.

### Config Format

Each line in a config file has three fields:

```
source-name  'matcher'  weight
```

- **source-name** — A label for the log entry (e.g., `apt`, `brew`, `cargo`)
- **matcher** — A regex, function name, or script path (see below)
- **weight** — Integer priority. When multiple matchers match, highest weight wins.

Lines starting with `#` and blank lines are ignored. Lines are `eval`'d by fish, so `$variables`, `(commands)`, `~`, and quoting all work.

### Matcher Types

The matcher type is detected by convention:

| Convention | Type | How It Works |
|------------|------|-------------|
| Starts with `^` | Regex | Tested with `string match -rq` against the full command line |
| Existing file path | Script file | Sourced, then calls `pkg_audit_match $cmdline`. The function is cleaned up after each call. |
| Anything else | Function name | Called as `$matcher $cmdline`, matches if exit code is 0 |

### Extension Configs

Drop additional `.conf` files into `~/.config/fish/pkg_audit.d/` to add matchers without editing the default config. They use the same format.

Example — add Homebrew tracking:

```fish
# ~/.config/fish/pkg_audit.d/brew.conf
brew  '^brew\s+(install|uninstall|upgrade|reinstall)\b'  1
```

Then reload:

```fish
pkg-audit reload
```

## Log Location

```
~/.local/share/fish/pkg-audit.log
```

Each line is a valid JSON object (JSONL format) with three fields:

| Field | Description |
|-------|-------------|
| `ts` | UTC timestamp in ISO 8601 format |
| `source` | The source-name from the matching config entry |
| `cmd` | The full command line as entered |

You can query the log with standard tools:

```fish
# All apt operations
jq 'select(.source == "apt")' < ~/.local/share/fish/pkg-audit.log

# Commands from today
jq 'select(.ts | startswith("2026-03-02"))' < ~/.local/share/fish/pkg-audit.log
```

## Uninstall

```fish
fisher remove InfiniteRoomLabs/pkg-audit
```

Your config files and audit log are intentionally preserved — they're your data.

## License

MIT
