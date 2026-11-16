--!strict
-- The safehouse's gentle scare director and the countdown escalation (design-safehouse.md §5).
-- Pure: the client asks what may happen and when; nothing here touches the world.
--   * At most one scare every 35-70s, never while a panel is open, never in the first 20s after
--     joining, never during the final countdown (the room has its own show then).
--   * The countdown runs calm -> ten -> five -> three, and the door opens at the very end.
local LobbyScares = {}

export type Event = { id: string, weight: number, caption: string }
export type Stage = "calm" | "ten" | "five" | "three"

LobbyScares.EVENTS = {
	{ id = "windowBang", weight = 25, caption = "[something bangs on the window]" },
	{ id = "bulbDip", weight = 20, caption = "[the light buzzes and dims]" },
	{ id = "footsteps", weight = 15, caption = "[footsteps cross the ceiling]" },
	{ id = "doorTest", weight = 10, caption = "[something outside tries the door]" },
	{ id = "eyes", weight = 10, caption = "[something is watching through the boards]" },
	{ id = "tallOne", weight = 3, caption = "[something blocks the moonlight]" },
} :: { Event }

LobbyScares.QUIET_AFTER_JOIN = 20 -- seconds
LobbyScares.DOOR_OPENS_AT = 0.8 -- seconds left on the countdown

-- One event, weighted, from a roll in [0, 1).
function LobbyScares.pick(roll: number): Event
	local total = 0
	for _, e in LobbyScares.EVENTS do
		total += e.weight
	end
	local target = roll * total
	for _, e in LobbyScares.EVENTS do
		target -= e.weight
		if target < 0 then
			return e
		end
	end
	return LobbyScares.EVENTS[#LobbyScares.EVENTS]
end

-- Seconds until the next scare, from a roll in [0, 1).
function LobbyScares.gap(roll: number): number
	return 35 + roll * 35
end

-- Where the countdown is. Only the countdown before a round escalates.
function LobbyScares.stage(phase: string?, timeLeft: number): Stage
	if phase ~= "Intermission" then
		return "calm"
	end
	if timeLeft <= 3 then
		return "three"
	elseif timeLeft <= 5 then
		return "five"
	elseif timeLeft <= 10 then
		return "ten"
	end
	return "calm"
end

-- May a scare play right now?
function LobbyScares.allowed(
	c: { inSafehouse: boolean, panelOpen: boolean, sinceJoin: number, stage: Stage }
): boolean
	return c.inSafehouse
		and not c.panelOpen
		and c.sinceJoin >= LobbyScares.QUIET_AFTER_JOIN
		and c.stage == "calm"
end

return LobbyScares
