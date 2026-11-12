local lib = require("./lib")
local test, expect = lib.test, lib.expect
local H = require("./helpers")
local hit, tick, left, pickUp = H.hit, H.tick, H.left, H.pickUp

test("Alpha downs a survivor in 2 hits, basic zombie needs 3", function()
	local s = H.activeRound(8)
	s = H.run(s, { hit(1, 3), hit(1, 3) })
	expect(s.players[3].life).toBe("Downed")
	s.players[4].role = "Zombie"
	s = H.run(s, { hit(4, 5), hit(4, 5) })
	expect(s.players[5].life).toBe("Alive")
	s = H.run(s, { hit(4, 5) })
	expect(s.players[5].life).toBe("Downed")
end)

test("bleed-out after 20s turns the player into a basic zombie, not an Alpha", function()
	local s = H.run(H.activeRound(8), { hit(1, 3), hit(1, 3), tick(19.9) })
	expect(s.players[3].life).toBe("Downed")
	s = H.run(s, { tick(0.1) })
	expect(s.players[3].role).toBe("Zombie")
	expect(s.players[3].life).toBe("Alive")
end)

test("revive takes 4s and resets hits", function()
	local s = H.run(H.activeRound(8), { hit(1, 3), hit(1, 3), H.reviveStart(4, 3), tick(3.9) })
	expect(s.players[3].life).toBe("Downed")
	s = H.run(s, { tick(0.1) })
	expect(s.players[3].life).toBe("Alive")
	expect(s.players[3].hitsTaken).toBe(0)
end)

test("letting go of revive resets progress", function()
	local s = H.run(H.activeRound(8), { hit(1, 3), hit(1, 3), H.reviveStart(4, 3), tick(3), H.reviveStop(4) })
	s = H.run(s, { H.reviveStart(4, 3), tick(3) })
	expect(s.players[3].life).toBe("Downed")
end)

test("revive finishing on the same tick as bleed-out wins", function()
	local s = H.run(H.activeRound(8), { hit(1, 3), hit(1, 3), tick(16), H.reviveStart(4, 3), tick(4) })
	expect(s.players[3].life).toBe("Alive")
	expect(s.players[3].role).toBe("Survivor")
end)

test("a reviver who gets downed stops reviving", function()
	local s =
		H.run(H.activeRound(8), { hit(1, 3), hit(1, 3), H.reviveStart(4, 3), hit(1, 4), hit(1, 4), tick(4) })
	expect(s.players[3].life).toBe("Downed")
end)

test("hits on downed players and from humans are ignored", function()
	local s = H.run(H.activeRound(8), { hit(1, 3), hit(1, 3), hit(1, 3), hit(2, 4), hit(5, 1) })
	expect(s.players[3].hitsTaken).toBe(2)
	expect(s.players[4].hitsTaken).toBe(0)
end)

test("hits during head start are ignored", function()
	local s = H.run(
		require("../src/shared/Rules/RoundRules").new(
			require("../src/shared/Config/Classic"),
			require("../src/shared/Rng").new(1)
		),
		H.join(6)
	)
	s = H.run(s, { tick(20) })
	expect(s.phase).toBe("HeadStart")
	s = H.run(s, { hit(1, 2), hit(2, 1) })
	expect(s.players[1].hitsTaken + s.players[2].hitsTaken).toBe(0)
end)

test("turned Hunter drops the gun; first survivor pickup becomes Hunter, second is refused", function()
	local s, fx = H.run(H.activeRound(8), { hit(1, 2), hit(1, 2), tick(20) })
	expect(s.gunDropped).toBe(true)
	expect(#H.find(fx, function(f)
		return f.card == "HunterFallen"
	end)).toBe(1)
	s = H.run(s, { pickUp(5), pickUp(6) })
	expect(s.players[5].role).toBe("Hunter")
	expect(s.players[6].role).toBe("Survivor")
	expect(s.gunDropped).toBe(false)
end)

test("zombies cannot pick up the gun", function()
	local s = H.run(H.activeRound(8), { hit(1, 2), hit(1, 2), tick(20), pickUp(1), pickUp(2) })
	expect(s.gunDropped).toBe(true)
end)

test("Hunter leaving drops the gun", function()
	local s = H.run(H.activeRound(8), { left(2) })
	expect(s.gunDropped).toBe(true)
end)

test("last zombie leaving makes a random Survivor the Alpha (never the Hunter)", function()
	local s = H.run(H.activeRound(8), { left(1) })
	expect(H.countRole(s.players, "Alpha")).toBe(1)
	expect(s.players[2].role).toBe("Hunter")
	expect(s.phase).toBe("Active")
end)

test("Alpha leaving during head start picks a new Alpha", function()
	local RoundRules = require("../src/shared/Rules/RoundRules")
	local s = H.run(
		RoundRules.new(require("../src/shared/Config/Classic"), require("../src/shared/Rng").new(1)),
		H.join(6)
	)
	s = H.run(s, { tick(20) })
	local alpha
	for id, p in s.players do
		if p.role == "Alpha" then
			alpha = id
		end
	end
	s = H.run(s, { left(alpha) })
	expect(H.countRole(s.players, "Alpha")).toBe(1)
	expect(s.phase).toBe("HeadStart")
end)
