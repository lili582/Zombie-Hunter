-- Server start, headless: the safehouse and every map really build (real Instances, so a bad
-- property value fails here instead of leaving players in the sky in Studio).
local lib = require("./lib")
local test, expect = lib.test, lib.expect
local World = require("./roblox")
local Maps = require("../src/shared/Config/Maps")

local function mapService()
	local game, requireModule = World.new()
	local services = game:GetService("ServerScriptService").Server.Services
	return game, requireModule(services.MapService)
end

test("server start builds the safehouse lobby and the first map", function()
	local game, MapService = mapService()
	local info = MapService.load()
	local workspace = game:GetService("Workspace")
	expect(workspace:FindFirstChild("Lobby") ~= nil).toBe(true)
	expect(workspace:FindFirstChild("Map") ~= nil).toBe(true)
	expect(#info.humanStarts >= 1).toBe(true)
	expect(#info.zombieSpawns >= 3).toBe(true)
end)

test("the safehouse has every station players use", function()
	local _, MapService = mapService()
	MapService.load()
	expect(World.tagged("LobbySpawn")).toBe(1)
	expect(World.tagged("MapVotePrompt")).toBe(3)
	expect(World.tagged("AlphaPickPrompt")).toBe(3)
	expect(World.tagged("ShopPrompt")).toBe(1)
	expect(World.tagged("CatalogPrompt")).toBe(1)
	expect(#MapService.lobby.mapSlots).toBe(3)
	expect(MapService.lobby.modeLabel.Text).toBe("WAITING FOR PLAYERS")
end)

for _, mapId in Maps.order do
	test(`{mapId} builds with all its spots`, function()
		local _, MapService = mapService()
		MapService.load()
		local info = MapService.loadMap(mapId)
		local meta = MapService.metas()[mapId]
		expect(#info.towerSpots).toBe(#meta.towerSpots)
		expect(#info.heliZones).toBe(meta.heliZoneCount)
		expect(#info.humanStarts >= 2).toBe(true)
		expect(#info.zombieSpawns >= 3).toBe(true)
		expect(#info.ammoSpawns >= 1).toBe(true)
		expect(#info.lockers >= 1).toBe(true)
	end)
end
