--!strict
-- Full-screen cards (round start / end) and top banners (mid-round), VH2 style.
-- Cards play one after another in the order the server sent them. No emoji.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local Theme = require(script.Parent.Theme)

local C = Theme.colors
local player = Players.LocalPlayer

local AnnouncementController = {}

local CARD_TIME = {
	Map = 2,
	SomeoneInfected = 3,
	YourRole = 2,
	YourRules = 3,
	HunterChosen = 1.5,
	Result = 3,
	YourCoins = 2,
	Infected = 2.5,
}
local BANNERS = { AlphaAwakened = true, HunterFallen = true, NewHunter = true }

local ROLE_TITLE = {
	Survivor = "YOU ARE A SURVIVOR",
	Hunter = "YOU ARE THE HUNTER",
	Alpha = "YOU ARE THE ALPHA ZOMBIE",
	Zombie = "YOU ARE A ZOMBIE",
}
local ROLE_RULES = {
	Survivor = "No weapons  -  Hide  -  Revive friends  -  Survive 6:00\nZombie attack? CLICK IN TIME to escape!",
	Hunter = "Your role is SECRET  -  Only you have a gun\nProtect the survivors  -  Ammo boxes  -  [R] reload",
	Alpha = "Your role is SECRET  -  Wait for release\nInfect everyone  -  2 hits downs a human",
	Zombie = "Infect everyone  -  3 hits downs a human",
}
local RESULT_TEXT = {
	SurvivorsSurvived = { "SURVIVORS SURVIVED!", C.baby },
	SurvivorsEscaped = { "SURVIVORS ESCAPED!", C.baby },
	ZombiesWin = { "ZOMBIES WIN!", C.mint },
	NoWinner = { "NOBODY WINS", C.lavender },
}

local gui: ScreenGui
local card: Frame
local title: TextLabel
local subtitle: TextLabel
local static: Frame
local banner: TextLabel
local queue: { { card: string, data: any } } = {}
local playing = false

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "Announcements"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")

	card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.new(0, 0, 0)
	card.Visible = false
	card.Parent = gui

	static = Instance.new("Frame")
	static.Size = UDim2.fromScale(1, 1)
	static.BackgroundColor3 = C.lavender
	static.BackgroundTransparency = 0.95
	static.Parent = card

	title = Theme.label(card, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.8, 0.16),
		Font = Theme.titleFont,
		Text = "",
	})
	subtitle = Theme.label(card, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromScale(0.7, 0.1),
		Text = "",
		TextColor3 = C.lavender,
	})

	banner = Theme.label(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 140),
		Size = UDim2.fromOffset(700, 44),
		Font = Theme.titleFont,
		Text = "",
		Visible = false,
	})
end

local function slam(label: TextLabel)
	label.Size = UDim2.fromScale(0.95, 0.22)
	TweenService
		:Create(label, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.8, 0.16) })
		:Play()
end

local function namesInServer(): { string }
	local names = {}
	for _, p in Players:GetPlayers() do
		table.insert(names, p.DisplayName)
	end
	return names
end

local function fill(name: string, data: any)
	title.TextColor3 = C.bone
	subtitle.Text = ""
	card.BackgroundColor3 = Color3.new(0, 0, 0)
	if name == "Map" then
		title.Text = data.name or "???"
		subtitle.Text = data.line or ""
	elseif name == "SomeoneInfected" then
		title.Text = "SOMEONE IS INFECTED..."
		title.TextColor3 = C.blood
		-- names flicker like a roulette, then stop without showing the Alpha
		task.spawn(function()
			local names = namesInServer()
			for i = 1, 14 do
				if #names > 0 then
					subtitle.Text = names[math.random(1, #names)]
				end
				task.wait(0.05 + i * 0.012)
			end
			subtitle.Text = "?"
		end)
	elseif name == "YourRole" then
		title.Text = ROLE_TITLE[data.role] or ""
		title.TextColor3 = Theme.roleColor[data.role] or C.bone
	elseif name == "YourRules" then
		title.Text = Theme.roleText[data.role] or ""
		title.TextColor3 = Theme.roleColor[data.role] or C.bone
		subtitle.Text = ROLE_RULES[data.role] or ""
	elseif name == "HunterChosen" then
		title.Text = "A HUNTER WALKS AMONG YOU"
		title.TextColor3 = C.peach
		subtitle.Text = "Nobody knows who. Trust no one."
	elseif name == "Result" then
		local r = RESULT_TEXT[data.winner] or RESULT_TEXT.NoWinner
		title.Text = r[1]
		title.TextColor3 = r[2]
	elseif name == "YourCoins" then
		title.Text = `+{data.coins} Z-COINS`
		title.TextColor3 = C.butter
		subtitle.Text = `{data.points} points this round`
	elseif name == "Infected" then
		title.Text = "YOU'VE BEEN INFECTED!"
		title.TextColor3 = C.blood
		subtitle.Text = "You're a zombie now - keep scoring points!"
		card.BackgroundColor3 = Color3.fromRGB(10, 40, 25)
	end
end

local function playQueue()
	if playing then
		return
	end
	playing = true
	task.spawn(function()
		while #queue > 0 do
			local item = table.remove(queue, 1) :: any
			fill(item.card, item.data or {})
			card.Visible = true
			slam(title)
			local t = 0
			local duration = CARD_TIME[item.card] or 2
			while t < duration do
				static.BackgroundTransparency = 0.88 + math.random() * 0.1 -- light static
				t += task.wait(0.05)
			end
		end
		card.Visible = false
		playing = false
	end)
end

local bannerToken = 0
local function showBanner(name: string, _data: any)
	local text, color = "", C.blood
	if name == "AlphaAwakened" then
		text = "THE ALPHA HAS AWAKENED - it could be anyone"
	elseif name == "HunterFallen" then
		text = "THE HUNTER HAS FALLEN - GRAB THE GUN!"
		color = C.peach
	elseif name == "NewHunter" then
		text = "SOMEONE PICKED UP THE GUN"
		color = C.peach
	end
	bannerToken += 1
	local my = bannerToken
	banner.Text = text
	banner.TextColor3 = color
	banner.Visible = true
	task.spawn(function()
		for _ = 1, 8 do -- quick shake
			banner.Position = UDim2.new(0.5, math.random(-4, 4), 0, 140 + math.random(-3, 3))
			task.wait(0.03)
		end
		banner.Position = UDim2.new(0.5, 0, 0, 140)
	end)
	task.delay(3, function()
		if bannerToken == my then
			banner.Visible = false
		end
	end)
end

local function onAnnounce(name: string, data: any)
	if BANNERS[name] then
		showBanner(name, data or {})
	elseif CARD_TIME[name] then
		table.insert(queue, { card = name, data = data })
		playQueue()
	end
end

-- The "infected moment": my role flips from human to zombie during a round.
local lastRole: string? = nil
local function onState(view: any)
	local mine = view.players[tostring(player.UserId)]
	local role = mine and mine.role
	if view.phase == "Active" and role == "Zombie" and (lastRole == "Survivor" or lastRole == "Hunter") then
		onAnnounce("Infected", {})
	end
	lastRole = role
end

function AnnouncementController.start()
	build()
	Remotes.get("Announce").OnClientEvent:Connect(onAnnounce)
	Remotes.get("RoundStateChanged").OnClientEvent:Connect(onState)
end

return AnnouncementController
