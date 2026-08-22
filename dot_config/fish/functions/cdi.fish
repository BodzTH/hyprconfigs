function cdi --description 'Interactive cd using zoxide query'
    if type -q zi
        zi $argv
    else if type -q zoxide
        zoxide query -i $argv
    else
        echo "zoxide is not installed."
    end
end
