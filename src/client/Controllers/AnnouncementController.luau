--!strict
-- Full-screen cards (round start / end) and top banners (mid-round). This module only decides
-- WHAT shows WHEN: it queues the cards the server announces and plays them one after another.
-- How each card looks lives in Cards/IntroCards and Cards/EndCards, the shared card screen in
-- Cards/Screen, the banners in Cards/Banners. No emoji, no names leaked.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local Cards = script.Parent:WaitForChild("Cards")
local Screen = require(Cards.Screen)
local Banners = require(Cards.Banners)
local IntroCards = require(Cards.IntroCards)
local EndCards = require(Cards.EndCards)

local player = Players.LocalPlayer

local AnnouncementController = {}

type Card = { seconds: number | (data: any) -> number, play: (data: any, token: number) -> () }

-- every card the server (or this client) can show, by name
local CARDS: { [string]: Card } = table.clone(IntroCards :: any)
for name, card in EndCards :: any do
	CARDS[name] = card
end

local MAX_EXTRA_READ_TIME = 4 -- a card never waits more than this for its text

local queue: { { card: string, data: any } } = {}
local playing = false

local function secondsFor(card: Card, data: any): number
	if type(card.seconds) == "function" then
		return (card.seconds :: (any) -> number)(data)
	end
	return card.seconds :: number
end

local function playQueue()
	if playing then
		return
	end
	playing = true
	task.spawn(function()
		while #queue > 0 do
			local item = table.remove(queue, 1) :: any
			local card = CARDS[item.card]
			local data = item.data or {}
			card.play(data, Screen.begin())
			task.wait(secondsFor(card, data))
			-- still typing? let it finish, then leave it up a moment to be read
			local extra = 0
			while not Screen.isRead() and extra < MAX_EXTRA_READ_TIME do
				extra += task.wait(0.1)
			end
		end
		Screen.finish()
		playing = false
	end)
end

-- In the dressing room / shop you sit the round out: its intro cards don't play over you.
local amBusy = false

local function onAnnounce(name: string, data: any)
	if amBusy and IntroCards[name] then
		return
	end
	if Banners.has(name) then
		Banners.show(name, data or {})
	elseif CARDS[name] then
		table.insert(queue, { card = name, data = data })
		playQueue()
	end
end

-- The "infected moment": my role flips from human to zombie during a round.
local lastRole: string? = nil
local function onState(view: any)
	amBusy = view.busy == true
	local mine = view.players[tostring(player.UserId)]
	local role = mine and mine.role
	if view.phase == "Active" and role == "Zombie" and (lastRole == "Survivor" or lastRole == "Hunter") then
		task.delay(0.8, function() -- let the zombie body load so the card shows it
			onAnnounce("Infected", {})
		end)
	end
	lastRole = role
end

function AnnouncementController.start()
	local gui = Screen.build()
	Banners.build(gui)
	Remotes.get("Announce").OnClientEvent:Connect(onAnnounce)
	Remotes.get("RoundStateChanged").OnClientEvent:Connect(onState)
	RunService.RenderStepped:Connect(Screen.animate)
end

return AnnouncementController
