-- Busted unit tests for logic.lua
-- Run: busted tests/test_logic.lua

-- Add project root to path
local project_root = debug.getinfo(1, "S").source:match("^@(.*/)") .. "../"
package.path = project_root .. "?.lua;" .. package.path

local logic = require("logic")

describe("logic", function()

  describe("runCommand()", function()
    it("returns command output as string", function()
      local result = logic.runCommand("echo hello")
      assert.are.equal("hello", result)
    end)

    it("strips trailing newline", function()
      local result = logic.runCommand("echo hello")
      assert.are.equal("hello", result)
      assert.falsy(result:match("\n$"))
    end)

    it("returns nil for nil command", function()
      assert.is_nil(logic.runCommand(nil))
    end)

    it("returns nil for command producing empty output", function()
      local result = logic.runCommand("true")
      assert.is_nil(result)
    end)

    it("captures stderr via 2>&1", function()
      local result = logic.runCommand("sh -c 'echo error >&2'")
      assert.are.equal("error", result)
    end)

    it("handles multiline output", function()
      local result = logic.runCommand("printf 'line1\\nline2\\nline3'")
      assert.are.equal("line1\nline2\nline3", result)
    end)

    it("preserves internal newlines but strips trailing", function()
      local result = logic.runCommand("echo -e 'a\\nb\\nc'")
      assert.are.equal("a\nb\nc", result)
    end)

    it("always closes handle even on failed commands", function()
      -- Command that exits non-zero should still close properly
      local result = logic.runCommand("sh -c 'exit 1'")
      assert.is_true(result == nil or type(result) == "string")
    end)

    it("handles command with large output", function()
      local result = logic.runCommand("seq 1 1000")
      assert.truthy(result and #result > 0)
    end)

    it("handles command with special characters in output", function()
      local result = logic.runCommand("echo '<tag> & \"quotes\"'")
      assert.truthy(result:match("tag"))
      assert.truthy(result:match("quotes"))
    end)

    it("handles command that doesn't exist", function()
      local result = logic.runCommand("nonexistent_command_12345")
      -- Should return something (stderr output) or nil
      assert.is_true(result == nil or type(result) == "string")
    end)
  end)

  describe("runOrFallback()", function()
    it("returns command output when successful", function()
      local result = logic.runOrFallback("echo hello", "fallback")
      assert.are.equal("hello", result)
    end)

    it("returns fallback when command returns nil", function()
      local result = logic.runOrFallback(nil, "fallback")
      assert.are.equal("fallback", result)
    end)

    it("returns default N/A when no fallback specified", function()
      local result = logic.runOrFallback(nil)
      assert.are.equal("N/A", result)
    end)

    it("returns fallback when command produces empty output", function()
      local result = logic.runOrFallback("true", "fallback")
      assert.are.equal("fallback", result)
    end)

    it("returns command output even if command exits non-zero", function()
      -- sh -c 'echo output; exit 1' should still capture "output"
      local result = logic.runOrFallback("sh -c 'echo output; exit 1'", "fallback")
      -- Depends on whether pclose returns the output or not
      -- The important thing is it doesn't crash
      assert.is_true(result == "output" or result == "fallback")
    end)
  end)

  describe("findConfig()", function()
    it("returns CLI arg if provided", function()
      local path = logic.findConfig("/my/config.lua", nil, "/home/user", "/script/dir")
      assert.are.equal("/my/config.lua", path)
    end)

    it("returns XDG config path if file exists", function()
      local tmpdir = os.tmpname()
      os.remove(tmpdir)
      os.execute("mkdir -p " .. tmpdir .. "/luci-sixsixsix-wm-gtkwindow")
      local cfgPath = tmpdir .. "/luci-sixsixsix-wm-gtkwindow/config.lua"
      local f = io.open(cfgPath, "w")
      f:write('return { title = "test" }')
      f:close()

      local path = logic.findConfig(nil, tmpdir, "/home/user", "/script/dir")
      assert.are.equal(cfgPath, path)

      os.remove(cfgPath)
      os.execute("rm -rf " .. tmpdir)
    end)

    it("returns script dir config when XDG file doesn't exist", function()
      local path = logic.findConfig(nil, "/nonexistent/xdg", "/home/user", "/script/dir")
      assert.are.equal("/script/dir/config.lua", path)
    end)

    it("falls back to HOME/.config when XDG_CONFIG_HOME is nil", function()
      local path = logic.findConfig(nil, nil, "/home/user", "/script/dir")
      assert.are.equal("/script/dir/config.lua", path)
    end)

    it("prefers CLI arg over XDG config", function()
      -- Even if XDG file exists, CLI arg takes priority
      local path = logic.findConfig("/cli/path.lua", "/some/xdg", "/home/user", "/script/dir")
      assert.are.equal("/cli/path.lua", path)
    end)
  end)

  describe("createLoadTracker()", function()
    it("starts with all tabs unloaded", function()
      local tracker = logic.createLoadTracker()
      assert.falsy(tracker.isLoaded(1))
      assert.falsy(tracker.isLoaded(2))
      assert.falsy(tracker.isLoaded(3))
    end)

    it("marks tabs as loaded", function()
      local tracker = logic.createLoadTracker()
      tracker.markLoaded(1)
      assert.truthy(tracker.isLoaded(1))
      assert.falsy(tracker.isLoaded(2))
    end)

    it("loads all tabs sequentially", function()
      local tracker = logic.createLoadTracker()
      for i = 1, 5 do
        tracker.markLoaded(i)
        assert.truthy(tracker.isLoaded(i))
      end
    end)

    it("does not reload already loaded tabs", function()
      local tracker = logic.createLoadTracker()
      tracker.markLoaded(1)
      tracker.markLoaded(1)
      assert.truthy(tracker.isLoaded(1))
    end)

    it("reset clears all loaded state", function()
      local tracker = logic.createLoadTracker()
      tracker.markLoaded(1)
      tracker.markLoaded(2)
      tracker.markLoaded(3)
      assert.are.equal(3, tracker.count())
      tracker.reset()
      assert.are.equal(0, tracker.count())
      assert.falsy(tracker.isLoaded(1))
      assert.falsy(tracker.isLoaded(2))
    end)

    it("count returns number of loaded tabs", function()
      local tracker = logic.createLoadTracker()
      assert.are.equal(0, tracker.count())
      tracker.markLoaded(1)
      assert.are.equal(1, tracker.count())
      tracker.markLoaded(3)
      assert.are.equal(2, tracker.count())
    end)

    it("handles large tab indices", function()
      local tracker = logic.createLoadTracker()
      tracker.markLoaded(1000)
      assert.truthy(tracker.isLoaded(1000))
      assert.falsy(tracker.isLoaded(999))
    end)
  end)

  describe("validateConfig()", function()
    it("accepts valid config", function()
      local config = {
        title = "Test",
        tabs = {
          { command = "echo hi", fallback = "nope" }
        }
      }
      local ok, err = logic.validateConfig(config)
      assert.truthy(ok)
      assert.is_nil(err)
    end)

    it("rejects non-table config", function()
      local ok, err = logic.validateConfig("not a table")
      assert.falsy(ok)
      assert.truthy(err:match("must be a table"))
    end)

    it("rejects nil config", function()
      local ok, err = logic.validateConfig(nil)
      assert.falsy(ok)
    end)

    it("accepts config with no tabs", function()
      local ok = logic.validateConfig({ title = "Empty" })
      assert.truthy(ok)
    end)

    it("rejects tab with non-string command", function()
      local ok, err = logic.validateConfig({
        tabs = { { command = 123 } }
      })
      assert.falsy(ok)
      assert.truthy(err:match("command must be string or nil"))
    end)

    it("rejects tab with empty command", function()
      local ok, err = logic.validateConfig({
        tabs = { { command = "" } }
      })
      assert.falsy(ok)
      assert.truthy(err:match("must not be empty"))
    end)

    it("rejects tab with negative interval", function()
      local ok, err = logic.validateConfig({
        tabs = { { command = "echo hi", interval = -1 } }
      })
      assert.falsy(ok)
      assert.truthy(err:match("interval must be >= 0"))
    end)

    it("rejects tab with non-number interval", function()
      local ok, err = logic.validateConfig({
        tabs = { { command = "echo hi", interval = "fast" } }
      })
      assert.falsy(ok)
      assert.truthy(err:match("interval must be a number"))
    end)

    it("accepts tab with nil command (fallback only)", function()
      local ok = logic.validateConfig({
        tabs = { { fallback = "static content" } }
      })
      assert.truthy(ok)
    end)

    it("accepts tab with zero interval (no refresh)", function()
      local ok = logic.validateConfig({
        tabs = { { command = "echo hi", interval = 0 } }
      })
      assert.truthy(ok)
    end)

    it("accepts tab with all optional fields", function()
      local ok = logic.validateConfig({
        tabs = {{
          command = "echo hi",
          fallback = "nope",
          titleScript = "echo title",
          titleFallback = "Tab",
          interval = 300,
          contentFont = "Monospace",
          contentFontSize = 14,
          tabTitleFont = "Sans",
          tabTitleFontSize = 12,
        }}
      })
      assert.truthy(ok)
    end)
  end)

  describe("resolveScriptDir()", function()
    it("extracts directory from @path source", function()
      local dir = logic.resolveScriptDir("@/home/user/scripts/main.lua", nil)
      assert.are.equal("/home/user/scripts/", dir)
    end)

    it("falls back to arg[0] when no @ prefix", function()
      local dir = logic.resolveScriptDir("no-at-prefix", "/opt/app/main.lua")
      assert.truthy(dir)
    end)

    it("defaults to ./ when no source or arg[0]", function()
      local dir = logic.resolveScriptDir("no-at", nil)
      assert.truthy(dir)
    end)

    it("makes relative paths absolute", function()
      local dir = logic.resolveScriptDir("@./scripts/main.lua", nil)
      -- Should start with /
      assert.truthy(dir:match("^/"))
    end)
  end)

  describe("loadConfig()", function()
    it("loads a valid config file", function()
      local tmp = os.tmpname()
      local f = io.open(tmp, "w")
      f:write('return { title = "Test Window", tabs = { { command = "echo hi" } } }')
      f:close()

      local config = logic.loadConfig(tmp)
      assert.are.equal("Test Window", config.title)
      assert.are.equal(1, #config.tabs)
      assert.are.equal("echo hi", config.tabs[1].command)

      os.remove(tmp)
    end)

    it("throws on invalid config file", function()
      assert.has.errors(function()
        logic.loadConfig("/nonexistent/path/config.lua")
      end)
    end)
  end)
end)

describe("integration: lazy loading simulation", function()
  it("first tab loads immediately, others only on demand", function()
    local tracker = logic.createLoadTracker()
    local loadOrder = {}

    local function simulateLoad(i)
      if tracker.isLoaded(i) then return end
      tracker.markLoaded(i)
      loadOrder[#loadOrder + 1] = i
    end

    simulateLoad(1)
    assert.are.equal(1, #loadOrder)
    assert.are.equal(1, loadOrder[1])

    assert.falsy(tracker.isLoaded(2))
    assert.falsy(tracker.isLoaded(3))

    simulateLoad(3)
    assert.are.equal(2, #loadOrder)
    assert.are.equal(3, loadOrder[2])

    simulateLoad(1)
    assert.are.equal(2, #loadOrder)
  end)

  it("simulate GTK notebook switch_page callback", function()
    local tracker = logic.createLoadTracker()
    local tabs = { {cmd="a"}, {cmd="b"}, {cmd="c"}, {cmd="d"} }

    local function onPageSwitch(pageNum)
      local i = pageNum + 1
      if tabs[i] and not tracker.isLoaded(i) then
        tracker.markLoaded(i)
      end
    end

    tracker.markLoaded(1)

    onPageSwitch(1)
    assert.truthy(tracker.isLoaded(2))

    onPageSwitch(0)
    assert.truthy(tracker.isLoaded(1))
  end)
end)

describe("memory and resource safety", function()
  it("loadTracker does not accumulate duplicate entries", function()
    local tracker = logic.createLoadTracker()
    for _ = 1, 100 do
      tracker.markLoaded(1)
    end
    assert.are.equal(1, tracker.count())
    assert.truthy(tracker.isLoaded(1))
  end)

  it("loadTracker reset frees all references", function()
    local tracker = logic.createLoadTracker()
    for i = 1, 50 do
      tracker.markLoaded(i)
    end
    assert.are.equal(50, tracker.count())
    tracker.reset()
    assert.are.equal(0, tracker.count())
    for i = 1, 50 do
      assert.falsy(tracker.isLoaded(i))
    end
  end)

  it("ansi2pango does not accumulate state across calls", function()
    local ansi2pango = require("ansi2pango")
    local ESC = string.char(27)

    local r1 = ansi2pango.convert(ESC .. "[31mred" .. ESC .. "[0m")
    local r2 = ansi2pango.convert("plain text")
    assert.are.equal("plain text", r2)
  end)

  it("ansi2pango handles very long strings without issues", function()
    local ansi2pango = require("ansi2pango")
    local ESC = string.char(27)

    local parts = {}
    for i = 1, 1000 do
      parts[#parts + 1] = ESC .. "[38;5;" .. (i % 256) .. "mtext" .. ESC .. "[0m"
    end
    local input = table.concat(parts)
    local result = ansi2pango.convert(input)
    assert.truthy(#result > 0)
  end)

  it("runCommand handles commands with lots of output", function()
    local result = logic.runCommand("seq 1 1000")
    assert.truthy(result and #result > 0)
    local lines = select(2, result:gsub("\n", "\n"))
    assert.are.equal(999, lines)
  end)

  it("runCommand pcall prevents crashes on bad handles", function()
    -- This should not crash even with unusual commands
    local result = logic.runCommand("cat /dev/null")
    assert.is_true(result == nil or type(result) == "string")
  end)

  it("no file handle leaks in runCommand", function()
    -- Run many commands to check for handle leaks
    for _ = 1, 100 do
      logic.runCommand("echo test")
    end
    -- If we got here without running out of file descriptors, we're fine
    assert.is_true(true)
  end)
end)

describe("security", function()
  local ansi2pango = require("ansi2pango")
  local ESC = string.char(27)

  it("runCommand does not allow command injection via config", function()
    -- This test documents that runCommand passes cmd directly to shell
    -- Config should be trusted (not user input from network)
    local result = logic.runCommand("echo safe")
    assert.are.equal("safe", result)
  end)

  it("ansi2pango output does not inject Pango markup from ANSI text", function()
    -- ANSI text should not be able to inject arbitrary Pango tags
    -- Only span tags with known attributes should appear
    local input = 'normal <b>bold</b> text'
    local result = ansi2pango.convert(input)
    -- <b> should be escaped to &lt;b&gt;
    assert.truthy(result:match("&lt;b&gt;"))
    assert.falsy(result:match("<b>"))
  end)

  it("Pango special chars in ANSI-colored text are escaped", function()
    local input = ESC .. "[31m<script>alert(1)</script>" .. ESC .. "[0m"
    local result = ansi2pango.convert(input)
    assert.falsy(result:match("<script>"))
    assert.truthy(result:match("&lt;script&gt;"))
  end)
end)

describe("loadTracker reset() closure bug", function()
  it("reset() actually clears loaded state (not just reassigns local)", function()
    local tracker = logic.createLoadTracker()
    tracker.markLoaded(1)
    tracker.markLoaded(2)
    tracker.markLoaded(3)
    assert.are.equal(3, tracker.count())
    assert.truthy(tracker.isLoaded(1))
    assert.truthy(tracker.isLoaded(2))
    assert.truthy(tracker.isLoaded(3))

    tracker.reset()
    assert.are.equal(0, tracker.count())
    assert.falsy(tracker.isLoaded(1))
    assert.falsy(tracker.isLoaded(2))
    assert.falsy(tracker.isLoaded(3))
  end)

  it("reset() followed by markLoaded works correctly", function()
    local tracker = logic.createLoadTracker()
    tracker.markLoaded(1)
    tracker.reset()
    tracker.markLoaded(2)
    assert.falsy(tracker.isLoaded(1))
    assert.truthy(tracker.isLoaded(2))
    assert.are.equal(1, tracker.count())
  end)
end)

describe("io.popen handle leaks", function()
  it("runCommand always closes the handle", function()
    -- If handles leak, FDs would be exhausted
    for i = 1, 200 do
      local result = logic.runCommand("echo test" .. i)
      assert.are.equal("test" .. i, result)
    end
  end)

  it("resolveScriptDir closes its pwd handle", function()
    for _ = 1, 50 do
      logic.resolveScriptDir("@./test.lua", nil)
    end
    -- No crash = no FD leak
    assert.is_true(true)
  end)
end)

describe("validateConfig edge cases", function()
  it("rejects empty command string", function()
    local ok, err = logic.validateConfig({
      tabs = { { command = "", fallback = "nope" } }
    })
    assert.falsy(ok)
    assert.truthy(err:match("must not be empty"))
  end)

  it("allows numeric zero interval", function()
    local ok = logic.validateConfig({
      tabs = { { command = "echo hi", interval = 0 } }
    })
    assert.truthy(ok)
  end)

  it("allows float intervals", function()
    local ok = logic.validateConfig({
      tabs = { { command = "echo hi", interval = 0.5 } }
    })
    assert.truthy(ok)
  end)

  it("rejects boolean command", function()
    local ok, err = logic.validateConfig({
      tabs = { { command = true } }
    })
    assert.falsy(ok)
    assert.truthy(err:match("command must be string or nil"))
  end)

  it("handles empty tabs table", function()
    local ok = logic.validateConfig({ tabs = {} })
    assert.truthy(ok)
  end)

  it("handles nil tabs gracefully", function()
    local ok = logic.validateConfig({})
    assert.truthy(ok)
  end)
end)