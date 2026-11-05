--!strict
-- Rolls what a player catches: rarity (Luck), human type (favourite bait),
-- weight (Size Boost), modifiers (Modifier Boost) and the Cash value.
-- Server only; the client never rolls anything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)

export type Roll = {
	t: string,
	w: number,
	m: { string },
	v: number,
	rarity: string,
}

export type Stats = {
	luck: number,
	sizeBoost: number,
	modifierBoost: number,
	cashBonus: number,
	bait: string,
}

local CatchRoller = {}

local rng = Random.new()

-- Human types of a zone, grouped by rarity.
local byZone: { [string]: { [string]: { Catalog.HumanType } } } = {}
for _, human in Catalog.Humans do
	local zone = byZone[human.zone] or {}
	byZone[human.zone] = zone
	local list = zone[human.rarity] or {}
	zone[human.rarity] = list
	table.insert(list, human)
end
for _, zone in byZone do
	for _, list in zone do
		table.sort(list, function(a, b)
			return a.id < b.id
		end)
	end
end

local rarityById: { [string]: Config.RarityDef } = {}
for _, rarity in Config.Rarities do
	rarityById[rarity.id] = rarity
end

function CatchRoller.rarity(id: string): Config.RarityDef?
	return rarityById[id]
end

local function pickWeighted<T>(entries: { { item: T, weight: number } }): T?
	local total = 0
	for _, entry in entries do
		total += entry.weight
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	for _, entry in entries do
		roll -= entry.weight
		if roll <= 0 then
			return entry.item
		end
	end
	return entries[#entries].item
end

-- Value for a given type, weight and modifier list.
function CatchRoller.value(human: Catalog.HumanType, weight: number, mods: { string }, cashBonus: number): number
	local avg = (human.minWeight + human.maxWeight) / 2
	local value = human.baseValue * weight / avg
	for _, modId in mods do
		for _, mod in Config.Modifiers do
			if mod.id == modId then
				value *= mod.mult
			end
		end
	end
	return math.max(1, math.floor(value * (1 + cashBonus) + 0.5))
end

function CatchRoller.roll(zoneId: string, stats: Stats): Roll?
	local zone = byZone[zoneId]
	if not zone then
		return nil
	end

	-- 1. Rarity: only tiers this zone has; Luck raises the rarer ones.
	local rarityEntries = {}
	for _, rarity in Config.Rarities do
		if zone[rarity.id] then
			table.insert(rarityEntries, { item = rarity, weight = rarity.base * (1 + stats.luck * rarity.luckBonus) })
		end
	end
	local rarity = pickWeighted(rarityEntries)
	if not rarity then
		return nil
	end

	-- 2. Type: a type whose favourite bait is on the hook is twice as likely.
	local typeEntries = {}
	for _, human in zone[rarity.id] do
		table.insert(typeEntries, { item = human, weight = if human.favouriteBait == stats.bait then 2 else 1 })
	end
	local human = pickWeighted(typeEntries) :: Catalog.HumanType

	-- 3. Weight: small is common; Size Boost pushes it up.
	local exponent = Config.SizeSkew / (1 + math.max(0, stats.sizeBoost))
	local weight = human.minWeight + (human.maxWeight - human.minWeight) * rng:NextNumber() ^ exponent
	weight = math.floor(weight * 10 + 0.5) / 10

	-- 4. Modifiers: each rolls on its own and they stack.
	local mods = {}
	for _, mod in Config.Modifiers do
		if rng:NextNumber() < mod.chance * (1 + math.max(0, stats.modifierBoost)) then
			table.insert(mods, mod.id)
		end
	end

	return {
		t = human.id,
		w = weight,
		m = mods,
		v = CatchRoller.value(human, weight, mods, stats.cashBonus),
		rarity = rarity.id,
	}
end

function CatchRoller.random(): Random
	return rng
end

return CatchRoller
