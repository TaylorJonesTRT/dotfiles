local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.font = wezterm.font("JetBrains Mono")

-- Color Scheme Settings
config.color_scheme = "Catppuccin Macchiato"
-- config.window_background_image = "/Users/taylorjones/powder.jpg"
-- config.window_background_opacity = 1.0

config.max_fps = 240

config.background = {
	{
		source = {
			Color = "rgba(36, 39, 58, 1)",
		},
		height = "100%",
		width = "100%",
		opacity = 0.89,
	},
	-- {
	-- 	source = {
	-- 		File = "/Users/taylorjones/powder.jpg",
	-- 	},
	-- 	opacity = 0.11,
	-- 	width = "160%",
	-- 	repeat_y = "NoRepeat",
	-- 	vertical_align = "Middle",
	-- 	horizontal_align = "Center",
	-- },
}

return config
