# Lucifer GTK Window

A tabbed GTK3 window that renders CLI command output in monospace.

Each tab runs a shell command, displays the result, and optionally auto-refreshes. Tab titles can also be generated from a script. The project is self-contained — bundled LGI is included in `lgi/`, no system install needed.

**App ID:** `luci.sixsixsix.wm.gtkwindow`

## Usage

```sh
lua main.lua [config_path]
```

Config search order:
1. CLI argument
2. `~/.config/luci-sixsixsix-wm-gtkwindow/config.lua`
3. `config.lua` next to the script

## Config

```lua
return {
  title = "Lucifer GTK Window",   -- window header bar title

  tabs = {
    {
      command = "curl -s wttr.in?0",
      fallback = "Weather unavailable",
      titleScript = "echo '🌤 Weather'",
      titleFallback = "Weather",
      interval = 300,                     -- auto-refresh seconds; 0 = no refresh
      contentFont = "JetBrainsMono Nerd Font Mono",
      contentFontSize = 11,
      tabTitleFont = "sans-serif",
      tabTitleFontSize = 12,
    },
    -- more tabs...
  },
}
```

### Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `command` | string | yes | Shell command. Output displayed in tab. |
| `fallback` | string | yes | Text shown if `command` fails or is nil. |
| `titleScript` | string \| nil | no | Shell command for tab label. `nil` = skip, use `titleFallback`. |
| `titleFallback` | string | no | Tab label if `titleScript` is nil or fails. Default `"Tab N"`. |
| `interval` | number | no | Auto-refresh in seconds. `0` = fetch once, no refresh. |
| `contentFont` | string | no | Font for tab content area. Default `"JetBrainsMono Nerd Font Mono"`. |
| `contentFontSize` | number | no | Content font size in pt. Default `12`. |
| `tabTitleFont` | string | no | Font for tab labels. Default `"sans-serif"`. |
| `tabTitleFontSize` | number | no | Tab label font size in pt. Default `12`. |

### Behavior

- `command` and `titleScript`: if nil, not called at all — fallback used directly.
- Tabs are lazy-loaded: content is fetched only when a tab is first viewed.
- On auto-refresh, both content and tab title update.
- Window size defaults to 720×480 (or first tab's `width`/`height`).
- Content font CSS fallback chain: `[contentFont] → Noto Color Emoji → monospace`
- Tab title font CSS fallback chain: `[tabTitleFont] → Noto Color Emoji → emoji`

## Project structure

```
luci-sixsixsix-wm-gtkwindow/
├── main.lua           # Entry point — sets up local LGI paths, creates GTK app
├── config.lua         # Default config (3 tabs: weather, BTC, system info)
├── lgi.lua            # LGI loader (entry point for require("lgi"))
├── lgi/               # Bundled patched LGI (self-contained, no system install)
│   ├── corelgilua51.so   # C module (built for Lua 5.5)
│   ├── *.lua             # Core LGI modules
│   └── override/         # GTK/GLib/GObject overrides
├── pkg/
│   ├── lua-lgi-patched/  # Arch PKGBUILD (if you want system-wide LGI install)
│   │   ├── PKGBUILD
│   │   ├── lua55-const-loop-var.patch
│   │   └── glib287-enum-iteration.patch
│   └── luci-sixsixsix-wm-gtkwindow/  # Arch PKGBUILD for this app
│       └── PKGBUILD
└── README.md
```

## Bundled LGI patches

The `lgi/` directory contains LGI 0.9.2.r128 (git) with three patches applied:

1. **Lua 5.5 const-variable fix** — Loop variables are read-only in 5.5. Three files reassign loop vars inside `for` bodies:
   - `component.lua`: `en` → `local en` / `local en_name`
   - `override/Gtk.lua`: `column` → `local col`
   - `override/GObject-Value.lua`: `name` → `local lname`

2. **GLib 2.87+ enum fix** — `ffi.lua`: `enum_class.values` changed from a record array to a table in GLib 2.87. Added `GLib.check_version(2, 87, 0)` conditional: `core.record.fromarray()` on older GLib, `ipairs()` on newer. Also fixes `TypeClass.ref` → `TypeClass.get` (no ref leak).

3. **C module compiled for Lua 5.5** — `corelgilua51.so` built against Lua 5.5 headers (`lua_newuserdatauv` API).

## System install (optional)

If you'd rather install LGI globally (so other Lua projects can use it too):

```sh
cd pkg/lua-lgi-patched && makepkg -sf && sudo pacman -U *.pkg.tar.zst
```

This replaces `lua-lgi` system-wide with the patched version.