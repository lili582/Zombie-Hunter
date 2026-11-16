--!strict
-- SHOPPING MALL: a dead two-storey mall. Hub: the food court under an open atrium with a dry
-- fountain and two stopped escalators up to a glass-railed gallery (vertical chases). Ground
-- floor: clothing / toy / shoe stores (west), a department store full of mannequins (north), an
-- arcade, a game store and the cinema lobby (east), the entrance hall (south). Upstairs: a big
-- clothing floor with changing booths, the cinema hall and an arcade. Outside: a covered parking
-- garage, the car park and the loading dock.
-- All spots are data at the top, so the round rules and the builder use the same numbers.
local CollectionService = game:GetService("CollectionService")

local Kit = require(script.Parent.Kit)
local BuildingKit = require(script.Parent.BuildingKit)
local Clutter = require(script.Parent.Clutter)

local Mall = {}

Mall.SIZE = 360

Mall.TOWERS = {
	Vector3.new(-150, 0.5, -130),
	Vector3.new(150, 0.5, -130),
	Vector3.new(-155, 0.5, 40),
	Vector3.new(155, 0.5, 0),
	Vector3.new(155, 0.5, 80),
	Vector3.new(-20, 0.5, -150),
	Vector3.new(100, 0.5, 165),
	Vector3.new(-163, 0.5, 163),
}
Mall.HELI = {
	Vector3.new(60, 0.5, 130), -- the car park
	Vector3.new(60, 0.5, -140), -- the loading dock
	Vector3.new(-155, 0.5, -40), -- the west lawn
}
local HUMAN_STARTS = {
	Vector3.new(0, 3, 48),
	Vector3.new(-80, 3, 0),
	Vector3.new(80, 3, 0),
	Vector3.new(4, 21, -71),
	Vector3.new(-82, 21, 8),
	Vector3.new(40, 3, 130),
	Vector3.new(60, 3, -125),
}
local ZOMBIE_SPAWNS = {
	Vector3.new(-165, 3, -165),
	Vector3.new(165, 3, -165),
	Vector3.new(-165, 3, 120),
	Vector3.new(165, 3, 165),
}
local AMMO = {
	Vector3.new(-110, 3, -50),
	Vector3.new(-110, 3, 40),
	Vector3.new(59, 3, -45),
	Vector3.new(100, 3, 40),
	Vector3.new(-3, 3, -74),
	Vector3.new(-4, 21, -71),
	Vector3.new(-100, 21, -60),
	Vector3.new(90, 21, -15),
}
-- changing booths and staff closets you can hide in (y = their floor)
local BOOTHS = {
	Vector3.new(-126, 0.3, -60),
	Vector3.new(-126, 0.3, 30),
	Vector3.new(-30, 0.3, -86),
	Vector3.new(30, 0.3, -86),
	Vector3.new(126, 0.3, -60),
	Vector3.new(126, 0.3, 30),
	Vector3.new(-60, 0.3, 56),
	Vector3.new(-126, 18, -80),
	Vector3.new(-126, 18, -40),
	Vector3.new(-126, 18, 20),
	Vector3.new(-126, 18, 50),
	Vector3.new(-45, 18, -86),
	Vector3.new(45, 18, -86),
	Vector3.new(-45, 18, 45),
}

-- the building: x -130..130, z -90..60; upper floor at y = 18; atrium opening x/z -36..36
local X0, X1, Z0, Z1 = -130, 130, -90, 60
local UP = 18
local TOP = 34
local A = 36 -- atrium half size
local OUTSIDE = Color3.fromRGB(150, 146, 138)
local INSIDE = Color3.fromRGB(196, 192, 184)
local TILE = Color3.fromRGB(176, 172, 164)

function Mall.meta(): any
	local spots = {}
	for _, p in Mall.TOWERS do
		table.insert(spots, { x = p.X, z = p.Z })
	end
	return { towerSpots = spots, heliZoneCount = #Mall.HELI }
end

local Terrain = workspace.Terrain

local function boxTruck(map: Model, cf: CFrame)
	Kit.part(
		map,
		"Cargo",
		Vector3.new(8, 9, 20),
		cf * CFrame.new(0, 5.5, 2),
		Color3.fromRGB(200, 200, 196),
		Enum.Material.Metal
	)
	Kit.part(
		map,
		"Cab",
		Vector3.new(8, 6, 6),
		cf * CFrame.new(0, 4, -11),
		Color3.fromRGB(120, 30, 30),
		Enum.Material.SmoothPlastic
	)
	for _, x in { -4, 4 } do
		for _, z in { -10, 7 } do
			Kit.cylinder(
				map,
				"Wheel",
				1.2,
				3,
				cf * CFrame.new(x, 1.5, z),
				Color3.fromRGB(20, 20, 22),
				Enum.Material.SmoothPlastic
			)
		end
	end
end

local function outside(map: Model, rng: Random)
	Terrain:FillBlock(CFrame.new(0, -8, 0), Vector3.new(420, 16, 420), Enum.Material.Grass)
	Terrain:FillBlock(CFrame.new(0, -2, 120), Vector3.new(320, 4, 110), Enum.Material.Asphalt) -- car park
	Terrain:FillBlock(CFrame.new(40, -2, -132), Vector3.new(200, 4, 76), Enum.Material.Asphalt) -- loading dock
	Terrain:FillBlock(CFrame.new(0, -2, 63), Vector3.new(280, 4, 8), Enum.Material.Pavement)
	-- the covered parking garage (west half of the car park): pillars and a low concrete roof
	for x = -146, -44, 17 do
		for z = 102, 168, 22 do
			BuildingKit.pillar(map, Vector3.new(x, 0, z), 14, 2.4)
		end
	end
	BuildingKit.slab(map, -152, 96, -40, 172, 15, Color3.fromRGB(100, 98, 96), Enum.Material.Concrete)
	for x = -140, -60, 30 do
		BuildingKit.ceilingLight(map, Vector3.new(x, 14, 135), rng:NextNumber() < 0.5, rng:NextNumber() > 0.7)
	end
	-- cars, some with their lights still on
	local colors = {
		Color3.fromRGB(90, 30, 30),
		Color3.fromRGB(40, 50, 70),
		Color3.fromRGB(60, 60, 62),
		Color3.fromRGB(150, 150, 146),
		Color3.fromRGB(30, 60, 50),
	}
	for _, z in { 90, 118, 146 } do
		for x = -140, 140, 15 do
			if rng:NextNumber() < 0.45 and not (x > 40 and x < 80 and z > 110) then
				local yaw = (if z == 118 then math.pi else 0) + rng:NextNumber(-0.1, 0.1)
				local cx = if x < -40 and z > 96 then x + 8 else x -- in the garage: between the pillars
				BuildingKit.car(
					map,
					CFrame.new(cx, 0, z) * CFrame.Angles(0, yaw, 0),
					colors[rng:NextInteger(1, #colors)],
					rng
				)
			end
		end
	end
	-- loading dock: two box trucks, dumpsters, a fence
	boxTruck(map, CFrame.new(100, 0, -110) * CFrame.Angles(0, math.pi, 0))
	boxTruck(map, CFrame.new(124, 0, -116) * CFrame.Angles(0, math.pi + 0.15, 0))
	for _, x in { 10, 22 } do
		Kit.onGround(
			map,
			"Dumpster",
			Vector3.new(10, 5, 5),
			CFrame.new(x, 0, -98),
			Color3.fromRGB(40, 70, 50),
			Enum.Material.CorrodedMetal
		)
	end
	BuildingKit.chainFence(map, Vector3.new(-60, 0, -170), Vector3.new(140, 0, -170))
	-- light poles
	for _, p in
		{
			Vector3.new(-20, 0, 104),
			Vector3.new(40, 0, 104),
			Vector3.new(100, 0, 104),
			Vector3.new(-20, 0, 160),
			Vector3.new(100, 0, 160),
			Vector3.new(40, 0, -150),
			Vector3.new(120, 0, -150),
		}
	do
		Kit.onGround(
			map,
			"LightPole",
			Vector3.new(0.6, 20, 0.6),
			CFrame.new(p),
			BuildingKit.METAL,
			Enum.Material.Metal
		)
		local head = Kit.part(
			map,
			"LightHead",
			Vector3.new(2.4, 0.6, 1.2),
			CFrame.new(p + Vector3.new(0, 20, 0)),
			Color3.fromRGB(255, 170, 90),
			Enum.Material.Neon
		)
		Kit.light(head, 36, 1.3, Color3.fromRGB(255, 160, 80), rng:NextNumber() < 0.4)
	end
	-- the mall's name over the entrance
	local signBoard = Kit.part(
		map,
		"MallSign",
		Vector3.new(40, 6, 1),
		CFrame.new(0, 28, Z1 + 1),
		Color3.fromRGB(30, 26, 34),
		Enum.Material.SmoothPlastic
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Parent = signBoard
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 120, 160)
	label.Text = "GLOOMDALE MALL"
	label.Parent = gui
	local glow = Kit.part(
		map,
		"SignGlow",
		Vector3.new(1, 1, 1),
		CFrame.new(0, 28, Z1 + 3),
		Color3.fromRGB(255, 120, 160),
		Enum.Material.Neon
	)
	glow.Transparency = 1
	Kit.light(glow, 30, 1, Color3.fromRGB(255, 120, 160), true)
	-- a few dead trees on the lawns
	for _, p in
		{
			Vector3.new(-160, 0, -110),
			Vector3.new(-140, 0, -20),
			Vector3.new(160, 0, -50),
			Vector3.new(150, 0, 30),
			Vector3.new(-165, 0, 75),
			Vector3.new(165, 0, 120),
		}
	do
		Kit.deadTree(map, p, rng:NextNumber(18, 26), rng)
	end
end

local function shell(map: Model)
	local door = function(at: number, width: number, height: number): BuildingKit.Gap
		return { at = at, width = width, height = height }
	end
	local function outer(a: Vector3, b: Vector3, gaps: { BuildingKit.Gap }?)
		BuildingKit.wall(map, a, b, TOP, OUTSIDE, Enum.Material.Concrete, gaps)
	end
	outer(Vector3.new(X0, 0, Z1), Vector3.new(X1, 0, Z1), { door(130, 16, 12) }) -- main entrance (south)
	outer(Vector3.new(X0, 0, Z0), Vector3.new(X1, 0, Z0), { door(230, 14, 14) }) -- loading dock (north)
	outer(Vector3.new(X0, 0, Z1), Vector3.new(X0, 0, Z0), { door(60, 12, 12) }) -- west exit
	outer(Vector3.new(X1, 0, Z1), Vector3.new(X1, 0, Z0), { door(60, 12, 12) }) -- east exit
	-- floors: the ground, the upper floor around the atrium opening, the roof
	BuildingKit.slab(map, X0, Z0, X1, Z1, 0.3, TILE, Enum.Material.Marble)
	local up = Color3.fromRGB(160, 156, 150)
	BuildingKit.slab(map, X0, Z0, X1, -A, UP, up, Enum.Material.Marble)
	BuildingKit.slab(map, X0, A, X1, Z1, UP, up, Enum.Material.Marble)
	BuildingKit.slab(map, X0, -A, -A, A, UP, up, Enum.Material.Marble)
	BuildingKit.slab(map, A, -A, X1, A, UP, up, Enum.Material.Marble)
	BuildingKit.slab(map, X0, Z0, X1, Z1, TOP + 1, Color3.fromRGB(70, 68, 70), Enum.Material.Concrete)
end

local function groundFloor(map: Model, rng: Random)
	local h = UP - 1
	local function inner(a: Vector3, b: Vector3)
		BuildingKit.wall(map, a, b, h, INSIDE, Enum.Material.SmoothPlastic)
	end
	-- store partitions (west and east blocks), and the walls between the blocks and the atrium
	for _, x in { -98.7, -67.3 } do
		inner(Vector3.new(x, 0, -15), Vector3.new(x, 0, Z0))
		inner(Vector3.new(x, 0, 15), Vector3.new(x, 0, Z1))
	end
	inner(Vector3.new(83, 0, -15), Vector3.new(83, 0, Z0))
	for _, x in { -A, A } do
		inner(Vector3.new(x, 0, -15), Vector3.new(x, 0, Z0))
		inner(Vector3.new(x, 0, 15), Vector3.new(x, 0, Z1))
	end
	-- store fronts on the concourse (z -15 / 15) and the department store front on the atrium
	local north = math.pi
	local fronts = {
		{ -114.3, -15, north, 30, "THREADS", Color3.fromRGB(255, 143, 184) },
		{ -83, -15, north, 30, "TOY PLANET", Color3.fromRGB(255, 224, 138) },
		{ -51.7, -15, north, 30, "SOLE MATES", Color3.fromRGB(156, 200, 255) },
		{ 59.5, -15, north, 46, "PIXEL PALACE", Color3.fromRGB(163, 234, 200) },
		{ 106.5, -15, north, 46, "GAME VAULT", Color3.fromRGB(191, 169, 242) },
		{ -114.3, 15, 0, 30, "BLOOM & CO", Color3.fromRGB(255, 199, 154) },
		{ -83, 15, 0, 30, "SNACK SHACK", Color3.fromRGB(255, 224, 138) },
		{ -51.7, 15, 0, 30, "PHONE ZONE", Color3.fromRGB(156, 200, 255) },
		{ 83, 15, 0, 94, "CINEMA 6", Color3.fromRGB(255, 80, 100) },
		{ 0, -A, north, 72, "HALLORAN'S", Color3.fromRGB(255, 246, 238) },
	}
	for _, f in fronts do
		BuildingKit.storeFront(
			map,
			CFrame.new(f[1], 0.3, f[2]) * CFrame.Angles(0, f[3], 0),
			f[4],
			h,
			f[5],
			f[6]
		)
	end
	-- the food court: the dry fountain, tables around it
	BuildingKit.fountain(map, Vector3.new(0, 0.3, 0))
	for _, p in
		{
			Vector3.new(-16, 0.3, -22),
			Vector3.new(16, 0.3, -22),
			Vector3.new(-16, 0.3, 22),
			Vector3.new(16, 0.3, 22),
			Vector3.new(-18, 0.3, 0),
			Vector3.new(18, 0.3, 0),
		}
	do
		BuildingKit.table(
			map,
			CFrame.new(p) * CFrame.Angles(0, if math.abs(p.Z) < 1 then math.pi / 2 else 0, 0),
			8,
			Color3.fromRGB(150, 60, 60)
		)
	end
	-- the department store: mannequins in rows, some turned the wrong way
	for x = -28, 28, 10 do
		for z = -80, -46, 11 do
			local yaw = if rng:NextNumber() < 0.2 then math.pi else 0
			BuildingKit.mannequin(
				map,
				CFrame.new(x + rng:NextNumber(-1, 1), 0.3, z)
					* CFrame.Angles(0, yaw + rng:NextNumber(-0.3, 0.3), 0)
			)
		end
	end
	-- west stores: clothes racks, toy shelves, shoe shelves
	for z = -80, -30, 12 do
		Kit.onGround(
			map,
			"Rack",
			Vector3.new(10, 5, 0.4),
			CFrame.new(-114, 0.3, z),
			BuildingKit.METAL,
			Enum.Material.Metal
		)
		BuildingKit.shelf(map, CFrame.new(-83, 0.3, z), 12, rng)
		BuildingKit.shelf(map, CFrame.new(-52, 0.3, z) * CFrame.Angles(0, math.pi, 0), 12, rng)
	end
	-- arcade (east): rows of cabinets; game store: shelves
	for x = 44, 76, 6 do
		for z = -80, -30, 14 do
			BuildingKit.arcade(map, CFrame.new(x, 0.3, z) * CFrame.Angles(0, math.pi, 0), rng)
		end
	end
	for z = -80, -30, 12 do
		BuildingKit.shelf(map, CFrame.new(106, 0.3, z), 18, rng)
	end
	-- cinema lobby: ticket counter
	Kit.onGround(
		map,
		"TicketCounter",
		Vector3.new(30, 4, 4),
		CFrame.new(83, 0.3, 45),
		Color3.fromRGB(120, 30, 40),
		Enum.Material.SmoothPlastic
	)
	-- the south shops get counters and benches
	for _, x in { -114.3, -83, -51.7 } do
		Kit.onGround(
			map,
			"Counter",
			Vector3.new(14, 4, 3),
			CFrame.new(x, 0.3, 50),
			Color3.fromRGB(90, 70, 60),
			Enum.Material.Wood
		)
	end
	-- the stopped escalators up to the gallery
	BuildingKit.escalator(map, Vector3.new(-30, 0.3, 26), Vector3.new(-30, UP, -(A + 1)), 6) -- ends on the gallery edge
	BuildingKit.escalator(map, Vector3.new(30, 0.3, -26), Vector3.new(30, UP, A + 1), 6)
end

local function upperFloor(map: Model, rng: Random)
	local h = TOP - UP
	local function inner(a: Vector3, b: Vector3, gaps: { BuildingKit.Gap }?)
		BuildingKit.wall(map, a, b, h, INSIDE, Enum.Material.SmoothPlastic, gaps)
	end
	-- the gallery ring (x/z -50..50) and the rooms around it
	inner(Vector3.new(-50, UP, Z0), Vector3.new(-50, UP, Z1), { { at = 90, width = 20, height = 10 } }) -- clothing floor
	inner(Vector3.new(50, UP, Z0), Vector3.new(50, UP, Z1), { { at = 90, width = 12, height = 10 } }) -- cinema
	inner(Vector3.new(-50, UP, -50), Vector3.new(50, UP, -50), { { at = 50, width = 16, height = 10 } }) -- arcade
	inner(Vector3.new(-50, UP, 50), Vector3.new(50, UP, 50))
	-- glass railings around the atrium, open where the escalators arrive
	BuildingKit.railing(map, Vector3.new(-A, UP, -A), Vector3.new(-34, UP, -A))
	BuildingKit.railing(map, Vector3.new(-26, UP, -A), Vector3.new(A, UP, -A))
	BuildingKit.railing(map, Vector3.new(-A, UP, A), Vector3.new(26, UP, A))
	BuildingKit.railing(map, Vector3.new(34, UP, A), Vector3.new(A, UP, A))
	BuildingKit.railing(map, Vector3.new(-A, UP, -A), Vector3.new(-A, UP, A))
	BuildingKit.railing(map, Vector3.new(A, UP, -A), Vector3.new(A, UP, A))
	-- the clothing floor: racks and mannequins
	for x = -120, -60, 15 do
		for z = -80, 50, 16 do
			if rng:NextNumber() < 0.7 then
				Kit.onGround(
					map,
					"Rack",
					Vector3.new(8, 5, 0.4),
					CFrame.new(x, UP, z),
					BuildingKit.METAL,
					Enum.Material.Metal
				)
			else
				BuildingKit.mannequin(
					map,
					CFrame.new(x, UP, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
				)
			end
		end
	end
	-- the cinema: rows of red seats facing a flickering screen on the east wall
	for x = 60, 112, 6 do
		for z = -80, 50, 3 do
			if math.abs(z + 15) > 4 then -- an aisle down the middle
				Kit.onGround(
					map,
					"Seat",
					Vector3.new(2.4, 2.6, 2.4),
					CFrame.new(x, UP, z),
					Color3.fromRGB(110, 20, 30),
					Enum.Material.Fabric
				)
			end
		end
	end
	local screen = Kit.part(
		map,
		"Screen",
		Vector3.new(0.3, 12, 90),
		CFrame.new(129, UP + 8, -15),
		Color3.fromRGB(200, 205, 215),
		Enum.Material.Neon
	)
	screen.Transparency = 0.3
	Kit.light(screen, 50, 0.6, Color3.fromRGB(200, 210, 230), true)
	-- the upstairs arcade
	for x = -40, 40, 8 do
		BuildingKit.arcade(map, CFrame.new(x, UP, -80), rng)
		BuildingKit.arcade(map, CFrame.new(x, UP, -62) * CFrame.Angles(0, math.pi, 0), rng)
	end
end

local function booths(map: Model)
	for _, p in BOOTHS do
		local booth = Kit.onGround(
			map,
			"ChangingBooth",
			Vector3.new(4, 7.5, 4),
			CFrame.new(p),
			Color3.fromRGB(60, 40, 50),
			Enum.Material.Fabric
		)
		CollectionService:AddTag(booth, "Locker")
		local curtain = Kit.part(
			map,
			"Curtain",
			Vector3.new(3.4, 6.5, 0.15),
			CFrame.new(p + Vector3.new(0, 3.6, -2.05)),
			Color3.fromRGB(120, 30, 50),
			Enum.Material.Fabric
		)
		curtain.CanCollide = false
	end
end

local function lights(map: Model, rng: Random)
	local function ceiling(pos: Vector3)
		local roll = rng:NextNumber()
		BuildingKit.ceilingLight(map, pos, roll < 0.35, roll > 0.8)
	end
	for x = -120, 120, 16 do
		ceiling(Vector3.new(x, UP - 1, 0)) -- the concourse
		ceiling(Vector3.new(x, UP - 1, -55))
		ceiling(Vector3.new(x, UP - 1, 40))
		ceiling(Vector3.new(x, TOP, -70))
		ceiling(Vector3.new(x, TOP, 30))
	end
	for _, p in
		{
			Vector3.new(0, 12, Z1 - 1),
			Vector3.new(X0 + 1, 12, 0),
			Vector3.new(X1 - 1, 12, 0),
			Vector3.new(100, 14, Z0 + 1),
			Vector3.new(-30, UP + 10, -49),
			Vector3.new(30, UP + 10, 49),
		}
	do
		BuildingKit.emergencyLight(map, p)
	end
end

local function details(map: Model, rng: Random)
	for _ = 1, 10 do
		Kit.stain(
			map,
			Vector3.new(rng:NextNumber(-120, 120), 0.35, rng:NextNumber(-12, 12)),
			rng:NextNumber(1.5, 3),
			rng
		)
	end
	for _ = 1, 4 do
		Kit.stain(
			map,
			Vector3.new(rng:NextNumber(-48, 48), UP + 0.05, rng:NextNumber(-48, -38)),
			rng:NextNumber(1.5, 2.5),
			rng
		)
	end
	BuildingKit.mannequin(map, CFrame.new(-60, 0.3, 4) * CFrame.Angles(0, math.rad(200), 0)) -- out in the concourse...
	BuildingKit.mannequin(map, CFrame.new(-20, UP, 44) * CFrame.Angles(0, math.rad(90), 0)) -- ...and on the gallery
	for _, p in { Vector3.new(-60, 0.3, -8), Vector3.new(60, 0.3, 8), Vector3.new(10, 0.3, 40) } do
		Kit.crate(map, p, 2.5, rng:NextNumber(0, 1))
	end
end

-- where a shadow figure may stand for a moment (AtmosphereController): at the gallery railing
-- looking down into the atrium, in the garage, at the edge of the car park
local SCARES = {
	Vector3.new(-40, 18, -40), -- the gallery, upstairs
	Vector3.new(40, 18, 40),
	Vector3.new(-40, 18, 40),
	Vector3.new(40, 18, -40),
	Vector3.new(-140, 0.3, 160), -- deep in the parking garage
	Vector3.new(120, 0, 168), -- the far end of the car park
	Vector3.new(-40, 0, 170),
	Vector3.new(130, 0, -160), -- the loading dock
	Vector3.new(-55, 0, -160),
}

local function spots(map: Model)
	for _, p in SCARES do
		Kit.marker(map, "ScareSpot", p)
	end
	for _, p in HUMAN_STARTS do
		Kit.marker(map, "HumanStart", p)
	end
	for _, p in ZOMBIE_SPAWNS do
		Kit.marker(map, "ZombieSpawn", p)
	end
	for _, p in AMMO do
		Kit.marker(map, "AmmoSpawn", p)
	end
	for _, p in Mall.TOWERS do
		Kit.marker(map, "TowerSpot", p)
	end
	for _, p in Mall.HELI do
		Kit.marker(map, "HeliZone", p)
	end
end

-- Rain getting in: leaks dripping from the atrium roof into the food court, broken glass in front
-- of the shops, clothes dumped on the upstairs floor, receipts everywhere, puddles outside.
local function weathering(map: Model, rng: Random)
	Clutter.leak(map, Vector3.new(14, TOP - 0.2, 10), 0.3, rng)
	Clutter.leak(map, Vector3.new(-18, TOP - 0.2, -14), 0.3, rng)
	Clutter.puddles(map, rng, { -30, -30, 30, 30 }, 0.3, 5)
	for _, c in
		{
			Vector3.new(-50, 0.3, -40),
			Vector3.new(50, 0.3, -40),
			Vector3.new(-50, 0.3, 40),
			Vector3.new(50, 0.3, 40),
		}
	do
		Clutter.shards(map, c, 5, 14, rng)
	end
	Clutter.clothes(map, Vector3.new(-80, UP, -60), 10, 14, rng)
	Clutter.clothes(map, Vector3.new(-90, UP, 30), 10, 10, rng)
	Clutter.papers(map, Vector3.new(0, 0.3, -24), 14, 12, rng)
	Clutter.papers(map, Vector3.new(0, UP, 44), 10, 8, rng)
	Clutter.puddles(map, rng, { -30, 70, 155, 172 }, 0, 18) -- the car park
	Clutter.puddles(map, rng, { -55, -165, 135, -98 }, 0, 10) -- the loading dock
	Clutter.trashCan(map, Vector3.new(60, 0, 68), true, rng)
	Clutter.flashlight(map, Vector3.new(-100, 0.3, 140), math.rad(40))
end

-- Builds the map into `map` (an empty Model already in the workspace).
function Mall.build(map: Model)
	local rng = Random.new(2014)
	outside(map, rng)
	shell(map)
	groundFloor(map, rng)
	upperFloor(map, rng)
	booths(map)
	lights(map, rng)
	details(map, rng)
	weathering(map, rng)
	spots(map)
	Kit.boundary(map, Mall.SIZE)
end

return Mall
