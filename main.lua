#!/usr/bin/env lua
-- LGIwindow: Tabbed GTK window rendering CLI command output in monospace
-- Usage: lua main.lua [config_path]
--        config_path defaults to ./config.lua

local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "3.0")
local GLib = lgi.require("GLib", "2.0")
local Pango = lgi.require("Pango", "1.0")

-- Load config
local this_dir = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
local configPath = arg[1] or (this_dir .. "config.lua")
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
    local cmd = tab.command
    local fallback = tab.fallback or "N/A"
    local titleScript = tab.titleScript
    local titleFallback = tab.titleFallback or ("Tab " .. i)
    local interval = tab.interval or 0
    local font = tab.font or "Monospace 12"

    -- Extract font size for CSS
    local fontSize = font:match("(%d+)") or "12"

    -- Get initial tab title
    local tabTitle = runOrFallback(titleScript, titleFallback)

    -- Tab label
    local tabLabel = Gtk.Label({
      visible = true,
      label = tabTitle
    })

    -- Content label
    local contentLabel = Gtk.Label({
      visible = true,
      label = fallback,
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

    -- Per-label CSS for monospace font
    local cssProvider = Gtk.CssProvider()
    local css = "label { font-family: monospace; font-size: " .. fontSize .. "pt; }"
    cssProvider:load_from_data(css, #css)
    local styleContext = contentLabel:get_style_context()
    styleContext:add_provider(cssProvider, 600)

    -- Scrollable container
    local scrolled = Gtk.ScrolledWindow({
      visible = true,
      hscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
      vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
      propagate_natural_width = true,
      propagate_natural_height = true
    })
    scrolled:add(contentLabel)

    -- Initial content fetch
    local content = runOrFallback(cmd, fallback)
    contentLabel:set_text(content)

    -- Auto-refresh
    if interval > 0 then
      GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, interval, function()
        local newContent = runOrFallback(cmd, fallback)
        contentLabel:set_text(newContent)
        local newTitle = runOrFallback(titleScript, titleFallback)
        tabLabel:set_text(newTitle)
        return true
      end)
    end

    notebook:append_page(scrolled, tabLabel)
  end

  window:add(notebook)
  window:present()
end

return App:run(arg)