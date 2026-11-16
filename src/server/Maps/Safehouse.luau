--!strict
-- THE SAFEHOUSE: a high-rise apartment, high above the dead city. It was somebody's beautiful
-- home: a concrete-and-hardwood living room, a dropped ceiling with a warm LED cove and recessed
-- downlights, a big TV over a linear fireplace on a dark wood-slat wall, floating shelves with
-- cube lamps, an L-shaped sectional on a shag rug, geometric pendant lights, floor-to-ceiling
-- glass. Now the survivors hide in it: the TV only shows the emergency broadcast, the windows are
-- boarded and taped with handprints on the glass, the plants are dying, the city below burns in
-- the fog, and something stands on the balcony some nights.
--
--   N:  [MISSING posters]  [front door = the deploy door, EXIT]  [TV: the map vote + 3 pads]
--   W:  [shelves + lamps]  [the painting]  [specimen jars: private Alpha pick]  [wardrobe mirror]
--   C:  [sectional, ottoman, pendants]          NE: [kitchen: the Z-Shop bell on the island]
--   S + SE:  [floor-to-ceiling windows, the balcony, the skyline]
--
-- Every station is an object with a prompt. The client's SafehouseController animates parts by
-- name (HearthBulb, DrumFire, DeployDoor/DoorPanel/DoorWheel, DoorBulb, DoorFog, DoorVapor,
-- Window1/2 with Board/ScareHand/ScareEye, TallOne, ShopTube, CRTScreen, CandleLight, JarLight).
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AlphaClasses = require(Shared.Config.AlphaClasses)
local Kit = require(script.Parent.Kit)

local Safehouse = {}

export type Poster = { face: ImageLabel, name: TextLabel }
-- Things on the walls that LobbyService updates.
export type Refs = {
	mapSlots: { { label: TextLabel, prompt: ProximityPrompt } },
	modeLabel: TextLabel,
	posters: { Poster },
}

local BASE = Vector3.new(0, 300, 0) -- the floor's top is BASE.Y + 1
local W, D, H = 64, 48, 16 -- inside: x -31..31, z -23..23, floor y 1, ceiling y 17

local C = {
	concrete = Color3.fromRGB(104, 96, 88),
	ceiling = Color3.fromRGB(92, 86, 80),
	wood = Color3.fromRGB(96, 46, 30), -- the hardwood floor
	slats = Color3.fromRGB(46, 34, 28),
	shelf = Color3.fromRGB(70, 42, 30),
	fabric = Color3.fromRGB(176, 158, 118),
	fabricDark = Color3.fromRGB(128, 112, 84),
	leather = Color3.fromRGB(58, 50, 46),
	rug = Color3.fromRGB(196, 174, 128),
	frame = Color3.fromRGB(34, 34, 38),
	glass = Color3.fromRGB(40, 46, 64),
	paper = Color3.fromRGB(206, 196, 172),
	ink = Color3.fromRGB(36, 26, 26),
	blood = Color3.fromRGB(110, 14, 18),
	-- light
	led = Color3.fromRGB(255, 168, 86),
	warm = Color3.fromRGB(255, 206, 150),
	ember = Color3.fromRGB(255, 150, 70),
	lavender = Color3.fromRGB(191, 169, 242),
	danger = Color3.fromRGB(255, 50, 60),
	signal = Color3.fromRGB(191, 216, 255),
	jar = Color3.fromRGB(163, 234, 200),
	sick = Color3.fromRGB(214, 236, 200),
	black = Color3.fromRGB(4, 3, 7),
}

local NORTH = Vector3.new(0, 0, -1)
local SOUTH = Vector3.new(0, 0, 1)
local EAST = Vector3.new(1, 0, 0)
local WEST = Vector3.new(-1, 0, 0)
local UP = Vector3.new(0, 1, 0)

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

local function deco<T>(p: T): T
	local part = p :: any
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return p
end

-- A light that doesn't cast shadows (only a few lights may: the pendant, the fire, the moon).
local function softLight(on: BasePart, range: number, brightness: number, color: Color3): PointLight
	local l = Kit.light(on, range, brightness, color)
	l.Shadows = false
	return l
end

local function upright(
	name: string,
	parent: Instance,
	height: number,
	diameter: number,
	pos: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	return Kit.cylinder(
		parent,
		name,
		height,
		diameter,
		CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
end

-- A rod from a to b (pendant cages, wires, mullions).
local function rod(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	thickness: number,
	color: Color3,
	material: Enum.Material?
): Part
	local length = (b - a).Magnitude
	return deco(
		Kit.part(
			parent,
			name,
			Vector3.new(thickness, thickness, length),
			CFrame.lookAt(a, b) * CFrame.new(0, 0, -length / 2),
			color,
			material or Enum.Material.Metal
		)
	)
end

-- Text on the face of a board that looks along `dir`. No board colour = only the text shows.
local function sign(
	parent: Instance,
	name: string,
	size: Vector2,
	pos: Vector3,
	dir: Vector3,
	text: string,
	style: { text: Color3, board: Color3?, font: Enum.Font?, glow: boolean? }
): TextLabel
	local board = deco(
		Kit.part(
			parent,
			name,
			Vector3.new(size.X, size.Y, 0.15),
			CFrame.lookAt(pos, pos + dir),
			style.board or C.black,
			Enum.Material.SmoothPlastic
		)
	)
	if not style.board then
		board.Transparency = 1
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.LightInfluence = if style.glow then 0 else 0.7
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

local function frame(
	parent: Instance,
	pos: UDim2,
	size: UDim2,
	color: Color3,
	round: boolean?,
	transparency: number?
): Frame
	local f = Instance.new("Frame")
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = f
	end
	return f
end

local function surface(part: BasePart, pixels: number, lightInfluence: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = pixels
	gui.LightInfluence = lightInfluence
	gui.Parent = part
	return gui
end

--------------------------------------------------------------------------- the room

-- Concrete walls, hardwood floor, a dropped ceiling with a glowing LED cove and downlights, the
-- front door opening in the north wall, glass along the south wall and the south half of the east.
local function shell(room: Model)
	piece(room, "Floor", Vector3.new(W, 2, D), BASE, C.wood, Enum.Material.WoodPlanks)
	piece(room, "Ceiling", Vector3.new(W, 1, D), at(0, H + 1.5, 0), C.ceiling, Enum.Material.Concrete)
	local function wall(size: Vector3, pos: Vector3)
		piece(room, "Wall", size, pos, C.concrete, Enum.Material.Concrete)
	end
	-- north wall with the front door x -23..-17, up to y 11
	local nz = -D / 2
	wall(Vector3.new(9, H, 2), at(-27.5, 1 + H / 2, nz))
	wall(Vector3.new(6, H - 10, 2), at(-20, 11 + (H - 10) / 2, nz))
	wall(Vector3.new(49, H, 2), at(7.5, 1 + H / 2, nz))
	wall(Vector3.new(2, H, D), at(-W / 2, 1 + H / 2, 0)) -- west
	wall(Vector3.new(2, H, D / 2), at(W / 2, 1 + H / 2, -D / 4)) -- east, kitchen half
	-- the glass: a low concrete ledge, a header, dark mullions, tinted panes
	piece(room, "Ledge", Vector3.new(W, 1, 2.4), at(0, 1.5, D / 2 - 0.2), C.concrete, Enum.Material.Concrete)
	piece(
		room,
		"Ledge",
		Vector3.new(2.4, 1, D / 2),
		at(W / 2 - 0.2, 1.5, D / 4),
		C.concrete,
		Enum.Material.Concrete
	)
	piece(room, "Header", Vector3.new(W + 2, 1.4, 2), at(0, H + 0.3, D / 2), C.frame, Enum.Material.Metal)
	piece(room, "Header", Vector3.new(2, 1.4, D / 2), at(W / 2, H + 0.3, D / 4), C.frame, Enum.Material.Metal)
	for x = -W / 2, W / 2, 8 do
		piece(
			room,
			"Mullion",
			Vector3.new(0.6, H - 1, 0.6),
			at(x, 1 + (H - 1) / 2 + 0.5, D / 2),
			C.frame,
			Enum.Material.Metal
		)
	end
	for z = 0, D / 2, 8 do
		piece(
			room,
			"Mullion",
			Vector3.new(0.6, H - 1, 0.6),
			at(W / 2, 1 + (H - 1) / 2 + 0.5, z),
			C.frame,
			Enum.Material.Metal
		)
	end
	-- the dropped ceiling band along the solid walls, a warm LED strip on its inner edge
	local soffitY = H - 0.25
	for _, s in
		{
			{ Vector3.new(W, 1.5, 5), at(0, soffitY + 0.75, -D / 2 + 2.5) },
			{ Vector3.new(5, 1.5, D - 5), at(-W / 2 + 2.5, soffitY + 0.75, 2.5) },
			{ Vector3.new(5, 1.5, D / 2 - 5), at(W / 2 - 2.5, soffitY + 0.75, -D / 4 + 2.5) },
		}
	do
		deco(piece(room, "Soffit", s[1], s[2], C.ceiling, Enum.Material.Concrete))
	end
	local function led(a: Vector3, b: Vector3)
		local strip = rod(room, "LEDStrip", a, b, 0.2, C.led, Enum.Material.Neon)
		strip.CastShadow = false
	end
	led(at(-W / 2 + 5, soffitY + 0.1, -D / 2 + 5.1), at(W / 2 - 5, soffitY + 0.1, -D / 2 + 5.1))
	led(at(-W / 2 + 5.1, soffitY + 0.1, -D / 2 + 5), at(-W / 2 + 5.1, soffitY + 0.1, D / 2 - 1))
	led(at(W / 2 - 5.1, soffitY + 0.1, -D / 2 + 5), at(W / 2 - 5.1, soffitY + 0.1, -0.5))
	for _, p in
		{
			at(-20, soffitY - 0.4, -18),
			at(0, soffitY - 0.4, -18),
			at(20, soffitY - 0.4, -18),
			at(-26, soffitY - 0.4, 0),
			at(-26, soffitY - 0.4, 16),
		}
	do
		local glow = deco(piece(room, "CoveGlow", Vector3.new(0.4, 0.4, 0.4), p, C.led, Enum.Material.Neon))
		glow.Transparency = 1
		softLight(glow, 20, 0.5, C.led).Name = "CoveLight"
	end
	-- recessed downlights in the band
	for _, p in
		{
			at(-26, soffitY, -20.5),
			at(-10, soffitY, -20.5),
			at(10, soffitY, -20.5),
			at(26, soffitY, -20.5),
			at(-28.5, soffitY, -6),
			at(-28.5, soffitY, 10),
			at(28.5, soffitY, -12),
		}
	do
		local can = deco(upright("Downlight", room, 0.15, 1, p, C.warm, Enum.Material.Neon))
		local beam = Instance.new("SpotLight")
		beam.Face = Enum.NormalId.Left -- the cylinder lies on its side: Left points down
		beam.Angle = 70
		beam.Range = 16
		beam.Brightness = 1.1
		beam.Color = C.warm
		beam.Shadows = false
		beam.Parent = can
	end
end

--------------------------------------------------------------------------- north: the TV wall

local function pottedPlant(room: Model, pos: Vector3, height: number, rng: Random)
	upright(
		"Pot",
		room,
		2.6,
		1.8,
		pos + Vector3.new(0, 1.3, 0),
		Color3.fromRGB(70, 62, 56),
		Enum.Material.Slate
	)
	upright(
		"Stem",
		room,
		height,
		0.2,
		pos + Vector3.new(0, 2.6 + height / 2, 0),
		Color3.fromRGB(70, 60, 40),
		Enum.Material.Wood
	)
	-- leaves: dull, browning at the edges (nobody waters them any more)
	for _ = 1, 9 do
		local leaf = pos
			+ Vector3.new(
				rng:NextNumber(-1.3, 1.3),
				2.6 + height * rng:NextNumber(0.5, 1.05),
				rng:NextNumber(-1.3, 1.3)
			)
		local p = deco(
			piece(
				room,
				"Leaves",
				Vector3.new(1.4, 1, 1.4),
				leaf,
				Color3.fromRGB(58, 72, 40):Lerp(Color3.fromRGB(96, 78, 44), rng:NextNumber(0, 0.7)),
				Enum.Material.Grass
			)
		)
		p.Shape = Enum.PartType.Ball
	end
end

-- A framed picture: a little scene drawn with UI frames. `scene` draws into the canvas.
local function picture(room: Model, pos: Vector3, dir: Vector3, size: Vector2, scene: (Frame) -> ())
	Kit.part(
		room,
		"PictureFrame",
		Vector3.new(size.X + 0.4, size.Y + 0.4, 0.2),
		CFrame.lookAt(pos, pos + dir),
		Color3.fromRGB(26, 24, 22),
		Enum.Material.Wood
	)
	local mount = deco(
		Kit.part(
			room,
			"Picture",
			Vector3.new(size.X, size.Y, 0.05),
			CFrame.lookAt(pos, pos + dir) * CFrame.new(0, 0, -0.13),
			C.paper
		)
	)
	local canvas = frame(
		surface(mount, 40, 0.8),
		UDim2.fromScale(0.06, 0.06),
		UDim2.fromScale(0.88, 0.88),
		Color3.fromRGB(40, 42, 50)
	)
	scene(canvas)
end

-- Lighthouse at night, its light red.
local function lighthouseScene(c: Frame)
	frame(c, UDim2.fromScale(0, 0.62), UDim2.fromScale(1, 0.38), Color3.fromRGB(26, 34, 44))
	frame(c, UDim2.fromScale(0.55, 0.3), UDim2.fromScale(0.1, 0.34), Color3.fromRGB(180, 176, 166))
	frame(c, UDim2.fromScale(0.54, 0.22), UDim2.fromScale(0.12, 0.09), Color3.fromRGB(220, 40, 40), true)
end

-- A hallway... with someone pale standing at the end of it.
local function hallwayScene(c: Frame)
	frame(c, UDim2.fromScale(0.3, 0.2), UDim2.fromScale(0.4, 0.8), Color3.fromRGB(70, 64, 58))
	frame(c, UDim2.fromScale(0.42, 0.35), UDim2.fromScale(0.16, 0.45), Color3.fromRGB(20, 18, 18))
	frame(c, UDim2.fromScale(0.47, 0.38), UDim2.fromScale(0.06, 0.07), Color3.fromRGB(214, 214, 204), true)
	frame(c, UDim2.fromScale(0.46, 0.46), UDim2.fromScale(0.08, 0.26), Color3.fromRGB(196, 196, 186))
end

-- The TV over the fireplace: the vote board, on an emergency broadcast. Returns the map slots.
local function tvWall(room: Model, rng: Random): { { label: TextLabel, prompt: ProximityPrompt } }
	local z = -D / 2 + 1
	-- the dark wood-slat wall behind
	for x = -11, 11, 1 do
		Kit.part(
			room,
			"Slat",
			Vector3.new(0.8, H - 1.5, 0.3),
			CFrame.new(at(x, 1 + (H - 1.5) / 2, z + 0.15)),
			C.slats,
			Enum.Material.Wood
		)
	end
	-- the linear fireplace: a dark box, a long glowing bed, flames along it
	piece(
		room,
		"FireBox",
		Vector3.new(16, 3.6, 1.6),
		at(0, 3, z + 0.9),
		Color3.fromRGB(14, 12, 12),
		Enum.Material.SmoothPlastic
	)
	piece(
		room,
		"Hearth",
		Vector3.new(19, 0.5, 3.2),
		at(0, 1.25, z + 1.6),
		Color3.fromRGB(150, 144, 134),
		Enum.Material.Marble
	)
	local bed = deco(
		piece(room, "DrumFire", Vector3.new(13.6, 0.4, 0.8), at(0, 2.1, z + 1.3), C.ember, Enum.Material.Neon)
	)
	Kit.light(bed, 26, 1.6, Color3.fromRGB(255, 150, 80)).Name = "FireLight"
	for x = -5, 5, 2.5 do
		local spot = deco(piece(room, "Flame", Vector3.new(1, 0.2, 0.5), at(x, 2.4, z + 1.3), C.ember))
		spot.Transparency = 1
		local fire = Instance.new("Fire")
		fire.Size = 2.5
		fire.Heat = 4
		fire.Color = Color3.fromRGB(255, 150, 60)
		fire.SecondaryColor = Color3.fromRGB(255, 70, 20)
		fire.Parent = spot
	end
	deco(
		piece(
			room,
			"FireGlass",
			Vector3.new(15, 3, 0.1),
			at(0, 3, z + 1.75),
			Color3.fromRGB(60, 50, 50),
			Enum.Material.Glass
		)
	).Transparency =
		0.7
	-- the floating shelf between fireplace and TV
	piece(room, "TVShelf", Vector3.new(22, 0.6, 2.2), at(0, 5.4, z + 1.1), C.shelf, Enum.Material.Wood)
	-- the TV: black bezel, a screen of cold static with the vote on it
	piece(
		room,
		"TV",
		Vector3.new(16.4, 9.4, 0.5),
		at(0, 10.6, z + 0.55),
		C.frame,
		Enum.Material.SmoothPlastic
	)
	local screen = deco(
		piece(
			room,
			"CRTScreen",
			Vector3.new(15.8, 8.8, 0.08),
			at(0, 10.6, z + 0.84),
			Color3.fromRGB(60, 66, 78),
			Enum.Material.Neon
		)
	)
	screen.Transparency = 0.15
	softLight(screen, 22, 1, C.signal)
	local gui = surface(screen, 30, 0)
	local static = frame(gui, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.fromRGB(26, 30, 38))
	for _ = 1, 40 do
		frame(
			static,
			UDim2.fromScale(rng:NextNumber(0, 0.98), rng:NextNumber(0, 0.98)),
			UDim2.fromScale(rng:NextNumber(0.01, 0.06), 0.006),
			Color3.fromRGB(120, 128, 140),
			false,
			0.5
		)
	end
	frame(gui, UDim2.fromScale(0, 0.04), UDim2.fromScale(1, 0.12), Color3.fromRGB(150, 20, 26))
	local banner = Instance.new("TextLabel")
	banner.BackgroundTransparency = 1
	banner.Position = UDim2.fromScale(0.02, 0.05)
	banner.Size = UDim2.fromScale(0.96, 0.1)
	banner.Font = Enum.Font.GothamBlack
	banner.TextScaled = true
	banner.TextColor3 = Color3.fromRGB(255, 240, 230)
	banner.Text = "EMERGENCY BROADCAST - STAY INDOORS - VOTE: WHERE DO WE GO TONIGHT?"
	banner.Parent = gui
	-- the three map slots on the screen, and the three pads on the floor in front
	local slots = {}
	for i, x in { -5.2, 0, 5.2 } do
		local label = sign(room, `MapSlot{i}`, Vector2.new(4.8, 5), at(x, 9.8, z + 0.95), SOUTH, "", {
			text = Color3.fromRGB(230, 236, 246),
			board = Color3.fromRGB(34, 40, 52),
			glow = true,
		})
		local pz = -14
		local pad =
			deco(upright("VotePad", room, 0.08, 5, at(x * 1.15, 1.05, pz), C.signal, Enum.Material.Neon))
		pad.Transparency = 0.75
		local ring = deco(
			upright(
				"VoteRing",
				room,
				0.06,
				5.6,
				at(x * 1.15, 1.03, pz),
				Color3.fromRGB(30, 34, 44),
				Enum.Material.SmoothPlastic
			)
		)
		ring.Transparency = 0.2
		local vote = prompt(pad, "Vote", "Map", "MapVotePrompt", 7)
		vote.Enabled = false
		vote:SetAttribute("Slot", i)
		table.insert(slots, { label = label, prompt = vote })
	end
	-- floating side shelves with cube lamps, pictures above, plants on the floor
	for _, side in { -1, 1 } do
		local x = side * 13.5
		piece(room, "SideShelf", Vector3.new(5, 0.4, 1.6), at(x, 8, z + 0.8), C.shelf, Enum.Material.Wood)
		local cube = deco(
			piece(
				room,
				"CubeLamp",
				Vector3.new(1.1, 1.1, 1.1),
				at(x - side * 1.5, 8.75, z + 0.9),
				C.warm,
				Enum.Material.Neon
			)
		)
		cube.Transparency = 0.1
		softLight(cube, 16, 0.9, C.warm).Name = "LampLight"
		picture(
			room,
			at(x, 12, z + 0.15),
			SOUTH,
			Vector2.new(2.6, 3.4),
			if side < 0 then lighthouseScene else hallwayScene
		)
		pottedPlant(room, at(x - side * 0.5, 1, z + 2.5), 4, rng)
	end
	return slots
end

-- The front door (the deploy door): warm wood with frosted glass slits, a lever handle, a red EXIT
-- sign above it, the hallway beyond full of lavender fog. Returns the countdown display.
local function frontDoor(room: Model): TextLabel
	local z = -D / 2
	local door = Instance.new("Model")
	door.Name = "DeployDoor"
	door.Parent = room
	for _, f in
		{
			{ Vector3.new(0.6, 10.3, 2.2), at(-23.2, 6.15, z) },
			{ Vector3.new(0.6, 10.3, 2.2), at(-16.8, 6.15, z) },
			{ Vector3.new(7, 0.6, 2.2), at(-20, 11.3, z) },
		}
	do
		piece(room, "DoorFrame", f[1], f[2], Color3.fromRGB(120, 112, 104), Enum.Material.Concrete)
	end
	piece(
		door,
		"DoorPanel",
		Vector3.new(6, 10, 0.5),
		at(-20, 6, z + 0.4),
		Color3.fromRGB(150, 88, 50),
		Enum.Material.WoodPlanks
	)
	for _, y in { 3, 5.2, 7.4, 9.6 } do
		local slit = piece(
			door,
			"DoorGlass",
			Vector3.new(3.6, 0.9, 0.12),
			at(-20.4, y, z + 0.7),
			Color3.fromRGB(200, 196, 186),
			Enum.Material.Glass
		)
		slit.Transparency = 0.3
	end
	-- the lever handle (the client turns it: someone outside trying the door)
	local handle = Instance.new("Model")
	handle.Name = "DoorWheel"
	handle.Parent = door
	local hub = at(-17.9, 6, z + 0.85)
	local hubPart = Kit.cylinder(
		handle,
		"WheelHub",
		0.3,
		0.45,
		CFrame.new(hub) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(30, 30, 32),
		Enum.Material.Metal
	)
	Kit.part(
		handle,
		"Lever",
		Vector3.new(1.3, 0.22, 0.22),
		CFrame.new(hub + Vector3.new(-0.6, 0, 0.15)),
		Color3.fromRGB(30, 30, 32),
		Enum.Material.Metal
	)
	handle.PrimaryPart = hubPart
	-- DO NOT OPEN, sprayed across it
	sign(door, "DoorWarning", Vector2.new(5.4, 1.6), at(-20, 6.9, z + 0.72), SOUTH, "DO NOT OPEN", {
		text = Color3.fromRGB(200, 30, 36),
		font = Enum.Font.PermanentMarker,
	})
	-- beyond: the hallway, the fog
	piece(room, "DoorOutside", Vector3.new(6, 10, 1), at(-20, 6, z - 4), C.black)
	local fog = deco(
		piece(room, "DoorFog", Vector3.new(5.6, 9.6, 2.4), at(-20, 6, z - 2), C.lavender, Enum.Material.Neon)
	)
	fog.Transparency = 0.55
	fog.CastShadow = false
	local fogLight = softLight(fog, 26, 2.2, C.lavender)
	fogLight.Name = "FogLight"
	fogLight.Enabled = false
	local vaporAt = deco(piece(room, "DoorVapor", Vector3.new(5, 1, 1), at(-20, 4, z + 2), C.black))
	vaporAt.Transparency = 1
	local vapor = Instance.new("ParticleEmitter")
	vapor.Name = "Vapor"
	vapor.Enabled = false
	vapor.Rate = 10
	vapor.Lifetime = NumberRange.new(2, 3)
	vapor.Speed = NumberRange.new(1, 2.5)
	vapor.EmissionDirection = Enum.NormalId.Back
	vapor.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4) })
	vapor.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
	vapor.Color = ColorSequence.new(Color3.fromRGB(210, 205, 230))
	vapor.Texture = "rbxasset://textures/particles/smoke_main.dds"
	vapor.Parent = vaporAt
	-- the red EXIT sign: the room's beacon
	local exit = deco(
		piece(
			room,
			"DoorBulb",
			Vector3.new(2.6, 1, 0.3),
			at(-20, 14.6, z + 1.2),
			Color3.fromRGB(60, 10, 12),
			Enum.Material.SmoothPlastic
		)
	)
	softLight(exit, 14, 1.4, C.danger)
	sign(room, "ExitText", Vector2.new(2.4, 0.8), at(-20, 14.6, z + 1.4), SOUTH, "EXIT", {
		text = C.danger,
		font = Enum.Font.GothamBlack,
		glow = true,
	})
	-- the countdown display over the door
	return sign(
		room,
		"ModeSign",
		Vector2.new(8, 1.5),
		at(-20, 12.8, z + 1.15),
		SOUTH,
		"WAITING FOR PLAYERS",
		{
			text = Color3.fromRGB(255, 70, 70),
			board = Color3.fromRGB(14, 12, 14),
			font = Enum.Font.Code,
			glow = true,
		}
	)
end

-- The MISSING posters on a corkboard left of the door.
local function missingPosters(room: Model): { Poster }
	local zWall = -D / 2 + 1.15
	piece(
		room,
		"Corkboard",
		Vector3.new(6.6, 7, 0.3),
		at(-27.5, 8, zWall - 0.1),
		Color3.fromRGB(116, 88, 60),
		Enum.Material.Cardboard
	)
	local posters = {}
	for i = 0, 3 do
		local col, row = i % 2, math.floor(i / 2)
		local pos = at(-29 + col * 3, 9.7 - row * 3.3, zWall + 0.1)
		local paper = deco(
			Kit.part(
				room,
				"Poster",
				Vector3.new(2.7, 3, 0.08),
				CFrame.lookAt(pos, pos + SOUTH) * CFrame.Angles(0, 0, (col - 0.5) * 0.06),
				C.paper
			)
		)
		local gui = surface(paper, 50, 0.8)
		local header = Instance.new("TextLabel")
		header.BackgroundTransparency = 1
		header.Size = UDim2.fromScale(1, 0.2)
		header.Font = Enum.Font.SpecialElite
		header.TextScaled = true
		header.TextColor3 = Color3.fromRGB(150, 20, 24)
		header.Text = "MISSING"
		header.Parent = gui
		local face = Instance.new("ImageLabel")
		face.Name = "Face"
		face.BackgroundColor3 = Color3.fromRGB(150, 144, 130)
		face.BorderSizePixel = 0
		face.Position = UDim2.fromScale(0.2, 0.22)
		face.Size = UDim2.fromScale(0.6, 0.56)
		face.ImageColor3 = Color3.fromRGB(200, 196, 186)
		face.Parent = gui
		local name = Instance.new("TextLabel")
		name.Name = "Name"
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromScale(0.05, 0.8)
		name.Size = UDim2.fromScale(0.9, 0.18)
		name.Font = Enum.Font.SpecialElite
		name.TextScaled = true
		name.TextColor3 = C.ink
		name.Text = "HAVE YOU SEEN ME?"
		name.Parent = gui
		table.insert(posters, { face = face, name = name })
	end
	return posters
end

--------------------------------------------------------------------------- the living room

-- One run of the sectional: base, seat cushions with rounded fronts, leaning back cushions.
-- `cf` stands at the floor in the middle of the run, looking where people sitting look.
local function sofaRun(room: Model, cf: CFrame, length: number)
	Kit.part(
		room,
		"SofaBase",
		Vector3.new(length, 1.4, 4.6),
		cf * CFrame.new(0, 0.9, 0),
		C.fabricDark,
		Enum.Material.Fabric
	)
	Kit.part(
		room,
		"SofaBack",
		Vector3.new(length, 2.4, 1),
		cf * CFrame.new(0, 2.6, 1.8),
		C.fabricDark,
		Enum.Material.Fabric
	)
	local n = math.max(1, math.floor(length / 3.6))
	local w = length / n
	for i = 0, n - 1 do
		local x = -length / 2 + w / 2 + i * w
		Kit.part(
			room,
			"SeatCushion",
			Vector3.new(w - 0.15, 0.9, 3.4),
			cf * CFrame.new(x, 2.05, -0.4),
			C.fabric,
			Enum.Material.Fabric
		)
		Kit.cylinder(
			room,
			"CushionRoll",
			w - 0.15,
			0.9,
			cf * CFrame.new(x, 2.05, -2.1),
			C.fabric,
			Enum.Material.Fabric
		)
		Kit.part(
			room,
			"BackCushion",
			Vector3.new(w - 0.25, 2.6, 1.1),
			cf * CFrame.new(x, 3.6, 1.1) * CFrame.Angles(-0.18, 0, 0),
			C.fabric,
			Enum.Material.Fabric
		)
	end
end

-- A geometric pendant: a wire octahedron cage around a bare bulb, on a long cord.
local function pendant(room: Model, pos: Vector3, size: number, name: string, shadows: boolean)
	rod(
		room,
		"PendantCord",
		at(pos.X - BASE.X, H + 1, pos.Z - BASE.Z),
		pos + Vector3.new(0, size, 0),
		0.06,
		Color3.fromRGB(20, 20, 20)
	)
	local v = {
		pos + Vector3.new(0, size, 0),
		pos - Vector3.new(0, size, 0),
		pos + Vector3.new(size, 0, 0),
		pos - Vector3.new(size, 0, 0),
		pos + Vector3.new(0, 0, size),
		pos - Vector3.new(0, 0, size),
	}
	for _, e in
		{
			{ 1, 3 },
			{ 1, 4 },
			{ 1, 5 },
			{ 1, 6 },
			{ 2, 3 },
			{ 2, 4 },
			{ 2, 5 },
			{ 2, 6 },
			{ 3, 5 },
			{ 5, 4 },
			{ 4, 6 },
			{ 6, 3 },
		}
	do
		rod(room, "PendantCage", v[e[1]], v[e[2]], 0.08, Color3.fromRGB(150, 116, 60))
	end
	local bulb = deco(piece(room, name, Vector3.new(0.5, 0.5, 0.5), pos, C.warm, Enum.Material.Neon))
	bulb.Shape = Enum.PartType.Ball
	local light = Kit.light(bulb, 30, if shadows then 1.8 else 0.9, C.warm)
	light.Shadows = shadows
	light.Name = if shadows then "BulbLight" else "PendantLight"
end

local function livingRoom(room: Model, rng: Random)
	-- the shag rug
	deco(piece(room, "Rug", Vector3.new(30, 0.12, 24), at(-3, 1.06, 2), C.rug, Enum.Material.Carpet))
	-- the L-sectional: the long run faces the TV, the short run faces east, a corner joins them
	sofaRun(room, CFrame.lookAt(at(-3, 1, 11.3), at(-3, 1, 0)), 24)
	sofaRun(room, CFrame.lookAt(at(-17.3, 1, 1.4), at(0, 1, 1.4)), 14.4)
	piece(
		room,
		"SofaCorner",
		Vector3.new(4.6, 2.5, 4.6),
		at(-17.3, 2.25, 11.3),
		C.fabric,
		Enum.Material.Fabric
	)
	piece(room, "SofaArm", Vector3.new(1, 2.8, 4.6), at(9.5, 2.4, 11.3), C.fabricDark, Enum.Material.Fabric)
	piece(room, "SofaArm", Vector3.new(4.6, 2.8, 1), at(-17.3, 2.4, -6.3), C.fabricDark, Enum.Material.Fabric)
	-- a throw blanket and a couple of pillows left where people slept
	deco(
		Kit.part(
			room,
			"Throw",
			Vector3.new(5, 0.25, 3.2),
			CFrame.new(at(-8, 3.2, 10)) * CFrame.Angles(0, 0.2, 0.05),
			Color3.fromRGB(120, 70, 56),
			Enum.Material.Fabric
		)
	)
	for _, p in { at(2, 3.4, 11.5), at(-16.8, 3.4, -2) } do
		Kit.part(
			room,
			"Pillow",
			Vector3.new(2, 1.6, 0.7),
			CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0),
			Color3.fromRGB(150, 120, 90),
			Enum.Material.Fabric
		)
	end
	-- the leather ottoman with a red wood tray, glowing softly underneath
	piece(room, "Ottoman", Vector3.new(9, 2.2, 7), at(-3, 2.2, 1), C.leather, Enum.Material.Leather)
	local under = deco(
		piece(room, "OttomanGlow", Vector3.new(8.4, 0.1, 6.4), at(-3, 1.12, 1), C.led, Enum.Material.Neon)
	)
	under.Transparency = 0.5
	piece(
		room,
		"Tray",
		Vector3.new(7, 0.3, 5),
		at(-3, 3.45, 1),
		Color3.fromRGB(120, 40, 28),
		Enum.Material.Wood
	)
	piece(
		room,
		"TrayInset",
		Vector3.new(6.2, 0.1, 4.2),
		at(-3, 3.62, 1),
		Color3.fromRGB(90, 30, 22),
		Enum.Material.Wood
	)
	piece(
		room,
		"Remote",
		Vector3.new(0.5, 0.15, 2),
		at(-4.6, 3.75, 1.4),
		Color3.fromRGB(20, 20, 22),
		Enum.Material.SmoothPlastic
	)
	for i, p in { at(-1.4, 3.7, 0), at(-0.6, 3.7, 0.4), at(-2.2, 3.7, 2.4) } do
		upright(
			"Candle",
			room,
			0.6,
			0.35,
			p + Vector3.new(0, 0.3, 0),
			Color3.fromRGB(214, 204, 180),
			Enum.Material.SmoothPlastic
		)
		local flame = deco(
			piece(
				room,
				"CandleFlame",
				Vector3.new(0.15, 0.3, 0.15),
				p + Vector3.new(0, 0.75, 0),
				C.ember,
				Enum.Material.Neon
			)
		)
		if i <= 2 then
			softLight(flame, 8, 0.5, C.ember).Name = "CandleLight"
		end
	end
	-- three geometric pendants over the ottoman (the middle one is the room's main light)
	pendant(room, at(-6, 12.2, -1), 1, "PendantBulb", false)
	pendant(room, at(-3, 10.6, 2), 1.1, "HearthBulb", true)
	pendant(room, at(0.5, 11.6, -0.5), 0.9, "PendantBulb", false)
	-- the bean bag by the TV, a teddy bear slumped on it with one button eye
	local bag = piece(
		room,
		"BeanBag",
		Vector3.new(4.4, 3, 4.4),
		at(12.5, 2.4, -15.5),
		Color3.fromRGB(120, 76, 44),
		Enum.Material.Fabric
	)
	bag.Shape = Enum.PartType.Ball
	local bear = Color3.fromRGB(150, 110, 72)
	deco(piece(room, "Teddy", Vector3.new(1.4, 1.6, 1.2), at(12.3, 4.4, -15.3), bear, Enum.Material.Fabric)).Shape =
		Enum.PartType.Ball
	deco(
		piece(room, "TeddyHead", Vector3.new(1.1, 1.1, 1.1), at(12.5, 5.5, -15.5), bear, Enum.Material.Fabric)
	).Shape =
		Enum.PartType.Ball
	deco(
		piece(
			room,
			"TeddyEye",
			Vector3.new(0.18, 0.18, 0.1),
			at(12.25, 5.6, -14.98),
			Color3.fromRGB(10, 10, 10)
		)
	)
	-- a tall plant by the window, dying
	pottedPlant(room, at(-27, 1, 20), 6, rng)
	pottedPlant(room, at(27, 1, 20), 5, rng)
end

--------------------------------------------------------------------------- west: shelves, painting, jars, mirror

local JAR_LOOK = {
	Runner = Vector3.new(0.35, 1.5, 0.3),
	Tank = Vector3.new(0.8, 1.2, 0.5),
	Screamer = Vector3.new(0.5, 1.35, 0.35),
}

local function westWall(room: Model)
	local x = -W / 2 + 1
	-- floating shelves with lamps and things
	for _, y in { 6, 10 } do
		piece(room, "WallShelf", Vector3.new(1.6, 0.4, 10), at(x + 0.8, y, -16), C.shelf, Enum.Material.Wood)
	end
	local lamp = deco(
		piece(room, "CubeLamp", Vector3.new(1, 1, 1), at(x + 0.8, 10.7, -19.5), C.warm, Enum.Material.Neon)
	)
	softLight(lamp, 16, 0.9, C.warm).Name = "LampLight"
	local lamp2 = deco(
		piece(room, "CubeLamp", Vector3.new(1, 1, 1), at(x + 0.8, 6.7, -12.5), C.warm, Enum.Material.Neon)
	)
	softLight(lamp2, 14, 0.8, C.warm).Name = "LampLight"
	for i = 0, 5 do
		piece(
			room,
			"Book",
			Vector3.new(1.2, 1.4, 0.35),
			at(x + 0.8, 6.9, -18 + i * 0.4),
			Color3.fromHSV(0.02 + i * 0.12, 0.45, 0.35),
			Enum.Material.SmoothPlastic
		)
	end
	upright("Vase", room, 1.6, 0.8, at(x + 0.8, 11, -14), Color3.fromRGB(40, 40, 44), Enum.Material.Glass)
	-- the big painting
	picture(room, at(x + 0.15, 9, -5), EAST, Vector2.new(6, 6.6), hallwayScene)
	-- the specimen jars on their shelf: the private Alpha pick
	piece(room, "JarShelf", Vector3.new(2.2, 0.4, 15), at(x + 1.1, 4.6, 6), C.shelf, Enum.Material.Wood)
	for i, className in AlphaClasses.order do
		local class = (AlphaClasses :: any)[className]
		local z = -0.5 + (i - 1) * 6.5
		local base = at(x + 1.1, 4.8, z)
		local jar = upright(
			"Jar",
			room,
			2.8,
			1.8,
			base + Vector3.new(0, 1.4, 0),
			Color3.fromRGB(90, 120, 104),
			Enum.Material.Glass
		)
		jar.Transparency = 0.35
		local liquid = deco(
			upright("JarLiquid", room, 2.2, 1.6, base + Vector3.new(0, 1.15, 0), Color3.fromRGB(52, 78, 60))
		)
		liquid.Transparency = 0.25
		upright(
			"JarLid",
			room,
			0.3,
			1.9,
			base + Vector3.new(0, 2.95, 0),
			Color3.fromRGB(80, 80, 84),
			Enum.Material.Metal
		)
		deco(
			piece(
				room,
				"JarShape",
				JAR_LOOK[className] or JAR_LOOK.Screamer,
				base + Vector3.new(0, 1.2, 0),
				Color3.fromRGB(14, 18, 14)
			)
		)
		local glow = deco(
			piece(
				room,
				"JarGlow",
				Vector3.new(0.3, 0.3, 0.3),
				base + Vector3.new(0, 0.4, 0),
				C.jar,
				Enum.Material.Neon
			)
		)
		glow.Transparency = 0.6
		softLight(glow, 5, 0.25, C.jar).Name = "JarLight"
		sign(room, "JarLabel", Vector2.new(1.9, 0.6), at(x + 2.25, 4.2, z), EAST, string.upper(class.name), {
			text = C.ink,
			board = C.paper,
			font = Enum.Font.SpecialElite,
		})
		local pick = prompt(jar, "Choose your nightmare", class.name, "AlphaPickPrompt", 6)
		pick:SetAttribute("Class", className)
	end
	-- the days, scratched on the concrete above the jars
	sign(room, "Graffiti", Vector2.new(7, 2.6), at(x + 0.1, 12.6, 6), EAST, "DAY 47\n||||/ ||||/ ||||/ ||", {
		text = Color3.fromRGB(214, 208, 196),
		font = Enum.Font.PermanentMarker,
	})
	-- the wardrobe mirror (the character catalog)
	piece(room, "Wardrobe", Vector3.new(2.4, 11, 6), at(x + 1.2, 6.5, 17.5), C.shelf, Enum.Material.Wood)
	local mirror = piece(
		room,
		"Mirror",
		Vector3.new(0.15, 9.4, 4.6),
		at(x + 2.45, 6.6, 17.5),
		Color3.fromRGB(176, 182, 190),
		Enum.Material.Glass
	)
	mirror.Reflectance = 0.4
	prompt(mirror, "Look in the mirror", "Catalog", "CatalogPrompt", 9)
	for _, crack in { { 0.6, 0.5 }, { -0.9, -0.3 } } do
		deco(
			Kit.part(
				room,
				"Crack",
				Vector3.new(0.05, 3, 0.08),
				CFrame.new(at(x + 2.55, 7 + crack[1], 17.5 + crack[2])) * CFrame.Angles(crack[2], 0, 0),
				Color3.fromRGB(30, 30, 34)
			)
		)
	end
end

--------------------------------------------------------------------------- north-east: the kitchen (the shop)

local function kitchen(room: Model)
	local x1 = W / 2 - 1
	local stone = Color3.fromRGB(40, 38, 40)
	-- the back counter, upper cabinets, the under-cabinet light that stutters
	piece(
		room,
		"Counter",
		Vector3.new(3, 3.6, 18),
		at(x1 - 1.5, 2.8, -13),
		Color3.fromRGB(56, 40, 32),
		Enum.Material.Wood
	)
	piece(room, "Worktop", Vector3.new(3.2, 0.3, 18.2), at(x1 - 1.5, 4.75, -13), stone, Enum.Material.Marble)
	piece(
		room,
		"Cabinets",
		Vector3.new(1.8, 4, 18),
		at(x1 - 0.9, 12, -13),
		Color3.fromRGB(56, 40, 32),
		Enum.Material.Wood
	)
	local tube = deco(
		piece(
			room,
			"ShopTube",
			Vector3.new(0.2, 0.2, 16),
			at(x1 - 1.9, 9.85, -13),
			C.sick,
			Enum.Material.Neon
		)
	)
	softLight(tube, 14, 1, C.sick)
	piece(
		room,
		"Fridge",
		Vector3.new(3.2, 9, 3.2),
		at(x1 - 1.6, 5.5, -2.2),
		Color3.fromRGB(150, 150, 150),
		Enum.Material.Metal
	)
	sign(
		room,
		"SurvivalRules",
		Vector2.new(2.4, 3.4),
		at(x1 - 3.25, 7, -2.2),
		WEST,
		"RULES\n1. STAY QUIET\n2. NEVER ALONE\n3. CHECK FOR BITES\n4. AIM FOR THE HEAD",
		{
			text = C.ink,
			board = C.paper,
			font = Enum.Font.SpecialElite,
		}
	)
	-- what's left to eat: cans, water, a flashlight, a radio
	for i = 0, 5 do
		upright(
			"Can",
			room,
			0.8,
			0.6,
			at(x1 - 1.6, 5.3, -20 + i * 0.75),
			Color3.fromRGB(150, 140, 120),
			Enum.Material.Metal
		)
	end
	for _, z in { -8.5, -7.2 } do
		local jug = upright(
			"WaterJug",
			room,
			2.2,
			1.2,
			at(x1 - 1.6, 6, z),
			Color3.fromRGB(110, 160, 200),
			Enum.Material.Glass
		)
		jug.Transparency = 0.35
	end
	-- the island: the Z-Shop. Ring the bell.
	piece(
		room,
		"Island",
		Vector3.new(3.4, 3.6, 10),
		at(24, 2.8, -13),
		Color3.fromRGB(56, 40, 32),
		Enum.Material.Wood
	)
	piece(room, "IslandTop", Vector3.new(4, 0.3, 10.6), at(24, 4.75, -13), stone, Enum.Material.Marble)
	local bell = upright(
		"ShopBell",
		room,
		0.5,
		1,
		at(24, 5.15, -11),
		Color3.fromRGB(196, 150, 60),
		Enum.Material.Metal
	)
	prompt(bell, "Ring the bell", "Z-Shop", "ShopPrompt", 8)
	piece(
		room,
		"SupplyBox",
		Vector3.new(2.2, 1.4, 1.6),
		at(24, 5.6, -15),
		Color3.fromRGB(84, 90, 60),
		Enum.Material.Metal
	)
	sign(room, "ShopSign", Vector2.new(5, 1.4), at(x1 - 1.85, 12, -13), WEST, "Z-SHOP", {
		text = Color3.fromRGB(255, 210, 140),
		board = Color3.fromRGB(26, 20, 18),
		font = Enum.Font.SpecialElite,
		glow = true,
	})
	for _, z in { -16.5, -13, -9.5 } do
		upright("StoolSeat", room, 0.4, 1.6, at(21, 4, z), C.leather, Enum.Material.Leather)
		upright("StoolLeg", room, 3, 0.3, at(21, 2.5, z), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
	end
	-- two small pendants over the island
	for _, z in { -15.5, -10.5 } do
		rod(room, "IslandCord", at(24, H + 1, z), at(24, 10.5, z), 0.06, Color3.fromRGB(20, 20, 20))
		local shade = deco(
			upright(
				"IslandLamp",
				room,
				0.8,
				1.2,
				at(24, 10.2, z),
				Color3.fromRGB(30, 30, 32),
				Enum.Material.Metal
			)
		)
		softLight(shade, 12, 0.7, C.warm).Name = "PendantLight"
	end
end

--------------------------------------------------------------------------- outside: windows, balcony, the city

-- One stretch of window: tinted glass, a few boards nailed across the bottom, tape crosses,
-- handprints. `along` runs along the glass, `inward` points into the room.
local function windowBay(
	room: Model,
	name: string,
	from: Vector3,
	along: Vector3,
	length: number,
	inward: Vector3,
	rng: Random
): Model
	local bay = Instance.new("Model")
	bay.Name = name
	bay.Parent = room
	local mid = from + along * (length / 2)
	local look = CFrame.lookAt(mid, mid + inward)
	local glass = Kit.part(
		bay,
		"Glass",
		Vector3.new(length, H - 2, 0.3),
		look * CFrame.new(0, (H - 2) / 2 + 1.5 - (mid.Y - BASE.Y), 0),
		C.glass,
		Enum.Material.Glass
	)
	glass.Transparency = 0.6
	glass.CastShadow = false
	-- boards across the lower part
	for i, y in { 3.2, 4.6, 6 } do
		local board = Kit.part(
			bay,
			"Board",
			Vector3.new(length * 0.55, 0.7, 0.3),
			look
				* CFrame.new(rng:NextNumber(-3, 3), y - (mid.Y - BASE.Y), -1)
				* CFrame.Angles(0, 0, rng:NextNumber(-0.05, 0.05) * i),
			Color3.fromRGB(110, 90, 66),
			Enum.Material.WoodPlanks
		)
		board.CastShadow = true
	end
	local puff = Instance.new("ParticleEmitter")
	puff.Name = "BangDust"
	puff.Enabled = false
	puff.Lifetime = NumberRange.new(1, 2)
	puff.Speed = NumberRange.new(1, 3)
	puff.SpreadAngle = Vector2.new(60, 60)
	puff.Acceleration = Vector3.new(0, -4, 0)
	puff.EmissionDirection = Enum.NormalId.Front
	puff.Size = NumberSequence.new(0.25)
	puff.Color = ColorSequence.new(Color3.fromRGB(120, 112, 100))
	puff.Parent = bay:FindFirstChild("Board")
	-- tape crosses on two panes, a bloody handprint, cracks
	for _, offset in { -length * 0.3, length * 0.2 } do
		for _, a in { 0.7, -0.7 } do
			deco(
				Kit.part(
					bay,
					"Tape",
					Vector3.new(9, 0.35, 0.05),
					look * CFrame.new(offset, 11 - (mid.Y - BASE.Y), -0.2) * CFrame.Angles(0, 0, a),
					Color3.fromRGB(196, 184, 150)
				)
			)
		end
	end
	for _, h in { { -length * 0.1, 8.5 }, { -length * 0.08 + 0.8, 7.7 } } do
		local print = deco(
			Kit.part(
				bay,
				"Handprint",
				Vector3.new(0.9, 1.1, 0.04),
				look * CFrame.new(h[1], h[2] - (mid.Y - BASE.Y), -0.2),
				C.blood
			)
		)
		print.Transparency = 0.25
	end
	-- the things a scare shows: a hand on the glass outside, eyes
	local hand = deco(
		Kit.part(
			bay,
			"ScareHand",
			Vector3.new(1.1, 1.5, 0.3),
			look * CFrame.new(length * 0.15, 8 - (mid.Y - BASE.Y), 0.5),
			Color3.fromRGB(70, 78, 66)
		)
	)
	hand.Transparency = 1
	for _, dx in { -0.4, 0.4 } do
		local eye = deco(
			Kit.part(
				bay,
				"ScareEye",
				Vector3.new(0.25, 0.14, 0.05),
				look * CFrame.new(-length * 0.25 + dx, 9 - (mid.Y - BASE.Y), 1.2),
				Color3.fromRGB(226, 232, 206),
				Enum.Material.Neon
			)
		)
		eye.Transparency = 1
	end
	-- moonlight falling in through the glass (the boards cut stripes into it)
	local source = mid + -inward * 22 + UP * 22
	local moon = deco(
		Kit.part(
			bay,
			"Moonbeam",
			Vector3.new(1, 1, 1),
			CFrame.lookAt(source, mid + inward * 12 - UP * 8),
			C.black
		)
	)
	moon.Transparency = 1
	local beam = Instance.new("SpotLight")
	beam.Name = "MoonLight"
	beam.Face = Enum.NormalId.Front
	beam.Angle = 35
	beam.Range = 60
	beam.Brightness = 1.8
	beam.Color = C.lavender
	beam.Shadows = true
	beam.Parent = moon
	local motes = deco(
		Kit.part(
			bay,
			"Motes",
			Vector3.new(length * 0.6, 8, 6),
			look * CFrame.new(0, 6 - (mid.Y - BASE.Y), -5),
			C.black
		)
	)
	motes.Transparency = 1
	local dust = Instance.new("ParticleEmitter")
	dust.Shape = Enum.ParticleEmitterShape.Box
	dust.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	dust.Rate = 4
	dust.Lifetime = NumberRange.new(6, 9)
	dust.Speed = NumberRange.new(0.1, 0.3)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Size = NumberSequence.new(0.06)
	dust.Transparency = NumberSequence.new(0.4)
	dust.LightInfluence = 1
	dust.Parent = motes
	return bay
end

-- The balcony outside the south windows, where something stands some nights.
local function balcony(room: Model)
	piece(room, "Balcony", Vector3.new(W, 1, 9), at(0, 0.5, D / 2 + 5.5), C.concrete, Enum.Material.Concrete)
	local rail = piece(
		room,
		"BalconyGlass",
		Vector3.new(W, 3.4, 0.2),
		at(0, 2.7, D / 2 + 9.9),
		C.glass,
		Enum.Material.Glass
	)
	rail.Transparency = 0.6
	rail.CastShadow = false
	piece(
		room,
		"BalconyRail",
		Vector3.new(W, 0.3, 0.4),
		at(0, 4.5, D / 2 + 9.9),
		C.frame,
		Enum.Material.Metal
	)
	-- the Tall One: very tall, very thin, outside the left windows (hidden until it isn't)
	local tall = Instance.new("Model")
	tall.Name = "TallOne"
	tall.Parent = room
	for _, part in
		{
			{ Vector3.new(0.9, 9, 0.7), at(-14.6, 5.5, D / 2 + 5) },
			{ Vector3.new(0.9, 9, 0.7), at(-13.4, 5.5, D / 2 + 5) },
			{ Vector3.new(2.2, 7, 1), at(-14, 13.5, D / 2 + 5) },
			{ Vector3.new(1.2, 1.6, 1.2), at(-14, 18, D / 2 + 5) },
		}
	do
		local p = deco(piece(tall, "TallPart", part[1], part[2], C.black))
		p.Transparency = 1
	end
	-- DON'T GO OUT, written on the glass from the inside
	sign(room, "GlassWriting", Vector2.new(9, 2.6), at(12, 9, D / 2 - 0.25), NORTH, "DON'T GO OUT", {
		text = Color3.fromRGB(176, 24, 30),
		font = Enum.Font.PermanentMarker,
	})
end

-- The dead city in the fog: dark towers with a few lit windows, a red warning light, fires and
-- smoke, and a dark floor of fog far below that hides everything under it.
local function skyline(room: Model, rng: Random)
	local city = Instance.new("Model")
	city.Name = "Skyline"
	city.Parent = room
	piece(
		city,
		"FogFloor",
		Vector3.new(1200, 2, 1200),
		at(0, -70, 0),
		Color3.fromRGB(22, 20, 28),
		Enum.Material.SmoothPlastic
	)
	local spots = {}
	for _ = 1, 16 do
		table.insert(spots, Vector3.new(rng:NextNumber(-220, 220), 0, rng:NextNumber(70, 230))) -- south
	end
	for _ = 1, 10 do
		table.insert(spots, Vector3.new(rng:NextNumber(70, 230), 0, rng:NextNumber(-160, 60))) -- east
	end
	local tallest: Vector3? = nil
	for i, s in spots do
		local w, d = rng:NextNumber(18, 34), rng:NextNumber(18, 34)
		local top = rng:NextNumber(-20, 90)
		local height = top + 75
		local centre = at(s.X, top - height / 2, s.Z)
		piece(
			city,
			"Tower",
			Vector3.new(w, height, d),
			centre,
			Color3.fromRGB(30, 30, 38):Lerp(Color3.fromRGB(44, 42, 50), rng:NextNumber(0, 1)),
			Enum.Material.Concrete
		)
		-- a few lit windows on the face toward the apartment
		local towards = if math.abs(s.X) > math.abs(s.Z) and s.X > 60 then WEST else NORTH
		for _ = 1, rng:NextInteger(2, 9) do
			local u = rng:NextNumber(-0.42, 0.42) * (if towards == NORTH then w else d)
			local y = top - rng:NextNumber(2, 60)
			local face = if towards == NORTH
				then Vector3.new(s.X + u, y, s.Z - d / 2 - 0.1)
				else Vector3.new(s.X - w / 2 - 0.1, y, s.Z + u)
			local roll = rng:NextNumber()
			local color = if roll < 0.1
				then Color3.fromRGB(200, 40, 40)
				elseif roll < 0.4 then Color3.fromRGB(170, 190, 230)
				else Color3.fromRGB(255, 196, 120)
			deco(
				piece(
					city,
					"LitWindow",
					if towards == NORTH then Vector3.new(1.4, 1.8, 0.1) else Vector3.new(0.1, 1.8, 1.4),
					BASE + face,
					color,
					Enum.Material.Neon
				)
			)
		end
		if not tallest or top > tallest.Y then
			tallest = Vector3.new(s.X, top, s.Z)
		end
		-- two of the towers are burning
		if i == 3 or i == 18 then
			local fireAt = deco(
				piece(
					city,
					"CityFire",
					Vector3.new(6, 2, 6),
					at(s.X, top + 1, s.Z),
					Color3.fromRGB(255, 100, 30),
					Enum.Material.Neon
				)
			)
			fireAt.Transparency = 0.3
			local flames = Instance.new("Fire")
			flames.Size = 18
			flames.Heat = 20
			flames.Parent = fireAt
			local smoke = Instance.new("Smoke")
			smoke.Color = Color3.fromRGB(30, 28, 30)
			smoke.Size = 30
			smoke.Opacity = 0.4
			smoke.RiseVelocity = 8
			smoke.Parent = fireAt
			softLight(fireAt, 60, 2, Color3.fromRGB(255, 120, 50))
		end
	end
	-- the aircraft warning light on the tallest tower, blinking red
	if tallest then
		local red = deco(
			piece(
				city,
				"WarningLight",
				Vector3.new(1.2, 1.2, 1.2),
				at(tallest.X, tallest.Y + 1, tallest.Z),
				C.danger,
				Enum.Material.Neon
			)
		)
		Kit.light(red, 30, 2, C.danger, true).Shadows = false
	end
end

local function spawnPoint(room: Model)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0 -- no forcefield
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.lookAt(at(-20, 1.5, -15), at(-3, 1.5, 2)) -- just inside the door, facing the room
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
	local rng = Random.new(12)
	shell(room)
	local slots = tvWall(room, rng)
	local modeLabel = frontDoor(room)
	local posters = missingPosters(room)
	livingRoom(room, rng)
	westWall(room)
	kitchen(room)
	windowBay(room, "Window1", at(-W / 2, 1, D / 2 - 0.6), EAST, W, NORTH, rng)
	windowBay(room, "Window2", at(W / 2 - 0.6, 1, 0), SOUTH, D / 2, WEST, rng)
	balcony(room)
	skyline(room, rng)
	spawnPoint(room)
	return { mapSlots = slots, modeLabel = modeLabel, posters = posters }
end

return Safehouse
