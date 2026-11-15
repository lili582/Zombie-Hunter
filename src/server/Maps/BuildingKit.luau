--!strict
-- The indoor kit: walls with door gaps, floors and ceilings, fluorescent and emergency lights,
-- lockers, furniture, store fronts and the outdoor pieces of town life (cars, buses, chain-link
-- fences, field goals). Built on Kit's anchored parts and realistic materials.
local CollectionService = game:GetService("CollectionService")

local Kit = require(script.Parent.Kit)

local BuildingKit = {}

BuildingKit.FLUORESCENT = Color3.fromRGB(210, 230, 225)
BuildingKit.EMERGENCY = Color3.fromRGB(255, 40, 40)
BuildingKit.METAL = Color3.fromRGB(110, 114, 120)
BuildingKit.GLASS = Color3.fromRGB(120, 150, 160)

export type Gap = { at: number, width: number, height: number? }

-- A wall from `a` to `b` (its base at a.Y), with door gaps measured along the wall from `a`.
-- A gap lower than the wall gets a lintel above it.
function BuildingKit.wall(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	height: number,
	color: Color3,
	material: Enum.Material,
	gaps: { Gap }?
): Model
	local wall = Instance.new("Model")
	wall.Name = "Wall"
	wall.Parent = parent
	local flatB = Vector3.new(b.X, a.Y, b.Z)
	local length = (flatB - a).Magnitude
	local look = CFrame.lookAt(a, flatB)
	local thickness = 1
	local sorted = table.clone(gaps or {})
	table.sort(sorted, function(x, y)
		return x.at < y.at
	end)
	local function segment(from: number, to: number, y0: number, h: number)
		if to - from < 0.05 or h < 0.05 then
			return
		end
		Kit.part(
			wall,
			"Segment",
			Vector3.new(thickness, h, to - from),
			look * CFrame.new(0, y0 + h / 2, -(from + to) / 2),
			color,
			material
		)
	end
	local cursor = 0
	for _, gap in sorted do
		local g0, g1 = gap.at - gap.width / 2, gap.at + gap.width / 2
		segment(cursor, g0, 0, height)
		local gh = gap.height or height
		segment(g0, g1, gh, height - gh) -- lintel
		cursor = g1
	end
	segment(cursor, length, 0, height)
	return wall
end

-- A floor or ceiling slab over the rectangle x0..x1, z0..z1 with its top at `y`.
function BuildingKit.slab(
	parent: Instance,
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	y: number,
	color: Color3,
	material: Enum.Material
): Part
	return Kit.part(
		parent,
		"Slab",
		Vector3.new(math.abs(x1 - x0), 1, math.abs(z1 - z0)),
		CFrame.new((x0 + x1) / 2, y - 0.5, (z0 + z1) / 2),
		color,
		material
	)
end

-- A buzzing fluorescent panel on the ceiling (y = ceiling height). Some flicker.
function BuildingKit.ceilingLight(parent: Instance, pos: Vector3, flicker: boolean, dead: boolean?): Part
	local panel = Kit.part(
		parent,
		"Fluorescent",
		Vector3.new(6, 0.3, 1.6),
		CFrame.new(pos - Vector3.new(0, 0.2, 0)),
		BuildingKit.FLUORESCENT,
		if dead then Enum.Material.SmoothPlastic else Enum.Material.Neon
	)
	panel.CanCollide = false
	if not dead then
		Kit.light(panel, 20, 0.75, BuildingKit.FLUORESCENT, flicker)
	end
	return panel
end

-- A red emergency light over a door: the only colour in a dark hallway.
function BuildingKit.emergencyLight(parent: Instance, pos: Vector3): Part
	local lamp = Kit.part(
		parent,
		"Emergency",
		Vector3.new(1.2, 0.6, 0.6),
		CFrame.new(pos),
		BuildingKit.EMERGENCY,
		Enum.Material.Neon
	)
	lamp.CanCollide = false
	Kit.light(lamp, 16, 1.2, BuildingKit.EMERGENCY, true)
	return lamp
end

-- A row of school lockers along `dir` from `start`, doors facing `facing`. Every `hideEvery`-th
-- one is a real hiding locker (tagged), the rest are scenery.
function BuildingKit.lockerRow(
	parent: Instance,
	start: Vector3,
	dir: Vector3,
	count: number,
	facing: Vector3,
	hideEvery: number,
	color: Color3
): Model
	local row = Instance.new("Model")
	row.Name = "Lockers"
	row.Parent = parent
	local w = 2.4
	for i = 0, count - 1 do
		local pos = start + dir.Unit * (i * w + w / 2)
		local cf = CFrame.lookAt(pos, pos + facing)
		local hiding = hideEvery > 0 and i % hideEvery == math.floor(hideEvery / 2)
		local locker = Kit.onGround(
			row,
			if hiding then "HidingLocker" else "Locker",
			Vector3.new(w - 0.1, 7.5, 2.2),
			cf,
			color,
			Enum.Material.DiamondPlate
		)
		if hiding then
			CollectionService:AddTag(locker, "Locker")
		end
		-- vents and a handle on the door
		for v = 0, 2 do
			local vent = Kit.part(
				row,
				"Vent",
				Vector3.new(w * 0.6, 0.12, 0.05),
				cf * CFrame.new(0, 6.4 - v * 0.3, -1.12),
				Color3.fromRGB(30, 30, 34)
			)
			vent.CanCollide = false
		end
		local handle = Kit.part(
			row,
			"Handle",
			Vector3.new(0.15, 0.8, 0.12),
			cf * CFrame.new(w * 0.32, 3.8, -1.15),
			BuildingKit.METAL,
			Enum.Material.Metal
		)
		handle.CanCollide = false
	end
	return row
end

-- A school desk with a chair.
function BuildingKit.desk(parent: Instance, cf: CFrame, tipped: boolean)
	local tilt = if tipped then CFrame.Angles(math.rad(80), 0, 0) * CFrame.new(0, 1, 1) else CFrame.new()
	local top = Kit.part(
		parent,
		"Desk",
		Vector3.new(4, 0.3, 2.6),
		cf * tilt * CFrame.new(0, 2.6, 0),
		Color3.fromRGB(150, 118, 84),
		Enum.Material.Wood
	)
	top.Name = "Desk"
	for _, x in { -1.7, 1.7 } do
		for _, z in { -1, 1 } do
			Kit.part(
				parent,
				"Leg",
				Vector3.new(0.2, 2.5, 0.2),
				cf * tilt * CFrame.new(x, 1.25, z),
				BuildingKit.METAL,
				Enum.Material.Metal
			)
		end
	end
	Kit.part(
		parent,
		"Seat",
		Vector3.new(2, 0.3, 2),
		cf * CFrame.new(0, 1.6, 2.6),
		Color3.fromRGB(70, 90, 120),
		Enum.Material.SmoothPlastic
	)
	Kit.part(
		parent,
		"Back",
		Vector3.new(2, 2, 0.3),
		cf * CFrame.new(0, 2.7, 3.6),
		Color3.fromRGB(70, 90, 120),
		Enum.Material.SmoothPlastic
	)
end

-- A tall shelf full of books (library) or cans (store), against a wall.
function BuildingKit.shelf(parent: Instance, cf: CFrame, length: number, rng: Random)
	Kit.onGround(
		parent,
		"Shelf",
		Vector3.new(length, 8, 1.6),
		cf,
		Color3.fromRGB(78, 56, 40),
		Enum.Material.Wood
	)
	for row = 0, 3 do
		local x = -length / 2 + 0.4
		while x < length / 2 - 0.6 do
			local w = rng:NextNumber(0.35, 0.9)
			local book = Kit.part(
				parent,
				"Books",
				Vector3.new(w, rng:NextNumber(1.1, 1.6), 1.2),
				cf * CFrame.new(x + w / 2, 1 + row * 1.9 + 0.7, -0.5),
				Color3.fromHSV(rng:NextNumber(), rng:NextNumber(0.3, 0.6), rng:NextNumber(0.25, 0.5)),
				Enum.Material.SmoothPlastic
			)
			book.CanCollide = false
			x += w + 0.05
		end
	end
end

-- Gym bleachers: steps rising away from `cf` (facing the court along -Z).
function BuildingKit.bleachers(parent: Instance, cf: CFrame, length: number, rows: number)
	for i = 0, rows - 1 do
		Kit.part(
			parent,
			"Bleacher",
			Vector3.new(length, 0.6, 2.4),
			cf * CFrame.new(0, 1.2 + i * 1.4, i * 2.4),
			Color3.fromRGB(120, 92, 64),
			Enum.Material.WoodPlanks
		)
		Kit.part(
			parent,
			"Riser",
			Vector3.new(length, 1.4, 0.3),
			cf * CFrame.new(0, 0.5 + i * 1.4, i * 2.4 - 1.2),
			BuildingKit.METAL,
			Enum.Material.Metal
		)
	end
end

-- A long table with benches (cafeteria / food court).
function BuildingKit.table(parent: Instance, cf: CFrame, length: number, color: Color3)
	Kit.part(
		parent,
		"Table",
		Vector3.new(length, 0.3, 3),
		cf * CFrame.new(0, 2.6, 0),
		color,
		Enum.Material.SmoothPlastic
	)
	for _, x in { -length / 2 + 0.5, length / 2 - 0.5 } do
		Kit.part(
			parent,
			"Leg",
			Vector3.new(0.3, 2.5, 2.6),
			cf * CFrame.new(x, 1.25, 0),
			BuildingKit.METAL,
			Enum.Material.Metal
		)
	end
	for _, z in { -2.4, 2.4 } do
		Kit.part(
			parent,
			"Bench",
			Vector3.new(length, 0.3, 1),
			cf * CFrame.new(0, 1.6, z),
			color,
			Enum.Material.SmoothPlastic
		)
	end
end

-- A dark rectangular pillar (garages, the mall).
function BuildingKit.pillar(parent: Instance, pos: Vector3, height: number, size: number?): Part
	return Kit.onGround(
		parent,
		"Pillar",
		Vector3.new(size or 2.5, height, size or 2.5),
		CFrame.new(pos),
		Color3.fromRGB(120, 118, 116),
		Enum.Material.Concrete
	)
end

-- A glass railing (mall galleries).
function BuildingKit.railing(parent: Instance, a: Vector3, b: Vector3)
	local length = (b - a).Magnitude
	local look = CFrame.lookAt(a, b)
	local glass = Kit.part(
		parent,
		"Railing",
		Vector3.new(0.3, 3.4, length),
		look * CFrame.new(0, 1.7, -length / 2),
		BuildingKit.GLASS,
		Enum.Material.Glass
	)
	glass.Transparency = 0.6
	Kit.part(
		parent,
		"Handrail",
		Vector3.new(0.4, 0.3, length),
		look * CFrame.new(0, 3.5, -length / 2),
		BuildingKit.METAL,
		Enum.Material.Metal
	)
end

-- An escalator: a climbable ramp of steps from `bottom` to `top` (both on their floors), with
-- side panels. Stopped, of course.
function BuildingKit.escalator(parent: Instance, bottom: Vector3, top: Vector3, width: number): Model
	local esc = Instance.new("Model")
	esc.Name = "Escalator"
	esc.Parent = parent
	local run = Vector3.new(top.X, bottom.Y, top.Z) - bottom
	local length = (top - bottom).Magnitude
	local look = CFrame.lookAt(bottom, top)
	Kit.part(
		esc,
		"Ramp",
		Vector3.new(width, 0.6, length),
		look * CFrame.new(0, 0, -length / 2),
		Color3.fromRGB(70, 72, 76),
		Enum.Material.DiamondPlate
	)
	local stepCount = math.floor(run.Magnitude / 1.2)
	for i = 1, stepCount - 1 do
		local stripe = Kit.part(
			esc,
			"Step",
			Vector3.new(width - 0.4, 0.05, 0.12),
			look * CFrame.new(0, 0.33, -i * length / stepCount),
			Color3.fromRGB(220, 200, 80),
			Enum.Material.SmoothPlastic
		)
		stripe.CanCollide = false
	end
	for _, x in { -width / 2 - 0.3, width / 2 + 0.3 } do
		Kit.part(
			esc,
			"Side",
			Vector3.new(0.5, 3.2, length),
			look * CFrame.new(x, 1.4, -length / 2),
			Color3.fromRGB(46, 48, 52),
			Enum.Material.Metal
		)
	end
	return esc
end

-- A store front: a glass window wall with a door gap, a lit sign above, and half-down shutters.
function BuildingKit.storeFront(
	parent: Instance,
	cf: CFrame,
	width: number,
	height: number,
	name: string,
	color: Color3
): Model
	local front = Instance.new("Model")
	front.Name = "StoreFront"
	front.Parent = parent
	local door = 6
	local side = (width - door) / 2
	for _, sx in { -1, 1 } do
		local glass = Kit.part(
			front,
			"Window",
			Vector3.new(side, height - 3, 0.3),
			cf * CFrame.new(sx * (door / 2 + side / 2), (height - 3) / 2, 0),
			BuildingKit.GLASS,
			Enum.Material.Glass
		)
		glass.Transparency = 0.55
		Kit.part(
			front,
			"Frame",
			Vector3.new(0.5, height - 3, 0.5),
			cf * CFrame.new(sx * width / 2, (height - 3) / 2, 0),
			BuildingKit.METAL,
			Enum.Material.Metal
		)
	end
	Kit.part(
		front,
		"Header",
		Vector3.new(width, 3, 0.8),
		cf * CFrame.new(0, height - 1.5, 0),
		Color3.fromRGB(30, 28, 32),
		Enum.Material.SmoothPlastic
	)
	local signBoard = Kit.part(
		front,
		"SignBoard",
		Vector3.new(width * 0.7, 2, 0.2),
		cf * CFrame.new(0, height - 1.5, -0.5),
		color,
		Enum.Material.Neon
	)
	signBoard.Transparency = 0.2
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = signBoard
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(20, 16, 22)
	label.Text = name
	label.Parent = gui
	-- a rolling shutter, stuck halfway over the door
	local shutter = Kit.part(
		front,
		"Shutter",
		Vector3.new(door, 3, 0.2),
		cf * CFrame.new(0, height - 4.5, 0.1),
		BuildingKit.METAL,
		Enum.Material.CorrodedMetal
	)
	shutter.CanCollide = false
	return front
end

-- A store mannequin, standing somewhere it shouldn't.
function BuildingKit.mannequin(parent: Instance, cf: CFrame)
	local white = Color3.fromRGB(225, 222, 216)
	Kit.part(
		parent,
		"Mannequin",
		Vector3.new(1.6, 2, 0.9),
		cf * CFrame.new(0, 4, 0),
		white,
		Enum.Material.SmoothPlastic
	)
	local head = Kit.part(
		parent,
		"Head",
		Vector3.new(1, 1.2, 1),
		cf * CFrame.new(0, 5.7, 0),
		white,
		Enum.Material.SmoothPlastic
	)
	head.Shape = Enum.PartType.Ball
	for _, x in { -0.45, 0.45 } do
		Kit.part(
			parent,
			"Leg",
			Vector3.new(0.6, 3, 0.6),
			cf * CFrame.new(x, 1.5, 0),
			white,
			Enum.Material.SmoothPlastic
		)
	end
	Kit.part(
		parent,
		"Arm",
		Vector3.new(0.5, 2, 0.5),
		cf * CFrame.new(-1.05, 4, 0),
		white,
		Enum.Material.SmoothPlastic
	)
	Kit.part(
		parent,
		"Arm",
		Vector3.new(0.5, 2, 0.5),
		cf * CFrame.new(1.2, 4.6, -0.6) * CFrame.Angles(math.rad(70), 0, 0),
		white,
		Enum.Material.SmoothPlastic
	)
	Kit.part(
		parent,
		"Stand",
		Vector3.new(1.4, 0.2, 1.4),
		cf * CFrame.new(0, 0.1, 0),
		BuildingKit.METAL,
		Enum.Material.Metal
	)
end

-- An arcade cabinet with a glowing screen.
function BuildingKit.arcade(parent: Instance, cf: CFrame, rng: Random)
	Kit.onGround(
		parent,
		"Arcade",
		Vector3.new(3, 6.5, 2.6),
		cf,
		Color3.fromRGB(28, 26, 40),
		Enum.Material.SmoothPlastic
	)
	local screen = Kit.part(
		parent,
		"Screen",
		Vector3.new(2.4, 2, 0.1),
		cf * CFrame.new(0, 4.5, -1.32),
		Color3.fromHSV(rng:NextNumber(), 0.7, 0.9),
		Enum.Material.Neon
	)
	screen.Transparency = 0.15
	screen.CanCollide = false
	Kit.light(screen, 8, 0.6, screen.Color, true)
end

-- The fountain in the middle of the food court: a round basin of still dark water.
function BuildingKit.fountain(parent: Instance, pos: Vector3): Model
	local f = Instance.new("Model")
	f.Name = "Fountain"
	f.Parent = parent
	local rim = Kit.cylinder(
		f,
		"Basin",
		2,
		22,
		CFrame.new(pos + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(150, 146, 140),
		Enum.Material.Marble
	)
	rim.Name = "Basin"
	local water = Kit.cylinder(
		f,
		"Water",
		0.4,
		20,
		CFrame.new(pos + Vector3.new(0, 1.85, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(28, 44, 48),
		Enum.Material.Glass
	)
	water.Transparency = 0.2
	water.CanCollide = false
	Kit.cylinder(
		f,
		"Column",
		8,
		2.4,
		CFrame.new(pos + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(150, 146, 140),
		Enum.Material.Marble
	)
	local bowl = Kit.cylinder(
		f,
		"Bowl",
		1,
		8,
		CFrame.new(pos + Vector3.new(0, 9, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(150, 146, 140),
		Enum.Material.Marble
	)
	bowl.Name = "Bowl"
	return f
end

-- A parked car: body, cabin with dark windows, wheels. Some have a light left on.
function BuildingKit.car(parent: Instance, cf: CFrame, color: Color3, rng: Random): Model
	local car = Instance.new("Model")
	car.Name = "Car"
	car.Parent = parent
	Kit.part(
		car,
		"Body",
		Vector3.new(6, 2.2, 13),
		cf * CFrame.new(0, 1.9, 0),
		color,
		Enum.Material.SmoothPlastic
	)
	local cabin = Kit.part(
		car,
		"Cabin",
		Vector3.new(5.4, 2, 6.5),
		cf * CFrame.new(0, 3.9, 0.6),
		Color3.fromRGB(26, 30, 34),
		Enum.Material.Glass
	)
	cabin.Transparency = 0.15
	for _, x in { -2.9, 2.9 } do
		for _, z in { -4.2, 4.2 } do
			Kit.cylinder(
				car,
				"Wheel",
				1,
				2.4,
				cf * CFrame.new(x, 1.2, z),
				Color3.fromRGB(20, 20, 22),
				Enum.Material.SmoothPlastic
			)
		end
	end
	if rng:NextNumber() < 0.3 then
		for _, x in { -2, 2 } do
			local head = Kit.part(
				car,
				"Headlight",
				Vector3.new(1, 0.6, 0.1),
				cf * CFrame.new(x, 2.3, -6.55),
				Color3.fromRGB(255, 240, 200),
				Enum.Material.Neon
			)
			head.CanCollide = false
			local beam = Instance.new("SpotLight")
			beam.Face = Enum.NormalId.Front
			beam.Range = 30
			beam.Angle = 40
			beam.Brightness = 1.5
			beam.Color = Color3.fromRGB(255, 240, 200)
			beam.Parent = head
		end
	end
	return car
end

-- A yellow school bus.
function BuildingKit.bus(parent: Instance, cf: CFrame): Model
	local bus = Instance.new("Model")
	bus.Name = "SchoolBus"
	bus.Parent = parent
	local yellow = Color3.fromRGB(214, 160, 32)
	Kit.part(
		bus,
		"Body",
		Vector3.new(8, 7, 30),
		cf * CFrame.new(0, 4.8, 0),
		yellow,
		Enum.Material.SmoothPlastic
	)
	Kit.part(
		bus,
		"Hood",
		Vector3.new(7, 3, 4),
		cf * CFrame.new(0, 3, -17),
		yellow,
		Enum.Material.SmoothPlastic
	)
	for _, x in { -4.05, 4.05 } do
		local windows = Kit.part(
			bus,
			"Windows",
			Vector3.new(0.1, 2.2, 24),
			cf * CFrame.new(x, 6.6, 1),
			Color3.fromRGB(26, 30, 34),
			Enum.Material.Glass
		)
		windows.Transparency = 0.1
		Kit.part(
			bus,
			"Stripe",
			Vector3.new(0.1, 0.4, 30),
			cf * CFrame.new(x, 4.6, 0),
			Color3.fromRGB(20, 20, 20),
			Enum.Material.SmoothPlastic
		)
		for _, z in { -10, 9 } do
			Kit.cylinder(
				bus,
				"Wheel",
				1.2,
				3,
				cf * CFrame.new(x, 1.5, z),
				Color3.fromRGB(20, 20, 22),
				Enum.Material.SmoothPlastic
			)
		end
	end
	return bus
end

-- A chain-link fence from `a` to `b`.
function BuildingKit.chainFence(parent: Instance, a: Vector3, b: Vector3, height: number?)
	local h = height or 8
	local length = (b - a).Magnitude
	local look = CFrame.lookAt(a, b)
	local mesh = Kit.part(
		parent,
		"ChainLink",
		Vector3.new(0.15, h, length),
		look * CFrame.new(0, h / 2, -length / 2),
		Color3.fromRGB(140, 144, 150),
		Enum.Material.DiamondPlate
	)
	mesh.Transparency = 0.55
	for d = 0, length, 10 do
		Kit.part(
			parent,
			"FencePost",
			Vector3.new(0.4, h + 0.4, 0.4),
			look * CFrame.new(0, (h + 0.4) / 2, -d),
			BuildingKit.METAL,
			Enum.Material.Metal
		)
	end
end

-- A football / soccer goal.
function BuildingKit.goal(parent: Instance, cf: CFrame)
	local white = Color3.fromRGB(230, 230, 228)
	for _, x in { -8, 8 } do
		Kit.onGround(
			parent,
			"GoalPost",
			Vector3.new(0.5, 8, 0.5),
			cf * CFrame.new(x, 0, 0),
			white,
			Enum.Material.Metal
		)
	end
	Kit.part(
		parent,
		"Crossbar",
		Vector3.new(16.5, 0.5, 0.5),
		cf * CFrame.new(0, 8, 0),
		white,
		Enum.Material.Metal
	)
	local net = Kit.part(
		parent,
		"Net",
		Vector3.new(16, 8, 0.1),
		cf * CFrame.new(0, 4, 4),
		white,
		Enum.Material.Fabric
	)
	net.Transparency = 0.8
	net.CanCollide = false
end

-- A painted line on a floor or field.
function BuildingKit.line(parent: Instance, a: Vector3, b: Vector3, width: number, color: Color3)
	local length = (b - a).Magnitude
	local p = Kit.part(
		parent,
		"Line",
		Vector3.new(width, 0.05, length),
		CFrame.lookAt(a, b) * CFrame.new(0, 0.03, -length / 2),
		color,
		Enum.Material.SmoothPlastic
	)
	p.CanCollide = false
	p.CanQuery = false
end

-- A solid flight of stairs from `bottom` going along `dir`, one stud up per step, until it has
-- climbed `rise` studs. The last step's top is at bottom.Y + rise, ready to meet a floor.
function BuildingKit.stairs(
	parent: Instance,
	bottom: Vector3,
	dir: Vector3,
	rise: number,
	width: number
): Model
	local stairs = Instance.new("Model")
	stairs.Name = "Stairs"
	stairs.Parent = parent
	local run = 1.5
	local flat = Vector3.new(dir.X, 0, dir.Z).Unit
	local look = CFrame.lookAt(bottom, bottom + flat)
	for i = 1, math.ceil(rise) do
		local top = math.min(i, rise)
		Kit.part(
			stairs,
			"Step",
			Vector3.new(width, top, run),
			look * CFrame.new(0, top / 2, -(i - 0.5) * run),
			Color3.fromRGB(150, 148, 142),
			Enum.Material.Concrete
		)
	end
	return stairs
end

-- A hospital bed: a steel frame, a stained mattress and a pillow. Some have a sheet over
-- something that isn't moving.
function BuildingKit.hospitalBed(parent: Instance, cf: CFrame, covered: boolean)
	local bed = Instance.new("Model")
	bed.Name = "HospitalBed"
	bed.Parent = parent
	for _, x in { -1.3, 1.3 } do
		for _, z in { -3, 3 } do
			Kit.onGround(
				bed,
				"Leg",
				Vector3.new(0.25, 2, 0.25),
				cf * CFrame.new(x, 0, z),
				BuildingKit.METAL,
				Enum.Material.Metal
			)
		end
	end
	Kit.part(
		bed,
		"Frame",
		Vector3.new(3, 0.4, 6.6),
		cf * CFrame.new(0, 2.1, 0),
		BuildingKit.METAL,
		Enum.Material.Metal
	)
	Kit.part(
		bed,
		"Mattress",
		Vector3.new(2.8, 0.6, 6.2),
		cf * CFrame.new(0, 2.6, 0),
		Color3.fromRGB(196, 200, 190),
		Enum.Material.Fabric
	)
	Kit.part(
		bed,
		"Headboard",
		Vector3.new(3, 2.4, 0.3),
		cf * CFrame.new(0, 3, -3.2),
		BuildingKit.METAL,
		Enum.Material.Metal
	)
	Kit.part(
		bed,
		"Pillow",
		Vector3.new(2, 0.4, 1.2),
		cf * CFrame.new(0, 3.1, -2.4),
		Color3.fromRGB(220, 222, 216),
		Enum.Material.Fabric
	)
	if covered then
		Kit.part(
			bed,
			"Sheet",
			Vector3.new(2.6, 1, 5),
			cf * CFrame.new(0, 3.3, 0.4),
			Color3.fromRGB(206, 208, 200),
			Enum.Material.Fabric
		)
	end
	return bed
end

return BuildingKit
