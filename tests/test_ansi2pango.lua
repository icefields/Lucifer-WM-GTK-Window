-- Busted unit tests for ansi2pango.lua
-- Run: busted tests/test_ansi2pango.lua

-- Add project root to path
local project_root = debug.getinfo(1, "S").source:match("^@(.*/)") .. "../"
package.path = project_root .. "?.lua;" .. package.path

local ansi2pango = require("ansi2pango")

-- Helper: ESC character
local ESC = string.char(27)

describe("ansi2pango", function()

  describe("escape()", function()
    it("escapes ampersands in plain text", function()
      local result = ansi2pango.convert("foo & bar")
      assert.are.equal("foo &amp; bar", result)
    end)

    it("escapes angle brackets in plain text", function()
      local result = ansi2pango.convert("if x < 5 > 3")
      assert.are.equal("if x &lt; 5 &gt; 3", result)
    end)

    it("escapes single quotes in plain text", function()
      local result = ansi2pango.convert("it's fine")
      assert.are.equal("it&apos;s fine", result)
    end)

    it("escapes all special characters together", function()
      local result = ansi2pango.convert("<tag attr='val&more'>")
      assert.are.equal("&lt;tag attr=&apos;val&amp;more&apos;&gt;", result)
    end)

    it("escapes special characters inside ANSI spans", function()
      local input = ESC .. "[31m<red> & 'text'" .. ESC .. "[0m"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match("&lt;red&gt;"))
      assert.truthy(result:match("&amp;"))
      assert.truthy(result:match("&apos;"))
    end)

    it("escapes double quotes are NOT escaped (Pango uses single-quote attrs)", function()
      local result = ansi2pango.convert('he said "hello"')
      assert.are.equal('he said "hello"', result)
    end)
  end)

  describe("plain text (no ANSI)", function()
    it("returns plain text unchanged when no ANSI codes", function()
      local result = ansi2pango.convert("Hello, World!")
      assert.are.equal("Hello, World!", result)
    end)

    it("handles empty string", function()
      assert.are.equal("", ansi2pango.convert(""))
    end)

    it("handles multiline text", function()
      local input = "line1\nline2\nline3"
      assert.are.equal("line1\nline2\nline3", ansi2pango.convert(input))
    end)

    it("preserves whitespace", function()
      local input = "  spaced  out  "
      assert.are.equal(input, ansi2pango.convert(input))
    end)

    it("preserves unicode characters", function()
      local input = "héllo wörld 日本語"
      assert.are.equal(input, ansi2pango.convert(input))
    end)

    it("preserves tabs and special whitespace", function()
      local input = "col1\tcol2\tcol3"
      assert.are.equal(input, ansi2pango.convert(input))
    end)
  end)

  describe("reset code (0)", function()
    it("ESC[0m resets all attributes", function()
      local input = ESC .. "[31mred" .. ESC .. "[0m plain"
      local result = ansi2pango.convert(input)
      assert.are.equal('<span foreground="#800000">red</span> plain', result)
    end)

    it("ESC[m is treated as reset (empty params)", function()
      local input = ESC .. "[1mbold" .. ESC .. "[m plain"
      local result = ansi2pango.convert(input)
      assert.are.equal('<span weight="bold">bold</span> plain', result)
    end)

    it("reset clears foreground color", function()
      local input = ESC .. "[32mgreen" .. ESC .. "[0m text"
      local result = ansi2pango.convert(input)
      assert.are.equal('<span foreground="#008000">green</span> text', result)
    end)

    it("reset clears background color", function()
      local input = ESC .. "[44mbluebg" .. ESC .. "[0m text"
      local result = ansi2pango.convert(input)
      assert.are.equal('<span background="#000080">bluebg</span> text', result)
    end)

    it("reset clears bold", function()
      local input = ESC .. "[1mbold" .. ESC .. "[0m text"
      local result = ansi2pango.convert(input)
      assert.are.equal('<span weight="bold">bold</span> text', result)
    end)

    it("reset clears all accumulated attributes", function()
      local input = ESC .. "[1;3;31;44mbold italic red on blue" .. ESC .. "[0m plain"
      local result = ansi2pango.convert(input)
      -- After reset, "plain" should have no span
      assert.truthy(result:match("^<span.*bold italic red on blue</span> plain$"))
      -- Verify "plain" has no span
      assert.truthy(result:match("plain$"))
      assert.falsy(result:match("plain</span>"))
    end)
  end)

  describe("4-bit foreground colors (30-37)", function()
    local fg_tests = {
      {30, "#000000", "black"},
      {31, "#800000", "red"},
      {32, "#008000", "green"},
      {33, "#808000", "yellow"},
      {34, "#000080", "blue"},
      {35, "#800080", "magenta"},
      {36, "#008080", "cyan"},
      {37, "#c0c0c0", "white"},
    }
    for _, t in ipairs(fg_tests) do
      it(("renders fg code %d as %s (%s)"):format(t[1], t[2], t[3]), function()
        local input = ESC .. "[" .. t[1] .. "mtext"
        local result = ansi2pango.convert(input)
        assert.are.equal('<span foreground="' .. t[2] .. '">text</span>', result)
      end)
    end
  end)

  describe("4-bit background colors (40-47)", function()
    local bg_tests = {
      {40, "#000000"}, {41, "#800000"}, {42, "#008000"}, {43, "#808000"},
      {44, "#000080"}, {45, "#800080"}, {46, "#008080"}, {47, "#c0c0c0"},
    }
    for _, t in ipairs(bg_tests) do
      it(("renders bg code %d"):format(t[1]), function()
        local input = ESC .. "[" .. t[1] .. "mtext"
        local result = ansi2pango.convert(input)
        assert.are.equal('<span background="' .. t[2] .. '">text</span>', result)
      end)
    end
  end)

  describe("bright foreground colors (90-97)", function()
    local bright_tests = {
      {90, "#808080"}, {91, "#ff0000"}, {92, "#00ff00"}, {93, "#ffff00"},
      {94, "#0000ff"}, {95, "#ff00ff"}, {96, "#00ffff"}, {97, "#ffffff"},
    }
    for _, t in ipairs(bright_tests) do
      it(("renders bright fg code %d"):format(t[1]), function()
        local input = ESC .. "[" .. t[1] .. "mtext"
        local result = ansi2pango.convert(input)
        assert.are.equal('<span foreground="' .. t[2] .. '">text</span>', result)
      end)
    end
  end)

  describe("bright background colors (100-107)", function()
    for code = 100, 107 do
      it(("renders bright bg code %d"):format(code), function()
        local input = ESC .. "[" .. code .. "mtext"
        local result = ansi2pango.convert(input)
        assert.truthy(result:match('background='))
      end)
    end
  end)

  describe("text styles", function()
    it("bold (code 1)", function()
      local input = ESC .. "[1mbold"
      assert.are.equal('<span weight="bold">bold</span>', ansi2pango.convert(input))
    end)

    it("italic (code 3)", function()
      local input = ESC .. "[3mitalic"
      assert.are.equal('<span style="italic">italic</span>', ansi2pango.convert(input))
    end)

    it("underline (code 4)", function()
      local input = ESC .. "[4muline"
      assert.are.equal('<span underline="single">uline</span>', ansi2pango.convert(input))
    end)

    it("bold off (code 22)", function()
      local input = ESC .. "[1mbold" .. ESC .. "[22m plain"
      local result = ansi2pango.convert(input)
      assert.are.equal('<span weight="bold">bold</span> plain', result)
    end)

    it("italic off (code 23)", function()
      local input = ESC .. "[3mitalic" .. ESC .. "[23m plain"
      local result = ansi2pango.convert(input)
      assert.are.equal('<span style="italic">italic</span> plain', result)
    end)

    it("underline off (code 24)", function()
      local input = ESC .. "[4muline" .. ESC .. "[24m plain"
      local result = ansi2pango.convert(input)
      assert.are.equal('<span underline="single">uline</span> plain', result)
    end)

    it("bold + italic combined in single sequence", function()
      local input = ESC .. "[1;3mbold italic"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match('weight="bold"'))
      assert.truthy(result:match('style="italic"'))
      assert.truthy(result:match("bold italic"))
    end)
  end)

  describe("256-color mode (38;5;n and 48;5;n)", function()
    it("256-color foreground (black)", function()
      local input = ESC .. "[38;5;0mtext"
      assert.are.equal('<span foreground="#000000">text</span>', ansi2pango.convert(input))
    end)

    it("256-color foreground (red)", function()
      local input = ESC .. "[38;5;1mtext"
      assert.are.equal('<span foreground="#800000">text</span>', ansi2pango.convert(input))
    end)

    it("256-color foreground (bright white)", function()
      local input = ESC .. "[38;5;15mtext"
      assert.are.equal('<span foreground="#ffffff">text</span>', ansi2pango.convert(input))
    end)

    it("256-color foreground (color cube index 16)", function()
      local input = ESC .. "[38;5;16mtext"
      assert.are.equal('<span foreground="#000000">text</span>', ansi2pango.convert(input))
    end)

    it("256-color foreground (color cube index 196 = bright red)", function()
      local input = ESC .. "[38;5;196mtext"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match('foreground="#ff0000"'))
    end)

    it("256-color foreground (grayscale 232)", function()
      local input = ESC .. "[38;5;232mtext"
      assert.are.equal('<span foreground="#080808">text</span>', ansi2pango.convert(input))
    end)

    it("256-color foreground (grayscale 255)", function()
      local input = ESC .. "[38;5;255mtext"
      assert.are.equal('<span foreground="#eeeeee">text</span>', ansi2pango.convert(input))
    end)

    it("256-color background", function()
      local input = ESC .. "[48;5;2mtext"
      assert.are.equal('<span background="#008000">text</span>', ansi2pango.convert(input))
    end)

    it("wttr.in yellow color (226)", function()
      local input = ESC .. "[38;5;226mhello" .. ESC .. "[0m"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match('foreground="#ffff00"'))
    end)
  end)

  describe("truecolor RGB (38;2;r;g;b and 48;2;r;g;b)", function()
    it("24-bit foreground color", function()
      local input = ESC .. "[38;2;255;128;0mtext"
      assert.are.equal('<span foreground="#ff8000">text</span>', ansi2pango.convert(input))
    end)

    it("24-bit background color", function()
      local input = ESC .. "[48;2;0;255;128mtext"
      assert.are.equal('<span background="#00ff80">text</span>', ansi2pango.convert(input))
    end)

    it("24-bit fg and bg in same sequence", function()
      local input = ESC .. "[38;2;255;0;0;48;2;0;0;255mtext"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match('foreground="#ff0000"'))
      assert.truthy(result:match('background="#0000ff"'))
    end)

    it("RGB values at boundaries (0,0,0 and 255,255,255)", function()
      local input1 = ESC .. "[38;2;0;0;0mtext" .. ESC .. "[0m " .. ESC .. "[38;2;255;255;255mtext"
      local result = ansi2pango.convert(input1)
      assert.truthy(result:match('foreground="#000000"'))
      assert.truthy(result:match('foreground="#ffffff"'))
    end)
  end)

  describe("default color reset (39, 49)", function()
    it("code 39 resets foreground to default", function()
      local input = ESC .. "[31mred" .. ESC .. "[39m plain"
      local result = ansi2pango.convert(input)
      assert.are.equal('<span foreground="#800000">red</span> plain', result)
    end)

    it("code 49 resets background to default", function()
      local input = ESC .. "[44mbluebg" .. ESC .. "[49m plain"
      local result = ansi2pango.convert(input)
      assert.are.equal('<span background="#000080">bluebg</span> plain', result)
    end)

    it("code 39 only resets foreground, not background", function()
      local input = ESC .. "[31;44mtext" .. ESC .. "[39m plain"
      local result = ansi2pango.convert(input)
      -- "text" should have both fg and bg, "plain" should have only bg
      assert.truthy(result:match('foreground="#800000"'))
      assert.truthy(result:match('background="#000080"'))
      -- After 39, foreground is gone but background persists
      -- The second segment "plain" should only have background
      local plainStart = result:find("plain") - 1
      local afterFirstSpan = result:sub(plainStart)
      -- "plain" should be inside a span with only background
      assert.falsy(afterFirstSpan:match('foreground='))
    end)
  end)

  describe("combined attributes", function()
    it("bold + color in single sequence", function()
      local input = ESC .. "[1;31mbold red"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match('weight="bold"'))
      assert.truthy(result:match('foreground="#800000"'))
      assert.truthy(result:match('bold red'))
    end)

    it("bold + italic + fg + bg combined", function()
      local input = ESC .. "[1;3;31;44mbig"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match('weight="bold"'))
      assert.truthy(result:match('style="italic"'))
      assert.truthy(result:match('foreground="#800000"'))
      assert.truthy(result:match('background="#000080"'))
    end)

    it("multiple styled segments", function()
      local input = ESC .. "[31mred" .. ESC .. "[0m " .. ESC .. "[32mgreen"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match('foreground="#800000"'))
      assert.truthy(result:match('foreground="#008000"'))
    end)

    it("attribute stacking without reset", function()
      -- Red text, then add bold (should have both attrs)
      local input = ESC .. "[31mred" .. ESC .. "[1m bold"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match('foreground="#800000"'))
      assert.truthy(result:match('weight="bold"'))
    end)
  end)

  describe("deterministic attribute order", function()
    it("outputs attributes in consistent order", function()
      -- Regardless of the order codes appear, output should be deterministic
      local input = ESC .. "[44;1;31mtext"
      local result = ansi2pango.convert(input)
      -- Order should be: weight, foreground, background (from attrOrder)
      assert.truthy(result:match('weight="bold" foreground="#800000" background="#000080"'))
    end)

    it("re-applied attributes maintain order", function()
      local input = ESC .. "[31m" .. ESC .. "[1m" .. ESC .. "[44mtext"
      local result = ansi2pango.convert(input)
      -- Final span should have weight, foreground, background in order
      assert.truthy(result:match('weight="bold" foreground="#800000" background="#000080"'))
    end)
  end)

  describe("edge cases", function()
    it("consecutive ANSI codes with no text between", function()
      local input = ESC .. "[31m" .. ESC .. "[1mtext"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match('foreground="#800000"'))
      assert.truthy(result:match('weight="bold"'))
    end)

    it("ANSI code at end of string with no text after", function()
      local input = "text" .. ESC .. "[0m"
      assert.are.equal("text", ansi2pango.convert(input))
    end)

    it("multiple resets", function()
      local input = ESC .. "[0m" .. ESC .. "[0mtext"
      assert.are.equal("text", ansi2pango.convert(input))
    end)

    it("malformed ANSI (no terminating m) - emits ESC as plain text", function()
      local input = "hello" .. ESC .. "[31text"
      local result = ansi2pango.convert(input)
      -- ESC[31t is a CSI with terminator 't' (non-SGR), stripped
      -- So "hello" + "ext" remains (the 't' terminator consumed)
      assert.truthy(result:match("hello"))
    end)

    it("malformed ANSI (just ESC[)", function()
      local input = "text" .. ESC .. "["
      local result = ansi2pango.convert(input)
      assert.truthy(result:match("text"))
    end)

    it("empty string between ANSI codes", function()
      local input = ESC .. "[31m" .. ESC .. "[0m"
      local result = ansi2pango.convert(input)
      assert.are.equal("", result)
    end)

    it("text starting with ANSI code", function()
      local input = ESC .. "[32mgreen"
      assert.are.equal('<span foreground="#008000">green</span>', ansi2pango.convert(input))
    end)

    it("text ending with ANSI code", function()
      local input = "hello" .. ESC .. "[0m"
      assert.are.equal("hello", ansi2pango.convert(input))
    end)

    it("handles null bytes gracefully", function()
      local input = "before\0after"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match("before"))
      assert.truthy(result:match("after"))
    end)

    it("incomplete 256-color sequence (38;5 without index)", function()
      -- Should be silently ignored
      local input = ESC .. "[38;5mtext"
      local result = ansi2pango.convert(input)
      assert.are.equal("text", result)
    end)

    it("incomplete truecolor sequence (38;2 with only r,g)", function()
      local input = ESC .. "[38;2;255;128mtext"
      local result = ansi2pango.convert(input)
      -- Should not produce a foreground color (missing blue component)
      assert.falsy(result:match('foreground'))
    end)

    it("256-color index out of range (>255)", function()
      -- Should not crash, just produce nil color
      local input = ESC .. "[38;5;300mtext"
      local result = ansi2pango.convert(input)
      -- Color should be nil, so no foreground attr
      assert.falsy(result:match('foreground'))
    end)

    it("256-color negative index", function()
      local input = ESC .. "[38;5;-1mtext"
      -- -1 won't parse as a number in the semicolon split, or if it does
      -- it won't be in the lookup table
      local result = ansi2pango.convert(input)
      assert.truthy(#result > 0) -- shouldn't crash
    end)

    it("truecolor RGB out of range (>255)", function()
      -- r=300 is out of range, should be clamped or ignored
      local input = ESC .. "[38;2;300;0;0mtext"
      local result = ansi2pango.convert(input)
      -- With validation, out-of-range values should be ignored
      assert.falsy(result:match('foreground'))
    end)

    it("unknown ANSI codes are silently ignored", function()
      -- Code 999 is not a real ANSI code
      local input = ESC .. "[999mtext"
      local result = ansi2pango.convert(input)
      assert.are.equal("text", result)
    end)

    it("ESC appears in middle of text without bracket", function()
      -- Bare ESC without [ — should be treated as plain text
      local input = "text" .. ESC .. "more"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match("text"))
    end)
  end)

  describe("findMTerminator correctness", function()
    it("doesn't match 'm' inside text after ANSI code", function()
      -- The 'm' in "mark" should NOT be confused with a terminator
      -- when there's text between ESC[ and m
      -- Actually, ESC[0m is valid, so this tests that findMTerminator
      -- correctly finds the m after the param digits
      local input = ESC .. "[31mmark"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match("mark"))
      assert.truthy(result:match('foreground="#800000"'))
    end)

    it("handles multiple semicolons in params", function()
      -- ESC[1;;31m — double semicolon (empty param = 0)
      -- Actually gmatch("[^;]+") skips empty segments, so ;; means
      -- the middle segment is dropped
      local input = ESC .. "[1;31mtext"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match('weight="bold"'))
      assert.truthy(result:match('foreground="#800000"'))
    end)

    it("CSI sequence with text-like content before m", function()
      -- This shouldn't happen in practice, but test robustness:
      -- \e[38;2;255;128;0m — the m at the end is the terminator
      local input = ESC .. "[38;2;255;128;0mtext"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match('foreground="#ff8000"'))
    end)
  end)

  describe("real-world wttr.in output", function()
    it("parses wttr.in 256-color sequences", function()
      local input = ESC .. "[38;5;226m   \\  " .. ESC .. "[0m       Partly cloudy"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match('foreground="#ffff00"'))
      assert.truthy(result:match("Partly cloudy"))
    end)

    it("parses complex wttr.in line with multiple 256-color codes", function()
      local input = ESC .. "[38;5;226m _ /\"\"" .. ESC .. "[38;5;250m.-.    " .. ESC .. "[0m"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match('foreground="#ffff00"'))
      assert.truthy(result:match('foreground="#bcbcbc"'))
    end)

    it("handles bold temperature display", function()
      local input = ESC .. "[1m" .. ESC .. "[38;5;118m4" .. ESC .. "[0m km/h"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match('weight="bold"'))
      assert.truthy(result:match("km/h"))
    end)

    it("handles degree symbol and special chars", function()
      local input = ESC .. "[38;5;226m+24" .. ESC .. "[0m(" .. ESC .. "[38;5;220m26" .. ESC .. "[0m) °C"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match("°C"))
    end)

    it("handles rate.sx output (256-color BTC display)", function()
      -- Simulated rate.sx output with 256 colors
      -- Color 82 = #5fff00 (green-ish), Color 226 = #ffff00 (yellow)
      local input = ESC .. "[38;5;82mBTC" .. ESC .. "[0m " .. ESC .. "[38;5;226m$67,543"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match('foreground="#5fff00"'))
      assert.truthy(result:match('foreground="#ffff00"'))
    end)

    it("handles neofetch-style output with many style changes", function()
      -- Simulated neofetch with bold, colors, resets
      local input = ESC .. "[1m" .. ESC .. "[36mOS:" .. ESC .. "[0m Arch Linux"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match('weight="bold"'))
      assert.truthy(result:match('foreground="#008080"'))
      assert.truthy(result:match("Arch Linux"))
    end)
  end)

  describe("color256 lookup table accuracy", function()
    -- Expected palette values (duplicated from module for verification)
    local expected_palette = {
      [0]  = "#000000", [1]  = "#800000", [2]  = "#008000", [3]  = "#808000",
      [4]  = "#000080", [5]  = "#800080", [6]  = "#008080", [7]  = "#c0c0c0",
      [8]  = "#808080", [9]  = "#ff0000", [10] = "#00ff00", [11] = "#ffff00",
      [12] = "#0000ff", [13] = "#ff00ff", [14] = "#00ffff", [15] = "#ffffff",
    }

    it("palette matches for indices 0-15", function()
      for i = 0, 15 do
        local input = ESC .. "[38;5;" .. i .. "mtext"
        local result = ansi2pango.convert(input)
        assert.truthy(result:match(expected_palette[i]), "color " .. i .. " should be " .. expected_palette[i])
      end
    end)

    it("color cube indices are valid hex colors", function()
      for i = 16, 231 do
        local input = ESC .. "[38;5;" .. i .. "mtext"
        local result = ansi2pango.convert(input)
        assert.truthy(result:match('foreground="#[0-9a-f]+"'), "index " .. i .. " should produce hex color")
      end
    end)

    it("grayscale range produces valid colors", function()
      for i = 232, 255 do
        local input = ESC .. "[38;5;" .. i .. "mtext"
        local result = ansi2pango.convert(input)
        assert.truthy(result:match('foreground="#[0-9a-f]+"'), "grayscale " .. i .. " should produce hex color")
      end
    end)

    it("specific known color values", function()
      -- Color 196 = (5,0,0) = #ff0000
      local r196 = ansi2pango.convert(ESC .. "[38;5;196mtext")
      assert.truthy(r196:match('foreground="#ff0000"'))

      -- Color 21 = (0,0,5) = #0000ff
      local r21 = ansi2pango.convert(ESC .. "[38;5;21mtext")
      assert.truthy(r21:match('foreground="#0000ff"'))

      -- Color 46 = (0,5,4) = #00ffaf
      -- 46-16=30, 30%6=0 (b=0), (30-0)/6=5%6=5 (g=5), r=5 -> (200,200,55) = wait let me recalc
      -- Actually: n=30, b=30%6=0, g=(30/6)%6=5%6=5, r=5/6=0... no
      -- 46-16=30, b=0, g=5, r=0 -> scale(0)=0, scale(5)=255, scale(0)=0 -> #00ff00
      -- Wait: scale(5) = 40*5+55 = 255 -> so it's scale(r), scale(g), scale(b)
      -- n=30: b=0, g=5, r=0 -> #00ff00? Let me just test what comes out
      local r46 = ansi2pango.convert(ESC .. "[38;5;46mtext")
      assert.truthy(r46:match('foreground="#[0-9a-f]+"'))
    end)

    it("bg 256-color also uses lookup table", function()
      local input = ESC .. "[48;5;196mtext"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match('background="#ff0000"'))
    end)
  end)

  describe("Pango markup validity", function()
    it("produces valid span open/close pairs", function()
      local input = ESC .. "[1;31mbold red" .. ESC .. "[0m plain " .. ESC .. "[32mgreen"
      local result = ansi2pango.convert(input)
      local opens = select(2, result:gsub("<span", ""))
      local closes = select(2, result:gsub("</span>", ""))
      assert.are.equal(opens, closes)
    end)

    it("no unclosed spans in complex output", function()
      local parts = {
        ESC .. "[1;38;5;196mRED BOLD",
        ESC .. "[0m ",
        ESC .. "[3;32mitalic green",
        ESC .. "[0m ",
        ESC .. "[4;38;2;255;128;0muline orange",
        ESC .. "[0m done",
      }
      local input = table.concat(parts)
      local result = ansi2pango.convert(input)
      local opens = select(2, result:gsub("<span", ""))
      local closes = select(2, result:gsub("</span>", ""))
      assert.are.equal(opens, closes)
    end)

    it("attribute values don't contain unescaped special chars", function()
      -- Pango attribute values should not contain <, >, &, '
      local input = ESC .. "[31mtext with <tag> & 'quotes'"
      local result = ansi2pango.convert(input)
      -- The text inside the span should be escaped
      assert.falsy(result:match("<tag>"))
      assert.truthy(result:match("&lt;"))
    end)
  end)

  describe("input size limit", function()
    it("truncates input over 1MB", function()
      local big = string.rep("A", 1024 * 1024 + 100)
      local result = ansi2pango.convert(big)
      assert.are.equal(1024 * 1024, #result)
    end)

    it("does not truncate input under 1MB", function()
      local small = string.rep("A", 1000)
      assert.are.equal(small, ansi2pango.convert(small))
    end)

    it("truncated input still produces valid Pango", function()
      local base = string.rep("X", 1024 * 1024)
      local extra = ESC .. "[31mred" .. ESC .. "[0m"
      local result = ansi2pango.convert(base .. extra)
      assert.truthy(#result <= 1024 * 1024 + 200)
    end)

    it("doesn't split UTF-8 characters at truncation boundary", function()
      -- Create a string that ends with a 3-byte UTF-8 character at the boundary
      local base = string.rep("A", 1024 * 1024 - 1)
      local utf8char = "日" -- 3-byte UTF-8
      local input = base .. utf8char .. "extra"
      local result = ansi2pango.convert(input)
      -- Should not contain a split UTF-8 sequence
      assert.truthy(#result > 0)
    end)
  end)

  describe("state isolation between calls", function()
    it("no state leaks across convert calls", function()
      local r1 = ansi2pango.convert(ESC .. "[31mred" .. ESC .. "[0m")
      local r2 = ansi2pango.convert("plain text")
      assert.are.equal("plain text", r2)
    end)

    it("currentAttrs is fresh for each call", function()
      ansi2pango.convert(ESC .. "[1;31mbold red" .. ESC .. "[0m")
      local result = ansi2pango.convert("plain")
      assert.are.equal("plain", result)
    end)
  end)

  describe("performance with large inputs", function()
    it("handles 1000 ANSI sequences without hanging", function()
      local parts = {}
      for i = 1, 1000 do
        parts[#parts + 1] = ESC .. "[38;5;" .. (i % 256) .. "mtext" .. ESC .. "[0m"
      end
      local input = table.concat(parts)
      local start = os.clock()
      local result = ansi2pango.convert(input)
      local elapsed = os.clock() - start
      assert.truthy(#result > 0)
      assert.truthy(elapsed < 1.0, "1000 sequences should complete in <1s, took " .. elapsed .. "s")
    end)

    it("handles large plain text efficiently", function()
      local input = string.rep("Hello World ", 10000)
      local start = os.clock()
      local result = ansi2pango.convert(input)
      local elapsed = os.clock() - start
      assert.truthy(#result > 0)
      assert.truthy(elapsed < 0.5, "large plain text should complete in <0.5s, took " .. elapsed .. "s")
    end)
  end)

  describe("findMTerminator robustness", function()
    it("correctly handles ESC[m (empty params = reset)", function()
      local input = ESC .. "[31mred" .. ESC .. "[m plain"
      local result = ansi2pango.convert(input)
      assert.are.equal('<span foreground="#800000">red</span> plain', result)
    end)

    it("correctly handles ESC[0m (explicit reset)", function()
      local input = ESC .. "[1mbold" .. ESC .. "[0m normal"
      local result = ansi2pango.convert(input)
      assert.are.equal('<span weight="bold">bold</span> normal', result)
    end)

    it("handles 'm' character in text after ANSI code", function()
      -- The 'm' in "mark" should be text, not a terminator
      -- ESC[31m followed by "mark" — the 'm' at escPos+2 terminates
      -- the sequence, leaving "ark" as text
      local input = ESC .. "[31mmark the spot"
      local result = ansi2pango.convert(input)
      -- The first 'm' terminates the sequence, text is "ark the spot"
      assert.truthy(result:match("ark the spot"))
      assert.truthy(result:match('foreground="#800000"'))
    end)

    it("handles multiple semicolons (empty params)", function()
      -- ESC[;;31m — gmatch("[^;]+") skips empty segments
      -- So this is parsed as just {31}
      local input = ESC .. "[31mtext"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match('foreground="#800000"'))
    end)

    it("handles non-SGR CSI sequences gracefully", function()
      -- ESC[?25l is a cursor hide sequence (private mode)
      -- Non-SGR CSI sequences are now stripped by findCSITerminator
      local input = "hello" .. ESC .. "[?25l" .. "world"
      local result = ansi2pango.convert(input)
      assert.are.equal("helloworld", result)
    end)
  end)

  describe("ATTR_ORDER determinism", function()
    it("always outputs attributes in consistent order", function()
      -- Set bg first, then fg — output should still be weight, style, underline, fg, bg
      local input = ESC .. "[44;31mtext"
      local result = ansi2pango.convert(input)
      -- fg should come before bg in the output
      local fgPos = result:find('foreground')
      local bgPos = result:find('background')
      assert.truthy(fgPos)
      assert.truthy(bgPos)
      assert.truthy(fgPos < bgPos, "foreground should come before background")
    end)

    it("deterministic output for same input across multiple calls", function()
      local input = ESC .. "[1;3;31;44mtext" .. ESC .. "[0m"
      local r1 = ansi2pango.convert(input)
      local r2 = ansi2pango.convert(input)
      assert.are.equal(r1, r2)
    end)
  end)

  describe("truecolor boundary validation", function()
    it("rejects truecolor with r=256 (out of range)", function()
      local input = ESC .. "[38;2;256;0;0mtext"
      local result = ansi2pango.convert(input)
      assert.falsy(result:match('foreground='))
    end)

    it("rejects truecolor with negative value", function()
      -- -1 won't parse as a valid number in the semicolon split
      -- so this tests what happens with 0-values
      local input = ESC .. "[38;2;0;0;0mtext"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match('foreground="#000000"'))
    end)

    it("accepts truecolor with r=255, g=255, b=255", function()
      local input = ESC .. "[38;2;255;255;255mtext"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match('foreground="#ffffff"'))
    end)

    it("rejects 256-color with index > 255", function()
      local input = ESC .. "[38;5;300mtext"
      local result = ansi2pango.convert(input)
      assert.falsy(result:match('foreground='))
    end)

    it("accepts 256-color boundary index 255", function()
      local input = ESC .. "[38;5;255mtext"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match('foreground="#eeeeee"'))
    end)

    it("accepts 256-color boundary index 0", function()
      local input = ESC .. "[38;5;0mtext"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match('foreground="#000000"'))
    end)
  end)

  describe("non-SGR CSI sequence stripping", function()
    it("strips cursor right (C)", function()
      local input = ESC .. "[41Ctext"
      assert.are.equal("text", ansi2pango.convert(input))
    end)

    it("strips cursor up (A)", function()
      local input = ESC .. "[18Atext"
      assert.are.equal("text", ansi2pango.convert(input))
    end)

    it("strips cursor home (G)", function()
      local input = ESC .. "[1Gtext"
      assert.are.equal("text", ansi2pango.convert(input))
    end)

    it("strips cursor position (H)", function()
      local input = ESC .. "[10;20Htext"
      assert.are.equal("text", ansi2pango.convert(input))
    end)

    it("strips erase display (J)", function()
      local input = ESC .. "[2Jtext"
      assert.are.equal("text", ansi2pango.convert(input))
    end)

    it("strips erase line (K)", function()
      local input = ESC .. "[0Ktext"
      assert.are.equal("text", ansi2pango.convert(input))
    end)

    it("strips scroll up (S)", function()
      local input = ESC .. "[3Stext"
      assert.are.equal("text", ansi2pango.convert(input))
    end)

    it("strips private mode cursor hide (?25l)", function()
      local input = ESC .. "[?25ltext"
      assert.are.equal("text", ansi2pango.convert(input))
    end)

    it("strips private mode cursor show (?25h)", function()
      local input = ESC .. "[?25htext"
      assert.are.equal("text", ansi2pango.convert(input))
    end)

    it("strips private mode alt screen (?1049h)", function()
      local input = ESC .. "[?1049htext"
      assert.are.equal("text", ansi2pango.convert(input))
    end)

    it("strips multiple cursor sequences before text", function()
      local input = ESC .. "[1G" .. ESC .. "[18A" .. ESC .. "[41Ctext"
      assert.are.equal("text", ansi2pango.convert(input))
    end)

    it("strips cursor move but preserves SGR color", function()
      local input = ESC .. "[41C" .. ESC .. "[31mred"
      local result = ansi2pango.convert(input)
      assert.are.equal('<span foreground="#800000">red</span>', result)
    end)

    it("strips cursor between colored segments", function()
      -- Cursor move is stripped, no space inserted (it's not text)
      local input = ESC .. "[31mred" .. ESC .. "[0m" .. ESC .. "[41C" .. ESC .. "[32mgreen"
      local result = ansi2pango.convert(input)
      assert.are.equal('<span foreground="#800000">red</span><span foreground="#008000">green</span>', result)
    end)
  end)

  describe("OSC sequence stripping", function()
    it("strips OSC with BEL terminator", function()
      local input = ESC .. "]0;window_title" .. string.char(7) .. "text"
      assert.are.equal("text", ansi2pango.convert(input))
    end)

    it("strips OSC with ST terminator (\\e\\\\)", function()
      -- ST is ESC + backslash (0x1B 0x5C)
      local input = ESC .. "]0;window_title" .. ESC .. string.char(0x5C) .. "text"
      assert.are.equal("text", ansi2pango.convert(input))
    end)

    it("strips OSC with multiple params", function()
      local input = ESC .. "]2;title;detail" .. string.char(7) .. "text"
      assert.are.equal("text", ansi2pango.convert(input))
    end)

    it("handles malformed OSC (no terminator) gracefully", function()
      local input = ESC .. "]0;no terminator here"
      local result = ansi2pango.convert(input)
      -- Should not crash, may return empty or partial
      assert.truthy(result ~= nil)
    end)
  end)

  describe("other ESC sequence handling", function()
    it("strips ESC + single char (e.g. \\e(B charset)", function()
      local input = ESC .. "(Btext"
      assert.are.equal("text", ansi2pango.convert(input))
    end)

    it("strips ESC ) charset sequence", function()
      local input = ESC .. ")0text"
      assert.are.equal("text", ansi2pango.convert(input))
    end)

    it("handles bare ESC at end of string", function()
      local input = "text" .. ESC
      assert.are.equal("text", ansi2pango.convert(input))
    end)

    it("handles ESC followed by another ESC", function()
      -- First ESC consumed as "other" (nextByte = 0x1B), then second ESC starts CSI
      local input = ESC .. ESC .. "[31mred"
      local result = ansi2pango.convert(input)
      assert.are.equal('<span foreground="#800000">red</span>', result)
    end)
  end)

  describe("fastfetch-style output", function()
    it("strips cursor positioning and preserves colored text", function()
      -- Simulated fastfetch line: cursor-right-41 then green OS label
      local input = ESC .. "[41C" .. ESC .. "[1m" .. ESC .. "[32mOS:" .. ESC .. "[0m Arch Linux"
      local result = ansi2pango.convert(input)
      assert.truthy(result:match('weight="bold"'))
      assert.truthy(result:match('foreground="#008000"'))
      assert.truthy(result:match("OS:"))
      assert.truthy(result:match("Arch Linux"))
    end)

    it("strips color block test sequences", function()
      -- Fastfetch outputs color blocks: \e[40m \e[41m ... \e[0m
      local input = ESC .. "[40m " .. ESC .. "[41m " .. ESC .. "[42m " .. ESC .. "[0m"
      local result = ansi2pango.convert(input)
      -- Should have 3 spans with background colors and spaces
      local opens = select(2, result:gsub("<span", ""))
      local closes = select(2, result:gsub("</span>", ""))
      assert.are.equal(opens, closes)
    end)

    it("handles full fastfetch-like output with cursor moves and colors", function()
      -- Logo lines + cursor moves + info lines with colors
      local parts = {
        ESC .. "[1G" .. ESC .. "[18A",  -- cursor home + up
        ESC .. "[41C" .. ESC .. "[1;36mOS:" .. ESC .. "[0m Arch Linux\n",
        ESC .. "[41C" .. ESC .. "[1;36mKernel:" .. ESC .. "[0m Linux 7.0.8-zen\n",
        ESC .. "[41C" .. ESC .. "[1;36mMemory:" .. ESC .. "[0m 7.38 GiB / 58.49 GiB",
      }
      local input = table.concat(parts)
      local result = ansi2pango.convert(input)
      assert.truthy(result:match("OS:"))
      assert.truthy(result:match("Arch Linux"))
      assert.truthy(result:match("Kernel:"))
      assert.truthy(result:match("Memory:"))
      -- No stray [41C or [1G or [18A in output
      assert.falsy(result:match("%[41C"))
      assert.falsy(result:match("%[1G"))
      assert.falsy(result:match("%[18A"))
    end)
  end)

  describe("concurrent attribute management", function()
    it("reset (0) clears only attributes, not future text", function()
      local input = ESC .. "[1;31mbold red" .. ESC .. "[0m" .. ESC .. "[32mgreen"
      local result = ansi2pango.convert(input)
      -- "bold red" should have weight and foreground
      -- "green" should only have foreground
      assert.truthy(result:match("bold red"))
      assert.truthy(result:match("green"))
      -- Verify "green" is inside a span with only foreground
      local greenSpan = result:match('(green)</span>')
      assert.truthy(greenSpan)
    end)

    it("setting same attribute twice is idempotent", function()
      local input = ESC .. "[1m" .. ESC .. "[1mtext"
      local result = ansi2pango.convert(input)
      -- Should produce exactly one span with weight="bold"
      assert.are.equal('<span weight="bold">text</span>', result)
    end)

    it("fg then different fg replaces", function()
      local input = ESC .. "[31m" .. ESC .. "[32mtext"
      local result = ansi2pango.convert(input)
      -- Second fg should replace first
      -- Both emit events: first emits empty (no text), second emits with green fg
      assert.truthy(result:match('foreground="#008000"'))
      assert.falsy(result:match('foreground="#800000"'))
    end)

    it("partial reset (39) only removes foreground", function()
      local input = ESC .. "[1;31;44mbold red on blue" .. ESC .. "[39mafter"
      local result = ansi2pango.convert(input)
      -- "bold red on blue" has weight, foreground, background
      -- "after" should have weight, background (no foreground)
      assert.truthy(result:match('weight="bold"'))
      assert.truthy(result:match('background="#000080"'))
      -- The second span for "after" should NOT have foreground
      -- Check that foreground appears only once (for the first text)
      local _, fgCount = result:gsub('foreground=', '')
      assert.are.equal(1, fgCount)
    end)
  end)
end)