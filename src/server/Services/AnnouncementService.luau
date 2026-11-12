--!strict
-- Sends cards and banners to everyone, or privately to one player.
-- Adds display names for player-id fields so clients can print them.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)

local AnnouncementService = {}

local NAME_FIELDS = { "hunter1", "hunter2", "alpha1", "alpha2", "playerId" }

function AnnouncementService.send(card: string, toPlayerId: number?, data: { [string]: any }?)
	local payload = if data then table.clone(data) else {}
	for _, key in NAME_FIELDS do
		local id = payload[key]
		if type(id) == "number" then
			local p = Players:GetPlayerByUserId(id)
			payload[key .. "Name"] = if p then p.DisplayName else "???"
		end
	end
	local remote = Remotes.get("Announce")
	if toPlayerId then
		local p = Players:GetPlayerByUserId(toPlayerId)
		if p then
			remote:FireClient(p, card, payload)
		end
	else
		remote:FireAllClients(card, payload)
	end
end

return AnnouncementService
