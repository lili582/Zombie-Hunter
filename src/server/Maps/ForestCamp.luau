--!strict
-- FOREST CAMP: an abandoned summer camp in the pines. Hub: the campfire circle in front of the
-- main lodge. Zones: the cabins (west), the lake with its dock (east), the ranger tower and trail
-- (south), and a clearing in the woods (north). Real terrain (grass, mud paths, rock hills, a
-- lake of water), lantern-lit paths, ~150 pines and dead trees, and thick cold mist.
-- All spots are data at the top, so the round rules and the builder use the same numbers.
local Kit = require(script.Parent.Kit)

local ForestCamp = {}

ForestCamp.SIZE = 360

local LAKE = { center = Vector3.new(110, 0, 30), size = Vector2.new(110, 130) } -- x 55..165, z -35..95

ForestCamp.TOWERS = {
	Vector3.new(-140, 0.5, -130),
	Vector3.new(-60, 0.5, -95),
	Vector3.new(60, 0.5, -110),
	Vector3.new(150, 0.5, -120),
	Vector3.new(160, 0.5, 145),
	Vector3.new(25, 0.5, 75),
	Vector3.new(-150, 0.5, 30),
	Vector3.new(-100, 0.5, 150),
}
ForestCamp.HELI = {
	Vector3.new(-35, 0.5, -135), -- the clearing in the woods
	Vector3.new(95, 0.5, 125), -- the lake shore
	Vector3.new(-80, 0.5, 120), -- below the ranger tower
}
local HUMAN_STARTS = {
	Vector3.new(0, 3, 30),
	Vector3.new(-70, 3, -10),
	Vector3.new(40, 3, -60),
	Vector3.new(-40, 3, 85),
	Vector3.new(30, 3, 155),
	Vector3.new(-150, 3, -70),
	Vector3.new(130, 3, 130),
}
local ZOMBIE_SPAWNS = {
	Vector3.new(-160, 3, -160),
	Vector3.new(160, 3, -160),
	Vector3.new(-160, 3, 160),
	Vector3.new(160, 3, 165),
}
local AMMO = {
	Vector3.new(-20, 3, -62),
	Vector3.new(70, 3, -80),
	Vector3.new(-115, 3, -95),
	Vector3.new(-140, 3, 90),
	Vector3.new(12, 3, 110),
	Vector3.new(140, 3, 160),
	Vector3.new(-55, 3, 42),
	Vector3.new(38, 3, -12),
}
local HIDING = {
	Vector3.new(-78, 0, -45),
	Vector3.new(-112, 0, -2),
	Vector3.new(-90, 0, 38),
	Vector3.new(-145, 0, 78),
	Vector3.new(-55, 0, -118),
	Vector3.new(18, 0, -72),
	Vector3.new(78, 0, -58),
	Vector3.new(38, 0, 46),
	Vector3.new(15, 0, 95),
	Vector3.new(-30, 0, 140),
	Vector3.new(-125, 0, 145),
	Vector3.new(110, 0, 145),
	Vector3.new(150, 0, -80),
	Vector3.new(-160, 0, -15),
}
-- cabins: position, turn (degrees), lit?
local CABINS = {
	{ Vector3.new(-95, 0, -65), 30, true },
	{ Vector3.new(-132, 0, -25), 90, false },
	{ Vector3.new(-100, 0, 15), 0, true },
	{ Vector3.new(-135, 0, 55), 120, false },
	{ Vector3.new(-70, 0, 65), 200, true },
	{ Vector3.new(-58, 0, -40), 60, false },
}
local LODGE = Vector3.new(0, 0, -42)
local RANGER_TOWER = Vector3.new(-20, 0, 125)
local RANGER_HUT = Vector3.new(28, 0, 132)
local DOCK = { from = Vector3.new(48, 0, 30), to = Vector3.new(84, 0, 30) }
-- dirt paths (polylines)
local PATHS = {
	{ Vector3.new(0, 0, 6), Vector3.new(0, 0, -28) },
	{
		Vector3.new(-8, 0, 0),
		Vector3.new(-55, 0, -8),
		Vector3.new(-92, 0, -40),
		Vector3.new(-118, 0, 5),
		Vector3.new(-100, 0, 45),
		Vector3.new(-62, 0, 40),
		Vector3.new(-55, 0, -8),
	},
	{ Vector3.new(8, 0, 2), Vector3.new(48, 0, 30) },
	{ Vector3.new(0, 0, 8), Vector3.new(-10, 0, 60), Vector3.new(-18, 0, 108), Vector3.new(0, 0, 160) },
	{ Vector3.new(0, 0, -56), Vector3.new(-32, 0, -115) },
	{ Vector3.new(-18, 0, 108), Vector3.new(26, 0, 122) },
}

-- what the round rules need: tower spots (x, z) and how many helicopter zones
function ForestCamp.meta(): any
	local spots = {}
	for _, p in ForestCamp.TOWERS do
		table.insert(spots, { x = p.X, z = p.Z })
	end
	return { towerSpots = spots, heliZoneCount = #ForestCamp.HELI }
end

local Terrain = workspace.Terrain

local function terrain()
	local S = ForestCamp.SIZE + 60
	Terrain:FillBlock(CFrame.new(0, -8, 0), Vector3.new(S, 16, S), Enum.Material.Grass)
	-- patches of leafy grass and mud so the ground isn't one flat colour
	local rng = Random.new(7)
	for _ = 1, 40 do
		local x, z = rng:NextNumber(-170, 170), rng:NextNumber(-170, 170)
		local mat = if rng:NextNumber() < 0.6 then Enum.Material.LeafyGrass else Enum.Material.Mud
		Terrain:FillBlock(
			CFrame.new(x, -2, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Vector3.new(rng:NextNumber(12, 30), 4, rng:NextNumber(12, 30)),
			mat
		)
	end
	-- dirt paths
	for _, path in PATHS do
		for i = 1, #path - 1 do
			local a, b = path[i], path[i + 1]
			local mid = (a + b) / 2
			local len = (b - a).Magnitude
			Terrain:FillBlock(
				CFrame.lookAt(Vector3.new(mid.X, -2, mid.Z), Vector3.new(b.X, -2, b.Z)),
				Vector3.new(9, 4, len + 8),
				Enum.Material.Ground
			)
		end
	end
	-- the lake: dig it out, fill it with water, soften the shore with mud
	local c, size = LAKE.center, LAKE.size
	Terrain:FillBlock(CFrame.new(c.X, -6, c.Z), Vector3.new(size.X + 8, 12, size.Y + 8), Enum.Material.Mud)
	Terrain:FillBlock(CFrame.new(c.X, -5, c.Z), Vector3.new(size.X, 10, size.Y), Enum.Material.Air)
	Terrain:FillBlock(CFrame.new(c.X, -6, c.Z), Vector3.new(size.X, 8, size.Y), Enum.Material.Water)
	-- rocky hills all around the edge (the camp is in a valley)
	local half = ForestCamp.SIZE / 2 + 6
	for t = -half, half, 18 do
		for _, p in
			{
				Vector3.new(t, 0, -half),
				Vector3.new(t, 0, half),
				Vector3.new(-half, 0, t),
				Vector3.new(half, 0, t),
			}
		do
			local r = rng:NextNumber(14, 24)
			Terrain:FillBall(p + Vector3.new(0, rng:NextNumber(-4, 4), 0), r, Enum.Material.Grass)
			Kit.rock(p + Vector3.new(rng:NextNumber(-6, 6), r * 0.5, rng:NextNumber(-6, 6)), r * 0.45)
		end
	end
end

-- Places a point is not allowed to have a tree (buildings, paths, spots, the lake).
local function clearZones(): { { pos: Vector3, r: number } }
	local zones = {}
	local function add(pos: Vector3, r: number)
		table.insert(zones, { pos = pos, r = r })
	end
	for _, list in { ForestCamp.TOWERS, HUMAN_STARTS, ZOMBIE_SPAWNS, AMMO, HIDING } do
		for _, p in list do
			add(p, 9)
		end
	end
	for _, p in ForestCamp.HELI do
		add(p, 26)
	end
	for _, cabin in CABINS do
		add(cabin[1], 17)
	end
	add(LODGE, 30)
	add(Vector3.zero, 18) -- campfire circle
	add(RANGER_TOWER, 14)
	add(RANGER_HUT, 14)
	for _, path in PATHS do
		for i = 1, #path - 1 do
			local a, b = path[i], path[i + 1]
			local steps = math.ceil((b - a).Magnitude / 6)
			for k = 0, steps do
				add(a:Lerp(b, k / steps), 8)
			end
		end
	end
	return zones
end

local function inLake(p: Vector3, margin: number): boolean
	local c, size = LAKE.center, LAKE.size
	return math.abs(p.X - c.X) < size.X / 2 + margin and math.abs(p.Z - c.Z) < size.Y / 2 + margin
end

local function trees(map: Model)
	local folder = Instance.new("Folder")
	folder.Name = "Trees"
	folder.Parent = map
	local rng = Random.new(1337)
	local zones = clearZones()
	local placed: { Vector3 } = {}
	local half = ForestCamp.SIZE / 2 - 12
	for _ = 1, 900 do
		if #placed >= 150 then
			break
		end
		local p = Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half))
		local ok = not inLake(p, 6)
		for _, z in zones do
			if ok and (p - z.pos).Magnitude < z.r then
				ok = false
			end
		end
		for _, q in placed do
			if ok and (p - q).Magnitude < 10 then
				ok = false
			end
		end
		if ok then
			table.insert(placed, p)
			if rng:NextNumber() < 0.72 then
				Kit.pine(folder, p, rng:NextNumber(26, 44), rng)
			else
				Kit.deadTree(folder, p, rng:NextNumber(16, 26), rng)
			end
		end
	end
end

local function lanterns(map: Model)
	local folder = Instance.new("Folder")
	folder.Name = "Lanterns"
	folder.Parent = map
	for _, path in PATHS do
		for i = 1, #path - 1 do
			local a, b = path[i], path[i + 1]
			local dir = (b - a).Unit
			local side = Vector3.new(-dir.Z, 0, dir.X) * 6
			local len = (b - a).Magnitude
			for d = 10, len, 26 do
				Kit.lantern(folder, a + dir * d + side)
			end
		end
	end
end

local function camp(map: Model)
	local rng = Random.new(21)
	-- the hub: campfire, log benches, the main lodge facing the fire
	Kit.campfire(map, Vector3.zero)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2 + 0.3
		Kit.log(map, Vector3.new(math.cos(a) * 9, 0, math.sin(a) * 9), 6, -a)
	end
	Kit.cabin(map, CFrame.new(LODGE) * CFrame.Angles(0, math.pi, 0), 34, 22, 12, true, rng)
	Kit.sign(map, CFrame.new(LODGE + Vector3.new(0, 0, 16)), "MAIN LODGE")
	for _, p in { Vector3.new(-20, 0, -26), Vector3.new(22, 0, -28) } do
		Kit.barrel(map, p)
		Kit.crate(map, p + Vector3.new(3, 0, 1), 3, rng:NextNumber(0, 1))
	end

	-- the cabins
	for i, cabin in CABINS do
		Kit.cabin(
			map,
			CFrame.new(cabin[1]) * CFrame.Angles(0, math.rad(cabin[2]), 0),
			16,
			12,
			9,
			cabin[3],
			rng
		)
		if i % 2 == 0 then
			Kit.stain(
				map,
				cabin[1] + Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10)),
				3,
				rng
			)
		end
	end
	Kit.fence(map, Vector3.new(-40, 0, -14), Vector3.new(-40, 0, 16))
	Kit.fence(map, Vector3.new(-150, 0, -50), Vector3.new(-120, 0, -80))

	-- the lake: dock, canoes, a stain on the planks
	Kit.dock(map, DOCK.from, DOCK.to, 6, 0.4)
	Kit.canoe(map, CFrame.new(44, 0, 62) * CFrame.Angles(0, math.rad(20), 0))
	Kit.canoe(map, CFrame.new(100, -2.6, 72) * CFrame.Angles(0.1, math.rad(70), 0.25)) -- drifting, half sunk
	Kit.stain(map, DOCK.to + Vector3.new(-3, 0.5, 0), 2.5, rng)
	Kit.crate(map, DOCK.from + Vector3.new(-4, 0, 5), 3, 0.3)

	-- the ranger tower and hut on the trail
	Kit.watchtower(map, RANGER_TOWER, 26)
	Kit.cabin(map, CFrame.new(RANGER_HUT) * CFrame.Angles(0, math.pi, 0), 14, 10, 8, true, rng)
	Kit.sign(map, CFrame.new(0, 0, 165), "CAMP WHISPERING PINES")

	-- fallen logs and a few stains along the trail
	for _, p in
		{
			Vector3.new(-40, 0, 20),
			Vector3.new(60, 0, -20),
			Vector3.new(-120, 0, 120),
			Vector3.new(130, 0, -150),
		}
	do
		Kit.log(map, p, rng:NextNumber(10, 16), rng:NextNumber(0, math.pi))
	end
	Kit.stain(map, Vector3.new(-12, 0, 70), 3, rng)

	-- hiding sheds
	for i, p in HIDING do
		Kit.hidingShed(map, CFrame.new(p) * CFrame.Angles(0, i * 1.3, 0))
	end
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
	for _, p in ForestCamp.TOWERS do
		Kit.marker(map, "TowerSpot", p)
	end
	for _, p in ForestCamp.HELI do
		Kit.marker(map, "HeliZone", p)
	end
end

-- Builds the map into `map` (an empty Model already in the workspace).
function ForestCamp.build(map: Model)
	terrain()
	camp(map)
	trees(map)
	lanterns(map)
	spots(map)
	Kit.boundary(map, ForestCamp.SIZE)
end

return ForestCamp
