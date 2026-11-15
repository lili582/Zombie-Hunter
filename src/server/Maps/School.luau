--!strict
-- SCHOOL AT NIGHT: one big school building and its grounds. Hub: the gym with its bleachers.
-- Zones: the classroom hallway lined with lockers (lots of hiding), the cafeteria & kitchen, the
-- library & science labs. Outside: the sports field, the bus lot and the staff parking lot.
-- Flickering fluorescent lights, red emergency lights over the exits, a chalkboard message.
-- All spots are data at the top, so the round rules and the builder use the same numbers.
local Kit = require(script.Parent.Kit)
local BuildingKit = require(script.Parent.BuildingKit)

local School = {}

School.SIZE = 360

School.TOWERS = {
	Vector3.new(-150, 0.5, -60),
	Vector3.new(-150, 0.5, 60),
	Vector3.new(150, 0.5, -60),
	Vector3.new(150, 0.5, 0),
	Vector3.new(-100, 0.5, 150),
	Vector3.new(20, 0.5, 160),
	Vector3.new(100, 0.5, -150),
	Vector3.new(-100, 0.5, -150),
}
School.HELI = {
	Vector3.new(-55, 0.5, 100), -- the sports field
	Vector3.new(115, 0.5, 150), -- the bus lot
	Vector3.new(-150, 0.5, -150), -- the lawn behind the parking lot
}
local HUMAN_STARTS = {
	Vector3.new(-80, 3, -24),
	Vector3.new(80, 3, -24),
	Vector3.new(0, 3, -5),
	Vector3.new(-60, 3, 90),
	Vector3.new(100, 3, 60),
	Vector3.new(-60, 3, -138),
	Vector3.new(150, 3, 30),
}
local ZOMBIE_SPAWNS = {
	Vector3.new(-165, 3, -165),
	Vector3.new(165, 3, -165),
	Vector3.new(-165, 3, 165),
	Vector3.new(165, 3, 165),
}
local AMMO = {
	Vector3.new(-81, 3, -50),
	Vector3.new(-81, 3, -3),
	Vector3.new(81, 3, -50),
	Vector3.new(61, 3, -3),
	Vector3.new(0, 3, -80),
	Vector3.new(-80, 3, -85),
	Vector3.new(-20, 3, 120),
	Vector3.new(100, 3, -135),
}

-- the building: x -120..120, z -100..12. Corridor z -30..-18. Gym x -30..30, z -100..-30.
local H = 16 -- ceiling height
local GYM_H = 24
local BRICK = Color3.fromRGB(116, 56, 44)
local INSIDE = Color3.fromRGB(188, 184, 160)
local FLOOR = Color3.fromRGB(140, 136, 124)

function School.meta(): any
	local spots = {}
	for _, p in School.TOWERS do
		table.insert(spots, { x = p.X, z = p.Z })
	end
	return { towerSpots = spots, heliZoneCount = #School.HELI }
end

local Terrain = workspace.Terrain

local function grounds(map: Model, rng: Random)
	Terrain:FillBlock(CFrame.new(0, -8, 0), Vector3.new(420, 16, 420), Enum.Material.Grass)
	Terrain:FillBlock(CFrame.new(0, -2, -137), Vector3.new(250, 4, 70), Enum.Material.Asphalt) -- staff parking
	Terrain:FillBlock(CFrame.new(115, -2, 95), Vector3.new(110, 4, 150), Enum.Material.Asphalt) -- bus lot
	Terrain:FillBlock(CFrame.new(0, -2, 20), Vector3.new(270, 4, 20), Enum.Material.Pavement) -- front walk
	-- the sports field: lines and goals, a chain fence around it with gaps
	local white = Color3.fromRGB(220, 220, 214)
	local x0, x1, z0, z1 = -145, 35, 38, 168
	for _, seg in
		{
			{ Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z0) },
			{ Vector3.new(x0, 0, z1), Vector3.new(x1, 0, z1) },
			{ Vector3.new(x0, 0, z0), Vector3.new(x0, 0, z1) },
			{ Vector3.new(x1, 0, z0), Vector3.new(x1, 0, z1) },
			{ Vector3.new(x0, 0, (z0 + z1) / 2), Vector3.new(x1, 0, (z0 + z1) / 2) },
		}
	do
		BuildingKit.line(map, seg[1], seg[2], 0.6, white)
	end
	BuildingKit.goal(map, CFrame.new(-55, 0, z0 + 2))
	BuildingKit.goal(map, CFrame.new(-55, 0, z1 - 2) * CFrame.Angles(0, math.pi, 0))
	BuildingKit.chainFence(map, Vector3.new(-152, 0, 32), Vector3.new(-152, 0, 172))
	BuildingKit.chainFence(map, Vector3.new(-152, 0, 172), Vector3.new(-80, 0, 172))
	BuildingKit.chainFence(map, Vector3.new(-30, 0, 172), Vector3.new(42, 0, 172))
	BuildingKit.chainFence(map, Vector3.new(42, 0, 172), Vector3.new(42, 0, 110))
	-- parking lot: rows of abandoned cars
	local colors = {
		Color3.fromRGB(90, 30, 30),
		Color3.fromRGB(40, 50, 70),
		Color3.fromRGB(60, 60, 62),
		Color3.fromRGB(150, 150, 146),
		Color3.fromRGB(30, 60, 50),
	}
	for _, z in { -124, -152 } do
		for x = -104, 104, 16 do
			if rng:NextNumber() < 0.6 then
				local yaw = (if z < -140 then math.pi else 0) + rng:NextNumber(-0.08, 0.08)
				BuildingKit.car(
					map,
					CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0),
					colors[rng:NextInteger(1, #colors)],
					rng
				)
			end
			BuildingKit.line(map, Vector3.new(x + 8, 0, z - 7), Vector3.new(x + 8, 0, z + 7), 0.4, white)
		end
	end
	-- bus lot
	for i, x in { 88, 106, 124 } do
		BuildingKit.bus(
			map,
			CFrame.new(x, 0, 100 + i * 2) * CFrame.Angles(0, math.rad(rng:NextNumber(-4, 4)), 0)
		)
	end
	-- sodium street lights around the outside
	for _, p in
		{
			Vector3.new(-60, 0, -112),
			Vector3.new(60, 0, -112),
			Vector3.new(-60, 0, -165),
			Vector3.new(60, 0, -165),
			Vector3.new(70, 0, 40),
			Vector3.new(160, 0, 70),
			Vector3.new(70, 0, 160),
			Vector3.new(-150, 0, 28),
			Vector3.new(30, 0, 28),
		}
	do
		Kit.onGround(
			map,
			"LightPole",
			Vector3.new(0.6, 18, 0.6),
			CFrame.new(p),
			BuildingKit.METAL,
			Enum.Material.Metal
		)
		local head = Kit.part(
			map,
			"LightHead",
			Vector3.new(2.4, 0.6, 1.2),
			CFrame.new(p + Vector3.new(0, 18, 0)),
			Color3.fromRGB(255, 170, 90),
			Enum.Material.Neon
		)
		Kit.light(head, 34, 1.3, Color3.fromRGB(255, 160, 80), rng:NextNumber() < 0.4)
	end
	-- a flagpole by the entrance, and the school sign
	Kit.onGround(
		map,
		"Flagpole",
		Vector3.new(0.5, 30, 0.5),
		CFrame.new(22, 0, 26),
		BuildingKit.METAL,
		Enum.Material.Metal
	)
	Kit.part(
		map,
		"Flag",
		Vector3.new(0.1, 4, 6),
		CFrame.new(22, 26, 23),
		Color3.fromRGB(110, 30, 34),
		Enum.Material.Fabric
	)
	Kit.sign(map, CFrame.new(-22, 0, 28), "RAVEN HOLLOW HIGH")
	-- trees along the edges
	local zones = {}
	for _, list in { School.TOWERS, School.HELI, HUMAN_STARTS, ZOMBIE_SPAWNS } do
		for _, p in list do
			table.insert(zones, p)
		end
	end
	local placed = 0
	for _ = 1, 400 do
		if placed >= 40 then
			break
		end
		local p = Vector3.new(rng:NextNumber(-170, 170), 0, rng:NextNumber(-170, 170))
		local inBuilding = p.X > -132 and p.X < 132 and p.Z > -175 and p.Z < 30
		local inField = p.X > -156 and p.X < 46 and p.Z > 28 and p.Z < 176
		local inLot = p.X > 56 and p.Z > 16
		local clear = not inBuilding and not inField and not inLot
		for _, z in zones do
			if clear and (p - z).Magnitude < 22 then
				clear = false
			end
		end
		if clear then
			placed += 1
			if rng:NextNumber() < 0.5 then
				Kit.deadTree(map, p, rng:NextNumber(18, 28), rng)
			else
				Kit.pine(map, p, rng:NextNumber(24, 36), rng)
			end
		end
	end
end

-- Outer and inner walls (door gaps measured along each wall from its first point).
local function walls(map: Model)
	local function outer(a: Vector3, b: Vector3, gaps: { BuildingKit.Gap })
		BuildingKit.wall(map, a, b, H, BRICK, Enum.Material.Brick, gaps)
	end
	local function inner(a: Vector3, b: Vector3, gaps: { BuildingKit.Gap }?, h: number?)
		BuildingKit.wall(map, a, b, h or H, INSIDE, Enum.Material.SmoothPlastic, gaps)
	end
	local door = function(at: number, width: number?, height: number?): BuildingKit.Gap
		return { at = at, width = width or 4, height = height or 8 }
	end
	-- outside: main entrance (south), gym back door and two exits (north), side exits (east, west)
	outer(Vector3.new(-120, 0, 12), Vector3.new(120, 0, 12), { door(120, 12, 10) })
	outer(
		Vector3.new(-120, 0, -100),
		Vector3.new(120, 0, -100),
		{ door(84, 8, 9), door(120, 10, 10), door(156, 8, 9) }
	)
	outer(Vector3.new(-120, 0, 12), Vector3.new(-120, 0, -100), { door(36, 10, 9) })
	outer(Vector3.new(120, 0, 12), Vector3.new(120, 0, -100), { door(36, 10, 9) })
	-- the gym is taller than the rest: brick above the roof line on its north and south sides
	BuildingKit.wall(
		map,
		Vector3.new(-30, H, -100),
		Vector3.new(30, H, -100),
		GYM_H - H,
		BRICK,
		Enum.Material.Brick
	)
	BuildingKit.wall(
		map,
		Vector3.new(-30, H, -30),
		Vector3.new(30, H, -30),
		GYM_H - H,
		BRICK,
		Enum.Material.Brick
	)

	-- corridor north wall: classroom doors (2 per room), the side corridors, gym and cafeteria doors
	local classroomDoors = { door(6), door(20), door(32), door(46), door(58), door(72) }
	local north = table.clone(classroomDoors)
	for _, g in
		{
			door(84, 12, H),
			door(105, 8, 9),
			door(135, 8, 9),
			door(156, 12, H),
			door(175, 8, 9),
			door(225, 8, 9),
		}
	do
		table.insert(north, g)
	end
	inner(Vector3.new(-120, 0, -30), Vector3.new(120, 0, -30), north)
	-- corridor south wall: classrooms, the entrance hall (wide open), the labs
	local south = table.clone(classroomDoors)
	for _, g in { door(120, 30, H), door(172), door(192), door(210), door(230) } do
		table.insert(south, g)
	end
	inner(Vector3.new(-120, 0, -18), Vector3.new(120, 0, -18), south)

	-- west wing: three classrooms north of the corridor, the library behind them
	for _, x in { -94, -68 } do
		inner(Vector3.new(x, 0, -30), Vector3.new(x, 0, -70))
		inner(Vector3.new(x, 0, -18), Vector3.new(x, 0, 12))
	end
	inner(Vector3.new(-120, 0, -70), Vector3.new(-42, 0, -70))
	inner(Vector3.new(-42, 0, -30), Vector3.new(-42, 0, -100), { door(55, 6, 9) }) -- library door
	-- the gym (tall)
	inner(Vector3.new(-30, 0, -30), Vector3.new(-30, 0, -100), { door(35, 8, 10) }, GYM_H)
	inner(Vector3.new(30, 0, -30), Vector3.new(30, 0, -100), { door(35, 8, 10) }, GYM_H)
	-- east wing: cafeteria and kitchen
	inner(Vector3.new(42, 0, -30), Vector3.new(42, 0, -100), { door(20, 6, 9), door(55, 6, 9) })
	inner(Vector3.new(42, 0, -70), Vector3.new(120, 0, -70), { door(39, 8, 9) })
	-- south side: entrance hall walls and the lab divider
	inner(Vector3.new(-42, 0, -18), Vector3.new(-42, 0, 12))
	inner(Vector3.new(42, 0, -18), Vector3.new(42, 0, 12))
	inner(Vector3.new(81, 0, -18), Vector3.new(81, 0, 12))
end

local function floorsAndRoofs(map: Model)
	BuildingKit.slab(map, -121, -101, 121, 13, 0.3, FLOOR, Enum.Material.SmoothPlastic)
	BuildingKit.slab(map, -30, -100, 30, -30, 0.4, Color3.fromRGB(150, 108, 66), Enum.Material.WoodPlanks) -- gym floor
	local roof = Color3.fromRGB(70, 68, 70)
	BuildingKit.slab(map, -121, -101, -30, 13, H + 1, roof, Enum.Material.Concrete)
	BuildingKit.slab(map, 30, -101, 121, 13, H + 1, roof, Enum.Material.Concrete)
	BuildingKit.slab(map, -30, -30, 30, 13, H + 1, roof, Enum.Material.Concrete)
	BuildingKit.slab(map, -30, -101, 30, -30, GYM_H + 1, roof, Enum.Material.Concrete)
end

local function lights(map: Model, rng: Random)
	local function ceiling(pos: Vector3)
		local roll = rng:NextNumber()
		BuildingKit.ceilingLight(map, pos, roll < 0.35, roll > 0.82)
	end
	for x = -112, 112, 14 do
		ceiling(Vector3.new(x, H, -24))
	end
	for _, room in
		{
			{ -107, -50 },
			{ -81, -50 },
			{ -55, -50 },
			{ -107, -3 },
			{ -81, -3 },
			{ -55, -3 },
			{ -80, -85 },
			{ 61, -3 },
			{ 100, -3 },
			{ 0, -3 },
		}
	do
		ceiling(Vector3.new(room[1], H, room[2]))
	end
	for x = 55, 105, 25 do
		ceiling(Vector3.new(x, H, -50))
		ceiling(Vector3.new(x, H, -85))
	end
	for _, z in { -36, -84 } do
		ceiling(Vector3.new(-36, H, z))
		ceiling(Vector3.new(36, H, z))
	end
	for x = -20, 20, 20 do
		for z = -85, -45, 20 do
			ceiling(Vector3.new(x, GYM_H, z))
		end
	end
	for _, p in
		{
			Vector3.new(0, 11, 11),
			Vector3.new(-36, 10, -99),
			Vector3.new(0, 11, -99),
			Vector3.new(36, 10, -99),
			Vector3.new(-119, 10, -24),
			Vector3.new(119, 10, -24),
		}
	do
		BuildingKit.emergencyLight(map, p)
	end
end

local function chalkboard(map: Model, cf: CFrame, message: string)
	local board = Kit.part(
		map,
		"Chalkboard",
		Vector3.new(14, 5, 0.3),
		cf,
		Color3.fromRGB(30, 50, 40),
		Enum.Material.Slate
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 25
	gui.LightInfluence = 1
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.IndieFlower
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(225, 225, 215)
	label.Text = message
	label.Parent = gui
end

local function rooms(map: Model, rng: Random)
	local messages = { "", "HOMEWORK: p. 113", "THEY ARE INSIDE", "", "DON'T LET IT BITE YOU", "" }
	local i = 0
	-- classrooms: desks in rows (some knocked over), a chalkboard on the far wall
	for _, cx in { -107, -81, -55 } do
		-- (students face the board: north rooms face north, south rooms face south; the board faces them)
		for _, side in
			{
				{ z0 = -66, board = -69.3, facing = 0, boardFacing = math.pi },
				{ z0 = -14, board = 11.3, facing = math.pi, boardFacing = 0 },
			}
		do
			i += 1
			for row = 0, 2 do
				for col = -1, 1 do
					local z = if side.facing == 0 then side.z0 + 8 + row * 9 else side.z0 + 4 + row * 8
					local cf = CFrame.new(cx + col * 7, 0.3, z)
						* CFrame.Angles(0, side.facing + rng:NextNumber(-0.2, 0.2), 0)
					BuildingKit.desk(map, cf, rng:NextNumber() < 0.15)
				end
			end
			chalkboard(
				map,
				CFrame.new(cx, 8, side.board) * CFrame.Angles(0, side.boardFacing, 0),
				messages[i] or ""
			)
		end
	end
	-- library: rows of shelves
	for z = -96, -76, 7 do
		for _, x in { -110, -90, -70, -52 } do
			BuildingKit.shelf(map, CFrame.new(x, 0.3, z), 12, rng)
		end
	end
	-- cafeteria: long tables; kitchen: steel counters
	for x = 52, 110, 14 do
		for z = -62, -38, 10 do
			BuildingKit.table(map, CFrame.new(x, 0.3, z), 10, Color3.fromRGB(80, 104, 120))
		end
	end
	for _, z in { -78, -94 } do
		Kit.onGround(
			map,
			"Counter",
			Vector3.new(60, 3.4, 3),
			CFrame.new(81, 0.3, z),
			BuildingKit.METAL,
			Enum.Material.Metal
		)
	end
	-- science labs: black lab benches
	for _, cx in { 61, 100 } do
		for z = -12, 6, 9 do
			BuildingKit.table(map, CFrame.new(cx, 0.3, z), 14, Color3.fromRGB(28, 28, 30))
		end
	end
	-- gym: bleachers on both long walls and two hoops
	BuildingKit.bleachers(map, CFrame.new(-25, 0.4, -65) * CFrame.Angles(0, math.rad(-90), 0), 50, 6)
	BuildingKit.bleachers(map, CFrame.new(25, 0.4, -65) * CFrame.Angles(0, math.rad(90), 0), 50, 6)
	for _, z in { -96, -34 } do
		Kit.part(
			map,
			"Backboard",
			Vector3.new(7, 4.5, 0.3),
			CFrame.new(0, 13, z),
			Color3.fromRGB(230, 230, 228),
			Enum.Material.SmoothPlastic
		)
		local hoop = Kit.cylinder(
			map,
			"Hoop",
			0.2,
			2.6,
			CFrame.new(0, 11.2, z + math.sign(-60 - z) * 1.8) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(220, 90, 40),
			Enum.Material.Metal
		)
		hoop.CanCollide = false
	end
	BuildingKit.line(
		map,
		Vector3.new(-30, 0.4, -65),
		Vector3.new(30, 0.4, -65),
		0.5,
		Color3.fromRGB(230, 230, 228)
	)
	-- the hallway lockers (every 5th one hides you)
	local blue = Color3.fromRGB(56, 76, 104)
	local function lockers(fromX: number, count: number, z: number, facing: Vector3)
		BuildingKit.lockerRow(map, Vector3.new(fromX, 0.3, z), Vector3.new(1, 0, 0), count, facing, 5, blue)
	end
	for _, r in { { -111.5, 4 }, { -97.5, 3 }, { -85.5, 4 }, { -71.5, 3 }, { -59.5, 4 } } do
		lockers(r[1], r[2], -28.4, Vector3.new(0, 0, 1))
		lockers(r[1], r[2], -19.6, Vector3.new(0, 0, -1))
	end
	for _, r in { { -29.5, 4 }, { -10.5, 8 }, { 19.5, 4 }, { 42.5, 3 }, { 59.5, 16 }, { 109.5, 4 } } do
		lockers(r[1], r[2], -28.4, Vector3.new(0, 0, 1))
	end
	for _, r in
		{ { -41.5, 10 }, { 15.5, 10 }, { 42.5, 3 }, { 54.5, 6 }, { 74.5, 5 }, { 92.5, 6 }, { 112.5, 3 } }
	do
		lockers(r[1], r[2], -19.6, Vector3.new(0, 0, -1))
	end
	-- unsettling details
	for _ = 1, 8 do
		Kit.stain(
			map,
			Vector3.new(rng:NextNumber(-110, 110), 0.35, rng:NextNumber(-27, -21)),
			rng:NextNumber(1.5, 3),
			rng
		)
	end
	Kit.crate(map, Vector3.new(-25, 0.3, 5), 3, 0.4)
	Kit.barrel(map, Vector3.new(118, 0, -112))
end

local function spots(map: Model)
	for _, p in HUMAN_STARTS do
		Kit.marker(map, "HumanStart", p)
	end
	for _, p in ZOMBIE_SPAWNS do
		Kit.marker(map, "ZombieSpawn", p)
	end
	for _, p in AMMO do
		Kit.marker(map, "AmmoSpawn", p)
	end
	for _, p in School.TOWERS do
		Kit.marker(map, "TowerSpot", p)
	end
	for _, p in School.HELI do
		Kit.marker(map, "HeliZone", p)
	end
end

-- Builds the map into `map` (an empty Model already in the workspace).
function School.build(map: Model)
	local rng = Random.new(404)
	grounds(map, rng)
	floorsAndRoofs(map)
	walls(map)
	rooms(map, rng)
	lights(map, rng)
	spots(map)
	Kit.boundary(map, School.SIZE)
end

return School
