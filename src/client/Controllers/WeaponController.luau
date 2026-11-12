--!strict
-- Input -> intents. Click/tap with the Revolver sends an aim direction; R reloads.
-- Bat and Claws need no code here: Tool.Activated already reaches the server.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local WeaponController = {}

local function hookTool(tool: Instance)
	if not tool:IsA("Tool") or tool.Name ~= "Revolver" or tool:GetAttribute("ClientHooked") then
		return
	end
	tool:SetAttribute("ClientHooked", true)
	tool.Activated:Connect(function()
		local char = player.Character
		local head = char and char:FindFirstChild("Head") :: BasePart?
		if head then
			Remotes.get("FireWeapon"):FireServer((mouse.Hit.Position - head.Position).Unit)
		end
	end)
end

local function watch(container: Instance)
	for _, t in container:GetChildren() do
		hookTool(t)
	end
	container.ChildAdded:Connect(hookTool)
end

function WeaponController.start()
	player.CharacterAdded:Connect(function(char)
		watch(char)
		watch(player:WaitForChild("Backpack"))
	end)
	if player.Character then
		watch(player.Character)
		watch(player:WaitForChild("Backpack"))
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.R then
			Remotes.get("Reload"):FireServer()
		end
	end)
end

return WeaponController
