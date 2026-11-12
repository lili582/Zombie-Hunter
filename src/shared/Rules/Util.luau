--!strict
-- Small pure helpers shared by the rule modules.
local Types = require("../Types")

local Util = {}

function Util.isHumanRole(role: Types.Role): boolean
	return role == "Survivor" or role == "Hunter"
end

function Util.isZombieRole(role: Types.Role): boolean
	return role == "Alpha" or role == "Zombie"
end

-- Player ids in ascending order, so loops are deterministic.
function Util.sortedIds(players: { [number]: Types.PlayerState }): { number }
	local ids = {}
	for id in players do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

function Util.count(players: { [number]: Types.PlayerState }): number
	local n = 0
	for _ in players do
		n += 1
	end
	return n
end

function Util.newPlayer(id: number): Types.PlayerState
	return {
		id = id,
		role = "Survivor",
		life = "Alive",
		hitsTaken = 0,
		bleedLeft = nil,
		downedBy = nil,
		reviverId = nil,
		reviveProgress = 0,
		points = 0,
		wasInfected = false,
		infections = 0,
	}
end

-- Copy of the round state that can be changed freely (config and rng are shared).
function Util.cloneState(s: Types.RoundState): Types.RoundState
	local players = {}
	for id, p in s.players do
		players[id] = table.clone(p)
	end
	local lastHits = {}
	for victim, attackers in s.lastHits do
		lastHits[victim] = table.clone(attackers)
	end
	local pending = {}
	for victim, list in s.pendingAssists do
		pending[victim] = table.clone(list)
	end
	local copy = table.clone(s)
	copy.players = players
	copy.sinceSpecial = table.clone(s.sinceSpecial)
	copy.lastHits = lastHits
	copy.pendingAssists = pending
	return copy
end

return Util
