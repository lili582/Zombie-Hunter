--!strict
-- Classic mode numbers. All (tune).
local Classic = {
	mapName = "ABANDONED TOWN",
	mapLine = "the lights went out at midnight",
	modeName = "CLASSIC",
	modeLine = "One of you is already infected. Survive 6:00. Trust no one.",
	minPlayers = 5,
	studioMinPlayers = 2, -- used automatically when testing in Roblox Studio
	nameTagDistance = 0, -- studs; 0 = no floating player names or health bars at all
	intermission = 20,
	-- Head start = the intro cards (everyone frozen) + 10s for humans to run before the Alpha
	-- is released. introLength must match the card times in AnnouncementController.
	introLength = 16,
	headStart = 26,
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
