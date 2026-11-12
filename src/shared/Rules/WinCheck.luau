--!strict
-- Who won (or nobody yet). Pure.
local Types = require("../Types")
local Util = require("./Util")

local WinCheck = {}

function WinCheck.check(s: Types.RoundState): Types.Winner?
	local humans, zombies = 0, 0
	for _, p in s.players do
		if p.life == "Out" then
			continue
		end
		if Util.isHumanRole(p.role) then
			humans += 1 -- downed counts as alive until they turn
		elseif Util.isZombieRole(p.role) then
			zombies += 1
		end
	end
	if humans == 0 and zombies == 0 then
		return "NoWinner"
	end
	if humans == 0 then
		return "ZombiesWin"
	end
	if s.timeLeft <= 1e-9 then
		return "SurvivorsSurvived"
	end
	return nil
end

return WinCheck
