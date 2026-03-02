function _pkg_audit_log --argument-names source_name event cmdline
    set -l log_dir ~/.local/share/fish
    set -l log_file $log_dir/pkg-audit.log

    # Ensure log directory exists
    test -d $log_dir; or command mkdir -p $log_dir

    # ISO 8601 timestamp
    set -l ts (date -u +"%Y-%m-%dT%H:%M:%S")

    # Escape double quotes and backslashes in command for valid JSON
    set -l escaped_cmd (string replace -a '\\' '\\\\' -- $cmdline | string replace -a '"' '\\"')
    set -l escaped_source (string replace -a '\\' '\\\\' -- $source_name | string replace -a '"' '\\"')

    echo "{\"ts\":\"$ts\",\"source\":\"$escaped_source\",\"event\":\"$event\",\"cmd\":\"$escaped_cmd\"}" >>$log_file
end
