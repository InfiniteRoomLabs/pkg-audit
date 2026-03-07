# pkg-audit: Fish Package Installation Audit Logger

## Overview

A Fisher plugin that monitors successful shell commands, matches them against configurable patterns for system package managers, and writes a JSONL audit log.

## Config Format

Tabular text files with `#` comments. Each non-comment line is `eval`'d by fish before parsing, enabling `$variable`, `(command)`, and `~` expansion.

Columns (whitespace-separated):

```
source-name   matcher   weight
```

- **source-name**: Label for the log entry (e.g. `apt`, `dpkg`, `snap`)
- **matcher**: One of three types, detected by convention:
  - Starts with `^` → fish regex, matched via `string match -rq`
  - Starts with `/`, `./`, or resolves to a file path after eval → fish script (must define a function returning 0/1)
  - Plain word → fish function name, called with the command line as `$argv`, return 0 = match
- **weight**: Integer priority. When multiple matchers fire, highest weight wins.

## Default Matchers

```
apt   '^(sudo\s+)?apt\s+(install|remove|purge|upgrade|full-upgrade|dist-upgrade|autoremove)\b'   1
apt   '^(sudo\s+)?apt-get\s+(install|remove|purge|upgrade|dist-upgrade|autoremove)\b'             5
dpkg  '^(sudo\s+)?dpkg\s+-(i|r|P|-install|-remove|-purge|-configure)\b'                          1
snap  '^(sudo\s+)?snap\s+(install|remove|refresh|revert|enable|disable)\b'                        1
```

## Config Loading

1. Load `$__fish_config_dir/pkg_audit.conf` (defaults shipped with plugin)
2. Glob `$__fish_config_dir/pkg_audit.d/*.conf` (user additions)
3. Skip blank and `#`-prefixed lines
4. `eval` each line, parse into three columns
5. Store in parallel global lists: `$_pkg_audit_names`, `$_pkg_audit_matchers`, `$_pkg_audit_weights`

## Event Flow

```
command finishes
  → fish_postexec fires (argv = full command line)
  → if $status != 0, skip
  → iterate matchers sorted by weight (highest first)
  → first match wins → _pkg_audit_log appends JSONL
```

## Log Format

JSONL at `~/.local/share/fish/pkg-audit.log`:

```json
{"ts":"2026-03-02T14:30:05","source":"apt","cmd":"sudo apt install neovim"}
```

Directory auto-created on first write.

## Plugin File Layout

```
pkg-audit/
  conf.d/pkg_audit.fish                # postexec handler + config load trigger
  functions/pkg-audit.fish             # CLI: pkg-audit log|list|reload
  functions/_pkg_audit_load_config.fish
  functions/_pkg_audit_match.fish
  functions/_pkg_audit_log.fish
  completions/pkg-audit.fish
  config/pkg_audit.conf                # default matcher definitions
```

## CLI Helper

- `pkg-audit log` — show/tail the audit log
- `pkg-audit list` — show loaded matchers with weights
- `pkg-audit reload` — re-parse configs without restarting shell

## Scope

- System package managers only: apt, apt-get, dpkg, snap
- Successful commands only (exit 0)
- No log rotation (can be added externally)
- No notifications or alerting
