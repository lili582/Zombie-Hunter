--!strict
-- Guns and abilities: ammo, the crosshair (exactly where the shot goes), the phone RELOAD
-- button, and the Alpha's class ability button ([Q]).
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local AlphaClasses = require(Shared.Config.AlphaClasses)
local Theme = require(script.Parent.Parent.Theme)
local Aim = require(script.Parent.Parent.Aim)

local C = Theme.colors
local player = Players.LocalPlayer

local Weapons = {}

local ui: { [string]: any } = {} -- the HUD's shared widget table (set in build)

function Weapons.build(gui: ScreenGui, widgets: { [string]: any })
	ui = widgets
	-- hunter: ammo + crosshair
	ui.ammo = Theme.chip(gui, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(0, 34),
		TextSize = 20,
		Text = "",
		TextColor3 = C.peach,
		Visible = false,
	})
	ui.crosshair = Theme.label(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26),
		Text = "+",
		TextColor3 = C.peach,
		TextStrokeTransparency = 0.3,
		Visible = false,
	})

	-- phone: reload button for the Hunter (attack = tap, interact = prompt buttons)
	local reload = Theme.button(gui, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -108),
		Size = UDim2.fromOffset(64, 64),
		Text = "RELOAD",
		TextColor3 = C.peach,
		Visible = false,
	})
	reload.Activated:Connect(function()
		Remotes.get("Reload"):FireServer()
	end)
	ui.reload = reload

	-- Alpha: class ability button ([Q] on a keyboard), shows the cooldown
	local ability = Theme.button(gui, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -60),
		Size = UDim2.fromOffset(150, 40),
		TextSize = 16,
		Text = "",
		Visible = false,
	})
	ability.Activated:Connect(function()
		Remotes.get("UseAbility"):FireServer()
	end)
	ui.ability = ability
end

-- Every frame: draw from the latest round snapshot.
function Weapons.render(frame: any)
	local view, viewStamp, phase, role, inRound, ammo =
		frame.view, frame.viewStamp, frame.phase, frame.role, frame.inRound, frame.ammo
	-- gun bits: the Hunter, or every Survivor in an armed mode (Outbreak)
	local hasGun = inRound and (role == "Hunter" or (role == "Survivor" and view.humanWeapon ~= nil))
	local char = player.Character
	local holdingGun = hasGun
		and char ~= nil
		and char:FindFirstChildWhichIsA("Tool") ~= nil
		and (char:FindFirstChildWhichIsA("Tool") :: Tool):GetAttribute("Gun") == true
	ui.ammo.Visible = hasGun == true
	ui.ammo.Text = `{ammo.mag} / {ammo.reserve}`
	-- the crosshair sits exactly where the shot goes (mouse cursor, or screen centre on touch)
	ui.crosshair.Visible = holdingGun == true
	if holdingGun then
		local at = Aim.screenPoint()
		ui.crosshair.Position = UDim2.fromOffset(at.X, at.Y)
	end
	UserInputService.MouseIconEnabled = not (holdingGun and Aim.usesMouse())
	ui.reload.Visible = hasGun == true and UserInputService.TouchEnabled

	-- Alpha ability
	local showAbility = inRound and phase == "Active" and role == "Alpha" and view.alphaClass ~= nil
	ui.ability.Visible = showAbility == true
	if showAbility then
		local class = AlphaClasses.get(view.alphaClass)
		local wait = math.max(0, (view.abilityIn or 0) - (os.clock() - viewStamp))
		local key = if UserInputService.TouchEnabled then "" else " [Q]"
		ui.ability.Text = if wait > 0
			then `{string.upper(class.ability)} {math.ceil(wait)}s`
			else string.upper(class.ability) .. key
		-- ready: glowing red pill; cooling down: quiet glass
		ui.ability.BackgroundColor3 = if wait > 0 then C.plum else Color3.fromRGB(150, 20, 40)
		ui.ability.BackgroundTransparency = if wait > 0 then 0.3 else 0.1
		ui.ability.TextColor3 = if wait > 0 then C.lavender else C.bone
	end
end

-- [Q]: the Alpha's class ability, when the button is up.
function Weapons.useAbility()
	if ui.ability.Visible then
		Remotes.get("UseAbility"):FireServer()
	end
end

return Weapons
