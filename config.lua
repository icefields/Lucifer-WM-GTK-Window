-- Lucifer GTK Window config
-- Each tab runs a CLI command and displays its output in monospace
--
-- interval: auto-refresh in seconds. 0 = no auto-refresh (fetch once on load)

return {
  title = "Lucifer GTK Window",

  tabs = {
    {
      command = "curl -s wttr.in?0",
      fallback = "Weather unavailable",
      titleScript = "echo '🌤 Weather'",
      titleFallback = "Weather",
      interval = 300,
      contentFont = "JetBrainsMono Nerd Font Mono",
      contentFontSize = 11,
      tabTitleFont = "sans-serif",
      tabTitleFontSize = 12,
    },
    {
      command = "curl -s rate.sx/btc",
      fallback = "BTC price unavailable",
      titleScript = "echo '₿ BTC'",
      titleFallback = "BTC",
      interval = 300,
      contentFont = "JetBrainsMono Nerd Font Mono",
      contentFontSize = 11,
      tabTitleFont = "sans-serif",
      tabTitleFontSize = 12,
    },
    {
      command = "neofetch --stdout 2>/dev/null || echo 'System info unavailable'",
      fallback = "System info unavailable",
      titleScript = "echo '🖥 System'",
      titleFallback = "System",
      interval = 0,
      contentFont = "JetBrainsMono Nerd Font Mono",
      contentFontSize = 11,
      tabTitleFont = "sans-serif",
      tabTitleFontSize = 12,
    },
  },
}