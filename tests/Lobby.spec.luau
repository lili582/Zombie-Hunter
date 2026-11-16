local lib = require("./lib")
local test, expect = lib.test, lib.expect
local Lobby = require("../src/shared/Rules/Lobby")

test("between rounds everyone is free to use the shop and dressing room", function()
	expect(Lobby.isFree("Waiting", "Alive")).toBe(true)
	expect(Lobby.isFree("Intermission", "Alive")).toBe(true)
	expect(Lobby.isFree("Results", "Alive")).toBe(true)
end)

test("during a round, players who are playing are not free", function()
	expect(Lobby.isFree("HeadStart", "Alive")).toBe(false)
	expect(Lobby.isFree("Active", "Alive")).toBe(false)
	expect(Lobby.isFree("Active", "Downed")).toBe(false)
end)

test("during a round, players sitting it out are free: joined late, escaped, killed, unknown", function()
	expect(Lobby.isFree("Active", "Out")).toBe(true)
	expect(Lobby.isFree("Active", "Escaped")).toBe(true)
	expect(Lobby.isFree("Active", "Dead")).toBe(true)
	expect(Lobby.isFree("HeadStart", nil)).toBe(true)
end)

test("sitting out: Out, Escaped and Dead are not in the round any more; Alive and Downed are", function()
	expect(Lobby.isSittingOut("Out")).toBe(true)
	expect(Lobby.isSittingOut("Escaped")).toBe(true)
	expect(Lobby.isSittingOut("Dead")).toBe(true)
	expect(Lobby.isSittingOut("Alive")).toBe(false)
	expect(Lobby.isSittingOut("Downed")).toBe(false)
end)

test("missing posters show the players infected this round, not the Alpha or survivors", function()
	local players = {
		[30] = { wasInfected = true },
		[10] = { wasInfected = true },
		[20] = { wasInfected = false },
		[40] = {},
	}
	expect(Lobby.missingIds(players, 4)).toEqual({ 10, 30 })
end)

test("at most as many missing posters as fit on the board", function()
	local players = {}
	for id = 1, 6 do
		players[id] = { wasInfected = true }
	end
	expect(#Lobby.missingIds(players, 4)).toBe(4)
end)
