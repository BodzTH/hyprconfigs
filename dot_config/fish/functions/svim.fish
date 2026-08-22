function svim --description 'Run Neovim with sudo preserving GUI display, runtime variables, and terminal type'
    if type -q nvim
        sudo -E WAYLAND_DISPLAY="$WAYLAND_DISPLAY" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" TERM="$TERM" nvim $argv
    else
        sudo -E WAYLAND_DISPLAY="$WAYLAND_DISPLAY" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" TERM="$TERM" vim $argv
    end
end
