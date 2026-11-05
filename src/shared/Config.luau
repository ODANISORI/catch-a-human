--!strict
-- Every tuning number for the first playable lives here.
-- All values are starting points from the game plan; tune after playtesting.

local Config = {}

Config.Data = {
	StoreName = "PlayerData_v1",
	AutosaveInterval = 120,
	SessionLockTimeout = 1800,
	LoadAttempts = 4,
	MaxReceiptHistory = 50,
}

Config.StartingCash = 0

-- Rarities, rarest last. luckBonus: weight = base * (1 + Luck * luckBonus).
-- difficulty makes rarer humans harder to reel.
export type RarityDef = {
	id: string,
	name: string,
	base: number,
	luckBonus: number,
	difficulty: number,
	color: Color3,
}

Config.Rarities = {
	{ id = "common", name = "Common", base = 55, luckBonus = 0, difficulty = 1.0, color = Color3.fromRGB(190, 190, 190) },
	{ id = "uncommon", name = "Uncommon", base = 27, luckBonus = 0.01, difficulty = 1.1, color = Color3.fromRGB(90, 210, 90) },
	{ id = "rare", name = "Rare", base = 12, luckBonus = 0.02, difficulty = 1.25, color = Color3.fromRGB(70, 150, 255) },
	{ id = "epic", name = "Epic", base = 4.5, luckBonus = 0.03, difficulty = 1.4, color = Color3.fromRGB(175, 90, 255) },
	{ id = "legendary", name = "Legendary", base = 1.2, luckBonus = 0.04, difficulty = 1.6, color = Color3.fromRGB(255, 200, 40) },
	{ id = "mythic", name = "Mythic", base = 0.25, luckBonus = 0.05, difficulty = 1.8, color = Color3.fromRGB(255, 60, 60) },
	{ id = "exotic", name = "Exotic", base = 0.05, luckBonus = 0.06, difficulty = 2.0, color = Color3.fromRGB(255, 120, 220) },
} :: { RarityDef }

-- Modifiers roll independently and stack (values multiply).
-- Modifier Boost multiplies every chance: chance * (1 + boost).
Config.Modifiers = {
	{ id = "sunburnt", name = "Sunburnt", chance = 0.08, mult = 1.25 },
	{ id = "soaked", name = "Soaked", chance = 0.05, mult = 1.5 },
	{ id = "shiny", name = "Shiny", chance = 0.02, mult = 2 },
	{ id = "golden", name = "Golden", chance = 0.005, mult = 4 },
}

-- Size roll: weight = min + (max - min) * r ^ SizeSkew, small catches more common.
-- Size Boost lowers the exponent: SizeSkew / (1 + sizeBoost).
-- Value = baseValue * weight / ((min + max) / 2) * modifiers * cash bonus.
Config.SizeSkew = 1.5

Config.Fishing = {
	CastRangeStudsPerPoint = 5, -- rod Cast Range 10 = 50 studs
	CastTolerance = 6, -- studs of slack for lag
	AttractRadius = 25, -- humans this close to the bait walk over
	AttractRadiusPerBaitTier = 3,
	NudgeAfter = 5, -- seconds; then a human up to 1.6x the radius away is sent over
	NudgeRadiusMult = 1.6,
	BiteTimeout = 15, -- seconds with no bite and the bait comes back
	HumanWalkSpeed = 8, -- studs per second while walking to bait
	HookWindow = 1.0, -- seconds to click once a human grabs the bait
	HookLatencyAllowance = 0.35,
	-- Reeling (server simulates at TickRate)
	TickRate = 10,
	ReelStartProgress = 0.2,
	ReelGainPerSecond = 0.12, -- times rod Reel Strength * Reel Speed, divided by difficulty
	ReelDecayPerSecond = 0.05, -- when not holding
	ThrashEvery = { 2.5, 4.5 },
	ThrashLength = { 0.8, 1.4 },
	ThrashWarning = 0.4,
	TensionGainPerSecond = 0.9, -- holding during a thrash
	TensionDecayPerSecond = 0.5,
	MaxReelSeconds = 60, -- safety cap
}

Config.Kraken = {
	FeedDistance = 30,
}

Config.Humans = {
	WanderSpeed = 5,
	RespawnDelay = 6, -- seconds after a catch before a new human walks on
}

Config.RateLimits = {
	CastRequest = 3, -- per second
	ShopRequest = 6,
	ReelInput = 25,
	HookRequest = 6,
}

return Config
