#!/usr/bin/env bash
# Switch every keyboard to the first layout in kb_layout (English) so the
# hyprlock password is typed in the expected layout. Used by the power menu.
# Never fail: callers chain `&& hyprlock`, and the lock must still happen.
hyprctl switchxkblayout all 0 >/dev/null || true
