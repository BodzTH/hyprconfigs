function y --description 'Run Yazi file manager, restore last path on launch and persist it on exit'
    # Persistent file that stores the last visited directory across sessions
    set state_dir ~/.local/state/yazi
    set state_file $state_dir/last-dir
    mkdir -p $state_dir

    # Determine the start path: use explicit arg if given, else restore last dir
    set start_args $argv
    if test (count $argv) -eq 0; and test -s "$state_file"
        read -l last_dir < "$state_file"
        if test -d "$last_dir"
            set start_args "$last_dir"
        end
    end

    # Run yazi, writing the exit-cwd into the persistent state file
    command yazi $start_args --cwd-file="$state_file"

    # cd the shell to wherever yazi exited
    if test -s "$state_file"
        read -l cwd < "$state_file"
        if [ "$cwd" != "$PWD" ]; and test -d "$cwd"
            builtin cd -- "$cwd"
            if type -q zoxide
                zoxide add "$cwd"
            end
        end
    end
end
