--!strict
-- ABANDONED TOWN: the first greybox map (hospital hub, main street & gas station, houses &
-- backyards, parking lot & police station). Its spots are data so the round rules can use them.
local CollectionService = game:GetService("CollectionService")

local Town = {}

Town.SIZE = 360

-- radio tower spots (8: each round picks 5) and helicopter zones (3)
Town.TOWERS = {
	Vector3.new(-140, 0.5, -140), -- behind the gas station
	Vector3.new(-40, 0.5, -110),
	Vector3.new(100, 0.5, -110),
	Vector3.new(160, 0.5, 30),
	Vector3.new(100, 0.5, 160),
	Vector3.new(-30, 0.5, 170),
	Vector3.new(-150, 0.5, 60),
	Vector3.new(35, 0.5, 75),
}
Town.HELI = { Vector3.new(-160, 0.5, -15), Vector3.new(125, 0.5, -150), Vector3.new(70, 0.5, 160) }

-- what the round rules need: tower spots (x, z) and how many helicopter zones
function Town.meta(): any
	local spots = {}
	for _, p in Town.TOWERS do
		table.insert(spots, { x = p.X, z = p.Z })
	end
	return { towerSpots = spots, heliZoneCount = #Town.HELI }
end

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

-- Builds the map into `map` (an empty Model already in the workspace).
function Town.build(map: Model)
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
	-- start spots (groups of 2-3 players each start at a different one, spread out)
	for _, p in
		{
			Vector3.new(0, 3, 150), -- south road
			Vector3.new(150, 3, 0), -- east road
			Vector3.new(-150, 3, 0), -- west road
			Vector3.new(0, 3, -110), -- north road
			Vector3.new(-40, 3, 100), -- behind the police station
			Vector3.new(100, 3, -20), -- by the houses
			Vector3.new(40, 3, 128), -- south-east yards
		}
	do
		marker(map, "HumanStart", p)
	end
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
	-- radio tower spots (8, each round picks 5), helicopter zones (3)
	for _, p in Town.TOWERS do
		marker(map, "TowerSpot", p)
	end
	for _, p in Town.HELI do
		marker(map, "HeliZone", p)
	end
	-- lockers: tall metal boxes to hide in
	for _, p in
		{
			Vector3.new(-24, 0, -15),
			Vector3.new(24, 0, 15),
			Vector3.new(-60, 0, -45),
			Vector3.new(-110, 0, -45),
			Vector3.new(-95, 0, -95),
			Vector3.new(52, 0, 47),
			Vector3.new(88, 0, 107),
			Vector3.new(-90, 0, 92),
			Vector3.new(-130, 0, 100),
			Vector3.new(130, 0, -40),
			Vector3.new(150, 0, -90),
			Vector3.new(15, 0, -60),
			Vector3.new(-15, 0, 60),
			Vector3.new(160, 0, 100),
		}
	do
		local locker = block(map, "Locker", p, Vector3.new(4, 7, 3), Color3.fromRGB(70, 78, 84))
		locker.Material = Enum.Material.DiamondPlate
		CollectionService:AddTag(locker, "Locker")
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

return Town
