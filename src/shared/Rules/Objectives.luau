--!strict
-- Radio towers (repair, co-op speed, skill checks) and the rescue helicopter (call, land,
-- escape). Pure. Works on RoundRules' working copy `s`.
local Types = require("../Types")
local Util = require("./Util")
local SpotPicker = require("./SpotPicker")

type State = Types.RoundState
type Effect = Types.Effect

local Objectives = {}

-- Called when a round starts (HeadStart): picks this round's towers.
function Objectives.setup(s: State)
	s.towers = {}
	s.towersDone = 0
	s.heli = { phase = "None", timeLeft = 0, zone = nil }
	local meta = s.mapMeta
	if not meta or #meta.towerSpots == 0 then
		return
	end
	local picked = SpotPicker.pick(meta.towerSpots, s.config.towersOnMap, s.config.towerMinDistance, s.rng)
	for _, idx in picked do
		s.towers[idx] = { progress = 0, done = false }
	end
end

local function stopRepair(_s: State, p: Types.PlayerState, fx: { Effect })
	if p.repairing ~= nil then
		local towerId = p.repairing
		p.repairing = nil
		table.insert(fx, { type = "RepairStopped", playerId = p.id, towerId = towerId })
	end
end
Objectives.stopRepair = stopRepair

local function callHeli(s: State, fx: { Effect })
	local count = if s.mapMeta then s.mapMeta.heliZoneCount else 0
	if count <= 0 or s.heli.phase ~= "None" then
		return
	end
	local zone = s.rng:int(1, count)
	s.heli = { phase = "Inbound", timeLeft = s.config.heliInbound, zone = zone }
	table.insert(fx, { type = "HeliCalled", zone = zone })
	table.insert(fx, { type = "Announce", card = "HeliIncoming", data = { seconds = s.config.heliInbound } })
end

local function repairersOf(s: State, towerId: number): { number }
	local ids = {}
	for _, id in Util.sortedIds(s.players) do
		if s.players[id].repairing == towerId then
			table.insert(ids, id)
		end
	end
	return ids
end

local function completeTower(s: State, towerId: number, fx: { Effect })
	local t = s.towers[towerId]
	t.progress = 1
	t.done = true
	s.towersDone += 1
	local ids = repairersOf(s, towerId)
	for _, id in ids do
		s.players[id].repairing = nil
	end
	table.insert(fx, { type = "TowerRepaired", towerId = towerId, repairerIds = ids })
	table.insert(fx, {
		type = "Announce",
		card = "TowerRepaired",
		data = { done = s.towersDone, needed = s.config.towersNeeded },
	})
	if s.towersDone >= s.config.towersNeeded then
		callHeli(s, fx)
	end
end

-- Adds `amount` progress to a tower, giving repair credit to `byId`.
local function addProgress(s: State, towerId: number, amount: number, byId: number?, fx: { Effect })
	local t = s.towers[towerId]
	if not t or t.done then
		return
	end
	local before = t.progress
	t.progress = math.clamp(t.progress + amount, 0, 1)
	local gained = t.progress - before
	if byId and gained > 0 then
		local p = s.players[byId]
		if p then
			p.repairCredit += gained
			local whole = math.floor(p.repairCredit / 0.1 + 1e-9)
			if whole > 0 then
				p.repairCredit -= whole * 0.1
				table.insert(fx, { type = "RepairPoints", playerId = byId, amount = whole })
			end
		end
	end
	if t.progress >= 1 - 1e-9 then
		completeTower(s, towerId, fx)
	end
end

local function onTick(s: State, dt: number, fx: { Effect })
	-- repairs: drop anyone who can no longer repair, then add progress
	local byTower: { [number]: { number } } = {}
	for _, id in Util.sortedIds(s.players) do
		local p = s.players[id]
		if p.repairing ~= nil then
			local t = s.towers[p.repairing]
			if not Util.canAct(p) or not t or t.done then
				stopRepair(s, p, fx)
			else
				byTower[p.repairing] = byTower[p.repairing] or {}
				table.insert(byTower[p.repairing], id)
			end
		end
	end
	local towerIds = {}
	for towerId in byTower do
		table.insert(towerIds, towerId)
	end
	table.sort(towerIds)
	for _, towerId in towerIds do
		local ids = byTower[towerId]
		local total = (dt / s.config.repairTime) * (1 + s.config.coopBonus * (#ids - 1))
		for _, id in ids do
			if not s.towers[towerId].done then
				addProgress(s, towerId, total / #ids, id, fx)
			end
		end
	end

	-- helicopter
	local heli = s.heli
	if heli.phase == "Inbound" or heli.phase == "Landed" then
		heli.timeLeft -= dt
		if heli.timeLeft <= 1e-9 then
			if heli.phase == "Inbound" then
				heli.phase = "Landed"
				heli.timeLeft = s.config.heliLanded
				table.insert(fx, { type = "HeliLanded", zone = heli.zone })
				table.insert(
					fx,
					{ type = "Announce", card = "HeliHere", data = { seconds = s.config.heliLanded } }
				)
			else
				heli.phase = "Gone"
				heli.timeLeft = 0
				table.insert(fx, { type = "HeliLeft" })
			end
		end
	end
end

function Objectives.step(s: State, event: Types.Event, fx: { Effect })
	if s.phase ~= "Active" then
		return
	end
	if event.type == "Tick" then
		onTick(s, event.dt, fx)
	elseif event.type == "RepairStart" then
		local p = s.players[event.playerId]
		local t = s.towers[event.towerId]
		if Util.canAct(p) and t and not t.done and p.repairing ~= event.towerId then
			stopRepair(s, p, fx)
			p.repairing = event.towerId
			table.insert(fx, { type = "RepairStarted", playerId = p.id, towerId = event.towerId })
		end
	elseif event.type == "RepairStop" then
		local p = s.players[event.playerId]
		if p then
			stopRepair(s, p, fx)
		end
	elseif event.type == "SkillCheck" then
		local p = s.players[event.playerId]
		if p and p.repairing ~= nil and Util.canAct(p) then
			local towerId = p.repairing
			if event.success then
				addProgress(s, towerId, s.config.skillBonus, p.id, fx)
			else
				addProgress(s, towerId, -s.config.skillPenalty, nil, fx)
				table.insert(fx, { type = "SkillCheckFailed", playerId = p.id, towerId = towerId })
				table.insert(fx, { type = "NoiseAlert", towerId = towerId })
			end
		end
	elseif event.type == "EnterHeliZone" then
		local p = s.players[event.playerId]
		if s.heli.phase == "Landed" and Util.canAct(p) then
			stopRepair(s, p, fx)
			p.life = "Escaped"
			table.insert(fx, { type = "Escaped", playerId = p.id })
			table.insert(fx, { type = "Announce", card = "Escaped", toPlayerId = p.id })
		end
	end
end

-- A zombie's hit landed on `victimId`: it stops their repair.
function Objectives.onHitLanded(s: State, attackerId: number, victimId: number, fx: { Effect })
	local v = s.players[victimId]
	if v and v.repairing ~= nil then
		stopRepair(s, v, fx)
		table.insert(fx, { type = "RepairInterrupted", attackerId = attackerId, victimId = victimId })
	end
end

function Objectives.escapedCount(s: State): number
	local n = 0
	for _, p in s.players do
		if p.life == "Escaped" then
			n += 1
		end
	end
	return n
end

return Objectives
