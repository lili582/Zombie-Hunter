--!strict
-- Builds the safehouse (Maps/Safehouse) and the map being played (Maps/<id>), and finds the map's
-- tagged spots. A hand-built workspace.Map is played instead of the built-in maps: it only needs
-- parts tagged HumanStart (1+, more = players start in spread-out groups), ZombieSpawn (3+),
-- AmmoSpawn, TowerSpot (5+, ideally 8), HeliZone (1-3), Locker (the locker parts themselves) and
-- an optional part named "AlphaDoor".
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Maps = require(Shared.Config.Maps)

local MapsFolder = script.Parent.Parent:WaitForChild("Maps")
local Safehouse = require(MapsFolder.Safehouse)

local MapService = {}

export type MapInfo = {
	humanStart: CFrame,
	humanStarts: { CFrame }, -- every HumanStart spot: groups of players start at different ones
	zombieSpawns: { CFrame },
	ammoSpawns: { CFrame },
	lobbySpawn: CFrame,
	alphaDoor: BasePart?,
	towerSpots: { CFrame },
	heliZones: { CFrame },
	lockers: { BasePart },
}

-- Things on the lobby walls that LobbyService updates (nil if the lobby was hand-built).
export type LobbyRefs = Safehouse.Refs
MapService.lobby = nil :: LobbyRefs?

local function buildLobby()
	MapService.lobby = Safehouse.build(workspace)
end

-- Every map that can be played, by id (Config/Maps): each builds itself and owns its spots.
local MapLighting = require(MapsFolder.Lighting)
local BUILDERS: { [string]: any } = {
	Town = require(MapsFolder.Town),
	ForestCamp = require(MapsFolder.ForestCamp),
	School = require(MapsFolder.School),
	Mall = require(MapsFolder.Mall),
}

local current: MapInfo? = nil
local currentId: string? = nil
local customMap = false -- a hand-built workspace.Map: always played, never swapped

-- The CFrames of every part with `tag` inside `scope`.
local function cframesFor(scope: Instance, tag: string, required: number): { CFrame }
	local list = {}
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(scope) then
			table.insert(list, inst.CFrame)
		end
	end
	if #list < required then
		error(`MapService: missing tag {tag} (need {required}, found {#list})`)
	end
	return list
end

local function readInfo(map: Instance): MapInfo
	local lobby = workspace:FindFirstChild("Lobby") :: Instance
	local starts = cframesFor(map, "HumanStart", 1)
	local info: MapInfo = {
		humanStart = starts[1],
		humanStarts = starts,
		zombieSpawns = cframesFor(map, "ZombieSpawn", 3),
		ammoSpawns = cframesFor(map, "AmmoSpawn", 0),
		towerSpots = cframesFor(map, "TowerSpot", 0),
		heliZones = cframesFor(map, "HeliZone", 0),
		lockers = {},
		lobbySpawn = cframesFor(lobby, "LobbySpawn", 1)[1] + Vector3.new(0, 3, 0),
		alphaDoor = map:FindFirstChild("AlphaDoor", true) :: BasePart?,
	}
	for _, inst in CollectionService:GetTagged("Locker") do
		if inst:IsA("BasePart") and inst:IsDescendantOf(map) then
			table.insert(info.lockers, inst)
		end
	end
	print(
		`MapService: ZombieSpawn {#info.zombieSpawns}, AmmoSpawn {#info.ammoSpawns}, TowerSpot {#info.towerSpots}, `
			.. `HeliZone {#info.heliZones}, Locker {#info.lockers}`
	)
	return info
end

-- What the round rules need per map: tower spots and helicopter zone counts (plain data).
function MapService.metas(): { [string]: any }
	local metas = {}
	for id, builder in BUILDERS do
		metas[id] = builder.meta()
	end
	return metas
end

-- Builds the map with this id (the old map and its terrain go away) and puts its night on.
-- Loading the map that is already there does nothing.
function MapService.loadMap(mapId: string): MapInfo
	if customMap or (mapId == currentId and current) then
		return current :: MapInfo
	end
	local builder = BUILDERS[mapId] or BUILDERS.Town
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	workspace.Terrain:Clear()
	local map = Instance.new("Model")
	map.Name = "Map"
	map.Parent = workspace
	builder.build(map)
	MapLighting.apply(mapId)
	currentId = mapId
	current = readInfo(map)
	return current :: MapInfo
end

-- Server start: the safehouse, then the first map (or your own hand-built workspace.Map).
function MapService.load(): MapInfo
	if not workspace:FindFirstChild("Lobby") then
		buildLobby()
	end
	local handBuilt = workspace:FindFirstChild("Map")
	if handBuilt then
		customMap = true
		MapLighting.apply("Town")
		current = readInfo(handBuilt)
		return current :: MapInfo
	end
	-- testing a map: a String attribute StartMap = "ForestCamp" on Workspace before pressing Play
	local start = workspace:GetAttribute("StartMap")
	return MapService.loadMap(if type(start) == "string" and Maps.get(start) then start else Maps.order[1])
end

-- A hand-built map is always played (no map vote between maps).
function MapService.isCustom(): boolean
	return customMap
end

function MapService.setAlphaDoor(info: MapInfo, open: boolean)
	local door = info.alphaDoor
	if door then
		door.CanCollide = not open
		door.Transparency = if open then 1 else 0
	end
end

-- Lights buzz and flicker at random (under 3 flickers per second).
function MapService.startFlicker()
	task.spawn(function()
		while true do
			task.wait(math.random(6, 20) / 10)
			local lights = CollectionService:GetTagged("FlickerLight")
			if #lights == 0 then
				continue
			end
			local head = lights[math.random(1, #lights)]
			local light = head:FindFirstChildWhichIsA("Light")
			if light then
				for _ = 1, math.random(1, 3) do
					light.Enabled = false
					task.wait(0.08)
					light.Enabled = true
					task.wait(0.35)
				end
			end
		end
	end)
end

return MapService
