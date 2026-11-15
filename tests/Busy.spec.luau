local lib = require("./lib")
local test, expect = lib.test, lib.expect
local RoundRules = require("../src/shared/Rules/RoundRules")
local Classic = require("../src/shared/Config/Classic")
local Rng = require("../src/shared/Rng")
local H = require("./helpers")

local function busy(id, b)
	return { type = "SetBusy", playerId = id, busy = b }
end

test("a player in the dressing room sits the next round out", function()
	local s = H.run(RoundRules.new(Classic, Rng.new(1)), H.join(6))
	s = H.run(s, { busy(6, true), H.tick(Classic.intermission) })
	expect(s.phase).toBe("HeadStart")
	expect(s.players[6].life).toBe("Out")
	expect(s.players[6].role).toBe("Survivor") -- placeholder, not playing
	local playing = 0
	for _, p in s.players do
		if p.life ~= "Out" then
			playing += 1
		end
	end
	expect(playing).toBe(5)
	expect(RoundRules.viewFor(s, 6).busy).toBe(true)
end)

test("the countdown only counts players who are ready", function()
	local s = H.run(RoundRules.new(Classic, Rng.new(1)), H.join(5))
	expect(s.phase).toBe("Intermission")
	s = H.run(s, { busy(3, true) })
	expect(s.phase).toBe("Waiting") -- 4 ready of 5 needed
	expect(RoundRules.viewFor(s, 1).count).toBe(4)
	s = H.run(s, { busy(3, false) })
	expect(s.phase).toBe("Intermission")
end)

test("closing the dressing room mid-round: still out until the next round", function()
	local s = H.run(RoundRules.new(Classic, Rng.new(1)), H.join(6))
	s = H.run(s, { busy(6, true), H.tick(Classic.intermission + Classic.headStart) })
	expect(s.phase).toBe("Active")
	s = H.run(s, { busy(6, false) })
	expect(s.players[6].life).toBe("Out")
	s = H.run(s, { H.tick(Classic.roundLength + Classic.results + Classic.intermission) })
	expect(s.phase).toBe("HeadStart")
	expect(s.players[6].life).toBe("Alive") -- plays this one
end)

test("busy players keep their points and leaving clears the flag", function()
	local s = H.run(RoundRules.new(Classic, Rng.new(1)), H.join(6))
	s.players[6].points = 42
	s = H.run(s, { busy(6, true), H.tick(Classic.intermission) })
	expect(s.players[6].points).toBe(42)
	s = H.run(s, { H.left(6) })
	expect(s.busy[6]).toBeNil()
end)
