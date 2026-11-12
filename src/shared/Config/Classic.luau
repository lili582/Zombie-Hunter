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
	-- Phase 2: objectives (tune)
	towersOnMap = 5, -- picked from the map's tower spots each round
	towersNeeded = 3, -- repaired towers needed to call the helicopter
	towerMinDistance = 60, -- studs between picked towers (relaxed if impossible)
	repairTime = 60, -- seconds for one player to repair a tower
	coopBonus = 0.6, -- each extra repairer adds 60% speed
	repairRange = 10, -- studs: walk further away and the repair stops
	skillBonus = 0.02, -- tower progress for a good skill check
	skillPenalty = 0.08, -- tower progress lost on a failed skill check
	heliInbound = 45, -- seconds from call to landing
	heliLanded = 20, -- seconds the helicopter waits
	heliZoneRadius = 18,
	medkitsPerSurvivor = 1,
	alphaRespawn = 8,
}

function Classic.specialCount(playerCount: number): number
	return if playerCount >= 12 then 2 else 1
end

return Classic
