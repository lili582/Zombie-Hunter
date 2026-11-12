local lib = require("./lib")
local test, expect = lib.test, lib.expect
local Dodge = require("../src/shared/Rules/Dodge")
local Rng = require("../src/shared/Rng")
local H = require("./helpers")

local c = { zoneStart = 0.5, zoneSize = 0.2, window = 1 }

test("clicking inside the zone escapes", function()
	local ok, why = Dodge.judge(c, 0.6, 0.65, 0.05)
	expect(ok).toBe(true)
	expect(why).toBe("escaped")
end)

test("clicking outside the zone is caught", function()
	local ok, why = Dodge.judge(c, 0.2, 0.25, 0.05)
	expect(ok).toBe(false)
	expect(why).toBe("missed")
end)

test("a claimed position that does not match the server's timing is refused", function()
	-- client says 0.6 (in zone) but the click arrived right away -> cheating / lag spike
	local _, why = Dodge.judge(c, 0.6, 0.05, 0.02)
	expect(why).toBe("timing_mismatch")
end)

test("lag is forgiven: high ping still escapes on a good click", function()
	expect((Dodge.judge(c, 0.6, 0.85, 0.25))).toBe(true)
end)

test("too late and bad input are refused", function()
	expect(select(2, Dodge.judge(c, 0.6, 3, 0.05))).toBe("too_late")
	expect(select(2, Dodge.judge(c, "x", 0.6, 0.05))).toBe("bad_input")
	expect(select(2, Dodge.judge(c, 2, 0.6, 0.05))).toBe("bad_input")
end)

test("new challenges put the zone inside the bar, never at the start", function()
	local rng = Rng.new(9)
	for _ = 1, 500 do
		local ch = Dodge.newChallenge(rng)
		expect(ch.zoneStart >= 0.3).toBeTruthy()
		expect(ch.zoneStart + ch.zoneSize <= 0.95 + 1e-9).toBeTruthy()
	end
end)

test("a survivor who escapes gets 5 points; the hit does not count", function()
	local s = H.run(H.activeRound(6), { { type = "Dodged", playerId = 3, attackerId = 1 } })
	expect(s.players[3].points).toBe(5)
	expect(s.players[3].hitsTaken).toBe(0)
end)

test("only alive Survivors attacked by a zombie can escape", function()
	local s = H.run(H.activeRound(6), {
		{ type = "Dodged", playerId = 2, attackerId = 1 }, -- Hunter
		{ type = "Dodged", playerId = 3, attackerId = 4 }, -- attacker is a human
	})
	expect(s.players[2].points).toBe(0)
	expect(s.players[3].points).toBe(0)
end)
