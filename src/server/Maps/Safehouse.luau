--!strict
-- THE SAFEHOUSE: where players wait between rounds, high above the maps. A lived-in room at
-- night: a crackling fireplace with a leather couch and armchairs around it, warm hanging lamps
-- (one flickers), rugs, bookshelves and an old TV showing static. The things players use: the map
-- vote board (paper posters pinned under picture lights, a glowing pad in front of each), the
-- Z-Shop supply counter, the dressing mirror (character catalog) and the Alpha pedestals in a dark
-- alcove under red lights. And just enough to remember why you're inside: boarded windows with
-- something pressing its hands on the glass, a barricaded door with claw marks, a stopped clock.
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AlphaClasses = require(Shared.Config.AlphaClasses)
local Kit = require(script.Parent.Kit)
local BuildingKit = require(script.Parent.BuildingKit)

local Safehouse = {}

-- Things on the walls that LobbyService updates.
export type Refs = {
	mapSlots: { { label: TextLabel, prompt: ProximityPrompt } },
	modeLabel: TextLabel,
}

local BASE = Vector3.new(0, 300, 0) -- the floor's top is BASE.Y + 1
local W, D, H = 84, 64, 18 -- room size; walls are 1 stud thick inside these edges

local COLORS = {
	floor = Color3.fromRGB(92, 66, 48),
	ceiling = Color3.fromRGB(46, 36, 30),
	beam = Color3.fromRGB(58, 42, 32),
	plaster = Color3.fromRGB(96, 100, 88), -- faded, dusty green-grey
	wainscot = Color3.fromRGB(70, 50, 38),
	leather = Color3.fromRGB(84, 44, 36),
	rug = Color3.fromRGB(96, 34, 38),
	brick = Color3.fromRGB(96, 54, 42),
	paper = Color3.fromRGB(214, 204, 180),
	ink = Color3.fromRGB(40, 28, 26),
	cream = Color3.fromRGB(236, 222, 196),
	warm = Color3.fromRGB(255, 186, 120),
	blood = Color3.fromRGB(110, 14, 18),
	night = Color3.fromRGB(8, 8, 14),
	flesh = Color3.fromRGB(88, 96, 80),
}

local NORTH = Vector3.new(0, 0, -1)
local SOUTH = Vector3.new(0, 0, 1)
local EAST = Vector3.new(1, 0, 0)
local WEST = Vector3.new(-1, 0, 0)

local function at(x: number, y: number, z: number): Vector3
	return BASE + Vector3.new(x, y, z)
end

local function piece(
	parent: Instance,
	name: string,
	size: Vector3,
	pos: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	return Kit.part(parent, name, size, CFrame.new(pos), color, material)
end

-- A board with text on the face that looks along `dir`. Returns the label to update.
local function sign(
	parent: Instance,
	name: string,
	size: Vector2,
	pos: Vector3,
	dir: Vector3,
	text: string,
	style: { text: Color3, board: Color3?, font: Enum.Font?, glow: boolean? }
): TextLabel
	local board = Kit.part(
		parent,
		name,
		Vector3.new(size.X, size.Y, 0.3),
		CFrame.lookAt(pos, pos + dir),
		style.board or COLORS.ceiling,
		Enum.Material.Wood
	)
	board.CanCollide = false
	if not style.board then
		board.Transparency = 1
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.LightInfluence = if style.glow then 0 else 0.6
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.92, 0.86)
	label.Position = UDim2.fromScale(0.04, 0.07)
	label.Font = style.font or Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = style.text
	label.Text = text
	label.Parent = gui
	if style.glow then
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Front
		light.Range = 8
		light.Brightness = 0.5
		light.Color = style.text
		light.Parent = board
	end
	return label
end

local function prompt(
	parent: Instance,
	action: string,
	object: string,
	tag: string,
	range: number
): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.HoldDuration = 0
	p.MaxActivationDistance = range
	p.RequiresLineOfSight = false
	CollectionService:AddTag(p, tag)
	p.Parent = parent
	return p
end

--------------------------------------------------------------------------- the room

local WINDOWS = { -20, 20 } -- x of the two south windows, 5..12 studs above the floor

local function shell(room: Model)
	piece(room, "Floor", Vector3.new(W, 2, D), BASE, COLORS.floor, Enum.Material.WoodPlanks)
	piece(room, "Ceiling", Vector3.new(W, 1, D), at(0, H + 1.5, 0), COLORS.ceiling, Enum.Material.WoodPlanks)
	for x = -W / 2 + 8, W / 2 - 8, 12 do
		piece(room, "Beam", Vector3.new(1.4, 1.2, D - 2), at(x, H + 0.4, 0), COLORS.beam, Enum.Material.Wood)
	end
	local function wall(size: Vector3, pos: Vector3)
		piece(room, "Wall", size, pos, COLORS.plaster, Enum.Material.Plaster)
	end
	wall(Vector3.new(W, H, 2), at(0, 1 + H / 2, -D / 2)) -- north
	wall(Vector3.new(2, H, D), at(W / 2, 1 + H / 2, 0)) -- east
	wall(Vector3.new(2, H, D), at(-W / 2, 1 + H / 2, 0)) -- west
	-- south: solid under and over the windows, three pieces between them
	local z = D / 2
	wall(Vector3.new(W, 5, 2), at(0, 3.5, z))
	wall(Vector3.new(W, H - 12, 2), at(0, 13 + (H - 12) / 2, z))
	for _, seg in { { -33.5, 17 }, { 0, 30 }, { 33.5, 17 } } do
		wall(Vector3.new(seg[2], 7, 2), at(seg[1], 9.5, z))
	end
	-- dark wood panelling along the bottom of every wall
	local function panel(size: Vector3, pos: Vector3)
		piece(room, "Wainscot", size, pos, COLORS.wainscot, Enum.Material.WoodPlanks).CanCollide = false
	end
	panel(Vector3.new(W - 2, 4, 0.3), at(0, 3, -D / 2 + 1.15))
	panel(Vector3.new(W - 2, 4, 0.3), at(0, 3, D / 2 - 1.15))
	panel(Vector3.new(0.3, 4, D - 2), at(W / 2 - 1.15, 3, 0))
	panel(Vector3.new(0.3, 4, D - 2), at(-W / 2 + 1.15, 3, 0))
	-- rugs: a big worn one in the middle, a deep red one by the fire
	piece(
		room,
		"Rug",
		Vector3.new(30, 0.1, 22),
		at(0, 1.05, -4),
		Color3.fromRGB(70, 56, 48),
		Enum.Material.Carpet
	).CanCollide =
		false
	piece(room, "Rug", Vector3.new(26, 0.12, 14), at(0, 1.06, 19), COLORS.rug, Enum.Material.Carpet).CanCollide =
		false
end

-- The windows: dark glass, boards nailed across, the night outside, and someone at the glass.
local function windows(room: Model, rng: Random)
	local z = D / 2
	for _, x in WINDOWS do
		local glass = piece(
			room,
			"Window",
			Vector3.new(10, 7, 0.3),
			at(x, 9.5, z),
			Color3.fromRGB(20, 26, 36),
			Enum.Material.Glass
		)
		glass.Transparency = 0.45
		for _, frame in
			{
				{ Vector3.new(11, 0.6, 0.6), at(x, 13, z - 1) },
				{ Vector3.new(11, 0.6, 0.6), at(x, 6, z - 1) },
				{ Vector3.new(0.6, 7.6, 0.6), at(x - 5.2, 9.5, z - 1) },
				{ Vector3.new(0.6, 7.6, 0.6), at(x + 5.2, 9.5, z - 1) },
				{ Vector3.new(0.3, 7, 0.3), at(x, 9.5, z - 0.4) },
			}
		do
			piece(room, "WindowFrame", frame[1], frame[2], COLORS.wainscot, Enum.Material.Wood)
		end
		-- boards nailed across, crooked
		for i, tilt in { -0.18, 0.12, -0.05 } do
			Kit.part(
				room,
				"Board",
				Vector3.new(12, 0.9, 0.25),
				CFrame.new(at(x + rng:NextNumber(-0.6, 0.6), 7 + i * 1.8, z - 1.4))
					* CFrame.Angles(0, 0, tilt),
				Color3.fromRGB(104, 80, 58):Lerp(COLORS.beam, rng:NextNumber(0, 0.6)),
				Enum.Material.WoodPlanks
			)
		end
		-- cold moonlight coming in
		local moon = piece(room, "Moonlight", Vector3.new(1, 1, 1), at(x, 12, z + 6), COLORS.night)
		moon.Transparency = 1
		moon.CanCollide = false
		Kit.light(moon, 18, 0.9, Color3.fromRGB(120, 140, 210))
	end
	-- outside: dark ground, pines, the night
	piece(
		room,
		"Outside",
		Vector3.new(W + 20, 1, 14),
		at(0, 0.5, z + 8),
		Color3.fromRGB(24, 30, 24),
		Enum.Material.Grass
	)
	piece(room, "Night", Vector3.new(W + 20, 40, 1), at(0, 10, z + 16), COLORS.night)
	for _, x in { -30, -12, 6, 30 } do
		Kit.pine(room, at(x + rng:NextNumber(-3, 3), 1, z + 12), rng:NextNumber(16, 22), rng)
	end
	-- a figure at the right window, hands pressed on the glass
	local wx = WINDOWS[2]
	local shadow = Color3.fromRGB(26, 28, 26)
	piece(room, "Figure", Vector3.new(3.4, 5, 1.4), at(wx + 1, 6.5, z + 2.6), shadow).CanCollide = false
	local head = piece(room, "FigureHead", Vector3.new(1.8, 2, 1.6), at(wx + 1.2, 10.4, z + 2.3), shadow)
	head.CanCollide = false
	for _, dx in { -0.45, 0.45 } do
		local eye = piece(
			room,
			"FigureEye",
			Vector3.new(0.3, 0.2, 0.1),
			at(wx + 1.2 + dx, 10.7, z + 1.45),
			Color3.fromRGB(226, 232, 206),
			Enum.Material.Neon
		)
		eye.CanCollide = false
	end
	for _, hand in { { -2.6, 10.2, 0.2 }, { 3.6, 9.4, -0.25 } } do
		Kit.part(
			room,
			"FigureHand",
			Vector3.new(1.1, 1.5, 0.3),
			CFrame.new(at(wx + hand[1], hand[2], z + 0.45)) * CFrame.Angles(0, 0, hand[3]),
			Color3.fromRGB(70, 78, 66)
		).CanCollide =
			false
	end
	local smear = piece(room, "Smear", Vector3.new(1, 3.2, 0.05), at(wx - 2.4, 8.2, z - 0.2), COLORS.blood)
	smear.CanCollide = false
	smear.Transparency = 0.35
end

-- The fireplace in the middle of the south wall, the mode sign on its chimney breast.
local function fireplace(room: Model): TextLabel
	local zi = D / 2 - 1 -- inside face of the south wall
	local brick = Enum.Material.Brick
	piece(room, "FirePillar", Vector3.new(2.5, 9, 3), at(-5.25, 5.5, zi - 1.5), COLORS.brick, brick)
	piece(room, "FirePillar", Vector3.new(2.5, 9, 3), at(5.25, 5.5, zi - 1.5), COLORS.brick, brick)
	piece(room, "FireLintel", Vector3.new(13, 3, 3), at(0, 8.5, zi - 1.5), COLORS.brick, brick)
	piece(room, "FireBack", Vector3.new(8, 6, 0.5), at(0, 4, zi - 0.3), Color3.fromRGB(20, 16, 14))
	piece(
		room,
		"Hearth",
		Vector3.new(14, 0.4, 4),
		at(0, 1.2, zi - 3),
		Color3.fromRGB(60, 58, 56),
		Enum.Material.Slate
	)
	piece(room, "Mantel", Vector3.new(15, 0.6, 4), at(0, 10.3, zi - 2), COLORS.wainscot, Enum.Material.Wood)
	piece(
		room,
		"Chimney",
		Vector3.new(11, H - 9.6, 1.5),
		at(0, 10.6 + (H - 9.6) / 2, zi - 0.75),
		COLORS.brick,
		brick
	)
	-- the fire: logs, flames, a warm light that never holds still
	for i, yaw in { 0.3, -0.25 } do
		Kit.cylinder(
			room,
			"FireLog",
			5,
			1,
			CFrame.new(at(0, 1.9 + (i - 1) * 0.7, zi - 1.6)) * CFrame.Angles(0, yaw, 0),
			Kit.BARK,
			Enum.Material.Wood
		)
	end
	local embers = piece(
		room,
		"Embers",
		Vector3.new(3.5, 0.4, 1.6),
		at(0, 1.6, zi - 1.6),
		Color3.fromRGB(255, 90, 24),
		Enum.Material.Neon
	)
	embers.CanCollide = false
	local flames = Instance.new("Fire")
	flames.Size = 4
	flames.Heat = 6
	flames.Color = Color3.fromRGB(255, 150, 60)
	flames.SecondaryColor = Color3.fromRGB(255, 70, 20)
	flames.Parent = embers
	Kit.light(embers, 34, 2, Color3.fromRGB(255, 140, 70), true)
	-- on the mantel: candles and a clock stopped at 3:33
	for _, x in { -6, -4.8, 5.6 } do
		Kit.cylinder(
			room,
			"Candle",
			1.2,
			0.5,
			CFrame.new(at(x, 11.2, zi - 2)) * CFrame.Angles(0, 0, math.rad(90)),
			COLORS.cream,
			Enum.Material.SmoothPlastic
		)
		local flame = piece(
			room,
			"CandleFlame",
			Vector3.new(0.2, 0.35, 0.2),
			at(x, 12, zi - 2),
			COLORS.warm,
			Enum.Material.Neon
		)
		flame.CanCollide = false
	end
	local clock = piece(
		room,
		"Clock",
		Vector3.new(2.4, 2.8, 1),
		at(1.5, 12, zi - 2.2),
		COLORS.wainscot,
		Enum.Material.Wood
	)
	clock.CanCollide = false
	sign(room, "ClockFace", Vector2.new(1.8, 1.8), at(1.5, 12.2, zi - 2.75), NORTH, "3:33", {
		text = COLORS.ink,
		board = COLORS.cream,
		font = Enum.Font.Antique,
	})
	-- what's next, carved into a board on the chimney
	return sign(room, "ModeSign", Vector2.new(22, 2.6), at(0, 15.5, zi - 1.7), NORTH, "WAITING FOR PLAYERS", {
		text = Color3.fromRGB(230, 70, 60),
		board = Color3.fromRGB(36, 26, 22),
		font = Enum.Font.Creepster,
		glow = true,
	})
end

local function armchair(room: Model, cf: CFrame)
	Kit.onGround(room, "ChairBase", Vector3.new(4.4, 2, 4), cf, COLORS.leather, Enum.Material.Leather)
	Kit.part(
		room,
		"ChairBack",
		Vector3.new(4.4, 3.4, 1),
		cf * CFrame.new(0, 3.6, 1.6),
		COLORS.leather,
		Enum.Material.Leather
	)
	for _, x in { -2, 2 } do
		Kit.part(
			room,
			"ChairArm",
			Vector3.new(0.6, 1.2, 4),
			cf * CFrame.new(x, 2.6, 0),
			COLORS.leather,
			Enum.Material.Leather
		)
	end
end

local function lamp(room: Model, pos: Vector3, flicker: boolean)
	piece(
		room,
		"LampCord",
		Vector3.new(0.1, 2.6, 0.1),
		pos + Vector3.new(0, 1.7, 0),
		Color3.fromRGB(20, 20, 20)
	).CanCollide =
		false
	local shade = Kit.cylinder(
		room,
		"LampShade",
		1.2,
		2.6,
		CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(40, 44, 40),
		Enum.Material.Metal
	)
	shade.CanCollide = false
	local bulb = piece(
		room,
		"Bulb",
		Vector3.new(0.7, 0.7, 0.7),
		pos - Vector3.new(0, 0.7, 0),
		COLORS.warm,
		Enum.Material.Neon
	)
	bulb.Shape = Enum.PartType.Ball
	bulb.CanCollide = false
	Kit.light(bulb, 32, 1.1, COLORS.warm, flicker)
end

-- The living room around the fire, the lights, the shelves, the TV.
local function livingRoom(room: Model, rng: Random)
	-- the couch faces the fire
	local leather = Enum.Material.Leather
	piece(room, "CouchSeat", Vector3.new(14, 2, 4), at(0, 2, 15), COLORS.leather, leather)
	piece(room, "CouchBack", Vector3.new(14, 3.6, 1.2), at(0, 4.4, 13.4), COLORS.leather, leather)
	for _, x in { -7.3, 7.3 } do
		piece(room, "CouchArm", Vector3.new(1.2, 3, 4.6), at(x, 2.5, 15), COLORS.leather, leather)
	end
	for _, x in { -4.4, 0, 4.4 } do
		Kit.part(
			room,
			"Cushion",
			Vector3.new(4.2, 0.7, 3.4),
			CFrame.new(at(x, 3.35, 15.2)),
			Color3.fromRGB(96, 52, 42),
			Enum.Material.Fabric
		)
	end
	armchair(room, CFrame.lookAt(at(-13, 1, 21), at(0, 1, 25)))
	armchair(room, CFrame.lookAt(at(13, 1, 21), at(0, 1, 25)))
	-- coffee table with mugs and a candle
	piece(room, "CoffeeTable", Vector3.new(8, 0.4, 4), at(0, 2.8, 20.5), COLORS.wainscot, Enum.Material.Wood)
	for _, x in { -3.6, 3.6 } do
		for _, dz in { -1.6, 1.6 } do
			piece(
				room,
				"TableLeg",
				Vector3.new(0.4, 1.6, 0.4),
				at(x, 1.8, 20.5 + dz),
				COLORS.beam,
				Enum.Material.Wood
			)
		end
	end
	for _, m in { { -2, 20 }, { 1.2, 21.2 } } do
		Kit.cylinder(
			room,
			"Mug",
			0.8,
			0.6,
			CFrame.new(at(m[1], 3.4, m[2])) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(180, 176, 166),
			Enum.Material.SmoothPlastic
		)
	end
	-- hanging lamps: the middle one flickers now and then
	lamp(room, at(0, H - 2, -6), true)
	lamp(room, at(-22, H - 2, 6), false)
	lamp(room, at(22, H - 2, 6), false)
	lamp(room, at(0, H - 2, 18), false)
	-- bookshelves in the east corners
	for _, z in { -24, 24 } do
		BuildingKit.shelf(room, CFrame.lookAt(at(W / 2 - 1.9, 1, z), at(W / 2 - 1.9, 1, z) + WEST), 10, rng)
	end
	-- an old TV in the south-east corner, nothing on but static
	local tvAt = at(31, 1, 25)
	local tvCf = CFrame.lookAt(tvAt, at(10, 1, 6))
	Kit.onGround(room, "TVStand", Vector3.new(6, 2.6, 3), tvCf, COLORS.wainscot, Enum.Material.Wood)
	Kit.part(
		room,
		"TV",
		Vector3.new(5, 4, 4),
		tvCf * CFrame.new(0, 4.6, 0),
		Color3.fromRGB(40, 36, 34),
		Enum.Material.SmoothPlastic
	)
	local screen = Kit.part(
		room,
		"TVScreen",
		Vector3.new(4, 3, 0.2),
		tvCf * CFrame.new(0, 4.6, -2.05),
		Color3.fromRGB(150, 156, 160),
		Enum.Material.Neon
	)
	screen.Transparency = 0.4
	screen.CanCollide = false
	Kit.light(screen, 14, 0.6, Color3.fromRGB(170, 190, 220), true)
	-- dust drifting in the lamplight
	local air = piece(room, "Dust", Vector3.new(W - 10, 10, D - 10), at(0, 8, 0), COLORS.night)
	air.Transparency = 1
	air.CanCollide = false
	air.CanQuery = false
	local dust = Instance.new("ParticleEmitter")
	dust.Shape = Enum.ParticleEmitterShape.Box
	dust.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	dust.Rate = 6
	dust.Lifetime = NumberRange.new(8, 12)
	dust.Speed = NumberRange.new(0.1, 0.4)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Size = NumberSequence.new(0.07)
	dust.Transparency = NumberSequence.new(0.45)
	dust.LightEmission = 0.3
	dust.Color = ColorSequence.new(Color3.fromRGB(255, 230, 200))
	dust.Parent = air
end

-- The barricaded back door (west wall, north end): planks, a dresser, claw marks, a warning.
local function barricade(room: Model)
	local x, z = -W / 2 + 1, -24
	piece(
		room,
		"BackDoor",
		Vector3.new(0.4, 8, 5),
		at(x + 0.2, 5, z),
		Color3.fromRGB(60, 44, 34),
		Enum.Material.WoodPlanks
	)
	for i, tilt in { 0.35, -0.3, 0.1 } do
		Kit.part(
			room,
			"Plank",
			Vector3.new(0.3, 0.8, 7),
			CFrame.new(at(x + 0.6, 3 + i * 1.6, z)) * CFrame.Angles(tilt, 0, 0),
			Color3.fromRGB(110, 84, 60),
			Enum.Material.WoodPlanks
		)
	end
	for i = 0, 3 do
		Kit.part(
			room,
			"ClawMark",
			Vector3.new(0.05, 2.6, 0.18),
			CFrame.new(at(x + 0.45, 7, z - 1.4 + i * 0.5)) * CFrame.Angles(0.35, 0, 0),
			Color3.fromRGB(26, 16, 14)
		).CanCollide =
			false
	end
	-- a dresser shoved against it
	piece(room, "Dresser", Vector3.new(3, 5, 7), at(x + 2.6, 3.5, z), COLORS.wainscot, Enum.Material.Wood)
	for _, y in { 2.4, 4.6 } do
		piece(room, "Drawer", Vector3.new(0.2, 1.6, 6.2), at(x + 4.15, y, z), COLORS.beam, Enum.Material.Wood).CanCollide =
			false
	end
	-- handprints and the warning scrawled on the wall next to it
	for _, p in { { -36, 6.5 }, { -34.6, 5.2 }, { -38.4, 4.6 } } do
		local print =
			piece(room, "Handprint", Vector3.new(0.9, 1.1, 0.05), at(p[1], p[2], -D / 2 + 1.05), COLORS.blood)
		print.CanCollide = false
		print.Transparency = 0.3
	end
	sign(room, "Scrawl", Vector2.new(9, 4), at(-34, 11, -D / 2 + 1.1), SOUTH, "DON'T LET\nTHEM IN", {
		text = COLORS.blood,
		font = Enum.Font.Creepster,
	})
end

--------------------------------------------------------------------------- what players use

-- The map vote board on the north wall: 3 paper posters + a glowing pad in front of each.
local function voteBoard(room: Model): { { label: TextLabel, prompt: ProximityPrompt } }
	local board = Instance.new("Model")
	board.Name = "VoteBoard"
	board.Parent = room
	local wallZ = -D / 2 + 1
	piece(
		board,
		"Corkboard",
		Vector3.new(52, 13, 0.4),
		at(0, 9.8, wallZ + 0.2),
		Color3.fromRGB(120, 92, 64),
		Enum.Material.Cardboard
	)
	for _, frame in
		{
			{ Vector3.new(53, 0.6, 0.6), at(0, 16.3, wallZ + 0.4) },
			{ Vector3.new(53, 0.6, 0.6), at(0, 3.3, wallZ + 0.4) },
			{ Vector3.new(0.6, 13.6, 0.6), at(-26.3, 9.8, wallZ + 0.4) },
			{ Vector3.new(0.6, 13.6, 0.6), at(26.3, 9.8, wallZ + 0.4) },
		}
	do
		piece(board, "BoardFrame", frame[1], frame[2], COLORS.wainscot, Enum.Material.Wood)
	end
	sign(
		board,
		"VoteHeader",
		Vector2.new(30, 2.4),
		at(0, 14.6, wallZ + 0.5),
		SOUTH,
		"VOTE FOR THE NEXT MAP",
		{
			text = COLORS.cream,
			font = Enum.Font.SpecialElite,
		}
	)
	local slots = {}
	for i, x in { -16, 0, 16 } do
		local label = sign(board, `MapSlot{i}`, Vector2.new(12, 8), at(x, 8.6, wallZ + 0.55), SOUTH, "", {
			text = COLORS.ink,
			board = COLORS.paper,
			font = Enum.Font.SpecialElite,
		})
		for _, corner in { -5.4, 5.4 } do
			local pin = piece(
				board,
				"Pin",
				Vector3.new(0.35, 0.35, 0.35),
				at(x + corner, 12.2, wallZ + 0.8),
				Color3.fromRGB(170, 30, 30)
			)
			pin.Shape = Enum.PartType.Ball
			pin.CanCollide = false
		end
		-- a little brass picture light over each poster
		local brass = piece(
			board,
			"PictureLight",
			Vector3.new(4, 0.4, 0.8),
			at(x, 13.4, wallZ + 1),
			Color3.fromRGB(150, 116, 60),
			Enum.Material.Metal
		)
		brass.CanCollide = false
		Kit.light(brass, 10, 0.9, COLORS.warm)
		-- the pad you stand on to vote: a soft glowing circle on the floor
		local pad = Kit.cylinder(
			board,
			"VotePad",
			0.12,
			6.5,
			CFrame.new(at(x, 1.07, wallZ + 7)) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(255, 214, 160),
			Enum.Material.Neon
		)
		pad.Transparency = 0.65
		pad.CanCollide = false
		local vote = prompt(pad, "Vote", "Map", "MapVotePrompt", 8)
		vote.Enabled = false
		vote:SetAttribute("Slot", i)
		table.insert(slots, { label = label, prompt = vote })
	end
	return slots
end

-- The Z-Shop: a supply counter on the west wall with stocked shelves behind it.
local function shopCounter(room: Model, rng: Random)
	local x, z = -W / 2 + 6, -10
	local counter = piece(
		room,
		"ShopCounter",
		Vector3.new(4, 4, 16),
		at(x, 3, z),
		COLORS.wainscot,
		Enum.Material.WoodPlanks
	)
	piece(room, "CounterTop", Vector3.new(4.6, 0.3, 16.6), at(x, 5.15, z), COLORS.beam, Enum.Material.Wood)
	prompt(counter, "Open shop", "Z-Shop", "ShopPrompt", 10)
	BuildingKit.shelf(room, CFrame.lookAt(at(-W / 2 + 1.9, 1, z), at(-W / 2 + 1.9, 1, z) + EAST), 14, rng)
	-- supplies on the counter: a lantern, a medkit, a box of shells
	local medkit =
		piece(room, "Medkit", Vector3.new(1.6, 1, 2.2), at(x, 5.8, z - 4), Color3.fromRGB(200, 196, 188))
	medkit.CanCollide = false
	piece(room, "MedkitCross", Vector3.new(1.62, 0.3, 0.8), at(x, 6.32, z - 4), Color3.fromRGB(190, 30, 30)).CanCollide =
		false
	piece(
		room,
		"Shells",
		Vector3.new(1.4, 0.8, 1.8),
		at(x, 5.7, z + 3),
		Color3.fromRGB(150, 110, 50),
		Enum.Material.Cardboard
	).CanCollide =
		false
	local lantern =
		piece(room, "Lantern", Vector3.new(0.9, 1.3, 0.9), at(x, 6, z + 6), Kit.WARM, Enum.Material.Neon)
	lantern.CanCollide = false
	piece(room, "LanternCap", Vector3.new(1.1, 0.3, 1.1), at(x, 6.8, z + 6), Kit.STONE, Enum.Material.Metal).CanCollide =
		false
	Kit.light(lantern, 14, 0.8, Kit.WARM, true)
	sign(room, "ShopSign", Vector2.new(12, 2.6), at(-W / 2 + 1.25, 13, z), EAST, "Z-SHOP", {
		text = Color3.fromRGB(255, 200, 110),
		board = Color3.fromRGB(30, 24, 20),
		font = Enum.Font.SpecialElite,
		glow = true,
	})
end

-- The dressing mirror (character catalog) on the west wall, with a clothes rack.
local function dressingCorner(room: Model)
	local x, z = -W / 2 + 1, 12
	piece(
		room,
		"MirrorFrame",
		Vector3.new(0.5, 11, 7),
		at(x + 0.3, 7, z),
		COLORS.wainscot,
		Enum.Material.Wood
	)
	local mirror = piece(
		room,
		"Mirror",
		Vector3.new(0.3, 10, 6),
		at(x + 0.6, 7, z),
		Color3.fromRGB(190, 196, 200),
		Enum.Material.Glass
	)
	mirror.Reflectance = 0.45
	prompt(mirror, "Edit your character", "Catalog", "CatalogPrompt", 10)
	sign(room, "MirrorSign", Vector2.new(8, 1.8), at(x + 0.4, 13.6, z), EAST, "CATALOG", {
		text = COLORS.cream,
		board = Color3.fromRGB(30, 24, 20),
		font = Enum.Font.SpecialElite,
		glow = true,
	})
	-- a clothes rack with a few jackets
	local rackX = x + 4
	for _, dz in { -3, 3 } do
		piece(
			room,
			"RackPost",
			Vector3.new(0.3, 7, 0.3),
			at(rackX, 4.5, z + 9 + dz),
			Kit.STONE,
			Enum.Material.Metal
		)
	end
	piece(room, "RackBar", Vector3.new(0.25, 0.25, 6.4), at(rackX, 8, z + 9), Kit.STONE, Enum.Material.Metal)
	for i, color in
		{
			Color3.fromRGB(70, 60, 44),
			Color3.fromRGB(44, 52, 60),
			Color3.fromRGB(96, 40, 36),
			Color3.fromRGB(60, 64, 46),
		}
	do
		piece(
			room,
			"Jacket",
			Vector3.new(0.8, 3.6, 1.6),
			at(rackX, 6, z + 6.6 + i * 1.2),
			color,
			Enum.Material.Fabric
		).CanCollide =
			false
	end
end

-- The Alpha pedestals in a dark alcove on the east wall: one figure per class, lit red from above.
local CLASS_LOOK = {
	Runner = { scale = Vector3.new(0.8, 1.1, 0.8), color = Color3.fromRGB(255, 120, 150) },
	Tank = { scale = Vector3.new(1.5, 1.2, 1.4), color = Color3.fromRGB(220, 90, 90) },
	Screamer = { scale = Vector3.new(1, 1, 1), color = Color3.fromRGB(230, 110, 200) },
}

local function alphaStation(room: Model)
	local station = Instance.new("Model")
	station.Name = "AlphaStation"
	station.Parent = room
	local facing = WEST
	local centre = at(W / 2 - 8, 1, 0)
	local right = Vector3.new(0, 1, 0):Cross(facing).Unit
	local look = CFrame.lookAt(Vector3.zero, facing)
	piece(
		station,
		"Alcove",
		Vector3.new(0.3, H - 1, 32),
		at(W / 2 - 1.2, 1 + (H - 1) / 2, 0),
		Color3.fromRGB(30, 24, 26),
		Enum.Material.Plaster
	)
	for i, className in AlphaClasses.order do
		local class = (AlphaClasses :: any)[className]
		local shape = CLASS_LOOK[className] or CLASS_LOOK.Screamer
		local pos = centre + right * ((i - 2) * 9)
		local base = piece(
			station,
			"Pedestal",
			Vector3.new(5, 2, 5),
			pos + Vector3.new(0, 1, 0),
			Color3.fromRGB(70, 68, 66),
			Enum.Material.Concrete
		)
		-- a figure in the class's shape: legs, a torn torso, reaching arms, a head with red eyes
		local s = shape.scale
		local function limb(name: string, size: Vector3, offset: Vector3, color: Color3): Part
			local p = Kit.part(
				station,
				name,
				Vector3.new(size.X * s.X, size.Y * s.Y, size.Z * s.Z),
				CFrame.new(pos) * look * CFrame.new(offset.X * s.X, 2 + offset.Y * s.Y, offset.Z * s.Z),
				color,
				Enum.Material.SmoothPlastic
			)
			p.CanCollide = false
			return p
		end
		local cloth = Color3.fromRGB(48, 44, 42)
		limb("Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0), cloth)
		limb("Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0), cloth)
		limb("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), cloth)
		limb("Arm", Vector3.new(1, 1, 2.2), Vector3.new(-1.5, 3.5, -1), COLORS.flesh)
		limb("Arm", Vector3.new(1, 1, 2.2), Vector3.new(1.5, 3.5, -1), COLORS.flesh)
		local head = limb("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.6, 0), COLORS.flesh)
		for _, x in { -0.25, 0.25 } do
			local eye = Kit.part(
				station,
				"Eye",
				Vector3.new(0.25, 0.2, 0.1),
				head.CFrame * CFrame.new(x * s.X, 0.15, -0.62 * s.Z),
				Color3.fromRGB(255, 30, 40),
				Enum.Material.Neon
			)
			eye.CanCollide = false
		end
		-- the class name on a plaque on the pedestal, and a red light from above
		sign(
			station,
			"ClassSign",
			Vector2.new(4.6, 1.2),
			pos + Vector3.new(0, 1, 0) + facing * 2.6,
			facing,
			class.name,
			{
				text = shape.color,
				board = Color3.fromRGB(26, 22, 22),
				font = Enum.Font.Creepster,
				glow = true,
			}
		)
		local redLamp = piece(
			station,
			"RedLamp",
			Vector3.new(1.4, 0.4, 1.4),
			Vector3.new(pos.X, BASE.Y + H - 0.2, pos.Z),
			Color3.fromRGB(120, 20, 20),
			Enum.Material.Neon
		)
		redLamp.CanCollide = false
		local beam = Instance.new("SpotLight")
		beam.Face = Enum.NormalId.Bottom
		beam.Angle = 45
		beam.Range = 20
		beam.Brightness = 2.5
		beam.Color = Color3.fromRGB(230, 40, 40)
		beam.Shadows = true
		beam.Parent = redLamp
		local pick = prompt(base, `Play as {class.name}`, "Alpha class", "AlphaPickPrompt", 8)
		pick:SetAttribute("Class", className)
	end
	sign(
		station,
		"StationSign",
		Vector2.new(22, 2.8),
		at(W / 2 - 1.5, 15, 0),
		facing,
		"IF YOU ARE THE ALPHA...",
		{
			text = Color3.fromRGB(220, 50, 50),
			font = Enum.Font.Creepster,
		}
	)
end

local function spawnPoint(room: Model)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0 -- no forcefield
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(at(0, 1.5, 0))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Parent = room
	CollectionService:AddTag(spawn, "LobbySpawn")
end

-- Builds the safehouse as workspace.Lobby (`parent`) and returns what LobbyService updates.
function Safehouse.build(parent: Instance): Refs
	local room = Instance.new("Model")
	room.Name = "Lobby"
	room.Parent = parent
	local rng = Random.new(77)
	shell(room)
	windows(room, rng)
	local modeLabel = fireplace(room)
	livingRoom(room, rng)
	barricade(room)
	local slots = voteBoard(room)
	shopCounter(room, rng)
	dressingCorner(room)
	alphaStation(room)
	spawnPoint(room)
	return { mapSlots = slots, modeLabel = modeLabel }
end

return Safehouse
