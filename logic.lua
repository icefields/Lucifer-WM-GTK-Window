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

-- Lazy-load tracker
function M.createLoadTracker()
  local loaded = {}
  return {
    isLoaded = function(i) return loaded[i] == true end,
    markLoaded = function(i) loaded[i] = true end,
    reset = function() for k in pairs(loaded) do loaded[k] = nil end end,
    count = function()
      local n = 0
      for _ in pairs(loaded) do n = n + 1 end
      return n
    end,
  }
end

-- Validate config structure
function M.validateConfig(config)
  if type(config) ~= "table" then
    return false, "config must be a table"
  end
  local tabs = config.tabs or {}
  for i, tab in ipairs(tabs) do
    if type(tab.command) ~= "string" and type(tab.command) ~= "nil" then
      return false, "tab " .. i .. ": command must be string or nil"
    end
    if tab.command == "" then
      return false, "tab " .. i .. ": command must not be empty string"
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

-- Resolve script directory (testable version)
function M.resolveScriptDir(source, arg0)
  local dir = source:match("^@(.*/)")
  if not dir then
    dir = arg0 and arg0:match("^(.*/)") or "./"
  end
  if not dir:find("^/") then
    local handle = io.popen("pwd")
    local cwd = handle:read("*a"):gsub("\n$", "")
    handle:close()
    dir = cwd .. "/" .. dir
  end
  return dir
end

return M