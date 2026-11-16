--!strict
-- Wear and tear for the maps: wet puddles that catch the lights, scattered paper, broken glass,
-- tipped bins, police barriers and sandbags, fallen ceiling tiles, a dropped flashlight still on,
-- a ritual circle, a leak dripping from the roof. Flat litter never blocks anyone (no collision).
local Kit = require(script.Parent.Kit)

local Clutter = {}

local function litter(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

-- A random point in the rectangle x0..x1, z0..z1 at height y.
function Clutter.pointIn(rng: Random, x0: number, z0: number, x1: number, z1: number, y: number): Vector3
	return Vector3.new(rng:NextNumber(x0, x1), y, rng:NextNumber(z0, z1))
end

-- A dark, wet puddle on the ground (glass, so lamps glint in it).
function Clutter.puddle(parent: Instance, pos: Vector3, size: number, rng: Random): Part
	local p = Kit.part(
		parent,
		"Puddle",
		Vector3.new(size, 0.05, size * rng:NextNumber(0.45, 0.9)),
		CFrame.new(pos + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		Color3.fromRGB(16, 20, 26),
		Enum.Material.Glass
	)
	p.Transparency = 0.3
	litter(p)
	return p
end

-- `count` puddles in a rectangle.
function Clutter.puddles(parent: Instance, rng: Random, area: { number }, y: number, count: number)
	for _ = 1, count do
		Clutter.puddle(
			parent,
			Clutter.pointIn(rng, area[1], area[2], area[3], area[4], y),
			rng:NextNumber(2.5, 7),
			rng
		)
	end
end

-- Sheets of paper blown around a point (newspapers, flyers, homework, receipts).
function Clutter.papers(parent: Instance, center: Vector3, radius: number, count: number, rng: Random)
	for _ = 1, count do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, radius)
		local pos = center + Vector3.new(math.cos(a) * r, 0.06, math.sin(a) * r)
		local sheet = Kit.part(
			parent,
			"Paper",
			Vector3.new(rng:NextNumber(0.9, 1.4), 0.04, rng:NextNumber(1.2, 1.8)),
			CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), rng:NextNumber(0, math.pi * 2), 0),
			Color3.fromRGB(206, 200, 184):Lerp(Color3.fromRGB(150, 140, 110), rng:NextNumber(0, 0.6)),
			Enum.Material.SmoothPlastic
		)
		litter(sheet)
	end
end

-- Broken glass glinting on the floor.
function Clutter.shards(parent: Instance, center: Vector3, radius: number, count: number, rng: Random)
	for _ = 1, count do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, radius)
		local shard = Kit.part(
			parent,
			"Shard",
			Vector3.new(rng:NextNumber(0.2, 0.7), 0.05, rng:NextNumber(0.2, 0.6)),
			CFrame.new(center + Vector3.new(math.cos(a) * r, 0.05, math.sin(a) * r))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Color3.fromRGB(150, 176, 186),
			Enum.Material.Glass
		)
		shard.Transparency = 0.4
		litter(shard)
	end
end

-- A metal bin, sometimes knocked over with its rubbish spilled out.
function Clutter.trashCan(parent: Instance, pos: Vector3, tipped: boolean, rng: Random)
	local color = Color3.fromRGB(70, 74, 72)
	if tipped then
		local yaw = rng:NextNumber(0, math.pi * 2)
		local cf = CFrame.new(pos + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, yaw, 0)
		Kit.cylinder(parent, "TrashCan", 3.6, 2.4, cf, color, Enum.Material.CorrodedMetal)
		Clutter.papers(parent, (cf * CFrame.new(3, -1.2, 0)).Position, 2.5, 5, rng)
	else
		Kit.cylinder(
			parent,
			"TrashCan",
			3.6,
			2.4,
			CFrame.new(pos + Vector3.new(0, 1.8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			color,
			Enum.Material.CorrodedMetal
		)
	end
end

-- A striped police sawhorse barrier.
function Clutter.sawhorse(parent: Instance, cf: CFrame)
	for _, x in { -2.6, 2.6 } do
		for _, tilt in { -0.25, 0.25 } do
			Kit.part(
				parent,
				"BarrierLeg",
				Vector3.new(0.3, 3.4, 0.3),
				cf * CFrame.new(x, 1.6, 0) * CFrame.Angles(tilt, 0, 0),
				Color3.fromRGB(90, 88, 84),
				Enum.Material.Metal
			)
		end
	end
	for i = 0, 3 do
		Kit.part(
			parent,
			"BarrierStripe",
			Vector3.new(1.5, 0.9, 0.2),
			cf * CFrame.new(-2.25 + i * 1.5, 3, 0),
			if i % 2 == 0 then Color3.fromRGB(220, 110, 30) else Color3.fromRGB(226, 222, 214),
			Enum.Material.SmoothPlastic
		)
	end
end

-- A low wall of sandbags along `cf`'s X axis, `length` studs long.
function Clutter.sandbags(parent: Instance, cf: CFrame, length: number, rng: Random)
	local bags = math.max(1, math.floor(length / 2.2))
	for row = 0, 1 do
		for i = 0, bags - 1 - row do
			local x = -length / 2 + 1.1 + i * 2.2 + row * 1.1
			Kit.part(
				parent,
				"Sandbag",
				Vector3.new(2.2, 1, 1.4),
				cf * CFrame.new(x, 0.5 + row, 0) * CFrame.Angles(0, rng:NextNumber(-0.1, 0.1), 0),
				Color3.fromRGB(128, 112, 84):Lerp(Color3.fromRGB(96, 84, 64), rng:NextNumber(0, 1)),
				Enum.Material.Fabric
			)
		end
	end
end

-- A ceiling tile that came down, lying crooked on the floor.
function Clutter.fallenTile(parent: Instance, pos: Vector3, rng: Random)
	local tile = Kit.part(
		parent,
		"FallenTile",
		Vector3.new(4, 0.25, 2),
		CFrame.new(pos + Vector3.new(0, 0.35, 0))
			* CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, math.pi), rng:NextNumber(-0.2, 0.2)),
		Color3.fromRGB(176, 172, 160),
		Enum.Material.SmoothPlastic
	)
	litter(tile)
end

-- A flashlight someone dropped and never came back for, still shining along the ground.
function Clutter.flashlight(parent: Instance, pos: Vector3, yaw: number)
	local cf = CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, yaw, 0)
	local body = Kit.part(
		parent,
		"Flashlight",
		Vector3.new(0.45, 0.45, 1.6),
		cf,
		Color3.fromRGB(30, 30, 32),
		Enum.Material.Metal
	)
	litter(body)
	local lens = Kit.part(
		parent,
		"FlashlightLens",
		Vector3.new(0.5, 0.5, 0.1),
		cf * CFrame.new(0, 0, -0.85),
		Color3.fromRGB(255, 244, 210),
		Enum.Material.Neon
	)
	litter(lens)
	local beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Front
	beam.Range = 28
	beam.Angle = 40
	beam.Brightness = 2
	beam.Color = Color3.fromRGB(255, 240, 210)
	beam.Shadows = true
	beam.Parent = lens
end

-- A ring of stones with stubby candles, something drawn in the middle.
function Clutter.ritualCircle(parent: Instance, center: Vector3, radius: number, rng: Random)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local pos = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		local stone = Kit.part(
			parent,
			"RitualStone",
			Vector3.new(1, 0.7, 1),
			CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Kit.STONE,
			Enum.Material.Slate
		)
		litter(stone)
		if i % 3 == 0 then
			local wax = Kit.part(
				parent,
				"Candle",
				Vector3.new(0.35, 0.7, 0.35),
				CFrame.new(pos + Vector3.new(0, 1, 0)),
				Color3.fromRGB(200, 190, 170)
			)
			litter(wax)
			local flame = Kit.part(
				parent,
				"CandleFlame",
				Vector3.new(0.18, 0.3, 0.18),
				CFrame.new(pos + Vector3.new(0, 1.5, 0)),
				Kit.WARM,
				Enum.Material.Neon
			)
			litter(flame)
			if i == 0 then
				Kit.light(flame, 16, 0.9, Kit.WARM, true)
			end
		end
	end
	-- the mark in the middle: three crossed lines
	for i = 0, 2 do
		local line = Kit.part(
			parent,
			"RitualMark",
			Vector3.new(0.3, 0.04, radius * 1.4),
			CFrame.new(center + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, i * math.pi / 3, 0),
			Kit.BLOOD,
			Enum.Material.SmoothPlastic
		)
		litter(line)
	end
end

-- Water dripping from a leak in the roof at `top` down into a puddle on the floor at `floorY`.
function Clutter.leak(parent: Instance, top: Vector3, floorY: number, rng: Random)
	local source = Kit.part(parent, "Leak", Vector3.new(1, 0.2, 1), CFrame.new(top), Color3.new(0, 0, 0))
	source.Transparency = 1
	litter(source)
	local drops = Instance.new("ParticleEmitter")
	drops.EmissionDirection = Enum.NormalId.Bottom
	drops.Speed = NumberRange.new(2, 4)
	drops.Acceleration = Vector3.new(0, -60, 0)
	drops.Lifetime = NumberRange.new(math.sqrt(2 * math.max(1, top.Y - floorY) / 60))
	drops.Rate = 6
	drops.Size = NumberSequence.new(0.12)
	drops.Color = ColorSequence.new(Color3.fromRGB(170, 190, 200))
	drops.Transparency = NumberSequence.new(0.3)
	drops.LightInfluence = 1
	drops.Parent = source
	Clutter.puddle(parent, Vector3.new(top.X, floorY, top.Z), 5, rng)
end

-- Clothes dumped on the floor.
function Clutter.clothes(parent: Instance, center: Vector3, radius: number, count: number, rng: Random)
	for _ = 1, count do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, radius)
		local cloth = Kit.part(
			parent,
			"Clothes",
			Vector3.new(rng:NextNumber(1.6, 2.6), 0.15, rng:NextNumber(1.2, 2)),
			CFrame.new(center + Vector3.new(math.cos(a) * r, 0.08, math.sin(a) * r))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
			Color3.fromHSV(rng:NextNumber(), rng:NextNumber(0.2, 0.5), rng:NextNumber(0.25, 0.55)),
			Enum.Material.Fabric
		)
		litter(cloth)
	end
end

return Clutter
