local lib = require("./lib")
local test, expect = lib.test, lib.expect
local HitValidation = require("../src/shared/Rules/HitValidation")

local function shot(over)
	local input = { role = "Hunter", distance = 10, sinceLastShot = 1, ammoInMag = 6 }
	for k, v in over do
		input[k] = v
	end
	return HitValidation.shot(input)
end

test("a normal Hunter shot is allowed", function()
	expect(shot({})).toBe(true)
end)

test("survivors cannot shoot", function()
	local ok, why = shot({ role = "Survivor" })
	expect(ok).toBe(false)
	expect(why).toBe("not_hunter")
end)

test("shot beyond 200 studs is refused", function()
	local _, why = shot({ distance = 201 })
	expect(why).toBe("out_of_range")
end)

test("shooting faster than 0.5s is refused", function()
	local _, why = shot({ sinceLastShot = 0.3 })
	expect(why).toBe("too_fast")
end)

test("empty magazine is refused", function()
	local _, why = shot({ ammoInMag = 0 })
	expect(why).toBe("no_ammo")
end)

test("claw from a survivor or beyond 6 studs is refused", function()
	expect((HitValidation.claw({ role = "Survivor", distance = 2, sinceLast = 5 }))).toBe(false)
	expect((HitValidation.claw({ role = "Zombie", distance = 7, sinceLast = 5 }))).toBe(false)
	expect((HitValidation.claw({ role = "Alpha", distance = 5, sinceLast = 5 }))).toBe(true)
	expect((HitValidation.claw({ role = "Zombie", distance = 5, sinceLast = 0.5 }))).toBe(false)
end)

test("melee is the Hunter's only, within 7 studs (survivors have no weapons)", function()
	expect((HitValidation.melee({ role = "Hunter", distance = 6, sinceLast = 1 }))).toBe(true)
	expect((HitValidation.melee({ role = "Survivor", distance = 6, sinceLast = 1 }))).toBe(false)
	expect((HitValidation.melee({ role = "Zombie", distance = 6, sinceLast = 1 }))).toBe(false)
	expect((HitValidation.melee({ role = "Hunter", distance = 8, sinceLast = 1 }))).toBe(false)
end)
