# =============================================================================
# Tool Initializations
# =============================================================================

# Starship prompt (plain fallback prompt if it isn't installed)
if type -q starship
    starship init fish | source
else
    function fish_prompt
        echo -n (set_color green)(prompt_pwd) (set_color normal)"> "
    end
end

# Zoxide smart cd (provides z / zi)
if type -q zoxide
    zoxide init fish | source
end
