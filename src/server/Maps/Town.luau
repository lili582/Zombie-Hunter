--!strict
-- ABANDONED TOWN: a small American town the night it went quiet. Hub: St. Agatha Hospital, two
-- floors (lobby & reception, a patient room, the staff room, the morgue with its body drawers,
-- stairs up to the wards). Around it: Main Street (diner, pharmacy, laundromat, hardware store),
-- the gas station, a row of houses with backyards and garden sheds, the police station with its
-- cells, the parking lot, the football field and a fenced used-car lot.
-- Sodium streetlights (some flicker, some are dead), a traffic light blinking yellow over an empty
-- crossroads, a burnt-out car behind police tape.
-- All spots are data at the top, so the round rules and the builder use the same numbers.
local CollectionService = game:GetService("CollectionService")

local Kit = require(script.Parent.Kit)
local BuildingKit = require(script.Parent.BuildingKit)
local Clutter = require(script.Parent.Clutter)

local Town = {}

Town.SIZE = 360

-- radio tower spots (8: each round picks 5) and helicopter zones (3)
Town.TOWERS = {
	Vector3.new(-130, 0.5, -165), -- behind the gas station
	Vector3.new(-20, 0.5, -130), -- behind Main Street
	Vector3.new(100, 0.5, -120), -- the used-car lot
	Vector3.new(155, 0.5, 40), -- a backyard
	Vector3.new(110, 0.5, 160), -- the football field
	Vector3.new(-30, 0.5, 165), -- the parking lot
	Vector3.new(-160, 0.5, 50), -- the west lawns
	Vector3.new(40, 0.5, 55), -- behind the hospital
}
Town.HELI = {
	Vector3.new(-20, 0.5, 130), -- the parking lot
	Vector3.new(127, 0.5, 136), -- the football field
	Vector3.new(-140, 0.5, -10), -- the empty lot on the west side
}
local HUMAN_STARTS = {
	Vector3.new(0, 3, 40),
	Vector3.new(-80, 3, -60),
	Vector3.new(60, 3, -60),
	Vector3.new(120, 3, 0),
	Vector3.new(-110, 3, 62),
	Vector3.new(20, 3, 120),
	Vector3.new(95, 3, 115),
}
local ZOMBIE_SPAWNS = {
	Vector3.new(-168, 3, -168),
	Vector3.new(168, 3, -168),
	Vector3.new(-168, 3, 168),
	Vector3.new(168, 3, 172),
}
local AMMO = {
	Vector3.new(0, 3, -15), -- hospital lobby
	Vector3.new(0, 17, -8), -- hospital, upstairs
	Vector3.new(-71, 3, -89), -- the diner
	Vector3.new(-112.5, 3, -96), -- under the gas station canopy
	Vector3.new(110, 3, -60), -- Main Street, east end
	Vector3.new(-135, 3, 115), -- police station
	Vector3.new(20, 3, 150), -- parking lot
	Vector3.new(140, 3, 22), -- a backyard
}

-- what the round rules need: tower spots (x, z) and how many helicopter zones
function Town.meta(): any
	local spots = {}
	for _, p in Town.TOWERS do
		table.insert(spots, { x = p.X, z = p.Z })
	end
	return { towerSpots = spots, heliZoneCount = #Town.HELI }
end

local Terrain = workspace.Terrain

local SODIUM = Color3.fromRGB(255, 158, 72)
local DARK_METAL = Color3.fromRGB(44, 46, 50)
local CONCRETE = Color3.fromRGB(168, 166, 158)
local INSIDE = Color3.fromRGB(196, 198, 186)
local TILE = Color3.fromRGB(150, 156, 150)
local ROOF = Color3.fromRGB(58, 56, 58)
local NORTH = Vector3.new(0, 0, -1)
local SOUTH = Vector3.new(0, 0, 1)
local EAST = Vector3.new(1, 0, 0)
local WEST = Vector3.new(-1, 0, 0)

local function tag(p: Instance, name: string)
	CollectionService:AddTag(p, name)
end

-- Text on the front face of a board (the face looking along the board's CFrame).
local function label(board: BasePart, text: string, color: Color3, font: Enum.Font)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = font
	t.TextScaled = true
	t.TextColor3 = color
	t.Text = text
	t.Parent = gui
end

-- A glowing sign on a wall: `pos` is its centre, `facing` the way it reads.
local function wallSign(map: Model, pos: Vector3, facing: Vector3, size: Vector2, text: string, color: Color3)
	local board = Kit.part(
		map,
		"Sign",
		Vector3.new(size.X, size.Y, 0.3),
		CFrame.lookAt(pos, pos + facing),
		Color3.fromRGB(24, 22, 26),
		Enum.Material.SmoothPlastic
	)
	board.CanCollide = false
	label(board, text, color, Enum.Font.GothamBold)
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Front
	glow.Range = 10
	glow.Brightness = 0.6
	glow.Color = color
	glow.Parent = board
	return board
end

--------------------------------------------------------------------------- the ground

local function pave(cx: number, cz: number, sx: number, sz: number, material: Enum.Material)
	Terrain:FillBlock(CFrame.new(cx, -2, cz), Vector3.new(sx, 4, sz), material)
end

local function grounds(map: Model)
	Terrain:FillBlock(CFrame.new(0, -8, 0), Vector3.new(440, 16, 440), Enum.Material.Grass)
	-- sidewalks first, then the asphalt over them, so the crossings are road
	pave(0, -60, 360, 34, Enum.Material.Pavement) -- Main Street
	pave(60, 0, 34, 360, Enum.Material.Pavement) -- the avenue
	pave(-60, 65, 30, 230, Enum.Material.Pavement) -- West Street
	pave(0, 75, 360, 30, Enum.Material.Pavement) -- South Street
	pave(0, -37, 70, 24, Enum.Material.Pavement) -- the hospital forecourt
	pave(0, -60, 360, 22, Enum.Material.Asphalt)
	pave(60, 0, 22, 360, Enum.Material.Asphalt)
	pave(-60, 65, 18, 230, Enum.Material.Asphalt)
	pave(0, 75, 360, 18, Enum.Material.Asphalt)
	pave(-5, 130, 90, 80, Enum.Material.Asphalt) -- the parking lot
	pave(-135, 92, 70, 16, Enum.Material.Asphalt) -- the police lot
	pave(-130, -115, 80, 70, Enum.Material.Concrete) -- the gas station forecourt
	pave(127, -118, 86, 66, Enum.Material.Ground) -- the used-car lot
	pave(-140, -10, 44, 40, Enum.Material.Mud) -- the empty west lot
	-- dashed yellow centre lines
	local yellow = Color3.fromRGB(196, 160, 60)
	for x = -176, 170, 14 do
		if math.abs(x - 60) > 16 then
			BuildingKit.line(map, Vector3.new(x, 0, -60), Vector3.new(x + 7, 0, -60), 0.5, yellow)
		end
	end
	for z = -176, 170, 14 do
		if math.abs(z + 60) > 16 and math.abs(z - 75) > 14 then
			BuildingKit.line(map, Vector3.new(60, 0, z), Vector3.new(60, 0, z + 7), 0.5, yellow)
		end
	end
	-- parking stalls
	local white = Color3.fromRGB(200, 200, 196)
	for x = -48, 38, 10 do
		BuildingKit.line(map, Vector3.new(x, 0, 92), Vector3.new(x, 0, 106), 0.4, white)
		BuildingKit.line(map, Vector3.new(x, 0, 154), Vector3.new(x, 0, 168), 0.4, white)
	end
end

--------------------------------------------------------------------------- street furniture

-- A sodium streetlight on the sidewalk, its arm reaching over the road (`toRoad`).
local function streetLight(map: Model, pos: Vector3, toRoad: Vector3, state: "on" | "flicker" | "dead")
	Kit.onGround(map, "LampPost", Vector3.new(0.6, 20, 0.6), CFrame.new(pos), DARK_METAL, Enum.Material.Metal)
	local armCf = CFrame.lookAt(pos + Vector3.new(0, 19.6, 0), pos + Vector3.new(0, 19.6, 0) + toRoad)
	Kit.part(
		map,
		"LampArm",
		Vector3.new(0.4, 0.4, 5),
		armCf * CFrame.new(0, 0, -2.5),
		DARK_METAL,
		Enum.Material.Metal
	)
	local head = Kit.part(
		map,
		"LampHead",
		Vector3.new(1.6, 0.5, 2.6),
		armCf * CFrame.new(0, -0.3, -5.2),
		if state == "dead" then Color3.fromRGB(60, 56, 50) else SODIUM,
		if state == "dead" then Enum.Material.Glass else Enum.Material.Neon
	)
	head.CanCollide = false
	if state == "dead" then
		return
	end
	local beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Bottom
	beam.Angle = 110
	beam.Range = 42
	beam.Brightness = 2.2
	beam.Color = SODIUM
	beam.Shadows = true
	beam.Parent = head
	if state == "flicker" then
		tag(head, "FlickerLight")
	end
end

local function streetLights(map: Model)
	local states: { "on" | "flicker" | "dead" } = { "on", "on", "flicker", "on", "dead", "on", "flicker" }
	local n = 0
	local function nextState(): "on" | "flicker" | "dead"
		n += 1
		return states[(n - 1) % #states + 1]
	end
	-- each row: the fixed coordinate, the spots along it, which way the arm reaches
	local function row(spots: { number }, at: (number) -> Vector3, toRoad: Vector3)
		for _, v in spots do
			streetLight(map, at(v), toRoad, nextState())
		end
	end
	-- Main Street: the north side stands in the alleys between the shops
	row({ -160, -120, -55, -23, 9, 100, 140 }, function(x)
		return Vector3.new(x, 0, -74)
	end, SOUTH)
	row({ -150, -70, -30, 34, 90, 130, 170 }, function(x)
		return Vector3.new(x, 0, -46)
	end, NORTH)
	row({ -150, -110, -20, 20, 100, 140 }, function(x)
		return Vector3.new(x, 0, 63)
	end, SOUTH)
	row({ -150, -110, -30, 10, 40, 130, 165 }, function(z)
		return Vector3.new(46, 0, z)
	end, EAST)
	row({ -130, -95, -30, 20, 50, 110, 150 }, function(z)
		return Vector3.new(74, 0, z)
	end, WEST)
	row({ 0, 40, 110, 150 }, function(z)
		return Vector3.new(-72, 0, z)
	end, EAST)
	-- the parking lot
	streetLight(map, Vector3.new(-47, 0, 130), EAST, "on")
	streetLight(map, Vector3.new(37, 0, 112), WEST, "flicker")
end

-- The traffic light on the crossroads, stuck blinking yellow.
local function trafficLight(map: Model)
	local base = Vector3.new(74, 0, -74)
	Kit.onGround(
		map,
		"SignalPole",
		Vector3.new(0.7, 18, 0.7),
		CFrame.new(base),
		DARK_METAL,
		Enum.Material.Metal
	)
	local arm = CFrame.lookAt(base + Vector3.new(0, 17.5, 0), base + Vector3.new(-1, 17.5, 1))
	Kit.part(
		map,
		"SignalArm",
		Vector3.new(0.5, 0.5, 18),
		arm * CFrame.new(0, 0, -9),
		DARK_METAL,
		Enum.Material.Metal
	)
	local box = arm * CFrame.new(0, -2.4, -18)
	Kit.part(
		map,
		"SignalBox",
		Vector3.new(1.6, 4.6, 1.4),
		box,
		Color3.fromRGB(40, 38, 20),
		Enum.Material.Metal
	)
	for i, color in { Color3.fromRGB(60, 10, 10), Color3.fromRGB(255, 186, 40), Color3.fromRGB(10, 40, 20) } do
		local lamp = Kit.part(
			map,
			"Signal",
			Vector3.new(1, 1, 0.3),
			box * CFrame.new(0, 2.4 - i * 1.3 + 0.2, -0.7),
			color,
			if i == 2 then Enum.Material.Neon else Enum.Material.Glass
		)
		lamp.CanCollide = false
		if i == 2 then
			Kit.light(lamp, 24, 1.6, color, true)
		end
	end
end

-- A wreck in the middle of Main Street, still smoking, taped off by the police.
local function burntCar(map: Model, rng: Random)
	local cf = CFrame.new(18, 0, -56) * CFrame.Angles(0, 0.35, 0)
	local car = BuildingKit.car(map, cf, Color3.fromRGB(30, 26, 24), rng)
	for _, p in car:GetDescendants() do
		if p:IsA("BasePart") then
			p.Material = Enum.Material.CorrodedMetal
			p.Color = p.Color:Lerp(Color3.fromRGB(20, 18, 16), 0.6)
		end
	end
	local core = Kit.part(
		map,
		"Embers",
		Vector3.new(2, 1, 2),
		cf * CFrame.new(0, 3, -3),
		Color3.fromRGB(255, 90, 20),
		Enum.Material.Neon
	)
	core.CanCollide = false
	core.Transparency = 0.4
	Kit.light(core, 18, 1.4, Color3.fromRGB(255, 110, 40), true)
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(40, 38, 40)
	smoke.Opacity = 0.35
	smoke.RiseVelocity = 4
	smoke.Size = 6
	smoke.Parent = core
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 4
	fire.Parent = core
	-- the tape: cones at the corners, yellow strips between them
	local corners = {
		cf * Vector3.new(-7, 0, -11),
		cf * Vector3.new(7, 0, -11),
		cf * Vector3.new(7, 0, 11),
		cf * Vector3.new(-7, 0, 11),
	}
	for i, c in corners do
		Kit.onGround(
			map,
			"Cone",
			Vector3.new(1.2, 2.6, 1.2),
			CFrame.new(c),
			Color3.fromRGB(230, 96, 30),
			Enum.Material.SmoothPlastic
		)
		local d = corners[i % #corners + 1]
		local a, b = c + Vector3.new(0, 2.3, 0), d + Vector3.new(0, 2.3, 0)
		local tape = Kit.part(
			map,
			"PoliceTape",
			Vector3.new(0.05, 0.5, (b - a).Magnitude),
			CFrame.lookAt(a, b) * CFrame.new(0, 0, -(b - a).Magnitude / 2),
			Color3.fromRGB(230, 196, 40),
			Enum.Material.SmoothPlastic
		)
		tape.CanCollide = false
	end
end

--------------------------------------------------------------------------- the hospital

-- The hospital: x -35..35, z -25..30. Floor 2 at y 14, the roof at y 28.
local HX0, HX1, HZ0, HZ1 = -35, 35, -25, 30
local F2 = 14

-- An outside wall of the upper floor: a solid band, a band of windows, a solid band.
-- Some windows still glow a sick yellow-green from inside.
local function windowWall(map: Model, a: Vector3, b: Vector3, rng: Random)
	local up = Vector3.new(0, 1, 0)
	BuildingKit.wall(map, a, b, 4, CONCRETE, Enum.Material.Concrete)
	local length = (b - a).Magnitude
	local gaps = {}
	local at = 6
	while at < length - 4 do
		table.insert(gaps, { at = at, width = 5 })
		at += 9
	end
	BuildingKit.wall(map, a + up * 4, b + up * 4, 5, CONCRETE, Enum.Material.Concrete, gaps)
	BuildingKit.wall(map, a + up * 9, b + up * 9, 5, CONCRETE, Enum.Material.Concrete)
	local dir = (b - a).Unit
	for _, g in gaps do
		local pos = a + dir * g.at + up * 6.5
		local lit = rng:NextNumber() < 0.35
		local pane = Kit.part(
			map,
			"Window",
			Vector3.new(0.3, 5, g.width),
			CFrame.lookAt(pos, pos + dir),
			if lit then Color3.fromRGB(176, 196, 150) else Color3.fromRGB(46, 54, 58),
			if lit then Enum.Material.Neon else Enum.Material.Glass
		)
		pane.Transparency = if lit then 0.55 else 0.35
	end
end

local function hospitalShell(map: Model, rng: Random)
	-- floors: the ground floor, floor 2 with the stairwell cut out, the roof
	BuildingKit.slab(map, HX0, HZ0, HX1, HZ1, 0.4, TILE, Enum.Material.Marble)
	BuildingKit.slab(map, -29, HZ0, HX1, HZ1, F2, TILE, Enum.Material.Marble)
	BuildingKit.slab(map, HX0, HZ0, -29, -23, F2, TILE, Enum.Material.Marble)
	BuildingKit.slab(map, HX0, -2.5, -29, HZ1, F2, TILE, Enum.Material.Marble)
	BuildingKit.slab(map, HX0 - 1, HZ0 - 1, HX1 + 1, HZ1 + 1, 29, ROOF, Enum.Material.Concrete)
	for _, side in
		{
			{ Vector3.new(HX0 - 1, 29, HZ0 - 1), Vector3.new(HX1 + 1, 29, HZ0 - 1) },
			{ Vector3.new(HX0 - 1, 29, HZ1 + 1), Vector3.new(HX1 + 1, 29, HZ1 + 1) },
			{ Vector3.new(HX0 - 1, 29, HZ0 - 1), Vector3.new(HX0 - 1, 29, HZ1 + 1) },
			{ Vector3.new(HX1 + 1, 29, HZ0 - 1), Vector3.new(HX1 + 1, 29, HZ1 + 1) },
		}
	do
		BuildingKit.wall(map, side[1], side[2], 2, CONCRETE, Enum.Material.Concrete)
	end
	-- the ground floor: big lobby windows and doors on every side
	BuildingKit.wall(
		map,
		Vector3.new(HX0, 0, HZ0),
		Vector3.new(HX1, 0, HZ0),
		F2,
		CONCRETE,
		Enum.Material.Concrete,
		{
			{ at = 35, width = 10, height = 9 },
			{ at = 15, width = 12, height = 9 },
			{ at = 55, width = 12, height = 9 },
		}
	)
	for _, x in { -20, 20 } do
		local glass = Kit.part(
			map,
			"LobbyWindow",
			Vector3.new(12, 9, 0.3),
			CFrame.new(x, 4.5, HZ0),
			Color3.fromRGB(56, 66, 70),
			Enum.Material.Glass
		)
		glass.Transparency = 0.45
	end
	BuildingKit.wall(
		map,
		Vector3.new(HX0, 0, HZ1),
		Vector3.new(HX1, 0, HZ1),
		F2,
		CONCRETE,
		Enum.Material.Concrete,
		{
			{ at = 43, width = 4, height = 8 },
		}
	)
	BuildingKit.wall(
		map,
		Vector3.new(HX0, 0, HZ0),
		Vector3.new(HX0, 0, HZ1),
		F2,
		CONCRETE,
		Enum.Material.Concrete,
		{
			{ at = 45, width = 5, height = 8 },
		}
	)
	BuildingKit.wall(
		map,
		Vector3.new(HX1, 0, HZ0),
		Vector3.new(HX1, 0, HZ1),
		F2,
		CONCRETE,
		Enum.Material.Concrete,
		{
			{ at = 10, width = 5, height = 8 },
		}
	)
	-- floor 2: window bands all round
	windowWall(map, Vector3.new(HX0, F2, HZ0), Vector3.new(HX1, F2, HZ0), rng)
	windowWall(map, Vector3.new(HX0, F2, HZ1), Vector3.new(HX1, F2, HZ1), rng)
	windowWall(map, Vector3.new(HX0, F2, HZ0), Vector3.new(HX0, F2, HZ1), rng)
	windowWall(map, Vector3.new(HX1, F2, HZ0), Vector3.new(HX1, F2, HZ1), rng)
	-- inside, both floors: rooms along the back behind a wall at z 2 with three doors
	for _, y in { 0, F2 } do
		BuildingKit.wall(
			map,
			Vector3.new(HX0, y, 2),
			Vector3.new(HX1, y, 2),
			F2,
			INSIDE,
			Enum.Material.SmoothPlastic,
			{
				{ at = 11, width = 5, height = 8 },
				{ at = 35, width = 5, height = 8 },
				{ at = 59, width = 5, height = 8 },
			}
		)
		for _, x in { -12, 12 } do
			BuildingKit.wall(
				map,
				Vector3.new(x, y, 2),
				Vector3.new(x, y, HZ1),
				F2,
				INSIDE,
				Enum.Material.SmoothPlastic
			)
		end
	end
	-- the stairs in the west of the lobby, up to the stairwell on floor 2
	BuildingKit.stairs(map, Vector3.new(-31.75, 0.4, -22), SOUTH, F2 - 0.4, 5.5)
	BuildingKit.railing(map, Vector3.new(-29, F2, -23), Vector3.new(-29, F2, -2.5))
	BuildingKit.railing(map, Vector3.new(-34.5, F2, -23), Vector3.new(-29, F2, -23))
	-- the canopy over the entrance, the name, and the red cross on the roof
	Kit.part(
		map,
		"Canopy",
		Vector3.new(16, 0.8, 8),
		CFrame.new(0, 10, HZ0 - 4),
		CONCRETE,
		Enum.Material.Concrete
	)
	for _, x in { -7.5, 7.5 } do
		BuildingKit.pillar(map, Vector3.new(x, 0, HZ0 - 7.5), 10, 0.8)
	end
	wallSign(
		map,
		Vector3.new(0, 12, HZ0 - 0.7),
		NORTH,
		Vector2.new(30, 2.6),
		"ST. AGATHA HOSPITAL",
		Color3.fromRGB(230, 226, 214)
	)
	for _, size in { Vector3.new(2, 7, 0.6), Vector3.new(7, 2, 0.6) } do
		local bar = Kit.part(
			map,
			"RedCross",
			size,
			CFrame.new(0, 34.5, HZ0 - 1),
			Color3.fromRGB(200, 20, 24),
			Enum.Material.Neon
		)
		bar.CanCollide = false
	end
	local crossLight =
		Kit.part(map, "CrossLight", Vector3.new(1, 1, 1), CFrame.new(0, 34.5, HZ0 - 2.5), Color3.new(0, 0, 0))
	crossLight.Transparency = 1
	crossLight.CanCollide = false
	Kit.light(crossLight, 30, 1.2, Color3.fromRGB(220, 30, 30), true)
	BuildingKit.pillar(map, Vector3.new(0, 29, HZ0 - 1), 2.5, 1)
end

-- An ambulance left at the door, back doors open, a red light still turning.
local function ambulance(map: Model, cf: CFrame)
	local white = Color3.fromRGB(214, 214, 208)
	Kit.part(
		map,
		"AmbulanceBox",
		Vector3.new(7, 6, 10),
		cf * CFrame.new(0, 4.4, 2),
		white,
		Enum.Material.SmoothPlastic
	)
	Kit.part(
		map,
		"AmbulanceCab",
		Vector3.new(7, 4, 5),
		cf * CFrame.new(0, 3.4, -5.5),
		white,
		Enum.Material.SmoothPlastic
	)
	local windshield = Kit.part(
		map,
		"Windshield",
		Vector3.new(6.4, 1.8, 0.2),
		cf * CFrame.new(0, 4.6, -8.05),
		Color3.fromRGB(26, 30, 34),
		Enum.Material.Glass
	)
	windshield.CanCollide = false
	for _, x in { -3.55, 3.55 } do
		local stripe = Kit.part(
			map,
			"Stripe",
			Vector3.new(0.1, 0.8, 15),
			cf * CFrame.new(x, 3.6, -0.5),
			Color3.fromRGB(190, 24, 28),
			Enum.Material.SmoothPlastic
		)
		stripe.CanCollide = false
		for _, z in { -5.5, 4.5 } do
			Kit.cylinder(
				map,
				"Wheel",
				1,
				2.6,
				cf * CFrame.new(x * 0.85, 1.3, z),
				Color3.fromRGB(20, 20, 22),
				Enum.Material.SmoothPlastic
			)
		end
	end
	for _, x in { -2, 2 } do
		local beacon = Kit.part(
			map,
			"Beacon",
			Vector3.new(1.4, 0.6, 0.8),
			cf * CFrame.new(x, 7.7, -2.6),
			if x < 0 then Color3.fromRGB(220, 20, 20) else Color3.fromRGB(240, 240, 240),
			Enum.Material.Neon
		)
		beacon.CanCollide = false
		if x < 0 then
			Kit.light(beacon, 26, 1.5, Color3.fromRGB(230, 30, 30), true)
		end
	end
	-- the rear doors hanging open
	for _, sx in { -1, 1 } do
		local hinge = cf * CFrame.new(sx * 3.5, 4.4, 7)
		Kit.part(
			map,
			"RearDoor",
			Vector3.new(3.4, 5.6, 0.2),
			hinge * CFrame.Angles(0, sx * math.rad(-110), 0) * CFrame.new(-sx * 1.7, 0, 0),
			white,
			Enum.Material.SmoothPlastic
		)
	end
end

local function chair(map: Model, cf: CFrame, color: Color3)
	Kit.part(map, "Seat", Vector3.new(2, 0.3, 2), cf * CFrame.new(0, 1.8, 0), color, Enum.Material.Fabric)
	Kit.part(map, "Back", Vector3.new(2, 2, 0.3), cf * CFrame.new(0, 2.9, 0.9), color, Enum.Material.Fabric)
	Kit.onGround(map, "ChairLeg", Vector3.new(1.6, 1.7, 1.6), cf, BuildingKit.METAL, Enum.Material.Metal).Transparency =
		0.6
end

local function hospitalRooms(map: Model, rng: Random)
	local floor = 0.4
	-- lobby: the reception desk, rows of waiting chairs, a dead monitor
	Kit.onGround(
		map,
		"Reception",
		Vector3.new(14, 3.6, 2.5),
		CFrame.new(0, floor, -12),
		Color3.fromRGB(110, 84, 62),
		Enum.Material.Wood
	)
	Kit.part(
		map,
		"Monitor",
		Vector3.new(1.8, 1.3, 0.3),
		CFrame.new(-3, floor + 4.3, -12) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(20, 22, 24),
		Enum.Material.Glass
	)
	local seat = Color3.fromRGB(70, 92, 96)
	for row = 0, 1 do
		for i = 0, 4 do
			if not (row == 1 and i == 2) then
				chair(map, CFrame.new(14 + i * 3, floor, -20 + row * 6), seat)
			end
		end
	end
	chair(map, CFrame.new(-18, floor, -16) * CFrame.Angles(math.rad(90), 0.4, 0), seat) -- knocked over
	-- patient room (x -35..-12): two beds behind a torn curtain
	BuildingKit.hospitalBed(map, CFrame.new(-28, floor, 22), false)
	BuildingKit.hospitalBed(map, CFrame.new(-19, floor, 22), true)
	local curtain = Kit.part(
		map,
		"Curtain",
		Vector3.new(0.2, 8, 8),
		CFrame.new(-23.5, 4.8, 22),
		Color3.fromRGB(140, 170, 160),
		Enum.Material.Fabric
	)
	curtain.Transparency = 0.2
	curtain.CanCollide = false
	-- staff room (x -12..12): lockers along the back (every 3rd hides you), the coffee table
	BuildingKit.lockerRow(map, Vector3.new(-10, floor, 28.4), EAST, 6, NORTH, 3, Color3.fromRGB(96, 110, 120))
	BuildingKit.table(map, CFrame.new(0, floor, 14), 8, Color3.fromRGB(150, 140, 124))
	-- the morgue (x 12..35): body drawers along the east wall (every 2nd one opens), steel tables
	BuildingKit.lockerRow(map, Vector3.new(33.4, floor, 6), SOUTH, 9, WEST, 2, Color3.fromRGB(150, 154, 158))
	BuildingKit.hospitalBed(map, CFrame.new(19, floor, 14), true)
	BuildingKit.hospitalBed(map, CFrame.new(25, floor, 22), true)
	for _ = 1, 4 do
		Kit.stain(
			map,
			Vector3.new(rng:NextNumber(14, 30), floor, rng:NextNumber(6, 28)),
			rng:NextNumber(1.5, 3),
			rng
		)
	end
	-- floor 2: the open ward in front, smaller wards behind
	for x = -20, 28, 8 do
		BuildingKit.hospitalBed(map, CFrame.new(x, F2, -20), rng:NextNumber() < 0.3)
	end
	BuildingKit.hospitalBed(map, CFrame.new(-28, F2, 22), false)
	BuildingKit.hospitalBed(map, CFrame.new(-18, F2, 22), true)
	BuildingKit.hospitalBed(map, CFrame.new(-5, F2, 22), false)
	BuildingKit.hospitalBed(map, CFrame.new(5, F2, 22) * CFrame.Angles(0, 0.5, 0), false)
	BuildingKit.hospitalBed(map, CFrame.new(20, F2, 22), true)
	BuildingKit.hospitalBed(map, CFrame.new(28, F2, 22), false)
	for _ = 1, 5 do
		Kit.stain(
			map,
			Vector3.new(rng:NextNumber(-25, 30), F2, rng:NextNumber(-22, 0)),
			rng:NextNumber(1.5, 3),
			rng
		)
	end
	-- the lights: a few work, a few flicker, the morgue's barely holds on
	for _, l in
		{
			{ Vector3.new(-15, 13, -15), false },
			{ Vector3.new(15, 13, -15), true },
			{ Vector3.new(0, 13, -3), false },
			{ Vector3.new(-24, 13, 16), true },
			{ Vector3.new(0, 13, 16), false },
			{ Vector3.new(24, 13, 16), true },
			{ Vector3.new(-15, 28, -12), true },
			{ Vector3.new(15, 28, -12), false },
			{ Vector3.new(-24, 28, 16), false },
			{ Vector3.new(0, 28, 16), true },
			{ Vector3.new(24, 28, 16), false },
		}
	do
		BuildingKit.ceilingLight(map, l[1], l[2])
	end
	BuildingKit.ceilingLight(map, Vector3.new(-24, 28, -3), false, true)
	BuildingKit.emergencyLight(map, Vector3.new(0, 9.6, HZ1 - 0.8))
	BuildingKit.emergencyLight(map, Vector3.new(HX1 - 0.8, 9.6, -15))
	-- outside: the ambulance and an abandoned gurney
	ambulance(map, CFrame.new(-16, 0, -40) * CFrame.Angles(0, math.rad(80), 0))
	BuildingKit.hospitalBed(map, CFrame.new(10, 0, -36) * CFrame.Angles(0, 1.1, 0), true)
	Kit.stain(map, Vector3.new(6, 0, -33), 3, rng)
end

--------------------------------------------------------------------------- Main Street

local BRICKS = {
	Color3.fromRGB(112, 58, 46),
	Color3.fromRGB(96, 70, 60),
	Color3.fromRGB(124, 82, 60),
	Color3.fromRGB(88, 60, 54),
}

-- One shop on the north side of Main Street (x0..x1, back at z -105, front on the street at
-- z -75): brick walls, a glass shop front with its neon name, a back door to the alley.
local STORE_Z0, STORE_Z1, STORE_H = -105, -75, 14

local function shop(map: Model, x0: number, x1: number, name: string, neon: Color3, brick: Color3)
	BuildingKit.slab(map, x0, STORE_Z0, x1, STORE_Z1, 0.3, Color3.fromRGB(120, 110, 100), Enum.Material.Slate)
	BuildingKit.wall(
		map,
		Vector3.new(x0, 0, STORE_Z0),
		Vector3.new(x1, 0, STORE_Z0),
		STORE_H,
		brick,
		Enum.Material.Brick,
		{
			{ at = (x1 - x0) / 2, width = 4, height = 8 },
		}
	)
	BuildingKit.wall(
		map,
		Vector3.new(x0, 0, STORE_Z0),
		Vector3.new(x0, 0, STORE_Z1),
		STORE_H,
		brick,
		Enum.Material.Brick
	)
	BuildingKit.wall(
		map,
		Vector3.new(x1, 0, STORE_Z0),
		Vector3.new(x1, 0, STORE_Z1),
		STORE_H,
		brick,
		Enum.Material.Brick
	)
	BuildingKit.storeFront(
		map,
		CFrame.new((x0 + x1) / 2, 0, STORE_Z1) * CFrame.Angles(0, math.pi, 0),
		x1 - x0,
		STORE_H,
		name,
		neon
	)
	BuildingKit.slab(
		map,
		x0 - 0.5,
		STORE_Z0 - 0.5,
		x1 + 0.5,
		STORE_Z1 + 0.5,
		STORE_H + 1,
		ROOF,
		Enum.Material.Concrete
	)
	-- a brick parapet over the front, so the street sees a real facade
	BuildingKit.wall(
		map,
		Vector3.new(x0 - 0.5, STORE_H + 1, STORE_Z1 + 0.5),
		Vector3.new(x1 + 0.5, STORE_H + 1, STORE_Z1 + 0.5),
		3,
		brick,
		Enum.Material.Brick
	)
	-- a torn awning
	local awning = Kit.part(
		map,
		"Awning",
		Vector3.new(x1 - x0 - 2, 0.3, 4),
		CFrame.new((x0 + x1) / 2, STORE_H - 4, STORE_Z1 + 2) * CFrame.Angles(math.rad(-18), 0, 0),
		neon:Lerp(Color3.fromRGB(30, 26, 30), 0.65),
		Enum.Material.Fabric
	)
	awning.CanCollide = false
end

local function diner(map: Model, x0: number, x1: number)
	local cx = (x0 + x1) / 2
	Kit.onGround(
		map,
		"Counter",
		Vector3.new(x1 - x0 - 6, 3.6, 2.4),
		CFrame.new(cx, 0.3, -98),
		Color3.fromRGB(150, 40, 40),
		Enum.Material.SmoothPlastic
	)
	for x = x0 + 4, x1 - 4, 3 do
		Kit.cylinder(
			map,
			"Stool",
			2.6,
			1.6,
			CFrame.new(x, 1.6, -95.5) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(170, 30, 30),
			Enum.Material.Fabric
		)
	end
	BuildingKit.table(map, CFrame.new(cx - 6, 0.3, -84), 5, Color3.fromRGB(180, 60, 50))
	BuildingKit.table(
		map,
		CFrame.new(cx + 6, 0.3, -84) * CFrame.Angles(0, 0, math.rad(8)),
		5,
		Color3.fromRGB(180, 60, 50)
	)
	BuildingKit.ceilingLight(map, Vector3.new(cx, STORE_H, -88), true)
end

local function pharmacy(map: Model, x0: number, x1: number, rng: Random)
	local cx = (x0 + x1) / 2
	for _, z in { -96, -88 } do
		BuildingKit.shelf(map, CFrame.new(cx, 0.3, z), x1 - x0 - 8, rng)
	end
	Kit.onGround(
		map,
		"Counter",
		Vector3.new(8, 3.6, 2.4),
		CFrame.new(x1 - 6, 0.3, -81),
		Color3.fromRGB(200, 200, 196),
		Enum.Material.SmoothPlastic
	)
	BuildingKit.ceilingLight(map, Vector3.new(cx, STORE_H, -92), false)
	BuildingKit.ceilingLight(map, Vector3.new(cx, STORE_H, -82), true, true)
end

local function laundromat(map: Model, x0: number, x1: number)
	local cx = (x0 + x1) / 2
	for x = x0 + 3, x1 - 3, 3.5 do
		if math.abs(x - cx) < 3.5 then
			continue -- keep the back door clear
		end
		Kit.onGround(
			map,
			"Washer",
			Vector3.new(3, 4, 3),
			CFrame.new(x, 0.3, -102.5),
			Color3.fromRGB(214, 214, 208),
			Enum.Material.SmoothPlastic
		)
		local door = Kit.cylinder(
			map,
			"WasherDoor",
			0.3,
			2.2,
			CFrame.new(x, 2.5, -100.9) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(40, 50, 56),
			Enum.Material.Glass
		)
		door.CanCollide = false
	end
	BuildingKit.table(map, CFrame.new(cx, 0.3, -88), 10, Color3.fromRGB(150, 150, 146))
	BuildingKit.ceilingLight(map, Vector3.new(cx, STORE_H, -95), true)
end

local function hardware(map: Model, x0: number, x1: number, rng: Random)
	local cx = (x0 + x1) / 2
	BuildingKit.shelf(map, CFrame.new(cx - 3, 0.3, -94), x1 - x0 - 12, rng)
	BuildingKit.shelf(map, CFrame.new(cx - 3, 0.3, -86) * CFrame.Angles(0, math.pi, 0), x1 - x0 - 12, rng)
	Kit.crate(map, Vector3.new(x0 + 4, 0.3, -80), 3, 0.3)
	Kit.crate(map, Vector3.new(x0 + 4, 3.3, -80), 2.4, 0.9)
	-- the stock room locker in the back corner (a hiding place)
	BuildingKit.lockerRow(
		map,
		Vector3.new(x1 - 3.4, 0.3, -103.5),
		WEST,
		1,
		SOUTH,
		1,
		Color3.fromRGB(90, 96, 80)
	)
	BuildingKit.ceilingLight(map, Vector3.new(cx, STORE_H, -90), false)
end

local function mainStreet(map: Model, rng: Random)
	local shops = {
		{ -84, -58, "DINER", Color3.fromRGB(255, 70, 90) },
		{ -52, -26, "PHARMACY", Color3.fromRGB(60, 230, 140) },
		{ -20, 6, "LAUNDROMAT", Color3.fromRGB(80, 170, 255) },
		{ 12, 38, "HARDWARE", Color3.fromRGB(255, 176, 60) },
	}
	for i, s in shops do
		shop(map, s[1], s[2], s[3], s[4], BRICKS[i])
	end
	diner(map, -84, -58)
	pharmacy(map, -52, -26, rng)
	laundromat(map, -20, 6)
	hardware(map, 12, 38, rng)
	-- the alleys between the shops: bins and boxes
	for _, x in { -55, -23, 9 } do
		Kit.barrel(map, Vector3.new(x - 1, 0, -100))
		Kit.crate(map, Vector3.new(x + 1, 0, -92), 2.4, rng:NextNumber(0, 1))
	end
	-- a bus stop on the south side
	Kit.part(
		map,
		"BusStopRoof",
		Vector3.new(10, 0.4, 4),
		CFrame.new(-110, 8, -45),
		DARK_METAL,
		Enum.Material.Metal
	)
	for _, x in { -114.5, -105.5 } do
		Kit.onGround(
			map,
			"BusStopPost",
			Vector3.new(0.4, 8, 0.4),
			CFrame.new(x, 0, -43.5),
			DARK_METAL,
			Enum.Material.Metal
		)
	end
	local glass = Kit.part(
		map,
		"BusStopGlass",
		Vector3.new(9, 6, 0.2),
		CFrame.new(-110, 4, -43.2),
		BuildingKit.GLASS,
		Enum.Material.Glass
	)
	glass.Transparency = 0.6
	Kit.part(
		map,
		"Bench",
		Vector3.new(7, 0.4, 1.4),
		CFrame.new(-110, 1.8, -44.2),
		Kit.WOOD,
		Enum.Material.WoodPlanks
	)
end

--------------------------------------------------------------------------- the gas station

local function gasStation(map: Model, rng: Random)
	-- the shop: x -168..-140, z -150..-128, open to the forecourt
	local x0, x1, z0, z1, h = -168, -140, -150, -128, 12
	local wall = Color3.fromRGB(176, 170, 156)
	BuildingKit.slab(map, x0, z0, x1, z1, 0.3, TILE, Enum.Material.Slate)
	BuildingKit.wall(map, Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z0), h, wall, Enum.Material.Concrete)
	BuildingKit.wall(map, Vector3.new(x0, 0, z0), Vector3.new(x0, 0, z1), h, wall, Enum.Material.Concrete)
	BuildingKit.wall(map, Vector3.new(x1, 0, z0), Vector3.new(x1, 0, z1), h, wall, Enum.Material.Concrete, {
		{ at = 6, width = 4, height = 8 },
	})
	BuildingKit.storeFront(
		map,
		CFrame.new((x0 + x1) / 2, 0, z1) * CFrame.Angles(0, math.pi, 0),
		x1 - x0,
		h,
		"GAS & GO",
		Color3.fromRGB(255, 60, 50)
	)
	BuildingKit.slab(map, x0 - 0.5, z0 - 0.5, x1 + 0.5, z1 + 0.5, h + 1, ROOF, Enum.Material.Concrete)
	BuildingKit.shelf(map, CFrame.new(-154, 0.3, -140), 16, rng)
	Kit.onGround(
		map,
		"Counter",
		Vector3.new(2.4, 3.6, 8),
		CFrame.new(-145, 0.3, -137),
		Color3.fromRGB(150, 40, 36),
		Enum.Material.SmoothPlastic
	)
	BuildingKit.lockerRow(
		map,
		Vector3.new(x0 + 1, 0.3, z0 + 1.6),
		EAST,
		2,
		SOUTH,
		2,
		Color3.fromRGB(110, 60, 50)
	)
	BuildingKit.ceilingLight(map, Vector3.new(-154, h, -139), true)
	-- the canopy over the pumps, lit from below; one light is dead
	local cx, cz = -112.5, -105
	Kit.part(
		map,
		"Canopy",
		Vector3.new(36, 1.6, 26),
		CFrame.new(cx, 14.8, cz),
		Color3.fromRGB(220, 220, 214),
		Enum.Material.SmoothPlastic
	)
	local edge = Kit.part(
		map,
		"CanopyEdge",
		Vector3.new(36.4, 0.6, 26.4),
		CFrame.new(cx, 15.2, cz),
		Color3.fromRGB(200, 30, 30),
		Enum.Material.Neon
	)
	edge.CanCollide = false
	for _, x in { -128, -97 } do
		for _, z in { -115, -95 } do
			BuildingKit.pillar(map, Vector3.new(x, 0, z), 14, 1.4)
		end
	end
	for i, p in
		{ Vector3.new(-122, 13.9, -105), Vector3.new(-112.5, 13.9, -105), Vector3.new(-103, 13.9, -105) }
	do
		local panel = Kit.part(
			map,
			"CanopyLight",
			Vector3.new(4, 0.2, 4),
			CFrame.new(p),
			BuildingKit.FLUORESCENT,
			if i == 3 then Enum.Material.SmoothPlastic else Enum.Material.Neon
		)
		panel.CanCollide = false
		if i ~= 3 then
			local spot = Instance.new("SpotLight")
			spot.Face = Enum.NormalId.Bottom
			spot.Angle = 120
			spot.Range = 30
			spot.Brightness = 1.6
			spot.Color = BuildingKit.FLUORESCENT
			spot.Shadows = true
			spot.Parent = panel
			if i == 2 then
				tag(panel, "FlickerLight")
			end
		end
	end
	-- two pump islands
	for _, x in { -118, -107 } do
		Kit.onGround(
			map,
			"PumpIsland",
			Vector3.new(3, 0.6, 12),
			CFrame.new(x, 0, cz),
			CONCRETE,
			Enum.Material.Concrete
		)
		for _, z in { -108, -102 } do
			Kit.onGround(
				map,
				"Pump",
				Vector3.new(2, 5, 1.6),
				CFrame.new(x, 0.6, z),
				Color3.fromRGB(190, 40, 36),
				Enum.Material.SmoothPlastic
			)
			local screen = Kit.part(
				map,
				"PumpScreen",
				Vector3.new(2.1, 0.8, 1.2),
				CFrame.new(x, 4.6, z),
				Color3.fromRGB(120, 200, 150),
				Enum.Material.Neon
			)
			screen.CanCollide = false
		end
	end
	BuildingKit.car(map, CFrame.new(-112.5, 0, -110), Color3.fromRGB(80, 90, 96), rng)
	-- the tall price sign on the corner
	Kit.onGround(
		map,
		"SignPole",
		Vector3.new(1.2, 26, 1.2),
		CFrame.new(-96, 0, -82),
		DARK_METAL,
		Enum.Material.Metal
	)
	local board = Kit.part(
		map,
		"GasSign",
		Vector3.new(10, 8, 1),
		CFrame.new(-96, 28, -82) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(220, 40, 36),
		Enum.Material.SmoothPlastic
	)
	label(board, "GAS\n$3.99", Color3.fromRGB(255, 240, 220), Enum.Font.GothamBlack)
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Front
	glow.Range = 16
	glow.Brightness = 0.8
	glow.Color = Color3.fromRGB(255, 80, 60)
	glow.Parent = board
	Kit.barrel(map, Vector3.new(-136, 0, -146))
	Kit.barrel(map, Vector3.new(-134, 0, -143))
end

--------------------------------------------------------------------------- houses

local SIDING = {
	{
		wall = Color3.fromRGB(108, 122, 128),
		material = Enum.Material.WoodPlanks,
		roof = Color3.fromRGB(46, 44, 48),
	},
	{
		wall = Color3.fromRGB(168, 156, 130),
		material = Enum.Material.WoodPlanks,
		roof = Color3.fromRGB(70, 44, 40),
	},
	{
		wall = Color3.fromRGB(104, 116, 96),
		material = Enum.Material.WoodPlanks,
		roof = Color3.fromRGB(44, 46, 44),
	},
	{
		wall = Color3.fromRGB(138, 134, 126),
		material = Enum.Material.WoodPlanks,
		roof = Color3.fromRGB(56, 50, 48),
	},
	{
		wall = Color3.fromRGB(150, 112, 96),
		material = Enum.Material.Brick,
		roof = Color3.fromRGB(40, 38, 40),
	},
}

-- A white picket fence from `a` to `b`.
local function picketFence(map: Model, a: Vector3, b: Vector3)
	local fence = Kit.fence(map, a, b)
	for _, p in fence:GetDescendants() do
		if p:IsA("BasePart") then
			p.Color = Color3.fromRGB(196, 194, 184)
			p.Material = Enum.Material.Wood
		end
	end
end

-- A house facing the street (`yaw` turns its front door, which is on -Z, to face the road),
-- its front fence with a gate, and a garden shed out back that you can hide in.
local function house(map: Model, pos: Vector3, facing: Vector3, style: number, lit: boolean, rng: Random)
	local yaw = if facing.X < 0 then math.pi / 2 else -math.pi / 2
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	Kit.cabin(map, cf, 20, 16, 11, lit, rng, SIDING[style] :: any)
	local frontX = pos.X + facing.X * 18
	picketFence(map, Vector3.new(frontX, 0, pos.Z - 11), Vector3.new(frontX, 0, pos.Z - 3))
	picketFence(map, Vector3.new(frontX, 0, pos.Z + 3), Vector3.new(frontX, 0, pos.Z + 11))
	local shedPos = Vector3.new(pos.X - facing.X * 30, 0, pos.Z + 6)
	Kit.hidingShed(map, CFrame.new(shedPos) * CFrame.Angles(0, yaw, 0))
	-- a mailbox by the gate
	Kit.onGround(
		map,
		"MailPost",
		Vector3.new(0.4, 3.6, 0.4),
		CFrame.new(frontX + facing.X, 0, pos.Z + 4.5),
		Kit.WOOD_DARK,
		Enum.Material.Wood
	)
	Kit.part(
		map,
		"Mailbox",
		Vector3.new(1.2, 1.2, 2),
		CFrame.new(frontX + facing.X, 4.2, pos.Z + 4.5) * CFrame.Angles(0, yaw, 0),
		Color3.fromRGB(60, 62, 66),
		Enum.Material.Metal
	)
end

local function houses(map: Model, rng: Random)
	-- the east row along the avenue, backyards running to the edge of town
	for i, z in { -25, 10, 45 } do
		house(map, Vector3.new(100, 0, z), WEST, i, i ~= 2, rng)
	end
	for _, z in { -7.5, 27.5 } do
		picketFence(map, Vector3.new(110, 0, z), Vector3.new(138, 0, z))
		picketFence(map, Vector3.new(148, 0, z), Vector3.new(172, 0, z))
	end
	Kit.deadTree(map, Vector3.new(150, 0, -25), 22, rng)
	Kit.deadTree(map, Vector3.new(158, 0, 12), 18, rng)
	Kit.barrel(map, Vector3.new(124, 0, -36))
	-- a swing set in the middle yard, one swing still moving in the wind
	for _, z in { 4, 12 } do
		for _, x in { 142, 148 } do
			Kit.part(
				map,
				"SwingLeg",
				Vector3.new(0.3, 9, 0.3),
				CFrame.new(x + (if x < 145 then 1 else -1), 4.3, z),
				DARK_METAL,
				Enum.Material.Metal
			)
		end
	end
	Kit.part(
		map,
		"SwingBar",
		Vector3.new(0.3, 0.3, 9),
		CFrame.new(145, 8.8, 8),
		DARK_METAL,
		Enum.Material.Metal
	)
	Kit.part(map, "Swing", Vector3.new(1.6, 0.2, 0.8), CFrame.new(145, 2.4, 6), Kit.WOOD, Enum.Material.Wood).CanCollide =
		false
	-- two houses on the west side, facing West Street
	house(map, Vector3.new(-100, 0, 10), EAST, 4, true, rng)
	house(map, Vector3.new(-100, 0, 40), EAST, 5, false, rng)
end

--------------------------------------------------------------------------- police station

-- A police car with its light bar still flashing.
local function policeCar(map: Model, cf: CFrame, rng: Random)
	BuildingKit.car(map, cf, Color3.fromRGB(22, 26, 40), rng)
	local stripe = Kit.part(
		map,
		"Stripe",
		Vector3.new(6.1, 0.9, 6),
		cf * CFrame.new(0, 2, 0),
		Color3.fromRGB(220, 220, 216),
		Enum.Material.SmoothPlastic
	)
	stripe.CanCollide = false
	for _, x in { -1.2, 1.2 } do
		local color = if x < 0 then Color3.fromRGB(220, 20, 30) else Color3.fromRGB(30, 70, 255)
		local bar = Kit.part(
			map,
			"LightBar",
			Vector3.new(2.2, 0.5, 0.8),
			cf * CFrame.new(x, 5.15, 0.6),
			color,
			Enum.Material.Neon
		)
		bar.CanCollide = false
		Kit.light(bar, 22, 1.6, color, true)
	end
end

local function policeStation(map: Model, rng: Random)
	local x0, x1, z0, z1, h = -170, -100, 100, 160, 13
	local brick = Color3.fromRGB(128, 108, 88)
	BuildingKit.slab(map, x0, z0, x1, z1, 0.4, Color3.fromRGB(110, 112, 108), Enum.Material.Slate)
	BuildingKit.wall(map, Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z0), h, brick, Enum.Material.Brick, {
		{ at = 35, width = 6, height = 9 },
	})
	BuildingKit.wall(map, Vector3.new(x0, 0, z1), Vector3.new(x1, 0, z1), h, brick, Enum.Material.Brick, {
		{ at = 60, width = 4, height = 8 },
	})
	BuildingKit.wall(map, Vector3.new(x0, 0, z0), Vector3.new(x0, 0, z1), h, brick, Enum.Material.Brick)
	BuildingKit.wall(map, Vector3.new(x1, 0, z0), Vector3.new(x1, 0, z1), h, brick, Enum.Material.Brick)
	BuildingKit.slab(map, x0 - 0.5, z0 - 0.5, x1 + 0.5, z1 + 0.5, h + 1, ROOF, Enum.Material.Concrete)
	wallSign(
		map,
		Vector3.new(-135, 11, z0 - 0.7),
		NORTH,
		Vector2.new(14, 2.2),
		"POLICE",
		Color3.fromRGB(110, 160, 255)
	)
	-- the front office: desks (one tipped over), the front counter
	BuildingKit.desk(map, CFrame.new(-155, 0.4, 112), false)
	BuildingKit.desk(map, CFrame.new(-145, 0.4, 112), true)
	BuildingKit.desk(map, CFrame.new(-155, 0.4, 124), false)
	BuildingKit.desk(map, CFrame.new(-120, 0.4, 118), false)
	Kit.onGround(
		map,
		"FrontCounter",
		Vector3.new(14, 3.6, 2.4),
		CFrame.new(-135, 0.4, 108),
		Color3.fromRGB(90, 70, 52),
		Enum.Material.Wood
	)
	-- the cells along the back: bars, every cell door hanging open
	local cellZ = 142
	for _, x in { -156.3, -144.6, -133 } do
		BuildingKit.wall(
			map,
			Vector3.new(x, 0, cellZ),
			Vector3.new(x, 0, z1),
			h,
			CONCRETE,
			Enum.Material.Concrete
		)
	end
	local x = -169
	while x < -133.5 do
		local inDoor = math.abs(x + 162) < 1.6 or math.abs(x + 139) < 1.6 or math.abs(x + 150.5) < 1.6
		if not inDoor then
			Kit.onGround(
				map,
				"Bar",
				Vector3.new(0.25, h - 0.4, 0.25),
				CFrame.new(x, 0.4, cellZ),
				DARK_METAL,
				Enum.Material.Metal
			)
		end
		x += 1.2
	end
	Kit.part(
		map,
		"BarRail",
		Vector3.new(36, 0.4, 0.4),
		CFrame.new(-151, 8.5, cellZ),
		DARK_METAL,
		Enum.Material.Metal
	)
	for _, cx in { -162, -150.5, -139 } do
		Kit.onGround(
			map,
			"Cot",
			Vector3.new(3, 1.6, 7),
			CFrame.new(cx + 3, 0.4, 154),
			Color3.fromRGB(90, 96, 84),
			Enum.Material.Fabric
		)
	end
	Kit.stain(map, Vector3.new(-150, 0.4, 150), 3, rng)
	-- the evidence lockers along the east wall (every 2nd hides you)
	BuildingKit.lockerRow(map, Vector3.new(-101.6, 0.4, 138), SOUTH, 6, WEST, 2, Color3.fromRGB(70, 80, 70))
	for _, l in
		{
			{ Vector3.new(-150, h, 115), false },
			{ Vector3.new(-120, h, 115), true },
			{ Vector3.new(-151, h, 151), true },
			{ Vector3.new(-118, h, 148), false },
		}
	do
		BuildingKit.ceilingLight(map, l[1], l[2])
	end
	BuildingKit.emergencyLight(map, Vector3.new(-110, 9.6, z1 - 0.8))
	-- out front: two cruisers, lights still going
	policeCar(map, CFrame.new(-152, 0, 92) * CFrame.Angles(0, math.pi / 2, 0), rng)
	policeCar(map, CFrame.new(-118, 0, 91) * CFrame.Angles(0, math.rad(70), 0), rng)
end

--------------------------------------------------------------------------- parking & field

local function parkingLot(map: Model, rng: Random)
	local colors = {
		Color3.fromRGB(80, 30, 30),
		Color3.fromRGB(40, 50, 70),
		Color3.fromRGB(120, 120, 116),
		Color3.fromRGB(30, 30, 32),
		Color3.fromRGB(90, 80, 60),
	}
	for i, x in { -43, -13, -3, 17, 27 } do
		BuildingKit.car(map, CFrame.new(x, 0, 99), colors[i], rng)
	end
	for i, x in { -43, 7, 17, 33 } do
		BuildingKit.car(
			map,
			CFrame.new(x, 0, 161) * CFrame.Angles(0, math.pi, 0),
			colors[(i + 1) % #colors + 1],
			rng
		)
	end
	-- one car left in the lane, door open
	BuildingKit.car(map, CFrame.new(10, 0, 128) * CFrame.Angles(0, 1.3, 0), colors[2], rng)
	Kit.crate(map, Vector3.new(-48, 0, 112), 2.4, 0.4)
end

local function footballField(map: Model, rng: Random)
	local x0, x1, z0, z1 = 85, 170, 102, 170
	local white = Color3.fromRGB(214, 214, 208)
	for _, seg in
		{
			{ Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z0) },
			{ Vector3.new(x0, 0, z1), Vector3.new(x1, 0, z1) },
			{ Vector3.new(x0, 0, z0), Vector3.new(x0, 0, z1) },
			{ Vector3.new(x1, 0, z0), Vector3.new(x1, 0, z1) },
			{ Vector3.new((x0 + x1) / 2, 0, z0), Vector3.new((x0 + x1) / 2, 0, z1) },
		}
	do
		BuildingKit.line(map, seg[1], seg[2], 0.6, white)
	end
	local midZ = (z0 + z1) / 2
	BuildingKit.goal(map, CFrame.new(x0 + 2, 0, midZ) * CFrame.Angles(0, -math.pi / 2, 0))
	BuildingKit.goal(map, CFrame.new(x1 - 2, 0, midZ) * CFrame.Angles(0, math.pi / 2, 0))
	BuildingKit.bleachers(map, CFrame.new(127, 0, 99) * CFrame.Angles(0, math.pi, 0), 46, 4)
	-- four field lights: one dead, one flickering
	for i, p in
		{
			Vector3.new(x0 - 4, 0, z0 - 4),
			Vector3.new(x1 + 4, 0, z0 - 4),
			Vector3.new(x0 - 4, 0, z1 + 4),
			Vector3.new(x1 + 4, 0, z1 + 4),
		}
	do
		Kit.onGround(
			map,
			"FieldLightPole",
			Vector3.new(1, 32, 1),
			CFrame.new(p),
			DARK_METAL,
			Enum.Material.Metal
		)
		local centre = Vector3.new((x0 + x1) / 2, 0, midZ)
		local headCf = CFrame.lookAt(p + Vector3.new(0, 32, 0), centre)
		local head = Kit.part(
			map,
			"FieldLight",
			Vector3.new(5, 3, 0.6),
			headCf,
			if i == 4 then Color3.fromRGB(60, 60, 58) else Color3.fromRGB(235, 240, 230),
			if i == 4 then Enum.Material.Glass else Enum.Material.Neon
		)
		head.CanCollide = false
		if i ~= 4 then
			local beam = Instance.new("SpotLight")
			beam.Face = Enum.NormalId.Front
			beam.Angle = 50
			beam.Range = 60
			beam.Brightness = 1.4
			beam.Color = Color3.fromRGB(220, 230, 235)
			beam.Shadows = true
			beam.Parent = head
			if i == 2 then
				tag(head, "FlickerLight")
			end
		end
	end
	Kit.stain(map, Vector3.new(140, 0, 120), 3, rng)
end

-- The fenced used-car lot in the north-east: wrecks, some flipped, one still smoking.
local function carLot(map: Model, rng: Random)
	local x0, x1, z0, z1 = 85, 170, -152, -86
	BuildingKit.chainFence(map, Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z0))
	BuildingKit.chainFence(map, Vector3.new(x1, 0, z0), Vector3.new(x1, 0, z1))
	BuildingKit.chainFence(map, Vector3.new(x0, 0, z1), Vector3.new(110, 0, z1))
	BuildingKit.chainFence(map, Vector3.new(124, 0, z1), Vector3.new(x1, 0, z1))
	BuildingKit.chainFence(map, Vector3.new(x0, 0, z0), Vector3.new(x0, 0, -126))
	BuildingKit.chainFence(map, Vector3.new(x0, 0, -112), Vector3.new(x0, 0, z1))
	Kit.sign(map, CFrame.new(117, 0, z1 + 2), "USED CARS")
	local wrecks = {
		{ 130, -140, 0.2, false },
		{ 150, -138, 1.4, false },
		{ 160, -110, 0.1, true },
		{ 135, -110, 2.6, false },
		{ 118, -100, 0.6, false },
		{ 150, -96, 1.8, false },
	}
	for _, w in wrecks do
		local cf = CFrame.new(w[1], 0, w[2]) * CFrame.Angles(0, w[3], 0)
		if w[4] then
			cf = cf * CFrame.new(0, 2.45, 0) * CFrame.Angles(0, 0, math.pi) * CFrame.new(0, -2.45, 0) -- on its roof
		end
		local car = BuildingKit.car(map, cf, Color3.fromHSV(rng:NextNumber(), 0.3, 0.3), rng)
		for _, p in car:GetDescendants() do
			if p:IsA("BasePart") and p.Name == "Body" then
				p.Material = Enum.Material.CorrodedMetal
			end
		end
	end
	Kit.barrel(map, Vector3.new(160, 0, -146))
	Kit.barrel(map, Vector3.new(157, 0, -147))
end

--------------------------------------------------------------------------- trees & details

local function trees(map: Model, rng: Random)
	for _, p in
		{
			Vector3.new(-170, 0, -40),
			Vector3.new(-90, 0, -165),
			Vector3.new(-60, 0, -150),
			Vector3.new(30, 0, -160),
			Vector3.new(-15, 0, 52),
			Vector3.new(25, 0, 45),
			Vector3.new(-160, 0, 20),
			Vector3.new(-125, 0, 60),
			Vector3.new(-90, 0, 170),
			Vector3.new(20, 0, 176),
		}
	do
		Kit.deadTree(map, p, rng:NextNumber(16, 26), rng)
	end
	-- a ring of trees just past the edge of town: dark shapes in the fog
	for a = 0, math.pi * 2 - 0.01, math.pi / 18 do
		local r = rng:NextNumber(190, 205)
		local pos = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if rng:NextNumber() < 0.6 then
			Kit.pine(map, pos, rng:NextNumber(28, 40), rng)
		else
			Kit.deadTree(map, pos, rng:NextNumber(20, 30), rng)
		end
	end
	for _ = 1, 10 do
		Kit.stain(
			map,
			Vector3.new(rng:NextNumber(-150, 150), 0, rng:NextNumber(-68, -52)),
			rng:NextNumber(1.5, 3.5),
			rng
		)
	end
	Kit.crate(map, Vector3.new(-155, 0, -32), 3, 0.5)
end

-- where a shadow figure may stand for a moment (AtmosphereController): roof edges, far corners
local SCARES = {
	Vector3.new(-28, 29, -22), -- the hospital roof
	Vector3.new(28, 29, -22),
	Vector3.new(30, 29, 26),
	Vector3.new(-71, 15, -80), -- Main Street rooftops
	Vector3.new(25, 15, -80),
	Vector3.new(-130, 14, 104), -- the police station roof
	Vector3.new(-112, 15.6, -98), -- on the gas station canopy
	Vector3.new(165, 0, -148), -- the back of the used-car lot
	Vector3.new(172, 0, 160), -- under the dead field light
	Vector3.new(-172, 0, 10), -- the edge of the west lot
	Vector3.new(130, 0, 62), -- the backyards
	Vector3.new(-40, 0, 172), -- the far end of the parking lot
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
	for _, p in Town.TOWERS do
		Kit.marker(map, "TowerSpot", p)
	end
	for _, p in Town.HELI do
		Kit.marker(map, "HeliZone", p)
	end
end

-- Rain-soaked and abandoned: puddles on every street, paper blowing down Main Street, glass
-- from the shop windows, tipped bins, and the quarantine line in front of the hospital.
local function weathering(map: Model, rng: Random)
	Clutter.puddles(map, rng, { -175, -70, 175, -50 }, 0, 26) -- Main Street
	Clutter.puddles(map, rng, { 50, -175, 70, 175 }, 0, 18) -- the avenue
	Clutter.puddles(map, rng, { -175, 67, 175, 83 }, 0, 14) -- South Street
	Clutter.puddles(map, rng, { -68, -45, -52, 175 }, 0, 10) -- West Street
	Clutter.puddles(map, rng, { -48, 92, 38, 168 }, 0, 12) -- the parking lot
	Clutter.puddles(map, rng, { -165, -145, -95, -85 }, 0, 6) -- the gas station
	for _, c in
		{
			Vector3.new(-120, 0, -62),
			Vector3.new(-40, 0, -56),
			Vector3.new(30, 0, -64),
			Vector3.new(110, 0, -58),
			Vector3.new(-5, 0, 130),
			Vector3.new(0, 0, -42),
		}
	do
		Clutter.papers(map, c, 10, 8, rng)
	end
	for _, x in { -71, -39, 25 } do
		Clutter.shards(map, Vector3.new(x, 0, -72), 4, 14, rng)
	end
	Clutter.shards(map, Vector3.new(18, 0, -56), 6, 16, rng)
	Clutter.trashCan(map, Vector3.new(-55, 0, -82), true, rng)
	Clutter.trashCan(map, Vector3.new(9, 0, -86), false, rng)
	Clutter.trashCan(map, Vector3.new(-23, 0, -80), true, rng)
	Clutter.trashCan(map, Vector3.new(84, 0, -45), true, rng)
	Clutter.trashCan(map, Vector3.new(-90, 0, 70), false, rng)
	-- the quarantine line
	Clutter.sawhorse(map, CFrame.new(-28, 0, -47))
	Clutter.sawhorse(map, CFrame.new(28, 0, -47))
	Clutter.sawhorse(map, CFrame.new(40, 0, -36) * CFrame.Angles(0, math.pi / 2, 0))
	Clutter.sandbags(map, CFrame.new(14, 0, -29), 8, rng)
	Clutter.sandbags(map, CFrame.new(-24, 0, -29), 8, rng)
	Kit.sign(map, CFrame.new(0, 0, -47), "QUARANTINE")
	Clutter.flashlight(map, Vector3.new(-60, 0, 30), 1.2)
end

-- Builds the map into `map` (an empty Model already in the workspace).
function Town.build(map: Model)
	local rng = Random.new(1313)
	grounds(map)
	hospitalShell(map, rng)
	hospitalRooms(map, rng)
	mainStreet(map, rng)
	gasStation(map, rng)
	houses(map, rng)
	policeStation(map, rng)
	parkingLot(map, rng)
	footballField(map, rng)
	carLot(map, rng)
	streetLights(map)
	trafficLight(map)
	burntCar(map, rng)
	trees(map, rng)
	weathering(map, rng)
	spots(map)
	Kit.boundary(map, Town.SIZE)
end

return Town
