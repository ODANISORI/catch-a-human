--!strict
-- Gear, bait, zones and human types for the first playable (MVP zones 1 and 2).
-- Prices and stats follow the game plan; values are to tune after playtesting.

export type Rod = {
	id: string,
	name: string,
	price: number,
	order: number,
	luck: number,
	reelStrength: number,
	reelSpeed: number,
	castRange: number,
	sizeBoost: number,
	modifierBoost: number,
	cashBonus: number,
}

export type Net = { id: string, name: string, price: number, order: number, capacity: number }

export type Bait = {
	id: string,
	name: string,
	pricePer10: number, -- 0 = free and unlimited
	order: number,
	luck: number,
}

export type HumanType = {
	id: string,
	name: string,
	zone: string,
	rarity: string,
	baseValue: number,
	minWeight: number,
	maxWeight: number,
	favouriteBait: string,
	shirt: Color3,
	pants: Color3,
}

export type Zone = {
	id: string,
	name: string,
	price: number,
	order: number,
	-- Where humans walk (axis-aligned box on the XZ plane, Y = ground height).
	walkMin: Vector3,
	walkMax: Vector3,
	maxHumans: number,
}

local Catalog = {}

Catalog.Rods = {
	stick = { id = "stick", name = "Stick Rod", price = 0, order = 1, luck = 1, reelStrength = 1, reelSpeed = 1.0, castRange = 10, sizeBoost = 0, modifierBoost = 0, cashBonus = 0 },
	wooden = { id = "wooden", name = "Wooden Rod", price = 600, order = 2, luck = 3, reelStrength = 1.5, reelSpeed = 1.0, castRange = 12, sizeBoost = 0, modifierBoost = 0, cashBonus = 0 },
	bamboo = { id = "bamboo", name = "Bamboo Rod", price = 5000, order = 3, luck = 6, reelStrength = 2, reelSpeed = 1.1, castRange = 14, sizeBoost = 0, modifierBoost = 0, cashBonus = 0 },
	fiberglass = { id = "fiberglass", name = "Fiberglass Rod", price = 45000, order = 4, luck = 12, reelStrength = 3, reelSpeed = 1.1, castRange = 16, sizeBoost = 0, modifierBoost = 0, cashBonus = 0 },
} :: { [string]: Rod }

Catalog.Nets = {
	bag = { id = "bag", name = "Plastic Bag", price = 0, order = 1, capacity = 3 },
	bucket = { id = "bucket", name = "Bucket", price = 1000, order = 2, capacity = 6 },
	net = { id = "net", name = "Fishing Net", price = 15000, order = 3, capacity = 12 },
} :: { [string]: Net }

Catalog.Baits = {
	coin = { id = "coin", name = "Coin", pricePer10 = 0, order = 1, luck = 0 },
	dollar = { id = "dollar", name = "Dollar Bill", pricePer10 = 50, order = 2, luck = 2 },
	hotdog = { id = "hotdog", name = "Hot Dog", pricePer10 = 400, order = 3, luck = 4 },
	phone = { id = "phone", name = "Smartphone", pricePer10 = 4000, order = 4, luck = 8 },
} :: { [string]: Bait }

-- Map layout (see Map/MapBuilder): water surface at Y = 0.
Catalog.Zones = {
	sunny_shore = {
		id = "sunny_shore",
		name = "Sunny Shore",
		price = 0,
		order = 1,
		walkMin = Vector3.new(-60, 2, -205),
		walkMax = Vector3.new(60, 2, -150),
		maxHumans = 10,
	},
	old_pier = {
		id = "old_pier",
		name = "Old Pier",
		price = 2500,
		order = 2,
		walkMin = Vector3.new(150, 6, 40),
		walkMax = Vector3.new(230, 6, 70),
		maxHumans = 8,
	},
} :: { [string]: Zone }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

Catalog.Humans = {
	-- Sunny Shore ($5 - $250 range)
	tourist = { id = "tourist", name = "Tourist", zone = "sunny_shore", rarity = "common", baseValue = 20, minWeight = 40, maxWeight = 140, favouriteBait = "dollar", shirt = rgb(255, 140, 60), pants = rgb(230, 220, 180) },
	sunbather = { id = "sunbather", name = "Sunbather", zone = "sunny_shore", rarity = "common", baseValue = 25, minWeight = 45, maxWeight = 120, favouriteBait = "coin", shirt = rgb(255, 230, 90), pants = rgb(80, 160, 230) },
	ice_cream_kid = { id = "ice_cream_kid", name = "Kid with Ice Cream", zone = "sunny_shore", rarity = "uncommon", baseValue = 40, minWeight = 20, maxWeight = 55, favouriteBait = "hotdog", shirt = rgb(255, 150, 200), pants = rgb(120, 200, 255) },
	surfer = { id = "surfer", name = "Surfer", zone = "sunny_shore", rarity = "uncommon", baseValue = 55, minWeight = 55, maxWeight = 110, favouriteBait = "dollar", shirt = rgb(40, 200, 200), pants = rgb(30, 60, 140) },
	lifeguard = { id = "lifeguard", name = "Lifeguard", zone = "sunny_shore", rarity = "rare", baseValue = 90, minWeight = 60, maxWeight = 120, favouriteBait = "hotdog", shirt = rgb(230, 40, 40), pants = rgb(230, 40, 40) },
	influencer = { id = "influencer", name = "Influencer", zone = "sunny_shore", rarity = "epic", baseValue = 150, minWeight = 45, maxWeight = 90, favouriteBait = "phone", shirt = rgb(200, 120, 255), pants = rgb(250, 250, 250) },
	treasure_hunter = { id = "treasure_hunter", name = "Treasure Hunter", zone = "sunny_shore", rarity = "legendary", baseValue = 220, minWeight = 60, maxWeight = 130, favouriteBait = "phone", shirt = rgb(150, 110, 60), pants = rgb(90, 70, 40) },
	-- Old Pier ($30 - $1.5K range)
	fisherman = { id = "fisherman", name = "Fisherman", zone = "old_pier", rarity = "common", baseValue = 140, minWeight = 60, maxWeight = 140, favouriteBait = "hotdog", shirt = rgb(70, 110, 70), pants = rgb(60, 60, 70) },
	seagull_feeder = { id = "seagull_feeder", name = "Seagull Feeder", zone = "old_pier", rarity = "common", baseValue = 170, minWeight = 50, maxWeight = 110, favouriteBait = "dollar", shirt = rgb(240, 240, 240), pants = rgb(110, 90, 160) },
	arcade_kid = { id = "arcade_kid", name = "Arcade Kid", zone = "old_pier", rarity = "uncommon", baseValue = 300, minWeight = 25, maxWeight = 65, favouriteBait = "phone", shirt = rgb(60, 220, 120), pants = rgb(40, 40, 40) },
	pier_chef = { id = "pier_chef", name = "Pier Chef", zone = "old_pier", rarity = "rare", baseValue = 550, minWeight = 70, maxWeight = 150, favouriteBait = "hotdog", shirt = rgb(255, 255, 255), pants = rgb(30, 30, 30) },
	magician = { id = "magician", name = "Magician", zone = "old_pier", rarity = "epic", baseValue = 900, minWeight = 55, maxWeight = 100, favouriteBait = "coin", shirt = rgb(30, 20, 60), pants = rgb(30, 20, 60) },
	ship_captain = { id = "ship_captain", name = "Ship Captain", zone = "old_pier", rarity = "legendary", baseValue = 1300, minWeight = 70, maxWeight = 150, favouriteBait = "phone", shirt = rgb(20, 40, 110), pants = rgb(240, 240, 240) },
} :: { [string]: HumanType }

-- Sorted lists for menus.
local function sorted<T>(map: { [string]: T }): { T }
	local list = {}
	for _, item in map do
		table.insert(list, item)
	end
	table.sort(list, function(a: any, b: any)
		return a.order < b.order
	end)
	return list
end

Catalog.rodList = sorted(Catalog.Rods)
Catalog.netList = sorted(Catalog.Nets)
Catalog.baitList = sorted(Catalog.Baits)
Catalog.zoneList = sorted(Catalog.Zones)

function Catalog.baitTier(baitId: string): number
	local bait = Catalog.Baits[baitId]
	return if bait then bait.order - 1 else 0
end

return Catalog
