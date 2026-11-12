--!strict
-- Round points from effects, and coins at round end. Pure.
-- `award` works on RoundRules' working copy and returns PointsAwarded effects (for "+points" popups).
local Types = require("../Types")
local Points = require("../Config/Points")
local Util = require("./Util")

type State = Types.RoundState
type Effect = Types.Effect

local Scoring = {}

local function give(s: State, playerId: number?, amount: number, reason: string, out: { Effect })
	if playerId == nil then
		return
	end
	local p = s.players[playerId]
	if not p then
		return
	end
	p.points += amount
	table.insert(out, { type = "PointsAwarded", playerId = playerId, amount = amount, reason = reason })
end

function Scoring.award(s: State, effects: { Effect }): { Effect }
	local out: { Effect } = {}
	for _, f in effects do
		if f.type == "HitLanded" then
			s.lastHits[f.victimId] = s.lastHits[f.victimId] or {}
			s.lastHits[f.victimId][f.attackerId] = s.clock
			give(s, f.attackerId, Points.hit, "HIT", out)
		elseif f.type == "Downed" then
			give(s, f.byId, Points.down, "DOWN", out)
			local assists = {}
			for attackerId, t in s.lastHits[f.playerId] or {} do
				if attackerId ~= f.byId and s.clock - t <= Points.assistWindow + 1e-9 then
					table.insert(assists, attackerId)
				end
			end
			table.sort(assists)
			s.pendingAssists[f.playerId] = assists
			s.lastHits[f.playerId] = nil
		elseif f.type == "Revived" then
			s.pendingAssists[f.playerId] = nil
			give(s, f.byId, Points.revive, "REVIVE", out)
		elseif f.type == "BecameZombie" then
			local by = if f.byId then s.players[f.byId] else nil
			if by then
				give(s, f.byId, Points.infection, "INFECTION", out)
				if by.wasInfected and by.infections == 0 then
					give(s, f.byId, Points.firstInfectionBonus, "FIRST INFECTION", out)
				end
				by.infections += 1
			end
			for _, attackerId in s.pendingAssists[f.playerId] or {} do
				local a = s.players[attackerId]
				if a and Util.isZombieRole(a.role) then
					give(s, attackerId, Points.infectionAssist, "ASSIST", out)
				end
			end
			s.pendingAssists[f.playerId] = nil
		elseif f.type == "RepairPoints" then
			give(s, f.playerId, Points.repairPer10 * f.amount, "REPAIR", out)
		elseif f.type == "TowerRepaired" then
			for _, id in f.repairerIds do
				give(s, id, Points.towerDone, "TOWER REPAIRED", out)
			end
		elseif f.type == "Escaped" then
			give(s, f.playerId, Points.escape, "ESCAPED THE NIGHT", out)
		elseif f.type == "RepairInterrupted" then
			give(s, f.attackerId, Points.interruptRepair, "STOPPED A REPAIR", out)
		elseif f.type == "LeftLocker" and f.pulledBy then
			give(s, f.pulledBy, Points.pullOut, "FOUND SOMEONE HIDING", out)
		elseif f.type == "Healed" and f.playerId ~= f.targetId then
			give(s, f.playerId, Points.heal, "HEALED A FRIEND", out)
		elseif f.type == "Dodged" then
			give(s, f.playerId, Points.dodge, "ESCAPED", out)
		elseif f.type == "NewHunter" then
			give(s, f.playerId, Points.pickUpGun, "PICKED UP THE GUN", out)
		elseif f.type == "ZombieKilled" then
			local v = s.players[f.victimId]
			local alpha = v ~= nil and v.role == "Alpha"
			give(
				s,
				f.killerId,
				if alpha then Points.alphaKill else Points.zombieKill,
				if alpha then "ALPHA KILL" else "ZOMBIE KILL",
				out
			)
		elseif f.type == "RoundOver" then
			for _, id in Util.sortedIds(s.players) do
				local p = s.players[id]
				if p.life == "Out" then
					continue
				end
				if f.winner == "ZombiesWin" and Util.isZombieRole(p.role) then
					give(s, id, Points.teamWin, "ZOMBIES WIN", out)
				elseif
					(f.winner == "SurvivorsSurvived" or f.winner == "SurvivorsEscaped")
					and Util.isHumanRole(p.role)
				then
					give(s, id, Points.teamWin, "TEAM WIN", out)
					if f.winner == "SurvivorsSurvived" then
						give(s, id, Points.survive, "SURVIVED", out)
					end
				end
			end
		end
	end
	return out
end

function Scoring.coins(points: number): number
	return math.max(Points.minCoins, math.floor(points * Points.coinsPerPoint))
end

return Scoring
