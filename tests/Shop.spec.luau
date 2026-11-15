local lib = require("./lib")
local test, expect = lib.test, lib.expect
local Profile = require("../src/shared/Data/Profile")
local Shop = require("../src/shared/Data/Shop")
local Items = require("../src/shared/Config/Items")
local Weapons = require("../src/shared/Config/Weapons")

local function rich(coins)
	local p = Profile.new()
	p.coins = coins
	return p
end

test("buying takes the price and the item is owned", function()
	local p = rich(500)
	expect(Shop.buy(p, "LeverRifle")).toBe(true)
	expect(p.coins).toBe(100)
	expect(Shop.owns(p, "LeverRifle")).toBe(true)
end)

test("not enough coins: refused, nothing changes", function()
	local p = rich(100)
	local ok, why = Shop.buy(p, "RustySMG")
	expect(ok).toBe(false)
	expect(why).toBe("coins")
	expect(p.coins).toBe(100)
	expect(Shop.owns(p, "RustySMG")).toBe(false)
end)

test("buying an owned item (or a starter) is refused", function()
	local p = rich(1000)
	Shop.buy(p, "Shovel")
	local ok, why = Shop.buy(p, "Shovel")
	expect(ok).toBe(false)
	expect(why).toBe("owned")
	expect(p.coins).toBe(750)
	expect(select(2, Shop.buy(p, "Revolver"))).toBe("owned")
	expect(select(2, Shop.buy(p, "Nope"))).toBe("unknown")
end)

test("equip: only owned items, into their own slot", function()
	local p = rich(1000)
	expect(select(2, Shop.equip(p, "PaleGhoul"))).toBe("not_owned")
	Shop.buy(p, "PaleGhoul")
	expect(Shop.equip(p, "PaleGhoul")).toBe(true)
	expect(p.equipped.zombieSkin).toBe("PaleGhoul")
	expect(p.equipped.hunterGun).toBe("Revolver") -- other slots untouched
	expect(Shop.equip(p, "Bat")).toBe(true) -- starters are always owned
end)

test("a broken save falls back to the starter item", function()
	local p = rich(0)
	p.equipped.hunterGun = "RustySMG" -- not owned
	p.equipped.hunterMelee = "Rotten" -- wrong slot
	p.equipped.zombieSkin = "Deleted" -- doesn't exist
	expect(Shop.equipped(p, "hunterGun")).toBe("Revolver")
	expect(Shop.equipped(p, "hunterMelee")).toBe("Bat")
	expect(Shop.equipped(p, "zombieSkin")).toBe("Rotten")
	expect(Shop.equipped(nil, "hunterGun")).toBe("Revolver")
end)

test("every item is complete, in the shop order, and starters cost 0", function()
	local seen = {}
	for _, id in Items.order do
		local item = Items.get(id)
		expect(item ~= nil).toBeTruthy()
		expect(Items.slots[item.slot] ~= nil).toBeTruthy()
		expect(item.price >= 0).toBeTruthy()
		seen[id] = true
	end
	for id in Items.list do
		expect(seen[id]).toBe(true)
	end
	for slot, id in Profile.DEFAULT_EQUIPPED do
		if Items.slots[slot] then
			expect(Items.get(id).price).toBe(0)
		end
	end
end)

test("guns are side-grades: no gun beats the Revolver on damage per second AND range", function()
	local base = Weapons.Revolver
	local baseDps = base.damage / base.fireInterval
	for _, id in Items.order do
		local item = Items.get(id)
		if item.slot == "hunterGun" and id ~= "Revolver" then
			local dps = item.stats.damage / item.stats.fireInterval
			expect(dps > baseDps and item.stats.range > base.range).toBe(false)
		end
	end
end)
