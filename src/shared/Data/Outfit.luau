--!strict
-- A player's in-game character (VH2-style): body colours, face, shirt, pants, T-shirt and
-- accessories, all Roblox catalog asset ids. Saved in the profile, built into a
-- HumanoidDescription by the server. Pure: the server checks each asset's type with Roblox,
-- these rules decide what may be worn and where.
--
-- New players get the DEFAULT character (classic 2014 look) until they change it.
local Outfit = {}

export type Rgb = { number }
export type Outfit = {
	colors: { [string]: Rgb }, -- head, torso, leftArm, rightArm, leftLeg, rightLeg
	face: number, -- 0 = Roblox's default face
	shirt: number,
	pants: number,
	tshirt: number,
	accessories: { { id: number, slot: string } },
}

Outfit.PARTS = { "head", "torso", "leftArm", "rightArm", "leftLeg", "rightLeg" }
Outfit.MAX_ACCESSORIES = 8
Outfit.MAX_PER_SLOT = 3

-- Roblox AssetTypeId -> where it goes. Only classic (R6-friendly) items: layered clothing,
-- bundles, heads and body parts are refused.
Outfit.TYPES = {
	[8] = "Hat",
	[41] = "Hair",
	[42] = "Face", -- face accessory (glasses, masks)
	[43] = "Neck",
	[44] = "Shoulders",
	[45] = "Front",
	[46] = "Back",
	[47] = "Waist",
	[11] = "shirt",
	[12] = "pants",
	[2] = "tshirt",
	[18] = "face",
}

-- accessory slot -> HumanoidDescription property
Outfit.ACCESSORY_PROPS = {
	Hat = "HatAccessory",
	Hair = "HairAccessory",
	Face = "FaceAccessory",
	Neck = "NeckAccessory",
	Shoulders = "ShouldersAccessory",
	Front = "FrontAccessory",
	Back = "BackAccessory",
	Waist = "WaistAccessory",
}

-- Body colours you can pick (pastel + classic 2014 bricks + skin tones).
Outfit.PALETTE = {
	{ 245, 205, 48 }, -- bright yellow (classic)
	{ 13, 105, 172 }, -- bright blue (classic)
	{ 164, 189, 71 }, -- yellowish green (classic)
	{ 255, 204, 153 },
	{ 234, 184, 146 },
	{ 204, 142, 105 },
	{ 160, 95, 53 },
	{ 105, 64, 40 },
	{ 52, 36, 26 },
	{ 248, 248, 248 },
	{ 163, 162, 165 },
	{ 27, 42, 53 },
	{ 17, 17, 17 },
	{ 196, 40, 28 },
	{ 255, 143, 184 },
	{ 191, 169, 242 },
	{ 156, 200, 255 },
	{ 163, 234, 200 },
	{ 255, 224, 138 },
	{ 255, 199, 154 },
	{ 58, 40, 86 },
	{ 40, 127, 71 },
	{ 218, 133, 65 },
	{ 107, 50, 124 },
}

local DEFAULT_COLORS = {
	head = { 245, 205, 48 },
	torso = { 13, 105, 172 },
	leftArm = { 245, 205, 48 },
	rightArm = { 245, 205, 48 },
	leftLeg = { 164, 189, 71 },
	rightLeg = { 164, 189, 71 },
}

function Outfit.default(): Outfit
	local colors = {}
	for part, rgb in DEFAULT_COLORS do
		colors[part] = table.clone(rgb)
	end
	return { colors = colors, face = 0, shirt = 0, pants = 0, tshirt = 0, accessories = {} }
end

local function validId(v: any): boolean
	return type(v) == "number" and v == v and v >= 0 and v % 1 == 0 and v < 1e15
end

local function validRgb(v: any): boolean
	if type(v) ~= "table" or #v ~= 3 then
		return false
	end
	for i = 1, 3 do
		local c = v[i]
		if type(c) ~= "number" or c ~= c or c < 0 or c > 255 then
			return false
		end
	end
	return true
end

-- Any saved value -> a valid outfit (missing or broken parts fall back to the default).
function Outfit.migrate(raw: any): Outfit
	local o = Outfit.default()
	if type(raw) ~= "table" then
		return o
	end
	if type(raw.colors) == "table" then
		for _, part in Outfit.PARTS do
			if validRgb(raw.colors[part]) then
				o.colors[part] = {
					math.floor(raw.colors[part][1]),
					math.floor(raw.colors[part][2]),
					math.floor(raw.colors[part][3]),
				}
			end
		end
	end
	for _, key in { "face", "shirt", "pants", "tshirt" } do
		if validId(raw[key]) then
			(o :: any)[key] = raw[key]
		end
	end
	if type(raw.accessories) == "table" then
		for _, a in raw.accessories do
			if
				type(a) == "table"
				and validId(a.id)
				and a.id > 0
				and Outfit.ACCESSORY_PROPS[a.slot] ~= nil
				and #o.accessories < Outfit.MAX_ACCESSORIES
			then
				table.insert(o.accessories, { id = a.id, slot = a.slot })
			end
		end
	end
	return o
end

local function countSlot(o: Outfit, slot: string): number
	local n = 0
	for _, a in o.accessories do
		if a.slot == slot then
			n += 1
		end
	end
	return n
end

function Outfit.wears(o: Outfit, id: number): boolean
	if o.face == id or o.shirt == id or o.pants == id or o.tshirt == id then
		return id ~= 0
	end
	for _, a in o.accessories do
		if a.id == id then
			return true
		end
	end
	return false
end

-- Puts an item on. `typeId` is the Roblox AssetTypeId (checked by the server).
-- Returns (true, nil) or (false, reason): "type" (not allowed) | "full" (too many accessories)
-- | "worn" (already on). Clothing and faces replace what was there.
function Outfit.wear(o: Outfit, id: number, typeId: number): (boolean, string?)
	local slot = Outfit.TYPES[typeId]
	if not slot or not validId(id) or id == 0 then
		return false, "type"
	end
	if Outfit.wears(o, id) then
		return false, "worn"
	end
	if Outfit.ACCESSORY_PROPS[slot] then
		if #o.accessories >= Outfit.MAX_ACCESSORIES then
			return false, "full"
		end
		if countSlot(o, slot) >= Outfit.MAX_PER_SLOT then
			-- swap out the oldest one in that slot
			for i, a in o.accessories do
				if a.slot == slot then
					table.remove(o.accessories, i)
					break
				end
			end
		end
		table.insert(o.accessories, { id = id, slot = slot })
	else
		(o :: any)[slot] = id
	end
	return true, nil
end

-- Takes an item off. Returns true if it was worn.
function Outfit.remove(o: Outfit, id: number): boolean
	for _, key in { "face", "shirt", "pants", "tshirt" } do
		if (o :: any)[key] == id and id ~= 0 then
			(o :: any)[key] = 0
			return true
		end
	end
	for i, a in o.accessories do
		if a.id == id then
			table.remove(o.accessories, i)
			return true
		end
	end
	return false
end

-- Colours one body part ("all", "arms" and "legs" colour several) with a palette colour.
function Outfit.setColor(o: Outfit, part: string, paletteIndex: number): boolean
	local rgb = Outfit.PALETTE[paletteIndex]
	if not rgb then
		return false
	end
	local parts = if part == "all"
		then Outfit.PARTS
		elseif part == "arms" then { "leftArm", "rightArm" }
		elseif part == "legs" then { "leftLeg", "rightLeg" }
		else { part }
	for _, p in parts do
		if not table.find(Outfit.PARTS, p) then
			return false
		end
	end
	for _, p in parts do
		o.colors[p] = table.clone(rgb)
	end
	return true
end

-- The HumanoidDescription properties for this outfit (plain values; the server sets them).
function Outfit.descriptionProps(o: Outfit): { [string]: any }
	local props: { [string]: any } = {
		Face = o.face,
		Shirt = o.shirt,
		Pants = o.pants,
		GraphicTShirt = o.tshirt,
	}
	local lists: { [string]: { string } } = {}
	for _, a in o.accessories do
		local prop = Outfit.ACCESSORY_PROPS[a.slot]
		lists[prop] = lists[prop] or {}
		table.insert(lists[prop], tostring(a.id))
	end
	for _, prop in Outfit.ACCESSORY_PROPS do
		props[prop] = table.concat(lists[prop] or {}, ",")
	end
	local names = {
		head = "HeadColor",
		torso = "TorsoColor",
		leftArm = "LeftArmColor",
		rightArm = "RightArmColor",
		leftLeg = "LeftLegColor",
		rightLeg = "RightLegColor",
	}
	for part, prop in names do
		props[prop] = o.colors[part]
	end
	return props
end

return Outfit
