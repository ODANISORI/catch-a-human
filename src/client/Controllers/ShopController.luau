--!strict
-- Placeholder shop: rods, nets, bait and islands. The UI builder replaces it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Format = require(ReplicatedStorage.Shared.Format)
local Strings = require(ReplicatedStorage.Shared.Strings)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ShopRequest = Remotes:WaitForChild("ShopRequest") :: RemoteFunction
local player = Players.LocalPlayer

local ShopController = {}

local panel: Frame
local list: ScrollingFrame
local tab = "rods"
local toast: (string, Color3?) -> ()

type Row = { id: string, title: string, detail: string, button: string, enabled: boolean, action: string? }

local function request(action: string, id: string)
	local ok, res = pcall(function()
		return ShopRequest:InvokeServer(action, id)
	end)
	if not ok or not res then
		toast(Strings.code("bad_request"), Theme.colors.bad)
	elseif not res.ok then
		toast(Strings.code(res.code), Theme.colors.bad)
	else
		toast(Strings.code("ok"), Theme.colors.cash)
	end
end

local function rowsFor(data: { [string]: any }): { Row }
	local rows: { Row } = {}
	if tab == "rods" then
		for _, rod in Catalog.rodList do
			local owned = data.rods[rod.id]
			local equipped = data.rod == rod.id
			table.insert(rows, {
				id = rod.id,
				title = rod.name,
				detail = `Luck {rod.luck} · Reel {rod.reelStrength} · Speed {rod.reelSpeed} · Range {rod.castRange}`,
				button = if equipped then Strings.get("shop.equipped") elseif owned then Strings.get("shop.equip") elseif rod.price == 0 then Strings.get("shop.free") else Format.cash(rod.price),
				enabled = not equipped,
				action = if owned then "equip_rod" else "buy_rod",
			})
		end
	elseif tab == "nets" then
		for _, net in Catalog.netList do
			local owned = data.nets[net.id]
			local equipped = data.net == net.id
			table.insert(rows, {
				id = net.id,
				title = net.name,
				detail = `Holds {net.capacity} humans`,
				button = if equipped then Strings.get("shop.equipped") elseif owned then Strings.get("shop.equip") elseif net.price == 0 then Strings.get("shop.free") else Format.cash(net.price),
				enabled = not equipped,
				action = if owned then "equip_net" else "buy_net",
			})
		end
	elseif tab == "bait" then
		for _, bait in Catalog.baitList do
			local free = bait.pricePer10 == 0
			local count = if free then "unlimited" else tostring(data.baitCounts[bait.id] or 0)
			table.insert(rows, {
				id = bait.id,
				title = bait.name,
				detail = `+{bait.luck} Luck · you have {count}`,
				button = if free then (if data.bait == bait.id then Strings.get("shop.equipped") else Strings.get("shop.equip")) else `{Strings.get("shop.buy10")} {Format.cash(bait.pricePer10)}`,
				enabled = not (free and data.bait == bait.id),
				action = if free then "select_bait" else "buy_bait",
			})
		end
	else
		for _, zone in Catalog.zoneList do
			local owned = data.zones[zone.id]
			table.insert(rows, {
				id = zone.id,
				title = zone.name,
				detail = `{zone.maxHumans} humans on the island`,
				button = if owned then Strings.get("shop.unlocked") else Format.cash(zone.price),
				enabled = not owned,
				action = "unlock_zone",
			})
		end
	end
	return rows
end

local function render()
	if not panel or not panel.Visible then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local data = State.data
	if not data then
		return
	end
	for i, row in rowsFor(data) do
		local button = Theme.button({
			Text = row.button,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(120, 40),
			TextSize = 16,
			BackgroundColor3 = if row.enabled then Theme.colors.button else Theme.colors.buttonOff,
			AutoButtonColor = row.enabled,
		})
		if row.enabled and row.action then
			local action = row.action
			button.Activated:Connect(function()
				request(action, row.id)
			end)
		end
		Theme.create("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1, -8, 0, 60),
			BackgroundColor3 = Theme.colors.panelDark,
			Parent = list,
			Theme.corner(8),
			Theme.label({ Text = row.title, TextSize = 20, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -150, 0, 24) }),
			Theme.label({ Text = row.detail, TextSize = 13, TextColor3 = Theme.colors.muted, Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -150, 0, 20), TextWrapped = true }),
			button,
		})
	end
end

function ShopController.toggle()
	panel.Visible = not panel.Visible
	render()
end

function ShopController.start(toastFn: (string, Color3?) -> ())
	toast = toastFn
	local gui = Theme.create("ScreenGui", {
		Name = "Shop",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		Parent = player:WaitForChild("PlayerGui"),
	})
	panel = Theme.create("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.8, 0),
		BackgroundColor3 = Theme.colors.panel,
		Visible = false,
		Parent = gui,
		Theme.corner(14),
		Theme.stroke(3),
		Theme.create("UISizeConstraint", { MaxSize = Vector2.new(560, 460) }),
		Theme.label({ Text = Strings.get("shop.title"), TextSize = 26, Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -80, 0, 32) }),
	})
	local close = Theme.button({
		Text = "X",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = Theme.colors.bad,
		Parent = panel,
	})
	close.Activated:Connect(ShopController.toggle)

	local tabs = Theme.create("Frame", {
		Position = UDim2.fromOffset(12, 48),
		Size = UDim2.new(1, -24, 0, 36),
		BackgroundTransparency = 1,
		Parent = panel,
		Theme.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
	})
	for _, entry in { { "rods", "shop.rods" }, { "nets", "shop.nets" }, { "bait", "shop.bait" }, { "islands", "shop.islands" } } do
		local b = Theme.button({ Text = Strings.get(entry[2]), Size = UDim2.new(0.25, -5, 1, 0), TextSize = 16, BackgroundColor3 = Theme.colors.panelDark, Parent = tabs })
		b.Activated:Connect(function()
			tab = entry[1]
			render()
		end)
	end

	list = Theme.create("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 92),
		Size = UDim2.new(1, -24, 1, -104),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
		Theme.create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	State.Changed:Connect(render)
end

return ShopController
