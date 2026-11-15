--!strict
-- A full-screen "room" (the dressing room and the shop): a dark screen with a title, a glass
-- panel on the left for the controller's own buttons, and a big preview of your character on
-- the right that turns slowly (drag to turn it). While a room is open you are "busy": the server
-- leaves you out of the next round, so a round never pulls you out of the dressing room.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local Theme = require(script.Parent.Theme)
local CharacterCopy = require(script.Parent.CharacterCopy)

local C = Theme.colors
local player = Players.LocalPlayer

local Room = {}
Room.__index = Room

local openRooms = 0 -- busy while any room is open

function Room.new(name: string, title: string, accent: Color3, displayOrder: number)
	local gui = Instance.new("ScreenGui")
	gui.Name = name .. "Room"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = displayOrder
	gui.Parent = player:WaitForChild("PlayerGui")

	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.fromRGB(10, 7, 16)
	root.BackgroundTransparency = 0.04
	root.Visible = false
	root.Parent = gui
	local glow = Instance.new("UIGradient") -- dark at the edges, a little light in the middle
	glow.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(6, 4, 10)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(36, 24, 52)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 7, 16)),
	})
	glow.Rotation = 0
	glow.Parent = root

	Theme.label(root, {
		Position = UDim2.fromOffset(28, 18),
		Size = UDim2.new(0.5, 0, 0, 46),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.titleFont,
		TextColor3 = accent,
		Text = title,
	})
	Theme.label(root, {
		Position = UDim2.fromOffset(30, 62),
		Size = UDim2.new(0.5, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 12,
		TextColor3 = C.lavender,
		Text = "you'll sit the next round out while you're in here",
	})

	-- left: the controller's panel
	local left = Theme.panel(root, {
		Name = "Panel",
		Position = UDim2.fromOffset(24, 88),
		Size = UDim2.new(0.56, -36, 1, -112),
	})

	-- right: your character on a little stage
	local stage = Instance.new("ViewportFrame")
	stage.Name = "Preview"
	stage.AnchorPoint = Vector2.new(1, 0)
	stage.Position = UDim2.new(1, -24, 0, 70)
	stage.Size = UDim2.new(0.44, -24, 1, -150)
	stage.BackgroundTransparency = 1
	stage.Ambient = Color3.fromRGB(70, 60, 90)
	stage.LightColor = Color3.fromRGB(255, 225, 200)
	stage.LightDirection = Vector3.new(-0.5, -0.6, 1)
	stage.Parent = root
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = stage
	stage.CurrentCamera = cam
	local done = Theme.button(root, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -22),
		Size = UDim2.fromOffset(150, 38),
		TextSize = 18,
		Text = "DONE",
		TextColor3 = C.mint,
	})
	Theme.label(root, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -184, 1, -30),
		Size = UDim2.fromOffset(200, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextScaled = false,
		TextSize = 12,
		TextColor3 = C.lavender,
		Text = "drag your character to turn it",
	})

	local self = setmetatable({
		gui = gui,
		root = root,
		left = left,
		stage = stage,
		cam = cam,
		model = nil :: Model?,
		modifier = nil :: ((Model) -> ())?,
		yaw = 0, -- facing you
		dragging = false,
		onClose = {} :: { () -> () },
	}, Room)

	done.Activated:Connect(function()
		self:close()
	end)
	stage.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			self.dragging = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			self.dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			self.dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			self.yaw += input.Delta.X * 0.012
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		if root.Visible and self.model and self.model.Parent then
			if not self.dragging then
				self.yaw += dt * 0.35
			end
			self.model:PivotTo(CFrame.Angles(0, self.yaw, 0))
		end
	end)
	-- your character changed (try-on, starter, reset): show the new look
	player.CharacterAppearanceLoaded:Connect(function()
		self:refreshPreview()
	end)
	return self
end

function Room.isOpen(self: any): boolean
	return self.root.Visible
end

function Room.open(self: any)
	if self.root.Visible then
		return
	end
	self.root.Visible = true
	openRooms += 1
	Remotes.get("SetBusy"):FireServer(true)
	self:refreshPreview()
end

function Room.close(self: any)
	if not self.root.Visible then
		return
	end
	self.root.Visible = false
	openRooms = math.max(0, openRooms - 1)
	if openRooms == 0 then
		Remotes.get("SetBusy"):FireServer(false)
	end
	for _, fn in self.onClose do
		task.spawn(fn)
	end
end

-- Something extra on the preview (a zombie skin, a weapon in hand). nil = just you.
function Room.setModifier(self: any, fn: ((Model) -> ())?)
	self.modifier = fn
	self:refreshPreview()
end

-- Re-copies your character into the preview (after the server dressed you).
function Room.refreshPreview(self: any)
	if not self.root.Visible then
		return
	end
	local copy = CharacterCopy.of(player)
	if self.model then
		self.model:Destroy()
		self.model = nil
	end
	if not copy then
		return
	end
	copy:PivotTo(CFrame.new())
	if self.modifier then
		pcall(self.modifier, copy)
	end
	copy.Parent = self.stage
	self.model = copy
	local _, size = copy:GetBoundingBox()
	local h = math.max(size.Y, 5)
	self.cam.CFrame = CFrame.lookAt(Vector3.new(0, h * 0.08, -h * 2.2), Vector3.new(0, 0, 0))
end

-- Refresh the preview a moment later (the server needs a moment to dress the character).
function Room.refreshSoon(self: any)
	task.delay(0.6, function()
		self:refreshPreview()
	end)
end

return Room
