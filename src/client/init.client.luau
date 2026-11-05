--!strict
-- Client entry point.

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local State = require(script.State)
local FishingController = require(script.Controllers.FishingController)
local HudController = require(script.Controllers.HudController)
local ShopController = require(script.Controllers.ShopController)

State.start()
ShopController.start(HudController.toast)
HudController.start({ openShop = ShopController.toggle })
FishingController.start(HudController.toast)
