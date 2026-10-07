#!/bin/sh
# What each terminal window is running, for the taskbar and overview icons
# (services/AppIconService.qml). For every terminal PID given, prints
#   PID NAME
# where NAME is the program in the foreground of the terminal's tty: the comm
# of the tty's foreground process group leader. That's "claude" for Claude
# Code (its launcher; the worker processes are named after the version),
# "nvim" for neovim, and the shell itself ("fish") when nothing is running.
# A terminal with several tabs reports the most recently started job.
#
# Read straight from /proc with shell built-ins only — no title parsing, and
# no cat/tr/head per process: one sh start is the whole cost.

for term in "$@"; do
    best="" best_start=-1
    for list in /proc/"$term"/task/*/children; do
        # No trailing newline in this file, so read "fails" yet fills the variable.
        children=""
        read -r children 2>/dev/null < "$list"
        [ -n "$children" ] || continue
        for child in $children; do
            read -r stat 2>/dev/null < /proc/"$child"/stat || continue
            # Fields after "comm) ": 3 state, 4 ppid, 5 pgrp, 6 session, 7 tty_nr, 8 tpgid
            set -- ${stat##*) }
            tpgid=$6
            [ "$tpgid" -gt 0 ] 2>/dev/null || continue
            read -r fg 2>/dev/null < /proc/"$tpgid"/stat || continue
            set -- ${fg##*) }
            start=${20}   # field 22, starttime
            if [ "$start" -gt "$best_start" ]; then
                read -r comm 2>/dev/null < /proc/"$tpgid"/comm || continue
                best_start=$start
                best=$comm
            fi
        done
    done
    [ -n "$best" ] && printf '%s %s\n' "$term" "$best"
done
exit 0
