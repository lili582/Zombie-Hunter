local lib = require("./lib")
local test, expect = lib.test, lib.expect
local RoundRules = require("../src/shared/Rules/RoundRules")
local Classic = require("../src/shared/Config/Classic")
local H = require("./helpers")

local function recapCard(fx)
	local cards = H.find(fx, function(f)
		return f.type == "Announce" and f.card == "Recap"
	end)
	return cards[1]
end

local function entry(card, id)
	for _, e in card.data.players do
		if e.id == id then
			return e
		end
	end
	return nil
end

test("round end recap: every player, their real role, what happened, who won", function()
	local s = H.activeRound(5) -- 1 Alpha, 2 Hunter, 3-5 Survivors
	-- the Alpha turns the Hunter, then the timer runs out with survivors alive
	s = H.run(s, { H.hit(1, 2), H.hit(1, 2), H.tick(Classic.bleedOut) })
	expect(s.players[2].role).toBe("Zombie")
	local fx
	s, fx = H.run(s, { H.tick(Classic.roundLength) })
	local card = recapCard(fx)
	expect(card ~= nil).toBeTruthy()
	expect(card.toPlayerId).toBeNil() -- everyone sees it: the round is over
	expect(card.data.winner).toBe("SurvivorsSurvived")
	expect(#card.data.players).toBe(5)
	local alpha, hunter, survivor = entry(card, 1), entry(card, 2), entry(card, 3)
	expect(alpha.role).toBe("Alpha")
	expect(alpha.outcome).toBe("ALPHA")
	expect(alpha.won).toBe(false)
	expect(hunter.role).toBe("Hunter") -- shown as the Hunter they were
	expect(hunter.outcome).toBe("INFECTED")
	expect(hunter.won).toBe(false)
	expect(survivor.outcome).toBe("SURVIVED")
	expect(survivor.won).toBe(true)
	-- winners come first
	expect(card.data.players[1].won).toBe(true)
	expect(card.data.players[#card.data.players].won).toBe(false)
end)

test("zombies win: the infected are on the winning side", function()
	local s = H.activeRound(5) -- 1 Alpha, 2 Hunter, 3-5 Survivors
	local events = {}
	for id = 2, 5 do
		table.insert(events, H.hit(1, id))
		table.insert(events, H.hit(1, id))
	end
	table.insert(events, H.tick(Classic.bleedOut))
	local fx
	s, fx = H.run(s, events)
	local card = recapCard(fx)
	expect(card.data.winner).toBe("ZombiesWin")
	expect(entry(card, 3).outcome).toBe("INFECTED")
	expect(entry(card, 3).won).toBe(true)
	expect(entry(card, 3).role).toBe("Survivor")
end)

test("players who sat the round out are not in the recap", function()
	local s = H.activeRound(5)
	s = H.run(s, H.join(1, 9))
	local _, fx = H.run(s, { H.tick(Classic.roundLength) })
	expect(entry(recapCard(fx), 9)).toBeNil()
end)

test("the recap never comes before the round is over", function()
	local s = H.activeRound(5)
	local _, fx = H.run(s, { H.tick(10) })
	expect(recapCard(fx)).toBeNil()
	expect(RoundRules.recap ~= nil).toBeTruthy()
end)
