local lib = require("./lib")
local test, expect = lib.test, lib.expect
local Outfit = require("../src/shared/Data/Outfit")
local Profile = require("../src/shared/Data/Profile")

local HAT, HAIR, SHIRT, PANTS, FACE, LAYERED = 8, 41, 11, 12, 18, 65

test("new players haven't picked a look: they get a boy or girl starter by user id", function()
	expect(Profile.new().outfitPicked).toBe(false)
	expect(Outfit.starterFor(2)).toBe("Boy")
	expect(Outfit.starterFor(3)).toBe("Girl")
	local girl = Outfit.starter("Girl")
	expect(girl.colors.head).toEqual(Outfit.STARTERS.Girl.skin)
	expect(girl.colors.torso).toEqual(Outfit.STARTERS.Girl.torso)
	expect(girl.colors.leftLeg).toEqual(Outfit.STARTERS.Girl.legs)
	expect(Outfit.starter("Nope").colors.torso).toEqual(Outfit.STARTERS.Boy.torso)
	expect(Profile.migrate({ outfitPicked = true }).outfitPicked).toBe(true)
end)

test("wearing: clothing replaces, accessories stack", function()
	local o = Outfit.default()
	expect(Outfit.wear(o, 101, SHIRT)).toBe(true)
	expect(Outfit.wear(o, 102, SHIRT)).toBe(true)
	expect(o.shirt).toBe(102)
	expect(Outfit.wear(o, 201, HAT)).toBe(true)
	expect(Outfit.wear(o, 202, HAIR)).toBe(true)
	expect(#o.accessories).toBe(2)
	expect(Outfit.wears(o, 201)).toBe(true)
	expect(select(2, Outfit.wear(o, 201, HAT))).toBe("worn")
end)

test("layered clothing, body parts and unknown types are refused", function()
	local o = Outfit.default()
	expect(select(2, Outfit.wear(o, 5, LAYERED))).toBe("type")
	expect(select(2, Outfit.wear(o, 6, 27))).toBe("type") -- torso
	expect(select(2, Outfit.wear(o, 0, SHIRT))).toBe("type")
end)

test("limits: 3 per slot (oldest swapped out), 8 in total", function()
	local o = Outfit.default()
	for id = 1, 4 do
		Outfit.wear(o, id, HAT)
	end
	expect(#o.accessories).toBe(3)
	expect(Outfit.wears(o, 1)).toBe(false) -- the oldest hat came off
	expect(Outfit.wears(o, 4)).toBe(true)
	for id = 10, 14 do
		Outfit.wear(o, id, 41 + (id - 10) % 3) -- hair / face / neck accessories
	end
	expect(#o.accessories).toBe(8)
	expect(select(2, Outfit.wear(o, 99, 46))).toBe("full")
end)

test("remove takes an item off", function()
	local o = Outfit.default()
	Outfit.wear(o, 7, FACE)
	Outfit.wear(o, 8, HAT)
	expect(Outfit.remove(o, 7)).toBe(true)
	expect(o.face).toBe(0)
	expect(Outfit.remove(o, 8)).toBe(true)
	expect(#o.accessories).toBe(0)
	expect(Outfit.remove(o, 123)).toBe(false)
end)

test("body colours: only palette colours, for a part, the arms, legs or all", function()
	local o = Outfit.default()
	expect(Outfit.setColor(o, "torso", 13)).toBe(true)
	expect(o.colors.torso).toEqual(Outfit.PALETTE[13])
	Outfit.setColor(o, "arms", 4)
	expect(o.colors.leftArm).toEqual(Outfit.PALETTE[4])
	expect(o.colors.rightArm).toEqual(Outfit.PALETTE[4])
	Outfit.setColor(o, "all", 10)
	expect(o.colors.leftLeg).toEqual(Outfit.PALETTE[10])
	expect(Outfit.setColor(o, "torso", 999)).toBe(false)
	expect(Outfit.setColor(o, "tail", 1)).toBe(false)
end)

test("description properties list the accessories per slot", function()
	local o = Outfit.default()
	Outfit.wear(o, 11, HAT)
	Outfit.wear(o, 12, HAT)
	Outfit.wear(o, 13, HAIR)
	Outfit.wear(o, 14, PANTS)
	local props = Outfit.descriptionProps(o)
	expect(props.HatAccessory).toBe("11,12")
	expect(props.HairAccessory).toBe("13")
	expect(props.BackAccessory).toBe("")
	expect(props.Pants).toBe(14)
	expect(props.HeadColor).toEqual(Outfit.STARTERS.Boy.skin)
end)

test("broken saves load as a valid outfit", function()
	local o = Outfit.migrate({
		colors = { head = { 1, 2, 3 }, torso = { 999, 0, 0 }, leftArm = "red" },
		shirt = -5,
		pants = 42,
		accessories = { { id = 5, slot = "Hat" }, { id = 6, slot = "Tail" }, "junk" },
	})
	expect(o.colors.head).toEqual({ 1, 2, 3 })
	expect(o.colors.torso).toEqual(Outfit.STARTERS.Boy.torso) -- broken: default
	expect(o.shirt).toBe(0)
	expect(o.pants).toBe(42)
	expect(#o.accessories).toBe(1)
	expect(Profile.migrate({}).outfit.colors.head).toEqual(Outfit.STARTERS.Boy.skin)
end)
