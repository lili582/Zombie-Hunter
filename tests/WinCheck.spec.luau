local lib = require("./lib")
local test, expect = lib.test, lib.expect
local WinCheck = require("../src/shared/Rules/WinCheck")
local H = require("./helpers")

local function state(list, timeLeft)
	local players = {}
	for i, e in list do
		players[i] = { id = i, role = e[1], life = e[2] }
	end
	return { players = players, timeLeft = timeLeft or 100 }
end

test("last human turning ends the round: ZombiesWin", function()
	expect(WinCheck.check(state({ { "Alpha", "Alive" }, { "Zombie", "Alive" } }))).toBe("ZombiesWin")
end)

test("timer at 0 with one downed human: SurvivorsSurvived", function()
	expect(WinCheck.check(state({ { "Alpha", "Alive" }, { "Survivor", "Downed" } }, 0))).toBe(
		"SurvivorsSurvived"
	)
end)

test("everyone left: NoWinner", function()
	expect(WinCheck.check(state({}))).toBe("NoWinner")
end)

test("waiting (Out) players do not count", function()
	expect(WinCheck.check(state({ { "Alpha", "Alive" }, { "Survivor", "Out" } }))).toBe("ZombiesWin")
end)

test("mid-round with humans and zombies: nil", function()
	expect(WinCheck.check(state({ { "Alpha", "Alive" }, { "Survivor", "Alive" } }))).toBeNil()
end)

test("RoundRules moves to Results when all humans leave", function()
	local s = H.activeRound(5)
	s.players[5].role = "Zombie"
	s = H.run(s, { H.left(2), H.left(3), H.left(4) })
	expect(s.phase).toBe("Results")
	expect(s.winner).toBe("ZombiesWin")
end)

test("last human bleeding out: ZombiesWin", function()
	local s = H.activeRound(5)
	for i = 3, 5 do
		s.players[i].role = "Zombie"
	end
	s = H.run(s, { H.hit(1, 2), H.hit(1, 2), H.tick(20) })
	expect(s.winner).toBe("ZombiesWin")
end)
