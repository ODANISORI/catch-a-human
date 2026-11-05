--!strict
-- Placeholder HUD: Cash, net count, bait picker, Shop button, toasts and the
-- catch popup. The UI builder replaces this with the real design.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Strings = require(ReplicatedStorage.Shared.Strings)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local HudController = {}

local gui: ScreenGui
local toastLabel: TextLabel
local toastToken = 0

function HudController.toast(text: string, color: Color3?)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = text
	toastLabel.TextColor3 = color or Theme.colors.text
	toastLabel.TextTransparency = 0
	toastLabel.TextStrokeTransparency = 0.3
	toastLabel.Visible = true
	task.delay(2.5, function()
		if token == toastToken then
			TweenService:Create(toastLabel, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local function rarityColor(id: string): Color3
	for _, r in Config.Rarities do
		if r.id == id then
			return r.color
		end
	end
	return Theme.colors.text
end

local function rarityName(id: string): string
	for _, r in Config.Rarities do
		if r.id == id then
			return r.name
		end
	end
	return id
end

local function modName(id: string): string
	for _, m in Config.Modifiers do
		if m.id == id then
			return m.name
		end
	end
	return id
end

local function ownedBaits(data: { [string]: any }): { string }
	local list = {}
	for _, bait in Catalog.baitList do
		if bait.pricePer10 == 0 or (data.baitCounts[bait.id] or 0) > 0 then
			table.insert(list, bait.id)
		end
	end
	return list
end

function HudController.start(actions: { openShop: () -> () })
	gui = Theme.create("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Cash and net, top left
	local cashValue = Theme.label({ Text = "$0", TextSize = 26, TextColor3 = Theme.colors.cash, Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 16) })
	local netValue = Theme.label({ Text = "0/3", TextSize = 20, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 62) })
	Theme.create("Frame", {
		Name = "Stats",
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.fromOffset(170, 92),
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = 0.15,
		Parent = gui,
		Theme.corner(12),
		Theme.stroke(),
		Theme.create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingTop = UDim.new(0, 6) }),
		Theme.label({ Text = Strings.get("hud.cash"), TextSize = 14, TextColor3 = Theme.colors.muted, Size = UDim2.new(1, 0, 0, 16) }),
		cashValue,
		Theme.label({ Text = Strings.get("hud.net"), TextSize = 14, TextColor3 = Theme.colors.muted, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 46) }),
		netValue,
	})

	-- Left side buttons: Shop, Bait
	local shopButton = Theme.button({
		Name = "Shop",
		Text = Strings.get("hud.shop"),
		Position = UDim2.new(0, 12, 0.5, -60),
		Size = UDim2.fromOffset(110, 48),
		BackgroundColor3 = Theme.colors.accent,
		TextColor3 = Color3.fromRGB(40, 30, 0),
		TextSize = 22,
		Parent = gui,
	})
	shopButton.Activated:Connect(actions.openShop)

	local baitButton = Theme.button({
		Name = "Bait",
		Text = "Bait: Coin",
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(170, 44),
		BackgroundColor3 = Theme.colors.panel,
		TextSize = 16,
		Parent = gui,
	})
	baitButton.Activated:Connect(function()
		local data = State.data
		if not data then
			return
		end
		local list = ownedBaits(data)
		local index = table.find(list, data.bait) or 0
		local nextId = list[(index % #list) + 1]
		local ok, res = pcall(function()
			return (Remotes:WaitForChild("ShopRequest") :: RemoteFunction):InvokeServer("select_bait", nextId)
		end)
		if ok and res and not res.ok then
			HudController.toast(Strings.code(res.code), Theme.colors.bad)
		end
	end)

	toastLabel = Theme.label({
		Name = "Toast",
		Text = "",
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.new(0.9, 0, 0, 30),
		TextStrokeTransparency = 0.3,
		Visible = false,
		Parent = gui,
	})

	local function refresh(data: { [string]: any })
		cashValue.Text = Format.cash(data.cash)
		local net = Catalog.Nets[data.net] or Catalog.Nets.bag
		netValue.Text = `{#data.catches}/{net.capacity}`
		netValue.TextColor3 = if #data.catches >= net.capacity then Theme.colors.bad else Theme.colors.text
		local bait = Catalog.Baits[data.bait] or Catalog.Baits.coin
		local count = if bait.pricePer10 == 0 then "free" else tostring(data.baitCounts[bait.id] or 0)
		baitButton.Text = `{Strings.get("hud.bait")}: {bait.name} ({count})`
	end
	State.Changed:Connect(refresh)
	if State.data then
		refresh(State.data)
	end

	-- Catch popup
	(Remotes:WaitForChild("CatchResult") :: RemoteEvent).OnClientEvent:Connect(function(catch)
		local def = Catalog.Humans[catch.t]
		local mods = {}
		for _, id in catch.m do
			table.insert(mods, modName(id))
		end
		local modText = if #mods > 0 then table.concat(mods, " ") .. " " else ""
		local text = `{modText}{def and def.name or catch.t} ({rarityName(catch.rarity)}) {Format.kg(catch.w)}  {Format.cash(catch.v)}`
		HudController.toast(text, rarityColor(catch.rarity))
		if catch.net >= catch.capacity then
			task.delay(2.6, function()
				HudController.toast(Strings.code("net_full"), Theme.colors.accent)
			end)
		end
	end);

	(Remotes:WaitForChild("FeedResult") :: RemoteEvent).OnClientEvent:Connect(function(res)
		if res.code then
			HudController.toast(Strings.code(res.code), Theme.colors.bad)
		else
			HudController.toast(string.format(Strings.get("result.feed"), Format.cash(res.total)), Theme.colors.cash)
		end
	end)
end

return HudController
