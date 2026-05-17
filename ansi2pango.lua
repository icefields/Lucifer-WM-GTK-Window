--- ANSI escape sequence parser → Pango markup
-- Converts terminal color codes into <span> tags for GTK labels
-- Supports: 8/16 colors, 256-color, RGB (truecolor), bold, italic, underline, reset

local M = {}

-- ANSI 4-bit color palette (standard + bright)
local palette = {
  [0]  = "#000000", [1]  = "#800000", [2]  = "#008000", [3]  = "#808000",
  [4]  = "#000080", [5]  = "#800080", [6]  = "#008080", [7]  = "#c0c0c0",
  [8]  = "#808080", [9]  = "#ff0000", [10] = "#00ff00", [11] = "#ffff00",
  [12] = "#0000ff", [13] = "#ff00ff", [14] = "#00ffff", [15] = "#ffffff",
}

-- Pre-computed 256-color lookup table (indices 0-255)
local color256_table = {}
do
  local function scale(v) return v == 0 and 0 or 40 * v + 55 end
  for i = 0, 15 do color256_table[i] = palette[i] end
  for i = 16, 231 do
    local n = i - 16
    local b = n % 6; n = (n - b) / 6
    local g = n % 6; local r = (n - g) / 6
    color256_table[i] = string.format("#%02x%02x%02x", scale(r), scale(g), scale(b))
  end
  for i = 232, 255 do
    local v = 8 + 10 * (i - 232)
    color256_table[i] = string.format("#%02x%02x%02x", v, v, v)
  end
end

-- Escape Pango markup special characters
local function escape(text)
  return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("'", "&apos;"))
end

--- Find the matching 'm' terminator for an ANSI escape sequence
-- The 'm' must be preceded only by digits and semicolons.
-- This prevents false matches on 'm' appearing inside numeric params
-- (e.g., \e[38;2;109;0;0m — the 109 contains no 'm' as char, but
--  searching for "m" with plain=true would match correctly here anyway
--  since 'm' as a byte can't appear in the digit/semicolon param region).
-- However, to be safe and handle edge cases, we find the first 'm' after
-- ESC[ and validate that everything between is valid param chars.
local function findMTerminator(text, startPos)
  -- startPos points to the character after ESC[
  -- We look for the first 'm' where the intervening chars are [0-9;]
  local pos = startPos
  while pos <= #text do
    local mPos = text:find("m", pos, true)
    if not mPos then return nil end
    -- Validate: everything from startPos to mPos-1 must be digits/semicolons
    local paramStr = text:sub(startPos, mPos - 1)
    if paramStr:match("^[0-9;]*$") then
      return mPos
    end
    -- Not a valid CSI sequence, skip past this 'm' and keep looking
    pos = mPos + 1
  end
  return nil
end

--- Convert ANSI-colored text to Pango markup
-- @param text string with ANSI escape sequences
-- @return Pango markup string
-- Input is truncated at 1MB to prevent unbounded memory growth.
-- Multi-byte UTF-8 is preserved during truncation.

local MAX_INPUT = 1024 * 1024 -- 1MB limit

-- Stable attribute order for deterministic Pango output (module-level constant)
local ATTR_ORDER = { "weight", "style", "underline", "foreground", "background" }

function M.convert(text)
  if #text > MAX_INPUT then
    -- Truncate but don't split a multi-byte UTF-8 sequence
    local cut = MAX_INPUT
    while cut > 1 and text:byte(cut) >= 0x80 and text:byte(cut) <= 0xBF do
      cut = cut - 1
    end
    if cut > 0 and text:byte(cut) >= 0xC0 then
      cut = cut - 1
    end
    text = text:sub(1, cut)
  end

  local result = {}
  local currentAttrs = {} -- key=value pairs
  local pos = 1

  local function emit(plain)
    if plain and plain ~= "" then
      local attrs = {}
      for _, k in ipairs(ATTR_ORDER) do
        if currentAttrs[k] then
          attrs[#attrs + 1] = string.format('%s="%s"', k, currentAttrs[k])
        end
      end
      if #attrs > 0 then
        result[#result + 1] = '<span ' .. table.concat(attrs, " ") .. '>'
        result[#result + 1] = escape(plain)
        result[#result + 1] = '</span>'
      else
        result[#result + 1] = escape(plain)
      end
    end
  end

  while pos <= #text do
    local escPos = text:find("\27[", pos, true)
    if not escPos then
      emit(text:sub(pos))
      break
    end

    if escPos > pos then
      emit(text:sub(pos, escPos - 1))
    end

    -- Find the 'm' terminator for this CSI sequence
    local mPos = findMTerminator(text, escPos + 2)
    if not mPos then
      -- Malformed: no terminating 'm', emit the ESC as plain text
      emit(text:sub(escPos))
      break
    end

    local paramStr = text:sub(escPos + 2, mPos - 1)
    pos = mPos + 1

    -- Parse params
    local nums = {}
    for s in paramStr:gmatch("[^;]+") do
      local n = tonumber(s)
      if n then nums[#nums + 1] = n end
    end
    if #nums == 0 then nums = {0} end

    local i = 1
    while i <= #nums do
      local code = nums[i]

      if code == 0 then
        currentAttrs = {}
      elseif code == 1 then
        currentAttrs["weight"] = "bold"
      elseif code == 3 then
        currentAttrs["style"] = "italic"
      elseif code == 4 then
        currentAttrs["underline"] = "single"
      elseif code == 22 then
        currentAttrs["weight"] = nil
      elseif code == 23 then
        currentAttrs["style"] = nil
      elseif code == 24 then
        currentAttrs["underline"] = nil
      elseif code == 38 then
        -- Extended foreground
        local nextCode = nums[i + 1]
        if nextCode == 5 and nums[i + 2] then
          local idx = nums[i + 2]
          if idx >= 0 and idx <= 255 then
            currentAttrs["foreground"] = color256_table[idx]
          end
          i = i + 2
        elseif nextCode == 2 and nums[i + 2] and nums[i + 3] and nums[i + 4] then
          local r, g, b = nums[i+2], nums[i+3], nums[i+4]
          if r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255 then
            currentAttrs["foreground"] = string.format("#%02x%02x%02x", r, g, b)
          end
          i = i + 4
        end
      elseif code == 48 then
        -- Extended background
        local nextCode = nums[i + 1]
        if nextCode == 5 and nums[i + 2] then
          local idx = nums[i + 2]
          if idx >= 0 and idx <= 255 then
            currentAttrs["background"] = color256_table[idx]
          end
          i = i + 2
        elseif nextCode == 2 and nums[i + 2] and nums[i + 3] and nums[i + 4] then
          local r, g, b = nums[i+2], nums[i+3], nums[i+4]
          if r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255 then
            currentAttrs["background"] = string.format("#%02x%02x%02x", r, g, b)
          end
          i = i + 4
        end
      elseif code == 39 then
        currentAttrs["foreground"] = nil
      elseif code == 49 then
        currentAttrs["background"] = nil
      elseif code >= 30 and code <= 37 then
        currentAttrs["foreground"] = palette[code - 30]
      elseif code >= 40 and code <= 47 then
        currentAttrs["background"] = palette[code - 40]
      elseif code >= 90 and code <= 97 then
        currentAttrs["foreground"] = palette[code - 90 + 8]
      elseif code >= 100 and code <= 107 then
        currentAttrs["background"] = palette[code - 100 + 8]
      end

      i = i + 1
    end
  end

  return table.concat(result)
end

return M