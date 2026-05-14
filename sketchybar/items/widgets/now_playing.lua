local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

-- Register custom event and start the media stream helper
sbar.add("event", "media_stream_changed")
sbar.exec("killall -q media_stream.sh 2>/dev/null; $CONFIG_DIR/helpers/media_stream.sh &")

local now_playing = sbar.add("item", "widgets.now_playing", {
    position = "right",
    drawing = false,
    updates = true,
    icon = {
        string = "󰐌",
        font = {
            family = settings.font_icon.text,
            style = settings.font_icon.style_map["Bold"],
            size = settings.icon_size,
        },
        padding_left = settings.padding.icon_label_item.icon.padding_left,
        padding_right = settings.padding.icon_label_item.icon.padding_right,
    },
    label = {
        font = {
            family = settings.font.text,
            style = settings.font.style_map["Regular"],
            size = settings.label_size,
        },
        padding_right = settings.padding.icon_label_item.label.padding_right,
        max_chars = 30,
    },
    scroll_texts = true,
})

now_playing:subscribe("media_stream_changed", function(env)
    local is_playing = env.playing == "true"
    if is_playing and env.title ~= "" then
        local label = env.title
        if env.artist and env.artist ~= "" then
            label = env.artist .. " - " .. env.title
        end
        now_playing:set({
            drawing = true,
            label = { string = label },
        })
    else
        now_playing:set({ drawing = false })
    end
end)

sbar.add("bracket", "widgets.now_playing.bracket", { now_playing.name }, {
    background = { color = colors.bg1 },
})

sbar.add("item", "widgets.now_playing.padding", {
    position = "right",
    width = settings.group_paddings,
    background = { drawing = false },
    icon = { drawing = false },
    label = { drawing = false },
})
