local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

local PAGE_SIZE = 10

local brew = sbar.add("item", "widgets.brew", {
    position = "right",
    update_freq = 3600,
    icon = {
        string = "󰏖",
        font = {
            family = settings.font_icon.text,
            style = settings.font_icon.style_map["Bold"],
            size = settings.icon_size
        },
        padding_left = settings.padding.icon_label_item.icon.padding_left,
        padding_right = settings.padding.icon_label_item.icon.padding_right,
    },
    label = {
        string = "?",
        font = {
            family = settings.font.numbers,
            style = settings.font.style_map["Bold"],
            size = settings.label_size,
        },
        padding_right = settings.padding.icon_label_item.label.padding_right,
    },
    popup = {
        align = "center",
        height = 30,
    },
})

local cached_packages = {}
local popup_items = {}
local current_page = 1

local function is_package_line(line)
    if not line or line == "" or line:match("^%s*$") then
        return false
    end
    if line:match("^Error:") or
        line:match("^Please report") or
        line:match("^/opt/homebrew") or
        line:match("Troubleshooting") or
        line:match("undefined method") or
        line:match("%.rb:") then
        return false
    end
    return true
end

local function update_brew(env)
    sbar.exec('/bin/zsh -c "brew outdated -q"', function(outdated_output)
        cached_packages = {}
        for line in outdated_output:gmatch("[^\r\n]+") do
            if is_package_line(line) then
                table.insert(cached_packages, line)
            end
        end

        local count = #cached_packages
        local color = colors.green
        if count >= 4 then
            color = colors.red
        elseif count > 0 then
            color = colors.yellow
        end

        brew:set({
            label = { string = count, color = color },
            icon = { color = color },
        })
    end)
end

brew:subscribe({ "routine", "forced" }, update_brew)
update_brew()

local function clear_popup()
    for _, item in ipairs(popup_items) do
        sbar.remove(item.name)
    end
    popup_items = {}
end

local function populate_popup()
    clear_popup()

    if #cached_packages == 0 then
        local no_updates = sbar.add("item", {
            position = "popup." .. brew.name,
            label = {
                string = "No outdated packages",
                font = {
                    family = settings.font.text,
                    style = settings.font.style_map["Regular"],
                    size = settings.font.size,
                },
                padding_left = 8,
                padding_right = 8,
            },
            icon = { drawing = false },
        })
        table.insert(popup_items, no_updates)
        return
    end

    local total_pages = math.ceil(#cached_packages / PAGE_SIZE)
    local start_idx = (current_page - 1) * PAGE_SIZE + 1
    local end_idx = math.min(current_page * PAGE_SIZE, #cached_packages)

    -- Header with page info if multiple pages
    if total_pages > 1 then
        local header = sbar.add("item", {
            position = "popup." .. brew.name,
            label = {
                string = string.format("Page %d/%d  (scroll to navigate)", current_page, total_pages),
                font = {
                    family = settings.font.text,
                    style = settings.font.style_map["Bold"],
                    size = 10.0,
                },
                color = colors.grey,
                padding_left = 8,
                padding_right = 8,
            },
            icon = { drawing = false },
        })
        table.insert(popup_items, header)
    end

    for i = start_idx, end_idx do
        local pkg_item = sbar.add("item", {
            position = "popup." .. brew.name,
            label = {
                string = cached_packages[i],
                font = {
                    family = settings.font.text,
                    style = settings.font.style_map["Regular"],
                    size = 10.0,
                },
                padding_left = 8,
                padding_right = 8,
            },
            icon = {
                string = "•",
                padding_left = 8,
                padding_right = 4,
            },
        })
        table.insert(popup_items, pkg_item)
    end
end

brew:subscribe("mouse.clicked", function(env)
    local query = brew:query()
    local is_open = query and query.popup and query.popup.drawing == "on"

    if is_open then
        brew:set({ popup = { drawing = false } })
    else
        current_page = 1
        populate_popup()
        brew:set({ popup = { drawing = true } })
    end
end)

brew:subscribe("mouse.scrolled", function(env)
    local total_pages = math.ceil(#cached_packages / PAGE_SIZE)
    if total_pages <= 1 then return end

    local delta = env.SCROLL_DELTA
    if delta and tonumber(delta) then
        if tonumber(delta) > 0 and current_page > 1 then
            current_page = current_page - 1
            populate_popup()
        elseif tonumber(delta) < 0 and current_page < total_pages then
            current_page = current_page + 1
            populate_popup()
        end
    end
end)

-- Background around the brew item
sbar.add("bracket", "widgets.brew.bracket", { brew.name }, {
    background = { color = colors.bg1 }
})

-- Padding after brew item
sbar.add("item", "widgets.brew.padding", {
    position = "right",
    width = settings.group_paddings,
})
