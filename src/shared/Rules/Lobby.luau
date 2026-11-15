--!strict
-- Who is in the round, and who is free to use the lobby (shop, dressing room). One rule, used by
-- the server (what it allows) and the clients (what they show). Pure.
local Lobby = {}

-- Lives that are no longer part of the round being played.
local SITTING_OUT = { Out = true, Escaped = true, Dead = true }

-- Joined late / escaped / killed: not playing this round any more.
function Lobby.isSittingOut(life: string?): boolean
	return life ~= nil and SITTING_OUT[life] == true
end

-- Free to use the shop and the dressing room: there is no round going on, or you are not in it.
function Lobby.isFree(phase: string, life: string?): boolean
	local roundRunning = phase == "HeadStart" or phase == "Active"
	return not roundRunning or life == nil or Lobby.isSittingOut(life)
end

return Lobby
