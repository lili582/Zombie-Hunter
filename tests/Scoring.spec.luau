local lib = require("./lib")
local test, expect = lib.test, lib.expect
local Scoring = require("../src/shared/Rules/Scoring")
local H = require("./helpers")
local hit, tick = H.hit, H.tick

test("hits and downs give points to the zombie", function()
	local s = H.run(H.activeRound(8), { hit(1, 3), hit(1, 3) })
	expect(s.players[1].points).toBe(3 + 3 + 10)
end)

test("infection gives 25 to the zombie that downed the victim and 10 assist", function()
	local s = H.activeRound(8)
	s.players[4].role = "Zombie"
	-- shared hit count: the zombie's hit + one Alpha hit = 2 = downed by the Alpha
	s = H.run(s, { hit(4, 3), tick(2), hit(1, 3), tick(20) })
	expect(s.players[3].role).toBe("Zombie")
	expect(s.players[1].points).toBe(3 + 10 + 25)
	expect(s.players[4].points).toBe(3 + 10)
end)

test("assist only counts within 10 seconds", function()
	local s = H.activeRound(8)
	s.players[4].role = "Zombie"
	s = H.run(s, { hit(4, 3), tick(11), hit(1, 3), tick(20) })
	expect(s.players[4].points).toBe(3)
end)

test("an infected player keeps human points and earns zombie points (+first infection bonus)", function()
	local s = H.activeRound(8)
	s = H.run(s, { hit(1, 3), hit(1, 3), H.reviveStart(4, 3), tick(4) })
	expect(s.players[4].points).toBe(20)
	s = H.run(s, { hit(1, 4), hit(1, 4), tick(20) })
	expect(s.players[4].role).toBe("Zombie")
	s = H.run(s, { hit(4, 5), hit(4, 5), hit(4, 5), tick(20) })
	expect(s.players[4].points).toBe(20 + 3 * 3 + 10 + 25 + 10)
end)

test("infected zombies get the team win bonus on ZombiesWin, and coins cards go out", function()
	local s = H.activeRound(5)
	s.players[3].role = "Zombie"
	s.players[4].role = "Zombie"
	s.players[5].role = "Zombie"
	local fx
	s, fx = H.run(s, { hit(3, 2), hit(3, 2), hit(3, 2), tick(20) })
	expect(s.winner).toBe("ZombiesWin")
	expect(s.players[4].points).toBe(30)
	expect(s.players[2].points).toBe(30) -- the turned Hunter is a zombie now
	local coins = H.find(fx, function(f)
		return f.card == "YourCoins"
	end)
	expect(#coins).toBe(5)
end)

test("surviving humans get team win + survive bonus", function()
	local s = H.run(H.activeRound(6), { tick(360) })
	expect(s.players[3].points).toBe(60)
	expect(s.players[1].points).toBe(0)
end)

test("picking up the gun and killing zombies give points", function()
	local s = H.run(
		H.activeRound(8),
		{ hit(1, 2), hit(1, 2), tick(20), H.pickUp(5), H.killed(5, 1), H.killed(5, 2) }
	)
	expect(s.players[5].points).toBe(15 + 30 + 10)
end)

test("only a Hunter's kills count", function()
	local s = H.run(H.activeRound(8), { H.killed(3, 1) })
	expect(s.players[3].points).toBe(0)
end)

test("coins are half the points, at least 10", function()
	expect(Scoring.coins(0)).toBe(10)
	expect(Scoring.coins(101)).toBe(50)
end)
