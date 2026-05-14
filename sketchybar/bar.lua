local colors = require("colors")

-- Equivalent to the --bar domain
sbar.bar({
    height = 36,
    color = colors.with_alpha(colors.bar.bg, 0.5),
    -- color=colors.transparent,
    padding_right = 2,
    padding_left = 2,
    corner_radius = 23,
    y_offset = 2,
    shadow = false,
    blur_radius = 10, -- ?
    margin = 2
})
