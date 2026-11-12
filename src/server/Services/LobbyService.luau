--!strict
-- The safehouse lobby's interactive spots: the Alpha class pedestals. Prompts become rule events.
local CollectionService = game:GetService("CollectionService")

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

function LobbyService.start(r: Round)
	round = r
	for _, prompt in CollectionService:GetTagged("AlphaPickPrompt") do
		hookClassPrompt(prompt)
	end
	CollectionService:GetInstanceAddedSignal("AlphaPickPrompt"):Connect(hookClassPrompt)
end

return LobbyService
