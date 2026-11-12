local lib = require("./lib")
local test, expect = lib.test, lib.expect
local RoundRules = require("../src/shared/Rules/RoundRules")
local ModePicker = require("../src/shared/Rules/ModePicker")
local HitValidation = require("../src/shared/Rules/HitValidation")
local Classic = require("../src/shared/Config/Classic")
local Modes = require("../src/shared/Config/Modes")
local Weapons = require("../src/shared/Config/Weapons")
local Rng = require("../src/shared/Rng")
local H = require("./helpers")

local POOL = { "Classic", "Outbreak" }

local function config(extra)
	local c = table.clone(Classic)
	c.modePool = POOL
	for k, v in extra or {} do
		c[k] = v
	end
	return c
end

test("mode weights: Classic about twice as often as Outbreak", function()
	local rng, outbreak = Rng.new(7), 0
	for _ = 1, 3000 do
		if ModePicker.pick(POOL, 8, nil, rng) == "Outbreak" then
			outbreak += 1
		end
	end
	-- 20 / (40 + 20) = 1/3 -> about 1000
	expect(outbreak > 850 and outbreak < 1150).toBeTruthy()
end)

test("Outbreak needs 6 players; Classic is the fallback", function()
	local rng = Rng.new(3)
	for _ = 1, 200 do
		expect(ModePicker.pick(POOL, 5, nil, rng)).toBe("Classic")
	end
end)

test("a special mode never comes twice in a row", function()
	local rng = Rng.new(9)
	for _ = 1, 200 do
		expect(ModePicker.pick(POOL, 8, "Outbreak", rng)).toBe("Classic")
	end
end)

test("Studio: minimums ignored; a forced mode always wins", function()
	local rng, outbreak = Rng.new(4), 0
	for _ = 1, 300 do
		if ModePicker.pick(POOL, 2, nil, rng, { ignoreMinimums = true }) == "Outbreak" then
			outbreak += 1
		end
	end
	expect(outbreak > 0).toBeTruthy()
	expect(ModePicker.pick(POOL, 2, "Outbreak", rng, { force = "Outbreak" })).toBe("Outbreak")
	expect(ModePicker.pick(POOL, 8, nil, rng, { force = "Nope" }) ~= "Nope").toBeTruthy()
end)

test("no mode pool: always Classic", function()
	local s = H.run(RoundRules.new(Classic, Rng.new(1)), H.join(8))
	expect(s.nextMode).toBe("Classic")
	expect(RoundRules.viewFor(s, 1).nextMode).toBe("Classic")
end)

test("Outbreak round: 2 Alphas, no Hunter, armed survivors, 4:00, 10s bleed-out", function()
	local s, fx = H.run(RoundRules.new(config({ forceMode = "Outbreak" }), Rng.new(1), H.mapMeta), H.join(8))
	expect(s.nextMode).toBe("Outbreak")
	s, fx = H.run(s, { H.tick(Classic.intermission) })
	expect(s.phase).toBe("HeadStart")
	expect(H.countRole(s.players, "Alpha")).toBe(2)
	expect(H.countRole(s.players, "Hunter")).toBe(0)
	expect(H.countRole(s.players, "Survivor")).toBe(6)
	expect(next(s.towers)).toBeNil() -- no towers, no helicopter
	local mode = H.find(fx, function(f)
		return f.type == "Announce" and f.card == "Mode"
	end)
	expect(mode[1].data.name).toBe("OUTBREAK")
	s = H.run(s, { H.tick(Classic.headStart) })
	expect(s.phase).toBe("Active")
	expect(s.timeLeft).toBe(240)
	local view = RoundRules.viewFor(s, 1)
	expect(view.mode).toBe("Outbreak")
	expect(view.humanWeapon).toBe("Pistol")
	expect(view.bleedOut).toBe(10)
end)

test(
	"Outbreak: the timer runs out with a human alive -> SurvivorsSurvived; then back to Classic numbers",
	function()
		local s = H.run(RoundRules.new(config({ forceMode = "Outbreak" }), Rng.new(1)), H.join(8))
		s = H.run(s, { H.tick(Classic.intermission + Classic.headStart) })
		local fx
		s, fx = H.run(s, { H.tick(240) })
		local over = H.find(fx, function(f)
			return f.type == "RoundOver"
		end)
		expect(over[1].winner).toBe("SurvivorsSurvived")
		s = H.run(s, { H.tick(Classic.results) })
		expect(s.phase).toBe("Intermission")
		expect(s.config.roundLength).toBe(Classic.roundLength)
	end
)

test("Outbreak: a downed survivor turns after 10s", function()
	local s = H.run(RoundRules.new(config({ forceMode = "Outbreak" }), Rng.new(1)), H.join(8))
	s = H.run(s, { H.tick(Classic.intermission + Classic.headStart) })
	local alpha, victim
	for id, p in s.players do
		if p.role == "Alpha" then
			alpha = alpha or id
		else
			victim = victim or id
		end
	end
	s = H.run(s, { H.hit(alpha, victim), H.hit(alpha, victim) })
	expect(s.players[victim].life).toBe("Downed")
	s = H.run(s, { H.tick(9.9) })
	expect(s.players[victim].role).toBe("Survivor")
	s = H.run(s, { H.tick(0.2) })
	expect(s.players[victim].role).toBe("Zombie")
end)

test("after an Outbreak round the next round is not Outbreak", function()
	local s = H.run(RoundRules.new(config(), Rng.new(1)), H.join(8))
	local outbreaks = 0
	for _ = 1, 20 do
		local last = s.lastMode
		s = H.run(s, { H.tick(Classic.intermission) })
		expect(last == "Outbreak" and s.config.modeId == "Outbreak").toBe(false)
		if s.config.modeId == "Outbreak" then
			outbreaks += 1
		end
		-- play the round out on the timer, then the results
		s = H.run(s, { H.tick(Classic.headStart + s.config.roundLength + Classic.results) })
	end
	expect(outbreaks > 0).toBeTruthy()
end)

test("pistols: armed Survivors may shoot, unarmed ones may not", function()
	local input = { role = "Survivor", distance = 10, sinceLastShot = 5, ammoInMag = 3 }
	expect(HitValidation.shot(input, Weapons.Pistol)).toBe(false)
	input.armed = true
	expect(HitValidation.shot(input, Weapons.Pistol)).toBe(true)
	input.role = "Zombie"
	expect(HitValidation.shot(input, Weapons.Pistol)).toBe(false)
end)

test("mode config keeps the lobby numbers and adds the mode's", function()
	local c = Modes.configFor(Classic, "Outbreak")
	expect(c.minPlayers).toBe(Classic.minPlayers)
	expect(c.roundLength).toBe(240)
	expect(c.alphaCount(12)).toBe(3)
	expect(Classic.roundLength).toBe(360) -- the base table is not changed
end)

test("Outbreak: a Survivor who kills a zombie gets the kill points; in Classic they can't", function()
	local s = H.run(RoundRules.new(config({ forceMode = "Outbreak" }), Rng.new(1)), H.join(8))
	s = H.run(s, { H.tick(Classic.intermission + Classic.headStart) })
	local alpha, survivor
	for id, p in s.players do
		if p.role == "Alpha" then
			alpha = alpha or id
		else
			survivor = survivor or id
		end
	end
	local _, fx = H.run(s, { H.killed(survivor, alpha) })
	expect(#H.find(fx, function(f)
		return f.type == "PointsAwarded" and f.playerId == survivor and f.reason == "ALPHA KILL"
	end)).toBe(1)
	local c = H.activeRound(5)
	_, fx = H.run(c, { H.killed(3, 1) })
	expect(#H.find(fx, function(f)
		return f.type == "PointsAwarded"
	end)).toBe(0)
end)
