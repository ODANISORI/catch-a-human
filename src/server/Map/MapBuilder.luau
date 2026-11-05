--!strict
-- Generates a placeholder blockout at startup: the sea (terrain water), the
-- Kraken's reef at the centre, Sunny Shore and the Old Pier. The Map builder
-- will replace this; it does nothing if Workspace already has a "Map" model.
--
-- Layout (studs, water surface at Y = 0):
--   Kraken reef      centre (0, 0, 0), platform radius 18, spawn on it
--   Sunny Shore      sand island x -75..75, z -230..-140, top Y = 2; beach slopes
--                    into the water down to z = -122. Humans walk z -205..-150
--   Old Pier         wooden deck x 145..235, z 35..75, top Y = 6, island east of it
--                    at x 235..300. Humans walk on the deck

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Format = require(ReplicatedStorage.Shared.Format)

local MapBuilder = {}

-- XZ footprints of land. Standing over one of these means "not in the water".
export type Box = { min: Vector2, max: Vector2 }
MapBuilder.Land = {
	{ min = Vector2.new(-75, -230), max = Vector2.new(75, -132) }, -- Sunny Shore (incl. upper beach)
	{ min = Vector2.new(145, 35), max = Vector2.new(300, 75) }, -- Old Pier deck and island
	{ min = Vector2.new(235, 10), max = Vector2.new(300, 110) }, -- Old Pier island
} :: { Box }

MapBuilder.KrakenFeedPoint = Vector3.new(0, 3, 12)
MapBuilder.SpawnPoint = Vector3.new(0, 4, -8)

local SAND = Color3.fromRGB(240, 220, 160)
local WOOD = Color3.fromRGB(150, 105, 65)
local DARK_WOOD = Color3.fromRGB(105, 75, 45)
local ROCK = Color3.fromRGB(120, 125, 135)
local LEAF = Color3.fromRGB(70, 180, 80)
local TRUNK = Color3.fromRGB(140, 100, 60)
local KRAKEN = Color3.fromRGB(150, 80, 200)

local function part(props: { [string]: any }): BasePart
	local className = props.ClassName or "Part"
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		if key ~= "ClassName" and key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function sign(parent: Instance, adornee: BasePart, title: string, subtitle: string?)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 70)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = 250
	gui.LightInfluence = 0
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 0.6)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = title
	label.Parent = gui
	if subtitle then
		local sub = label:Clone()
		sub.Position = UDim2.fromScale(0, 0.6)
		sub.Size = UDim2.fromScale(1, 0.4)
		sub.Text = subtitle
		sub.Parent = gui
	end
	gui.Parent = parent
end

local function palm(parent: Instance, base: Vector3, height: number)
	part({
		Name = "Trunk",
		ClassName = "Part",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 1.6, 1.6),
		CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = TRUNK,
		Parent = parent,
	})
	for i = 0, 4 do
		local angle = math.rad(i * 72)
		part({
			Name = "Leaf",
			Size = Vector3.new(1, 0.4, 7),
			CFrame = CFrame.new(base + Vector3.new(0, height, 0))
				* CFrame.Angles(0, angle, 0)
				* CFrame.new(0, 0, -3)
				* CFrame.Angles(math.rad(-20), 0, 0),
			Color = LEAF,
			CanCollide = false,
			CanQuery = false,
			Parent = parent,
		})
	end
end

local function umbrella(parent: Instance, base: Vector3, color: Color3)
	part({
		Name = "Pole",
		Size = Vector3.new(0.3, 6, 0.3),
		CFrame = CFrame.new(base + Vector3.new(0, 3, 0)),
		Color = Color3.new(1, 1, 1),
		Parent = parent,
	})
	part({
		Name = "Canopy",
		ClassName = "Part",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 7, 7),
		CFrame = CFrame.new(base + Vector3.new(0, 6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		CanCollide = false,
		CanQuery = false,
		Parent = parent,
	})
	part({
		Name = "Towel",
		Size = Vector3.new(3, 0.1, 6),
		CFrame = CFrame.new(base + Vector3.new(2.5, 0.05, 0)),
		Color = color,
		CanCollide = false,
		Parent = parent,
	})
end

local function buildSea()
	local terrain = Workspace.Terrain
	terrain:FillBlock(CFrame.new(0, -34, 0), Vector3.new(1000, 8, 1000), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(0, -15, 0), Vector3.new(1000, 30, 1000), Enum.Material.Water)
	terrain.WaterColor = Color3.fromRGB(40, 170, 200)
	terrain.WaterTransparency = 0.6
	terrain.WaterWaveSize = 0.08
	terrain.WaterWaveSpeed = 6
	terrain.WaterReflectance = 0.4
end

local function buildReef(map: Model)
	local reef = Instance.new("Model")
	reef.Name = "KrakenReef"
	reef.Parent = map

	-- A cylinder's length runs along X; rotated upright it spans Y -33 to 3.
	part({
		Name = "Platform",
		ClassName = "Part",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(36, 36, 36),
		CFrame = CFrame.new(0, -15, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = ROCK,
		Material = Enum.Material.Slate,
		Parent = reef,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(MapBuilder.SpawnPoint - Vector3.new(0, 0.5, 0))
	spawn.Color = Color3.fromRGB(255, 240, 200)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = reef

	-- The Kraken: big friendly head rising out of the water behind the platform.
	local kraken = Instance.new("Model")
	kraken.Name = "Kraken"
	kraken.Parent = reef
	local head = part({
		Name = "Head",
		ClassName = "Part",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(26, 26, 26),
		CFrame = CFrame.new(0, 8, 30),
		Color = KRAKEN,
		Parent = kraken,
	})
	for _, x in { -5, 5 } do
		part({
			Name = "Eye",
			ClassName = "Part",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(6, 6, 6),
			CFrame = CFrame.new(x, 13, 18.5),
			Color = Color3.new(1, 1, 1),
			CanCollide = false,
			Parent = kraken,
		})
		part({
			Name = "Pupil",
			ClassName = "Part",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3, 3, 3),
			CFrame = CFrame.new(x, 13, 16),
			Color = Color3.fromRGB(20, 20, 30),
			CanCollide = false,
			Parent = kraken,
		})
	end
	part({
		Name = "Mouth",
		Size = Vector3.new(10, 2, 1),
		CFrame = CFrame.new(0, 5, 17.5),
		Color = Color3.fromRGB(80, 30, 100),
		CanCollide = false,
		Parent = kraken,
	})
	for i = 0, 5 do
		local angle = math.rad(-75 + i * 30)
		local dir = Vector3.new(math.sin(angle), 0, -math.cos(angle))
		part({
			Name = "Tentacle",
			ClassName = "Part",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(22, 3.5, 3.5),
			CFrame = CFrame.lookAt(Vector3.new(0, 0, 30) + dir * 20, Vector3.new(0, 0, 30) + dir * 40)
				* CFrame.Angles(0, math.rad(90), 0),
			Color = KRAKEN,
			CanCollide = false,
			Parent = kraken,
		})
	end
	kraken.PrimaryPart = head
	sign(kraken, head, Strings.get("kraken.name"), "Feed me humans for Cash!")

	local feed = part({
		Name = "FeedPoint",
		Size = Vector3.new(4, 4, 4),
		CFrame = CFrame.new(MapBuilder.KrakenFeedPoint),
		Transparency = 1,
		CanCollide = false,
		Parent = kraken,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FeedPrompt"
	prompt.ActionText = Strings.get("kraken.prompt")
	prompt.ObjectText = Strings.get("kraken.name")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 30
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = feed
end

local function buildSunnyShore(map: Model)
	local zone = Instance.new("Model")
	zone.Name = "SunnyShore"
	zone.Parent = map

	part({ Name = "Sand", Size = Vector3.new(150, 40, 90), CFrame = CFrame.new(0, -18, -185), Color = SAND, Material = Enum.Material.Sand, Parent = zone })
	-- Beach sloping into the water toward the reef (z -140 -> -122, Y 2 -> -6).
	local slope = part({ Name = "Beach", ClassName = "WedgePart", Size = Vector3.new(150, 8, 18), Color = SAND, Material = Enum.Material.Sand, Parent = zone })
	slope.CFrame = CFrame.new(0, -2, -131) * CFrame.Angles(0, math.rad(180), 0)

	for i, x in { -60, -30, 30, 60 } do
		palm(zone, Vector3.new(x, 2, -215 + (i % 2) * 6), 14 + (i % 3) * 2)
	end
	local colors = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(80, 170, 255), Color3.fromRGB(255, 210, 60), Color3.fromRGB(120, 220, 130) }
	for i = 1, 6 do
		umbrella(zone, Vector3.new(-55 + i * 16, 2, -160 - (i % 3) * 12), colors[(i % #colors) + 1])
	end
	local marker = part({ Name = "SignPost", Size = Vector3.new(1, 8, 1), CFrame = CFrame.new(0, 6, -142), Color = WOOD, Parent = zone })
	sign(zone, marker, Catalog.Zones.sunny_shore.name)
end

local function buildOldPier(map: Model)
	local zone = Instance.new("Model")
	zone.Name = "OldPier"
	zone.Parent = map

	part({ Name = "Deck", Size = Vector3.new(90, 2, 40), CFrame = CFrame.new(190, 5, 55), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = zone })
	for x = 150, 230, 16 do
		for _, z in { 37, 73 } do
			part({ Name = "Post", Size = Vector3.new(1.5, 30, 1.5), CFrame = CFrame.new(x, -10, z), Color = DARK_WOOD, Material = Enum.Material.Wood, Parent = zone })
			part({ Name = "Rail", Size = Vector3.new(1, 3, 1), CFrame = CFrame.new(x, 7.5, z), Color = DARK_WOOD, Parent = zone })
		end
	end
	part({ Name = "Island", Size = Vector3.new(65, 40, 100), CFrame = CFrame.new(267.5, -14, 60), Color = SAND, Material = Enum.Material.Sand, Parent = zone })
	part({ Name = "Shack", Size = Vector3.new(16, 10, 12), CFrame = CFrame.new(270, 11, 60), Color = Color3.fromRGB(200, 90, 70), Material = Enum.Material.WoodPlanks, Parent = zone })
	palm(zone, Vector3.new(285, 6, 25), 14)
	palm(zone, Vector3.new(285, 6, 95), 16)
	for i, z in { 15, 95 } do
		part({ Name = "Boat", Size = Vector3.new(18, 3, 7), CFrame = CFrame.new(175 + i * 20, 0.5, z), Color = Color3.fromRGB(240, 240, 240), Parent = zone })
	end

	local zoneDef = Catalog.Zones.old_pier
	local marker = part({ Name = "SignPost", Size = Vector3.new(1, 8, 1), CFrame = CFrame.new(150, 10, 55), Color = WOOD, Parent = zone })
	sign(zone, marker, zoneDef.name, "Unlock: " .. Format.cash(zoneDef.price))

	-- Buoy line marking the island's water (purely visual; the server checks unlocks).
	for x = 130, 230, 10 do
		part({ Name = "Buoy", ClassName = "Part", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(x, 0.3, 0), Color = Color3.fromRGB(255, 120, 40), CanCollide = false, Parent = zone })
	end
end

function MapBuilder.build()
	if Workspace:FindFirstChild("Map") then
		return
	end
	-- The Baseplate template's leftovers clash with the generated map.
	for _, name in { "Baseplate", "SpawnLocation" } do
		local leftover = Workspace:FindFirstChild(name)
		if leftover then
			leftover:Destroy()
		end
	end

	local map = Instance.new("Model")
	map.Name = "Map"
	buildSea()
	buildReef(map)
	buildSunnyShore(map)
	buildOldPier(map)
	folder("Humans", Workspace)
	folder("Baits", Workspace)
	map:SetAttribute("Generated", true)
	map.Parent = Workspace
end

function MapBuilder.isOverLand(position: Vector3): boolean
	for _, box in MapBuilder.Land do
		if position.X >= box.min.X and position.X <= box.max.X and position.Z >= box.min.Y and position.Z <= box.max.Y then
			return true
		end
	end
	return false
end

return MapBuilder
