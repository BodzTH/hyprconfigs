function cat --description 'Alias for bat if available, falling back to standard cat'
    if type -q bat
        # --theme="ansi" inherits your terminal's customized ANSI colors
        # --style="full" displays line numbers, git changes, grid lines, and file headers
        # --paging=never prevents bat from trapping short outputs inside a 'less' window
        bat --theme="ansi" --style="full" $argv
    else
        command cat $argv
    end
end
