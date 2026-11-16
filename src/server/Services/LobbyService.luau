--!strict
-- The safehouse lobby's interactive spots. Prompts become rule events; the boards show the state.
--   * Alpha class pedestals -> SetAlphaClass
--   * Map vote pads (3)     -> VoteMap (only during the countdown)
--   * Sign                  -> waiting / starting soon / round in progress (never the mode)
--   * MISSING posters       -> the players infected last round, with their faces
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Maps = require(Shared.Config.Maps)
local Lobby = require(Shared.Rules.Lobby)
local MapService = require(script.Parent.MapService)

local LobbyService = {}

type Round = {
	getState: () -> any,
	send: (event: any) -> (),
}

local round: Round

local function hookClassPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	prompt.Triggered:Connect(function(player)
		round.send({ type = "SetAlphaClass", playerId = player.UserId, class = prompt:GetAttribute("Class") })
	end)
end

local function hookVotePrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	prompt.Triggered:Connect(function(player)
		local slot = prompt:GetAttribute("Slot")
		local mapId = type(slot) == "number" and round.getState().mapChoices[slot]
		if mapId then
			round.send({ type = "VoteMap", playerId = player.UserId, mapId = mapId })
		end
	end)
end

local function hookAll(tag: string, hook: (Instance) -> ())
	for _, prompt in CollectionService:GetTagged(tag) do
		hook(prompt)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(hook)
end

-- Updates the vote board and the mode sign. Called with every state broadcast.
-- Chalk tally marks: "||||/" for every 5, then single strokes.
local function tally(n: number): string
	if n == 0 then
		return "-"
	end
	local groups = {}
	for _ = 1, n // 5 do
		table.insert(groups, "||||/")
	end
	if n % 5 > 0 then
		table.insert(groups, string.rep("|", n % 5))
	end
	return table.concat(groups, " ")
end

-- The missing, newest first. They stay up until someone newer takes their place.
local missing: { { id: number, name: string } } = {}
local lastPhase: string? = nil

local function postMissing(state: any, refs: any)
	local fresh = {}
	for _, id in Lobby.missingIds(state.players, #refs.posters) do
		local player = Players:GetPlayerByUserId(id)
		table.insert(fresh, { id = id, name = if player then player.DisplayName else "UNKNOWN" })
	end
	for _, old in missing do
		local already = false
		for _, f in fresh do
			already = already or f.id == old.id
		end
		if not already and #fresh < #refs.posters then
			table.insert(fresh, old)
		end
	end
	missing = fresh
	for i, poster in refs.posters do
		local m = missing[i]
		poster.face.Image = if m then `rbxthumb://type=AvatarHeadShot&id={m.id}&w=150&h=150` else ""
		poster.name.Text = if m then string.upper(m.name) else "HAVE YOU SEEN ME?"
	end
end

function LobbyService.refresh(state: any)
	local refs = MapService.lobby
	if not refs then
		return
	end
	local voting = state.phase == "Intermission"
	local counts = {}
	for _, id in state.votes do
		counts[id] = (counts[id] or 0) + 1
	end
	for i, slot in refs.mapSlots do
		local mapId = state.mapChoices[i]
		local map = Maps.get(mapId)
		if map then
			local n = counts[mapId] or 0
			slot.label.Text = `{map.name}\n{tally(n)}`
			slot.prompt.ObjectText = map.name
		else
			slot.label.Text = "MORE MAPS\nCOMING SOON"
		end
		slot.prompt.Enabled = voting and map ~= nil
	end
	-- The mode stays a surprise until the MODE card in the intro.
	if state.phase == "Waiting" then
		refs.modeLabel.Text = "WAITING FOR PLAYERS"
	elseif voting then
		refs.modeLabel.Text = "NEXT ROUND STARTING SOON"
	else
		refs.modeLabel.Text = "ROUND IN PROGRESS"
	end
	-- a round just ended: whoever was infected in it goes up on the wall
	if state.phase == "Results" and lastPhase ~= "Results" and refs.posters then
		postMissing(state, refs)
	end
	lastPhase = state.phase
end

function LobbyService.start(r: Round)
	round = r
	hookAll("AlphaPickPrompt", hookClassPrompt)
	hookAll("MapVotePrompt", hookVotePrompt)
end

return LobbyService
