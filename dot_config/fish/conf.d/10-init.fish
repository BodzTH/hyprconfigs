# =============================================================================
# Tool Initializations
# =============================================================================

# Initialize the Starship prompt layout if installed
if type -q starship
    set -l cache ~/.cache/starship_init.fish
    if not test -f $cache
        mkdir -p ~/.cache
        starship init fish > $cache
    end
    source $cache
else
    # Fallback prompt if Starship is missing
    function fish_prompt
        echo -n (set_color green)(prompt_pwd) (set_color normal)"> "
    end
end

# Zoxide Smart-CD Initialization if installed
if type -q zoxide
    set -l cache ~/.cache/zoxide_init.fish
    if not test -f $cache
        mkdir -p ~/.cache
        zoxide init fish > $cache
    end
    source $cache
end
