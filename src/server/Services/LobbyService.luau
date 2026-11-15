--!strict
-- The safehouse lobby's interactive spots. Prompts become rule events; the boards show the state.
--   * Alpha class pedestals -> SetAlphaClass
--   * Map vote pads (3)     -> VoteMap (only during the countdown)
--   * Sign                  -> waiting / starting soon / round in progress (never the mode)
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Maps = require(Shared.Config.Maps)
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
			slot.label.Text = `{map.name}\n{n} {if n == 1 then "VOTE" else "VOTES"}`
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
end

function LobbyService.start(r: Round)
	round = r
	hookAll("AlphaPickPrompt", hookClassPrompt)
	hookAll("MapVotePrompt", hookVotePrompt)
end

return LobbyService
