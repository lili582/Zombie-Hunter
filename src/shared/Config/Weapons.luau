--!strict
-- Weapon and character numbers. All (tune).
return {
	Revolver = { damage = 35, fireInterval = 0.5, mag = 6, reserve = 36, range = 200, reloadTime = 1.5 },
	-- Outbreak: every Survivor gets one. Weaker than the Hunter's revolver.
	Pistol = { damage = 20, fireInterval = 0.6, mag = 8, reserve = 24, range = 150, reloadTime = 1.3 },
	Melee = { damage = 15, interval = 0.8, range = 7 },
	Claw = { interval = 0.9, range = 6 },
	-- Survivor escape timing (click while the needle is in the zone)
	Dodge = {
		window = 1.0, -- seconds the needle takes to cross the bar
		zoneSize = 0.22, -- share of the bar that counts as a good click
		tolerance = 0.2, -- how far the client's claimed position may be from the server's estimate
		boostSpeed = 26, -- run speed right after escaping
		boostTime = 1.5,
		immunity = 1.2, -- seconds after an escape in which new claws miss
		skillZoneSize = 0.18, -- tower skill checks use a slightly smaller zone
		skillEvery = { 6, 12 }, -- seconds between skill checks while repairing
	},
	AlphaReveal = { seconds = 3 }, -- how long the Alpha's zombie face shows after an attack
	AmmoBox = { amount = 12, respawn = 30 },
	health = { human = 100, basic = 100, alpha = 350 },
	speed = { human = 16, downed = 3, basic = 14, alpha = 18 },
}
