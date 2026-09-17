function cdi --description 'Interactive cd using zoxide'
    if type -q zi
        zi $argv
    else
        echo "zoxide is not installed." >&2
        return 1
    end
end
