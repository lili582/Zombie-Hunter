--!strict
-- Towers and lockers: the repair bar (bottom centre) and the dark HIDING screen with its
-- way out ([E] / LEAVE).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local Theme = require(script.Parent.Parent.Theme)

local C = Theme.colors

local Objectives = {}

local ui: { [string]: any } = {} -- the HUD's shared widget table (set in build)

function Objectives.build(gui: ScreenGui, widgets: { [string]: any })
	ui = widgets
	-- repairing: progress of the tower you're working on
	local repair = Instance.new("Frame")
	repair.Name = "Repair"
	repair.AnchorPoint = Vector2.new(0.5, 1)
	repair.Position = UDim2.new(0.5, 0, 1, -110)
	repair.Size = UDim2.fromOffset(240, 26)
	repair.BackgroundTransparency = 1
	repair.Visible = false
	repair.Parent = gui
	ui.repairText = Theme.label(repair, {
		Size = UDim2.new(1, 0, 0, 14),
		TextScaled = false,
		TextSize = 12,
		TextColor3 = C.mint,
		Text = "",
	})
	local repairTrack = Instance.new("Frame")
	repairTrack.AnchorPoint = Vector2.new(0, 1)
	repairTrack.Position = UDim2.fromScale(0, 1)
	repairTrack.Size = UDim2.new(1, 0, 0, 7)
	repairTrack.ClipsDescendants = true
	repairTrack.Parent = repair
	Theme.glass(repairTrack, true)
	local repairFill = Instance.new("Frame")
	repairFill.Size = UDim2.fromScale(0, 1)
	repairFill.BackgroundColor3 = C.mint
	repairFill.BorderSizePixel = 0
	repairFill.Parent = repairTrack
	local rfc = Instance.new("UICorner")
	rfc.CornerRadius = UDim.new(1, 0)
	rfc.Parent = repairFill
	ui.repairBack, ui.repairFill = repair, repairFill

	-- hiding in a locker: dark screen with slats and a way out
	local hiding = Instance.new("Frame")
	hiding.Size = UDim2.fromScale(1, 1)
	hiding.BackgroundColor3 = Color3.new(0, 0, 0)
	hiding.BackgroundTransparency = 0.25
	hiding.Visible = false
	hiding.Parent = gui
	for i = 0, 6 do -- light through the locker slats
		local slat = Instance.new("Frame")
		slat.BorderSizePixel = 0
		slat.BackgroundColor3 = C.lavender
		slat.BackgroundTransparency = 0.85
		slat.Position = UDim2.fromScale(0.35, 0.38 + i * 0.025)
		slat.Size = UDim2.fromScale(0.3, 0.006)
		slat.Parent = hiding
	end
	Theme.label(hiding, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromOffset(500, 32),
		Text = "HIDING... stay quiet",
		Font = Theme.titleFont,
		TextColor3 = C.lavender,
	})
	local leave = Instance.new("TextButton")
	leave.AnchorPoint = Vector2.new(0.5, 0)
	leave.Position = UDim2.fromScale(0.5, 0.67)
	leave.Size = UDim2.fromOffset(170, 40)
	leave.BackgroundColor3 = C.dusk
	leave.Font = Theme.uiFont
	leave.TextScaled = true
	leave.TextColor3 = C.bone
	leave.Text = "[E] LEAVE"
	local lc = Instance.new("UICorner")
	lc.CornerRadius = UDim.new(0, 10)
	lc.Parent = leave
	leave.Parent = hiding
	leave.Activated:Connect(function()
		Remotes.get("LockerLeave"):FireServer()
	end)
	ui.hiding = hiding
end

-- Every frame: draw from the latest round snapshot.
function Objectives.render(frame: any)
	local view, inRound = frame.view, frame.inRound
	-- repairing a tower
	local towerId = inRound and view.repairing
	local tower = towerId and view.towers[tostring(towerId)]
	-- (tower can be false here, not just nil: only a real tower shows the bar)
	ui.repairBack.Visible = if tower then true else false
	if tower then
		ui.repairFill.Size = UDim2.fromScale(math.clamp(tower.progress, 0, 1), 1)
		ui.repairText.Text = `REPAIRING  {math.floor(tower.progress * 100)}%`
	end

	-- hiding
	ui.hiding.Visible = inRound and view.hidden == true or false
end

return Objectives
