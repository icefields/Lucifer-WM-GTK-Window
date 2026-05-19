#!/usr/bin/env lua
-- Lucifer GTK Window: Tabbed GTK window rendering CLI command output in monospace
-- Supports nested tabs: groups with children create a secondary notebook row.
-- Single-child groups are inlined (no secondary row).
-- Content is lazy-loaded (except first visible tab). Titles are loaded immediately.
-- Usage: lua main.lua [config_path]

-- Resolve the script's directory (works when called from any path)
local this_dir = debug.getinfo(1, "S").source:match("^@(.*/)")
if not this_dir then
  this_dir = arg[0] and arg[0]:match("^(.*/)") or "./"
end
if not this_dir:find("^/") then
  local h = io.popen("pwd")
  local cwd = h:read("*a"):gsub("\n$", "")
  h:close()
  this_dir = cwd .. "/" .. this_dir
end

package.path = this_dir .. "?.lua;" .. this_dir .. "lgi/?.lua;" .. package.path
package.cpath = this_dir .. "lgi/?.so;" .. package.cpath

local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "3.0")
local GLib = lgi.require("GLib", "2.0")
local Pango = lgi.require("Pango", "1.0")
local ansi2pango = require("ansi2pango")
local logic = require("logic")

-- Config
local configPath = logic.findConfig(arg[1], os.getenv("XDG_CONFIG_HOME"), os.getenv("HOME"), this_dir)
local config = logic.loadConfig(configPath)

local rawTabs = config.tabs or {}
local winTitle = config.title or "Lucifer GTK Window"
local winWidth = config.width or 720
local winHeight = config.height or 480

-- Flatten nested config into linear entries + child notebook definitions
local flatTabs, childNotebooks = logic.flattenTabs(rawTabs)

-- Default values
local DEFAULTS = {
  contentFont = "JetBrainsMono Nerd Font Mono",
  contentFontSize = 11,
  tabTitleFont = "sans-serif",
  tabTitleFontSize = 12,
  fallback = "N/A",
  interval = 0,
}

local function getVal(entry, key)
  if entry[key] ~= nil then return entry[key] end
  return DEFAULTS[key]
end

local function applyCss(widget, cssText)
  local cssProvider = Gtk.CssProvider()
  cssProvider:load_from_data(cssText, #cssText)
  widget:get_style_context():add_provider(cssProvider, 600)
end

-- Content loading state: loadId -> boolean
local contentLoaded = {}

-- Widget references: loadId -> { contentLabel, tabLabel, entry }
local widgets = {}

local nextLoadId = 0

local function createContentLabel(entry)
  local font = getVal(entry, "contentFont")
  local size = getVal(entry, "contentFontSize")
  local label = Gtk.Label({
    visible = true,
    label = "Loading...",
    selectable = false,
    halign = Gtk.Align.START,
    valign = Gtk.Align.START,
    xalign = 0,
    yalign = 0,
    wrap = true,
    wrap_mode = Pango.WrapMode.WORD_CHAR,
    margin_top = 10,
    margin_bottom = 10,
    margin_start = 10,
    margin_end = 10,
  })
  applyCss(label, "label { font-family: '" .. font:gsub("'", "\\'") .. "', 'Noto Color Emoji', monospace; font-size: " .. size .. "pt; }")
  return label
end

local function createTabLabel(entry)
  local font = getVal(entry, "tabTitleFont")
  local size = getVal(entry, "tabTitleFontSize")
  local fallback = getVal(entry, "titleFallback") or "Tab"
  local label = Gtk.Label({ visible = true, label = fallback })
  applyCss(label, "label { font-family: '" .. font:gsub("'", "\\'") .. "', 'Noto Color Emoji', emoji; font-size: " .. size .. "pt; }")
  return label
end

local function wrapScrolled(child)
  local scrolled = Gtk.ScrolledWindow({
    visible = true,
    hscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
    vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
    propagate_natural_width = true,
    propagate_natural_height = true,
  })
  scrolled:add(child)
  return scrolled
end

local function loadTitle(entry, tabLabel)
  local fallback = getVal(entry, "titleFallback") or "Tab"
  tabLabel:set_text(logic.runOrFallback(entry.titleScript, fallback))
end

local function loadContent(loadId, entry, contentLabel)
  if contentLoaded[loadId] then return end
  contentLoaded[loadId] = true
  contentLabel:set_markup(ansi2pango.convert(logic.runOrFallback(entry.command, getVal(entry, "fallback"))))
end

local function setupRefresh(loadId, entry, contentLabel, tabLabel)
  local interval = getVal(entry, "interval")
  if interval <= 0 then return end
  local fallback = getVal(entry, "titleFallback") or "Tab"
  GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, interval, function()
    if not contentLoaded[loadId] then return true end
    contentLabel:set_markup(ansi2pango.convert(logic.runOrFallback(entry.command, getVal(entry, "fallback"))))
    tabLabel:set_text(logic.runOrFallback(entry.titleScript, fallback))
    return true
  end)
end

local function buildLeaf(entry)
  nextLoadId = nextLoadId + 1
  local loadId = nextLoadId
  local tabLabel = createTabLabel(entry)
  local contentLabel = createContentLabel(entry)
  widgets[loadId] = { contentLabel = contentLabel, tabLabel = tabLabel, entry = entry }
  loadTitle(entry, tabLabel)
  return loadId, tabLabel, contentLabel
end

-- Create the application
local App = Gtk.Application({ application_id = "luci.sixsixsix.wm.gtkwindow" })

function App:on_startup()
  local window = Gtk.ApplicationWindow({
    application = self,
    default_width = winWidth,
    default_height = winHeight,
    border_width = 0,
  })
  window:set_wmclass("luci-sixsixsix-wm-gtkwindow", "Lucifer GTK Window")
end

function App:on_activate()
  local window = self.active_window
  window:set_titlebar(Gtk.HeaderBar({
    visible = true,
    show_close_button = true,
    title = winTitle,
  }))

  local mainNotebook = Gtk.Notebook({
    visible = true,
    show_border = false,
    scrollable = true,
    tab_pos = Gtk.PositionType.TOP,
  })

  -- loadId tracking: main tab index -> loadId (nil for groups)
  local mainLoadIds = {}
  -- cnIdx -> { j -> loadId }
  local childLoadIds = {}
  -- loadId of first visible leaf (loaded immediately)
  local firstLoadId = nil

  for i, entry in ipairs(flatTabs) do
    if entry.type == "group" then
      local cnIdx = entry.childNotebookIdx
      local cnData = childNotebooks[cnIdx]

      local childNotebook = Gtk.Notebook({
        visible = true,
        show_border = false,
        scrollable = true,
        tab_pos = Gtk.PositionType.TOP,
      })

      childLoadIds[cnIdx] = {}

      for j, childEntry in ipairs(cnData.children) do
        local loadId, childTabLabel, childContentLabel = buildLeaf(childEntry)
        childLoadIds[cnIdx][j] = loadId
        setupRefresh(loadId, childEntry, childContentLabel, childTabLabel)
        childNotebook:append_page(wrapScrolled(childContentLabel), childTabLabel)
        if not firstLoadId then firstLoadId = loadId end
      end

      -- Load first child content immediately
      if #cnData.children > 0 then
        loadContent(childLoadIds[cnIdx][1], cnData.children[1],
                    widgets[childLoadIds[cnIdx][1]].contentLabel)
      end

      -- Child notebook lazy-load handler
      do local cn = cnData
        function childNotebook:on_switch_page(page, page_num)
          local j = page_num + 1
          local childEntry = cn.children[j]
          if childEntry and childLoadIds[cnIdx][j] then
            loadContent(childLoadIds[cnIdx][j], childEntry,
                        widgets[childLoadIds[cnIdx][j]].contentLabel)
          end
        end
      end

      local groupTabLabel = createTabLabel(entry)
      loadTitle(entry, groupTabLabel)
      mainNotebook:append_page(childNotebook, groupTabLabel)

    else
      -- Leaf tab
      local loadId, tabLabel, contentLabel = buildLeaf(entry)
      mainLoadIds[i] = loadId
      setupRefresh(loadId, entry, contentLabel, tabLabel)
      mainNotebook:append_page(wrapScrolled(contentLabel), tabLabel)
      if not firstLoadId then firstLoadId = loadId end
    end
  end

  -- Load first visible tab content
  if firstLoadId then
    loadContent(firstLoadId, widgets[firstLoadId].entry, widgets[firstLoadId].contentLabel)
  end

  -- Main notebook lazy-load handler
  function mainNotebook:on_switch_page(page, page_num)
    local i = page_num + 1
    local entry = flatTabs[i]
    if not entry then return end
    if entry.type == "leaf" and mainLoadIds[i] then
      loadContent(mainLoadIds[i], entry, widgets[mainLoadIds[i]].contentLabel)
    end
  end

  window:add(mainNotebook)
  window:present()
end

return App:run(arg)