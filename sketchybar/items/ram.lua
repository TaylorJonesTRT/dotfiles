local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

local ram = SBAR.add("graph", "widgets.ram", 42, {
  position = "right",
  graph = { color = colors.blue },
  background = {
    height = 22,
    color = { alpha = 0 },
    border_color = { alpha = 0 },
    drawing = true,
  },
  icon = { string = icons.ram },
  label = {
    string = "RAM ??%",
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Medium"],
      size = 10.0,
    },
    align = "right",
    padding_right = 0,
    width = 0,
    y_offset = 4
  },
  update_freq = 3,
  padding_right = settings.paddings + 6
})

-- Used memory percentage derived from vm_stat page counts.
local RAM_CMD = [[vm_stat | awk '
  /page size of/ { ps = $8 }
  /Pages free/ { free = $3 }
  /Pages active/ { active = $3 }
  /Pages inactive/ { inactive = $3 }
  /Pages speculative/ { spec = $3 }
  /Pages wired down/ { wired = $4 }
  /Pages occupied by compressor/ { comp = $5 }
  END {
    gsub("\\.","",free); gsub("\\.","",active); gsub("\\.","",inactive);
    gsub("\\.","",spec); gsub("\\.","",wired); gsub("\\.","",comp);
    used = (active + wired + comp) * ps;
    total = (free + active + inactive + spec + wired + comp) * ps;
    printf "%.0f", (used / total) * 100
  }']]

ram:subscribe({ "routine", "forced", "system_woke" }, function()
  SBAR.exec(RAM_CMD, function(out)
    local load = tonumber(out)
    if not load then return end

    ram:push({ load / 100. })

    local color = colors.blue
    if load > 30 then
      if load < 60 then
        color = colors.yellow
      elseif load < 80 then
        color = colors.orange
      else
        color = colors.red
      end
    end

    ram:set({
      graph = { color = color },
      label = { string = load .. "%", align = "right" },
    })
  end)
end)

SBAR.add("bracket", "widgets.ram.bracket", { ram.name }, {
  background = { color         = colors.bg05,
  border_color  = colors.bg1, border_width = 1 }
})

SBAR.add("item", "widgets.ram.padding", {
  position = "right",
  width = settings.group_paddings
})
