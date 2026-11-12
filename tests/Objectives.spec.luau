local lib = require("./lib")
local test, expect = lib.test, lib.expect
local SpotPicker = require("../src/shared/Rules/SpotPicker")
local Rng = require("../src/shared/Rng")
local Classic = require("../src/shared/Config/Classic")
local H = require("./helpers")
local tick, repair, skill = H.tick, H.repair, H.skill

test("5 distinct, spread-out tower spots are picked from 8", function()
	local rng = Rng.new(4)
	for _ = 1, 50 do
		local picked = SpotPicker.pick(H.mapMeta.towerSpots, 5, 60, rng)
		expect(#picked).toBe(5)
		local seen = {}
		for _, i in picked do
			expect(seen[i]).toBeNil()
			seen[i] = true
		end
	end
end)

test("spot picker relaxes the distance when the map is too small", function()
	local tight = { { x = 0, z = 0 }, { x = 1, z = 0 }, { x = 2, z = 0 } }
	expect(#SpotPicker.pick(tight, 3, 500, Rng.new(1))).toBe(3)
end)

test("a round on a map with towers starts with 5 towers at 0%", function()
	local s = H.objectiveRound(6)
	expect(#H.towerIds(s)).toBe(5)
	for _, t in s.towers do
		expect(t.progress).toBe(0)
	end
end)

test("one survivor repairs a tower in 60s and gets points", function()
	local s = H.objectiveRound(6)
	local tid = H.towerIds(s)[1]
	s = H.run(s, { repair(3, tid), tick(59) })
	expect(s.towers[tid].done).toBe(false)
	s = H.run(s, { tick(1.1) })
	expect(s.towers[tid].done).toBe(true)
	expect(s.towersDone).toBe(1)
	expect(s.players[3].points).toBe(10 * 1 + 25) -- 1 per 10% + tower bonus
	expect(s.players[3].repairing).toBeNil()
end)

test("two repairers are faster than one", function()
	local s = H.objectiveRound(6)
	local tid = H.towerIds(s)[1]
	s = H.run(s, { repair(3, tid), repair(4, tid), tick(40) })
	expect(s.towers[tid].done).toBe(true) -- 60 / 1.6 = 37.5s
end)

test("good skill check adds progress, failed one removes progress and makes noise", function()
	local s = H.objectiveRound(6)
	local tid = H.towerIds(s)[1]
	s = H.run(s, { repair(3, tid), tick(30) })
	local mid = s.towers[tid].progress
	s = H.run(s, { skill(3, true) })
	expect(s.towers[tid].progress > mid).toBeTruthy()
	local fx
	s, fx = H.run(s, { skill(3, false) })
	expect(s.towers[tid].progress < mid + 0.02 - 0.05).toBeTruthy()
	expect(#H.find(fx, function(f)
		return f.type == "NoiseAlert"
	end)).toBe(1)
end)

test("zombies cannot repair, and a zombie hit stops a repair (+5 to the zombie)", function()
	local s = H.objectiveRound(6)
	local tid = H.towerIds(s)[1]
	s = H.run(s, { repair(1, tid), repair(3, tid), H.hit(1, 3) })
	expect(s.players[1].repairing).toBeNil()
	expect(s.players[3].repairing).toBeNil()
	expect(s.players[1].points).toBe(3 + 5)
end)

test("3 repaired towers call the helicopter; it lands after 45s", function()
	local s = H.objectiveRound(6)
	local ids = H.towerIds(s)
	for i = 1, 3 do
		s.towers[ids[i]].progress = 0.99
	end
	local fx
	s, fx = H.run(s, { repair(3, ids[1]), repair(4, ids[2]), repair(5, ids[3]), tick(1) })
	expect(s.towersDone).toBe(3)
	expect(s.heli.phase).toBe("Inbound")
	expect(#H.find(fx, function(f)
		return f.card == "HeliIncoming"
	end)).toBe(1)
	s = H.run(s, { tick(Classic.heliInbound) })
	expect(s.heli.phase).toBe("Landed")
end)

local function landedRound()
	local s = H.objectiveRound(6)
	s.heli = { phase = "Landed", timeLeft = Classic.heliLanded, zone = 1 }
	return s
end

test("a human entering the landed helicopter's zone escapes (+40)", function()
	local s = H.run(landedRound(), { { type = "EnterHeliZone", playerId = 3 } })
	expect(s.players[3].life).toBe("Escaped")
	expect(s.players[3].points).toBe(40)
	expect(s.phase).toBe("Active") -- others are still out there
end)

test("zombies and downed humans cannot escape", function()
	local s = H.run(landedRound(), { H.hit(1, 4), H.hit(1, 4) })
	s = H.run(s, { { type = "EnterHeliZone", playerId = 1 }, { type = "EnterHeliZone", playerId = 4 } })
	expect(s.players[1].life).toBe("Alive")
	expect(s.players[4].life).toBe("Downed")
end)

test("helicopter leaving with someone on board: SurvivorsEscaped", function()
	local s = H.run(landedRound(), { { type = "EnterHeliZone", playerId = 3 }, tick(Classic.heliLanded) })
	expect(s.phase).toBe("Results")
	expect(s.winner).toBe("SurvivorsEscaped")
end)

test("helicopter leaving empty: the round goes on", function()
	local s = H.run(landedRound(), { tick(Classic.heliLanded) })
	expect(s.heli.phase).toBe("Gone")
	expect(s.phase).toBe("Active")
end)

test("everyone left either escaped or turned: SurvivorsEscaped", function()
	local s = landedRound()
	s.players[4].role = "Zombie"
	s.players[5].role = "Zombie"
	s.players[6].role = "Zombie"
	s.players[2].role = "Zombie"
	s = H.run(s, { { type = "EnterHeliZone", playerId = 3 } })
	expect(s.winner).toBe("SurvivorsEscaped")
end)

test("no map meta (Phase 1 maps): no towers, no helicopter", function()
	local s = H.activeRound(6)
	expect(#H.towerIds(s)).toBe(0)
	expect(s.heli.phase).toBe("None")
end)
