--!strict
-- What to save after rule effects: coins at round end and the stat counters
-- (rounds, wins, escapes, survivals, zombie kills, infections, revives, towers, special roles).
-- Pure. Reads the state *after* the effects happened.
local Types = require("../Types")
local Util = require("./Util")
local Scoring = require("./Scoring")

type Reward = { coins: number?, stats: { [string]: number } }

local Rewards = {}

local function add(out: { [number]: Reward }, playerId: number?, stat: string)
	if playerId == nil then
		return
	end
	local r = out[playerId] or { stats = {} }
	r.stats[stat] = (r.stats[stat] or 0) + 1
	out[playerId] = r
end

local function onSide(winner: Types.Winner, p: Types.PlayerState): boolean
	if p.life == "Dead" then
		return false -- killed this round: no win
	end
	if winner == "ZombiesWin" then
		return Util.isZombieRole(p.role)
	elseif winner == "SurvivorsSurvived" or winner == "SurvivorsEscaped" then
		return Util.isHumanRole(p.role)
	end
	return false
end

-- player id -> reward, for every player something happened to.
function Rewards.collect(s: Types.RoundState, effects: { Types.Effect }): { [number]: Reward }
	local out: { [number]: Reward } = {}
	for _, f in effects do
		if f.type == "RolesAssigned" then
			for _, id in Util.sortedIds(s.players) do
				local role = s.players[id].role
				if role == "Hunter" then
					add(out, id, "roundsAsHunter")
				elseif role == "Alpha" then
					add(out, id, "roundsAsAlpha")
				end
			end
		elseif f.type == "BecameAlpha" then
			add(out, f.playerId, "roundsAsAlpha")
		elseif f.type == "NewHunter" then
			add(out, f.playerId, "roundsAsHunter")
		elseif f.type == "Revived" then
			add(out, f.byId, "revives")
		elseif f.type == "ZombieKilled" then
			add(out, f.killerId, "zombieKills")
		elseif f.type == "BecameZombie" then
			add(out, f.byId, "infections")
		elseif f.type == "TowerRepaired" then
			for _, id in f.repairerIds do
				add(out, id, "towersRepaired")
			end
		elseif f.type == "Escaped" then
			add(out, f.playerId, "escapes")
		elseif f.type == "RoundOver" then
			for _, id in Util.sortedIds(s.players) do
				local p = s.players[id]
				if p.life == "Out" then
					continue -- joined mid-round: didn't play it
				end
				add(out, id, "rounds")
				if onSide(f.winner, p) then
					add(out, id, "wins")
				end
				if f.winner == "SurvivorsSurvived" and Util.isHumanRole(p.role) and p.life ~= "Dead" then
					add(out, id, "survivals")
				end
				out[id].coins = Scoring.coins(p.points)
			end
		end
	end
	return out
end

return Rewards
