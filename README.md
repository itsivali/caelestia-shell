# caelestia-shell — Willis Ivali's copy

A personal, heavily customised copy of **[Caelestia shell](https://github.com/caelestia-dots/shell) v2.5.0** —
the Quickshell-based desktop shell for the [Caelestia dots](https://github.com/caelestia-dots) on Hyprland
(Garuda Linux).

This copy lives at `~/.config/quickshell/caelestia`. Quickshell prefers the user-level path over the packaged
one, so this tree is what actually runs; the packaged copy in `/etc/xdg/quickshell/caelestia` is never
modified and is kept as a pristine reference for syncing.

```sh
git clone git@github.com:WillisIvali/caelestia-shell.git ~/.config/quickshell/caelestia
```

---

## Table of contents

- [What's custom](#whats-custom)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration outside this repo](#configuration-outside-this-repo)
- [Feature details](#feature-details)
  - [Weather in °C + location picker](#weather-in--c--location-picker)
  - [Natural trackpad scrolling](#natural-trackpad-scrolling)
  - [Clearing notifications from the lock screen](#clearing-notifications-from-the-lock-screen)
  - [Settings → Updates](#settings--updates)
  - [Settings → Plugins](#settings--plugins)
  - [Settings → Display](#settings--display)
- [Writing a plugin](#writing-a-plugin)
- [Working on this copy](#working-on-this-copy)
- [Syncing with the packaged upstream](#syncing-with-the-packaged-upstream)
- [Controlling the shell from the CLI](#controlling-the-shell-from-the-cli)
- [Project layout](#project-layout)
- [Troubleshooting](#troubleshooting)
- [License and credits](#license-and-credits)

---

## What's custom

Upstream ships three Nexus settings pages as placeholders and has no plugin system. This copy fills them in
and adds quality-of-life fixes:

| Area | Change |
|---|---|
| **Weather** | Always °C (`services.weatherUnits: "Celsius"`), plus a search/select your-location form with IP-based fallback |
| **Scrolling** | Natural, full-resolution touchpad scrolling — deltas are accumulated per step instead of being quantised, scroll factor `0.7` |
| **Lock screen** | Notifications can be cleared while locked: a `clear_all` button in the dock header and a `✕` per notification group, cleared in a short stagger so animations don't all fire at once |
| **Settings → Updates** | Real page: lists pending upgrades from `checkupdates`, can re-check, and launches `paru -Syu` in your configured terminal |
| **Settings → Plugins** | Real page backed by a **runtime plugin loader**: discovers QML plugins, toggles them on/off, shows status and description, feeds the count into Settings → About |
| **Settings → Display** | Real page: shows output info, lets you pick resolution/refresh/scale, applies **live** with a 15-second revert countdown, and persists the choice on Keep |
| **About** | Plugin count wired to the loader instead of the hard-coded `0` |

Everything above lives in this repository and is visible in the [commit history](../../commits).

---

## Requirements

- **Arch-based distro** — developed and verified on Garuda Linux
- **Hyprland 0.56+** (the Display page uses `hyprctl eval "hl.monitor(...)"`, because
  `hyprctl keyword monitor` is rejected by 0.56)
- **Quickshell 0.3.1** (`quickshell-git`) and Qt 6.11
- The packaged `caelestia-shell 2.5.0` dependencies, since this copy is a superset of it:
  `quickshell-git ddcutil brightnessctl libcava networkmanager lm_sensors aubio libpipewire
  libqalculate power-profiles-daemon ttf-material-symbols-variable ttf-rubik-vf
  ttf-cascadia-code-nerd qt6-base qt6-declarative qt6-imageformats qt6-m3shapes-git swappy`
- **`paru`** for the Updates page (any `checkupdates`-capable AUR helper works for listing;
  the upgrade command is `paru -Syu`)
- A **terminal emulator** configured as `general.apps.terminal` — the Updates page runs the
  upgrade inside it instead of doing anything privileged in the shell itself

---

## Installation

**Fresh install** (wipes any existing user copy — back it up first):

```sh
git clone git@github.com:WillisIvali/caelestia-shell.git ~/.config/quickshell/caelestia
```

**Adopt an existing copy** (keeps your local edits, replays mine on top):

```sh
cd ~/.config/quickshell/caelestia
git remote add origin git@github.com:WillisIvali/caelestia-shell.git
git fetch origin
git reset --hard origin/main   # discards local edits — stash first if you care
```

**Start / restart the shell:**

```sh
qs -c caelestia kill
qs -c caelestia -n -d
```

**Follow logs:**

```sh
qs -c caelestia log
```

> **Note:** if you already use Caelestia, installing over `~/.config/quickshell/caelestia` replaces your
> user copy. The packaged shell in `/etc/xdg/quickshell/caelestia` is untouched, so removing this
> directory restores stock behaviour.

---

## Configuration outside this repo

These live in `~/.config/caelestia/` (the Caelestia *user config*, separate from the shell QML) and are
part of this setup:

| File | What's set |
|---|---|
| `shell.json` | `services.weatherUnits: "Celsius"`, `services.sensorUnits: "Celsius"`, `services.weatherLocation` (empty = auto via IP until you pick a place in the UI) |
| `hypr-vars.lua` | `touchpadScrollFactor = 0.7` — the packaged default of `0.3` needs a lot of force; `1.0` is unscaled |
| `hypr-user.lua` | Written by **Settings → Display** — see [below](#settings--display) |

---

## Feature details

### Weather in °C + location picker

The shell never shows Fahrenheit: `services.weatherUnits` is pinned to `Celsius` in `shell.json`.

The location itself is pickable — `services/Weather.qml` gained a search API (city/region lookup, explicit
selection, and IP-based fallback when nothing is chosen), exposed as a form on the
**Settings → Language and region** page. Whatever you select is written to
`services.weatherLocation` in `shell.json`; clear it to go back to automatic IP lookup.

### Natural trackpad scrolling

Two halves:

1. **`~/.config/caelestia/hypr-vars.lua`** → `touchpadScrollFactor = 0.7`
2. **`components/controls/CustomMouseArea.qml`** — scroll deltas are accumulated at full resolution and
   only a step is emitted once a whole unit has accumulated, so slow two-finger scrolling moves smoothly
   instead of jumping in coarse notches (upstream rounds each event independently, which makes touchpad
   scrolling feel sticky).

### Clearing notifications from the lock screen

While locked, the notification dock now has:

- a filled **`clear_all`** button in the dock header (shown only when there is something to clear and
  `lock.hideNotifs` is off),
- a **`✕`** on each notification group header to dismiss just that group.

Bulk clearing runs one group at a time on a 15–80 ms cadence (scaled by group count) so the removal
animations don't all fire in the same frame.

### Settings → Updates

- Lists pending upgrades from `checkupdates`, name on the left, version range on the right. Read-only by
  design.
- **Check for updates** re-runs the check; **Update system** launches
  `paru -Syu` *inside your configured terminal* (`general.apps.terminal`) — nothing privileged ever runs
  in the shell process.
- Shows the last-checked time and the command it will run.

### Settings → Plugins

The shell can load extra QML widgets at runtime. See [Writing a plugin](#writing-a-plugin) for the format.

The page shows, per plugin: name, description, loaded/off status and a toggle; plus **Open plugins folder**
and **Scan for plugins**. Toggling updates the state file and the plugin appears/disappears immediately —
no restart. The enabled count is surfaced in **Settings → About**.

- Plugins live in: `~/.local/share/caelestia/plugins/*.qml`
- State lives in: `~/.local/state/caelestia/plugins.json` — a JSON array of absolute paths of the
  *enabled* plugins (hand-editing it works too; the shell reloads when it changes)

### Settings → Display

- Shows output name/make/model, resolution, refresh rate, scale and position for the focused output,
  plus pickers for **Resolution & refresh rate** and **Scale** (0.75×–2×).
- Picking a value applies it **immediately** through
  `hyprctl eval "hl.monitor({ output = '…', mode = '…', position = '…', scale = … })"`.
- Every change is *provisional*: a **"Confirm change"** card appears with a 15-second countdown.
  - **Keep these settings** → stops the timer and persists.
  - **Revert now** → rolls back immediately.
  - Let the countdown expire → rolls back automatically.
- Persistence writes a marker-delimited block into `~/.config/caelestia/hypr-user.lua`, which Hyprland
  loads at startup. The block is rewritten in place (never duplicated):

  ```lua
  -- >>> caelestia:display (managed by the shell, do not edit) >>>
  hl.monitor({
      output = "eDP-1",
      mode = "1366x768@60.06",
      position = "0x0",
      scale = 1,
  })
  -- <<< caelestia:display <<<
  ```

  Don't edit or delete just one of the markers — the shell rewrites everything between them as a unit.

---

## Writing a plugin

A plugin is a single `.qml` file dropped into `~/.local/share/caelestia/plugins/`.

Rules:

1. The **root object must be an `Item`** (or a subclass) — plugins that aren't are skipped with a warning.
2. An optional first-line comment `// Description: …` is shown in Settings → Plugins.
3. Plugins are **display-only**: they render above your windows in the shell's content layer but sit
   outside the input mask, so they never swallow clicks.

Minimal example (`~/.local/share/caelestia/plugins/hello.qml`):

```qml
// Description: Sample plugin: greets you from the bottom right corner

import QtQuick

Item {
    Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 48
        width: helloText.implicitWidth + 32
        height: helloText.implicitHeight + 18
        radius: 12
        color: "#cc1e1e2e"

        Text {
            id: helloText

            anchors.centerIn: parent
            text: "Hello from a plugin!"
            color: "white"
            font.pixelSize: 15
        }
    }
}
```

Then either toggle it on in **Settings → Plugins** or add it to the state file:

```sh
mkdir -p ~/.local/share/caelestia/plugins ~/.local/state/caelestia
echo '["'"$HOME"'/.local/share/caelestia/plugins/hello.qml"]' > ~/.local/state/caelestia/plugins.json
```

**Useful imports inside a plugin:** `QtQuick`, `Caelestia.Config` (tokens/colours), `qs.components`,
`qs.services`. Check `qs -c caelestia log` if your plugin doesn't appear.

---

## Working on this copy

**Every QML change needs a shell restart** — upstream ships `settings.watchFiles: false` in
`shell.qml`:

```sh
qs -c caelestia kill && qs -c caelestia -n -d
qs -c caelestia log | grep -iE "error|caused"
```

If you edit frequently, flip `settings.watchFiles` to `true` in `shell.qml` for hot reload — note that
every save reloads the whole config, so a syntax error blanks the shell mid-edit.

Workflow notes that matter in this codebase:

- `qmllint` isn't usable here (quickshell synthesises `qmldir` at startup), so verify changes at runtime
  through the log rather than statically.
- `PageBase` has `default property Item contentChild`: only **one** `Item` child is allowed at page root —
  `Process`, `Timer`, `FileView`, `Variants`, `IpcHandler` etc. must be declared inside the page's
  `ColumnLayout`.
- `anchors.top/bottom/left/right` always return a non-null anchor line even when unset; only `anchors.fill`
  is safe for "is this item anchored?" checks.
- ListView delegates here don't self-size — anchor them to `list.list.contentItem.left/right`.
- QML's JS engine (QV4) lacks some modern built-ins (`String.prototype.trimEnd`, for example); use
  `replace(/\s+$/, "")` instead.

**Git history:** the `baseline` tag is the pristine `caelestia-shell 2.5.0` as shipped in `/etc`, and every
feature after it is its own commit, so you can always diff against stock:

```sh
git diff baseline..HEAD          # everything custom
git show baseline:modules/nexus/pages/UpdatesPage.qml   # (won't exist — placeholder had none)
```

---

## Syncing with the packaged upstream

When `caelestia-shell` is updated by the distro, `/etc/xdg/quickshell/caelestia` changes but this copy
doesn't. The helper script keeps them comparable:

```sh
~/.config/quickshell/sync-upstream.sh --check    # what upstream changed since baseline, and what I changed
~/.config/quickshell/sync-upstream.sh --update   # rebase local changes onto the current /etc copy
```

`--update` snapshots `/etc` onto an `upstream` branch and rebases your commits; conflicts, if any, are left
for you to resolve.

---

## Controlling the shell from the CLI

```sh
qs -c caelestia ipc call nexus open                 # open the Nexus settings window
qs -c caelestia ipc call lock lock                  # lock the session
qs -c caelestia ipc call lock unlock                # unlock it
qs -c caelestia ipc call lock isLocked              # query
qs -c caelestia ipc call toaster info "T" "msg"     # toast notifications
```

Other useful state:

- Plugin state: `~/.local/state/caelestia/plugins.json`
- Weather/location and everything else: `~/.config/caelestia/shell.json`

---

## Project layout

```
~/.config/quickshell/caelestia/
├── shell.qml                  # entry point (settings.watchFiles lives here)
├── assets/                    # icons, images, fonts metadata
├── components/                # reusable primitives (controls, containers, effects)
│   └── controls/CustomMouseArea.qml     # ← scroll accumulation fix
├── modules/
│   ├── bar/                   # the status bar
│   ├── drawers/               # overlay layers
│   │   ├── ContentWindow.qml  # ← hosts plugins
│   │   └── PluginLayer.qml    # ← renders enabled plugins
│   ├── lock/                  # lock screen
│   │   ├── NotifDock.qml      # ← clear-all button
│   │   └── NotifGroup.qml     # ← per-group clear
│   ├── nexus/                 # the settings window
│   │   ├── NavPane.qml / NexusState.qml / PageRegistry.qml
│   │   ├── common/            # PageBase, InfoRow, ItemList, SelectRow …
│   │   └── pages/
│   │       ├── UpdatesPage.qml        # ← new
│   │       ├── PluginsPage.qml        # ← new
│   │       ├── DisplayPage.qml        # ← new
│   │       ├── AboutPage.qml          # ← plugin count wired
│   │       └── …                      # upstream pages
│   └── Shortcuts.qml          # IPC handlers
├── services/                  # singletons (Weather, Notifs, Hypr, …)
│   └── Plugins.qml            # ← new: plugin discovery + state
└── utils/
```

---

## Troubleshooting

**Plugin doesn't show up**
Root isn't an `Item`, or the file has a syntax error — check `qs -c caelestia log` for a `PluginLayer`
warning. Also confirm the path is enabled in `~/.local/state/caelestia/plugins.json`.

**A settings page fails to load**
`qs -c caelestia log | grep -iE "error|caused"` prints the QML error chain with file and line. The shell
still starts and falls back to the previous page.

**Display changes revert after 15 seconds**
Working as intended — press **Keep these settings**. If nothing is visible, the confirm card sits below the
page fold; scroll down after picking a mode.

**Lock screen has no clear button**
There is nothing to clear, or `lock.hideNotifs` is enabled in your config.

**Weather shows no data**
The shell queries `api.open-meteo.com`; a transient `Service Unavailable` (or no network) leaves the last
value in place. `services.weatherLocation` empty means "locate me by IP".

**Scrolling feels too fast/slow**
Adjust `touchpadScrollFactor` in `~/.config/caelestia/hypr-vars.lua`, then reload Hyprland config.

**Everything above is upstream behaviour too?**
Run `~/.config/quickshell/sync-upstream.sh --check` — anything not listed under "Packaged files changed
since your baseline" is a local modification, and `git diff baseline..HEAD` shows exactly what.

---

## License and credits

GPL-3.0-only — inherited from upstream; see [LICENSE](./LICENSE).

Built on:

- **[Caelestia shell](https://github.com/caelestia-dots/shell)** — the desktop shell this copy is based on
- **[Quickshell](https://quickshell.org/)** — the QML shell framework
- **[Hyprland](https://hyprland.org/)** — the compositor

Improvements here are offered under the same GPL-3.0-only licence.
