# =============================================================================
# Kitty Terminal Sound Effects (Optional)
# =============================================================================
# Set this to true to enable the sound effects when opening/closing Kitty.
# Can also be set as a universal variable: set -U fish_enable_kitty_sounds true
if not set -q fish_enable_kitty_sounds
    set -g fish_enable_kitty_sounds false
end

if test "$fish_enable_kitty_sounds" = true; and status is-interactive; and set -q KITTY_WINDOW_ID; and type -q mpv
    # Play startup sound
    if test -f "$HOME/.config/kitty/Kiss.m4a"
        mpv --no-video "$HOME/.config/kitty/Kiss.m4a" >/dev/null 2>&1 &
    end

    # Shutdown sound player function
    function play_shutdown_sound
        if not set -q _shutdown_sound_played
            set -g _shutdown_sound_played 1
            if test -f "$HOME/.config/kitty/windows-xp-shutdown.mp3"
                mpv --no-video "$HOME/.config/kitty/windows-xp-shutdown.mp3" >/dev/null 2>&1
            end
        end
    end

    # Register exit event handlers
    function play_shutdown_sound_on_exit --on-event fish_exit
        play_shutdown_sound
    end

    function play_shutdown_sound_on_hup --on-signal SIGHUP
        play_shutdown_sound
    end

    function play_shutdown_sound_on_term --on-signal SIGTERM
        play_shutdown_sound
    end
end
