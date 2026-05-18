local colors = require("colors")
local settings = require("settings")
local Aerospace = require("helpers.aerospace")

local MAX_WS = 10
local MAX_APPS = 12

local ok, aerospace = pcall(Aerospace.new)
if not ok or not aerospace then
	return
end

local slots = {}

local function name_num(i)
	return "aerospace.ws." .. i .. ".num"
end
local function name_app(i, j)
	return "aerospace.ws." .. i .. ".app." .. j
end
local function name_brk(i)
	return "aerospace.ws." .. i .. ".bracket"
end

local function make_num(i)
	local item = SBAR.add("item", name_num(i), {
		drawing = false,
		icon = {
			string = tostring(i),
			font = { family = settings.font.text, style = "Bold", size = 12.0 },
			color = colors.grey,
			padding_left = 4,
			padding_right = 4,
			y_offset = 1,
		},
		label = { drawing = false },
	})
	item:subscribe("mouse.clicked", function(_)
		os.execute("aerospace workspace " .. tostring(i))
	end)
	return item
end

local function make_app(i, j)
	local item = SBAR.add("item", name_app(i, j), {
		drawing = false,
		icon = { drawing = false },
		label = { drawing = false },
		padding_left = 2,
		padding_right = 2,
		background = {
			drawing = true,
			image = { scale = 0.80, clip = 0.8 },
		},
	})
	item:subscribe("mouse.clicked", function(_)
		os.execute("aerospace workspace " .. tostring(i))
	end)
	return item
end

local function make_bracket(i, members)
	return SBAR.add("bracket", name_brk(i), members, {
		blur_radius = 12,
		background = {
			drawing = true,
			color = colors.bg05,
			border_color = colors.bg1,
			blur_radius = 32,
			border_width = 1,
			height = 32,
			corner_radius = 10,
		},
	})
end

local function build_pool()
	for i = 1, MAX_WS do
		local num = make_num(i)
		local apps = {}
		local members = { num.name }
		for j = 1, MAX_APPS do
			apps[j] = make_app(i, j)
			members[#members + 1] = apps[j].name
		end
		local bracket = make_bracket(i, members)
		slots[i] = { num = num, apps = apps, bracket = bracket }
	end
end

local function paint(idx, focused, wins, slot)
	slot.num:set({
		drawing = true,
		icon = { color = focused and colors.white or colors.grey },
	})

	for j = 1, MAX_APPS do
		local win = wins[j]
		local item = slot.apps[j]
		if win then
			local app = win["app-name"] or "?"
			item:set({
				drawing = true,
				background = {
					drawing = true,
					blur_radius = 12,
					image = { string = "app." .. app, scale = focused and 1 or 0.80 },
					x_offset = -1,
				},
			})
		else
			item:set({ drawing = false })
		end
	end

	slot.bracket:set({ background = { drawing = focused } })
end

local function hide(slot)
	slot.num:set({ drawing = false })
	for j = 1, MAX_APPS do
		slot.apps[j]:set({ drawing = false })
	end
	slot.bracket:set({ background = { drawing = false } })
end

local function refresh()
	local ok_ws, ws_list = pcall(function()
		return aerospace:query_workspaces()
	end)
	if not ok_ws or type(ws_list) ~= "table" then
		return
	end

	local ok_wins, all_windows = pcall(function()
		return aerospace:list_all_windows()
	end)
	if not ok_wins or type(all_windows) ~= "table" then
		all_windows = {}
	end

	local by_ws = {}
	for _, w in ipairs(all_windows) do
		local name = w["workspace"]
		if name then
			by_ws[name] = by_ws[name] or {}
			table.insert(by_ws[name], w)
		end
	end

	local seen = {}
	for _, ws in ipairs(ws_list) do
		local name = ws["workspace"]
		local idx = tonumber(name)
		if idx and idx >= 1 and idx <= MAX_WS then
			paint(idx, ws["workspace-is-focused"] == true, by_ws[name] or {}, slots[idx])
			seen[idx] = true
		end
	end
	for i = 1, MAX_WS do
		if not seen[i] then
			hide(slots[i])
		end
	end
end

SBAR.add("event", "aerospace_workspace_change")

SBAR.delay(0.5, function()
	build_pool()

	local watcher = SBAR.add("item", "aerospace.watcher", {
		drawing = false,
		updates = "on",
		padding_left = 0,
		padding_right = 0,
	})

	watcher:subscribe(
		{ "aerospace_workspace_change", "front_app_switched", "space_change", "system_woke", "forced" },
		function(_)
			SBAR.animate("circ", 8, refresh)
		end
	)

	refresh()
end)
