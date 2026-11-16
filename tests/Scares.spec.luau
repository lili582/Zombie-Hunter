local lib = require("./lib")
local test, expect = lib.test, lib.expect
local Scares = require("../src/shared/Rules/Scares")

local function v(x: number, y: number, z: number)
	return { X = x, Y = y, Z = z }
end

local EYE = v(0, 5, 0)
local NORTH = v(0, 0, -1)

test("a figure 60 studs ahead and a little to the side is a good spot", function()
	local spot = v(40, 0, -60)
	expect(Scares.pickSpot({ spot }, EYE, NORTH, 0)).toBe(spot)
end)

test("no figure right where you are looking (you'd see it appear)", function()
	expect(Scares.pickSpot({ v(0, 0, -60) }, EYE, NORTH, 0)).toBe(nil)
end)

test("no figure behind you, too close or lost in the fog", function()
	expect(Scares.pickSpot({ v(30, 0, 60) }, EYE, NORTH, 0)).toBe(nil)
	expect(Scares.pickSpot({ v(15, 0, -20) }, EYE, NORTH, 0)).toBe(nil)
	expect(Scares.pickSpot({ v(120, 0, -200) }, EYE, NORTH, 0)).toBe(nil)
end)

test("the roll picks among the spots that fit", function()
	local a, b = v(40, 0, -60), v(-40, 0, -60)
	local spots = { a, v(0, 0, 90), b }
	expect(Scares.pickSpot(spots, EYE, NORTH, 0)).toBe(a)
	expect(Scares.pickSpot(spots, EYE, NORTH, 0.99)).toBe(b)
end)

test("looking straight at the figure's head counts as seeing it", function()
	local feet = v(40, 0, -60)
	local head = v(40, Scares.FIGURE_HEAD, -60)
	local look = v(head.X - EYE.X, head.Y - EYE.Y, head.Z - EYE.Z)
	expect(Scares.isSeen(EYE, look, feet)).toBe(true)
end)

test("seeing it from the corner of your eye does not make it vanish", function()
	expect(Scares.isSeen(EYE, NORTH, v(40, 0, -60))).toBe(false)
end)

test("figures come every 40-90s, thunder every 110-190s", function()
	expect(Scares.figureDelay(0)).toBe(40)
	expect(Scares.figureDelay(0.999) < 90).toBe(true)
	expect(Scares.thunderDelay(0)).toBe(110)
	expect(Scares.thunderDelay(0.999) < 190).toBe(true)
end)
