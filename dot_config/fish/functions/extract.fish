function extract --description 'Extract any archive file automatically based on its extension'
    if test (count $argv) -eq 0
        echo "Usage: extract <archive_file>"
        return 1
    end
    if not test -f $argv[1]
        echo "'$argv[1]' is not a valid file"
        return 1
    end

    switch $argv[1]
        # bsdtar (libarchive, always present on Arch) reads all multi-file formats
        case '*.tar' '*.tar.*' '*.tgz' '*.tbz2' '*.txz' '*.zip' '*.rar' '*.7z'
            bsdtar -xf $argv[1]
        case '*.gz'
            gunzip -k $argv[1]
        case '*.bz2'
            bunzip2 -k $argv[1]
        case '*.xz'
            unxz -k $argv[1]
        case '*.zst'
            unzstd $argv[1]
        case '*.Z'
            uncompress $argv[1]
        case '*'
            echo "'$argv[1]' cannot be extracted via extract"
            return 1
    end
end
