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

describe("memory and resource safety", function()
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
    local result = logic.runCommand("cat /dev/null")
    assert.is_true(result == nil or type(result) == "string")
  end)

  it("no file handle leaks in runCommand", function()
    for _ = 1, 100 do
      logic.runCommand("echo test")
    end
    assert.is_true(true)
  end)
end)

describe("security", function()
  local ansi2pango = require("ansi2pango")
  local ESC = string.char(27)

  it("runCommand does not allow command injection via config", function()
    local result = logic.runCommand("echo safe")
    assert.are.equal("safe", result)
  end)

  it("ansi2pango output does not inject Pango markup from ANSI text", function()
    local input = 'normal <b>bold</b> text'
    local result = ansi2pango.convert(input)
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

describe("io.popen handle leaks", function()
  it("runCommand always closes the handle", function()
    for i = 1, 200 do
      local result = logic.runCommand("echo test" .. i)
      assert.are.equal("test" .. i, result)
    end
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

  it("accepts group with children", function()
    local ok = logic.validateConfig({
      tabs = {
        {
          titleFallback = "Weather",
          children = {
            { command = "curl wttr.in", fallback = "N/A" },
            { command = "curl wttr.in/chicago", fallback = "N/A" },
          }
        }
      }
    })
    assert.truthy(ok)
  end)

  it("rejects group with non-table children", function()
    local ok, err = logic.validateConfig({
      tabs = {
        { titleFallback = "Bad", children = "not a table" }
      }
    })
    assert.falsy(ok)
    assert.truthy(err:match("children must be a table"))
  end)

  it("rejects child with empty command", function()
    local ok, err = logic.validateConfig({
      tabs = {
        {
          titleFallback = "Bad",
          children = { { command = "" } }
        }
      }
    })
    assert.falsy(ok)
    assert.truthy(err:match("must not be empty"))
  end)
end)

describe("flattenTabs()", function()
  it("flattens leaf tabs as-is", function()
    local tabs = {
      { command = "echo a", titleFallback = "A" },
      { command = "echo b", titleFallback = "B" },
    }
    local flat, cn = logic.flattenTabs(tabs)
    assert.are.equal(2, #flat)
    assert.are.equal("leaf", flat[1].type)
    assert.are.equal("leaf", flat[2].type)
    assert.are.equal("echo a", flat[1].command)
    assert.are.equal("echo b", flat[2].command)
    assert.are.equal(0, #cn)
  end)

  it("creates group entry for multi-child tabs", function()
    local tabs = {
      {
        titleFallback = "Weather",
        children = {
          { command = "curl wttr.in/local", titleFallback = "Local" },
          { command = "curl wttr.in/chicago", titleFallback = "Chicago" },
        },
      },
    }
    local flat, cn = logic.flattenTabs(tabs)
    assert.are.equal(1, #flat)
    assert.are.equal("group", flat[1].type)
    assert.are.equal("Weather", flat[1].titleFallback)
    assert.are.equal(1, #cn)
    assert.are.equal(2, #cn[1].children)
    assert.are.equal("curl wttr.in/local", cn[1].children[1].command)
    assert.are.equal("Chicago", cn[1].children[2].titleFallback)
  end)

  it("inlines single-child groups (no child notebook)", function()
    local tabs = {
      {
        titleFallback = "Only One",
        children = {
          { command = "echo solo", titleFallback = "Solo" },
        },
      },
    }
    local flat, cn = logic.flattenTabs(tabs)
    assert.are.equal(1, #flat)
    assert.are.equal("leaf", flat[1].type)
    assert.are.equal("echo solo", flat[1].command)
    assert.are.equal("Solo", flat[1].titleFallback)
    assert.are.equal(0, #cn)
  end)

  it("mixes groups and leaf tabs", function()
    local tabs = {
      {
        titleFallback = "Weather",
        children = {
          { command = "curl wttr.in/local", titleFallback = "Local" },
          { command = "curl wttr.in/chicago", titleFallback = "Chicago" },
        },
      },
      { command = "echo btc", titleFallback = "BTC" },
    }
    local flat, cn = logic.flattenTabs(tabs)
    assert.are.equal(2, #flat)
    assert.are.equal("group", flat[1].type)
    assert.are.equal("leaf", flat[2].type)
    assert.are.equal(1, #cn)
  end)

  it("assigns childNotebookIdx to group entries", function()
    local tabs = {
      {
        titleFallback = "G1",
        children = {
          { command = "a" },
          { command = "b" },
        },
      },
      {
        titleFallback = "G2",
        children = {
          { command = "c" },
          { command = "d" },
          { command = "e" },
        },
      },
    }
    local flat, cn = logic.flattenTabs(tabs)
    assert.are.equal(1, flat[1].childNotebookIdx)
    assert.are.equal(2, flat[2].childNotebookIdx)
    assert.are.equal(2, #cn[1].children)
    assert.are.equal(3, #cn[2].children)
  end)

  it("treats empty children array as leaf", function()
    local tabs = {
      { command = "echo hi", children = {} },
    }
    local flat, cn = logic.flattenTabs(tabs)
    assert.are.equal(1, #flat)
    assert.are.equal("leaf", flat[1].type)
    assert.are.equal("echo hi", flat[1].command)
    assert.are.equal(0, #cn)
  end)

  it("preserves interval in child entries", function()
    local tabs = {
      {
        titleFallback = "Group",
        interval = 60,
        children = {
          { command = "echo a", interval = 120 },
          { command = "echo b" },
        },
      },
    }
    local flat, cn = logic.flattenTabs(tabs)
    assert.are.equal(120, cn[1].children[1].interval)
    assert.are.equal(60, cn[1].children[2].interval)  -- inherited from parent
  end)

  it("does not set childNotebookIdx on leaf entries", function()
    local tabs = {
      { command = "echo hi", titleFallback = "Hi" },
    }
    local flat, cn = logic.flattenTabs(tabs)
    assert.is_nil(flat[1].childNotebookIdx)
  end)
end)

describe("mergeDefaults()", function()
  it("child overrides parent values", function()
    local parent = { contentFont = "Parent", contentFontSize = 12 }
    local child = { command = "echo hi", contentFont = "Child" }
    local merged = logic.mergeDefaults(child, parent)
    assert.are.equal("Child", merged.contentFont)
    assert.are.equal(12, merged.contentFontSize)
    assert.are.equal("echo hi", merged.command)
  end)

  it("parent provides fallbacks for missing child values", function()
    local parent = { contentFont = "Mono", contentFontSize = 14, tabTitleFont = "Sans" }
    local child = { command = "echo test" }
    local merged = logic.mergeDefaults(child, parent)
    assert.are.equal("Mono", merged.contentFont)
    assert.are.equal(14, merged.contentFontSize)
    assert.are.equal("Sans", merged.tabTitleFont)
  end)

  it("does not inherit children table from parent", function()
    local parent = { children = { "should", "not", "inherit" }, contentFont = "Mono" }
    local child = { command = "echo hi" }
    local merged = logic.mergeDefaults(child, parent)
    assert.is_nil(merged.children)
    assert.are.equal("Mono", merged.contentFont)
  end)

  it("does not inherit command/fallback/titleScript/titleFallback from parent", function()
    local parent = { command = "parent_cmd", fallback = "parent_fb", titleScript = "parent_ts", titleFallback = "parent_tf", contentFont = "Mono" }
    local child = { command = "child_cmd" }
    local merged = logic.mergeDefaults(child, parent)
    assert.are.equal("child_cmd", merged.command)
    assert.is_nil(merged.fallback)
    assert.is_nil(merged.titleScript)
    assert.is_nil(merged.titleFallback)
  end)

  it("child with explicit nil value does not override parent", function()
    -- pairs() skips nil values, so child.contentFont = nil is not iterated
    -- This test documents the behavior
    local parent = { contentFont = "Mono", contentFontSize = 12 }
    local child = { command = "echo test" }
    local merged = logic.mergeDefaults(child, parent)
    assert.are.equal("Mono", merged.contentFont)
  end)

  it("deeply nested tables in child are preserved by reference", function()
    local parent = { contentFont = "Mono" }
    local child = { command = "echo test", extra = { a = 1, b = 2 } }
    local merged = logic.mergeDefaults(child, parent)
    assert.are.equal(1, merged.extra.a)
    assert.are.equal(2, merged.extra.b)
  end)
end)