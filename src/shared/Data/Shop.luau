--!strict
-- Buying and equipping coin items on a profile. Pure: the server checks *when* you may shop
-- (in the lobby, not while playing a round) and saves the result.
local Items = require("../Config/Items")
local Profile = require("./Profile")

local Shop = {}

function Shop.owns(p: Profile.Profile, id: string): boolean
	local item = Items.get(id)
	return item ~= nil and (item.price == 0 or p.owned[id] == true)
end

-- Returns (true, nil) or (false, reason): "unknown" | "owned" | "coins" (not enough).
function Shop.buy(p: Profile.Profile, id: string): (boolean, string?)
	local item = Items.get(id)
	if not item then
		return false, "unknown"
	end
	if Shop.owns(p, id) then
		return false, "owned"
	end
	if p.coins < item.price then
		return false, "coins"
	end
	p.coins -= item.price
	p.owned[id] = true
	return true, nil
end

-- Returns (true, nil) or (false, reason): "unknown" | "not_owned".
function Shop.equip(p: Profile.Profile, id: string): (boolean, string?)
	local item = Items.get(id)
	if not item then
		return false, "unknown"
	end
	if not Shop.owns(p, id) then
		return false, "not_owned"
	end
	(p.equipped :: any)[item.slot] = id
	return true, nil
end

-- The equipped item id for a slot, falling back to the starter if the save points to an item
-- that doesn't exist (any more) or isn't owned.
function Shop.equipped(p: Profile.Profile?, slot: string): string
	local id = if p then (p.equipped :: any)[slot] else nil
	if p and id and Shop.owns(p, id) and Items.get(id).slot == slot then
		return id
	end
	return (Profile.DEFAULT_EQUIPPED :: any)[slot]
end

return Shop
