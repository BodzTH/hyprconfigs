pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

// App icons for the whole shell: windows in the taskbar (bar/Taskbar.qml) and
// overview (panels/Overview.qml), notifications (panels/NotificationCard.qml)
// and the cheatsheet's app rows (panels/Cheatsheet.qml).
//
// Most windows are resolved from their Wayland appId and its desktop entry.
// Terminals are the exception: their appId never says what's running inside,
// so for those the icon follows the program in the terminal's foreground,
// read from /proc by scripts/term_fg.sh: Claude Code shows the claude icon,
// nvim the nvim icon, and the terminal's own icon comes back when the
// program exits. Any program the icon theme (Tela-circle-black-dark) has an
// icon for is picked up by name; terminalPrograms below only lists the ones
// whose icon is named differently.
//
// The old title matching is kept as the fallback for a window whose PID isn't
// known yet: it can't see Claude Code at all, which replaces the title with
// its own ("◐ <task>").
//
// Browsers are the one place the page title is read (Bodz asked for it,
// 2026-10-07): a window whose active tab is claude.ai shows the Claude icon.
QtObject {
    id: self

    // PID (as a string) → name of the program in that terminal's foreground.
    // Reassigned whole on every update, so bindings that read it re-evaluate.
    property var running: ({})

    // App-identity overrides, keyed on the Wayland appId only — never on the
    // window title, which is page/document content an app doesn't control.
    // Both exist because hypr/modules/variables.lua launches these with a
    // custom --class, so their appId isn't "kitty" and has no matching desktop
    // entry for heuristicLookup to find:
    //   - fileManager = "kitty --class=org.yazi.fm ..."
    //   - updater = "kitty --class=cachy.update ..." → Pac-Man (pacmanSource;
    //     it runs pacman -Syu). windowrules.lua also
    //     matches the older "cachy-update" and "org.cachyos.update"
    //     spellings — id.includes("cachy") covers all three
    readonly property var appIdOverrides: [
        { key: "org.yazi.fm", icon: "yazi" },
        { key: "cachy", icon: "pacman" },          // drawn (pacmanSource)
    ]

    // Browser windows whose active tab is one of these pages take its icon.
    // Matched on the page title with the browser's own suffix removed;
    // claude.ai titles a page "Claude" or "<chat> - Claude", and Claude Code
    // on the web "Claude Code".
    readonly property var browserAppIds: ["firefox"]
    readonly property var browserPages: [
        // The theme's claude icon is the spark on a dark round badge; this is
        // the spark alone (icons/claude-spark.svg), as Bodz asked. Bump ?v=
        // after editing the SVG: quickshell caches images by URL for its whole
        // run, through config reloads.
        { title: /(^|\s[-–—|·]\s)Claude( Code)?$/, icon: Quickshell.shellDir + "/icons/claude-spark.svg?v=2" },
    ]

    readonly property var terminalAppIds: ["kitty", "foot", "alacritty", "org.wezfurlong.wezterm", "com.mitchellh.ghostty"]

    // A terminal at its prompt shows the terminal's own icon, not the shell's.
    readonly property var shells: ["fish", "bash", "zsh", "sh", "dash", "nu"]

    // Short-lived tools the icon theme happens to have an icon for. Without
    // this, every `git status` or `python3 x.py` flicked the terminal's icon.
    readonly property var notApps: ["git", "python", "python3", "node", "npm", "make", "cargo", "sudo", "ssh"]

    // Programs whose icon isn't named after the program. Everything else is
    // looked up by its own name, in the icon theme and then desktop entries.
    readonly property var terminalPrograms: [
        { key: "claude", icon: "clawd" },                           // the mascot (pixelIcons)
        { key: "vim", icon: "gvim" },                               // vim.desktop's real Icon= key
        { key: "nano", icon: "accessories-text-editor" },
        { key: "lazygit", icon: "utilities-terminal" },
        { key: "nmtui", icon: "preferences-system-network" },
    ]

    function isTerminal(appId) {
        const id = appId ? appId.toLowerCase() : "";
        return terminalAppIds.some(t => id.includes(t));
    }

    function isBrowser(appId) {
        const id = appId ? appId.toLowerCase() : "";
        return browserAppIds.some(b => id.includes(b));
    }

    function browserPageIcon(title) {
        const page = (title || "").replace(/\s[-–—]\s(Mozilla )?Firefox$/, "");
        const match = browserPages.find(p => p.title.test(page));
        return match ? match.icon : "";
    }

    // ▓▒░ PIXEL ICONS — drawn here, in the wallpaper accent, so they follow
    // the wallpaper like the window border. One string per row, "#" a filled
    // cell, 11 cells wide: at the taskbar's 22px each cell is exactly 2px, and
    // crispEdges keeps them sharp. Names here win over the icon theme.
    readonly property var pixelIcons: ({
        // Clawd, Claude Code's mascot, as on its welcome screen: head, two eye
        // notches, an arm each side, four legs. The colour the Hyprland Claude
        // Code theme gives him.
        "clawd": [
            ".#########.",
            ".#########.",
            "##.#####.##",
            "###########",
            ".#########.",
            ".#########.",
            ".#.#...#.#.",
            ".#.#...#.#.",
        ],
    })

    // A data: URL for a pixel icon, one rect per run of filled cells,
    // vertically centred in an 11×11 box.
    function pixelSource(name) {
        const rows = pixelIcons[name];
        const top = (11 - rows.length) / 2;
        let d = "";
        rows.forEach((row, y) => {
            const re = /#+/g;
            let run;
            while ((run = re.exec(row)) !== null)
                d += "M" + run.index + " " + (y + top) + "h" + run[0].length + "v1H" + run.index + "z";
        });
        const svg = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 11 11' shape-rendering='crispEdges'>"
            + "<path fill='" + Theme.accent.toString() + "' d='" + d + "'/></svg>";
        return "data:image/svg+xml;utf8," + encodeURIComponent(svg);
    }

    function clawdSource() { return pixelSource("clawd"); }

    // Pac-Man, for the pacman updater (SUPER+U) — pacman's own ILoveCandy
    // progress bar is the same joke. A smooth vector body (as 11-cell pixel
    // art it read as a corrupted image next to the theme's round icons) with
    // one square pixel eye, cut out like Clawd's: 2.18 units is exactly 2px at
    // the taskbar's 22px (4px at the cheatsheet's 44), on the pixel grid.
    function pacmanSource() {
        const svg = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'>"
            + "<path fill='" + Theme.accent.toString() + "' fill-rule='evenodd' d='"
            + "M12 12L20.66 7A10 10 0 1 0 20.66 17Z"   // body, mouth open to the right
            + "M13.09 5.45h2.18v2.18h-2.18Z"           // eye
            + "'/></svg>";
        return "data:image/svg+xml;utf8," + encodeURIComponent(svg);
    }

    // Icons drawn here rather than taken from the theme.
    function isDrawn(name) { return name === "pacman" || name in pixelIcons; }

    // The part of a title that says what's running. Claude Code animates a
    // spinner glyph in front of its title several times a second; without
    // this, every frame would look like a new program.
    function titleKey(title) {
        return (title || "").replace(/^[^\w~\/.]+/, "");
    }

    // ▓▒░ LOOKUP CACHE
    // heuristicLookup scans every desktop entry and hasThemeIcon walks the
    // theme; both answer the same for a key until apps are installed or
    // removed. Bindings re-run these on every title change (a browser's tab
    // switches, a terminal's commands), so each key is looked up once. Not a
    // bound property: a cache hit must not notify anything.
    property var _cache: ({})
    readonly property int _appCount: DesktopEntries.applications.values.length
    on_AppCountChanged: _cache = {}

    function _cached(kind, key, compute) {
        const k = kind + ":" + key;
        if (!(k in _cache)) _cache[k] = compute();
        return _cache[k];
    }

    function hasIcon(name) {
        return !!name && _cached("theme", name, () => Quickshell.hasThemeIcon(name));
    }

    // The icon of the desktop entry for `key` (an appId, an app name), or "".
    function entryIcon(key) {
        const k = (key || "").toLowerCase();
        if (!k) return "";
        return _cached("entry", k, () => {
            const entry = DesktopEntries.heuristicLookup(k);
            return entry && entry.icon ? entry.icon : "";
        });
    }

    // The icon of the installed app whose display name is exactly `name`
    // ("The Plan"), or "". For scripts that notify as plain notify-send.
    function entryIconByName(name) {
        const n = (name || "").trim().toLowerCase();
        if (!n) return "";
        return _cached("name", n, () => {
            const entry = DesktopEntries.applications.values.find(a => (a.name || "").toLowerCase() === n);
            return entry && entry.icon ? entry.icon : "";
        });
    }

    // The icon of the app a cheatsheet label names, or "": the app in
    // trailing parentheses, else the whole label — "Terminal (kitty)" → kitty,
    // "Editor (Neovim)" → nvim, "The Plan". Bind descriptions are the only
    // handle: a Lua bind's command isn't visible to `hyprctl binds`.
    function appIconForLabel(label) {
        const m = /\(([^)]+)\)\s*$/.exec(label || "");
        const name = (m ? m[1] : (label || "")).trim();
        const lower = name.toLowerCase();
        const command = lower.split(" ")[0];   // "(pacman -Syu)" → pacman
        const icon = (isDrawn(command) ? command : "")
            || entryIconByName(name) || entryIcon(name) || (hasIcon(lower) ? lower : "");
        return icon ? sourceFor(icon) : "";
    }

    // An image source for an icon name, a path or a pixelIcons name.
    function sourceFor(name) {
        if (!name) return "";
        if (name === "pacman") return pacmanSource();
        if (name in pixelIcons) return pixelSource(name);
        if (name.startsWith("/")) return "file://" + name;
        if (name.startsWith("file://")) return name;
        return Quickshell.iconPath(name);
    }

    // Ask term_fg.sh what terminal `pid` is running. Requests within the
    // throttle window share one run.
    property var _pending: ({})
    function watch(pid) {
        if (!(pid > 0)) return;
        _pending[pid] = true;
        if (!throttle.running && !fgProc.running) throttle.start();
    }

    property Timer throttle: Timer {
        id: throttle
        interval: 150
        onTriggered: {
            const pids = Object.keys(self._pending);
            if (pids.length === 0) return;
            self._pending = {};
            fgProc.asked = pids;
            fgProc.command = [Quickshell.shellDir + "/scripts/term_fg.sh"].concat(pids);
            fgProc.running = true;
        }
    }

    property Process fgProc: Process {
        id: fgProc
        property var asked: []
        stdout: StdioCollector {
            onStreamFinished: {
                const next = Object.assign({}, self.running);
                fgProc.asked.forEach(pid => delete next[pid]);  // gone or unreadable
                this.text.split("\n").forEach(line => {
                    const space = line.indexOf(" ");
                    if (space > 0) next[line.slice(0, space)] = line.slice(space + 1).trim();
                });
                self.running = next;
            }
        }
        // Requests that arrived during this run.
        onRunningChanged: if (!running && Object.keys(self._pending).length > 0) throttle.start()
    }

    function programIcon(name) {
        const n = (name || "").toLowerCase();
        if (!n || shells.includes(n) || notApps.includes(n)) return "";
        const mapped = terminalPrograms.find(p => p.key === n);
        if (mapped) return mapped.icon;
        return hasIcon(n) ? n : entryIcon(n);
    }

    function titleProgramIcon(title) {
        const t = titleKey(title).toLowerCase();
        const words = t.split(/[^\w.-]+/);
        // fish_title puts the running command first: "nvim ~/.c/hypr".
        return words.length > 0 && words[0] ? programIcon(words[0]) : "";
    }

    function iconName(appId, title, pid) {
        let id = appId ? appId.toLowerCase() : "";
        if (id.endsWith(".desktop")) id = id.substring(0, id.length - 8);
        if (!id) return "application-x-executable";

        if (id.includes("antigravity")) return "";

        for (let i = 0; i < appIdOverrides.length; i++) {
            if (id.includes(appIdOverrides[i].key)) return appIdOverrides[i].icon;
        }

        if (isBrowser(id)) {
            const page = browserPageIcon(title);
            if (page) return page;
        }

        if (isTerminal(id)) {
            const known = pid > 0 ? running[String(pid)] : undefined;
            const program = known !== undefined ? programIcon(known) : titleProgramIcon(title);
            if (program) return program;
        }

        return entryIcon(id) || (hasIcon(id) ? id : "application-x-executable");
    }

    // An image source for the window: a theme icon path, or a file URL.
    function iconSource(appId, title, pid) {
        const id = appId ? appId.toLowerCase() : "";
        if (id.includes("antigravity")) {
            return "file://" + Quickshell.env("HOME") + "/Apps/Antigravity/Google-Antigravity-Icon-White.png";
        }
        return sourceFor(iconName(appId, title, pid) || "application-x-executable");
    }

    // ▓▒░ NOTIFICATIONS
    // An image source for a notification's badge, or "" for the card's glyph.
    //   1. an inline image (avatar, album art) — the card fills the badge
    //   2. Claude Code: it notifies through its terminal (kitty's OSC 99), so
    //      it arrives as app "kitty" titled "Claude Code" → Clawd
    //   3. a theme icon the sender named (Network's network-wireless, ...)
    //   4. the sender's themed app icon, found by its desktop-entry hint, its
    //      app name, or — for plain notify-send from a script — a summary that
    //      names an installed app ("The Plan", "Prayer Calendar")
    //   5. a file the sender passed. One under /usr or /opt is the app's own
    //      logo (kitty sends /usr/lib/kitty/logo/kitty.png) and loses to the
    //      themed icon in 4; anywhere else it's content and wins.
    function isClaudeNotification(n) {
        return !!n && isTerminal(n.appName) && /^claude( code)?$/i.test((n.summary || "").trim());
    }

    // The name a notification's header shows: Claude Code for Claude Code, the
    // installed app a plain notify-send names in its summary, else the sender.
    function notificationAppName(n) {
        if (!n) return "";
        if (isClaudeNotification(n)) return "Claude Code";
        const app = (n.appName || "").trim();
        const summary = (n.summary || "").trim();
        if (app.toLowerCase() === "notify-send" && entryIconByName(summary)) return summary;
        return app;
    }

    function notificationSource(n) {
        if (!n) return "";
        if (n.image) return n.image;

        if (isClaudeNotification(n)) return clawdSource();
        const app = (n.appName || "").trim();
        const appKey = app.toLowerCase();
        const summary = (n.summary || "").trim();

        const icon = n.appIcon || "";
        const isFile = icon.startsWith("/") || icon.startsWith("file://");
        if (icon && !isFile && hasIcon(icon)) return sourceFor(icon);

        const themed = entryIcon(n.desktopEntry) || entryIcon(app)
            || (appKey === "notify-send" ? entryIconByName(summary) : "");
        const path = icon.replace(/^file:\/\//, "");
        if (isFile && !(themed && /^\/(usr|opt)\//.test(path))) return "file://" + path;
        if (themed) return sourceFor(themed);
        if (appKey === "notify-send") return sourceFor("utilities-terminal");
        return "";
    }
}
