--!strict
-- Finds the tagged spots of the map. If there is no map yet, builds a greybox Town + a lobby,
-- so the game is playable right away. Replace workspace.Map with a hand-built map later:
-- it only needs parts tagged HumanStart (1+, more = players start in spread-out groups), ZombieSpawn (3+), AmmoSpawn, and an
-- optional part named "AlphaDoor". Phase 2 adds TowerSpot (5+, ideally 8), HeliZone (1-3) and
-- Locker (the locker parts themselves, any number).
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AlphaClasses = require(Shared.Config.AlphaClasses)
local Maps = require(Shared.Config.Maps)

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

local COLORS = {
	lamp = Color3.fromRGB(255, 224, 138), -- butter
}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Inlet
	p.Parent = parent
	return p
end

-- A sign with text on its front face. Returns the TextLabel so services can update it.
local function sign(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	text: string,
	color: Color3
): TextLabel
	local board = part(parent, name, size, cf, Color3.fromRGB(27, 20, 40))
	board.Material = Enum.Material.SmoothPlastic
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.PixelsPerStud = 40
	surface.LightInfluence = 0
	surface.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(42, 31, 61)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = surface
	return label
end
MapService.sign = sign

-- Alpha class pick: one pedestal per class with a figure in the class's shape and a prompt.
-- `at` is the middle pedestal; pedestals face `facing` (a unit vector into the room).
local CLASS_LOOK = {
	Runner = { scale = Vector3.new(0.8, 1.1, 0.8), color = Color3.fromRGB(255, 143, 184) },
	Tank = { scale = Vector3.new(1.5, 1.2, 1.4), color = Color3.fromRGB(200, 90, 120) },
	Screamer = { scale = Vector3.new(1, 1, 1), color = Color3.fromRGB(255, 120, 200) },
}
local function buildAlphaStation(parent: Instance, at: Vector3, facing: Vector3)
	local station = Instance.new("Model")
	station.Name = "AlphaStation"
	station.Parent = parent
	local right = Vector3.new(0, 1, 0):Cross(facing).Unit
	local look = CFrame.lookAt(Vector3.zero, facing)
	for i, className in AlphaClasses.order do
		local class = (AlphaClasses :: any)[className]
		local shape = CLASS_LOOK[className]
		local pos = at + right * ((i - 2) * 9)
		local base = part(
			station,
			"Pedestal",
			Vector3.new(5, 2, 5),
			CFrame.new(pos + Vector3.new(0, 1, 0)),
			Color3.fromRGB(58, 40, 86)
		)
		base.Material = Enum.Material.SmoothPlastic
		-- a blocky zombie figure: legs, torso, arms, head, glowing eyes
		local s = shape.scale
		local function limb(size: Vector3, offset: Vector3)
			local p = part(
				station,
				"Figure",
				Vector3.new(size.X * s.X, size.Y * s.Y, size.Z * s.Z),
				CFrame.new(pos) * look * CFrame.new(offset.X * s.X, 2 + offset.Y * s.Y, offset.Z * s.Z),
				shape.color
			)
			p.CanCollide = false
			return p
		end
		limb(Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0))
		limb(Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0))
		limb(Vector3.new(2, 2, 1), Vector3.new(0, 3, 0))
		limb(Vector3.new(1, 1, 2.2), Vector3.new(-1.5, 3.5, -1)) -- arms reaching out
		limb(Vector3.new(1, 1, 2.2), Vector3.new(1.5, 3.5, -1))
		local head = limb(Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.6, 0))
		for _, x in { -0.25, 0.25 } do
			local eye = part(
				station,
				"Eye",
				Vector3.new(0.25, 0.25, 0.1),
				head.CFrame * CFrame.new(x * s.X, 0.15, -0.62 * s.Z),
				Color3.fromRGB(255, 40, 60)
			)
			eye.Material = Enum.Material.Neon
			eye.CanCollide = false
		end
		sign(
			station,
			"ClassSign",
			Vector3.new(7, 2.4, 0.3),
			CFrame.new(pos) * look * CFrame.new(0, 9 * s.Y, 0),
			class.name,
			shape.color
		)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = `Play as {class.name}`
		prompt.ObjectText = "Alpha class"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("Class", className)
		CollectionService:AddTag(prompt, "AlphaPickPrompt")
		prompt.Parent = base
	end
	sign(
		station,
		"StationSign",
		Vector3.new(24, 3, 0.3),
		CFrame.new(at) * look * CFrame.new(0, 13.5, 2),
		"IF YOU ARE THE ALPHA...",
		Color3.fromRGB(255, 246, 238)
	)
end

-- Things on the lobby walls that LobbyService updates (nil if the lobby was hand-built).
export type LobbyRefs = {
	mapSlots: { { label: TextLabel, prompt: ProximityPrompt } },
	modeLabel: TextLabel,
}
MapService.lobby = nil :: LobbyRefs?

-- The safehouse: the one cozy place. Warm string lights, a couch and an old TV, the map vote
-- board, the Alpha pedestals, a shop counter for later... and a zombie peeking in the window.
local SAFEHOUSE = {
	wall = Color3.fromRGB(58, 40, 86), -- dusk
	ceiling = Color3.fromRGB(42, 31, 61),
	floor = Color3.fromRGB(70, 55, 45),
	rug = Color3.fromRGB(120, 96, 160),
	couch = Color3.fromRGB(150, 90, 110),
	wood = Color3.fromRGB(96, 70, 58),
	zombie = Color3.fromRGB(118, 156, 96),
	bulbs = {
		Color3.fromRGB(255, 143, 184),
		Color3.fromRGB(163, 234, 200),
		Color3.fromRGB(255, 224, 138),
		Color3.fromRGB(191, 169, 242),
		Color3.fromRGB(156, 200, 255),
	},
}

local function buildLobby()
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	lobby.Parent = workspace
	local base = Vector3.new(0, 300, 0) -- floor top is base.Y + 1
	local W, D, H = 84, 64, 18
	local function at(x: number, y: number, z: number): Vector3
		return base + Vector3.new(x, y, z)
	end
	-- a CFrame at `pos` whose front face (where signs draw) points along `dir`
	local function facing(pos: Vector3, dir: Vector3): CFrame
		return CFrame.lookAt(pos, pos + dir)
	end
	local function piece(name: string, size: Vector3, pos: Vector3, color: Color3): Part
		return part(lobby, name, size, CFrame.new(pos), color)
	end

	-- room
	local floor = piece("Floor", Vector3.new(W, 2, D), base, SAFEHOUSE.floor)
	floor.Material = Enum.Material.WoodPlanks
	piece("Ceiling", Vector3.new(W, 1, D), at(0, H + 1.5, 0), SAFEHOUSE.ceiling)
	piece("Wall", Vector3.new(W, H, 2), at(0, 1 + H / 2, -D / 2), SAFEHOUSE.wall) -- north
	piece("Wall", Vector3.new(2, H, D), at(W / 2, 1 + H / 2, 0), SAFEHOUSE.wall) -- east
	piece("Wall", Vector3.new(2, H, D), at(-W / 2, 1 + H / 2, 0), SAFEHOUSE.wall) -- west
	-- south wall with two windows (x = -20 and +20, from 5 to 12 above the floor)
	local z = D / 2
	piece("Wall", Vector3.new(W, 5, 2), at(0, 3.5, z), SAFEHOUSE.wall)
	piece("Wall", Vector3.new(W, H - 12, 2), at(0, 13 + (H - 12) / 2, z), SAFEHOUSE.wall)
	for _, seg in { { -33.5, 17 }, { 0, 30 }, { 33.5, 17 } } do
		piece("Wall", Vector3.new(seg[2], 7, 2), at(seg[1], 9.5, z), SAFEHOUSE.wall)
	end
	for _, x in { -20, 20 } do
		local glass = piece("Window", Vector3.new(10, 7, 0.3), at(x, 9.5, z), Color3.fromRGB(150, 160, 200))
		glass.Material = Enum.Material.Glass
		glass.Transparency = 0.75
	end
	-- outside: the night, and someone who wants in
	local night = piece("Night", Vector3.new(W + 20, 40, 1), at(0, 10, z + 10), Color3.fromRGB(10, 8, 18))
	night.Material = Enum.Material.SmoothPlastic
	local head = piece("Peeker", Vector3.new(2, 2, 2), at(21, 10.5, z + 3), SAFEHOUSE.zombie)
	head.CanCollide = false
	for _, x in { 20.5, 21.5 } do
		local eye = piece("PeekerEye", Vector3.new(0.4, 0.4, 0.1), at(x, 10.8, z + 1.95), SAFEHOUSE.bulbs[2])
		eye.Material = Enum.Material.Neon
		eye.CanCollide = false
	end
	for _, x in { 18, 24 } do
		piece("PeekerHand", Vector3.new(1, 0.6, 1.6), at(x, 6.3, z + 1.6), SAFEHOUSE.zombie).CanCollide =
			false
	end
	local moon = Instance.new("PointLight")
	moon.Color = Color3.fromRGB(150, 160, 230)
	moon.Range = 14
	moon.Brightness = 1
	moon.Parent = head

	-- warm light + string lights along the long walls
	local lamp = piece("Lamp", Vector3.new(2, 1, 2), at(0, H + 0.5, 0), COLORS.lamp)
	lamp.Material = Enum.Material.Neon
	local warm = Instance.new("PointLight")
	warm.Range = 50
	warm.Brightness = 1.4
	warm.Color = Color3.fromRGB(255, 200, 150)
	warm.Parent = lamp
	for _, wz in { -D / 2 + 1.5, D / 2 - 1.5 } do
		piece("Wire", Vector3.new(W - 4, 0.1, 0.1), at(0, H - 0.5, wz), Color3.fromRGB(30, 26, 36))
		local i = 0
		for x = -W / 2 + 4, W / 2 - 4, 5 do
			i += 1
			local color = SAFEHOUSE.bulbs[(i - 1) % #SAFEHOUSE.bulbs + 1]
			local bulb = piece("StringLight", Vector3.new(0.6, 0.6, 0.6), at(x, H - 1, wz), color)
			bulb.Shape = Enum.PartType.Ball
			bulb.Material = Enum.Material.Neon
			bulb.CanCollide = false
			if i % 4 == 0 then
				local glow = Instance.new("PointLight")
				glow.Color = color
				glow.Range = 12
				glow.Brightness = 1
				glow.Parent = bulb
			end
		end
	end

	-- cozy corner: rug, couch, an old TV with no signal
	piece("Rug", Vector3.new(26, 0.2, 18), at(0, 1.1, 4), SAFEHOUSE.rug).CanCollide = false
	piece("CouchSeat", Vector3.new(14, 2, 4), at(-26, 2, 25), SAFEHOUSE.couch)
	piece("CouchBack", Vector3.new(14, 4, 1.5), at(-26, 4, 27.5), SAFEHOUSE.couch)
	piece("CouchArm", Vector3.new(1.5, 3, 4), at(-33.5, 2.5, 25), SAFEHOUSE.couch)
	piece("CouchArm", Vector3.new(1.5, 3, 4), at(-18.5, 2.5, 25), SAFEHOUSE.couch)
	piece("TVStand", Vector3.new(6, 3, 3), at(-26, 2.5, 13), SAFEHOUSE.wood)
	piece("TV", Vector3.new(5, 4, 4), at(-26, 6, 13), Color3.fromRGB(40, 36, 44))
	local screen = piece("TVScreen", Vector3.new(4, 3, 0.2), at(-26, 6, 15.05), Color3.fromRGB(90, 90, 130))
	screen.Material = Enum.Material.Neon
	screen.Transparency = 0.35

	-- the map vote board (north wall): 3 posters + a pad in front of each
	local board = Instance.new("Model")
	board.Name = "VoteBoard"
	board.Parent = lobby
	local wallZ = -D / 2 + 1.2
	local south = Vector3.new(0, 0, 1)
	sign(
		board,
		"VoteHeader",
		Vector3.new(40, 3, 0.3),
		facing(at(0, 15.5, wallZ), south),
		"VOTE FOR THE NEXT MAP",
		COLORS.lamp
	)
	local slots = {}
	for i, x in { -16, 0, 16 } do
		local label = sign(
			board,
			`MapSlot{i}`,
			Vector3.new(12, 8, 0.3),
			facing(at(x, 9, wallZ), south),
			"",
			Color3.fromRGB(255, 246, 238)
		)
		local pad =
			piece("VotePad", Vector3.new(8, 0.4, 6), at(x, 1.2, wallZ + 7), Color3.fromRGB(191, 169, 242))
		pad.Material = Enum.Material.Neon
		pad.Transparency = 0.5
		pad.CanCollide = false
		pad.Parent = board
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Vote"
		prompt.ObjectText = "Map"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt:SetAttribute("Slot", i)
		CollectionService:AddTag(prompt, "MapVotePrompt")
		prompt.Parent = pad
		table.insert(slots, { label = label, prompt = prompt })
	end

	-- what's next (south wall, above the windows)
	local modeLabel = sign(
		lobby,
		"ModeSign",
		Vector3.new(30, 3, 0.3),
		facing(at(0, 15.5, D / 2 - 1.2), Vector3.new(0, 0, -1)),
		"WAITING FOR PLAYERS",
		COLORS.blood
	)

	-- shop counter (west wall) + dressing mirror (character catalog)
	local east = Vector3.new(1, 0, 0)
	local counter = piece("ShopCounter", Vector3.new(4, 4, 16), at(-37, 3, -10), SAFEHOUSE.wood)
	sign(
		lobby,
		"ShopSign",
		Vector3.new(14, 3, 0.3),
		facing(at(-W / 2 + 1.2, 12, -10), east),
		"Z-SHOP",
		COLORS.lamp
	)
	local shopPrompt = Instance.new("ProximityPrompt")
	shopPrompt.ActionText = "Open shop"
	shopPrompt.ObjectText = "Z-Shop"
	shopPrompt.KeyboardKeyCode = Enum.KeyCode.E
	shopPrompt.HoldDuration = 0
	shopPrompt.MaxActivationDistance = 10
	shopPrompt.RequiresLineOfSight = false
	CollectionService:AddTag(shopPrompt, "ShopPrompt")
	shopPrompt.Parent = counter
	local mirror =
		piece("Mirror", Vector3.new(0.3, 10, 6), at(-W / 2 + 1.2, 7, 2), Color3.fromRGB(200, 205, 220))
	mirror.Material = Enum.Material.Glass
	mirror.Reflectance = 0.4
	sign(
		lobby,
		"MirrorSign",
		Vector3.new(10, 2, 0.3),
		facing(at(-W / 2 + 1.2, 13.5, 2), east),
		"CATALOG",
		Color3.fromRGB(191, 169, 242)
	)
	-- the dressing mirror opens the character catalog
	local catalogPrompt = Instance.new("ProximityPrompt")
	catalogPrompt.ActionText = "Edit your character"
	catalogPrompt.ObjectText = "Catalog"
	catalogPrompt.KeyboardKeyCode = Enum.KeyCode.E
	catalogPrompt.HoldDuration = 0
	catalogPrompt.MaxActivationDistance = 10
	catalogPrompt.RequiresLineOfSight = false
	CollectionService:AddTag(catalogPrompt, "CatalogPrompt")
	catalogPrompt.Parent = mirror

	-- the Alpha pedestals (east wall)
	buildAlphaStation(lobby, at(W / 2 - 8, 1, 0), Vector3.new(-1, 0, 0))

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0 -- no forcefield
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(at(0, 1.5, 0))
	spawn.Color = Color3.fromRGB(255, 143, 184)
	spawn.Parent = lobby
	CollectionService:AddTag(spawn, "LobbySpawn")

	MapService.lobby = { mapSlots = slots, modeLabel = modeLabel }
end

-- Every map that can be played, by id (Config/Maps): each builds itself and owns its spots.
local MapsFolder = script.Parent.Parent:WaitForChild("Maps")
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
