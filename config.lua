-- Lucifer GTK Window config
-- Supports nested tabs: groups with `children` create a secondary notebook.
-- Single-child groups are inlined (no secondary row).
-- Titles are loaded immediately; content is lazy-loaded on first view.
-- `interval`: auto-refresh in seconds. 0 = no auto-refresh (fetch once on load)

local FONT = "JetBrainsMono Nerd Font Mono"
local FONT_SIZE = 11
local TAB_FONT = "sans-serif"
local TAB_FONT_SIZE = 12

return {
  title = "Lucifer GTK Window",

  tabs = {
    {
      titleScript = "echo '🌤 Weather'",
      titleFallback = "Weather",
      contentFont = FONT,
      contentFontSize = FONT_SIZE,
      tabTitleFont = TAB_FONT,
      tabTitleFontSize = TAB_FONT_SIZE,
      children = {
        {
          command = "curl -s wttr.in?0",
          fallback = "Weather unavailable",
          titleScript = "echo '📍 Local'",
          titleFallback = "Local",
          interval = 300,
        },
        {
          command = "curl -s wttr.in/chicago?m&lang=en",
          fallback = "Weather unavailable",
          titleScript = "echo '🏙 Chicago'",
          titleFallback = "Chicago",
          interval = 300,
        },
        {
          command = "curl -s v2.wttr.in/toledo?m&lang=en",
          fallback = "Weather unavailable",
          titleScript = "echo '🏛 Toledo'",
          titleFallback = "Toledo",
          interval = 300,
        },
      },
    },
    {
      command = "curl -s rate.sx/btc",
      fallback = "BTC price unavailable",
      titleScript = "echo '₿ BTC'",
      titleFallback = "BTC",
      interval = 300,
      contentFont = FONT,
      contentFontSize = FONT_SIZE,
      tabTitleFont = TAB_FONT,
      tabTitleFontSize = TAB_FONT_SIZE,
    },
    {
      titleScript = "echo '🖥 System'",
      titleFallback = "System",
      contentFont = FONT,
      contentFontSize = FONT_SIZE,
      tabTitleFont = TAB_FONT,
      tabTitleFontSize = TAB_FONT_SIZE,
      children = {
        {
          command = "fastfetch --logo none 2>/dev/null || echo 'System info unavailable'",
          fallback = "System info unavailable",
          titleScript = "echo 'ℹ️ Info'",
          titleFallback = "Info",
          interval = 0,
        },
        {
          command = "acpi -V 2>/dev/null || echo 'Battery info unavailable'",
          fallback = "Battery info unavailable",
          titleScript = "echo '🔋 Battery'",
          titleFallback = "Battery",
          interval = 60,
        },
        {
          command = "free -h 2>/dev/null || echo 'Memory info unavailable'",
          fallback = "Memory info unavailable",
          titleScript = "echo '💾 Memory'",
          titleFallback = "Memory",
          interval = 10,
          contentFontSize = 13,
        },
      },
    },
  },
}