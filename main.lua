#!/usr/bin/env lua
-- LGIwindow: Tabbed GTK window rendering CLI command output in monospace
-- Usage: lua main.lua [config_path]
--        config_path defaults to ~/.config/lgiwindow/config.lua
--
-- Tabs are lazy-loaded: content is fetched only when a tab is first viewed.

-- Set up local LGI paths (bundled in ./lgi/)
local this_dir = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
package.path = this_dir .. "lgi/?.lua;" .. package.path
package.cpath = this_dir .. "lgi/?.so;" .. package.cpath

local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "3.0")
local GLib = lgi.require("GLib", "2.0")
local Pango = lgi.require("Pango", "1.0")

-- Config search: 1) CLI arg, 2) XDG config dir, 3) same dir as script
local function findConfig()
  if arg[1] then return arg[1] end
  local xdg = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
  local xdgPath = xdg .. "/lgiwindow/config.lua"
  local f = io.open(xdgPath, "r")
  if f then f:close(); return xdgPath end
  return this_dir .. "config.lua"
end
local configPath = findConfig()
local config = dofile(configPath)

local tabs = config.tabs or {}
local winTitle = config.title or "LGIwindow"
local winWidth = tabs[1] and tabs[1].width or 720
local winHeight = tabs[1] and tabs[1].height or 480

-- Run a shell command; returns nil if cmd is nil or on failure
local function runCommand(cmd)
  if not cmd then return nil end
  local handle = io.popen(cmd .. " 2>&1")
  if not handle then return nil end
  local result = handle:read("*a")
  handle:close()
  if result and result ~= "" then
    return result:gsub("\n$", "")
  end
  return nil
end

-- Run command or return fallback
local function runOrFallback(cmd, fallback)
  local result = runCommand(cmd)
  if result then return result end
  return fallback or "N/A"
end

-- Track which tabs have been loaded
local loaded = {}

-- Widget references (indexed by tab number)
local tabLabels = {}
local contentLabels = {}

-- Fetch content and title for a tab, update the labels
local function loadTab(i)
  if loaded[i] then return end
  loaded[i] = true
  local tab = tabs[i]
  contentLabels[i]:set_text(runOrFallback(tab.command, tab.fallback or "N/A"))
  tabLabels[i]:set_text(runOrFallback(tab.titleScript, tab.titleFallback or ("Tab " .. i)))
end

-- Create the application
local App = Gtk.Application({
  application_id = "com.devilplan.lgiwindow"
})

function App:on_startup()
  Gtk.ApplicationWindow({
    application = self,
    default_width = winWidth,
    default_height = winHeight,
    border_width = 0
  })
end

function App:on_activate()
  local window = self.active_window
  window:set_titlebar(Gtk.HeaderBar({
    visible = true,
    show_close_button = true,
    title = winTitle
  }))

  local notebook = Gtk.Notebook({
    visible = true,
    show_border = false,
    scrollable = true,
    tab_pos = Gtk.PositionType.TOP
  })

  for i, tab in ipairs(tabs) do
    local titleFallback = tab.titleFallback or ("Tab " .. i)
    local interval = tab.interval or 0
    local contentFont = tab.contentFont or "JetBrainsMono Nerd Font Mono"
    local contentFontSize = tab.contentFontSize or 12
    local tabTitleFont = tab.tabTitleFont or "sans-serif"
    local tabTitleFontSize = tab.tabTitleFontSize or 12

    -- Tab label starts with fallback title; updated on first load
    local tabLabel = Gtk.Label({
      visible = true,
      label = titleFallback
    })
    tabLabels[i] = tabLabel

    -- Emoji font fallback for tab labels
    local tabCss = Gtk.CssProvider()
    local tabCssText = "label { font-family: '" .. tabTitleFont .. "', 'Noto Color Emoji', emoji; font-size: " .. tabTitleFontSize .. "pt; }"
    tabCss:load_from_data(tabCssText, #tabCssText)
    tabLabel:get_style_context():add_provider(tabCss, 600)

    local contentLabel = Gtk.Label({
      visible = true,
      label = "Loading...",
      selectable = true,
      halign = Gtk.Align.START,
      valign = Gtk.Align.START,
      xalign = 0,
      yalign = 0,
      wrap = true,
      wrap_mode = Pango.WrapMode.WORD_CHAR,
      margin_top = 10,
      margin_bottom = 10,
      margin_start = 10,
      margin_end = 10
    })
    contentLabels[i] = contentLabel

    -- Per-label CSS: use Nerd Font Mono for symbols, Noto Color Emoji for emoji
    local cssProvider = Gtk.CssProvider()
    local css = "label { font-family: '" .. contentFont .. "', 'Noto Color Emoji', monospace; font-size: " .. contentFontSize .. "pt; }"
    cssProvider:load_from_data(css, #css)
    contentLabel:get_style_context():add_provider(cssProvider, 600)

    local scrolled = Gtk.ScrolledWindow({
      visible = true,
      hscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
      vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
      propagate_natural_width = true,
      propagate_natural_height = true
    })
    scrolled:add(contentLabel)

    -- Auto-refresh (starts after first load)
    if interval > 0 then
      GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, interval, function()
        if not loaded[i] then return true end
        contentLabel:set_text(runOrFallback(tab.command, tab.fallback or "N/A"))
        tabLabel:set_text(runOrFallback(tab.titleScript, titleFallback))
        return true
      end)
    end

    notebook:append_page(scrolled, tabLabel)
  end

  -- Lazy-load: first tab immediately, others on switch
  if #tabs > 0 then
    loadTab(1)
  end

  function notebook:on_switch_page(page, page_num)
    local i = page_num + 1
    if tabs[i] and not loaded[i] then
      loadTab(i)
    end
  end

  window:add(notebook)
  window:present()
end

return App:run(arg)