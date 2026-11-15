--!strict
-- Input -> intents. Click/tap with a gun sends the direction from your head to the point under
-- the crosshair (Aim); R reloads. Melee and Claws need no code here: Tool.Activated reaches the server.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local Aim = require(script.Parent.Aim)

local player = Players.LocalPlayer

local WeaponController = {}

local function hookTool(tool: Instance)
	local isGun = tool:GetAttribute("Gun") == true -- Hunter's equipped gun, or an Outbreak Pistol
	if not tool:IsA("Tool") or not isGun or tool:GetAttribute("ClientHooked") then
		return
	end
	tool:SetAttribute("ClientHooked", true)
	tool.Activated:Connect(function()
		local char = player.Character
		local head = char and char:FindFirstChild("Head") :: BasePart?
		if head then
			local direction = Aim.worldPoint() - head.Position
			if direction.Magnitude > 0.01 then
				Remotes.get("FireWeapon"):FireServer(direction.Unit)
			end
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
