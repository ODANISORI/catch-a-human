--!strict
-- Player-facing text. English first (broad audience); other languages later.
-- Services return codes; the client turns codes into text here.

local Strings = {}

local en: { [string]: string } = {
	["hud.cash"] = "Cash",
	["hud.net"] = "Net",
	["hud.shop"] = "Shop",
	["hud.bait"] = "Bait",
	["fish.cast_hint"] = "Click the beach to cast",
	["fish.cast_hint_touch"] = "Aim at the beach and tap Cast",
	["fish.waiting"] = "Waiting for a bite...",
	["fish.bite"] = "BITE! Click now!",
	["fish.bite_touch"] = "BITE! Tap Hook!",
	["fish.reeling"] = "Hold to reel. Let go when it thrashes!",
	["fish.thrash"] = "It's thrashing! Let go!",
	["fish.btn_cast"] = "Cast",
	["fish.btn_hook"] = "Hook",
	["fish.btn_reel"] = "Reel",
	["fish.btn_cancel"] = "Pull in",
	["result.caught"] = "Caught!",
	["result.escaped"] = "It got away!",
	["result.snapped"] = "The line snapped!",
	["result.missed"] = "Too slow, it walked off.",
	["result.no_bite"] = "Nobody bit. Try somewhere busier.",
	["result.feed"] = "The Kraken loved it! +%s",
	["code.not_ready"] = "Still loading your data...",
	["code.busy"] = "You're already fishing.",
	["code.net_full"] = "Your net is full! Feed the Kraken at the reef.",
	["code.not_in_water"] = "Get in the water to cast.",
	["code.too_far"] = "Too far. Get closer to the beach.",
	["code.no_zone"] = "Cast onto a beach or the pier.",
	["code.zone_locked"] = "Unlock this island in the Shop first.",
	["code.no_bait"] = "Out of that bait. Switched to Coins.",
	["code.not_enough"] = "Not enough Cash.",
	["code.owned"] = "You already own that.",
	["code.not_owned"] = "You don't own that.",
	["code.bad_request"] = "Something went wrong.",
	["code.too_fast"] = "Slow down a little.",
	["code.net_empty"] = "Your net is empty. Go catch some humans!",
	["code.too_far_kraken"] = "Swim closer to the Kraken.",
	["code.ok"] = "Done!",
	["shop.title"] = "Shop",
	["shop.rods"] = "Rods",
	["shop.nets"] = "Nets",
	["shop.bait"] = "Bait",
	["shop.islands"] = "Islands",
	["shop.buy"] = "Buy",
	["shop.equip"] = "Equip",
	["shop.equipped"] = "Equipped",
	["shop.unlocked"] = "Unlocked",
	["shop.buy10"] = "Buy 10",
	["shop.free"] = "Free",
	["kraken.prompt"] = "Feed the Kraken",
	["kraken.name"] = "Kraken",
	["data.load_failed"] = "Couldn't load your save. Please rejoin.",
}

function Strings.get(key: string): string
	return en[key] or key
end

function Strings.code(code: string): string
	return en["code." .. code] or en["code.bad_request"]
end

return Strings
