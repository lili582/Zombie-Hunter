--!strict
-- Finds the tagged spots of the map. If there is no map yet, builds a greybox Town + a lobby,
-- so the game is playable right away. Replace workspace.Map with a hand-built map later:
-- it only needs parts tagged HumanStart, AlphaStart, ZombieSpawn (3+), AmmoSpawn, and an
-- optional part named "AlphaDoor".
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local MapService = {}

export type MapInfo = {
	humanStart: CFrame,
	alphaStart: CFrame,
	zombieSpawns: { CFrame },
	ammoSpawns: { CFrame },
	lobbySpawn: CFrame,
	alphaDoor: BasePart?,
}

local COLORS = {
	ground = Color3.fromRGB(60, 58, 62),
	road = Color3.fromRGB(38, 36, 40),
	building = Color3.fromRGB(84, 78, 88),
	hospital = Color3.fromRGB(110, 104, 112),
	house = Color3.fromRGB(96, 70, 58),
	car = Color3.fromRGB(70, 40, 40),
	fence = Color3.fromRGB(90, 90, 80),
	lamp = Color3.fromRGB(255, 224, 138), -- butter
	blood = Color3.fromRGB(255, 143, 184), -- candy blood (no gore)
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

local function marker(parent: Instance, tag: string, pos: Vector3)
	local p = part(parent, tag, Vector3.new(4, 1, 4), CFrame.new(pos), Color3.new(1, 0, 0))
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	CollectionService:AddTag(p, tag)
end

local function block(parent: Instance, name: string, pos: Vector3, size: Vector3, color: Color3)
	-- pos is the center of the footprint on the ground
	return part(parent, name, size, CFrame.new(pos + Vector3.new(0, size.Y / 2, 0)), color)
end

-- Hollow building with door gaps on the north and south sides (a chase loop inside).
local function hollow(
	parent: Instance,
	name: string,
	pos: Vector3,
	w: number,
	d: number,
	h: number,
	color: Color3
)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	local t = 1.5
	local gap = 8
	local side = (w - gap) / 2
	for _, z in { -d / 2, d / 2 } do
		block(model, "Wall", pos + Vector3.new(-(gap / 2 + side / 2), 0, z), Vector3.new(side, h, t), color)
		block(model, "Wall", pos + Vector3.new(gap / 2 + side / 2, 0, z), Vector3.new(side, h, t), color)
	end
	for _, x in { -w / 2, w / 2 } do
		block(model, "Wall", pos + Vector3.new(x, 0, 0), Vector3.new(t, h, d), color)
	end
	part(model, "Roof", Vector3.new(w, 1, d), CFrame.new(pos + Vector3.new(0, h + 0.5, 0)), color)
	-- inner pillar to run around
	block(model, "Pillar", pos, Vector3.new(6, h, 6), color)
end

local function lamp(parent: Instance, pos: Vector3)
	block(parent, "LampPole", pos, Vector3.new(0.6, 14, 0.6), Color3.fromRGB(30, 30, 30))
	local head =
		part(parent, "LampHead", Vector3.new(2, 0.6, 2), CFrame.new(pos + Vector3.new(0, 14, 0)), COLORS.lamp)
	head.Material = Enum.Material.Neon
	local light = Instance.new("PointLight")
	light.Range = 22
	light.Brightness = 1.6
	light.Color = COLORS.lamp
	light.Shadows = false
	light.Parent = head
	CollectionService:AddTag(head, "FlickerLight")
end

local function car(parent: Instance, pos: Vector3, rot: number)
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(rot), 0)
	part(parent, "Car", Vector3.new(6, 3, 12), cf * CFrame.new(0, 1.5, 0), COLORS.car)
	part(parent, "CarTop", Vector3.new(5, 2, 6), cf * CFrame.new(0, 4, 0), COLORS.car)
end

local function buildLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 0.4
	Lighting.Ambient = Color3.fromRGB(22, 18, 32)
	Lighting.OutdoorAmbient = Color3.fromRGB(46, 40, 62)
	Lighting.FogColor = Color3.fromRGB(27, 20, 40) -- plum night
	Lighting.FogStart = 10
	Lighting.FogEnd = 70 -- spec: ~50 (tune)
	Lighting.GlobalShadows = false
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") then
			child:Destroy() -- an Atmosphere overrides the classic fog
		end
	end
end

local function buildLobby()
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	lobby.Parent = workspace
	local base = Vector3.new(0, 300, 0)
	local floor = part(lobby, "Floor", Vector3.new(60, 2, 60), CFrame.new(base), Color3.fromRGB(70, 55, 45))
	floor.Material = Enum.Material.WoodPlanks
	for _, w in
		{
			{ Vector3.new(0, 9, 30), Vector3.new(60, 16, 2) },
			{ Vector3.new(0, 9, -30), Vector3.new(60, 16, 2) },
			{ Vector3.new(30, 9, 0), Vector3.new(2, 16, 60) },
			{ Vector3.new(-30, 9, 0), Vector3.new(2, 16, 60) },
		}
	do
		part(lobby, "Wall", w[2], CFrame.new(base + w[1]), Color3.fromRGB(58, 40, 86)) -- dusk
	end
	part(
		lobby,
		"Ceiling",
		Vector3.new(60, 1, 60),
		CFrame.new(base + Vector3.new(0, 17, 0)),
		Color3.fromRGB(42, 31, 61)
	)
	local bulb =
		part(lobby, "Bulb", Vector3.new(1, 1, 1), CFrame.new(base + Vector3.new(0, 15, 0)), COLORS.lamp)
	bulb.Shape = Enum.PartType.Ball
	bulb.Material = Enum.Material.Neon
	local light = Instance.new("PointLight")
	light.Range = 45
	light.Brightness = 2
	light.Color = Color3.fromRGB(255, 200, 150)
	light.Parent = bulb
	CollectionService:AddTag(bulb, "FlickerLight")

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0 -- no forcefield
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(base + Vector3.new(0, 1.5, 0))
	spawn.Color = Color3.fromRGB(255, 143, 184)
	spawn.Parent = lobby
	CollectionService:AddTag(spawn, "LobbySpawn")
end

local function buildTown()
	local map = Instance.new("Model")
	map.Name = "Map"
	map.Parent = workspace
	local S = 360
	part(map, "Ground", Vector3.new(S, 2, S), CFrame.new(0, -1, 0), COLORS.ground)
	-- cross roads
	part(map, "Road", Vector3.new(24, 0.2, S), CFrame.new(0, 0.1, 0), COLORS.road)
	part(map, "Road", Vector3.new(S, 0.2, 24), CFrame.new(0, 0.1, 0), COLORS.road)
	-- boundary walls
	for _, w in
		{
			{ Vector3.new(0, 0, S / 2), Vector3.new(S, 24, 2) },
			{ Vector3.new(0, 0, -S / 2), Vector3.new(S, 24, 2) },
			{ Vector3.new(S / 2, 0, 0), Vector3.new(2, 24, S) },
			{ Vector3.new(-S / 2, 0, 0), Vector3.new(2, 24, S) },
		}
	do
		block(map, "Boundary", w[1], w[2], COLORS.fence)
	end

	-- HUB: hospital in the center (hollow, two doors, pillar loop)
	hollow(map, "Hospital", Vector3.new(0, 0, 0), 56, 40, 18, COLORS.hospital)
	-- (it sits on the crossing; the roads lead to its doors)

	-- ZONE 1 (north-west): main street & gas station
	for i = 0, 3 do
		block(map, "Shop", Vector3.new(-60 - i * 28, 0, -60), Vector3.new(20, 14, 18), COLORS.building)
	end
	block(map, "GasStationRoof", Vector3.new(-90, 10, -110), Vector3.new(30, 1, 18), COLORS.building)
	for _, x in { -100, -80 } do
		block(map, "Pump", Vector3.new(x, 0, -110), Vector3.new(2, 5, 2), COLORS.car)
		block(map, "RoofPost", Vector3.new(x, 0, -118), Vector3.new(1, 10, 1), COLORS.building)
	end

	-- ZONE 2 (east): houses & backyards
	for row = 0, 1 do
		for col = 0, 2 do
			local p = Vector3.new(60 + col * 36, 0, 50 + row * 60)
			hollow(map, "House", p, 22, 18, 12, COLORS.house)
			block(map, "Fence", p + Vector3.new(0, 0, 18), Vector3.new(24, 4, 1), COLORS.fence)
		end
	end
	for i = 0, 3 do
		block(map, "House", Vector3.new(60 + i * 30, 0, -60), Vector3.new(18, 12, 16), COLORS.house)
	end

	-- ZONE 3 (south-west): parking lot & police station
	block(map, "PoliceStation", Vector3.new(-90, 0, 70), Vector3.new(40, 16, 26), COLORS.building)
	for i = 0, 4 do
		for j = 0, 1 do
			car(map, Vector3.new(-120 + i * 16, 0, 120 + j * 22), if (i + j) % 2 == 0 then 0 else 8)
		end
	end

	-- Alpha room (north): locked during head start, door opens at release
	local roomPos = Vector3.new(0, 0, -150)
	block(map, "AlphaRoom", roomPos + Vector3.new(0, 0, -8), Vector3.new(20, 12, 1), COLORS.building)
	block(map, "AlphaRoom", roomPos + Vector3.new(-10, 0, 0), Vector3.new(1, 12, 16), COLORS.building)
	block(map, "AlphaRoom", roomPos + Vector3.new(10, 0, 0), Vector3.new(1, 12, 16), COLORS.building)
	part(
		map,
		"AlphaRoomRoof",
		Vector3.new(20, 1, 16),
		CFrame.new(roomPos + Vector3.new(0, 12.5, 0)),
		COLORS.building
	)
	local door = block(map, "AlphaDoor", roomPos + Vector3.new(0, 0, 8), Vector3.new(20, 12, 1), COLORS.car)
	door.Name = "AlphaDoor"
	local splat = part(
		map,
		"Splatter",
		Vector3.new(6, 0.2, 4),
		CFrame.new(roomPos + Vector3.new(0, 0.1, 14)),
		COLORS.blood
	)
	splat.CanCollide = false

	-- street lamps along the roads (the path is always lit by something)
	for d = -150, 150, 50 do
		if math.abs(d) > 30 then
			lamp(map, Vector3.new(14, 0, d))
			lamp(map, Vector3.new(d, 0, 14))
		end
	end

	-- tagged spots
	marker(map, "HumanStart", Vector3.new(0, 3, 150))
	marker(map, "AlphaStart", roomPos + Vector3.new(0, 3, 0))
	for _, p in
		{
			Vector3.new(-150, 3, -150),
			Vector3.new(150, 3, -150),
			Vector3.new(-150, 3, 150),
			Vector3.new(150, 3, 150),
		}
	do
		marker(map, "ZombieSpawn", p)
	end
	for _, p in
		{
			Vector3.new(-40, 3, -40),
			Vector3.new(40, 3, 40),
			Vector3.new(-140, 3, -20),
			Vector3.new(140, 3, 20),
			Vector3.new(-60, 3, 150),
			Vector3.new(60, 3, -150),
			Vector3.new(-150, 3, 90),
			Vector3.new(150, 3, -90),
		}
	do
		marker(map, "AmmoSpawn", p)
	end
end

local function cframesFor(tag: string, required: number): { CFrame }
	local list = {}
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsA("BasePart") then
			table.insert(list, inst.CFrame)
		end
	end
	if #list < required then
		error(`MapService: missing tag {tag} (need {required}, found {#list})`)
	end
	return list
end

function MapService.load(): MapInfo
	buildLighting()
	if not workspace:FindFirstChild("Lobby") then
		buildLobby()
	end
	if not workspace:FindFirstChild("Map") then
		buildTown()
	end
	local map = workspace:FindFirstChild("Map")
	local info: MapInfo = {
		humanStart = cframesFor("HumanStart", 1)[1],
		alphaStart = cframesFor("AlphaStart", 1)[1],
		zombieSpawns = cframesFor("ZombieSpawn", 3),
		ammoSpawns = cframesFor("AmmoSpawn", 0),
		lobbySpawn = cframesFor("LobbySpawn", 1)[1] + Vector3.new(0, 3, 0),
		alphaDoor = map and map:FindFirstChild("AlphaDoor", true) :: BasePart?,
	}
	print(
		`MapService: HumanStart 1, AlphaStart 1, ZombieSpawn {#info.zombieSpawns}, AmmoSpawn {#info.ammoSpawns}`
	)
	return info
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
