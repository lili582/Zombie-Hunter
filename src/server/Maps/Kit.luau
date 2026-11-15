--!strict
-- The prop kit every map is built from: realistic materials (no studs), anchored parts, and the
-- tagged gameplay spots. Each function builds one thing at a position on the ground (y = 0 is
-- the ground surface unless a map says otherwise) and returns it.
local CollectionService = game:GetService("CollectionService")

local Kit = {}

local Terrain = workspace.Terrain

Kit.WOOD = Color3.fromRGB(86, 62, 44)
Kit.WOOD_DARK = Color3.fromRGB(52, 38, 28)
Kit.LEAVES = Color3.fromRGB(31, 52, 38)
Kit.BARK = Color3.fromRGB(58, 44, 34)
Kit.STONE = Color3.fromRGB(92, 92, 96)
Kit.WARM = Color3.fromRGB(255, 196, 120)
Kit.BLOOD = Color3.fromRGB(74, 6, 10)

-- One anchored part. Smooth surfaces: the realistic look, not 2014 studs.
function Kit.part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A part standing on the ground: `cf` is the centre of its footprint.
function Kit.onGround(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	return Kit.part(parent, name, size, cf * CFrame.new(0, size.Y / 2, 0), color, material)
end

-- A cylinder lying along `cf`'s look direction (logs) or standing up (posts) when `upright`.
function Kit.cylinder(
	parent: Instance,
	name: string,
	length: number,
	diameter: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Kit.part(parent, name, Vector3.new(length, diameter, diameter), cf, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- An invisible tagged spot (start, spawn, tower spot, ...).
function Kit.marker(parent: Instance, tag: string, pos: Vector3)
	local p = Kit.part(parent, tag, Vector3.new(4, 1, 4), CFrame.new(pos), Color3.new(1, 0, 0))
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	CollectionService:AddTag(p, tag)
end

-- A warm light that the server makes flicker now and then.
function Kit.light(
	at: BasePart,
	range: number,
	brightness: number,
	color: Color3?,
	flicker: boolean?
): PointLight
	local light = Instance.new("PointLight")
	light.Range = range
	light.Brightness = brightness
	light.Color = color or Kit.WARM
	light.Shadows = true
	light.Parent = at
	if flicker then
		CollectionService:AddTag(at, "FlickerLight")
	end
	return light
end

--------------------------------------------------------------------------- nature

-- A pine: a dark trunk and stacked, turned layers of needles that narrow to the top.
function Kit.pine(parent: Instance, pos: Vector3, height: number, rng: Random): Model
	local tree = Instance.new("Model")
	tree.Name = "Pine"
	tree.Parent = parent
	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	Kit.cylinder(
		tree,
		"Trunk",
		height,
		math.max(1, height * 0.07),
		CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Kit.BARK,
		Enum.Material.Wood
	)
	local tiers = 5
	for i = 1, tiers do
		local t = (i - 1) / (tiers - 1)
		local width = height * (0.42 - t * 0.32)
		local y = height * (0.32 + t * 0.62)
		local leaves = Kit.part(
			tree,
			"Needles",
			Vector3.new(width, height * 0.13, width),
			CFrame.new(pos + Vector3.new(0, y, 0)) * yaw * CFrame.Angles(0, i * 0.5, 0),
			Kit.LEAVES:Lerp(Color3.fromRGB(20, 34, 26), rng:NextNumber(0, 0.6)),
			Enum.Material.LeafyGrass
		)
		leaves.CastShadow = true
	end
	return tree
end

-- A dead tree: a bare trunk and a few crooked branches. Creepy in the fog.
function Kit.deadTree(parent: Instance, pos: Vector3, height: number, rng: Random): Model
	local tree = Instance.new("Model")
	tree.Name = "DeadTree"
	tree.Parent = parent
	local lean = CFrame.Angles(
		rng:NextNumber(-0.08, 0.08),
		rng:NextNumber(0, math.pi * 2),
		rng:NextNumber(-0.08, 0.08)
	)
	local base = CFrame.new(pos) * lean
	Kit.cylinder(
		tree,
		"Trunk",
		height,
		math.max(0.9, height * 0.06),
		base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(46, 40, 36),
		Enum.Material.Wood
	)
	for _ = 1, rng:NextInteger(2, 4) do
		local at = rng:NextNumber(0.45, 0.85) * height
		local len = height * rng:NextNumber(0.2, 0.38)
		local branch = base
			* CFrame.new(0, at, 0)
			* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(35, 65)))
			* CFrame.new(len / 2, 0, 0)
		Kit.cylinder(tree, "Branch", len, 0.45, branch, Color3.fromRGB(46, 40, 36), Enum.Material.Wood)
	end
	return tree
end

-- A mossy boulder made of terrain rock.
function Kit.rock(pos: Vector3, radius: number)
	Terrain:FillBall(pos, radius, Enum.Material.Rock)
end

--------------------------------------------------------------------------- buildings

-- A wooden cabin: log walls, a door gap front and back (a chase loop through it), windows with
-- glass, a pitched roof and a porch step. `lit` puts a weak warm light inside.
-- `cf` is the centre of the floor, facing its front door along -Z.
function Kit.cabin(
	parent: Instance,
	cf: CFrame,
	w: number,
	d: number,
	h: number,
	lit: boolean,
	rng: Random
): Model
	local cabin = Instance.new("Model")
	cabin.Name = "Cabin"
	cabin.Parent = parent
	local t = 1
	local door = 5
	local wallColor = Kit.WOOD:Lerp(Kit.WOOD_DARK, rng:NextNumber(0, 0.5))
	local function wall(name: string, size: Vector3, offset: Vector3)
		Kit.part(cabin, name, size, cf * CFrame.new(offset), wallColor, Enum.Material.WoodPlanks)
	end
	Kit.part(
		cabin,
		"Floor",
		Vector3.new(w, 0.6, d),
		cf * CFrame.new(0, 0.3, 0),
		Kit.WOOD_DARK,
		Enum.Material.WoodPlanks
	)
	-- front and back walls with a door gap in the middle
	local side = (w - door) / 2
	for _, z in { -d / 2, d / 2 } do
		for _, sx in { -1, 1 } do
			wall("Wall", Vector3.new(side, h, t), Vector3.new(sx * (door / 2 + side / 2), h / 2, z))
		end
		wall("Lintel", Vector3.new(door, h - 7, t), Vector3.new(0, 7 + (h - 7) / 2, z))
	end
	-- side walls with a window each
	local win = math.min(4, d * 0.35)
	local seg = (d - win) / 2
	for _, x in { -w / 2, w / 2 } do
		for _, sz in { -1, 1 } do
			wall("Wall", Vector3.new(t, h, seg), Vector3.new(x, h / 2, sz * (win / 2 + seg / 2)))
		end
		wall("UnderWindow", Vector3.new(t, 3, win), Vector3.new(x, 1.5, 0))
		wall("OverWindow", Vector3.new(t, h - 6.5, win), Vector3.new(x, 6.5 + (h - 6.5) / 2, 0))
		local glass = Kit.part(
			cabin,
			"Window",
			Vector3.new(0.2, 3.5, win),
			cf * CFrame.new(x, 4.75, 0),
			Color3.fromRGB(70, 80, 90),
			Enum.Material.Glass
		)
		glass.Transparency = 0.55
	end
	-- pitched roof: two slabs meeting at the ridge, and the two triangle gables
	local pitch = math.rad(28)
	local half = d / 2 + 1
	local rise = half * math.tan(pitch)
	local slab = half / math.cos(pitch)
	for _, sz in { -1, 1 } do
		Kit.part(
			cabin,
			"Roof",
			Vector3.new(w + 2, 0.7, slab),
			cf * CFrame.new(0, h + rise / 2, sz * half / 2) * CFrame.Angles(sz * pitch, 0, 0),
			Color3.fromRGB(48, 44, 46),
			Enum.Material.Slate
		)
	end
	for _, x in { -w / 2, w / 2 } do
		for _, sz in { -1, 1 } do
			local gable = Instance.new("WedgePart")
			gable.Name = "Gable"
			gable.Anchored = true
			gable.Size = Vector3.new(t, rise, d / 2)
			gable.CFrame = cf
				* CFrame.new(x, h + rise / 2, sz * d / 4)
				* CFrame.Angles(0, if sz > 0 then math.pi else 0, 0)
			gable.Color = wallColor
			gable.Material = Enum.Material.WoodPlanks
			gable.Parent = cabin
		end
	end
	-- porch step in front of the door
	Kit.part(
		cabin,
		"Step",
		Vector3.new(door + 2, 0.6, 2.4),
		cf * CFrame.new(0, 0.3, -d / 2 - 1.2),
		Kit.WOOD_DARK,
		Enum.Material.WoodPlanks
	)
	if lit then
		local bulb = Kit.part(
			cabin,
			"Bulb",
			Vector3.new(0.6, 0.6, 0.6),
			cf * CFrame.new(0, h - 1, 0),
			Kit.WARM,
			Enum.Material.Neon
		)
		bulb.CanCollide = false
		Kit.light(bulb, math.max(w, d) * 0.9, 0.9, Kit.WARM, true)
	end
	return cabin
end

-- A lantern on a wooden post: the warm, flickering light along the paths.
function Kit.lantern(parent: Instance, pos: Vector3): Model
	local lamp = Instance.new("Model")
	lamp.Name = "Lantern"
	lamp.Parent = parent
	Kit.onGround(lamp, "Post", Vector3.new(0.6, 8, 0.6), CFrame.new(pos), Kit.WOOD_DARK, Enum.Material.Wood)
	Kit.part(
		lamp,
		"Arm",
		Vector3.new(0.4, 0.4, 2),
		CFrame.new(pos + Vector3.new(0, 7.8, 0.8)),
		Kit.WOOD_DARK,
		Enum.Material.Wood
	)
	local glass = Kit.part(
		lamp,
		"Lamp",
		Vector3.new(0.9, 1.2, 0.9),
		CFrame.new(pos + Vector3.new(0, 7, 1.6)),
		Kit.WARM,
		Enum.Material.Neon
	)
	glass.CanCollide = false
	Kit.light(glass, 26, 1.4, Kit.WARM, true)
	return lamp
end

-- A campfire: a ring of stones, crossed logs, real fire and a flickering orange light.
function Kit.campfire(parent: Instance, pos: Vector3): Model
	local fire = Instance.new("Model")
	fire.Name = "Campfire"
	fire.Parent = parent
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		local stone = Kit.part(
			fire,
			"Stone",
			Vector3.new(1.4, 1, 1.4),
			CFrame.new(pos + Vector3.new(math.cos(a) * 3, 0.4, math.sin(a) * 3)),
			Kit.STONE,
			Enum.Material.Slate
		)
		stone.Shape = Enum.PartType.Ball
	end
	for i = 1, 3 do
		Kit.cylinder(
			fire,
			"Log",
			4,
			0.7,
			CFrame.new(pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, i * math.pi / 3, 0),
			Kit.BARK,
			Enum.Material.Wood
		)
	end
	local embers = Kit.part(
		fire,
		"Embers",
		Vector3.new(2, 0.3, 2),
		CFrame.new(pos + Vector3.new(0, 0.6, 0)),
		Color3.fromRGB(255, 120, 40),
		Enum.Material.Neon
	)
	embers.CanCollide = false
	local flames = Instance.new("Fire")
	flames.Size = 6
	flames.Heat = 9
	flames.Color = Color3.fromRGB(255, 130, 40)
	flames.SecondaryColor = Color3.fromRGB(255, 60, 20)
	flames.Parent = embers
	Kit.light(embers, 40, 2.2, Color3.fromRGB(255, 140, 60), true)
	return fire
end

-- A log lying on the ground (benches around the fire, fallen trees).
function Kit.log(parent: Instance, pos: Vector3, length: number, yaw: number): Part
	return Kit.cylinder(
		parent,
		"Log",
		length,
		1.4,
		CFrame.new(pos + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, yaw, 0),
		Kit.BARK,
		Enum.Material.Wood
	)
end

-- A split-rail fence from `a` to `b` (both on the ground).
function Kit.fence(parent: Instance, a: Vector3, b: Vector3): Model
	local fence = Instance.new("Model")
	fence.Name = "Fence"
	fence.Parent = parent
	local span = (b - a)
	local length = span.Magnitude
	local posts = math.max(2, math.floor(length / 8) + 1)
	for i = 0, posts - 1 do
		local p = a + span * (i / (posts - 1))
		Kit.onGround(
			fence,
			"Post",
			Vector3.new(0.6, 4, 0.6),
			CFrame.new(p),
			Kit.WOOD_DARK,
			Enum.Material.Wood
		)
	end
	local look = CFrame.lookAt(a, b)
	for _, y in { 1.6, 3.2 } do
		Kit.part(
			fence,
			"Rail",
			Vector3.new(0.3, 0.4, length),
			look * CFrame.new(0, y, -length / 2),
			Kit.WOOD,
			Enum.Material.Wood
		)
	end
	return fence
end

function Kit.crate(parent: Instance, pos: Vector3, size: number, yaw: number): Part
	return Kit.onGround(
		parent,
		"Crate",
		Vector3.new(size, size, size),
		CFrame.new(pos) * CFrame.Angles(0, yaw, 0),
		Kit.WOOD,
		Enum.Material.WoodPlanks
	)
end

function Kit.barrel(parent: Instance, pos: Vector3): Part
	local b = Kit.cylinder(
		parent,
		"Barrel",
		3.2,
		2.2,
		CFrame.new(pos + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(70, 46, 34),
		Enum.Material.CorrodedMetal
	)
	return b
end

-- A dark stain on the ground. Not gore: just enough to make you nervous.
function Kit.stain(parent: Instance, pos: Vector3, size: number, rng: Random): Part
	local s = Kit.part(
		parent,
		"Stain",
		Vector3.new(size, 0.05, size * rng:NextNumber(0.5, 1)),
		CFrame.new(pos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		Kit.BLOOD,
		Enum.Material.SmoothPlastic
	)
	s.CanCollide = false
	s.CanQuery = false
	s.Transparency = 0.25
	return s
end

-- A hiding place: a tall wooden shed with a door. The tagged part is the "locker" itself.
function Kit.hidingShed(parent: Instance, cf: CFrame): Part
	local box = Kit.onGround(
		parent,
		"HidingShed",
		Vector3.new(4, 7.5, 4),
		cf,
		Kit.WOOD_DARK,
		Enum.Material.WoodPlanks
	)
	CollectionService:AddTag(box, "Locker")
	local roof = Kit.part(
		parent,
		"ShedRoof",
		Vector3.new(5, 0.5, 5),
		cf * CFrame.new(0, 7.8, 0),
		Color3.fromRGB(48, 44, 46),
		Enum.Material.Slate
	)
	roof.CanCollide = false
	local door = Kit.part(
		parent,
		"ShedDoor",
		Vector3.new(2.6, 6, 0.2),
		cf * CFrame.new(0, 3.3, -2.05),
		Kit.WOOD,
		Enum.Material.WoodPlanks
	)
	door.CanCollide = false
	return box
end

--------------------------------------------------------------------------- lake

-- A wooden dock from `a` (on shore) to `b` (over the water), on posts.
function Kit.dock(parent: Instance, a: Vector3, b: Vector3, width: number, deckY: number): Model
	local dock = Instance.new("Model")
	dock.Name = "Dock"
	dock.Parent = parent
	local look = CFrame.lookAt(Vector3.new(a.X, deckY, a.Z), Vector3.new(b.X, deckY, b.Z))
	local length = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
	local plank = 1.4
	for i = 0, math.floor(length / plank) - 1 do
		Kit.part(
			dock,
			"Plank",
			Vector3.new(width, 0.4, plank - 0.15),
			look * CFrame.new(0, 0, -(i + 0.5) * plank),
			Kit.WOOD:Lerp(Kit.WOOD_DARK, (i % 3) / 4),
			Enum.Material.WoodPlanks
		)
	end
	for i = 0, math.floor(length / 6) do
		for _, x in { -width / 2, width / 2 } do
			Kit.part(
				dock,
				"Post",
				Vector3.new(0.7, 8, 0.7),
				look * CFrame.new(x, -3.5, -i * 6),
				Kit.WOOD_DARK,
				Enum.Material.Wood
			)
		end
	end
	return dock
end

function Kit.canoe(parent: Instance, cf: CFrame): Model
	local canoe = Instance.new("Model")
	canoe.Name = "Canoe"
	canoe.Parent = parent
	local hull = Kit.part(
		canoe,
		"Hull",
		Vector3.new(2.4, 1, 11),
		cf * CFrame.new(0, 0.5, 0),
		Color3.fromRGB(110, 52, 40),
		Enum.Material.Wood
	)
	hull.Shape = Enum.PartType.Block
	for _, z in { -6, 6 } do
		local tip = Instance.new("WedgePart")
		tip.Anchored = true
		tip.Size = Vector3.new(2.4, 1, 1.6)
		tip.CFrame = cf
			* CFrame.new(0, 0.5, z - math.sign(z) * 0.2)
			* CFrame.Angles(0, if z > 0 then math.pi else 0, 0)
		tip.Color = hull.Color
		tip.Material = Enum.Material.Wood
		tip.Parent = canoe
	end
	return canoe
end

-- A ranger watchtower: four legs, a platform with rails and a roof, and a ladder.
function Kit.watchtower(parent: Instance, pos: Vector3, height: number): Model
	local tower = Instance.new("Model")
	tower.Name = "Watchtower"
	tower.Parent = parent
	local s = 8
	for _, x in { -s / 2, s / 2 } do
		for _, z in { -s / 2, s / 2 } do
			Kit.onGround(
				tower,
				"Leg",
				Vector3.new(1, height, 1),
				CFrame.new(pos + Vector3.new(x, 0, z)),
				Kit.WOOD_DARK,
				Enum.Material.Wood
			)
		end
	end
	Kit.part(
		tower,
		"Platform",
		Vector3.new(s + 2, 0.8, s + 2),
		CFrame.new(pos + Vector3.new(0, height, 0)),
		Kit.WOOD,
		Enum.Material.WoodPlanks
	)
	for _, dir in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1) } do
		local size = if dir.X ~= 0 then Vector3.new(0.4, 3, s + 2) else Vector3.new(s + 2, 3, 0.4)
		Kit.part(
			tower,
			"Rail",
			size,
			CFrame.new(pos + Vector3.new(0, height + 1.9, 0) + dir * (s / 2 + 0.8)),
			Kit.WOOD,
			Enum.Material.Wood
		)
	end
	Kit.part(
		tower,
		"Roof",
		Vector3.new(s + 4, 0.6, s + 4),
		CFrame.new(pos + Vector3.new(0, height + 7, 0)),
		Color3.fromRGB(48, 44, 46),
		Enum.Material.Slate
	)
	for _, x in { -s / 2, s / 2 } do
		for _, z in { -s / 2, s / 2 } do
			Kit.part(
				tower,
				"RoofPost",
				Vector3.new(0.5, 6.2, 0.5),
				CFrame.new(pos + Vector3.new(x, height + 3.8, z)),
				Kit.WOOD_DARK,
				Enum.Material.Wood
			)
		end
	end
	-- ladder on the open side (-Z)
	local ladder = pos + Vector3.new(0, 0, -s / 2 - 1.2)
	for _, x in { -1, 1 } do
		Kit.onGround(
			tower,
			"LadderRail",
			Vector3.new(0.3, height, 0.3),
			CFrame.new(ladder + Vector3.new(x, 0, 0)),
			Kit.WOOD_DARK,
			Enum.Material.Wood
		)
	end
	for y = 1, height - 1, 1.5 do
		Kit.part(
			tower,
			"Rung",
			Vector3.new(2, 0.25, 0.25),
			CFrame.new(ladder + Vector3.new(0, y, 0)),
			Kit.WOOD,
			Enum.Material.Wood
		)
	end
	local truss = Instance.new("TrussPart") -- climbable
	truss.Anchored = true
	truss.Size = Vector3.new(2, height, 2)
	truss.CFrame = CFrame.new(ladder + Vector3.new(0, height / 2, 0.6))
	truss.Transparency = 1
	truss.Parent = tower
	local lamp = Kit.part(
		tower,
		"Lamp",
		Vector3.new(0.8, 0.8, 0.8),
		CFrame.new(pos + Vector3.new(0, height + 6, 0)),
		Color3.fromRGB(255, 80, 80),
		Enum.Material.Neon
	)
	Kit.light(lamp, 30, 1.2, Color3.fromRGB(255, 90, 90), true)
	return tower
end

-- A sign on two posts with a carved name (SurfaceGui text on both faces).
function Kit.sign(parent: Instance, cf: CFrame, text: string): Model
	local sign = Instance.new("Model")
	sign.Name = "Sign"
	sign.Parent = parent
	for _, x in { -5, 5 } do
		Kit.onGround(
			sign,
			"Post",
			Vector3.new(0.8, 9, 0.8),
			cf * CFrame.new(x, 0, 0),
			Kit.WOOD_DARK,
			Enum.Material.Wood
		)
	end
	local board = Kit.part(
		sign,
		"Board",
		Vector3.new(12, 3, 0.5),
		cf * CFrame.new(0, 7.5, 0),
		Kit.WOOD,
		Enum.Material.WoodPlanks
	)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.PixelsPerStud = 30
		gui.LightInfluence = 1
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.Fantasy
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(225, 210, 180)
		label.Text = text
		label.Parent = gui
	end
	return sign
end

-- Invisible walls around a square map of `size` studs, so nobody walks off the edge.
function Kit.boundary(parent: Instance, size: number)
	for _, w in
		{
			{ Vector3.new(0, 30, size / 2), Vector3.new(size, 60, 2) },
			{ Vector3.new(0, 30, -size / 2), Vector3.new(size, 60, 2) },
			{ Vector3.new(size / 2, 30, 0), Vector3.new(2, 60, size) },
			{ Vector3.new(-size / 2, 30, 0), Vector3.new(2, 60, size) },
		}
	do
		local wall = Kit.part(parent, "Boundary", w[2], CFrame.new(w[1]), Color3.new(0, 0, 0))
		wall.Transparency = 1
	end
end

return Kit
