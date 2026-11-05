--!strict
-- Spawns placeholder humans on each island and walks them around. Bodies are
-- simple low-poly block people: an anchored invisible root with welded,
-- massless parts, moved by server tweens (cheap on phones, no Humanoid physics).
-- Walking humans look generic; when one bites, FishingService dresses it as the
-- type that was rolled (the catch is revealed as they hit the water).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)

export type Human = {
	id: number,
	zone: string,
	model: Model,
	root: BasePart,
	state: "wander" | "claimed" | "hooked" | "gone",
	token: number, -- bumps whenever the human gets a new job, to stop old ones
	tween: Tween?,
}

local HumanService = {}

local rng = Random.new()
local humans: { [number]: Human } = {}
local nextId = 0
local container: Folder

local SKIN = {
	Color3.fromRGB(255, 220, 180),
	Color3.fromRGB(235, 190, 145),
	Color3.fromRGB(200, 150, 105),
	Color3.fromRGB(150, 105, 70),
	Color3.fromRGB(105, 70, 45),
}
local CASUAL = {
	Color3.fromRGB(250, 250, 250),
	Color3.fromRGB(120, 180, 240),
	Color3.fromRGB(250, 170, 120),
	Color3.fromRGB(170, 220, 160),
	Color3.fromRGB(240, 220, 120),
}

local function addPart(model: Model, root: BasePart, name: string, size: Vector3, offset: Vector3, color: Color3, shape: Enum.PartType?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.CFrame = root.CFrame * CFrame.new(offset)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = p
	weld.Parent = p
	p.Parent = model
	return p
end

local function randomPoint(zone: Catalog.Zone): Vector3
	return Vector3.new(
		rng:NextNumber(zone.walkMin.X, zone.walkMax.X),
		zone.walkMin.Y,
		rng:NextNumber(zone.walkMin.Z, zone.walkMax.Z)
	)
end

local function rootCFrame(ground: Vector3): CFrame
	return CFrame.new(ground + Vector3.new(0, 2.5, 0))
end

local function build(zone: Catalog.Zone, at: Vector3): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "Human"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 5, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CFrame = rootCFrame(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	root.Parent = model
	model.PrimaryPart = root

	local skin = SKIN[rng:NextInteger(1, #SKIN)]
	local shirt = CASUAL[rng:NextInteger(1, #CASUAL)]
	local pants = CASUAL[rng:NextInteger(1, #CASUAL)]
	addPart(model, root, "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0.5, 0), shirt)
	addPart(model, root, "Head", Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 2.15, 0), skin)
	addPart(model, root, "LeftArm", Vector3.new(0.9, 2, 0.9), Vector3.new(-1.45, 0.5, 0), skin)
	addPart(model, root, "RightArm", Vector3.new(0.9, 2, 0.9), Vector3.new(1.45, 0.5, 0), skin)
	addPart(model, root, "LeftLeg", Vector3.new(0.95, 2, 0.95), Vector3.new(-0.5, -1.5, 0), pants)
	addPart(model, root, "RightLeg", Vector3.new(0.95, 2, 0.95), Vector3.new(0.5, -1.5, 0), pants)
	-- Eyes, so the face direction reads from a distance.
	addPart(model, root, "EyeL", Vector3.new(0.2, 0.25, 0.1), Vector3.new(-0.3, 2.3, -0.66), Color3.new(0.1, 0.1, 0.1))
	addPart(model, root, "EyeR", Vector3.new(0.2, 0.25, 0.1), Vector3.new(0.3, 2.3, -0.66), Color3.new(0.1, 0.1, 0.1))

	model:SetAttribute("Zone", zone.id)
	model.Parent = container
	return model, root
end

local function stopTween(human: Human)
	if human.tween then
		human.tween:Cancel()
		human.tween = nil
	end
end

-- Walks the human to a ground point. Yields until it arrives or is interrupted.
-- Returns true if it arrived and still has the same job.
local function walkTo(human: Human, ground: Vector3, speed: number): boolean
	local token = human.token
	stopTween(human)
	local from = human.root.Position
	local to = ground + Vector3.new(0, 2.5, 0)
	local flat = (to - from) * Vector3.new(1, 0, 1)
	local distance = flat.Magnitude
	if distance < 0.2 then
		return human.token == token
	end
	local tween = TweenService:Create(human.root, TweenInfo.new(distance / speed, Enum.EasingStyle.Linear), {
		CFrame = CFrame.lookAt(to, to + flat.Unit),
	})
	-- Face the way it walks straight away.
	human.root.CFrame = CFrame.lookAt(from, from + flat.Unit)
	human.tween = tween
	tween:Play()
	local state = tween.Completed:Wait()
	if human.tween == tween then
		human.tween = nil
	end
	return state == Enum.PlaybackState.Completed and human.token == token
end

local function wanderLoop(human: Human)
	local zone = Catalog.Zones[human.zone]
	while human.state == "wander" do
		local token = human.token
		walkTo(human, randomPoint(zone), Config.Humans.WanderSpeed)
		if human.state ~= "wander" or human.token ~= token then
			return
		end
		task.wait(rng:NextNumber(1, 4))
		if human.token ~= token then
			return
		end
	end
end

local function startWander(human: Human)
	human.token += 1
	human.state = "wander"
	task.spawn(wanderLoop, human)
end

local function spawnHuman(zone: Catalog.Zone)
	nextId += 1
	local model, root = build(zone, randomPoint(zone))
	local human: Human = {
		id = nextId,
		zone = zone.id,
		model = model,
		root = root,
		state = "wander",
		token = 0,
		tween = nil,
	}
	humans[human.id] = human
	startWander(human)
end

local function countIn(zoneId: string): number
	local n = 0
	for _, human in humans do
		if human.zone == zoneId then
			n += 1
		end
	end
	return n
end

-- Nearest wandering human in a zone within radius (flat distance) of a point.
function HumanService.findFree(zoneId: string, point: Vector3, radius: number): Human?
	local best: Human? = nil
	local bestDistance = radius
	for _, human in humans do
		if human.zone == zoneId and human.state == "wander" then
			local offset = (human.root.Position - point) * Vector3.new(1, 0, 1)
			local d = offset.Magnitude
			if d <= bestDistance then
				best = human
				bestDistance = d
			end
		end
	end
	return best
end

-- Takes a human out of wandering for a bait. Returns the job token.
function HumanService.claim(human: Human): number
	human.token += 1
	human.state = "claimed"
	stopTween(human)
	return human.token
end

-- Walks a claimed human to the bait. Yields; true when it arrived and the job
-- is still current.
function HumanService.walkToBait(human: Human, token: number, ground: Vector3): boolean
	if human.token ~= token or human.state ~= "claimed" then
		return false
	end
	local arrived = walkTo(human, ground, Config.Fishing.HumanWalkSpeed)
	return arrived and human.state == "claimed" and human.token == token
end

function HumanService.isJob(human: Human, token: number): boolean
	return human.token == token and human.state ~= "gone" and human.state ~= "wander"
end

-- Back to wandering (missed hook, escaped, cancelled cast).
function HumanService.release(human: Human)
	if human.state == "gone" then
		return
	end
	stopTween(human)
	local tag = human.root:FindFirstChild("Tag")
	if tag then
		tag:Destroy()
	end
	startWander(human)
end

-- Recolours the human as the rolled type and shows a name tag.
function HumanService.dressAs(human: Human, typeId: string, rarityColor: Color3)
	local def = Catalog.Humans[typeId]
	if not def then
		return
	end
	human.state = "hooked"
	local torso = human.model:FindFirstChild("Torso") :: BasePart?
	if torso then
		torso.Color = def.shirt
	end
	for _, name in { "LeftLeg", "RightLeg" } do
		local leg = human.model:FindFirstChild(name) :: BasePart?
		if leg then
			leg.Color = def.pants
		end
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Size = UDim2.fromOffset(160, 30)
	tag.StudsOffset = Vector3.new(0, 4, 0)
	tag.MaxDistance = 120
	tag.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0.2
	label.TextColor3 = rarityColor
	label.Text = def.name
	label.Parent = tag
	tag.Parent = human.root
end

-- Moves the hooked human smoothly to a point (called each reel tick).
function HumanService.dragTo(human: Human, ground: Vector3, seconds: number)
	if human.state == "gone" then
		return
	end
	stopTween(human)
	local from = human.root.Position
	local to = ground + Vector3.new(0, 2.5, 0)
	-- Dragged backwards: keep facing away from where it is pulled.
	local back = (from - to) * Vector3.new(1, 0, 1)
	local goal = if back.Magnitude > 0.05 then CFrame.lookAt(to, to + back.Unit) else human.root.CFrame.Rotation + to
	local tween = TweenService:Create(human.root, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { CFrame = goal })
	human.tween = tween
	tween:Play()
end

-- Caught: the human "floats back to the beach in a bubble" (placeholder:
-- removed now, a fresh one walks on after RespawnDelay).
function HumanService.remove(human: Human)
	if human.state == "gone" then
		return
	end
	human.state = "gone"
	human.token += 1
	stopTween(human)
	humans[human.id] = nil
	human.model:Destroy()
	local zone = Catalog.Zones[human.zone]
	task.delay(Config.Humans.RespawnDelay, function()
		if countIn(zone.id) < zone.maxHumans then
			spawnHuman(zone)
		end
	end)
end

function HumanService.start()
	container = Workspace:FindFirstChild("Humans") :: Folder
	if not container then
		container = Instance.new("Folder")
		container.Name = "Humans"
		container.Parent = Workspace
	end
	for _, zone in Catalog.Zones do
		for _ = 1, zone.maxHumans do
			spawnHuman(zone)
		end
	end
	-- Top up now and then in case a respawn was skipped.
	task.spawn(function()
		while true do
			task.wait(10)
			for _, zone in Catalog.Zones do
				if countIn(zone.id) < zone.maxHumans then
					spawnHuman(zone)
				end
			end
		end
	end)
end

return HumanService
