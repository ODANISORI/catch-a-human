--!strict
-- Server entry point.

local MapBuilder = require(script.Map.MapBuilder)
local DataService = require(script.Services.DataService)
local FishingService = require(script.Services.FishingService)
local HumanService = require(script.Services.HumanService)
local KrakenService = require(script.Services.KrakenService)
local ShopService = require(script.Services.ShopService)

MapBuilder.build()

DataService.start()
HumanService.start()
FishingService.start()
KrakenService.start()
ShopService.start()
