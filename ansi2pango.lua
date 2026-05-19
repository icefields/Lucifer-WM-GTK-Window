--- ANSI escape sequence parser → Pango markup
-- Converts terminal color codes into <span> tags for GTK labels
-- Supports: 8/16 colors, 256-color, RGB (truecolor), bold, italic, underline, reset
-- Strips: cursor movement, scroll, erase, private mode, OSC sequences

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

--- Find the terminator for a CSI escape sequence
-- CSI sequences end with a byte in the range 0x40-0x7E
-- Returns: terminatorChar, endPos (position after terminator), paramStr
-- Returns nil if no valid terminator found
local function findCSITerminator(text, startPos)
  local pos = startPos
  -- Skip intermediate bytes (0x20-0x2F)
  while pos <= #text do
    local b = text:byte(pos)
    if b >= 0x20 and b <= 0x2F then
      pos = pos + 1
    else
      break
    end
  end
  local paramStart = pos
  while pos <= #text do
    local b = text:byte(pos)
    -- Digits, semicolons, and '?' (private mode) are param chars
    if (b >= 0x30 and b <= 0x39) or b == 0x3B or b == 0x3F then
      pos = pos + 1
    elseif b >= 0x40 and b <= 0x7E then
      local paramStr = text:sub(paramStart, pos - 1)
      return string.char(b), pos + 1, paramStr
    else
      return nil
    end
  end
  return nil
end

--- Find the end of an OSC sequence
-- OSC ends with BEL (0x07) or ST (\e\\)
-- Returns endPos (position after terminator), or nil if malformed
local function findOSCEnd(text, startPos)
  local pos = startPos
  while pos <= #text do
    local b = text:byte(pos)
    if b == 0x07 then
      return pos + 1
    elseif b == 0x1B and text:byte(pos + 1) == 0x5C then
      return pos + 2
    end
    pos = pos + 1
  end
  return nil
end

--- Parse SGR parameters and update current attributes
-- @param paramStr semicolon-separated params (may include leading '?')
-- @param currentAttrs table of current Pango attributes
-- @return updated attributes table (new reference on reset, same ref otherwise)
local function parseSGR(paramStr, currentAttrs)
  -- Strip leading '?' if present (shouldn't happen for SGR but be safe)
  paramStr = paramStr:match("^%?(.*)$") or paramStr

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

  return currentAttrs
end

local MAX_INPUT = 1024 * 1024 -- 1MB limit
local ATTR_ORDER = { "weight", "style", "underline", "foreground", "background" }

--- Convert ANSI-colored text to Pango markup
-- @param text string with ANSI escape sequences
-- @return Pango markup string
function M.convert(text)
  if #text > MAX_INPUT then
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
  local currentAttrs = {}
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
    local escPos = text:find("\27", pos, true)
    if not escPos then
      emit(text:sub(pos))
      break
    end

    if escPos > pos then
      emit(text:sub(pos, escPos - 1))
    end

    local nextByte = text:byte(escPos + 1)

    if nextByte == 0x5B then
      -- CSI sequence (\e[...)
      local termChar, endPos, paramStr = findCSITerminator(text, escPos + 2)
      if not termChar then
        emit(text:sub(escPos))
        break
      end
      pos = endPos
      if termChar == "m" then
        currentAttrs = parseSGR(paramStr, currentAttrs)
      end
      -- Non-SGR CSI sequences are stripped (cursor move, erase, etc.)

    elseif nextByte == 0x5D then
      -- OSC sequence (\e]...BEL or \e]...\e\\) — strip entirely
      local endPos = findOSCEnd(text, escPos + 2)
      if endPos then
        pos = endPos
      else
        break -- malformed, bail
      end

    elseif nextByte == 0x1B then
      -- Consecutive ESCs — skip first, let next iteration handle second
      pos = escPos + 1
    elseif nextByte then
      -- Other escape sequences
      -- Charset sequences: ESC ( X or ESC ) X (3 bytes total)
      -- Other 2-byte: ESC X (just skip ESC + next char)
      local thirdByte = text:byte(escPos + 2)
      if (nextByte == 0x28 or nextByte == 0x29) and thirdByte then
        -- ESC ( or ESC ) charset designation — skip 3 bytes
        pos = escPos + 3
      else
        -- Generic 2-byte ESC sequence — skip ESC + next char
        pos = escPos + 2
      end
    else
      -- Bare ESC at end of string
      pos = escPos + 1
    end
  end

  return table.concat(result)
end

return M