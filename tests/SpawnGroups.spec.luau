local lib = require("./lib")
local test, expect = lib.test, lib.expect
local SpawnGroups = require("../src/shared/Rules/SpawnGroups")
local Rng = require("../src/shared/Rng")

-- 7 spots spread over a 360-stud map
local SPOTS = {
	{ x = 0, z = 150 },
	{ x = 150, z = 0 },
	{ x = -150, z = 0 },
	{ x = 0, z = -110 },
	{ x = -60, z = 110 },
	{ x = 100, z = -20 },
	{ x = 40, z = 130 },
}

local function ids(n)
	local list = {}
	for i = 1, n do
		list[i] = i
	end
	return list
end

local function groupSizes(assignment)
	local sizes = {}
	for _, spot in assignment do
		sizes[spot] = (sizes[spot] or 0) + 1
	end
	local list = {}
	for _, n in sizes do
		table.insert(list, n)
	end
	table.sort(list)
	return list
end

test("8 players: 4 groups of 2 at 4 different spots", function()
	local a = SpawnGroups.assign(ids(8), SPOTS, Rng.new(1))
	expect(groupSizes(a)).toEqual({ 2, 2, 2, 2 })
end)

test("odd counts: groups of 2 and one of 3", function()
	expect(groupSizes(SpawnGroups.assign(ids(5), SPOTS, Rng.new(2)))).toEqual({ 2, 3 })
	expect(groupSizes(SpawnGroups.assign(ids(3), SPOTS, Rng.new(2)))).toEqual({ 3 })
end)

test("everyone gets a spot; more groups than spots share the spots", function()
	local a = SpawnGroups.assign(ids(20), SPOTS, Rng.new(3))
	local n = 0
	for id, spot in a do
		n += 1
		expect(spot >= 1 and spot <= #SPOTS).toBeTruthy()
	end
	expect(n).toBe(20)
	expect(#groupSizes(a)).toBe(#SPOTS)
end)

test("a map with one start spot: everyone starts together", function()
	local a = SpawnGroups.assign(ids(6), { { x = 0, z = 0 } }, Rng.new(4))
	expect(groupSizes(a)).toEqual({ 6 })
end)

test("groups land on spots far apart", function()
	local a = SpawnGroups.assign(ids(6), SPOTS, Rng.new(5))
	local used = {}
	for _, spot in a do
		used[spot] = true
	end
	local list = {}
	for spot in used do
		table.insert(list, SPOTS[spot])
	end
	for i = 1, #list do
		for j = i + 1, #list do
			local d = math.sqrt((list[i].x - list[j].x) ^ 2 + (list[i].z - list[j].z) ^ 2)
			expect(d >= SpawnGroups.MIN_DISTANCE).toBeTruthy()
		end
	end
end)

test("who starts with whom changes from round to round", function()
	local rng = Rng.new(6)
	local first = SpawnGroups.assign(ids(8), SPOTS, rng)
	local changed = false
	for _ = 1, 5 do
		local next = SpawnGroups.assign(ids(8), SPOTS, rng)
		for id = 2, 8 do
			if (first[1] == first[id]) ~= (next[1] == next[id]) then
				changed = true
			end
		end
	end
	expect(changed).toBe(true)
end)
