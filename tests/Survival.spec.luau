local lib = require("./lib")
local test, expect = lib.test, lib.expect
local H = require("./helpers")

local function enter(pid, lid)
	return { type = "LockerEnter", playerId = pid, lockerId = lid }
end
local function exit(pid)
	return { type = "LockerExit", playerId = pid }
end
local function search(aid, lid)
	return { type = "LockerSearch", attackerId = aid, lockerId = lid }
end
local function medkit(pid, tid)
	return { type = "UseMedkit", playerId = pid, targetId = tid }
end

test("a hiding survivor cannot be hit", function()
	local s = H.run(H.objectiveRound(6), { enter(3, 7), H.hit(1, 3), H.hit(1, 3) })
	expect(s.players[3].hitsTaken).toBe(0)
	expect(s.players[3].hiddenIn).toBe(7)
end)

test("one person per locker", function()
	local s = H.run(H.objectiveRound(6), { enter(3, 7), enter(4, 7) })
	expect(s.players[4].hiddenIn).toBeNil()
end)

test("leaving the locker makes you hittable again", function()
	local s = H.run(H.objectiveRound(6), { enter(3, 7), exit(3), H.hit(1, 3) })
	expect(s.players[3].hitsTaken).toBe(1)
end)

test("a zombie searching the right locker pulls the human out (+5)", function()
	local s, fx = H.run(H.objectiveRound(6), { enter(3, 7), search(1, 7) })
	expect(s.players[3].hiddenIn).toBeNil()
	expect(s.players[1].points).toBe(5)
	expect(#H.find(fx, function(f)
		return f.type == "LeftLocker" and f.pulledBy == 1
	end)).toBe(1)
end)

test("searching an empty locker finds nothing; humans cannot search", function()
	local s = H.run(H.objectiveRound(6), { enter(3, 7), search(1, 8), search(4, 7) })
	expect(s.players[3].hiddenIn).toBe(7)
	expect(s.players[1].points).toBe(0)
end)

test("hiding stops your repair", function()
	local s = H.objectiveRound(6)
	local tid = H.towerIds(s)[1]
	s = H.run(s, { H.repair(3, tid), enter(3, 7) })
	expect(s.players[3].repairing).toBeNil()
end)

test("hiding players still count as humans alive at the timer", function()
	local s = H.objectiveRound(6)
	for _, id in { 2, 4, 5, 6 } do
		s.players[id].role = "Zombie"
	end
	s = H.run(s, { enter(3, 1), H.tick(360) })
	expect(s.winner).toBe("SurvivorsSurvived")
end)

test("a medkit heals one hit on a teammate (+5) and is used up", function()
	local s = H.run(H.objectiveRound(6), { H.hit(1, 4), medkit(3, 4) })
	expect(s.players[4].hitsTaken).toBe(0)
	expect(s.players[3].medkits).toBe(0)
	expect(s.players[3].points).toBe(5)
	s = H.run(s, { H.hit(1, 4), medkit(3, 4) })
	expect(s.players[4].hitsTaken).toBe(1) -- no medkit left
end)

test("medkit on yourself works but gives no points; unhurt targets waste nothing", function()
	local s = H.run(H.objectiveRound(6), { medkit(3, 3) })
	expect(s.players[3].medkits).toBe(1)
	s = H.run(s, { H.hit(1, 3), medkit(3, 3) })
	expect(s.players[3].hitsTaken).toBe(0)
	expect(s.players[3].points).toBe(0)
end)

test("medkits cannot bring back a downed player, and Hunters have none", function()
	local s =
		H.run(H.objectiveRound(6), { H.hit(1, 4), H.hit(1, 4), medkit(3, 4), H.hit(1, 5), medkit(2, 5) })
	expect(s.players[4].life).toBe("Downed")
	expect(s.players[5].hitsTaken).toBe(1)
end)

test("survivors start each round with a medkit", function()
	local Classic = require("../src/shared/Config/Classic")
	local RoundRules = require("../src/shared/Rules/RoundRules")
	local Rng = require("../src/shared/Rng")
	local s = H.run(RoundRules.new(Classic, Rng.new(2), H.mapMeta), H.join(6))
	s = H.run(s, { H.tick(20) })
	for _, p in s.players do
		expect(p.medkits).toBe(if p.role == "Survivor" then 1 else 0)
	end
end)
