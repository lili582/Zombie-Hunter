--!strict
-- The in-round HUD. Draws only what the server sends (RoundStateChanged); sends nothing itself
-- except the player's own key presses. Each part of the screen is its own module in Hud/
-- (clock, player list, vitals, weapons, objectives, role help, lobby lines, effects): this
-- module builds them, hands them the latest round snapshot every frame, and routes input.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local Lobby = require(Shared.Rules.Lobby)
local Hud = script.Parent:WaitForChild("Hud")
local PlayerList = require(Hud.PlayerList)
local Weapons = require(Hud.Weapons)
local RoleHelp = require(Hud.RoleHelp)
local LobbyInfo = require(Hud.LobbyInfo)
local Effects = require(Hud.Effects)
local Prompts = require(Hud.Prompts)

local player = Players.LocalPlayer

local HudController = {}

-- every part of the screen, built in this order: later parts draw on top, so the edge tint
-- is underneath everything and the full-screen BLEEDING OUT / HIDING screens cover the rest
local PARTS = {
	Effects,
	require(Hud.TopBar),
	PlayerList,
	Weapons,
	RoleHelp,
	LobbyInfo,
	require(Hud.Vitals),
	require(Hud.Objectives),
}

local view: any = nil
local viewStamp = 0
local ammo = { mag = 0, reserve = 0 }

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	local widgets: { [string]: any } = {}
	for _, part in PARTS do
		part.build(gui, widgets)
	end
end

local function onState(newView: any)
	view = newView
	viewStamp = os.clock()
	PlayerList.update(view)
	Prompts.update(view)
end

-- One snapshot per frame for every part: the round, you, and the time left right now.
local function render()
	if not view then
		return
	end
	local mine = view.players[tostring(player.UserId)]
	local phase = view.phase
	local frame = {
		view = view,
		viewStamp = viewStamp,
		phase = phase,
		left = math.max(0, view.timeLeft - (os.clock() - viewStamp)),
		mine = mine,
		role = mine and mine.role or "-",
		inRound = mine ~= nil and not Lobby.isFree(phase, mine.life),
		ammo = ammo,
	}
	for _, part in PARTS do
		part.render(frame)
	end
end

local function onKey(input: InputObject, processed: boolean)
	if input.KeyCode == Enum.KeyCode.E and view and view.hidden then
		Remotes.get("LockerLeave"):FireServer()
	end
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Tab then
		PlayerList.toggle()
	elseif input.KeyCode == Enum.KeyCode.Q then
		Weapons.useAbility()
	elseif input.KeyCode == Enum.KeyCode.H then
		RoleHelp.toggle()
	end
end

function HudController.start()
	build()
	Remotes.get("RoundStateChanged").OnClientEvent:Connect(onState)
	Remotes.get("PointsPopup").OnClientEvent:Connect(Effects.popup)
	Remotes.get("ShotFired").OnClientEvent:Connect(Effects.tracer)
	Remotes.get("NoiseAlert").OnClientEvent:Connect(Effects.noisePing)
	Remotes.get("RevealHumans").OnClientEvent:Connect(Effects.revealHumans)
	Remotes.get("AmmoChanged").OnClientEvent:Connect(function(mag, reserve)
		ammo.mag, ammo.reserve = mag, reserve
	end)
	Remotes.get("ProfileChanged").OnClientEvent:Connect(function(profile)
		LobbyInfo.showCoins(profile.coins)
	end)
	Remotes.get("RequestProfile"):FireServer()
	for _, tag in Prompts.TAGS do
		CollectionService:GetInstanceAddedSignal(tag):Connect(function()
			Prompts.update(view)
		end)
	end
	RunService.RenderStepped:Connect(render)
	-- our own player list and health bar replace Roblox's
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
	UserInputService.InputBegan:Connect(onKey)
end

return HudController
