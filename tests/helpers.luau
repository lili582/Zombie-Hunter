local RoundRules = require("../src/shared/Rules/RoundRules")
local Classic = require("../src/shared/Config/Classic")
local Rng = require("../src/shared/Rng")

local H = {}

function H.run(state, events)
	local all = {}
	for _, e in events do
		local fx
		state, fx = RoundRules.apply(state, e)
		for _, f in fx do
			table.insert(all, f)
		end
	end
	return state, all
end

function H.join(n: number, from: number?)
	local ev = {}
	for i = from or 1, (from or 1) + n - 1 do
		table.insert(ev, { type = "PlayerJoined", playerId = i })
	end
	return ev
end

-- Active round with known roles: 1 = Alpha, 2 = Hunter, the rest Survivors.
function H.activeRound(n: number)
	local s = H.run(RoundRules.new(Classic, Rng.new(1)), H.join(n))
	s = H.run(s, { H.tick(30) })
	assert(s.phase == "Active", "expected Active, got " .. s.phase)
	for id, p in s.players do
		p.role = if id == 1 then "Alpha" elseif id == 2 then "Hunter" else "Survivor"
	end
	return s
end

function H.hit(a, v)
	return { type = "Hit", attackerId = a, victimId = v }
end
function H.tick(dt)
	return { type = "Tick", dt = dt }
end
function H.reviveStart(r, t)
	return { type = "ReviveStart", reviverId = r, targetId = t }
end
function H.reviveStop(r)
	return { type = "ReviveStop", reviverId = r }
end
function H.pickUp(id)
	return { type = "PickUpGun", playerId = id }
end
function H.left(id)
	return { type = "PlayerLeft", playerId = id }
end
function H.killed(k, v)
	return { type = "ZombieKilled", killerId = k, victimId = v }
end

function H.countRole(players, role)
	local n = 0
	for _, p in players do
		if p.role == role then
			n += 1
		end
	end
	return n
end

function H.find(fx, pred)
	local found = {}
	for _, f in fx do
		if pred(f) then
			table.insert(found, f)
		end
	end
	return found
end

return H
