--!strict
-- The role help icon (top left) and its "how to play your role" panel ([H]).
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local RoleGuide = require(Shared.Config.RoleGuide)
local Theme = require(script.Parent.Parent.Theme)

local C = Theme.colors

local RoleHelp = {}

local ui: { [string]: any } = {} -- the HUD's shared widget table (set in build)

-- Fills the role help panel: role title, the goal, then one line per tip.
local helpFor = ""
local function fillHelp(role: string, mode: string)
	local key = role .. "/" .. mode
	if key == helpFor then
		return
	end
	helpFor = key
	local guide = RoleGuide.get(role, mode)
	for _, child in ui.helpPanel:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if not guide then
		return
	end
	local color = Theme.roleColor[role] or C.bone
	local order = 0
	local function line(text: string, size: number, textColor: Color3, font: Enum.Font?)
		order += 1
		Theme.label(ui.helpPanel, {
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			TextScaled = false,
			TextSize = size,
			TextStrokeTransparency = 0.5,
			TextColor3 = textColor,
			Font = font or Theme.uiFont,
			Text = text,
		})
	end
	line(`YOU ARE THE {guide.title}`, 22, color, Theme.titleFont)
	line(guide.goal, 15, C.bone)
	for _, tip in guide.tips do
		line("-  " .. tip, 13, C.lavender)
	end
end

function RoleHelp.build(gui: ScreenGui, widgets: { [string]: any })
	ui = widgets
	-- role help: a round icon (top left) that opens "how to play your role" ([H])
	local help = Instance.new("TextButton")
	help.Name = "RoleHelp"
	help.Position = UDim2.fromOffset(16, 46)
	help.Size = UDim2.fromOffset(32, 32)
	help.BackgroundColor3 = C.baby
	help.Font = Theme.titleFont
	help.TextScaled = true
	help.TextColor3 = C.ink
	help.Text = "?"
	help.Visible = false
	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(1, 0)
	hc.Parent = help
	local hs = Instance.new("UIStroke")
	hs.Color = C.plum
	hs.Thickness = 2
	hs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	hs.Parent = help
	help.Parent = gui
	ui.help = help
	ui.helpStroke = hs
	ui.helpLabel = Theme.label(gui, {
		Position = UDim2.fromOffset(56, 46),
		Size = UDim2.fromOffset(200, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 14,
		Text = "",
		Visible = false,
	})
	Theme.label(ui.helpLabel, {
		Position = UDim2.fromOffset(0, 17),
		Size = UDim2.fromOffset(200, 13),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 11,
		TextColor3 = C.lavender,
		Text = if UserInputService.TouchEnabled then "tap ? for how to play" else "[H] how to play",
	})

	local panel = Theme.panel(gui, {
		Name = "RoleHelpPanel",
		Position = UDim2.fromOffset(16, 86),
		Size = UDim2.fromOffset(340, 10),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
	})
	local panelPad = Instance.new("UIPadding")
	panelPad.PaddingTop = UDim.new(0, 10)
	panelPad.PaddingBottom = UDim.new(0, 12)
	panelPad.PaddingLeft = UDim.new(0, 12)
	panelPad.PaddingRight = UDim.new(0, 12)
	panelPad.Parent = panel
	local panelLayout = Instance.new("UIListLayout")
	panelLayout.SortOrder = Enum.SortOrder.LayoutOrder
	panelLayout.Padding = UDim.new(0, 6)
	panelLayout.Parent = panel
	ui.helpPanel = panel
	help.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
end

-- Every frame: draw from the latest round snapshot.
function RoleHelp.render(frame: any)
	local view, phase, left, role, inRound = frame.view, frame.phase, frame.left, frame.role, frame.inRound
	-- role help icon: in a round, for your own role (pulses for the first seconds)
	local knowsRole = inRound
		and (role == "Survivor" or role == "Hunter" or role == "Alpha" or role == "Zombie")
	ui.help.Visible = knowsRole == true
	ui.helpLabel.Visible = knowsRole == true
	if knowsRole then
		local color = Theme.roleColor[role] or C.baby
		ui.help.BackgroundColor3 = color
		local guide = RoleGuide.get(role, view.mode)
		ui.helpLabel.Text = if guide then guide.title else ""
		ui.helpLabel.TextColor3 = color
		fillHelp(role, view.mode or "Classic")
		local pulse = phase == "HeadStart" or (phase == "Active" and left > view.roundLength - 8)
		ui.helpStroke.Thickness = if pulse then 3 + 2 * math.abs(math.sin(os.clock() * 4)) else 3
	else
		ui.helpPanel.Visible = false
	end
end

-- [H] / the ? icon: show or hide how to play your role.
function RoleHelp.toggle()
	if ui.help.Visible then
		ui.helpPanel.Visible = not ui.helpPanel.Visible
	end
end

return RoleHelp
