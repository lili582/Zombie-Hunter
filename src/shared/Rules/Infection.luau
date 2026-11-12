--!strict
-- Hits -> downed -> revive or turn; Hunter gun hand-off; special roles leaving. Pure.
-- Works on a working copy `s` owned by RoundRules (it may be changed in place).
local Types = require("../Types")
local Util = require("./Util")
local RolePicker = require("./RolePicker")
local Abilities = require("./Abilities")

type State = Types.RoundState
type Effect = Types.Effect

local Infection = {}

local function validReviver(s: State, reviverId: number?): boolean
	if reviverId == nil then
		return false
	end
	return Util.canAct(s.players[reviverId])
end

local function stopRevivesBy(s: State, reviverId: number, fx: { Effect })
	for _, id in Util.sortedIds(s.players) do
		local p = s.players[id]
		if p.reviverId == reviverId then
			p.reviverId = nil
			p.reviveProgress = 0
			table.insert(fx, { type = "ReviveStopped", targetId = id })
		end
	end
end

local function dropGun(s: State, fromId: number, fx: { Effect })
	s.gunDropped = true
	table.insert(fx, { type = "GunDropped", fromId = fromId })
	table.insert(fx, { type = "Announce", card = "HunterFallen" })
end

local function turn(s: State, p: Types.PlayerState, fx: { Effect })
	local wasHunter = p.role == "Hunter"
	local byId = p.downedBy
	p.role = "Zombie" -- an infected player is never an Alpha
	p.life = "Alive"
	p.hitsTaken = 0
	p.bleedLeft = nil
	p.downedBy = nil
	p.reviverId = nil
	p.reviveProgress = 0
	p.wasInfected = true
	p.repairing = nil
	p.hiddenIn = nil
	stopRevivesBy(s, p.id, fx)
	table.insert(fx, { type = "BecameZombie", playerId = p.id, byId = byId })
	if wasHunter then
		dropGun(s, p.id, fx)
	end
end

local function onHit(s: State, attackerId: number, victimId: number, fx: { Effect })
	local a, v = s.players[attackerId], s.players[victimId]
	if not a or not v or attackerId == victimId then
		return
	end
	if not Util.isZombieRole(a.role) or a.life ~= "Alive" then
		return
	end
	if not Util.isHumanRole(v.role) or v.life ~= "Alive" or v.hiddenIn ~= nil then
		return -- hiding in a locker keeps you safe until a zombie pulls you out
	end
	v.hitsTaken += 1
	table.insert(fx, { type = "HitLanded", attackerId = attackerId, victimId = victimId })
	if v.hitsTaken >= s.config.hitsToDown[a.role] then
		v.life = "Downed"
		v.bleedLeft = s.config.bleedOut
		v.downedBy = attackerId
		v.reviverId = nil
		v.reviveProgress = 0
		stopRevivesBy(s, victimId, fx)
		table.insert(fx, { type = "Downed", playerId = victimId, byId = attackerId })
	end
end

local function onReviveStart(s: State, reviverId: number, targetId: number, fx: { Effect })
	local t = s.players[targetId]
	if not t or t.life ~= "Downed" or not validReviver(s, reviverId) or reviverId == targetId then
		return
	end
	if t.reviverId ~= nil and t.reviverId ~= reviverId and validReviver(s, t.reviverId) then
		return -- someone else is already reviving
	end
	stopRevivesBy(s, reviverId, fx) -- one revive at a time
	t.reviverId = reviverId
	t.reviveProgress = 0
	table.insert(fx, { type = "ReviveStarted", reviverId = reviverId, targetId = targetId })
end

local function onTick(s: State, dt: number, fx: { Effect })
	for _, id in Util.sortedIds(s.players) do
		local p = s.players[id]
		if p.life ~= "Downed" then
			continue
		end
		-- Revive first, so a revive finishing on the same tick as the bleed-out wins.
		if p.reviverId ~= nil then
			if validReviver(s, p.reviverId) then
				p.reviveProgress += dt
				if p.reviveProgress >= s.config.reviveTime - 1e-9 then
					local by = p.reviverId
					p.life = "Alive"
					p.hitsTaken = 0
					p.bleedLeft = nil
					p.downedBy = nil
					p.reviverId = nil
					p.reviveProgress = 0
					table.insert(fx, { type = "Revived", playerId = id, byId = by })
					continue
				end
			else
				p.reviverId = nil
				p.reviveProgress = 0
				table.insert(fx, { type = "ReviveStopped", targetId = id })
			end
		end
		p.bleedLeft = (p.bleedLeft or 0) - dt
		if (p.bleedLeft :: number) <= 1e-9 then
			turn(s, p, fx)
		end
	end
end

local function onPickUpGun(s: State, playerId: number, fx: { Effect })
	local p = s.players[playerId]
	if not s.gunDropped or not p or p.role ~= "Survivor" or not Util.canAct(p) then
		return
	end
	p.role = "Hunter"
	s.gunDropped = false
	table.insert(fx, { type = "NewHunter", playerId = playerId })
	table.insert(fx, { type = "Announce", card = "NewHunter" }) -- secret: no name
end

function Infection.step(s: State, event: Types.Event, fx: { Effect })
	if s.phase ~= "Active" then
		return
	end
	if event.type == "Hit" then
		onHit(s, event.attackerId, event.victimId, fx)
	elseif event.type == "ReviveStart" then
		onReviveStart(s, event.reviverId, event.targetId, fx)
	elseif event.type == "ReviveStop" then
		stopRevivesBy(s, event.reviverId, fx)
	elseif event.type == "PickUpGun" then
		onPickUpGun(s, event.playerId, fx)
	elseif event.type == "Tick" then
		onTick(s, event.dt, fx)
	elseif event.type == "Dodged" then
		local p, a = s.players[event.playerId], s.players[event.attackerId]
		if p and a and p.role == "Survivor" and p.life == "Alive" and Util.isZombieRole(a.role) then
			table.insert(fx, { type = "Dodged", playerId = event.playerId, attackerId = event.attackerId })
		end
	elseif event.type == "ZombieKilled" then
		local k, v = s.players[event.killerId], s.players[event.victimId]
		if k and v and k.role == "Hunter" and Util.isZombieRole(v.role) then
			table.insert(fx, { type = "ZombieKilled", killerId = event.killerId, victimId = event.victimId })
		end
	end
end

-- Called after `leaver` was removed from s.players, during HeadStart or Active.
function Infection.onPlayerLeft(s: State, leaver: Types.PlayerState, fx: { Effect })
	stopRevivesBy(s, leaver.id, fx)
	if leaver.role == "Hunter" and leaver.life ~= "Out" then
		dropGun(s, leaver.id, fx)
	end

	local survivors, zombies, humans = {}, 0, 0
	local hasAlpha = false
	for _, id in Util.sortedIds(s.players) do
		local p = s.players[id]
		if p.life == "Out" then
			continue
		end
		if Util.isZombieRole(p.role) then
			zombies += 1
			hasAlpha = hasAlpha or p.role == "Alpha"
		elseif Util.isHumanRole(p.role) and p.life ~= "Escaped" then
			humans += 1
			if p.role == "Survivor" and Util.canAct(p) then
				table.insert(survivors, id)
			end
		end
	end

	local needAlpha = (s.phase == "HeadStart" and leaver.role == "Alpha" and not hasAlpha)
		or (s.phase == "Active" and zombies == 0 and humans > 0)
	if not needAlpha then
		return
	end
	local newId = RolePicker.pickReplacementAlpha(survivors, s.rng)
	if newId == nil then
		return
	end
	s.players[newId].role = "Alpha"
	Abilities.makeAlpha(s, s.players[newId])
	s.sinceSpecial[newId] = 0
	table.insert(fx, { type = "BecameAlpha", playerId = newId })
	table.insert(fx, { type = "Announce", card = "YourRole", toPlayerId = newId, data = { role = "Alpha" } })
	table.insert(fx, {
		type = "Announce",
		card = "YourRules",
		toPlayerId = newId,
		data = { role = "Alpha", alphaClass = s.players[newId].alphaClass },
	})
	if s.phase == "Active" then
		table.insert(fx, { type = "Announce", card = "AlphaAwakened" }) -- secret: no name
	end
end

return Infection
