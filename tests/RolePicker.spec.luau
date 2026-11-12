local lib = require("./lib")
local test, expect = lib.test, lib.expect
local RolePicker = require("../src/shared/Rules/RolePicker")
local Rng = require("../src/shared/Rng")

test("8 players: 1 Alpha, 1 Hunter, 6 Survivors", function()
	local roles = RolePicker.pick({ 1, 2, 3, 4, 5, 6, 7, 8 }, {}, Rng.new(1))
	local counts = { Alpha = 0, Hunter = 0, Survivor = 0 }
	for _, r in roles do
		counts[r] += 1
	end
	expect(counts).toEqual({ Alpha = 1, Hunter = 1, Survivor = 6 })
end)

test("12 players: 2 Alphas, 2 Hunters", function()
	local ids = {}
	for i = 1, 12 do
		ids[i] = i
	end
	local counts = { Alpha = 0, Hunter = 0, Survivor = 0 }
	for _, r in RolePicker.pick(ids, {}, Rng.new(1)) do
		counts[r] += 1
	end
	expect(counts).toEqual({ Alpha = 2, Hunter = 2, Survivor = 8 })
end)

test("last round's special player is picked less often", function()
	local rng, hits = Rng.new(3), 0
	for _ = 1, 1000 do
		local roles = RolePicker.pick({ 1, 2, 3, 4, 5, 6, 7, 8 }, { [1] = 0 }, rng)
		if roles[1] ~= "Survivor" then
			hits += 1
		end
	end
	expect(hits < 250).toBeTruthy() -- fair share would be 250 (2 of 8)
end)

test("replacement alpha comes from the candidates", function()
	local id = RolePicker.pickReplacementAlpha({ 4, 7 }, Rng.new(5))
	expect(id == 4 or id == 7).toBeTruthy()
	expect(RolePicker.pickReplacementAlpha({}, Rng.new(5))).toBeNil()
end)
