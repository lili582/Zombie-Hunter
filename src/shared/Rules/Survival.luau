--!strict
-- Lockers (hide, leave, zombies search) and the Survivor medkit. Pure.
-- Works on RoundRules' working copy `s`.
local Types = require("../Types")
local Util = require("./Util")
local Objectives = require("./Objectives")

type State = Types.RoundState
type Effect = Types.Effect

local Survival = {}

local function occupant(s: State, lockerId: number): Types.PlayerState?
	for _, id in Util.sortedIds(s.players) do
		local p = s.players[id]
		if p.hiddenIn == lockerId then
			return p
		end
	end
	return nil
end

function Survival.step(s: State, event: Types.Event, fx: { Effect })
	if s.phase ~= "Active" then
		return
	end
	if event.type == "LockerEnter" then
		local p = s.players[event.playerId]
		if Util.canAct(p) and occupant(s, event.lockerId) == nil then
			local me = p :: Types.PlayerState
			Objectives.stopRepair(s, me, fx)
			me.hiddenIn = event.lockerId
			table.insert(fx, { type = "EnteredLocker", playerId = me.id, lockerId = event.lockerId })
		end
	elseif event.type == "LockerExit" then
		local p = s.players[event.playerId]
		if p and p.hiddenIn ~= nil then
			local lockerId = p.hiddenIn
			p.hiddenIn = nil
			table.insert(fx, { type = "LeftLocker", playerId = p.id, lockerId = lockerId })
		end
	elseif event.type == "LockerSearch" then
		local a = s.players[event.attackerId]
		if a and Util.isZombieRole(a.role) and a.life == "Alive" then
			local hidden = occupant(s, event.lockerId)
			if hidden then
				hidden.hiddenIn = nil
				table.insert(fx, {
					type = "LeftLocker",
					playerId = hidden.id,
					lockerId = event.lockerId,
					pulledBy = event.attackerId,
				})
			end
		end
	elseif event.type == "UseMedkit" then
		local user = s.players[event.playerId]
		local target = s.players[event.targetId]
		if
			user
			and user.role == "Survivor"
			and Util.canAct(user)
			and user.medkits > 0
			and Util.canAct(target)
			and (target :: Types.PlayerState).hitsTaken > 0
		then
			local t = target :: Types.PlayerState
			user.medkits -= 1
			t.hitsTaken -= 1
			table.insert(fx, { type = "Healed", playerId = user.id, targetId = t.id })
		end
	end
end

return Survival
