# catch-a-human

Roblox reverse-fishing simulator (working title "Fish for Humans"). You are a fish with a rod: bait humans on the beach, hook them, reel them in and feed them to the Kraken for Cash. Progression follows Prospecting!: rarities, sizes, modifiers, gear tiers and islands bought with Cash.

Design notes, briefs and the dev log live in the Roblox Dev vault (`Ongoing projects/Fish for Humans/`).

## Tooling

- [Rojo](https://rojo.space) project (`default.project.json`); tools pinned with Rokit (`rokit.toml`). All code is `--!strict` Luau.
- Build a place file: `rojo build -o CatchAHuman.rbxl`, then open it in Studio and press Play.
- Lint: `selene src`.

## Agent skills

`.claude/skills/` holds 23 Roblox reference skills (Luau, security, DataStores, UI, networking, code review and more) from [EL4CTEO/roblox-skills](https://github.com/EL4CTEO/roblox-skills), MIT. Claude Code loads the matching skill when a task needs it. See `.claude/skills/SOURCE.md` for the version and how to update.

## Layout

| Path | In Roblox | Contents |
| --- | --- | --- |
| `src/shared/` | ReplicatedStorage.Shared | `Config` (tuning numbers), `Catalog` (rods, nets, bait, islands, humans), `Strings` (UI text), `Format` |
| `src/server/` | ServerScriptService.Server | `init.server.luau` boots everything |
| `src/server/Services/` | | `DataService` (saving), `FishingService` (cast, bite, hook, reel), `CatchRoller` (rarity, size, modifiers, value), `HumanService` (humans on the islands), `KrakenService` (feeding for Cash), `ShopService` |
| `src/server/Map/MapBuilder.luau` | | Placeholder blockout of the sea, the Kraken's reef, Sunny Shore and Old Pier |
| `src/client/` | StarterPlayerScripts.Client | `State`, `Controllers/` (HUD, fishing input and bar, shop), `UI/Theme` (all placeholder UI) |
