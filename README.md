# Lucifer GTK Window

A tabbed GTK3 window that renders CLI command output in monospace, with full ANSI color support.

Each tab runs a shell command, displays the result (with colors), and optionally auto-refreshes. Tab titles can also be generated from a script. The project is self-contained — bundled LGI is included in `lgi/`, no system install needed.

**App ID:** `luci.sixsixsix.wm.gtkwindow`

## Usage

```sh
lua main.lua [config_path]
```

Config search order:
1. CLI argument
2. `~/.config/luci-sixsixsix-wm-gtkwindow/config.lua`
3. `config.lua` next to the script

## ANSI Color Support

Command output containing ANSI escape sequences (colors, bold, italic, underline) is automatically converted to Pango markup and rendered with full color in GTK labels. This means tools like `curl -s wttr.in?0` display with their original terminal colors.

Supported ANSI codes:
- **4-bit colors:** fg 30–37, bg 40–47, bright fg 90–97, bright bg 100–107
- **256-color:** `38;5;n` (fg), `48;5;n` (bg) — full color cube + grayscale
- **Truecolor RGB:** `38;2;r;g;b` (fg), `48;2;r;g;b` (bg)
- **Styles:** bold (1), italic (3), underline (4)
- **Style resets:** bold off (22), italic off (23), underline off (24)
- **Color resets:** default fg (39), default bg (49), full reset (0)

Plain text (no ANSI) passes through unchanged. Pango special characters (`&`, `<`, `>`, `'`) are always escaped.

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
| `command` | string | yes | Shell command. Output displayed in tab (ANSI colors supported). |
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
- First tab loads immediately on startup; others load when clicked.
- On auto-refresh, both content and tab title update.
- Window size defaults to 720×480 (or first tab's `width`/`height`).
- Content font CSS fallback chain: `[contentFont] → Noto Color Emoji → monospace`
- Tab title font CSS fallback chain: `[tabTitleFont] → Noto Color Emoji → emoji`

## Testing

Tests use [Busted](https://lunarmodules.github.io/busted/). Install it:

```sh
luarocks --lua-version 5.4 --local install busted
eval "$(luarocks path --bin --lua-version 5.4)"
```

Run the full suite from the project root:

```sh
busted tests/test_ansi2pango.lua tests/test_logic.lua
```

### Test coverage

**`tests/test_ansi2pango.lua`** — 88 tests

| Category | Tests | What's covered |
|---|---|---|
| Pango escaping | 4 | `&`, `<`, `>`, `'` in plain text |
| Plain text | 5 | Empty string, multiline, whitespace, Unicode, no-ANSI passthrough |
| Reset (code 0) | 5 | Full reset, `ESC[m`, resets fg/bg/bold |
| 4-bit fg colors (30–37) | 8 | All 8 standard foreground colors |
| 4-bit bg colors (40–47) | 8 | All 8 standard background colors |
| Bright fg colors (90–97) | 8 | All 8 bright foreground colors |
| Bright bg colors (100–107) | 8 | All 8 bright background colors |
| Text styles | 6 | Bold, italic, underline, bold-off (22), italic-off (23), underline-off (24) |
| 256-color mode | 9 | `38;5;n` / `48;5;n`, color cube, grayscale, wttr.in color 226 |
| Truecolor RGB | 3 | `38;2;r;g;b` fg, `48;2;r;g;b` bg, combined fg+bg |
| Default color reset | 2 | Code 39 (default fg), code 49 (default bg) |
| Combined attributes | 3 | Bold+color, bold+italic+fg+bg, multi-segment |
| Edge cases | 8 | Consecutive codes, trailing codes, multiple resets, malformed sequences, null bytes, empty between codes |
| Real-world wttr.in | 4 | 256-color weather icons, complex multi-color lines, bold+color, degree symbols |
| Color 256 internals | 3 | Boundaries (0, 15, 16, 231), grayscale (232, 255) |
| Pango validity | 2 | Span open/close balance, complex multi-span balance |

**`tests/test_logic.lua`** — 37 tests

| Category | Tests | What's covered |
|---|---|---|
| `runCommand` | 7 | Output capture, nil command, failing command, stderr capture, multiline, trailing newline strip |
| `runOrFallback` | 4 | Success, nil command, default N/A, empty output |
| `findConfig` | 4 | CLI arg priority, XDG path, script dir fallback, HOME fallback |
| `createLoadTracker` | 4 | Starts unloaded, marks loaded, sequential loads, idempotent marking |
| `validateConfig` | 6 | Valid config, non-table, empty tabs, bad command type, negative interval, nil command |
| `resolveScriptDir` | 3 | `@path` extraction, `arg[0]` fallback, default `./` |
| `loadConfig` | 2 | Valid file, missing file error |
| Lazy load simulation | 2 | First tab immediate, on-demand loading, no-reload guard |
| Memory leak prevention | 4 | No duplicate tracker entries, no state across convert calls, long strings, large output |

**Total: 125 tests, 0 failures**

## Project structure

```
luci-sixsixsix-wm-gtkwindow/
├── main.lua           # Entry point — GTK app, uses logic + ansi2pango modules
├── logic.lua          # Pure logic module (testable without GTK)
├── ansi2pango.lua     # ANSI escape → Pango markup converter
├── config.lua         # Default config (3 tabs: weather, BTC, system info)
├── lgi.lua            # LGI loader (entry point for require("lgi"))
├── lgi/               # Bundled patched LGI (self-contained, no system install)
│   ├── corelgilua51.so   # C module (built for Lua 5.5)
│   ├── *.lua             # Core LGI modules
│   └── override/         # GTK/GLib/GObject overrides
├── tests/
│   ├── test_ansi2pango.lua   # 88 tests for ANSI→Pango conversion
│   └── test_logic.lua        # 37 tests for pure logic module
├── pkg/
│   ├── lua-lgi-patched/      # Arch PKGBUILD (system-wide LGI install)
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