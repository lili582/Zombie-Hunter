local lib = require("./lib")
local test, expect = lib.test, lib.expect
local RoundRules = require("../src/shared/Rules/RoundRules")
local Classic = require("../src/shared/Config/Classic")
local H = require("./helpers")

local function shoot(hunter, victim)
	return { type = "FriendlyFire", shooterId = hunter, victimId = victim }
end

test("the Hunter shoots a survivor: both die and the gun drops", function()
	local s = H.activeRound(6) -- 1 Alpha, 2 Hunter, 3-6 Survivors
	local fx
	s, fx = H.run(s, { shoot(2, 3) })
	expect(s.players[3].life).toBe("Dead")
	expect(s.players[2].life).toBe("Dead")
	expect(s.gunDropped).toBe(true)
	local killed = H.find(fx, function(f)
		return f.type == "Killed"
	end)
	expect(#killed).toBe(2)
	expect(killed[1].playerId).toBe(3)
	expect(killed[1].byId).toBe(2)
	expect(#H.find(fx, function(f)
		return f.type == "GunDropped" and f.fromId == 2
	end)).toBe(1)
	local banner = H.find(fx, function(f)
		return f.type == "Announce" and f.card == "HunterFallen"
	end)
	expect(banner[1].data.reason).toBe("innocent")
	expect(banner[1].toPlayerId).toBeNil()
	expect(#H.find(fx, function(f)
		return f.card == "ShotInnocent" and f.toPlayerId == 2
	end)).toBe(1)
	expect(#H.find(fx, function(f)
		return f.card == "ShotByHunter" and f.toPlayerId == 3
	end)).toBe(1)
end)

test("after friendly fire a survivor picks up the gun and is the new Hunter", function()
	local s = H.run(H.activeRound(6), { shoot(2, 3), H.pickUp(4) })
	expect(s.players[4].role).toBe("Hunter")
	expect(s.gunDropped).toBe(false)
	-- the new Hunter makes the same mistake: same punishment
	s = H.run(s, { shoot(4, 5) })
	expect(s.players[4].life).toBe("Dead")
	expect(s.players[5].life).toBe("Dead")
	expect(s.gunDropped).toBe(true)
end)

test("the dead can't act, and don't count as humans alive", function()
	local s = H.run(H.activeRound(6), { shoot(2, 3) })
	local _, fx = H.run(s, { H.pickUp(3), H.reviveStart(2, 4), H.hit(1, 3) })
	expect(#H.find(fx, function(f)
		return f.type == "NewHunter" or f.type == "ReviveStarted" or f.type == "HitLanded"
	end)).toBe(0)
	expect(RoundRules.viewFor(s, 3).humansLeft).toBe(3) -- 5 humans minus the 2 dead
end)

test("only the Hunter is punished, only for humans, only while alive", function()
	local s = H.activeRound(6)
	local _, fx = H.run(s, { shoot(3, 4) }) -- a survivor can't
	expect(#fx).toBe(0)
	_, fx = H.run(s, { shoot(2, 1) }) -- shooting a zombie is not friendly fire
	expect(#H.find(fx, function(f)
		return f.type == "Killed"
	end)).toBe(0)
	_, fx = H.run(s, { shoot(2, 2) })
	expect(#fx).toBe(0)
end)

test("killing the last other human: the zombies win; the dead get no win", function()
	local s = H.activeRound(5) -- 1 Alpha, 2 Hunter, 3-5 Survivors
	s = H.run(s, {
		H.hit(1, 4),
		H.hit(1, 4),
		H.hit(1, 5),
		H.hit(1, 5),
		H.tick(Classic.bleedOut),
	})
	local fx
	s, fx = H.run(s, { shoot(2, 3) })
	local over = H.find(fx, function(f)
		return f.type == "RoundOver"
	end)
	expect(over[1].winner).toBe("ZombiesWin")
	local recap = H.find(fx, function(f)
		return f.card == "Recap"
	end)[1]
	for _, e in recap.data.players do
		if e.id == 2 or e.id == 3 then
			expect(e.outcome).toBe("KILLED")
			expect(e.won).toBe(false)
		end
	end
end)
