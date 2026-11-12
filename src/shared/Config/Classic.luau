--!strict
-- Classic mode numbers. All (tune).
local Classic = {
	mapName = "ABANDONED TOWN",
	mapLine = "the lights went out at midnight",
	minPlayers = 5,
	intermission = 20,
	headStart = 10,
	roundLength = 360,
	results = 15,
	bleedOut = 20,
	reviveTime = 4,
	hitsToDown = { Alpha = 2, Zombie = 3 } :: { [string]: number },
	zombieRespawn = 5,
	alphaRespawn = 8,
}

function Classic.specialCount(playerCount: number): number
	return if playerCount >= 12 then 2 else 1
end

return Classic
