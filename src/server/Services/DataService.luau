--!strict
-- Loads, holds and saves player data. A session lock stops two servers from
-- writing the same save at once. When DataStores are unavailable (a place
-- opened from a local file), Studio falls back to temporary data that is never
-- written, so the game still runs.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Remotes = ReplicatedStorage.Remotes

export type Catch = {
	t: string, -- human type id
	w: number, -- weight in kg (one decimal)
	m: { string }, -- modifier ids
	v: number, -- Cash value, fixed when caught
}

export type IndexEntry = { count: number, best: number }

export type PlayerData = {
	version: number,
	cash: number,
	totalEarned: number,
	rods: { [string]: boolean },
	rod: string,
	nets: { [string]: boolean },
	net: string,
	baitCounts: { [string]: number },
	bait: string,
	zones: { [string]: boolean },
	catches: { Catch },
	index: { [string]: IndexEntry },
	stats: { caught: number, fed: number },
	receipts: { string },
}

local DataService = {}

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore(Config.Data.StoreName)
end)

local profiles: { [Player]: PlayerData } = {}
local dirty: { [Player]: boolean } = {}
local unsaved: { [Player]: boolean } = {}

local loadedEvent = Instance.new("BindableEvent")
DataService.Loaded = loadedEvent.Event -- (player, data)
local changedEvent = Instance.new("BindableEvent")
DataService.Changed = changedEvent.Event -- (player, data)

local function defaultData(): PlayerData
	return {
		version = 1,
		cash = Config.StartingCash,
		totalEarned = 0,
		rods = { stick = true },
		rod = "stick",
		nets = { bag = true },
		net = "bag",
		baitCounts = {},
		bait = "coin",
		zones = { sunny_shore = true },
		catches = {},
		index = {},
		stats = { caught = 0, fed = 0 },
		receipts = {},
	}
end

-- Fills fields added after a save was first created.
local function reconcile(data: any): PlayerData
	local defaults = defaultData() :: any
	for key, value in defaults do
		if data[key] == nil then
			data[key] = value
		end
	end
	for key, value in defaults.stats do
		if data.stats[key] == nil then
			data.stats[key] = value
		end
	end
	return data
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

local function claim(player: Player): (PlayerData?, boolean)
	assert(store, "no DataStore")
	local jobId = game.JobId
	local now = os.time()
	local lockedElsewhere = false

	local stored = store:UpdateAsync(keyFor(player), function(current)
		current = current or { data = defaultData() }
		local lock = current.lock
		if lock and lock.jobId ~= jobId and now - lock.time < Config.Data.SessionLockTimeout then
			lockedElsewhere = true
			return nil
		end
		lockedElsewhere = false
		current.lock = { jobId = jobId, time = now }
		return current
	end)

	if lockedElsewhere or not stored then
		return nil, lockedElsewhere
	end
	return reconcile(stored.data or defaultData()), false
end

local function write(player: Player, data: PlayerData, release: boolean): boolean
	if not store then
		return false
	end
	local jobId = game.JobId
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(current)
			current = current or {}
			if current.lock and current.lock.jobId ~= jobId then
				return nil -- another server took over this save
			end
			current.data = data
			current.lock = if release then nil else { jobId = jobId, time = os.time() }
			return current
		end)
	end)
	if not ok then
		warn(`[DataService] save failed for {player.UserId}: {err}`)
	end
	return ok
end

local function makeLeaderstats(player: Player, data: PlayerData)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local cash = Instance.new("NumberValue")
	cash.Name = Strings.get("hud.cash")
	cash.Value = data.cash
	cash.Parent = folder
	folder.Parent = player
end

-- What the client sees. Everything except receipts.
function DataService.snapshot(data: PlayerData)
	return {
		cash = data.cash,
		rods = table.clone(data.rods),
		rod = data.rod,
		nets = table.clone(data.nets),
		net = data.net,
		baitCounts = table.clone(data.baitCounts),
		bait = data.bait,
		zones = table.clone(data.zones),
		catches = table.clone(data.catches),
		index = table.clone(data.index),
		stats = table.clone(data.stats),
	}
end

function DataService.replicate(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	local cash = stats and stats:FindFirstChildWhichIsA("NumberValue")
	if cash then
		cash.Value = data.cash
	end
	Remotes.DataChanged:FireClient(player, DataService.snapshot(data))
end

-- Call after any change to a player's data.
function DataService.markChanged(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	dirty[player] = true
	DataService.replicate(player)
	changedEvent:Fire(player, data)
end

local function load(player: Player)
	local data: PlayerData? = nil
	if store then
		for attempt = 1, Config.Data.LoadAttempts do
			local ok, result, lockedElsewhere = pcall(claim, player)
			if ok and result then
				data = result
				break
			end
			if not ok then
				warn(`[DataService] load attempt {attempt} failed for {player.UserId}: {result}`)
				if RunService:IsStudio() then
					break -- no API access in Studio; don't make the tester wait
				end
			elseif lockedElsewhere then
				task.wait(5)
			end
			if player.Parent == nil then
				return
			end
			task.wait(attempt)
		end
	end

	if not data then
		if RunService:IsStudio() then
			warn("[DataService] using temporary data (publish the place and enable Studio API access to test saving)")
			data = defaultData()
			unsaved[player] = true
		else
			player:Kick(Strings.get("data.load_failed"))
			return
		end
	end
	local loaded = data :: PlayerData

	if player.Parent == nil then
		if not unsaved[player] then
			write(player, loaded, true)
		end
		unsaved[player] = nil
		return
	end

	profiles[player] = loaded
	makeLeaderstats(player, loaded)
	DataService.replicate(player)
	loadedEvent:Fire(player, loaded)
end

local releasing: { [Player]: boolean } = {}

local function release(player: Player)
	if releasing[player] then
		return
	end
	releasing[player] = true
	local data = profiles[player]
	if data and not unsaved[player] then
		write(player, data, true)
	end
	profiles[player] = nil
	dirty[player] = nil
	unsaved[player] = nil
	releasing[player] = nil
end

function DataService.get(player: Player): PlayerData?
	return profiles[player]
end

function DataService.addCash(player: Player, amount: number)
	local data = profiles[player]
	if not data or amount <= 0 or amount ~= amount or amount == math.huge then
		return
	end
	amount = math.floor(amount)
	data.cash += amount
	data.totalEarned += amount
	DataService.markChanged(player)
end

-- Checks and spends in one step so two requests can't both pass the check.
function DataService.spendCash(player: Player, amount: number): boolean
	local data = profiles[player]
	if not data or amount < 0 or amount ~= amount or data.cash < amount then
		return false
	end
	data.cash -= amount
	DataService.markChanged(player)
	return true
end

function DataService.hasReceipt(player: Player, purchaseId: string): boolean
	local data = profiles[player]
	return data ~= nil and table.find(data.receipts, purchaseId) ~= nil
end

function DataService.recordReceipt(player: Player, purchaseId: string)
	local data = profiles[player]
	if not data then
		return
	end
	table.insert(data.receipts, purchaseId)
	while #data.receipts > Config.Data.MaxReceiptHistory do
		table.remove(data.receipts, 1)
	end
	dirty[player] = true
end

function DataService.saveNow(player: Player): boolean
	local data = profiles[player]
	if not data then
		return false
	end
	if unsaved[player] then
		return true
	end
	local ok = write(player, data, false)
	if ok then
		dirty[player] = nil
	end
	return ok
end

function DataService.start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(release)

	Remotes.GetData.OnServerInvoke = function(player: Player)
		local data = profiles[player]
		return data and DataService.snapshot(data)
	end

	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveInterval)
			for player in dirty do
				task.spawn(DataService.saveNow, player)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				release(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait()
		end
	end)
end

return DataService
