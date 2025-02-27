local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

-- Update with path to stats_provider
sbar.exec(
	"killall stats_provider >/dev/null; ~/Development/scripts/sketchybar-system-stats/target/release/stats_provider --memory ram_used ram_total ram_usage"
)
-- Subscribe and use the `DISK_USAGE` var

local ram_usage = sbar.add("graph", "widgets.ram", 42, {
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
		string = "ram ??%",
		font = {
			family = settings.font.numbers,
			style = settings.font.style_map["Bold"],
			size = 9.0,
		},
		align = "right",
		padding_right = 0,
		width = 0,
		y_offset = 4,
	},
	padding_right = settings.paddings + 6,
})

ram_usage:subscribe("system_stats", function(env)
	local used = env.RAM_USED:sub(1, -2)
	ram_usage:push({ load })

	-- local color = colors.blue
	-- if load > 30 then
	-- 	if load < 60 then
	-- 		color = colors.yellow
	-- 	elseif load < 80 then
	-- 		color = colors.orange
	-- 	else
	-- 		color = colors.red
	-- 	end
	-- end

	ram_usage:set({
		graph = { color = color },
		label = "ram " .. env.RAM_USED:sub(1, -2) .. "%",
	})
end)

-- local memory = sbar.add("graph", "memory", 42, {
-- 	position = "right",
-- 	graph = { color = colors.blue },
-- 	background = {
-- 		height = 22,
-- 		color = { alpha = 0 },
-- 		border_color = { alpha = 0 },
-- 		drawing = true,
-- 	},
-- 	icon = { string = icons.ram },
-- 	label = {
-- 		string = "ram ??%",
-- 		font = {
-- 			family = settings.font.numbers,
-- 			style = settings.font.style_map["Bold"],
-- 			size = 9.0,
-- 		},
-- 		align = "right",
-- 		padding_right = 0,
-- 		width = 0,
-- 		y_offset = 4,
-- 	},
-- 	padding_right = settings.paddings + 6,
-- })
--
-- memory:subscribe("system_stats", function(env)
-- 	-- Also available: env.user_load, env.sys_load
-- 	local load = tonumber(env.RAM_USAGE)
-- 	memory:push({ load / 100. })
--
-- 	local color = colors.blue
-- 	if load > 30 then
-- 		if load < 60 then
-- 			color = colors.yellow
-- 		elseif load < 80 then
-- 			color = colors.orange
-- 		else
-- 			color = colors.red
-- 		end
-- 	end
--
-- 	memory:set({
-- 		graph = { color = color },
-- 		label = "ram " .. env.RAM_USAGE .. "%",
-- 	})
-- end)
--
ram_usage:subscribe("mouse.clicked", function(env)
	sbar.exec("open -a 'Activity Monitor'")
end)
--
-- Background around the cpu item
sbar.add("bracket", "widgets.ram.bracket", { ram_usage.name }, {
	background = { color = colors.bg1 },
})
--
-- -- Background around the cpu item
sbar.add("item", "widgets.ram.padding", {
	position = "right",
	width = settings.group_paddings,
})
