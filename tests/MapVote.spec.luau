local lib = require("./lib")
local test, expect = lib.test, lib.expect
local RoundRules = require("../src/shared/Rules/RoundRules")
local MapVote = require("../src/shared/Rules/MapVote")
local Classic = require("../src/shared/Config/Classic")
local Rng = require("../src/shared/Rng")
local H = require("./helpers")

local FOUR = { "Town", "Mall", "School", "Forest" }

local function vote(id, map)
	return { type = "VoteMap", playerId = id, mapId = map }
end

test("3 of 4 maps are shown, all different, in pool order", function()
	local rng = Rng.new(2)
	for _ = 1, 50 do
		local c = MapVote.choices(FOUR, {}, 3, 2, rng)
		expect(#c).toBe(3)
		local seen = {}
		local lastIndex = 0
		for _, id in c do
			expect(seen[id]).toBeNil()
			seen[id] = true
			local index = table.find(FOUR, id) :: number
			expect(index > lastIndex).toBeTruthy()
			lastIndex = index
		end
	end
end)

test("a map played twice in a row is not shown a third time", function()
	local rng = Rng.new(5)
	for _ = 1, 50 do
		local c = MapVote.choices(FOUR, { "School", "Mall", "Mall" }, 3, 2, rng)
		expect(table.find(c, "Mall")).toBeNil()
	end
	expect(MapVote.banned({ "Mall", "School" }, 2)).toBeNil()
	expect(MapVote.banned({ "Mall" }, 2)).toBeNil()
end)

test("only one map: it is always shown, even after repeats", function()
	expect(MapVote.choices({ "Town" }, { "Town", "Town", "Town" }, 3, 2, Rng.new(1))).toEqual({ "Town" })
end)

test("most votes wins; a tie is broken at random among the tied maps", function()
	local choices = { "Town", "Mall", "School" }
	expect(MapVote.winner(choices, { [1] = "Mall", [2] = "Mall", [3] = "Town" }, Rng.new(1))).toBe("Mall")
	local rng, seen = Rng.new(3), {}
	for _ = 1, 100 do
		local w = MapVote.winner(choices, { [1] = "Town", [2] = "School" }, rng) :: string
		expect(w == "Town" or w == "School").toBeTruthy()
		seen[w] = true
	end
	expect(seen.Town and seen.School).toBeTruthy()
end)

test("votes count only during the intermission and only for maps on the board", function()
	local base = table.clone(Classic)
	base.mapPool = { "Town" }
	local s, fx = H.run(RoundRules.new(base, Rng.new(1)), H.join(4))
	s, fx = H.run(s, { vote(1, "Town") }) -- still waiting for players
	expect(s.votes[1]).toBeNil()
	s = H.run(s, H.join(1, 5))
	expect(s.phase).toBe("Intermission")
	expect(s.mapChoices).toEqual({ "Town" })
	s, fx = H.run(s, { vote(1, "Mall"), vote(2, "Town") })
	expect(s.votes[1]).toBeNil()
	expect(s.votes[2]).toBe("Town")
	local voted = H.find(fx, function(f)
		return f.type == "Announce" and f.card == "Voted"
	end)
	expect(voted[1].toPlayerId).toBe(2)
	local view = RoundRules.viewFor(s, 2)
	expect(view.mapVotes.Town).toBe(1)
	expect(view.myVote).toBe("Town")
	expect(RoundRules.viewFor(s, 3).myVote).toBeNil()
end)

test("the voted map is played, named on the map card, and remembered", function()
	local s = H.run(RoundRules.new(Classic, Rng.new(1)), H.join(5))
	local fx
	s, fx = H.run(s, { vote(1, "Town"), H.tick(Classic.intermission) })
	expect(s.mapId).toBe("Town")
	expect(s.mapHistory).toEqual({ "Town" })
	expect(#H.find(fx, function(f)
		return f.type == "MapChosen" and f.mapId == "Town"
	end)).toBe(1)
	local card = H.find(fx, function(f)
		return f.type == "Announce" and f.card == "Map"
	end)
	expect(card[1].data.name).toBe("ABANDONED TOWN")
	expect(next(s.votes)).toBeNil() -- votes are cleared for the next intermission
end)

test("a player who leaves takes their vote with them", function()
	local s = H.run(RoundRules.new(Classic, Rng.new(1)), H.join(6))
	s = H.run(s, { vote(6, "Town"), H.left(6) })
	expect(s.votes[6]).toBeNil()
end)
