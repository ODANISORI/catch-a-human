--!strict
-- Buying and equipping rods and nets, buying and choosing bait, unlocking
-- islands. The client only asks; every check happens here.
--
-- ShopRequest(action, id) -> { ok, code }
--   "buy_rod" | "equip_rod" | "buy_net" | "equip_net" | "buy_bait" (10 at a time)
--   | "select_bait" | "unlock_zone"

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = ReplicatedStorage.Remotes

local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local DataService = require(script.Parent.DataService)

local ShopService = {}

local MAX_BAIT = 9990

local function result(ok: boolean, code: string)
	return { ok = ok, code = code }
end

local function handle(player: Player, action: unknown, id: unknown)
	if not RateLimit.allow(player, "ShopRequest", Config.RateLimits.ShopRequest) then
		return result(false, "too_fast")
	end
	if typeof(action) ~= "string" or typeof(id) ~= "string" then
		return result(false, "bad_request")
	end
	local data = DataService.get(player)
	if not data then
		return result(false, "not_ready")
	end

	if action == "buy_rod" or action == "equip_rod" then
		local rod = Catalog.Rods[id :: string]
		if not rod then
			return result(false, "bad_request")
		end
		if action == "buy_rod" then
			if data.rods[rod.id] then
				return result(false, "owned")
			end
			if not DataService.spendCash(player, rod.price) then
				return result(false, "not_enough")
			end
			data.rods[rod.id] = true
		elseif not data.rods[rod.id] then
			return result(false, "not_owned")
		end
		data.rod = rod.id
		DataService.markChanged(player)
		return result(true, "ok")
	elseif action == "buy_net" or action == "equip_net" then
		local net = Catalog.Nets[id :: string]
		if not net then
			return result(false, "bad_request")
		end
		if action == "buy_net" then
			if data.nets[net.id] then
				return result(false, "owned")
			end
			if not DataService.spendCash(player, net.price) then
				return result(false, "not_enough")
			end
			data.nets[net.id] = true
		elseif not data.nets[net.id] then
			return result(false, "not_owned")
		end
		-- A smaller net than the catches you carry is fine: you just can't cast
		-- until you feed the Kraken.
		data.net = net.id
		DataService.markChanged(player)
		return result(true, "ok")
	elseif action == "buy_bait" then
		local bait = Catalog.Baits[id :: string]
		if not bait or bait.pricePer10 <= 0 then
			return result(false, "bad_request")
		end
		local have = data.baitCounts[bait.id] or 0
		if have + 10 > MAX_BAIT then
			return result(false, "bad_request")
		end
		if not DataService.spendCash(player, bait.pricePer10) then
			return result(false, "not_enough")
		end
		data.baitCounts[bait.id] = have + 10
		data.bait = bait.id
		DataService.markChanged(player)
		return result(true, "ok")
	elseif action == "select_bait" then
		local bait = Catalog.Baits[id :: string]
		if not bait then
			return result(false, "bad_request")
		end
		if bait.pricePer10 > 0 and (data.baitCounts[bait.id] or 0) <= 0 then
			return result(false, "not_owned")
		end
		data.bait = bait.id
		DataService.markChanged(player)
		return result(true, "ok")
	elseif action == "unlock_zone" then
		local zone = Catalog.Zones[id :: string]
		if not zone then
			return result(false, "bad_request")
		end
		if data.zones[zone.id] then
			return result(false, "owned")
		end
		-- Islands unlock in order.
		for _, other in Catalog.zoneList do
			if other.order < zone.order and not data.zones[other.id] then
				return result(false, "zone_locked")
			end
		end
		if not DataService.spendCash(player, zone.price) then
			return result(false, "not_enough")
		end
		data.zones[zone.id] = true
		DataService.markChanged(player)
		return result(true, "ok")
	end
	return result(false, "bad_request")
end

function ShopService.start()
	Remotes.ShopRequest.OnServerInvoke = handle
end

return ShopService
