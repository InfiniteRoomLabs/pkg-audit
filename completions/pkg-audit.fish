complete -c pkg-audit -f
complete -c pkg-audit -n "not __fish_seen_subcommand_from log list reload" -a log -d "Show the audit log"
complete -c pkg-audit -n "not __fish_seen_subcommand_from log list reload" -a list -d "Show loaded matchers"
complete -c pkg-audit -n "not __fish_seen_subcommand_from log list reload" -a reload -d "Reload matcher configs"
complete -c pkg-audit -n "__fish_seen_subcommand_from log" -l follow -d "Follow the log (tail -f)"
