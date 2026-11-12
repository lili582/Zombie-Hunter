local lib = require("./lib")
local test, expect = lib.test, lib.expect
local RoundRules = require("../src/shared/Rules/RoundRules")
local Classic = require("../src/shared/Config/Classic")
local AlphaClasses = require("../src/shared/Config/AlphaClasses")
local Rng = require("../src/shared/Rng")
local H = require("./helpers")

local function setClass(id, class)
	return { type = "SetAlphaClass", playerId = id, class = class }
end
local function ability(id)
	return { type = "UseAbility", playerId = id }
end
local function alphaOf(s)
	for id, p in s.players do
		if p.role == "Alpha" then
			return id
		end
	end
	return nil
end

test("everyone's Alpha class pick is used when they become the Alpha", function()
	local s = H.run(RoundRules.new(Classic, Rng.new(1)), H.join(5))
	local events = {}
	for id = 1, 5 do
		table.insert(events, setClass(id, "Tank"))
	end
	s = H.run(s, events)
	s = H.run(s, { H.tick(Classic.intermission) })
	expect(s.phase).toBe("HeadStart")
	local alpha = alphaOf(s)
	expect(s.players[alpha].alphaClass).toBe("Tank")
end)

test("no pick: the Alpha is a Runner", function()
	local s = H.run(RoundRules.new(Classic, Rng.new(1)), H.join(5))
	s = H.run(s, { H.tick(Classic.intermission) })
	expect(s.players[alphaOf(s)].alphaClass).toBe(AlphaClasses.default)
end)

test("unknown classes are refused and the pick is private", function()
	local s, fx = H.run(RoundRules.new(Classic, Rng.new(1)), H.join(5))
	s, fx = H.run(s, { setClass(3, "Dragon") })
	expect(s.alphaPrefs[3]).toBeNil()
	expect(#fx).toBe(0)
	s, fx = H.run(s, { setClass(3, "Screamer") })
	expect(s.alphaPrefs[3]).toBe("Screamer")
	local cards = H.find(fx, function(f)
		return f.type == "Announce" and f.card == "AlphaPicked"
	end)
	expect(cards[1].toPlayerId).toBe(3)
	expect(RoundRules.viewFor(s, 3).alphaPref).toBe("Screamer")
	expect(RoundRules.viewFor(s, 4).alphaPref).toBeNil()
end)

test("the Alpha's rules card names their class, privately", function()
	local s = H.run(RoundRules.new(Classic, Rng.new(1)), H.join(5))
	local events = {}
	for id = 1, 5 do
		table.insert(events, setClass(id, "Screamer"))
	end
	s = H.run(s, events)
	local fx
	s, fx = H.run(s, { H.tick(Classic.intermission) })
	local alpha = alphaOf(s)
	local rules = H.find(fx, function(f)
		return f.type == "Announce" and f.card == "YourRules" and f.toPlayerId == alpha
	end)
	expect(rules[1].data.alphaClass).toBe("Screamer")
	for _, f in fx do
		if f.type == "Announce" and f.toPlayerId == nil and f.data then
			expect(f.data.alphaClass).toBeNil()
		end
	end
end)

test("ability works only for an alive Alpha in the Active phase", function()
	local s = H.run(RoundRules.new(Classic, Rng.new(1)), H.join(5))
	s = H.run(s, { H.tick(Classic.intermission) })
	local alpha = alphaOf(s)
	local _, fx = H.run(s, { ability(alpha) }) -- HeadStart: claws still asleep
	expect(#H.find(fx, function(f)
		return f.type == "AbilityUsed"
	end)).toBe(0)
	s = H.run(s, { H.tick(Classic.headStart) })
	expect(s.phase).toBe("Active")
	s, fx = H.run(s, { ability(alpha) })
	local used = H.find(fx, function(f)
		return f.type == "AbilityUsed"
	end)
	expect(#used).toBe(1)
	expect(used[1].ability).toBe("Dash")
	-- a Survivor can't
	local other = if alpha == 1 then 2 else 1
	_, fx = H.run(s, { ability(other) })
	expect(#H.find(fx, function(f)
		return f.type == "AbilityUsed"
	end)).toBe(0)
end)

test("ability has a cooldown", function()
	local s = H.activeRound(5)
	s.players[1].alphaClass = "Tank"
	local fx
	s, fx = H.run(s, { ability(1) })
	expect(H.find(fx, function(f)
		return f.type == "AbilityUsed"
	end)[1].ability).toBe("Slam")
	expect(RoundRules.viewFor(s, 1).abilityIn).toBe(AlphaClasses.Tank.cooldown)
	expect(RoundRules.viewFor(s, 2).abilityIn).toBeNil() -- nobody else learns about it
	s, fx = H.run(s, { H.tick(AlphaClasses.Tank.cooldown - 1), ability(1) })
	expect(#H.find(fx, function(f)
		return f.type == "AbilityUsed"
	end)).toBe(0)
	s, fx = H.run(s, { H.tick(1), ability(1) })
	expect(#H.find(fx, function(f)
		return f.type == "AbilityUsed"
	end)).toBe(1)
end)

test("a Survivor who replaces a leaving Alpha gets their own class", function()
	local s = H.activeRound(5)
	s.alphaPrefs[3] = "Screamer"
	s.alphaPrefs[4] = "Screamer"
	s.alphaPrefs[5] = "Screamer"
	s = H.run(s, { H.left(1) })
	local alpha = alphaOf(s)
	expect(alpha ~= nil).toBeTruthy()
	expect(s.players[alpha].alphaClass).toBe("Screamer")
end)
