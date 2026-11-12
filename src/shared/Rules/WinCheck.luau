--!strict
-- Who won (or nobody yet). Pure.
local Types = require("../Types")
local Util = require("./Util")

local WinCheck = {}

function WinCheck.check(s: Types.RoundState): Types.Winner?
	local humans, zombies, escaped = 0, 0, 0
	for _, p in s.players do
		if p.life == "Out" then
			continue
		elseif p.life == "Escaped" then
			escaped += 1
		elseif Util.isHumanRole(p.role) then
			humans += 1 -- downed and hiding count as alive until they turn
		elseif Util.isZombieRole(p.role) then
			zombies += 1
		end
	end
	if humans == 0 then
		if escaped > 0 then
			return "SurvivorsEscaped"
		elseif zombies > 0 then
			return "ZombiesWin"
		end
		return "NoWinner"
	end
	-- the helicopter left with at least one human on board
	if s.heli and s.heli.phase == "Gone" and escaped > 0 then
		return "SurvivorsEscaped"
	end
	if s.timeLeft <= 1e-9 then
		return if escaped > 0 then "SurvivorsEscaped" else "SurvivorsSurvived"
	end
	return nil
end

return WinCheck
