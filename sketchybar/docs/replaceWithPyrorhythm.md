# Replace sketchybar with pyrorhythm/dotconfig (AeroSpace-adapted)

## Context

The user wants to wholesale-replace their current SketchyBar config (`/Users/taylorjones/.dotfiles/sketchybar`) with the one from `https://github.com/pyrorhythm/dotconfig/tree/master/sketchybar`, but keep AeroSpace as the window manager (pyrorhythm ships for Rift).

Both configs share the same FelixKratz SbarLua lineage (identical `colors.lua` / `default.lua` / `settings.lua` / `bar.lua` shape), so the structural overlap is high. The substantive deltas being adopted:

- **Visual style**: glassier bar (height 40, blur 64, 1px border, 16px margin, 16px corner radius) replacing the user's current (height 36, blur 10, no border, 23px corner radius, 50% alpha).
- **Widget set shrinks**: from 16 items to ~9. Dropping VPN, Brew, RAM, Network, Now Playing, Front App, and the custom C event providers (`cpu_load`, `network_load`, `menus`, `animate_flag`).
- **Code cleanup**: pyrorhythm's `helpers/utils.lua` introduces a shared `SETUP_POPUP()` helper and `IS_SYSTEM_SLEEPING` flag; `helpers/logger.lua` is more capable than the current `helpers/log.lua`.

User decisions captured:
- **Bring nothing over** from the current widget set.
- **No snapshot to `old/`** — rely on git history as the backup.
- **Spaces wiring**: keep `helpers/aerospace.lua` (the only file preserved from the current config) and rewrite `items/spaces.lua` to call its API instead of Rift's.

Intended outcome: a clean, simpler SbarLua config matching pyrorhythm's visual style and structure, with AeroSpace workspaces rendered by an adapted `spaces.lua`.

## Approach

### 1. Wipe and replace the config tree

Delete everything in `/Users/taylorjones/.dotfiles/sketchybar/` **except**:
- `helpers/aerospace.lua` — preserved for the spaces rewrite.
- `old/` — historical snapshots, leave untouched.
- `.claude/` — Claude project metadata.
- `backuprc` — leave alone (out of scope).

Then copy the pyrorhythm `sketchybar/` tree into place verbatim:
- Root: `sketchybarrc`, `init.lua`, `bar.lua`, `colors.lua`, `default.lua`, `icons.lua`, `settings.lua`, `sketchybar_types.lua`, `.luarc.json`
- `helpers/`: `init.lua`, `app_icons.lua`, `default_font.lua`, `logger.lua`, `utils.lua`, `makefile`
- `items/`: `init.lua`, `apple.lua`, `battery.lua`, `calendar.lua`, `cpu.lua`, `media.lua`, `menus.lua`, `spaces.lua` (to be rewritten — see below), `volume.lua`, `wifi.lua`

Skip:
- `riftapi/` submodule — replaced by `helpers/aerospace.lua`.

Source fetch: `gh api repos/pyrorhythm/dotconfig/contents/sketchybar/<path>` returns base64-encoded content per file — fetch each file individually since the repo has no submodule-friendly clone path for a subdir.

### 2. Restore `helpers/aerospace.lua` after the wipe

The pyrorhythm tree does not contain this file. Re-place the user's existing `helpers/aerospace.lua` (10,850 bytes) into the new `helpers/` directory. It exposes the AeroSpace API surface (`Aerospace.new`, `:query_workspaces`, `:list_apps`, `:list_windows`, `:focused_window`, etc.) that the rewritten spaces.lua will call.

### 3. Rewrite `items/spaces.lua` against AeroSpace

The pyrorhythm spaces.lua is structured cleanly enough that this is mostly a surgical swap. The mapping from Rift → AeroSpace:

| Pyrorhythm (Rift)                                  | AeroSpace replacement                                              |
| -------------------------------------------------- | ------------------------------------------------------------------ |
| `local rift = require("riftapi")`                  | `local aerospace = require("helpers.aerospace").new()`             |
| `rift.query.workspaces()` → `{index, is_active, windows[].app_name}` | `aerospace:query_workspaces()` — compose with `:list_windows(ws)` to get apps per workspace |
| `rift.workspace.switch(i)`                         | `os.execute("aerospace workspace " .. ws_name)`                    |
| `rift.workspace.create()` (right-click)            | No-op (AeroSpace workspaces are static in `~/.aerospace.toml`)     |
| `rift.subscribe({ "*" }, refresh)`                 | `SBAR.add("event", "aerospace_workspace_change")` + watcher subscribes to it. The user's `~/.aerospace.toml` must emit this via `exec-on-workspace-change`. |

Preserve pyrorhythm's structural choices:
- Pool-of-slots pattern (`MAX_WS = 10`, `MAX_APPS = 12`) with `make_num` / `make_app` / `make_bracket` factories.
- `paint()` / `hide()` / `render()` separation.
- `SBAR.delay(0.5, ...)` startup + retry-friendly init.
- Watcher subscribed to `{"front_app_switched", "space_change", "system_woke", "forced"}` in addition to AeroSpace events.
- `SBAR.animate("circ", 30, refresh)` on every event.

The retry-loop and NSScreen-to-display mapping from the user's current 360-line `workspaces.lua` are **not** carried over — they're tied to the user's bracket-per-display design, which pyrorhythm doesn't have. If multi-monitor display routing is needed it can be added in a follow-up.

### 4. Verify AeroSpace event emission

Check `~/.aerospace.toml` for an `exec-on-workspace-change` directive that fires `sketchybar --trigger aerospace_workspace_change`. The user's current `workspaces.lua` already depends on this, so it's almost certainly there — confirm before declaring the rewrite done.

## Critical files

Modified / replaced:
- `/Users/taylorjones/.dotfiles/sketchybar/sketchybarrc` (replace)
- `/Users/taylorjones/.dotfiles/sketchybar/init.lua` (replace)
- `/Users/taylorjones/.dotfiles/sketchybar/bar.lua` (replace)
- `/Users/taylorjones/.dotfiles/sketchybar/colors.lua` (replace)
- `/Users/taylorjones/.dotfiles/sketchybar/default.lua` (replace)
- `/Users/taylorjones/.dotfiles/sketchybar/icons.lua` (replace)
- `/Users/taylorjones/.dotfiles/sketchybar/settings.lua` (replace)
- `/Users/taylorjones/.dotfiles/sketchybar/sketchybar_types.lua` (new)
- `/Users/taylorjones/.dotfiles/sketchybar/.luarc.json` (new)
- `/Users/taylorjones/.dotfiles/sketchybar/helpers/{init.lua,app_icons.lua,default_font.lua,logger.lua,utils.lua,makefile}` (replace)
- `/Users/taylorjones/.dotfiles/sketchybar/items/{init.lua,apple.lua,battery.lua,calendar.lua,cpu.lua,media.lua,menus.lua,volume.lua,wifi.lua}` (replace; old `front_app.lua`, `vpn.lua`, `workspaces.lua`, `spaces.sh`, and `widgets/` directory deleted)
- `/Users/taylorjones/.dotfiles/sketchybar/items/spaces.lua` (rewrite — pyrorhythm structure, AeroSpace API)

Preserved:
- `/Users/taylorjones/.dotfiles/sketchybar/helpers/aerospace.lua` (10,850 bytes — drives the rewritten spaces.lua via `Aerospace.new`, `:query_workspaces`, `:list_windows`)
- `/Users/taylorjones/.dotfiles/sketchybar/old/` (historical snapshots)
- `/Users/taylorjones/.dotfiles/sketchybar/.claude/`, `backuprc`

External (read-only check):
- `~/.aerospace.toml` — verify `exec-on-workspace-change` triggers `aerospace_workspace_change`.

## Verification

1. **Syntactic check**: `lua -e 'package.path = "/Users/taylorjones/.dotfiles/sketchybar/?.lua;"..package.path; for _,f in ipairs({"bar","colors","default","icons","settings"}) do require(f) end'` — confirms the Lua modules at least parse.
2. **Reload**: `sketchybar --reload` (or kill + restart the sketchybar service). Watch stderr / `~/Library/Logs/sketchybar.log` for errors. Compile errors in `helpers/utils.lua` typically surface here.
3. **Visual smoke test**: Bar appears at top of screen with the glass style (translucent, 1px border, 16px corner radius). Apple logo on left, calendar on right.
4. **Workspace switching**: Trigger an AeroSpace workspace switch (`aerospace workspace 2` from terminal). The spaces.lua slots should re-render and the active workspace should highlight. The app icon for each running app in each workspace should appear.
5. **Subscribed events**: Open an app to trigger `front_app_switched`; close laptop and reopen for `system_woke` — the bar should re-render workspaces in response.
6. **Per-widget sanity**: Battery shows charge %, WiFi shows SSID, CPU shows utilization, Volume responds to volume keys, Calendar shows time. Media item (Spotify-backed) shows current track if Spotify is open.
7. **Failure mode to watch**: If `helpers/aerospace.lua` fails to connect on startup (AeroSpace not yet running), `spaces.lua` will silently fall through. The 0.5s delay should usually be enough but may need a retry loop if it flakes.

After approval, per the user's global CLAUDE.md ("Save plan files in the `docs/` directory of the project"), this plan file should be copied to `/Users/taylorjones/.dotfiles/sketchybar/docs/replaceWithPyrorhythm.md` as the first implementation step.
