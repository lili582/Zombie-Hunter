local lib = require("./lib")
local test, expect = lib.test, lib.expect
local RoundRules = require("../src/shared/Rules/RoundRules")
local Classic = require("../src/shared/Config/Classic")
local Rng = require("../src/shared/Rng")
local H = require("./helpers")

local function fresh()
	return RoundRules.new(Classic, Rng.new(1))
end

test("4 players keep waiting and announce 4/5", function()
	local s, fx = H.run(fresh(), H.join(4))
	expect(s.phase).toBe("Waiting")
	local cards = H.find(fx, function(f)
		return f.type == "Announce" and f.card == "WaitingForPlayers"
	end)
	expect(cards[#cards].data).toEqual({ count = 4, needed = 5 })
end)

test("5 players start intermission, then head start after 20s", function()
	local s = H.run(fresh(), H.join(5))
	expect(s.phase).toBe("Intermission")
	s = H.run(s, { H.tick(20) })
	expect(s.phase).toBe("HeadStart")
end)

test("small ticks add up the same as one big tick", function()
	local s = H.run(fresh(), H.join(5))
	for _ = 1, 200 do
		s = H.run(s, { H.tick(0.1) })
	end
	expect(s.phase).toBe("HeadStart")
end)

test("apply never changes the state it was given", function()
	local s = H.run(fresh(), H.join(5))
	local before = s.phase
	RoundRules.apply(s, H.tick(25))
	expect(s.phase).toBe(before)
end)

test("Alpha id never appears in a public announce before Active", function()
	local s, fx = H.run(fresh(), H.join(8))
	s, fx = H.run(s, { H.tick(20) })
	local alpha
	for id, p in s.players do
		if p.role == "Alpha" then
			alpha = id
		end
	end
	expect(alpha ~= nil).toBeTruthy()
	for _, f in fx do
		if f.type == "Announce" and f.toPlayerId == nil and f.data then
			for _, v in f.data do
				expect(v ~= alpha).toBeTruthy()
			end
		end
	end
end)

test("secret roles: others see Alpha, Hunter and Survivors as ? for the whole round", function()
	local s = H.run(fresh(), H.join(8))
	s = H.run(s, { H.tick(20) })
	local alpha, hunter, other
	for id, p in s.players do
		if p.role == "Alpha" then
			alpha = id
		elseif p.role == "Hunter" then
			hunter = id
		else
			other = id
		end
	end
	expect(RoundRules.viewFor(s, other).players[tostring(alpha)].role).toBe("?")
	expect(RoundRules.viewFor(s, other).players[tostring(hunter)].role).toBe("?")
	expect(RoundRules.viewFor(s, alpha).players[tostring(alpha)].role).toBe("Alpha")
	expect(RoundRules.viewFor(s, hunter).players[tostring(hunter)].role).toBe("Hunter")
	s = H.run(s, { H.tick(Classic.headStart) }) -- Alpha released: still secret
	expect(s.phase).toBe("Active")
	expect(RoundRules.viewFor(s, other).players[tostring(alpha)].role).toBe("?")
	expect(RoundRules.viewFor(s, other).players[tostring(hunter)].role).toBe("?")
	s = H.run(s, { H.tick(360) }) -- results: still secret
	expect(s.phase).toBe("Results")
	expect(RoundRules.viewFor(s, other).players[tostring(alpha)].role).toBe("?")
end)

test("secret roles: no public announcement ever carries a player id", function()
	local s, fx = H.run(fresh(), H.join(8))
	local all = {}
	s, fx = H.run(s, { H.tick(20), H.tick(Classic.headStart) })
	for _, f in fx do
		table.insert(all, f)
	end
	-- Hunter turns, gun picked up, last zombie leaves -> replacement Alpha
	local alpha, hunter, survivor
	for id, p in s.players do
		if p.role == "Alpha" then
			alpha = id
		elseif p.role == "Hunter" then
			hunter = id
		else
			survivor = survivor or id
		end
	end
	s, fx = H.run(s, { H.hit(alpha, hunter), H.hit(alpha, hunter), H.tick(20), H.pickUp(survivor) })
	for _, f in fx do
		table.insert(all, f)
	end
	for _, f in all do
		if f.type == "Announce" and f.toPlayerId == nil then
			for _, v in f.data or {} do
				expect(s.players[v] == nil).toBeTruthy()
			end
		end
	end
	expect(#H.find(all, function(f)
		return f.card == "HunterChosen"
	end)).toBe(1)
	expect(#H.find(all, function(f)
		return f.card == "NewHunter"
	end)).toBe(1)
end)

test("infected (basic) zombies are visible to everyone", function()
	local s = H.run(H.activeRound(6), { H.hit(1, 3), H.hit(1, 3), H.tick(20) })
	expect(RoundRules.viewFor(s, 4).players["3"].role).toBe("Zombie")
	expect(RoundRules.viewFor(s, 4).players["1"].role).toBe("?")
end)

test("intro order: map, mode, someone infected, then private role cards", function()
	local s, fx = H.run(fresh(), H.join(5))
	s, fx = H.run(s, { H.tick(20) })
	local order = {}
	for _, f in fx do
		if f.type == "Announce" and (f.toPlayerId == nil or f.toPlayerId == 1) then
			table.insert(order, f.card)
		end
	end
	expect(order).toEqual({ "Map", "Mode", "SomeoneInfected", "YourRole", "YourRules", "HunterChosen" })
end)

test("humans get 10s to run after the intro before the Alpha is released", function()
	expect(Classic.headStart - Classic.introLength).toBe(10)
end)

test("every player gets a private role card", function()
	local s, fx = H.run(fresh(), H.join(6))
	s, fx = H.run(s, { H.tick(20) })
	local roleCards = H.find(fx, function(f)
		return f.card == "YourRole"
	end)
	expect(#roleCards).toBe(6)
	for _, f in roleCards do
		expect(f.toPlayerId ~= nil).toBeTruthy()
	end
end)

test("after 10s head start the round is Active with 360s and alpha revealed", function()
	local s = H.run(fresh(), H.join(8))
	s = H.run(s, { H.tick(20), H.tick(Classic.headStart) })
	expect(s.phase).toBe("Active")
	expect(s.timeLeft).toBe(360)
	expect(s.alphaRevealed).toBe(true)
end)

test("dropping below 2 players mid-round ends with NoWinner", function()
	local s = H.run(fresh(), H.join(5))
	s = H.run(s, { H.tick(20 + Classic.headStart) })
	s = H.run(s, { H.left(1), H.left(2), H.left(3), H.left(4) })
	expect(s.phase).toBe("Results")
	expect(s.winner).toBe("NoWinner")
end)

test("intermission falls back to waiting if players leave", function()
	local s = H.run(fresh(), H.join(5))
	s = H.run(s, { H.left(5) })
	expect(s.phase).toBe("Waiting")
end)

test("a player joining mid-round waits (Out) and plays next round", function()
	local s = H.activeRound(6)
	s = H.run(s, H.join(1, 99))
	expect(s.players[99].life).toBe("Out")
	s = H.run(s, { H.tick(360) }) -- survivors survive
	expect(s.phase).toBe("Results")
	s = H.run(s, { H.tick(15) })
	expect(s.phase).toBe("Intermission")
	expect(s.players[99].life).toBe("Alive")
end)

test("timer running out with humans alive: SurvivorsSurvived", function()
	local s = H.activeRound(6)
	s = H.run(s, { H.tick(360) })
	expect(s.winner).toBe("SurvivorsSurvived")
end)
