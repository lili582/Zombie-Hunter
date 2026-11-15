--!strict
-- The character catalog window (VH2-style): open it at the dressing mirror in the safehouse or
-- with the CATALOG button in the lobby. Browse the real Roblox catalog, try anything on for free
-- (the server checks and saves it), pick body colours, see what you wear, reset to the default
-- character or copy your Roblox avatar. BUY opens Roblox's own purchase prompt (optional).
local AvatarEditorService = game:GetService("AvatarEditorService")
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local Outfit = require(Shared.Data.Outfit)
local Theme = require(script.Parent.Theme)

local C = Theme.colors
local player = Players.LocalPlayer

local CatalogController = {}

-- Catalog tabs: search tabs (Roblox asset types), then body colours and what you wear.
local TABS = {
	{ id = "Hats", name = "HATS", types = { "Hat" } },
	{ id = "Hair", name = "HAIR", types = { "HairAccessory" } },
	{ id = "FaceItems", name = "FACE", types = { "FaceAccessory" } },
	{
		id = "Extras",
		name = "EXTRAS",
		types = { "NeckAccessory", "ShoulderAccessory", "FrontAccessory", "BackAccessory", "WaistAccessory" },
	},
	{ id = "Shirts", name = "SHIRTS", types = { "Shirt" } },
	{ id = "Pants", name = "PANTS", types = { "Pants" } },
	{ id = "TShirts", name = "T-SHIRTS", types = { "TShirt" } },
	{ id = "Faces", name = "FACES", types = { "Face" } },
	{ id = "Colors", name = "BODY" },
	{ id = "Worn", name = "WEARING" },
}

local REASONS = {
	type = "THAT ITEM CAN'T BE WORN HERE (layered clothing / body parts)",
	full = "TOO MANY ACCESSORIES - TAKE ONE OFF FIRST",
	worn = "YOU'RE ALREADY WEARING THAT",
	in_round = "THE CATALOG OPENS BETWEEN ROUNDS",
	loading = "LOADING YOUR SAVE... TRY AGAIN",
	unknown = "ROBLOX COULDN'T FIND THAT ITEM",
	avatar = "COULDN'T LOAD YOUR ROBLOX AVATAR",
	slow = "",
}

local ui: { [string]: any } = {}
local outfit: any = Outfit.default()
local view: any = nil
local tab = "Hats"
local search = ""
local pages: any = nil
local searchToken = 0
local colorPart = "all"

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

local toastToken = 0
local function toast(text: string, color: Color3)
	if text == "" then
		return
	end
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

local function clearGrid()
	for _, child in ui.grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function thumb(id: number): string
	return `rbxthumb://type=Asset&id={id}&w=150&h=150`
end

-- One item card: picture, name, WEAR / REMOVE, and BUY.
local function card(order: number, id: number, name: string, canBuy: boolean)
	local worn = Outfit.wears(outfit, id)
	local c = Theme.panel(ui.grid, { LayoutOrder = order, BackgroundTransparency = 0.35 })
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Position = UDim2.fromOffset(8, 6)
	img.Size = UDim2.new(1, -16, 0, 74)
	img.ScaleType = Enum.ScaleType.Fit
	img.Image = thumb(id)
	img.Parent = c
	Theme.label(c, {
		Position = UDim2.fromOffset(6, 82),
		Size = UDim2.new(1, -12, 0, 16),
		TextScaled = false,
		TextSize = 11,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = name,
	})
	local wear = Theme.button(c, {
		Position = UDim2.new(0, 6, 1, -30),
		Size = UDim2.new(if canBuy then 0.62 else 1, -9, 0, 24),
		Text = if worn then "REMOVE" else "WEAR",
		TextColor3 = if worn then C.blood else C.mint,
	})
	wear.Activated:Connect(function()
		if Outfit.wears(outfit, id) then
			Remotes.get("CatalogRemove"):FireServer(id)
		else
			Remotes.get("CatalogWear"):FireServer(id)
		end
	end)
	if canBuy then
		local buy = Theme.button(c, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 1, -30),
			Size = UDim2.new(0.38, -3, 0, 24),
			Text = "BUY",
			TextColor3 = C.butter,
		})
		buy.Activated:Connect(function()
			-- a real Robux purchase: Roblox shows its own prompt with the price
			pcall(function()
				MarketplaceService:PromptPurchase(player, id)
			end)
		end)
	end
end

local function showPage(items: { any }, startOrder: number)
	for i, item in items do
		if type(item) == "table" and item.ItemType == "Asset" and type(item.Id) == "number" then
			card(startOrder + i, item.Id, tostring(item.Name or "?"), true)
		end
	end
end

local function runSearch(more: boolean)
	local t
	for _, candidate in TABS do
		if candidate.id == tab then
			t = candidate
		end
	end
	if not t or not t.types then
		return
	end
	searchToken += 1
	local my = searchToken
	if not more then
		clearGrid()
		pages = nil
	end
	ui.status.Text = "SEARCHING THE CATALOG..."
	ui.more.Visible = false
	task.spawn(function()
		local ok, err = pcall(function()
			if more and pages then
				pages:AdvanceToNextPageAsync()
			else
				local params = CatalogSearchParams.new()
				params.SearchKeyword = search
				local types = {}
				for _, name in t.types do
					table.insert(types, (Enum.AvatarAssetType :: any)[name])
				end
				params.AssetTypes = types
				pages = AvatarEditorService:SearchCatalog(params)
			end
		end)
		if my ~= searchToken then
			return
		end
		if not ok or not pages then
			ui.status.Text = "THE CATALOG ISN'T AVAILABLE RIGHT NOW"
			warn("Catalog search failed: " .. tostring(err))
			return
		end
		local items = pages:GetCurrentPage()
		showPage(items, #ui.grid:GetChildren() + 1)
		ui.status.Text = if #items == 0 then "NOTHING FOUND" else ""
		ui.more.Visible = not pages.IsFinished
	end)
end

local function showColors()
	clearGrid()
	ui.more.Visible = false
	ui.status.Text = ""
	ui.colorBar.Visible = true
	for i, rgb in Outfit.PALETTE do
		local swatch = Instance.new("TextButton")
		swatch.LayoutOrder = i
		swatch.Text = ""
		swatch.BackgroundColor3 = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		swatch.AutoButtonColor = true
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = swatch
		local edge = Instance.new("UIStroke")
		edge.Color = C.lavender
		edge.Transparency = 0.6
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Parent = swatch
		swatch.Parent = ui.grid
		swatch.Activated:Connect(function()
			Remotes.get("CatalogColor"):FireServer(colorPart, i)
		end)
	end
end

local function showWorn()
	clearGrid()
	ui.more.Visible = false
	local order = 0
	for _, key in { "face", "shirt", "pants", "tshirt" } do
		local id = outfit[key]
		if id and id ~= 0 then
			order += 1
			card(order, id, string.upper(key), false)
		end
	end
	for _, a in outfit.accessories do
		order += 1
		card(order, a.id, string.upper(a.slot), false)
	end
	ui.status.Text = if order == 0 then "NOTHING ON YET - THIS IS THE DEFAULT CHARACTER" else ""
end

local function refresh()
	if not ui.window or not ui.window.Visible then
		return
	end
	for id, b in ui.tabs do
		b.TextColor3 = if id == tab then C.bone else C.lavender
		b.BackgroundTransparency = if id == tab then 0.05 else 0.3
	end
	ui.colorBar.Visible = tab == "Colors"
	ui.searchRow.Visible = tab ~= "Colors" and tab ~= "Worn"
	if tab == "Colors" then
		showColors()
	elseif tab == "Worn" then
		showWorn()
	else
		runSearch(false)
	end
end

local function setOpen(open: boolean)
	if open and not inLobby() then
		toast(REASONS.in_round, C.blood)
		return
	end
	ui.window.Visible = open
	if open then
		refresh()
	end
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Catalog"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 6
	gui.Parent = player:WaitForChild("PlayerGui")

	-- CATALOG button (lobby only), next to SHOP
	ui.open = Theme.button(gui, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -184, 0, 12),
		Size = UDim2.fromOffset(86, 26),
		TextColor3 = C.blood,
		Text = "CATALOG",
	})
	ui.open.Activated:Connect(function()
		setOpen(not ui.window.Visible)
	end)

	-- the window sits on the left so you can see your character on the right
	local window = Theme.panel(gui, {
		Name = "Window",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromScale(0.55, 0.82),
		Visible = false,
	})
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(600, 520)
	limit.Parent = window
	ui.window = window
	Theme.label(window, {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(0.5, 0, 0, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.titleFont,
		TextColor3 = C.blood,
		Text = "CATALOG",
	})
	local close = Theme.button(window, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(30, 26),
		Text = "X",
		TextColor3 = C.blood,
	})
	close.Activated:Connect(function()
		setOpen(false)
	end)

	-- tabs (two rows of small pills)
	local tabRow = Instance.new("Frame")
	tabRow.BackgroundTransparency = 1
	tabRow.Position = UDim2.fromOffset(12, 44)
	tabRow.Size = UDim2.new(1, -24, 0, 58)
	tabRow.Parent = window
	local tabLayout = Instance.new("UIGridLayout")
	tabLayout.CellSize = UDim2.fromOffset(88, 24)
	tabLayout.CellPadding = UDim2.fromOffset(6, 6)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabRow
	ui.tabs = {}
	for i, t in TABS do
		local b = Theme.button(tabRow, { LayoutOrder = i, Text = t.name, TextSize = 12 })
		b.Activated:Connect(function()
			tab = t.id
			refresh()
		end)
		ui.tabs[t.id] = b
	end

	-- search box (catalog tabs)
	local searchRow = Instance.new("Frame")
	searchRow.BackgroundTransparency = 1
	searchRow.Position = UDim2.fromOffset(12, 108)
	searchRow.Size = UDim2.new(1, -24, 0, 28)
	searchRow.Parent = window
	ui.searchRow = searchRow
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, -96, 1, 0)
	box.Font = Theme.uiFont
	box.TextSize = 14
	box.TextColor3 = C.bone
	box.PlaceholderText = "search the catalog..."
	box.PlaceholderColor3 = C.lavender
	box.Text = ""
	box.ClearTextOnFocus = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	Theme.glass(box, true)
	local boxPad = Instance.new("UIPadding")
	boxPad.PaddingLeft = UDim.new(0, 10)
	boxPad.Parent = box
	box.Parent = searchRow
	local go = Theme.button(searchRow, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 88, 1, 0),
		Text = "SEARCH",
		TextColor3 = C.mint,
	})
	local function doSearch()
		search = box.Text
		runSearch(false)
	end
	go.Activated:Connect(doSearch)
	box.FocusLost:Connect(function(enter)
		if enter then
			doSearch()
		end
	end)

	-- body colour target (BODY tab)
	local colorBar = Instance.new("Frame")
	colorBar.BackgroundTransparency = 1
	colorBar.Position = UDim2.fromOffset(12, 108)
	colorBar.Size = UDim2.new(1, -24, 0, 28)
	colorBar.Visible = false
	colorBar.Parent = window
	local colorLayout = Instance.new("UIListLayout")
	colorLayout.FillDirection = Enum.FillDirection.Horizontal
	colorLayout.Padding = UDim.new(0, 6)
	colorLayout.Parent = colorBar
	ui.colorBar = colorBar
	local partButtons = {}
	for _, part in { "all", "head", "torso", "arms", "legs" } do
		local b = Theme.button(colorBar, {
			Size = UDim2.fromOffset(72, 28),
			Text = string.upper(part),
			TextColor3 = if part == colorPart then C.bone else C.lavender,
		})
		partButtons[part] = b
		b.Activated:Connect(function()
			colorPart = part
			for p, other in partButtons do
				other.TextColor3 = if p == colorPart then C.bone else C.lavender
			end
		end)
	end

	-- the grid of items / swatches
	local grid = Instance.new("ScrollingFrame")
	grid.Position = UDim2.fromOffset(12, 144)
	grid.Size = UDim2.new(1, -24, 1, -226)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 5
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.Parent = window
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(112, 136)
	gridLayout.CellPadding = UDim2.fromOffset(8, 8)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid
	ui.grid = grid
	ui.status = Theme.label(window, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.new(1, -24, 0, 20),
		TextScaled = false,
		TextSize = 13,
		TextColor3 = C.lavender,
		Text = "",
		ZIndex = 2,
	})

	-- bottom row: more results, reset, use my Roblox avatar
	ui.more = Theme.button(window, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -44),
		Size = UDim2.fromOffset(120, 28),
		Text = "MORE",
		Visible = false,
	})
	ui.more.Activated:Connect(function()
		runSearch(true)
	end)
	local reset = Theme.button(window, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -10),
		Size = UDim2.fromOffset(170, 28),
		Text = "RESET TO DEFAULT",
		TextColor3 = C.blood,
	})
	reset.Activated:Connect(function()
		Remotes.get("CatalogReset"):FireServer()
	end)
	local mine = Theme.button(window, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -10),
		Size = UDim2.fromOffset(200, 28),
		Text = "USE MY ROBLOX AVATAR",
		TextColor3 = C.baby,
	})
	mine.Activated:Connect(function()
		Remotes.get("CatalogUseAvatar"):FireServer()
	end)

	ui.toast = Theme.label(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 100),
		Size = UDim2.fromOffset(640, 26),
		TextScaled = false,
		TextSize = 18,
		Text = "",
		Visible = false,
	})
end

function CatalogController.start()
	build()
	Remotes.get("ProfileChanged").OnClientEvent:Connect(function(snapshot)
		if snapshot.outfit then
			outfit = snapshot.outfit
			-- redraw WEAR / REMOVE buttons without searching again
			if ui.window.Visible and (tab == "Worn") then
				showWorn()
			end
		end
	end)
	Remotes.get("CatalogResult").OnClientEvent:Connect(function(ok, reason)
		if ok then
			if reason == "reset" then
				toast("BACK TO THE DEFAULT CHARACTER", C.mint)
			elseif reason == "avatar_ok" then
				toast("YOU'RE WEARING YOUR ROBLOX AVATAR", C.mint)
			end
			if ui.window.Visible and tab ~= "Colors" and tab ~= "Worn" then
				-- flip the button on the card that changed
				for _, child in ui.grid:GetChildren() do
					local wear = child:FindFirstChildWhichIsA("TextButton")
					local img = child:FindFirstChildWhichIsA("ImageLabel")
					local id = img and tonumber(string.match(img.Image, "id=(%d+)"))
					if wear and id then
						local worn = Outfit.wears(outfit, id)
						wear.Text = if worn then "REMOVE" else "WEAR"
						wear.TextColor3 = if worn then C.blood else C.mint
					end
				end
			end
		else
			toast(REASONS[reason] or "CAN'T DO THAT", C.blood)
		end
	end)
	Remotes.get("RoundStateChanged").OnClientEvent:Connect(function(newView)
		view = newView
		local lobby = inLobby()
		ui.open.Visible = lobby
		if not lobby and ui.window.Visible then
			ui.window.Visible = false -- the catalog is locked during your round
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who == player and CollectionService:HasTag(prompt, "CatalogPrompt") then
			setOpen(true)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape and ui.window.Visible then
			setOpen(false)
		end
	end)
end

return CatalogController
