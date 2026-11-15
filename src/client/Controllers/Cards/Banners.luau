--!strict
-- Mid-round banners: a short line at the top of the screen that shakes in and fades after 3s.
-- Each banner is one entry in TEXT (name -> text and colour), so adding one changes nothing else.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AlphaClasses = require(Shared.Config.AlphaClasses)
local Maps = require(Shared.Config.Maps)
local Theme = require(script.Parent.Parent.Theme)

local C = Theme.colors

local Banners = {}

local TEXT: { [string]: (data: any) -> (string, Color3) } = {
	AlphaAwakened = function(_data: any): (string, Color3)
		local text = "THE ALPHA HAS AWAKENED - it could be anyone"
		local color = C.blood
		return text, color
	end,
	HunterFallen = function(data: any): (string, Color3)
		local text = if data.reason == "innocent"
			then "THE HUNTER SHOT AN INNOCENT - BOTH ARE DEAD. GRAB THE GUN!"
			else "THE HUNTER HAS FALLEN - GRAB THE GUN!"
		local color = C.peach
		return text, color
	end,
	NewHunter = function(_data: any): (string, Color3)
		local text = "SOMEONE PICKED UP THE GUN"
		local color = C.peach
		return text, color
	end,
	TowerRepaired = function(data: any): (string, Color3)
		local text = `A RADIO TOWER IS ONLINE  {data.done or "?"}/{data.needed or "?"}`
		local color = C.mint
		return text, color
	end,
	HeliIncoming = function(data: any): (string, Color3)
		local text = `HELICOPTER INCOMING - {data.seconds or 45}s`
		local color = C.butter
		return text, color
	end,
	HeliHere = function(_data: any): (string, Color3)
		local text = "THE HELICOPTER IS HERE - GET TO THE ZONE!"
		local color = C.butter
		return text, color
	end,
	Voted = function(data: any): (string, Color3)
		local map = Maps.get(data.mapId)
		local text = `YOU VOTED: {if map then map.name else "?"}`
		local color = C.lavender
		return text, color
	end,
	AlphaPicked = function(data: any): (string, Color3)
		local class = AlphaClasses.get(data.class)
		local text = `IF YOU ARE THE ALPHA: {class.name}`
		local color = C.blood
		return text, color
	end,
}

local ui: { [string]: any } = {}
local bannerToken = 0

function Banners.has(name: string): boolean
	return TEXT[name] ~= nil
end

function Banners.build(gui: ScreenGui)
	ui.banner = Theme.label(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 140),
		Size = UDim2.fromOffset(700, 44),
		Font = Theme.titleFont,
		Text = "",
		Visible = false,
	})
end

function Banners.show(name: string, data: any)
	local text, color = TEXT[name](data)
	bannerToken += 1
	local my = bannerToken
	local banner = ui.banner
	banner.Text = text
	banner.TextColor3 = color
	banner.Visible = true
	task.spawn(function()
		for _ = 1, 10 do -- shake + flicker
			banner.Position = UDim2.new(0.5, math.random(-5, 5), 0, 140 + math.random(-3, 3))
			banner.TextTransparency = if math.random() < 0.3 then 0.6 else 0
			task.wait(0.03)
		end
		banner.Position = UDim2.new(0.5, 0, 0, 140)
		banner.TextTransparency = 0
	end)
	task.delay(3, function()
		if bannerToken == my then
			banner.Visible = false
		end
	end)
end

return Banners
