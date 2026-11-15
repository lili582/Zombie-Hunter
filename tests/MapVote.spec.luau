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
	local Maps = require("../src/shared/Config/Maps")
	local s = H.run(RoundRules.new(Classic, Rng.new(1)), H.join(5))
	local pick = s.mapChoices[#s.mapChoices] -- any map on the board
	local fx
	s, fx = H.run(s, { vote(1, pick), H.tick(Classic.intermission) })
	expect(s.mapId).toBe(pick)
	expect(s.mapHistory).toEqual({ pick })
	expect(#H.find(fx, function(f)
		return f.type == "MapChosen" and f.mapId == pick
	end)).toBe(1)
	local card = H.find(fx, function(f)
		return f.type == "Announce" and f.card == "Map"
	end)
	expect(card[1].data.name).toBe(Maps.get(pick).name)
	expect(next(s.votes)).toBeNil() -- votes are cleared for the next intermission
end)

test("a player who leaves takes their vote with them", function()
	local s = H.run(RoundRules.new(Classic, Rng.new(1)), H.join(6))
	s = H.run(s, { vote(6, "Town"), H.left(6) })
	expect(s.votes[6]).toBeNil()
end)

test("each map brings its own tower spots: the round uses the voted map's spots", function()
	local forest =
		{ towerSpots = { { x = 1000, z = 0 }, { x = 1200, z = 0 }, { x = 1400, z = 0 } }, heliZoneCount = 2 }
	local base = table.clone(Classic)
	base.mapPool = { "Town" }
	base.mapMetas = { Town = forest }
	local s = H.run(RoundRules.new(base, Rng.new(1), H.mapMeta), H.join(5))
	s = H.run(s, { H.tick(Classic.intermission) })
	expect(s.mapMeta).toBe(forest)
	for id in s.towers do
		expect(forest.towerSpots[id] ~= nil).toBeTruthy()
	end
end)

test("without per-map data the round keeps the map data it was given", function()
	local s = H.run(RoundRules.new(Classic, Rng.new(1), H.mapMeta), H.join(5))
	s = H.run(s, { H.tick(Classic.intermission) })
	expect(s.mapMeta).toBe(H.mapMeta)
end)

test("with all four maps, the board shows 3 different ones", function()
	local s = H.run(RoundRules.new(Classic, Rng.new(3)), H.join(5))
	expect(#s.mapChoices).toBe(3)
	expect(s.mapChoices[1] ~= s.mapChoices[2] and s.mapChoices[2] ~= s.mapChoices[3]).toBeTruthy()
end)
