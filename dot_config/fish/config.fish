# =============================================================================
# Fish Shell Configuration Entrypoint
# =============================================================================
#
# Your fish configurations have been modularized and enhanced!
#
# Structure:
# - conf.d/
#   - 00-env.fish          : Environment variables, PATH modifications, FZF, and man page styles.
#   - 10-init.fish         : Prompt (Starship) and jump-helper (Zoxide) initializations.
#   - 20-aliases.fish      : Directory listing aliases (Eza/fallback) and common abbreviations.
#   - 30-kitty-sounds.fish : Toggleable sound events for the Kitty terminal.
#
# - functions/
#   - y.fish               : Yazi file manager cwd switcher.
#   - svim.fish            : Edit root-owned files safely via sudoedit + nvim.
#   - cat.fish             : bat wrapper fallback.
#   - cdi.fish             : Interactive directory jump using zoxide.
#   - mkcd.fish            : Create directory and cd into it.
#   - extract.fish         : Universal archive extractor.
#
# Note: fish automatically loads files in `conf.d/` on shell startup (in alphabetical order)
# and autoloads files in `functions/` on demand.
# =============================================================================
