complete -c pkg-audit -f
complete -c pkg-audit -n "not __fish_seen_subcommand_from log list report reload" -a log -d "Show the audit log"
complete -c pkg-audit -n "not __fish_seen_subcommand_from log list report reload" -a list -d "Show loaded matchers"
complete -c pkg-audit -n "not __fish_seen_subcommand_from log list report reload" -a report -d "Show installed packages grouped by source"
complete -c pkg-audit -n "not __fish_seen_subcommand_from log list report reload" -a reload -d "Reload matcher configs"
complete -c pkg-audit -n "__fish_seen_subcommand_from log" -l follow -d "Follow the log (tail -f)"
