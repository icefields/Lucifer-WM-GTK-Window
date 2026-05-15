# LGIwindow

A tabbed GTK3 window that renders CLI command output in monospace.

Each tab runs a shell command, displays the result, and optionally auto-refreshes. Tab titles can also be generated from a script.

## Prerequisites

- Lua 5.5
- GTK3
- **Patched LGI** (installed via `install.sh`)

The stock `lua-lgi` package is broken on Lua 5.5 (const loop variables) and has issues with modern GLib. The `lua-lgi-git` AUR package only targets Lua 5.4 and has an enum iteration bug. Our patched bundle fixes all of this.

### Install LGI

```sh
sudo sh install.sh
```

Verify:

```sh
lua -e 'require("lgi"); print("LGI OK")'
```

## Usage

```sh
lua main.lua [config_path]
```

Config defaults to `./config.lua`.

## Config

```lua
return {
  title = "LGIwindow",   -- window title (header bar)

  tabs = {
    {
      command = "curl -s wttr.in?0",    -- shell command to run
      fallback = "Weather unavailable",  -- shown if command fails
      titleScript = "echo '🌤 Weather'", -- script for tab title (nil = use titleFallback)
      titleFallback = "Weather",          -- tab title if titleScript fails or is nil
      interval = 300,                     -- auto-refresh seconds; 0 = fetch once, no refresh
      font = "JetBrains Mono 12",        -- monospace font (CSS applied)
    },
    -- more tabs...
  },
}
```

### Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `command` | string | yes | Shell command to execute. Output is displayed in the tab. |
| `fallback` | string | yes | Text shown if `command` fails or returns empty. |
| `titleScript` | string \| nil | no | Shell command to generate the tab label. Output becomes the tab title. Set to `nil` to skip and use `titleFallback` directly. |
| `titleFallback` | string | no | Tab label if `titleScript` is nil or fails. Defaults to `"Tab N"`. |
| `interval` | number | no | Auto-refresh interval in seconds. `0` = no auto-refresh (fetch once on startup). |
| `font` | string | no | CSS font value. Applied as `font-family: monospace; font-size: Npt`. Default `"Monospace 12"`. |

### Behavior

- `command` and `titleScript` are run via `io.popen()`. If either is `nil`, it's not called at all — the fallback is used directly.
- On auto-refresh, both content and tab title are updated.
- Window size uses the first tab's `width`/`height` (if set), defaults to 720×480.

## Architecture

```
LGIwindow/
├── main.lua        # Entry point — GTK app with tabbed notebook
├── config.lua      # User configuration (tabs, commands, intervals)
├── install.sh      # Installs patched LGI for Lua 5.5
├── lgi-bundle/     # Bundled LGI files for install.sh
│   ├── lgi.lua
│   ├── lgi/        # Lua modules (class, component, override, etc.)
│   └── corelgilua51.so  # C module (compiled for Lua 5.5)
└── README.md
```

### How it works

1. **Config loading** — `dofile()` loads the config table. Each entry in `tabs` defines one notebook tab.
2. **GTK Application** — Uses `Gtk.Application` with `on_startup`/`on_activate` pattern. A `Gtk.Notebook` holds all tabs.
3. **Tab creation** — For each tab:
   - `titleScript` runs via `io.popen()`. If nil or it fails, `titleFallback` is used.
   - `command` runs via `io.popen()`. If it fails, `fallback` is used.
   - Content goes in a `Gtk.Label` inside a `Gtk.ScrolledWindow`.
   - CSS applies `font-family: monospace` with the configured font size.
4. **Auto-refresh** — If `interval > 0`, `GLib.timeout_add_seconds()` schedules periodic re-execution of both `command` and `titleScript`.

### Key LGI patterns used

- `Gtk.Application({ application_id = ... })` — main app singleton
- `function App:on_activate()` — called when window is ready
- `Gtk.Notebook:append_page(child, tab_label)` — add tabs
- `Gtk.CssProvider:load_from_data(css, #css)` — runtime CSS
- `GLib.timeout_add_seconds(priority, seconds, callback)` — periodic refresh
- `io.popen(cmd .. " 2>&1")` — capture command stdout+stderr

### LGI patching details

The `lgi-bundle/` contains the git version of LGI (0.9.2.r128) with three patches applied:

1. **Lua 5.5 const-variable fix** — Loop variables are read-only in Lua 5.5. Three files reassign loop vars inside `for` bodies:
   - `component.lua`: `en` reassigned → use `local en` / `local en_name`
   - `override/Gtk.lua`: `column` reassigned → use `local col`
   - `override/GObject-Value.lua`: `name` reassigned → use `local lname`

2. **GLib 2.87+ enum fix** — `ffi.lua` from the older `lua-lgi` package includes a `GLib.check_version(2, 87, 0)` check that uses `ipairs()` for enum iteration on newer GLib (where `enum_class.values` is a table, not a record). The git version lacks this check.

3. **C module rebuilt for Lua 5.5** — The `.so` was compiled targeting `lua_newuserdatauv` (Lua 5.4+ API) with Lua 5.5 headers.