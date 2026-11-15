--!strict
-- The Z-Shop window: opened at the shop counter in the safehouse (or the SHOP button in the
-- lobby). Tabs, item cards, BUY / EQUIP. The server decides everything (ShopBuy / ShopEquip);
-- this only draws the saved profile it is sent.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local Items = require(Shared.Config.Items)
local Theme = require(script.Parent.Theme)
local Room = require(script.Parent.Room)

local C = Theme.colors
local player = Players.LocalPlayer

local ShopController = {}

local profile: any = nil
local view: any = nil
local tab = Items.tabs[1].id
local ui: { [string]: any } = {}

local REASONS = {
	coins = "NOT ENOUGH Z-COINS",
	owned = "YOU ALREADY OWN THIS",
	not_owned = "BUY IT FIRST",
	in_round = "THE SHOP OPENS BETWEEN ROUNDS",
	loading = "LOADING YOUR SAVE... TRY AGAIN",
	unknown = "THAT ITEM DOESN'T EXIST",
}

local function rgb(c: { number }?): Color3
	return if c then Color3.fromRGB(c[1], c[2], c[3]) else C.lavender
end

local function inLobby(): boolean
	if not view then
		return true
	end
	if view.phase ~= "HeadStart" and view.phase ~= "Active" then
		return true
	end
	local me = view.players[tostring(player.UserId)]
	return me == nil or me.life == "Out" or me.life == "Escaped" or me.life == "Dead"
end

local function owns(id: string): boolean
	local item = Items.get(id)
	return item ~= nil and (item.price == 0 or (profile ~= nil and profile.owned[id] == true))
end

local function button(parent: Instance, props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	b.Font = Theme.uiFont
	b.TextScaled = true
	b.TextColor3 = C.ink
	b.BackgroundColor3 = C.mint
	b.AutoButtonColor = true
	for k, v in props do
		(b :: any)[k] = v
	end
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.ink
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	b.Parent = parent
	return b
end

local toastToken = 0
local function toast(text: string, color: Color3)
	toastToken += 1
	local my = toastToken
	ui.toast.Text = text
	ui.toast.TextColor3 = color
	ui.toast.Visible = true
	task.delay(2.2, function()
		if toastToken == my then
			ui.toast.Visible = false
		end
	end)
end

-- What the preview shows when you click a card: the weapon in your hand, or your zombie skin.
local function previewItem(id: string)
	local item = Items.get(id)
	if not item then
		return
	end
	ui.room:setModifier(function(model: Model)
		if item.skin then
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d.Parent == model and d.Name ~= "HumanoidRootPart" then
					d.Color = rgb(item.skin)
				elseif d:IsA("BodyColors") then
					d:Destroy()
				end
			end
			local head = model:FindFirstChild("Head") :: BasePart?
			if head then
				for _, x in { -0.22, 0.22 } do
					local eye = Instance.new("Part")
					eye.Shape = Enum.PartType.Ball
					eye.Size = Vector3.new(0.26, 0.26, 0.26)
					eye.Material = Enum.Material.Neon
					eye.Color = rgb(item.eyes)
					eye.Anchored = true
					eye.CanCollide = false
					eye.CFrame = head.CFrame * CFrame.new(x, 0.15, -head.Size.Z / 2 - 0.02)
					eye.Parent = model
				end
			end
		elseif item.look then
			local hand = (model:FindFirstChild("RightHand") or model:FindFirstChild("Right Arm")) :: BasePart?
			if hand then
				local size = Vector3.new(item.look.size[1], item.look.size[2], item.look.size[3])
				local tool = Instance.new("Part")
				tool.Size = size
				tool.Color = rgb(item.look.color)
				tool.Anchored = true
				tool.CanCollide = false
				-- held in the hand: guns point forward, melee weapons stand up
				tool.CFrame = hand.CFrame
					* CFrame.new(
						0,
						-hand.Size.Y / 2,
						if item.slot == "hunterGun" then -size.Z / 2 + 0.2 else 0
					)
					* (if item.slot == "hunterGun" then CFrame.new() else CFrame.new(0, size.Y / 2 - 0.4, 0))
				tool.Parent = model
			end
		end
	end)
	ui.previewName.Text = `PREVIEW: {item.name}`
end

local function refresh()
	if not ui.window then
		return
	end
	ui.coins.Text = if profile then `Z-COINS  {profile.coins}` else "Z-COINS  ..."
	for id, b in ui.tabs do
		b.BackgroundColor3 = if id == tab then C.blood else C.dusk
		b.TextColor3 = if id == tab then C.ink else C.lavender
	end
	for _, child in ui.list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for order, id in Items.order do
		local item = Items.get(id)
		if item.tab ~= tab then
			continue
		end
		local card = Theme.panel(ui.list, {
			Name = "Card",
			LayoutOrder = order,
			Size = UDim2.new(1, -8, 0, 64),
			BackgroundColor3 = C.ink,
			BackgroundTransparency = 0.2,
		})
		local look = Instance.new("TextButton") -- click the card to see it on your character
		look.Name = "Preview"
		look.BackgroundTransparency = 1
		look.Text = ""
		look.Size = UDim2.new(1, -124, 1, 0)
		look.ZIndex = 2
		look.Parent = card
		look.Activated:Connect(function()
			previewItem(id)
		end)
		if item.skin then -- a colour swatch for skins
			local swatch = Instance.new("Frame")
			swatch.Position = UDim2.fromOffset(8, 10)
			swatch.Size = UDim2.fromOffset(44, 44)
			swatch.BackgroundColor3 = rgb(item.skin)
			swatch.BorderSizePixel = 0
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = swatch
			swatch.Parent = card
			for _, x in { 12, 26 } do
				local eye = Instance.new("Frame")
				eye.Position = UDim2.fromOffset(x, 14)
				eye.Size = UDim2.fromOffset(7, 7)
				eye.BackgroundColor3 = rgb(item.eyes)
				eye.BorderSizePixel = 0
				eye.Parent = swatch
			end
		end
		local textLeft = if item.skin then 60 else 10
		Theme.label(card, {
			Position = UDim2.fromOffset(textLeft, 6),
			Size = UDim2.new(1, -(textLeft + 120), 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = false,
			TextSize = 20,
			Text = item.name,
		})
		Theme.label(card, {
			Position = UDim2.fromOffset(textLeft, 32),
			Size = UDim2.new(1, -(textLeft + 120), 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = false,
			TextSize = 13,
			TextWrapped = true,
			TextColor3 = C.lavender,
			Text = `{Items.slots[item.slot]}  -  {item.line}`,
		})
		local equipped = profile ~= nil and profile.equipped[item.slot] == id
		local b = button(card, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(104, 38),
		})
		if equipped then
			b.Text = "EQUIPPED"
			b.BackgroundColor3 = C.dusk
			b.TextColor3 = C.mint
			b.AutoButtonColor = false
		elseif owns(id) then
			b.Text = "EQUIP"
			b.BackgroundColor3 = C.mint
			b.Activated:Connect(function()
				Remotes.get("ShopEquip"):FireServer(id)
			end)
		else
			local short = profile ~= nil and profile.coins < item.price
			b.Text = `BUY {item.price}`
			b.BackgroundColor3 = if short then C.dusk else C.butter
			b.TextColor3 = if short then C.lavender else C.ink
			b.Activated:Connect(function()
				if profile and profile.coins < item.price then
					toast(
						`YOU NEED {item.price - profile.coins} MORE Z-COINS - play rounds to earn them`,
						C.blood
					)
					return
				end
				Remotes.get("ShopBuy"):FireServer(id)
			end)
		end
	end
end

local function setOpen(open: boolean)
	if open and not inLobby() then
		return
	end
	if open then
		ui.room:open()
		ui.room:setModifier(nil)
		ui.previewName.Text = "click an item to try it on"
		refresh()
	else
		ui.room:close()
	end
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Shop"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 8 -- the SHOP button and toasts, above the room
	gui.Parent = player:WaitForChild("PlayerGui")

	-- SHOP button (lobby only), under the PLAYERS toggle
	ui.open = Theme.button(gui, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -100, 0, 12),
		Size = UDim2.fromOffset(78, 26),
		TextColor3 = C.butter,
		Text = "SHOP",
	})
	ui.open.Activated:Connect(function()
		setOpen(not ui.room:isOpen())
	end)

	-- the shop room: a full screen, the items on the left, your character on the right
	ui.room = Room.new("Shop", "Z-SHOP", C.butter, 7)
	local window = ui.room.left
	ui.window = window
	ui.coins = Theme.label(ui.room.root, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 24),
		Size = UDim2.fromOffset(220, 30),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.butter,
		Text = "",
	})
	ui.previewName = Theme.label(ui.room.root, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 56),
		Size = UDim2.fromOffset(320, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextScaled = false,
		TextSize = 13,
		TextColor3 = C.lavender,
		Text = "",
	})

	ui.tabs = {}
	for i, t in Items.tabs do
		local b = button(window, {
			Position = UDim2.fromOffset(14 + (i - 1) * 150, 14),
			Size = UDim2.fromOffset(140, 30),
			Text = t.name,
		})
		b.Activated:Connect(function()
			tab = t.id
			refresh()
		end)
		ui.tabs[t.id] = b
	end

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(10, 54)
	list.Size = UDim2.new(1, -20, 1, -64)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = window
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list
	ui.list = list

	ui.toast = Theme.label(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 100),
		Size = UDim2.fromOffset(600, 30),
		Text = "",
		Visible = false,
	})
end

function ShopController.start()
	build()
	Remotes.get("ProfileChanged").OnClientEvent:Connect(function(snapshot)
		profile = snapshot
		refresh()
		ui.room:refreshSoon()
	end)
	Remotes.get("RoundStateChanged").OnClientEvent:Connect(function(newView)
		view = newView
		local lobby = inLobby()
		ui.open.Visible = lobby
		if not lobby and ui.room:isOpen() then
			ui.room:close() -- (can't happen while busy: the round leaves you out)
		end
	end)
	Remotes.get("ShopResult").OnClientEvent:Connect(function(ok, reason, itemId)
		local item = Items.get(itemId)
		if ok then
			toast(`{if item then item.name else "ITEM"} EQUIPPED`, C.mint)
		else
			toast(REASONS[reason] or "CAN'T DO THAT", C.blood)
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who == player and CollectionService:HasTag(prompt, "ShopPrompt") then
			setOpen(true)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape and ui.room:isOpen() then
			setOpen(false)
		end
	end)
end

return ShopController
