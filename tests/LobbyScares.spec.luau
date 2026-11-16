local lib = require("./lib")
local test, expect = lib.test, lib.expect
local LobbyScares = require("../src/shared/Rules/LobbyScares")

local function ok(overrides: { [string]: any })
	local c = { inSafehouse = true, panelOpen = false, sinceJoin = 60, stage = "calm" }
	for k, v in overrides do
		c[k] = v
	end
	return LobbyScares.allowed(c :: any)
end

test("a scare may play when you've been in the safehouse a while with nothing open", function()
	expect(ok({})).toBe(true)
end)

test("no scare while a panel (shop, catalog) is open", function()
	expect(ok({ panelOpen = true })).toBe(false)
end)

test("no scare in the first 20 seconds after joining", function()
	expect(ok({ sinceJoin = 19 })).toBe(false)
	expect(ok({ sinceJoin = 20 })).toBe(true)
end)

test("no lobby scares out on the map or during the final countdown", function()
	expect(ok({ inSafehouse = false })).toBe(false)
	expect(ok({ stage = "ten" })).toBe(false)
end)

test("scares come every 35-70 seconds", function()
	expect(LobbyScares.gap(0)).toBe(35)
	expect(LobbyScares.gap(0.999) < 70).toBe(true)
end)

test("the window bang is the most common scare, the Tall One the rarest", function()
	expect(LobbyScares.pick(0).id).toBe("windowBang")
	expect(LobbyScares.pick(0.999).id).toBe("tallOne")
	local counts = {}
	for i = 0, 999 do
		local id = LobbyScares.pick(i / 1000).id
		counts[id] = (counts[id] or 0) + 1
	end
	expect(counts.windowBang > counts.bulbDip).toBe(true)
	expect(counts.tallOne < counts.eyes).toBe(true)
end)

test("every scare has a caption", function()
	for _, e in LobbyScares.EVENTS do
		expect(#e.caption > 0).toBe(true)
	end
end)

test("the countdown escalates at 10, 5 and 3 seconds, only before a round", function()
	expect(LobbyScares.stage("Intermission", 30)).toBe("calm")
	expect(LobbyScares.stage("Intermission", 10)).toBe("ten")
	expect(LobbyScares.stage("Intermission", 5)).toBe("five")
	expect(LobbyScares.stage("Intermission", 2)).toBe("three")
	expect(LobbyScares.stage("Results", 2)).toBe("calm")
	expect(LobbyScares.stage("Waiting", 0)).toBe("calm")
end)
