--!strict
-- The coin shop. Clients ask to buy or equip; the server checks you're not playing a round,
-- applies Shop rules to the saved profile and answers with ShopResult. Changes are saved by
-- DataService (autosave / leave). Equipped items take effect the next time you spawn in a round.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Shop = require(Shared.Data.Shop)
local Items = require(Shared.Config.Items)
local Remotes = require(Shared.Net.Remotes)
local DataService = require(script.Parent.DataService)

local ShopService = {}

type Round = {
	getState: () -> any,
	send: (event: any) -> (),
}

local round: Round
local lastRequest: { [Player]: number } = {}
local MIN_GAP = 0.25 -- seconds between requests (no spamming)

-- You can shop in the lobby: between rounds, or while sitting out a round.
function ShopService.canShop(player: Player): boolean
	local s = round.getState()
	if s.phase ~= "HeadStart" and s.phase ~= "Active" then
		return true
	end
	local p = s.players[player.UserId]
	return p == nil or p.life == "Out" or p.life == "Escaped" or p.life == "Dead"
end

local function handle(player: Player, itemId: any, action: (any, string) -> (boolean, string?))
	local now = os.clock()
	if now - (lastRequest[player] or 0) < MIN_GAP then
		return
	end
	lastRequest[player] = now
	local result = Remotes.get("ShopResult")
	if type(itemId) ~= "string" or not Items.get(itemId) then
		result:FireClient(player, false, "unknown", itemId)
		return
	end
	if not ShopService.canShop(player) then
		result:FireClient(player, false, "in_round", itemId)
		return
	end
	local profile = DataService.get(player)
	if not profile then
		result:FireClient(player, false, "loading", itemId)
		return
	end
	local ok, reason = false, nil
	DataService.update(player, function(p)
		ok, reason = action(p, itemId)
	end)
	result:FireClient(player, ok, reason, itemId)
end

function ShopService.start(r: Round)
	round = r
	Remotes.get("ShopBuy").OnServerEvent:Connect(function(player, itemId)
		handle(player, itemId, function(p, id)
			local ok, reason = Shop.buy(p, id)
			if ok then
				Shop.equip(p, id) -- buying puts it on
			end
			return ok, reason
		end)
	end)
	Remotes.get("ShopEquip").OnServerEvent:Connect(function(player, itemId)
		handle(player, itemId, Shop.equip)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

-- The equipped item for a slot (starter if the profile isn't loaded yet).
function ShopService.equipped(player: Player, slot: string): string
	return Shop.equipped(DataService.get(player), slot)
end

return ShopService
