--!strict
-- The character catalog (VH2-style). Players browse the real Roblox catalog on their client and
-- ask to wear items; the server checks the item's type with Roblox (MarketplaceService), applies
-- the Outfit rules, saves the outfit in the profile and dresses the character. Try-on is free;
-- buying for real is a normal Roblox purchase prompt on the client. Lobby only.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Outfit = require(Shared.Data.Outfit)
local Remotes = require(Shared.Net.Remotes)
local DataService = require(script.Parent.DataService)
local CharacterService = require(script.Parent.CharacterService)

local CatalogService = {}

local canEdit: (Player) -> boolean = function(_player: Player)
	return true
end
local lastRequest: { [Player]: number } = {}
local typeCache: { [number]: number } = {} -- asset id -> AssetTypeId
local MIN_GAP = 0.3

local function reply(player: Player, ok: boolean, reason: string?, assetId: any)
	Remotes.get("CatalogResult"):FireClient(player, ok, reason, assetId)
end

-- The Roblox asset type of an item (cached). nil if Roblox can't tell us.
local function assetType(assetId: number): number?
	if typeCache[assetId] then
		return typeCache[assetId]
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(assetId, Enum.InfoType.Asset)
	end)
	if ok and type(info) == "table" and type(info.AssetTypeId) == "number" then
		typeCache[assetId] = info.AssetTypeId
		return info.AssetTypeId
	end
	return nil
end

-- Runs `change` on the player's outfit if they may edit now, then saves and dresses them.
local function edit(player: Player, change: (any) -> (boolean, string?))
	local now = os.clock()
	if now - (lastRequest[player] or 0) < MIN_GAP then
		return false, "slow"
	end
	lastRequest[player] = now
	if not canEdit(player) then
		return false, "in_round"
	end
	local profile = DataService.get(player)
	if not profile then
		return false, "loading"
	end
	local ok, reason = false, nil
	DataService.update(player, function(p)
		-- still on the starter? start editing from the look you actually have
		local wasPicked = p.outfitPicked
		if not wasPicked then
			p.outfit = Outfit.starter(Outfit.starterFor(player.UserId))
		end
		ok, reason = change(p.outfit)
		p.outfitPicked = if ok then true else wasPicked
	end)
	if ok then
		CharacterService.applyOutfit(player)
	end
	return ok, reason
end

-- Copies the player's real Roblox avatar (rigid accessories, clothes, face, colours).
local function fromRobloxAvatar(player: Player): any?
	local ok, desc = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(player.UserId)
	end)
	if not ok or not desc then
		return nil
	end
	local d = desc :: HumanoidDescription
	local o = Outfit.default()
	local function rgb(c: Color3): { number }
		return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
	end
	o.colors = {
		head = rgb(d.HeadColor),
		torso = rgb(d.TorsoColor),
		leftArm = rgb(d.LeftArmColor),
		rightArm = rgb(d.RightArmColor),
		leftLeg = rgb(d.LeftLegColor),
		rightLeg = rgb(d.RightLegColor),
	}
	o.face, o.shirt, o.pants, o.tshirt = d.Face, d.Shirt, d.Pants, d.GraphicTShirt
	for slot, prop in Outfit.ACCESSORY_PROPS do
		for idText in string.gmatch((d :: any)[prop], "%d+") do
			local id = tonumber(idText)
			if id and #o.accessories < Outfit.MAX_ACCESSORIES then
				table.insert(o.accessories, { id = id, slot = slot })
			end
		end
	end
	return Outfit.migrate(o)
end

function CatalogService.start(lobbyCheck: (Player) -> boolean)
	canEdit = lobbyCheck
	Remotes.get("CatalogWear").OnServerEvent:Connect(function(player, assetId)
		if type(assetId) ~= "number" or assetId <= 0 or assetId % 1 ~= 0 then
			return reply(player, false, "type", assetId)
		end
		local typeId = assetType(assetId)
		if not typeId then
			return reply(player, false, "unknown", assetId)
		end
		local ok, reason = edit(player, function(o)
			return Outfit.wear(o, assetId, typeId)
		end)
		reply(player, ok, reason, assetId)
	end)
	Remotes.get("CatalogRemove").OnServerEvent:Connect(function(player, assetId)
		if type(assetId) ~= "number" then
			return
		end
		local ok, reason = edit(player, function(o)
			return Outfit.remove(o, assetId), nil
		end)
		reply(player, ok, reason, assetId)
	end)
	Remotes.get("CatalogColor").OnServerEvent:Connect(function(player, part, paletteIndex)
		if type(part) ~= "string" or type(paletteIndex) ~= "number" then
			return
		end
		local ok, reason = edit(player, function(o)
			return Outfit.setColor(o, part, paletteIndex), nil
		end)
		if not ok then
			reply(player, ok, reason, nil)
		end
	end)
	Remotes.get("CatalogReset").OnServerEvent:Connect(function(player)
		-- back to your starter (boy / girl by user id), as if you never changed anything
		local ok, reason = edit(player, function(o)
			Outfit.replace(o, Outfit.starter(Outfit.starterFor(player.UserId)))
			return true, nil
		end)
		if ok then
			DataService.update(player, function(p)
				p.outfitPicked = false
			end)
		end
		reply(player, ok, if ok then "reset" else reason, nil)
	end)
	Remotes.get("CatalogStarter").OnServerEvent:Connect(function(player, kind)
		if type(kind) ~= "string" or not (Outfit.STARTERS :: any)[kind] then
			return
		end
		local ok, reason = edit(player, function(o)
			Outfit.replace(o, Outfit.starter(kind))
			return true, nil
		end)
		reply(player, ok, if ok then "starter" else reason, kind)
	end)
	Remotes.get("CatalogUseAvatar").OnServerEvent:Connect(function(player)
		local copy = fromRobloxAvatar(player)
		if not copy then
			return reply(player, false, "avatar", nil)
		end
		local ok, reason = edit(player, function(o)
			Outfit.replace(o, copy)
			return true, nil
		end)
		reply(player, ok, if ok then "avatar_ok" else reason, nil)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return CatalogService
