function svim --description 'Edit files as root safely: nvim runs as you, only the save is privileged'
    # sudoedit copies the file to a temp file, opens it with your own nvim and
    # config, then writes it back as root -- nothing in ~/.local/state/nvim
    # ends up owned by root.
    SUDO_EDITOR=nvim command sudoedit $argv
end
