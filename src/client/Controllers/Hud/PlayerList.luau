--!strict
-- The compact player list (top right) and its PLAYERS button / [Tab]. No roles shown:
-- only your own row says what you are.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.Parent.Theme)

local C = Theme.colors
local player = Players.LocalPlayer

local LIST_WIDTH = 165 -- compact player list
local ROW_HEIGHT = 15

local PlayerList = {}

local ui: { [string]: any } = {} -- the HUD's shared widget table (set in build)

local function rebuildList(view: any)
	for _, child in ui.list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local rows = {}
	for _, p in view.players do
		table.insert(rows, p)
	end
	table.sort(rows, function(a, b)
		return a.points > b.points
	end)
	for i, p in rows do
		local other = Players:GetPlayerByUserId(p.id)
		local name = if other then other.DisplayName else "?"
		-- No roles in the list: only your own row says what you are.
		local isMe = p.id == player.UserId
		local roleText = if isMe then (Theme.roleText[p.role] or "") else ""
		if p.life == "Out" then
			roleText = "WAITING"
		elseif isMe and p.life == "Downed" then
			roleText = "DOWN"
		elseif isMe and p.life == "Dead" then
			roleText = "DEAD"
		end
		-- one compact row: name (cut if long) | role | points
		local row = Instance.new("Frame")
		row.Name = "Row"
		row.LayoutOrder = i
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
		row.Parent = ui.list
		local small = { TextScaled = false, TextSize = 12, TextStrokeTransparency = 0.4 }
		local function cell(props)
			for k, v in small do
				props[k] = props[k] or v
			end
			return Theme.label(row, props)
		end
		cell({
			Size = UDim2.new(0.5, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = name,
		})
		cell({
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(0.34, 0, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Theme.roleColor[p.role] or C.lavender,
			Text = roleText,
		})
		cell({
			Position = UDim2.fromScale(0.84, 0),
			Size = UDim2.new(0.16, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = C.butter,
			Text = tostring(p.points),
		})
	end
end

function PlayerList.build(gui: ScreenGui, widgets: { [string]: any })
	ui = widgets
	-- top right: player list
	local list = Theme.panel(gui, {
		Name = "PlayerList",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 46),
		Size = UDim2.fromOffset(LIST_WIDTH, 10),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = not UserInputService.TouchEnabled, -- phones start with it closed
	})
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 1)
	layout.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 3)
	pad.PaddingBottom = UDim.new(0, 3)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = list
	ui.list = list

	-- small toggle button (and Tab on a keyboard) to show / hide the list
	local toggle = Theme.button(gui, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 12),
		Size = UDim2.fromOffset(78, 26),
		Text = "PLAYERS",
	})
	toggle.Activated:Connect(function()
		list.Visible = not list.Visible
	end)
end

function PlayerList.render(_frame: any) end

-- Tab / the PLAYERS button.
function PlayerList.toggle()
	ui.list.Visible = not ui.list.Visible
end

function PlayerList.update(view: any)
	rebuildList(view)
end

return PlayerList
