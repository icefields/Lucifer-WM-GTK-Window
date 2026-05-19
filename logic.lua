--- Pure logic for LGIwindow (testable without GTK)
-- Extracted from main.lua for unit testing

local M = {}

-- Run a shell command; returns nil if cmd is nil or on failure
-- Uses pcall to ensure handle is always closed even on read errors
function M.runCommand(cmd)
  if not cmd then return nil end
  local handle, err = io.popen(cmd .. " 2>&1")
  if not handle then return nil end
  local ok, result = pcall(handle.read, handle, "*a")
  handle:close()
  if not ok then return nil end
  if result and result ~= "" then
    return result:gsub("\n$", "")
  end
  return nil
end

-- Run command or return fallback
function M.runOrFallback(cmd, fallback)
  local result = M.runCommand(cmd)
  if result then return result end
  return fallback or "N/A"
end

-- Config search: 1) CLI arg, 2) XDG config dir, 3) fallback path
function M.findConfig(arg1, xdgConfigHome, homeDir, scriptDir)
  if arg1 then return arg1 end
  local xdg = xdgConfigHome or (homeDir .. "/.config")
  local xdgPath = xdg .. "/luci-sixsixsix-wm-gtkwindow/config.lua"
  local f = io.open(xdgPath, "r")
  if f then f:close(); return xdgPath end
  return (scriptDir or ".") .. "/config.lua"
end

-- Load config from a path
function M.loadConfig(path)
  return dofile(path)
end

--- Flatten a nested tab config into a linear list of display entries.
-- Each entry is one of:
--   { type = "leaf", command = ..., titleScript = ..., ... }
--   { type = "group", titleScript = ..., titleFallback = ..., childNotebookIdx = N }
-- Groups with a single child are inlined as leaf entries.
-- Returns: flat list, childNotebooks (list of { children = [...] })
function M.flattenTabs(tabs)
  local flat = {}
  local childNotebooks = {}

  for i, tab in ipairs(tabs) do
    if tab.children and #tab.children > 0 then
      if #tab.children == 1 then
        local child = M.mergeDefaults(tab.children[1], tab)
        child.type = "leaf"
        flat[#flat + 1] = child
      else
        local groupEntry = {
          type = "group",
          titleScript = tab.titleScript,
          titleFallback = tab.titleFallback or ("Tab " .. i),
          contentFont = tab.contentFont,
          contentFontSize = tab.contentFontSize,
          tabTitleFont = tab.tabTitleFont,
          tabTitleFontSize = tab.tabTitleFontSize,
          interval = tab.interval,
        }
        flat[#flat + 1] = groupEntry

        local childEntries = {}
        for j, child in ipairs(tab.children) do
          local entry = M.mergeDefaults(child, tab)
          entry.type = "leaf"
          childEntries[#childEntries + 1] = entry
        end

        childNotebooks[#childNotebooks + 1] = { children = childEntries }
        groupEntry.childNotebookIdx = #childNotebooks
      end
    else
      local entry = {}
      for k, v in pairs(tab) do entry[k] = v end
      entry.type = "leaf"
      flat[#flat + 1] = entry
    end
  end

  return flat, childNotebooks
end

--- Merge child config with parent defaults.
-- Child values take priority; parent provides fallbacks.
-- Excludes: children, command, fallback, titleScript, titleFallback
function M.mergeDefaults(child, parent)
  local merged = {}
  for k, v in pairs(parent) do
    if k ~= "children" and k ~= "command" and k ~= "fallback"
       and k ~= "titleScript" and k ~= "titleFallback" then
      merged[k] = v
    end
  end
  for k, v in pairs(child) do
    merged[k] = v
  end
  return merged
end

-- Validate config structure
function M.validateConfig(config)
  if type(config) ~= "table" then
    return false, "config must be a table"
  end
  local tabs = config.tabs or {}
  for i, tab in ipairs(tabs) do
    if tab.children then
      if type(tab.children) ~= "table" then
        return false, "tab " .. i .. ": children must be a table"
      end
      for j, child in ipairs(tab.children) do
        if type(child.command) ~= "string" and type(child.command) ~= "nil" then
          return false, "tab " .. i .. " child " .. j .. ": command must be string or nil"
        end
        if child.command == "" then
          return false, "tab " .. i .. " child " .. j .. ": command must not be empty string"
        end
      end
    else
      if type(tab.command) ~= "string" and type(tab.command) ~= "nil" then
        return false, "tab " .. i .. ": command must be string or nil"
      end
      if tab.command == "" then
        return false, "tab " .. i .. ": command must not be empty string"
      end
    end
    if tab.interval and type(tab.interval) ~= "number" then
      return false, "tab " .. i .. ": interval must be a number"
    end
    if tab.interval and tab.interval < 0 then
      return false, "tab " .. i .. ": interval must be >= 0"
    end
  end
  return true
end

return M