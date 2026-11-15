--!strict
-- Lobby lines: your saved Z-Coins (top left) and the Alpha class you would play.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AlphaClasses = require(Shared.Config.AlphaClasses)
local Lobby = require(Shared.Rules.Lobby)
local Theme = require(script.Parent.Parent.Theme)

local C = Theme.colors

local LobbyInfo = {}

local ui: { [string]: any } = {} -- the HUD's shared widget table (set in build)

function LobbyInfo.build(gui: ScreenGui, widgets: { [string]: any })
	ui = widgets
	-- your saved Z-Coins (top left)
	ui.coins = Theme.chip(gui, {
		Position = UDim2.fromOffset(16, 12),
		Text = "",
		TextColor3 = C.butter,
		Visible = false, -- until your save has loaded
	})

	-- lobby: which Alpha class you will play if you are picked
	ui.alphaPref = Theme.chip(gui, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		TextSize = 13,
		Text = "",
		TextColor3 = C.blood,
		Visible = false,
	})
end

-- Every frame: draw from the latest round snapshot.
function LobbyInfo.render(frame: any)
	local view, phase, mine = frame.view, frame.phase, frame.mine
	-- lobby: your Alpha class
	local lobby = Lobby.isFree(phase, mine and mine.life)
	ui.alphaPref.Text = if lobby
		then `IF YOU ARE THE ALPHA: {AlphaClasses.get(view.alphaPref).name}  -  change it at the pedestals`
		else ""
	ui.alphaPref.Visible = ui.alphaPref.Text ~= ""
end

-- Your saved coins, once the save has loaded.
function LobbyInfo.showCoins(coins: number)
	ui.coins.Text = `Z-COINS  {coins}`
	ui.coins.Visible = true
end

return LobbyInfo
