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
	return me == nil or me.life == "Out" or me.life == "Escaped"
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
	ui.window.Visible = open
	if open then
		refresh()
	end
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Shop"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
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
		setOpen(not ui.window.Visible)
	end)

	local window = Theme.panel(gui, {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.8),
		Visible = false,
	})
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 440)
	limit.Parent = window
	ui.window = window
	Theme.label(window, {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(0.5, 0, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.titleFont,
		TextColor3 = C.butter,
		Text = "Z-SHOP",
	})
	ui.coins = Theme.label(window, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -56, 0, 14),
		Size = UDim2.fromOffset(180, 28),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.butter,
		Text = "",
	})
	local close = button(window, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 12),
		Size = UDim2.fromOffset(34, 32),
		BackgroundColor3 = C.blood,
		Text = "X",
	})
	close.Activated:Connect(function()
		setOpen(false)
	end)

	ui.tabs = {}
	for i, t in Items.tabs do
		local b = button(window, {
			Position = UDim2.fromOffset(14 + (i - 1) * 150, 54),
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
	list.Position = UDim2.fromOffset(10, 94)
	list.Size = UDim2.new(1, -20, 1, -104)
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
	end)
	Remotes.get("RoundStateChanged").OnClientEvent:Connect(function(newView)
		view = newView
		local lobby = inLobby()
		ui.open.Visible = lobby
		if not lobby and ui.window.Visible then
			ui.window.Visible = false -- a round is starting for you
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
		if not processed and input.KeyCode == Enum.KeyCode.Escape and ui.window.Visible then
			setOpen(false)
		end
	end)
end

return ShopController
