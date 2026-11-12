--!strict
-- Survivor "escape" timing challenge. Pure: no Roblox APIs.
-- When a zombie claws a Survivor, the Survivor sees a bar with a moving needle (0 -> 1) and a
-- target zone. Clicking while the needle is in the zone dodges the attack.
local Weapons = require("../Config/Weapons")

export type Challenge = { zoneStart: number, zoneSize: number, window: number }

local Dodge = {}

function Dodge.newChallenge(rng: { float: (any) -> number }): Challenge
	local cfg = Weapons.Dodge
	local size = cfg.zoneSize
	-- zone somewhere in the middle/late part of the bar, never right at the start
	local start = 0.3 + rng:float() * (0.95 - size - 0.3)
	return { zoneStart = start, zoneSize = size, window = cfg.window }
end

-- claimed: needle position (0..1) the client says it clicked at.
-- serverElapsed: seconds between the server sending the challenge and receiving the click.
-- rtt: the player's round-trip network time in seconds.
function Dodge.judge(c: Challenge, claimed: any, serverElapsed: number, rtt: number): (boolean, string)
	local tol = Weapons.Dodge.tolerance
	if type(claimed) ~= "number" or claimed ~= claimed or claimed < 0 or claimed > 1 then
		return false, "bad_input"
	end
	if serverElapsed > c.window * (1 + tol) + rtt then
		return false, "too_late"
	end
	-- the client's needle starts ~half an RTT late and its click arrives ~half an RTT later
	local estimate = (serverElapsed - rtt) / c.window
	if math.abs(claimed - estimate) > tol then
		return false, "timing_mismatch"
	end
	if claimed < c.zoneStart or claimed > c.zoneStart + c.zoneSize then
		return false, "missed"
	end
	return true, "escaped"
end

return Dodge
