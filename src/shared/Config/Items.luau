--!strict
-- Everything in the coin shop. Weapons are side-grades (different, not stronger overall), and
-- zombie skins are looks only. Price 0 = starter item, always owned. All (tune).
-- Robux items (premium skins, VIP) come later and will never change combat stats.
local Weapons = require("./Weapons")

local Items = {}

Items.tabs = {
	{ id = "Weapons", name = "WEAPONS" },
	{ id = "Skins", name = "ZOMBIE SKINS" },
}

-- equip slots (match Profile.equipped)
Items.slots = {
	hunterGun = "HUNTER GUN",
	hunterMelee = "HUNTER MELEE",
	zombieSkin = "ZOMBIE SKIN",
}

Items.list = {
	-- Hunter guns
	Revolver = {
		name = "REVOLVER",
		tab = "Weapons",
		slot = "hunterGun",
		price = 0,
		line = "Six shots. Reliable.",
		stats = Weapons.Revolver,
	},
	LeverRifle = {
		name = "LEVER RIFLE",
		tab = "Weapons",
		slot = "hunterGun",
		price = 400,
		line = "Hits hard, far. Slow to fire, 5 shots.",
		stats = { damage = 50, fireInterval = 0.9, mag = 5, reserve = 30, range = 260, reloadTime = 2 },
	},
	RustySMG = {
		name = "RUSTY SMG",
		tab = "Weapons",
		slot = "hunterGun",
		price = 600,
		line = "Sprays fast, weak and short range.",
		stats = { damage = 12, fireInterval = 0.15, mag = 20, reserve = 80, range = 120, reloadTime = 1.8 },
	},
	-- Hunter melee
	Bat = {
		name = "BAT",
		tab = "Weapons",
		slot = "hunterMelee",
		price = 0,
		line = "Pushes zombies back.",
		stats = Weapons.Melee,
	},
	Shovel = {
		name = "SHOVEL",
		tab = "Weapons",
		slot = "hunterMelee",
		price = 250,
		line = "Heavier hit, slower swing.",
		stats = { damage = 22, interval = 1.1, range = 7.5 },
	},
	Crowbar = {
		name = "CROWBAR",
		tab = "Weapons",
		slot = "hunterMelee",
		price = 250,
		line = "Quick swings, shorter reach.",
		stats = { damage = 11, interval = 0.55, range = 6 },
	},
	-- Zombie skins: body color + eye glow as { r, g, b } (basic zombie, and the Alpha's face when
	-- revealed). Plain numbers so the shop rules run outside Roblox.
	Rotten = {
		name = "ROTTEN",
		tab = "Skins",
		slot = "zombieSkin",
		price = 0,
		line = "The classic grey-green.",
		skin = { 118, 156, 96 },
		eyes = { 163, 234, 200 },
	},
	PaleGhoul = {
		name = "PALE GHOUL",
		tab = "Skins",
		slot = "zombieSkin",
		price = 150,
		line = "White as a sheet, ice-blue eyes.",
		skin = { 214, 214, 205 },
		eyes = { 156, 200, 255 },
	},
	BogMint = {
		name = "BOG MINT",
		tab = "Skins",
		slot = "zombieSkin",
		price = 150,
		line = "Fresh from the swamp.",
		skin = { 90, 170, 140 },
		eyes = { 255, 224, 138 },
	},
	BruisedPlum = {
		name = "BRUISED PLUM",
		tab = "Skins",
		slot = "zombieSkin",
		price = 200,
		line = "Purple and very unhappy.",
		skin = { 110, 80, 130 },
		eyes = { 255, 143, 184 },
	},
	CandyCorpse = {
		name = "CANDY CORPSE",
		tab = "Skins",
		slot = "zombieSkin",
		price = 300,
		line = "Cute. Still wants your brain.",
		skin = { 255, 170, 200 },
		eyes = { 163, 234, 200 },
	},
}

-- display order in the shop
Items.order = {
	"Revolver",
	"LeverRifle",
	"RustySMG",
	"Bat",
	"Shovel",
	"Crowbar",
	"Rotten",
	"PaleGhoul",
	"BogMint",
	"BruisedPlum",
	"CandyCorpse",
}

function Items.get(id: any): any
	return if type(id) == "string" then (Items.list :: any)[id] else nil
end

return Items
