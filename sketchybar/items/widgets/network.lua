local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

local popup_width = 250

local function trim(value)
    return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function shell_quote(value)
    return "'" .. tostring(value):gsub("'", [['"'"']]) .. "'"
end

local function read_command(command)
    local handle = io.popen(command)
    if not handle then
        return ""
    end

    local output = handle:read("*a")
    handle:close()
    return trim(output)
end

local function parse_service_order()
    local services = {}
    local services_by_device = {}
    local current

    local output = read_command("networksetup -listnetworkserviceorder 2>/dev/null")
    for line in output:gmatch("[^\r\n]+") do
        local raw_name = line:match("^%(%d+%)%s+(.+)$")
        if raw_name then
            local disabled = raw_name:sub(1, 1) == "*"
            current = {
                name = trim(raw_name:gsub("^%*%s*", "")),
                disabled = disabled,
            }
        else
            local hardware_port, device = line:match("^%(Hardware Port:%s*(.-), Device:%s*(.-)%)$")
            if current and hardware_port then
                current.hardware_port = trim(hardware_port)
                current.device = trim(device)
                table.insert(services, current)

                if current.device ~= "" then
                    services_by_device[current.device] = current
                end

                current = nil
            end
        end
    end

    return services, services_by_device
end

local function interface_exists(interface)
    if interface == "" then
        return false
    end

    return read_command("ifconfig " .. shell_quote(interface) .. " 2>/dev/null") ~= ""
end

local function interface_is_active_with_ipv4(interface)
    if interface == "" then
        return false
    end

    local ifconfig_output = read_command("ifconfig " .. shell_quote(interface) .. " 2>/dev/null")
    local status = ifconfig_output:match("status:%s*(%S+)")
    if status ~= "active" then
        return false
    end

    return read_command("ipconfig getifaddr " .. shell_quote(interface) .. " 2>/dev/null") ~= ""
end

local function default_route_interface()
    return read_command("route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}'")
end

local function is_wired_candidate(service)
    if not service or service.disabled or service.device == "" then
        return false
    end

    local descriptor = (service.name .. " " .. (service.hardware_port or "")):lower()
    if descriptor:find("wi%-fi") or descriptor:find("thunderbolt bridge") then
        return false
    end

    return descriptor:find("ethernet") or descriptor:find("lan")
end

local function is_suitable_fallback_interface(interface, services_by_device)
    if interface == "" then
        return false
    end

    if interface:match("^bridge") or interface:match("^utun") then
        return false
    end

    if not services_by_device[interface] and not interface:match("^en%d+$") then
        return false
    end

    return interface_exists(interface)
end

local function select_preferred_interface()
    local services, services_by_device = parse_service_order()

    for _, service in ipairs(services) do
        if is_wired_candidate(service) and interface_is_active_with_ipv4(service.device) then
            return service.name, service.device
        end
    end

    local default_interface = default_route_interface()
    if is_suitable_fallback_interface(default_interface, services_by_device) then
        local service = services_by_device[default_interface]
        return service and service.name or default_interface, default_interface
    end

    local wifi_service = services_by_device.en1
    return wifi_service and wifi_service.name or "Wi-Fi", "en1"
end

local function format_connection_label(service, interface)
    local connection_service = service ~= "" and service or "Unknown"
    local connection_interface = interface ~= "" and interface or "N/A"
    return connection_service .. " (" .. connection_interface .. ")"
end

local current_service = ""
local current_interface = ""

local rate_font = {
    family = settings.font.numbers,
    style = settings.font.style_map["Bold"],
    size = 9.0,
}

-- Upload item (top line, stacked)
local network_up = sbar.add("item", "widgets.network.up", {
    position = "right",
    width = 0,
    padding_left = 0,
    padding_right = 0,
    icon = { drawing = false },
    label = {
        font = rate_font,
        padding_left = 8,
        padding_right = 8,
        align = "right",
        string = icons.wifi.upload .. " ???",
        color = colors.red,
    },
    y_offset = 5,
    background = { drawing = false },
})

-- Download item (bottom line, stacked)
local network_down = sbar.add("item", "widgets.network.down", {
    position = "right",
    padding_left = 0,
    padding_right = 0,
    icon = { drawing = false },
    label = {
        font = rate_font,
        padding_left = 8,
        padding_right = 8,
        align = "right",
        string = icons.wifi.download .. " ???",
        color = colors.blue,
    },
    y_offset = -5,
    background = { drawing = false },
})

local network_bracket = sbar.add("bracket", "widgets.network.bracket", {
    network_up.name,
    network_down.name,
}, {
    background = { color = colors.bg1 },
    popup = { align = "center", height = 31 },
})

local connection = sbar.add("item", "widgets.network.popup.connection", {
    position = "popup." .. network_bracket.name,
    width = popup_width,
    icon = {
        align = "left",
        string = "Connection",
        width = popup_width / 2,
        font = {
            style = settings.font.style_map["Bold"],
        },
    },
    label = {
        string = "Detecting...",
        width = popup_width / 2,
        align = "right",
        max_chars = 26,
        font = {
            style = settings.font.style_map["Bold"],
        },
    },
    background = {
        height = 2,
        color = colors.grey,
        y_offset = -18,
    },
})

local hostname = sbar.add("item", "widgets.network.popup.hostname", {
    position = "popup." .. network_bracket.name,
    icon = {
        align = "left",
        string = "Hostname",
        width = popup_width / 2,
    },
    label = {
        string = "N/A",
        width = popup_width / 2,
        align = "right",
        max_chars = 24,
    },
})

local ip = sbar.add("item", "widgets.network.popup.ip", {
    position = "popup." .. network_bracket.name,
    icon = {
        align = "left",
        string = "IP",
        width = popup_width / 2,
    },
    label = {
        string = "Disconnected",
        width = popup_width / 2,
        align = "right",
    },
})

local mask = sbar.add("item", "widgets.network.popup.mask", {
    position = "popup." .. network_bracket.name,
    icon = {
        align = "left",
        string = "Subnet mask",
        width = popup_width / 2,
    },
    label = {
        string = "N/A",
        width = popup_width / 2,
        align = "right",
    },
})

local router = sbar.add("item", "widgets.network.popup.router", {
    position = "popup." .. network_bracket.name,
    icon = {
        align = "left",
        string = "Router",
        width = popup_width / 2,
    },
    label = {
        string = "N/A",
        width = popup_width / 2,
        align = "right",
    },
})

local function format_rate(raw)
    if not raw then return "??" end
    if raw:match(" Bps$") then
        local value = tonumber(raw:match("^%d+"))
        if value then
            return string.format("%dKB/s", math.floor(value / 1000))
        end
    end
    return raw:gsub("Bps$", "B/s"):gsub("ps$", "/s")
end

local function popup_is_visible()
    return network_bracket:query().popup.drawing == "on"
end

local function start_network_load(interface)
    local target_interface = interface ~= "" and interface or "en1"
    sbar.exec(
        "killall network_load >/dev/null 2>&1; "
            .. "$CONFIG_DIR/helpers/event_providers/network_load/bin/network_load "
            .. target_interface
            .. " network_update 2.0"
    )
end

local function set_connection_label()
    connection:set({
        label = {
            string = format_connection_label(current_service, current_interface),
        },
    })
end

local function refresh_popup_fields()
    local service = current_service
    local interface = current_interface

    set_connection_label()

    sbar.exec("networksetup -getcomputername", function(result)
        hostname:set({
            label = trim(result) ~= "" and trim(result) or "N/A",
        })
    end)

    sbar.exec("ipconfig getifaddr " .. shell_quote(interface) .. " 2>/dev/null", function(result)
        if service ~= current_service or interface ~= current_interface then
            return
        end

        local ip_address = trim(result)
        ip:set({
            label = ip_address ~= "" and ip_address or "Disconnected",
        })
    end)

    if service == "" then
        mask:set({ label = "N/A" })
        router:set({ label = "N/A" })
        return
    end

    sbar.exec("networksetup -getinfo " .. shell_quote(service) .. " 2>/dev/null", function(result)
        if service ~= current_service or interface ~= current_interface then
            return
        end

        local subnet_mask = trim((result or ""):match("Subnet mask:%s*([^\r\n]+)") or "")
        local router_address = trim((result or ""):match("Router:%s*([^\r\n]+)") or "")

        mask:set({
            label = subnet_mask ~= "" and subnet_mask or "N/A",
        })
        router:set({
            label = router_address ~= "" and router_address or "N/A",
        })
    end)
end

local function refresh_interface_binding(force_restart)
    local next_service, next_interface = select_preferred_interface()
    local changed = next_service ~= current_service or next_interface ~= current_interface

    current_service = next_service
    current_interface = next_interface
    set_connection_label()

    if changed or force_restart then
        start_network_load(current_interface)
        if popup_is_visible() then
            refresh_popup_fields()
        end
    end

    return changed
end

local function toggle_details()
    if popup_is_visible() then
        network_bracket:set({ popup = { drawing = false } })
        return
    end

    refresh_interface_binding(false)
    refresh_popup_fields()
    network_bracket:set({ popup = { drawing = true } })
end

local function copy_label_to_clipboard(env)
    local label = sbar.query(env.NAME).label.value
    sbar.exec("echo " .. shell_quote(label) .. " | pbcopy")
    sbar.set(env.NAME, { label = { string = icons.clipboard, align = "center" } })
    sbar.delay(0.5, function()
        sbar.set(env.NAME, { label = { string = label, align = "right" } })
    end)
end

network_up:subscribe("network_update", function(env)
    local up = format_rate(env.upload)
    local down = format_rate(env.download)
    local up_color = (env.upload == "000 Bps" or up == "0KB/s") and colors.grey or colors.red
    local down_color = (env.download == "000 Bps" or down == "0KB/s") and colors.grey or colors.blue
    network_up:set({
        label = { string = icons.wifi.upload .. " " .. up, color = up_color },
    })
    network_down:set({
        label = { string = icons.wifi.download .. " " .. down, color = down_color },
    })

    refresh_interface_binding(false)
end)

network_up:subscribe("system_woke", function()
    refresh_interface_binding(true)
    refresh_popup_fields()
end)

network_up:subscribe("forced", function()
    refresh_interface_binding(false)
    if popup_is_visible() then
        refresh_popup_fields()
    end
end)

network_up:subscribe("mouse.clicked", toggle_details)
network_down:subscribe("mouse.clicked", toggle_details)

connection:subscribe("mouse.clicked", copy_label_to_clipboard)
hostname:subscribe("mouse.clicked", copy_label_to_clipboard)
ip:subscribe("mouse.clicked", copy_label_to_clipboard)
mask:subscribe("mouse.clicked", copy_label_to_clipboard)
router:subscribe("mouse.clicked", copy_label_to_clipboard)

-- Padding after network widget
sbar.add("item", "widgets.network.padding", {
    position = "right",
    width = settings.group_paddings,
    background = { drawing = false },
    icon = { drawing = false },
    label = { drawing = false },
})

refresh_interface_binding(true)
