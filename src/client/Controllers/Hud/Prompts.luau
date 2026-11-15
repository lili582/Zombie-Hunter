--!strict
-- Which E-prompts you can use right now (revive, the dropped gun, ammo, repair, hide, search):
-- only the ones your role and state allow, none while you hide in a locker.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local Prompts = {}

Prompts.TAGS =
	{ "RevivePrompt", "GunPrompt", "AmmoPrompt", "RepairPrompt", "LockerHidePrompt", "LockerSearchPrompt" }

function Prompts.update(view: any)
	local mine = view and view.players[tostring(player.UserId)]
	local role = mine and mine.role
	local alive = mine and mine.life == "Alive"
	local human = role == "Survivor" or role == "Hunter"
	for _, prompt in CollectionService:GetTagged("RevivePrompt") do
		local ownBody = player.Character ~= nil and prompt:IsDescendantOf(player.Character)
		prompt.Enabled = human and alive and not ownBody
	end
	for _, prompt in CollectionService:GetTagged("GunPrompt") do
		prompt.Enabled = role == "Survivor" and alive
	end
	local armed = role == "Hunter" or (role == "Survivor" and view ~= nil and view.humanWeapon ~= nil)
	for _, prompt in CollectionService:GetTagged("AmmoPrompt") do
		local box = prompt.Parent
		prompt.Enabled = armed and box ~= nil and not box:GetAttribute("Empty")
	end
	local hidden = view ~= nil and view.hidden == true
	local canAct = human and alive and not hidden
	local zombie = (role == "Alpha" or role == "Zombie") and alive
	for _, prompt in CollectionService:GetTagged("RepairPrompt") do
		prompt.Enabled = canAct == true
	end
	for _, prompt in CollectionService:GetTagged("LockerHidePrompt") do
		prompt.Enabled = canAct == true
	end
	for _, prompt in CollectionService:GetTagged("LockerSearchPrompt") do
		prompt.Enabled = zombie == true
	end
	if hidden then
		for _, prompt in CollectionService:GetTagged("RevivePrompt") do
			prompt.Enabled = false
		end
		for _, prompt in CollectionService:GetTagged("GunPrompt") do
			prompt.Enabled = false
		end
	end
end

return Prompts
