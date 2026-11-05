--!strict
-- Feeding the Kraken: every human in the net turns into Cash.
-- Triggered by the ProximityPrompt on the reef (works with mouse, keyboard,
-- touch and gamepad). FeedResult (server -> client): { total, count }.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = ReplicatedStorage.Remotes

local MapBuilder = require(script.Parent.Parent.Map.MapBuilder)
local DataService = require(script.Parent.DataService)

local KrakenService = {}

local fedEvent = Instance.new("BindableEvent")
KrakenService.Fed = fedEvent.Event -- (player, total, count)

local function root(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Returns a result code; also used by tests and other systems.
function KrakenService.feed(player: Player): (boolean, string)
	local data = DataService.get(player)
	if not data then
		return false, "not_ready"
	end
	local hrp = root(player)
	if not hrp or (hrp.Position - MapBuilder.KrakenFeedPoint).Magnitude > Config.Kraken.FeedDistance + 6 then
		return false, "too_far_kraken"
	end
	local count = #data.catches
	if count == 0 then
		return false, "net_empty"
	end
	local total = 0
	for _, catch in data.catches do
		total += catch.v
	end
	data.catches = {}
	data.stats.fed += count
	DataService.addCash(player, total) -- also marks the data changed
	Remotes.FeedResult:FireClient(player, { total = total, count = count })
	fedEvent:Fire(player, total, count)
	return true, "ok"
end

function KrakenService.start()
	local map = Workspace:WaitForChild("Map")
	local prompt = map:FindFirstChild("FeedPrompt", true) :: ProximityPrompt?
	if not prompt then
		warn("[KrakenService] no FeedPrompt in the map")
		return
	end
	prompt.Triggered:Connect(function(player: Player)
		local ok, code = KrakenService.feed(player)
		if not ok then
			Remotes.FeedResult:FireClient(player, { code = code })
		end
	end)
end

return KrakenService
