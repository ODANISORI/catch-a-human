--!strict
-- Cast -> bite -> hook -> reel -> net. The server runs the whole thing; the
-- client only sends "cast here", "hook", "holding / not holding" and "pull in",
-- and draws what FishingState tells it.
--
-- FishingState payloads (server -> client):
--   { state = "idle", result = "caught" | "escaped" | "snapped" | "missed" | "no_bite" | "cancelled" | nil }
--   { state = "waiting", bait = Vector3 }
--   { state = "bite", window = number }
--   { state = "reeling", p = progress 0..1, tn = tension 0..1, thrash = bool, warn = bool, rarity = id }
-- CatchResult (server -> client), once the catch is saved in the net:
--   { t, w, m, v, rarity, net = count, capacity = number }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = ReplicatedStorage.Remotes

local MapBuilder = require(script.Parent.Parent.Map.MapBuilder)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local CatchRoller = require(script.Parent.CatchRoller)
local DataService = require(script.Parent.DataService)
local HumanService = require(script.Parent.HumanService)

type State = "waiting" | "bite" | "reeling"

type Session = {
	player: Player,
	state: State,
	zone: string,
	target: Vector3,
	bait: string,
	baitPart: BasePart,
	human: HumanService.Human?,
	humanToken: number,
	roll: CatchRoller.Roll?,
	biteAt: number,
	-- reeling
	progress: number,
	tension: number,
	holding: boolean,
	gain: number,
	thrashStart: number,
	thrashEnd: number,
	reelStart: number,
	closed: boolean,
}

local FishingService = {}

local sessions: { [Player]: Session } = {}
local rng = Random.new()
local caughtEvent = Instance.new("BindableEvent")
FishingService.Caught = caughtEvent.Event -- (player, roll) after it is saved in the net

local function result(ok: boolean, code: string)
	return { ok = ok, code = code }
end

local function rodOf(data: DataService.PlayerData): Catalog.Rod
	return Catalog.Rods[data.rod] or Catalog.Rods.stick
end

function FishingService.capacity(data: DataService.PlayerData): number
	local net = Catalog.Nets[data.net] or Catalog.Nets.bag
	return net.capacity
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function rodTip(player: Player): Attachment?
	local character = player.Character
	local rod = character and character:FindFirstChild("FishingRod")
	return rod and rod:FindFirstChild("Tip", true) :: Attachment?
end

-- Which unlocked-or-not zone a point on land belongs to.
local function zoneAt(point: Vector3): Catalog.Zone?
	for _, zone in Catalog.Zones do
		local pad = 8
		if
			point.X >= zone.walkMin.X - pad
			and point.X <= zone.walkMax.X + pad
			and point.Z >= zone.walkMin.Z - pad
			and point.Z <= zone.walkMax.Z + pad
			and math.abs(point.Y - zone.walkMin.Y) <= 12
		then
			return zone
		end
	end
	return nil
end

local function send(player: Player, payload: { [string]: any })
	Remotes.FishingState:FireClient(player, payload)
end

local function makeBait(session: Session, tip: Attachment?)
	local p = Instance.new("Part")
	p.Name = "Bait"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(0.8, 0.8, 0.8)
	p.Color = Color3.fromRGB(255, 215, 60)
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CFrame = CFrame.new(session.target + Vector3.new(0, 0.4, 0))
	local attachment = Instance.new("Attachment")
	attachment.Parent = p
	if tip then
		local line = Instance.new("Beam")
		line.Name = "Line"
		line.Attachment0 = tip
		line.Attachment1 = attachment
		line.Width0 = 0.08
		line.Width1 = 0.08
		line.Color = ColorSequence.new(Color3.new(1, 1, 1))
		line.Transparency = NumberSequence.new(0.2)
		line.FaceCamera = true
		line.CurveSize0 = -2
		line.Segments = 8
		line.Parent = p
	end
	p.Parent = Workspace:FindFirstChild("Baits") or Workspace
	session.baitPart = p
end

local function close(session: Session, reason: string)
	if session.closed then
		return
	end
	session.closed = true
	if sessions[session.player] == session then
		sessions[session.player] = nil
	end
	session.baitPart:Destroy()
	local human = session.human
	if human and reason ~= "caught" and HumanService.isJob(human, session.humanToken) then
		HumanService.release(human)
	end
	if session.player.Parent then
		send(session.player, { state = "idle", result = reason })
	end
end

local function stillOpen(session: Session): boolean
	return not session.closed and sessions[session.player] == session
end

local function statsFor(data: DataService.PlayerData, baitId: string): CatchRoller.Stats
	local rod = rodOf(data)
	local bait = Catalog.Baits[baitId] or Catalog.Baits.coin
	return {
		luck = rod.luck + bait.luck,
		sizeBoost = rod.sizeBoost,
		modifierBoost = rod.modifierBoost,
		cashBonus = rod.cashBonus,
		bait = bait.id,
	}
end

-- Uses one bait. Coins are free and unlimited. Returns false when out.
local function useBait(data: DataService.PlayerData, baitId: string): boolean
	local bait = Catalog.Baits[baitId]
	if not bait then
		return false
	end
	if bait.pricePer10 == 0 then
		return true
	end
	local count = data.baitCounts[baitId] or 0
	if count <= 0 then
		return false
	end
	data.baitCounts[baitId] = count - 1
	return true
end

local function bite(session: Session)
	local player = session.player
	local data = DataService.get(player)
	local human = session.human
	if not data or not human then
		close(session, "cancelled")
		return
	end
	if not useBait(data, session.bait) then
		-- Ran out while waiting (e.g. used on another cast); fall back to coins.
		session.bait = "coin"
		data.bait = "coin"
	end
	DataService.markChanged(player)

	local roll = CatchRoller.roll(session.zone, statsFor(data, session.bait))
	if not roll then
		close(session, "cancelled")
		return
	end
	session.roll = roll
	local rarity = CatchRoller.rarity(roll.rarity)
	HumanService.dressAs(human, roll.t, if rarity then rarity.color else Color3.new(1, 1, 1))

	session.state = "bite"
	session.biteAt = os.clock()
	send(player, { state = "bite", window = Config.Fishing.HookWindow })

	task.delay(Config.Fishing.HookWindow + Config.Fishing.HookLatencyAllowance, function()
		if stillOpen(session) and session.state == "bite" then
			close(session, "missed")
		end
	end)
end

local function waitForBite(session: Session)
	local f = Config.Fishing
	local radius = f.AttractRadius + f.AttractRadiusPerBaitTier * Catalog.baitTier(session.bait)
	local started = os.clock()
	while stillOpen(session) do
		local elapsed = os.clock() - started
		if elapsed > f.BiteTimeout then
			close(session, "no_bite")
			return
		end
		local searchRadius = if elapsed >= f.NudgeAfter then radius * f.NudgeRadiusMult else radius
		local human = HumanService.findFree(session.zone, session.target, searchRadius)
		if human then
			session.human = human
			session.humanToken = HumanService.claim(human)
			local arrived = HumanService.walkToBait(human, session.humanToken, session.target)
			if not stillOpen(session) then
				return -- close() already released the human
			end
			if arrived then
				bite(session)
			else
				close(session, "cancelled")
			end
			return
		end
		task.wait(0.25)
	end
end

local function nextThrash(session: Session, now: number)
	local f = Config.Fishing
	session.thrashStart = now + rng:NextNumber(f.ThrashEvery[1], f.ThrashEvery[2])
	session.thrashEnd = session.thrashStart + rng:NextNumber(f.ThrashLength[1], f.ThrashLength[2])
end

local function landCatch(session: Session)
	local player = session.player
	local data = DataService.get(player)
	local roll = session.roll
	if not data or not roll then
		close(session, "cancelled")
		return
	end
	table.insert(data.catches, { t = roll.t, w = roll.w, m = roll.m, v = roll.v })
	local entry = data.index[roll.t]
	if entry then
		entry.count += 1
		entry.best = math.max(entry.best, roll.w)
	else
		data.index[roll.t] = { count = 1, best = roll.w }
	end
	data.stats.caught += 1
	DataService.markChanged(player)

	if session.human then
		HumanService.remove(session.human)
	end
	close(session, "caught")
	Remotes.CatchResult:FireClient(player, {
		t = roll.t,
		w = roll.w,
		m = roll.m,
		v = roll.v,
		rarity = roll.rarity,
		net = #data.catches,
		capacity = FishingService.capacity(data),
	})
	caughtEvent:Fire(player, roll)
end

local function reelTick(session: Session, dt: number)
	local f = Config.Fishing
	local now = os.clock()
	if now >= session.thrashEnd then
		nextThrash(session, now)
	end
	local thrashing = now >= session.thrashStart and now < session.thrashEnd
	local warning = not thrashing and now >= session.thrashStart - f.ThrashWarning

	if session.holding then
		if thrashing then
			session.tension += f.TensionGainPerSecond * dt
		else
			session.progress += session.gain * dt
			session.tension = math.max(0, session.tension - f.TensionDecayPerSecond * dt)
		end
	else
		session.progress -= f.ReelDecayPerSecond * dt
		session.tension = math.max(0, session.tension - f.TensionDecayPerSecond * dt)
	end

	if session.tension >= 1 then
		close(session, "snapped")
		return
	end
	if session.progress <= 0 or now - session.reelStart > f.MaxReelSeconds then
		close(session, "escaped")
		return
	end
	if session.progress >= 1 then
		landCatch(session)
		return
	end

	-- Drag the human from the bait spot toward the fish.
	local root = rootOf(session.player)
	if root and session.human then
		local shore = Vector3.new(root.Position.X, session.target.Y, root.Position.Z)
		local t = math.clamp((session.progress - f.ReelStartProgress) / (1 - f.ReelStartProgress), 0, 1) * 0.7
		local ground = session.target:Lerp(shore, t)
		HumanService.dragTo(session.human, ground, dt)
	end

	send(session.player, {
		state = "reeling",
		p = session.progress,
		tn = session.tension,
		thrash = thrashing,
		warn = warning,
		rarity = if session.roll then session.roll.rarity else nil,
	})
end

local function onCast(player: Player, target: unknown)
	if not RateLimit.allow(player, "CastRequest", Config.RateLimits.CastRequest) then
		return result(false, "too_fast")
	end
	if typeof(target) ~= "Vector3" then
		return result(false, "bad_request")
	end
	local point = target :: Vector3
	if point.X ~= point.X or point.Y ~= point.Y or point.Z ~= point.Z then
		return result(false, "bad_request")
	end
	local data = DataService.get(player)
	if not data then
		return result(false, "not_ready")
	end
	if sessions[player] then
		return result(false, "busy")
	end
	if #data.catches >= FishingService.capacity(data) then
		return result(false, "net_full")
	end
	local root = rootOf(player)
	if not root then
		return result(false, "not_ready")
	end
	if root.Position.Y > 3 or MapBuilder.isOverLand(root.Position) then
		return result(false, "not_in_water")
	end
	local zone = zoneAt(point)
	if not zone then
		return result(false, "no_zone")
	end
	if not data.zones[zone.id] then
		return result(false, "zone_locked")
	end
	local range = rodOf(data).castRange * Config.Fishing.CastRangeStudsPerPoint + Config.Fishing.CastTolerance
	local flat = (point - root.Position) * Vector3.new(1, 0, 1)
	if flat.Magnitude > range then
		return result(false, "too_far")
	end
	local baitId = data.bait
	local bait = Catalog.Baits[baitId]
	if not bait or (bait.pricePer10 > 0 and (data.baitCounts[baitId] or 0) <= 0) then
		data.bait = "coin"
		DataService.markChanged(player)
		return result(false, "no_bait")
	end

	-- Snap the bait onto the walk surface of the zone.
	local landing = Vector3.new(
		math.clamp(point.X, zone.walkMin.X, zone.walkMax.X),
		zone.walkMin.Y,
		math.clamp(point.Z, zone.walkMin.Z, zone.walkMax.Z)
	)

	local session: Session = {
		player = player,
		state = "waiting",
		zone = zone.id,
		target = landing,
		bait = baitId,
		baitPart = nil :: any,
		human = nil,
		humanToken = 0,
		roll = nil,
		biteAt = 0,
		progress = 0,
		tension = 0,
		holding = false,
		gain = 0,
		thrashStart = 0,
		thrashEnd = 0,
		reelStart = 0,
		closed = false,
	}
	makeBait(session, rodTip(player))
	sessions[player] = session
	send(player, { state = "waiting", bait = landing })
	task.spawn(waitForBite, session)
	return result(true, "ok")
end

local function onHook(player: Player)
	if not RateLimit.allow(player, "HookRequest", Config.RateLimits.HookRequest) then
		return
	end
	local session = sessions[player]
	if not session or session.state ~= "bite" then
		return
	end
	local f = Config.Fishing
	if os.clock() - session.biteAt > f.HookWindow + f.HookLatencyAllowance then
		close(session, "missed")
		return
	end
	local data = DataService.get(player)
	local roll = session.roll
	if not data or not roll then
		close(session, "cancelled")
		return
	end
	local rod = rodOf(data)
	local def = Catalog.Humans[roll.t]
	local rarity = CatchRoller.rarity(roll.rarity)
	local avg = (def.minWeight + def.maxWeight) / 2
	local difficulty = (if rarity then rarity.difficulty else 1) * math.sqrt(roll.w / avg)
	session.gain = f.ReelGainPerSecond * rod.reelStrength * rod.reelSpeed / difficulty
	session.state = "reeling"
	session.progress = f.ReelStartProgress
	session.tension = 0
	session.holding = true -- they just clicked
	session.reelStart = os.clock()
	nextThrash(session, os.clock())
end

local function onReelInput(player: Player, holding: unknown)
	if not RateLimit.allow(player, "ReelInput", Config.RateLimits.ReelInput) then
		return
	end
	if typeof(holding) ~= "boolean" then
		return
	end
	local session = sessions[player]
	if session and session.state == "reeling" then
		session.holding = holding :: boolean
	end
end

local function onCancel(player: Player)
	local session = sessions[player]
	if session and session.state == "waiting" then
		close(session, "cancelled")
	end
end

local function giveRod(character: Model)
	local hand = character:WaitForChild("RightHand", 5) or character:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local rod = Instance.new("Part")
	rod.Name = "FishingRod"
	rod.Size = Vector3.new(0.25, 0.25, 6)
	rod.Color = Color3.fromRGB(120, 80, 45)
	rod.Material = Enum.Material.Wood
	rod.CanCollide = false
	rod.CanQuery = false
	rod.CanTouch = false
	rod.Massless = true
	rod.CFrame = hand.CFrame * CFrame.new(0, -0.6, -2.6) * CFrame.Angles(math.rad(35), 0, 0)
	local tip = Instance.new("Attachment")
	tip.Name = "Tip"
	tip.Position = Vector3.new(0, 0, -3)
	tip.Parent = rod
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = rod
	weld.Parent = rod
	rod.Parent = character
	-- The rod model itself is a placeholder for the 3D model brief.
	rod:SetAttribute("Placeholder", true)
end

function FishingService.isFishing(player: Player): boolean
	return sessions[player] ~= nil
end

function FishingService.start()
	Remotes.CastRequest.OnServerInvoke = onCast
	Remotes.HookRequest.OnServerEvent:Connect(onHook)
	Remotes.ReelInput.OnServerEvent:Connect(onReelInput)
	Remotes.CancelCast.OnServerEvent:Connect(onCancel)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			local old = sessions[player]
			if old then
				close(old, "cancelled")
			end
			giveRod(character)
		end)
		if player.Character then
			task.spawn(giveRod, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if session then
			close(session, "cancelled")
		end
	end)

	local accumulator = 0
	local step = 1 / Config.Fishing.TickRate
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < step then
			return
		end
		local elapsed = accumulator
		accumulator = 0
		for _, session in sessions do
			if session.state == "reeling" and not session.closed then
				reelTick(session, elapsed)
			end
		end
	end)
end

return FishingService
