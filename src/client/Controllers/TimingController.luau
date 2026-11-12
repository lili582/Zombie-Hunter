--!strict
-- Timing bar with a moving needle. Two kinds:
--   "dodge": a zombie is attacking you (Survivors) - ESCAPE!
--   "skill": skill check while repairing a radio tower - SKILL CHECK!
-- Click / tap / Space while the needle is in the mint zone. One try per bar.
-- The server decides if it counts (it checks the timing itself).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local Theme = require(script.Parent.Theme)

local C = Theme.colors
local player = Players.LocalPlayer

local TimingController = {}

local ui: { [string]: any } = {}
local active: { id: number, window: number, startedAt: number, tried: boolean, kind: string }? = nil

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TimingBar"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.68)
	holder.Size = UDim2.fromOffset(340, 80)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = gui
	ui.holder = holder

	ui.title = Theme.label(holder, {
		Size = UDim2.new(1, 0, 0, 30),
		Font = Theme.titleFont,
		TextColor3 = C.blood,
		Text = "ESCAPE!",
	})
	ui.hint = Theme.label(holder, {
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 0, 16),
		TextScaled = false,
		TextSize = 13,
		TextColor3 = C.lavender,
		Text = if UserInputService.TouchEnabled
			then "TAP when the needle is in the green"
			else "CLICK or SPACE when the needle is in the green",
	})

	local bar = Theme.panel(holder, {
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 26),
		ClipsDescendants = true,
	})
	local zone = Instance.new("Frame")
	zone.BorderSizePixel = 0
	zone.BackgroundColor3 = C.mint
	zone.Size = UDim2.fromScale(0.2, 1)
	zone.Parent = bar
	ui.zone = zone

	local needle = Instance.new("Frame")
	needle.BorderSizePixel = 0
	needle.AnchorPoint = Vector2.new(0.5, 0)
	needle.BackgroundColor3 = C.bone
	needle.Size = UDim2.new(0, 4, 1, 0)
	needle.Parent = bar
	ui.needle = needle
end

local function hideSoon(text: string, color: Color3)
	ui.title.Text = text
	ui.title.TextColor3 = color
	local mine = active
	task.delay(0.6, function()
		if active == mine then
			active = nil
			ui.holder.Visible = false
		end
	end)
end

local function needlePos(): number
	if not active then
		return 0
	end
	return math.clamp((os.clock() - active.startedAt) / active.window, 0, 1)
end

local function tryEscape()
	if not active or active.tried then
		return
	end
	active.tried = true
	Remotes.get("TimingAttempt"):FireServer(active.id, needlePos())
end

local function onChallenge(id: number, kind: string, window: number, zoneStart: number, zoneSize: number)
	active = { id = id, window = window, startedAt = os.clock(), tried = false, kind = kind }
	ui.zone.Position = UDim2.fromScale(zoneStart, 0)
	ui.zone.Size = UDim2.fromScale(zoneSize, 1)
	if kind == "skill" then
		ui.title.Text = "SKILL CHECK!"
		ui.title.TextColor3 = C.butter
	else
		ui.title.Text = "ESCAPE!"
		ui.title.TextColor3 = C.blood
	end
	ui.holder.Visible = true
end

local function onResult(id: number, escaped: boolean)
	if active and active.id == id then
		local skill = active.kind == "skill"
		if escaped then
			hideSoon(if skill then "GOOD!" else "ESCAPED!", C.mint)
		else
			hideSoon(if skill then "FAILED - THEY HEARD THAT" else "CAUGHT!", C.blood)
		end
	end
end

function TimingController.start()
	build()
	Remotes.get("TimingChallenge").OnClientEvent:Connect(onChallenge)
	Remotes.get("TimingResult").OnClientEvent:Connect(onResult)
	UserInputService.InputBegan:Connect(function(input)
		if not active then
			return
		end
		local t = input.UserInputType
		if
			t == Enum.UserInputType.MouseButton1
			or t == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.Space
		then
			tryEscape()
		end
	end)
	RunService.RenderStepped:Connect(function()
		if active and not active.tried then
			ui.needle.Position = UDim2.fromScale(needlePos(), 0)
		end
	end)
end

return TimingController
