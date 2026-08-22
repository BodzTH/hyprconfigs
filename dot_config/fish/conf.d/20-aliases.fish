# =============================================================================
# Aliases & Abbreviations Configuration
# =============================================================================

# Exit if not interactive to speed up script execution
if not status is-interactive
    return
end

# Directory Listing Aliases with Eza Fallback
if type -q eza
    alias ls="eza --icons"
    alias l="eza -l --icons"
    alias la="eza -a --icons"
    alias lla="eza -la --icons"
    alias lt="eza --tree --icons"
else
    # Fallback to standard ls
    alias ls="ls --color=auto"
    alias l="ls -l"
    alias la="ls -a"
    alias lla="ls -la"
    
    # Fallback for tree-like view
    if type -q tree
        alias lt="tree"
    else
        alias lt="find . -maxdepth 2"
    end
end

# Handy Navigation Abbreviations
abbr --add .. 'cd ..'
abbr --add ... 'cd ../..'
abbr --add .3 'cd ../../..'
abbr --add .4 'cd ../../../..'
abbr --add .5 'cd ../../../../../'

# Utility Abbreviations
abbr --add mkdir 'mkdir -p'

# Calendar Abbreviation (only if calcurse is installed)
if type -q calcurse
    abbr --add c calcurse
end

# Chezmoi / Dotfiles Shortcuts
alias cm="chezmoi"
alias dotfiles="chezmoi"
