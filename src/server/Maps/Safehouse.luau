--!strict
-- THE SAFEHOUSE: the basement of Relay Station 9, the old radio station that ran the towers
-- (design-safehouse.md). "The last lit room in a town that went dark." 64 x 48 studs, a low
-- 16-stud ceiling. The center is warm (an oil-drum fire, cots and sandbags under the one hanging
-- bulb); the edges are cold (boarded windows letting in lavender moonbeams, the stairwell climbing
-- into black, the deploy door with its red bulb).
--
--   N:  [stairs + spawn]  [map vote chalkboard + 3 pads]  [deploy door]
--   W:  [loadout pegboard + lockers]  [specimen jars: private Alpha pick]
--   C:  [the hearth]
--   E:  [shop cage + bell]  [mirror alcove: catalog]
--   S:  [radio desk, CRT, CCTV]  [boarded windows]  [MISSING posters]
--
-- Every station is a physical object with a prompt. The room is built here once; the client's
-- SafehouseController plays the scares and the countdown on its own copy (never replicated), and
-- finds what it animates by name (HearthBulb, DeployDoor, Window1/2, TallOne, ...).
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AlphaClasses = require(Shared.Config.AlphaClasses)
local Kit = require(script.Parent.Kit)
local BuildingKit = require(script.Parent.BuildingKit)
local Clutter = require(script.Parent.Clutter)

local Safehouse = {}

export type Poster = { face: ImageLabel, name: TextLabel }
-- Things on the walls that LobbyService updates.
export type Refs = {
	mapSlots: { { label: TextLabel, prompt: ProximityPrompt } },
	modeLabel: TextLabel,
	posters: { Poster },
}

local BASE = Vector3.new(0, 300, 0) -- the floor's top is BASE.Y + 1
local W, D, H = 64, 48, 16 -- inside faces of the walls: x +-31, z +-23; ceiling at y 17

local C = {
	concrete = Color3.fromRGB(56, 54, 58),
	waterLine = Color3.fromRGB(34, 32, 36),
	floor = Color3.fromRGB(46, 44, 48),
	ceiling = Color3.fromRGB(40, 38, 42),
	rust = Color3.fromRGB(104, 62, 42),
	metal = Color3.fromRGB(74, 76, 80),
	rotten = Color3.fromRGB(84, 82, 66), -- grey-green planks
	olive = Color3.fromRGB(70, 74, 50),
	dustyPurple = Color3.fromRGB(78, 60, 90),
	paper = Color3.fromRGB(206, 196, 172),
	ink = Color3.fromRGB(36, 26, 26),
	chalk = Color3.fromRGB(226, 226, 214),
	-- light colours: the only colour in the room
	butter = Color3.fromRGB(255, 224, 138),
	ember = Color3.fromRGB(255, 184, 107),
	lavender = Color3.fromRGB(191, 169, 242),
	danger = Color3.fromRGB(255, 74, 92),
	mint = Color3.fromRGB(205, 239, 217),
	signal = Color3.fromRGB(191, 216, 255),
	jar = Color3.fromRGB(163, 234, 200),
	black = Color3.fromRGB(4, 3, 7),
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

local function deco<T>(p: T): T
	local part = p :: any
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return p
end

-- A light that doesn't cast shadows (the design allows only 4 shadow casters).
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
			Vector3.new(size.X, size.Y, 0.2),
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
	label.Font = style.font or Enum.Font.SpecialElite
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

--------------------------------------------------------------------------- the room

-- Concrete box with the stairwell hole and the deploy door in the north wall and two basement
-- windows high in the south wall. Damp: a dark water line along the bottom of every wall.
local function shell(room: Model)
	piece(room, "Floor", Vector3.new(W, 2, D), BASE, C.floor, Enum.Material.Slate)
	piece(room, "Ceiling", Vector3.new(W, 1, D), at(0, H + 1.5, 0), C.ceiling, Enum.Material.Concrete)
	local function wall(size: Vector3, pos: Vector3)
		piece(room, "Wall", size, pos, C.concrete, Enum.Material.Concrete)
	end
	local top = H + 1
	-- north (z -24): stair hole x -30..-24 above y 8, door x 18..26 up to y 13
	local nz = -D / 2
	wall(Vector3.new(2, H, 2), at(-31, 1 + H / 2, nz))
	wall(Vector3.new(6, 7, 2), at(-27, 4.5, nz))
	wall(Vector3.new(42, H, 2), at(-3, 1 + H / 2, nz))
	wall(Vector3.new(8, top - 13, 2), at(22, 13 + (top - 13) / 2, nz))
	wall(Vector3.new(6, H, 2), at(29, 1 + H / 2, nz))
	-- south (z 24): windows x -9..-3 and 3..9, y 10..14
	local sz = D / 2
	wall(Vector3.new(23, H, 2), at(-20.5, 1 + H / 2, sz))
	wall(Vector3.new(6, H, 2), at(0, 1 + H / 2, sz))
	wall(Vector3.new(23, H, 2), at(20.5, 1 + H / 2, sz))
	for _, x in { -6, 6 } do
		wall(Vector3.new(6, 9, 2), at(x, 5.5, sz))
		wall(Vector3.new(6, top - 14, 2), at(x, 14 + (top - 14) / 2, sz))
	end
	wall(Vector3.new(2, H, D), at(W / 2, 1 + H / 2, 0))
	wall(Vector3.new(2, H, D), at(-W / 2, 1 + H / 2, 0))
	-- the water line
	for _, band in
		{
			{ Vector3.new(W - 2, 2.5, 0.2), at(0, 2.25, -D / 2 + 1.1) },
			{ Vector3.new(W - 2, 2.5, 0.2), at(0, 2.25, D / 2 - 1.1) },
			{ Vector3.new(0.2, 2.5, D - 2), at(W / 2 - 1.1, 2.25, 0) },
			{ Vector3.new(0.2, 2.5, D - 2), at(-W / 2 + 1.1, 2.25, 0) },
		}
	do
		deco(piece(room, "WaterLine", band[1], band[2], C.waterLine, Enum.Material.Concrete))
	end
	-- pipes and a cable tray under the ceiling
	for i, z in { -19, -17.6 } do
		Kit.cylinder(
			room,
			"Pipe",
			W - 2,
			0.8 - i * 0.15,
			CFrame.new(at(0, 15.6, z)),
			C.rust,
			Enum.Material.CorrodedMetal
		)
	end
	Kit.cylinder(
		room,
		"Pipe",
		D - 2,
		0.7,
		CFrame.new(at(-14, 15.9, 0)) * CFrame.Angles(0, math.rad(90), 0),
		C.metal,
		Enum.Material.Metal
	)
	deco(
		piece(
			room,
			"CableTray",
			Vector3.new(W - 4, 0.3, 1.4),
			at(0, 16.2, 9),
			C.metal,
			Enum.Material.DiamondPlate
		)
	)
	-- the old studded tiles around the hearth (the one nostalgic floor)
	local studs = piece(
		room,
		"HearthTiles",
		Vector3.new(20, 0.2, 16),
		at(0, 1.1, 2),
		Color3.fromRGB(64, 58, 54),
		Enum.Material.Plastic
	)
	studs.TopSurface = Enum.SurfaceType.Studs
	-- a slow leak from a pipe joint into a puddle
	Clutter.leak(room, at(-14, 15.4, -6), BASE.Y + 1, Random.new(5))
end

-- The stairwell in the north-west corner: steps climbing into pure black. You spawn at the bottom.
local function stairwell(room: Model)
	BuildingKit.stairs(room, at(-27, 1, -13), NORTH, 7, 5.6)
	piece(room, "StairVoid", Vector3.new(6, 10, 1), at(-27, 12.5, -25.5), C.black)
	deco(piece(room, "StairDark", Vector3.new(6, 9, 6), at(-27, 12.5, -21), C.black)).Transparency = 0.15
	Kit.part(
		room,
		"Handrail",
		Vector3.new(0.25, 0.25, 11),
		CFrame.new(at(-24.1, 7, -18)) * CFrame.Angles(math.atan(7 / 10.5), 0, 0),
		C.rust,
		Enum.Material.CorrodedMetal
	)
	-- scratched into the wall by the stairs: an old visitor counter
	sign(room, "VisitorCounter", Vector2.new(4, 1.4), at(-30.8, 5, -9), EAST, "VISITORS 000013", {
		text = Color3.fromRGB(150, 146, 140),
		font = Enum.Font.Arcade,
	})
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0 -- no forcefield
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.lookAt(at(-25, 1.5, -8), at(0, 1.5, 2)) -- facing the hearth
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Parent = room
	CollectionService:AddTag(spawn, "LobbySpawn")
end

--------------------------------------------------------------------------- north: vote + door

-- The map vote: a chalkboard with three map slots, a lantern over it, three chalk-outlined pads.
local function chalkboard(room: Model): { { label: TextLabel, prompt: ProximityPrompt } }
	local board = Instance.new("Model")
	board.Name = "VoteBoard"
	board.Parent = room
	local z = -D / 2 + 1
	piece(
		board,
		"Chalkboard",
		Vector3.new(18, 7, 0.3),
		at(0, 8.5, z + 0.2),
		Color3.fromRGB(30, 40, 34),
		Enum.Material.Slate
	)
	for _, f in
		{
			{ Vector3.new(18.8, 0.5, 0.5), at(0, 12.2, z + 0.4) },
			{ Vector3.new(18.8, 0.5, 0.5), at(0, 4.8, z + 0.4) },
			{ Vector3.new(0.5, 7.8, 0.5), at(-9.2, 8.5, z + 0.4) },
			{ Vector3.new(0.5, 7.8, 0.5), at(9.2, 8.5, z + 0.4) },
		}
	do
		piece(board, "BoardFrame", f[1], f[2], C.rotten, Enum.Material.Wood)
	end
	sign(board, "VoteHeader", Vector2.new(14, 1.4), at(0, 11.1, z + 0.45), SOUTH, "WHERE TONIGHT?", {
		text = C.chalk,
		font = Enum.Font.PermanentMarker,
	})
	local lantern = deco(
		piece(
			board,
			"BoardLantern",
			Vector3.new(0.9, 1.2, 0.9),
			at(0, 13.6, z + 1.4),
			C.butter,
			Enum.Material.Neon
		)
	)
	softLight(lantern, 12, 0.9, Color3.fromRGB(255, 199, 154))
	local slots = {}
	for i, x in { -6, 0, 6 } do
		local label = sign(board, `MapSlot{i}`, Vector2.new(5.4, 4.6), at(x, 7.6, z + 0.45), SOUTH, "", {
			text = C.chalk,
			font = Enum.Font.PermanentMarker,
		})
		-- the pad: a chalk square on the floor, faintly glowing
		local pz = -16
		for _, l in
			{
				{ at(x - 2.5, 1, pz - 2.5), at(x + 2.5, 1, pz - 2.5) },
				{ at(x - 2.5, 1, pz + 2.5), at(x + 2.5, 1, pz + 2.5) },
				{ at(x - 2.5, 1, pz - 2.5), at(x - 2.5, 1, pz + 2.5) },
				{ at(x + 2.5, 1, pz - 2.5), at(x + 2.5, 1, pz + 2.5) },
			}
		do
			BuildingKit.line(board, l[1], l[2], 0.25, C.chalk)
		end
		local pad = deco(
			piece(board, "VotePad", Vector3.new(5, 0.06, 5), at(x, 1.04, pz), C.butter, Enum.Material.Neon)
		)
		pad.Transparency = 0.85
		local vote = prompt(pad, "Vote", "Map", "MapVotePrompt", 7)
		vote.Enabled = false
		vote:SetAttribute("Slot", i)
		table.insert(slots, { label = label, prompt = vote })
	end
	return slots
end

-- The steel blast door in the north-east corner: wheel lock, red caged bulb, lavender fog behind.
-- Returns the countdown sign beside it.
local function deployDoor(room: Model): TextLabel
	local z = -D / 2
	local door = Instance.new("Model")
	door.Name = "DeployDoor"
	door.Parent = room
	for _, f in
		{
			{ Vector3.new(0.8, 12.6, 1.4), at(17.6, 7.3, z + 1) },
			{ Vector3.new(0.8, 12.6, 1.4), at(26.4, 7.3, z + 1) },
			{ Vector3.new(9.6, 0.8, 1.4), at(22, 13.2, z + 1) },
		}
	do
		piece(room, "DoorFrame", f[1], f[2], C.rust, Enum.Material.CorrodedMetal)
	end
	piece(
		door,
		"DoorPanel",
		Vector3.new(8, 12, 0.8),
		at(22, 7, z + 0.9),
		Color3.fromRGB(82, 74, 70),
		Enum.Material.DiamondPlate
	)
	for _, y in { 3, 11 } do
		piece(
			door,
			"DoorBand",
			Vector3.new(8, 0.6, 0.3),
			at(22, y, z + 1.4),
			C.rust,
			Enum.Material.CorrodedMetal
		)
	end
	-- the wheel lock (its own model so the client can turn it)
	local wheel = Instance.new("Model")
	wheel.Name = "DoorWheel"
	wheel.Parent = door
	local hub = at(22, 7, z + 1.6)
	local hubPart = Kit.cylinder(
		wheel,
		"WheelHub",
		0.6,
		0.8,
		CFrame.new(hub) * CFrame.Angles(0, math.rad(90), 0),
		C.metal,
		Enum.Material.Metal
	)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		Kit.part(
			wheel,
			"WheelRim",
			Vector3.new(1.2, 0.3, 0.3),
			CFrame.new(hub) * CFrame.Angles(0, 0, a) * CFrame.new(0, 1.45, 0),
			C.rust,
			Enum.Material.CorrodedMetal
		)
	end
	for _, a in { 0, math.pi / 2 } do
		Kit.part(
			wheel,
			"WheelSpoke",
			Vector3.new(2.9, 0.25, 0.25),
			CFrame.new(hub) * CFrame.Angles(0, 0, a),
			C.metal,
			Enum.Material.Metal
		)
	end
	wheel.PrimaryPart = hubPart
	-- behind the door: the night, lavender fog (seen only when it opens)
	piece(room, "DoorOutside", Vector3.new(8, 12, 1), at(22, 7, z - 3), C.black)
	local fog = deco(
		piece(
			room,
			"DoorFog",
			Vector3.new(7.6, 11.6, 2.2),
			at(22, 7, z - 1.4),
			C.lavender,
			Enum.Material.Neon
		)
	)
	fog.Transparency = 0.55
	fog.CastShadow = false
	local fogLight = softLight(fog, 26, 2.2, C.lavender)
	fogLight.Name = "FogLight"
	fogLight.Enabled = false
	-- cold breath at the door in the final seconds (the client turns it on)
	local vaporAt = deco(piece(room, "DoorVapor", Vector3.new(6, 1, 1), at(22, 5, z + 2.5), C.black))
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
	-- the red caged bulb: the room's beacon, like the towers' in a round
	local bulb = deco(
		piece(
			room,
			"DoorBulb",
			Vector3.new(0.9, 0.9, 0.9),
			at(22, 14.6, z + 1.6),
			C.danger,
			Enum.Material.Neon
		)
	)
	bulb.Shape = Enum.PartType.Ball
	softLight(bulb, 14, 1.4, C.danger)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2
		deco(
			piece(
				room,
				"BulbCage",
				Vector3.new(0.1, 1.3, 0.1),
				at(22 + math.cos(a) * 0.6, 14.6, z + 1.6 + math.sin(a) * 0.6),
				C.metal,
				Enum.Material.Metal
			)
		)
	end
	-- the countdown board beside it (a flip-clock look)
	return sign(room, "ModeSign", Vector2.new(9, 2), at(11, 13.6, z + 1.15), SOUTH, "WAITING FOR PLAYERS", {
		text = C.butter,
		board = Color3.fromRGB(16, 14, 18),
		font = Enum.Font.Code,
		glow = true,
	})
end

--------------------------------------------------------------------------- west: rack + jars

-- The loadout wall: a pegboard with outlines (revolver, bat, medkit) and four dented lockers.
local function loadoutRack(room: Model)
	local x = -W / 2 + 1
	piece(
		room,
		"Pegboard",
		Vector3.new(0.3, 7, 9),
		at(x + 0.2, 7, -8),
		Color3.fromRGB(116, 92, 66),
		Enum.Material.Cardboard
	)
	for _, o in
		{
			{ Vector3.new(0.1, 0.9, 3.2), at(x + 0.4, 9, -10) }, -- revolver outline
			{ Vector3.new(0.1, 1.6, 0.8), at(x + 0.4, 8.3, -11) },
			{ Vector3.new(0.1, 0.9, 1.5), at(x + 0.4, 5.6, -5) }, -- medkit tin outline
		}
	do
		deco(piece(room, "ToolOutline", o[1], o[2], Color3.fromRGB(30, 26, 22)))
	end
	Kit.cylinder(
		room,
		"Bat",
		4.2,
		0.45,
		CFrame.new(at(x + 0.7, 8, -6.5)) * CFrame.Angles(0, 0, math.rad(80)),
		Color3.fromRGB(120, 86, 56),
		Enum.Material.Wood
	)
	piece(
		room,
		"MedkitTin",
		Vector3.new(0.8, 0.9, 1.5),
		at(x + 0.75, 5.6, -5),
		Color3.fromRGB(196, 190, 180),
		Enum.Material.Metal
	)
	deco(
		piece(
			room,
			"MedkitCross",
			Vector3.new(0.82, 0.25, 0.6),
			at(x + 0.76, 5.6, -5),
			Color3.fromRGB(180, 30, 30)
		)
	)
	BuildingKit.lockerRow(room, at(-29.9, 1, -2.8), SOUTH, 4, EAST, 0, Color3.fromRGB(70, 78, 70))
end

-- The specimen jars: three murky jars, each with a faint silhouette of an Alpha class inside.
-- Picking one changes nothing in the world: the choice stays private.
local JAR_LOOK = {
	Runner = Vector3.new(0.35, 1.5, 0.3),
	Tank = Vector3.new(0.8, 1.2, 0.5),
	Screamer = Vector3.new(0.5, 1.35, 0.35),
}

local function specimenJars(room: Model)
	local x = -W / 2 + 2
	piece(room, "JarShelf", Vector3.new(2.2, 0.3, 15), at(x, 4.4, 15), C.rotten, Enum.Material.WoodPlanks)
	for _, z in { 8.5, 21.5 } do
		piece(
			room,
			"ShelfBracket",
			Vector3.new(2, 3.4, 0.3),
			at(x, 2.7, z),
			C.rotten,
			Enum.Material.WoodPlanks
		)
	end
	for i, className in AlphaClasses.order do
		local class = (AlphaClasses :: any)[className]
		local z = 9 + (i - 1) * 6
		local base = at(x, 4.55, z)
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
		upright("JarLid", room, 0.3, 1.9, base + Vector3.new(0, 2.95, 0), C.metal, Enum.Material.Metal)
		local shape = JAR_LOOK[className] or JAR_LOOK.Screamer
		deco(piece(room, "JarShape", shape, base + Vector3.new(0, 1.2, 0), Color3.fromRGB(14, 18, 14)))
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
		sign(room, "JarLabel", Vector2.new(1.9, 0.6), at(x + 1.15, 4.1, z), EAST, string.upper(class.name), {
			text = C.ink,
			board = C.paper,
		})
		local pick = prompt(jar, "Choose your nightmare", class.name, "AlphaPickPrompt", 6)
		pick:SetAttribute("Class", className)
	end
end

--------------------------------------------------------------------------- the hearth

local function cot(room: Model, cf: CFrame)
	for _, x in { -1.3, 1.3 } do
		for _, z in { -3, 3 } do
			Kit.onGround(
				room,
				"CotLeg",
				Vector3.new(0.2, 1.4, 0.2),
				cf * CFrame.new(x, 0, z),
				C.metal,
				Enum.Material.Metal
			)
		end
	end
	Kit.part(
		room,
		"Cot",
		Vector3.new(2.8, 0.25, 6.6),
		cf * CFrame.new(0, 1.5, 0),
		C.olive,
		Enum.Material.Fabric
	)
	Kit.part(
		room,
		"Blanket",
		Vector3.new(2.6, 0.3, 3.2),
		cf * CFrame.new(0, 1.7, 1.4) * CFrame.Angles(0, 0.08, 0),
		Color3.fromRGB(86, 64, 52),
		Enum.Material.Fabric
	)
end

-- The warm center: an oil drum fire, cots, crates to sit on, a half-ring of sandbags, candles,
-- and the one hanging bulb (moths circling it).
local function hearth(room: Model, rng: Random)
	local c = at(0, 1, 2)
	upright("OilDrum", room, 4, 3.2, c + Vector3.new(0, 2, 0), C.rust, Enum.Material.CorrodedMetal)
	local fire = deco(
		piece(
			room,
			"DrumFire",
			Vector3.new(2.4, 0.4, 2.4),
			c + Vector3.new(0, 4.1, 0),
			Color3.fromRGB(255, 110, 40),
			Enum.Material.Neon
		)
	)
	local flames = Instance.new("Fire")
	flames.Size = 4
	flames.Heat = 7
	flames.Color = Color3.fromRGB(255, 150, 60)
	flames.SecondaryColor = Color3.fromRGB(255, 70, 20)
	flames.Parent = fire
	Kit.light(fire, 16, 1.1, Color3.fromRGB(255, 150, 80)).Name = "FireLight"
	local embers = Instance.new("ParticleEmitter")
	embers.Rate = 6
	embers.Lifetime = NumberRange.new(2, 3)
	embers.Speed = NumberRange.new(3, 5)
	embers.SpreadAngle = Vector2.new(20, 20)
	embers.Size = NumberSequence.new(0.12)
	embers.Color = ColorSequence.new(C.ember)
	embers.LightEmission = 1
	embers.Parent = fire
	-- cots around the fire, crates as seats
	cot(room, CFrame.new(at(-8, 1, -1)) * CFrame.Angles(0, 0.35, 0))
	cot(room, CFrame.new(at(8, 1, -1)) * CFrame.Angles(0, -0.35, 0))
	cot(room, CFrame.new(at(-7.5, 1, 8)) * CFrame.Angles(0, -0.4, 0))
	cot(room, CFrame.new(at(7.5, 1, 8)) * CFrame.Angles(0, 0.4, 0))
	Kit.crate(room, at(-3.5, 1, -4.5), 2.2, 0.3)
	Kit.crate(room, at(4, 1, -5), 2.2, -0.2)
	Kit.crate(room, at(0, 1, 9.5), 2.4, 0.6)
	-- the sandbag half-ring on the window side
	for i = 0, 4 do
		local a = math.rad(30 + i * 30)
		local pos = c + Vector3.new(math.cos(a) * 12, 0, math.sin(a) * 12)
		Clutter.sandbags(room, CFrame.lookAt(pos, c) * CFrame.Angles(0, math.pi / 2, 0), 5, rng)
	end
	-- candles on the crates (three of them light the faces around the fire)
	for i, p in
		{
			at(-3.5, 3.2, -4.5),
			at(4, 3.2, -5),
			at(0, 3.4, 9.5),
			at(-3, 3.2, -4),
			at(4.5, 3.2, -4.6),
			at(0.6, 3.4, 9.2),
		}
	do
		upright("Candle", room, 0.6, 0.3, p + Vector3.new(0, 0.3, 0), Color3.fromRGB(214, 204, 180))
		local flame = deco(
			piece(
				room,
				"CandleFlame",
				Vector3.new(0.16, 0.3, 0.16),
				p + Vector3.new(0, 0.75, 0),
				C.ember,
				Enum.Material.Neon
			)
		)
		if i <= 3 then
			softLight(flame, 7, 0.5, C.ember).Name = "CandleLight"
		end
	end
	-- the one hanging bulb
	deco(piece(room, "BulbCord", Vector3.new(0.08, 3.6, 0.08), at(0, 15.2, 2), Color3.fromRGB(20, 20, 20)))
	local bulb = deco(
		piece(room, "HearthBulb", Vector3.new(0.8, 0.8, 0.8), at(0, 13.1, 2), C.butter, Enum.Material.Neon)
	)
	bulb.Shape = Enum.PartType.Ball
	Kit.light(bulb, 22, 1.6, Color3.fromRGB(255, 214, 150)).Name = "BulbLight"
	local moths = Instance.new("ParticleEmitter")
	moths.Name = "Moths"
	moths.Rate = 1.5
	moths.Lifetime = NumberRange.new(5, 7)
	moths.Speed = NumberRange.new(0.8, 1.6)
	moths.SpreadAngle = Vector2.new(180, 180)
	moths.RotSpeed = NumberRange.new(-200, 200)
	moths.Size = NumberSequence.new(0.18)
	moths.Color = ColorSequence.new(Color3.fromRGB(60, 54, 48))
	moths.LightInfluence = 1
	moths.Parent = bulb
end

--------------------------------------------------------------------------- east: shop + mirror

-- The shop: a chain-link cage with a counter in its front, a brass bell to ring, crates of stock
-- and a sick green tube light.
local function shopCage(room: Model, rng: Random)
	local fx = 25 -- the cage front
	local x1 = W / 2 - 1
	BuildingKit.chainFence(room, at(fx, 1, -12), at(fx, 1, -8), 9)
	BuildingKit.chainFence(room, at(fx, 1, -4), at(fx, 1, 0), 9)
	BuildingKit.chainFence(room, at(fx, 1, -12), at(x1, 1, -12), 9)
	BuildingKit.chainFence(room, at(fx, 1, 0), at(x1, 1, 0), 9)
	piece(
		room,
		"ShopCounter",
		Vector3.new(1.8, 3.6, 4.2),
		at(fx, 2.8, -6),
		C.rotten,
		Enum.Material.WoodPlanks
	)
	piece(
		room,
		"CounterTop",
		Vector3.new(2.2, 0.25, 4.6),
		at(fx, 4.7, -6),
		Color3.fromRGB(60, 50, 40),
		Enum.Material.Wood
	)
	local bell = upright(
		"ShopBell",
		room,
		0.5,
		1,
		at(fx, 5.1, -6.8),
		Color3.fromRGB(196, 150, 60),
		Enum.Material.Metal
	)
	prompt(bell, "Ring the bell", "Z-Shop", "ShopPrompt", 8)
	BuildingKit.shelf(room, CFrame.lookAt(at(x1 - 0.8, 1, -6), at(x1 - 0.8, 1, -6) + WEST), 9, rng)
	Kit.crate(room, at(27.5, 1, -10.2), 2.4, 0.2)
	Kit.crate(room, at(27.5, 3.4, -10.2), 1.8, 0.7)
	Kit.crate(room, at(28, 1, -1.8), 2.2, -0.3)
	local tube =
		deco(piece(room, "ShopTube", Vector3.new(0.3, 0.3, 5), at(28, 11.5, -6), C.mint, Enum.Material.Neon))
	softLight(tube, 12, 1, C.mint)
	sign(room, "ShopSign", Vector2.new(6, 1.6), at(fx - 0.3, 10.8, -6), WEST, "Z-SHOP", {
		text = C.butter,
		board = Color3.fromRGB(22, 18, 16),
		glow = true,
	})
end

-- The mirror alcove: a tall cracked mirror behind a moth-eaten curtain. Dressing happens "in" it.
local function mirrorAlcove(room: Model)
	local x1 = W / 2 - 1
	for _, z in { 7.5, 16.5 } do
		piece(
			room,
			"AlcoveWall",
			Vector3.new(6, 12, 0.8),
			at(x1 - 3, 7, z),
			C.concrete,
			Enum.Material.Concrete
		)
	end
	piece(
		room,
		"MirrorFrame",
		Vector3.new(0.4, 10, 5),
		at(x1 - 0.1, 6.6, 12),
		Color3.fromRGB(46, 34, 28),
		Enum.Material.Wood
	)
	local mirror = piece(
		room,
		"Mirror",
		Vector3.new(0.2, 9.2, 4.2),
		at(x1 - 0.35, 6.6, 12),
		Color3.fromRGB(176, 182, 190),
		Enum.Material.Glass
	)
	mirror.Reflectance = 0.4
	prompt(mirror, "Look in the mirror", "Catalog", "CatalogPrompt", 9)
	-- cracks across the glass
	for _, crack in { { 0.6, 0.5 }, { -0.9, -0.3 }, { 0.1, 1.2 } } do
		deco(
			Kit.part(
				room,
				"Crack",
				Vector3.new(0.05, 3, 0.08),
				CFrame.new(at(x1 - 0.47, 7 + crack[1], 12 + crack[2] * 0.8)) * CFrame.Angles(crack[2], 0, 0),
				Color3.fromRGB(30, 30, 34)
			)
		)
	end
	-- the curtain, half drawn, on a sagging rod
	deco(
		piece(
			room,
			"CurtainRod",
			Vector3.new(0.2, 0.2, 9),
			at(x1 - 5.6, 12.4, 12),
			C.rust,
			Enum.Material.CorrodedMetal
		)
	)
	local curtain = deco(
		piece(
			room,
			"Curtain",
			Vector3.new(0.25, 11, 3.2),
			at(x1 - 5.6, 6.9, 9.4),
			C.dustyPurple,
			Enum.Material.Fabric
		)
	)
	curtain.Transparency = 0.1
	sign(room, "MirrorSign", Vector2.new(3.6, 0.9), at(x1 - 5.8, 13.4, 12), WEST, "LOOK", {
		text = C.chalk,
		font = Enum.Font.PermanentMarker,
	})
end

--------------------------------------------------------------------------- south: archive, windows, posters

-- The radio desk: a reel-to-reel deck, a CRT playing static, a bank of four CCTV monitors, the
-- tape archive shelf and a clipboard nailed by the desk.
local function archive(room: Model)
	local z = D / 2 - 2.6
	piece(room, "RadioDesk", Vector3.new(14, 3.4, 3), at(-19.5, 2.7, z), C.rotten, Enum.Material.WoodPlanks)
	piece(
		room,
		"TapeDeck",
		Vector3.new(3.4, 2.4, 1.6),
		at(-24, 5.6, z + 0.3),
		Color3.fromRGB(58, 56, 52),
		Enum.Material.Metal
	)
	for _, x in { -24.8, -23.2 } do
		Kit.cylinder(
			room,
			"Reel",
			0.2,
			1.3,
			CFrame.new(at(x, 6, z - 0.55)) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(150, 146, 140),
			Enum.Material.Metal
		)
	end
	-- the CRT, nothing but static
	local tvCf = CFrame.lookAt(at(-17, 6.3, z), at(-17, 6.3, z) + NORTH)
	Kit.part(
		room,
		"CRT",
		Vector3.new(3.6, 3, 3),
		tvCf,
		Color3.fromRGB(40, 38, 36),
		Enum.Material.SmoothPlastic
	)
	local screen = deco(
		Kit.part(
			room,
			"CRTScreen",
			Vector3.new(2.8, 2.2, 0.1),
			tvCf * CFrame.new(0, 0, -1.52),
			Color3.fromRGB(150, 160, 176),
			Enum.Material.Neon
		)
	)
	screen.Transparency = 0.35
	softLight(screen, 9, 0.9, C.signal)
	-- CCTV bank on the wall above
	local zWall = D / 2 - 1.2
	local bank = Instance.new("Model")
	bank.Name = "CCTV"
	bank.Parent = room
	for i = 0, 3 do
		local col, row = i % 2, math.floor(i / 2)
		local pos = at(-13.4 + col * 2.5, 8.6 + row * 2, zWall)
		piece(
			bank,
			"Monitor",
			Vector3.new(2.3, 1.8, 1.2),
			pos,
			Color3.fromRGB(34, 34, 34),
			Enum.Material.SmoothPlastic
		)
		sign(
			bank,
			"MonitorScreen",
			Vector2.new(1.9, 1.4),
			pos + Vector3.new(0, 0, -0.65),
			NORTH,
			`CAM {i + 1}\nNO SIGNAL`,
			{
				text = C.signal,
				board = Color3.fromRGB(26, 34, 46),
				font = Enum.Font.Code,
				glow = true,
			}
		)
	end
	-- the tape shelf: room for twelve tapes, only four found so far
	piece(room, "TapeShelf", Vector3.new(7, 0.3, 1), at(-24, 10, zWall), C.rotten, Enum.Material.Wood)
	for i = 0, 3 do
		piece(
			room,
			"Tape",
			Vector3.new(0.4, 1.2, 0.8),
			at(-27 + i * 0.5, 10.75, zWall),
			Color3.fromRGB(30, 28, 30)
		)
	end
	-- the clipboard nailed by the desk, and a candle
	sign(
		room,
		"Clipboard",
		Vector2.new(1.4, 2),
		at(-11.6, 6.5, zWall),
		NORTH,
		"NIGHT LOG\n...",
		{ text = C.ink, board = C.paper }
	)
	upright("Candle", room, 0.6, 0.3, at(-21, 4.7, z - 0.8), Color3.fromRGB(214, 204, 180))
	deco(
		piece(
			room,
			"CandleFlame",
			Vector3.new(0.16, 0.3, 0.16),
			at(-21, 5.15, z - 0.8),
			C.ember,
			Enum.Material.Neon
		)
	)
end

-- The two basement windows at ground level: boards with gaps, lavender moonbeams cutting through,
-- dust in the light. Hidden things the client's scares use: a hand, eyes, the Tall One.
local function windows(room: Model, rng: Random)
	local z = D / 2
	for i, x in { -6, 6 } do
		local win = Instance.new("Model")
		win.Name = `Window{i}`
		win.Parent = room
		local glass = piece(
			win,
			"Glass",
			Vector3.new(6, 4, 0.2),
			at(x, 12, z + 0.4),
			Color3.fromRGB(26, 24, 40),
			Enum.Material.Glass
		)
		glass.Transparency = 0.5
		glass.CastShadow = false -- the moonbeams shine through it
		for b, y in { 10.4, 11.5, 12.7, 13.7 } do
			Kit.part(
				win,
				"Board",
				Vector3.new(7, 0.7, 0.3),
				CFrame.new(at(x + rng:NextNumber(-0.3, 0.3), y, z - 1.2))
					* CFrame.Angles(0, 0, rng:NextNumber(-0.06, 0.06) * b),
				C.rotten:Lerp(Color3.fromRGB(60, 58, 48), rng:NextNumber(0, 0.6)),
				Enum.Material.WoodPlanks
			)
		end
		-- moonlight shining in through the gaps (the boards cut it into stripes)
		local from = at(x * 1.4, 18, z + 7)
		local moon = deco(
			Kit.part(
				win,
				"Moonbeam",
				Vector3.new(1, 1, 1),
				CFrame.lookAt(from, at(x * 0.6, 1, z - 12)),
				C.black
			)
		)
		moon.Transparency = 1
		local beam = Instance.new("SpotLight")
		beam.Name = "MoonLight"
		beam.Face = Enum.NormalId.Front
		beam.Angle = 30
		beam.Range = 40
		beam.Brightness = 2.2
		beam.Color = C.lavender
		beam.Shadows = true
		beam.Parent = moon
		-- dust motes in the beam
		local motes = deco(piece(win, "Motes", Vector3.new(4, 6, 8), at(x * 0.8, 7, z - 7), C.black))
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
		-- a puff of dust the client throws when something bangs on the boards
		local puff = Instance.new("ParticleEmitter")
		puff.Name = "BangDust"
		puff.Enabled = false
		puff.Lifetime = NumberRange.new(1, 2)
		puff.Speed = NumberRange.new(1, 3)
		puff.SpreadAngle = Vector2.new(60, 60)
		puff.Acceleration = Vector3.new(0, -4, 0)
		puff.EmissionDirection = Enum.NormalId.Back
		puff.Size = NumberSequence.new(0.25)
		puff.Color = ColorSequence.new(Color3.fromRGB(120, 112, 100))
		puff.Parent = win:FindFirstChild("Board")
		-- the hand that slides in between the planks (hidden until a scare)
		local hand = deco(
			piece(
				win,
				"ScareHand",
				Vector3.new(1.1, 0.5, 1.6),
				at(x + 1, 12.1, z - 0.6),
				Color3.fromRGB(70, 78, 66)
			)
		)
		hand.Transparency = 1
		-- eyes in the gap (hidden until a scare)
		for _, dx in { -0.4, 0.4 } do
			local eye = deco(
				piece(
					win,
					"ScareEye",
					Vector3.new(0.25, 0.14, 0.05),
					at(x - 1.5 + dx, 12.1, z + 0.2),
					Color3.fromRGB(226, 232, 206),
					Enum.Material.Neon
				)
			)
			eye.Transparency = 1
		end
	end
	-- outside: the black street
	piece(room, "Outside", Vector3.new(W, 12, 1), at(0, 12, z + 10), C.black)
	-- the Tall One: very tall, very thin, standing in the first moonbeam (hidden until it isn't)
	local tall = Instance.new("Model")
	tall.Name = "TallOne"
	tall.Parent = room
	for _, part in
		{
			{ Vector3.new(0.9, 9, 0.7), at(-8.6, 4.5, z + 4) },
			{ Vector3.new(0.9, 9, 0.7), at(-7.4, 4.5, z + 4) },
			{ Vector3.new(2.2, 7, 1), at(-8, 12.5, z + 4) },
			{ Vector3.new(1.2, 1.6, 1.2), at(-8, 17, z + 4) },
		}
	do
		local p = deco(piece(tall, "TallPart", part[1], part[2], C.black))
		p.Transparency = 1
	end
end

-- The MISSING posters: a corkboard of the players infected last round, with their faces.
local function missingPosters(room: Model): { Poster }
	local zWall = D / 2 - 1.2
	piece(
		room,
		"Corkboard",
		Vector3.new(9, 7, 0.3),
		at(17, 7.5, zWall + 0.1),
		Color3.fromRGB(116, 88, 60),
		Enum.Material.Cardboard
	)
	local posters = {}
	for i = 0, 3 do
		local col, row = i % 2, math.floor(i / 2)
		local pos = at(14.9 + col * 4.2, 9.3 - row * 3.6, zWall - 0.15)
		local paper = deco(
			Kit.part(
				room,
				"Poster",
				Vector3.new(3.4, 3.2, 0.1),
				CFrame.lookAt(pos, pos + NORTH) * CFrame.Angles(0, 0, (col - 0.5) * 0.06),
				C.paper,
				Enum.Material.SmoothPlastic
			)
		)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.PixelsPerStud = 50
		gui.LightInfluence = 0.8
		gui.Parent = paper
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
		face.ImageColor3 = Color3.fromRGB(200, 196, 186) -- faded, like a photocopy
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

-- Builds the safehouse as workspace.Lobby (`parent`) and returns what LobbyService updates.
function Safehouse.build(parent: Instance): Refs
	local room = Instance.new("Model")
	room.Name = "Lobby"
	room.Parent = parent
	local rng = Random.new(9)
	shell(room)
	stairwell(room)
	local slots = chalkboard(room)
	local modeLabel = deployDoor(room)
	loadoutRack(room)
	specimenJars(room)
	hearth(room, rng)
	shopCage(room, rng)
	mirrorAlcove(room)
	archive(room)
	windows(room, rng)
	local posters = missingPosters(room)
	return { mapSlots = slots, modeLabel = modeLabel, posters = posters }
end

return Safehouse
