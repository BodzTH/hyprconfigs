# =============================================================================
# Environment Variables & Paths Configuration
# =============================================================================

# Set default editor (Neovim -> Vim -> Vi -> Nano) if not already set
if not set -q EDITOR
    if type -q nvim
        set -gx EDITOR nvim
        set -gx VISUAL nvim
    else if type -q vim
        set -gx EDITOR vim
        set -gx VISUAL vim
    else if type -q vi
        set -gx EDITOR vi
        set -gx VISUAL vi
    else
        set -gx EDITOR nano
        set -gx VISUAL nano
    end
end

# Add ~/.local/bin to PATH if it exists and is not already present
if test -d ~/.local/bin; and not contains ~/.local/bin $PATH
    fish_add_path ~/.local/bin
end

# Exit if not interactive to speed up script execution
if not status is-interactive
    return
end

# HyprBlur theme for FZF
if type -q fzf
    set -gx FZF_DEFAULT_OPTS "\
    --color=bg+:#1c1c1c,bg:#111111,spinner:#af87af,hl:#87afd7 \
    --color=fg:#e5e5e5,header:#d75f5f,info:#af87af,pointer:#87afd7 \
    --color=marker:#87af87,fg+:#ffffff,prompt:#87afd7,hl+:#87afd7"
end

# Colorized man pages via less
set -gx LESS_TERMCAP_mb (printf '\e[1;31m')      # start blink
set -gx LESS_TERMCAP_md (printf '\e[1;36m')      # start bold/cyan
set -gx LESS_TERMCAP_me (printf '\e[0m')         # end bold/blink
set -gx LESS_TERMCAP_se (printf '\e[0m')         # end standout
set -gx LESS_TERMCAP_so (printf '\e[1;44;33m')   # start standout (yellow on blue)
set -gx LESS_TERMCAP_ue (printf '\e[0m')         # end underline
set -gx LESS_TERMCAP_us (printf '\e[1;32m')      # start underline/green
