local lib = require("./lib")
local test, expect = lib.test, lib.expect
local Rng = require("../src/shared/Rng")
local Classic = require("../src/shared/Config/Classic")

test("same seed gives same sequence", function()
	local a, b = Rng.new(42), Rng.new(42)
	for _ = 1, 20 do
		expect(a:int(1, 100)).toBe(b:int(1, 100))
	end
end)

test("int stays in range and hits both ends", function()
	local r, seen = Rng.new(7), {}
	for _ = 1, 2000 do
		local v = r:int(1, 3)
		expect(v >= 1 and v <= 3).toBeTruthy()
		seen[v] = true
	end
	expect(seen[1] and seen[3]).toBeTruthy()
end)

test("float is in [0, 1)", function()
	local r = Rng.new(99)
	for _ = 1, 2000 do
		local f = r:float()
		expect(f >= 0 and f < 1).toBeTruthy()
	end
end)

test("special count is 1 below 12 players and 2 from 12", function()
	expect(Classic.specialCount(11)).toBe(1)
	expect(Classic.specialCount(12)).toBe(2)
end)
