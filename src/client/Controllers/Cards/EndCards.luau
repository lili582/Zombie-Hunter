--!strict
-- Cards for the end of a round and for your own big moments: the result, the recap (every
-- player's character lit up one by one with their real role and what happened to them), your
-- coins, and the private cards (escaped, infected, shot an innocent, shot by the Hunter).
-- Each card: { seconds, play }.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Parent.Theme)
local CharacterCopy = require(script.Parent.Parent.CharacterCopy)
local Screen = require(script.Parent.Screen)

local C = Theme.colors
local player = Players.LocalPlayer
local ui = Screen.ui
local setTitle, slam, doFlash, typeText = Screen.setTitle, Screen.slam, Screen.flash, Screen.typeText
local stage, playEmote = Screen.stage, Screen.playEmote

local RESULT_TEXT = {
	SurvivorsSurvived = { "SURVIVORS SURVIVED!", C.baby },
	SurvivorsEscaped = { "SURVIVORS ESCAPED!", C.baby },
	ZombiesWin = { "ZOMBIES WIN!", C.mint },
	NoWinner = { "NOBODY WINS", C.lavender },
}

-- Round recap: everyone who played, lined up in the dark. One by one a light comes on over each
-- character with their name, the role they really had, and what happened to them.
local OUTCOME_LOOK = {
	SURVIVED = { "SURVIVED", Theme.colors.baby },
	ESCAPED = { "ESCAPED", Theme.colors.butter },
	INFECTED = { "INFECTED", Theme.colors.mint },
	ZOMBIE = { "ZOMBIE", Theme.colors.mint },
	ALPHA = { "THE ALPHA", Theme.colors.blood },
	KILLED = { "KILLED", Theme.colors.lavender },
}
local RECAP_STEP = 0.55 -- seconds between two reveals (slow on purpose)
local RECAP_MAX = 12

local function recapDuration(count: number): number
	return 2.2 + math.min(count, RECAP_MAX) * RECAP_STEP + 3.5
end

local function playRecap(data: any, token: number)
	local entries = data.players or {}
	local zombiesWon = data.winner == "ZombiesWin"
	setTitle("", C.bone)
	typeText(
		ui.title,
		if zombiesWon then "THE NIGHT BELONGS TO THEM" else "WHO MADE IT THROUGH THE NIGHT",
		0.06,
		token
	)
	ui.kicker.Text = "THE ROUND"
	ui.row.Size = UDim2.fromScale(0.94, 0.46)
	ui.row.Position = UDim2.fromScale(0.5, 0.42)
	local slots = {}
	for i = 1, math.min(#entries, RECAP_MAX) do
		local e = entries[i]
		local who = Players:GetPlayerByUserId(e.id)
		local look = OUTCOME_LOOK[e.outcome] or OUTCOME_LOOK.SURVIVED
		local slot = Instance.new("Frame")
		slot.Name = "RecapSlot"
		slot.LayoutOrder = i
		slot.Size = UDim2.fromScale(math.min(0.15, 0.9 / math.max(#entries, 1)), 1)
		slot.BackgroundTransparency = 1
		slot.Parent = ui.row
		local vp = Instance.new("ViewportFrame")
		vp.Size = UDim2.fromScale(1, 0.72)
		vp.BackgroundColor3 = Color3.fromRGB(12, 8, 18)
		vp.BackgroundTransparency = 0.4
		vp.Parent = slot
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = vp
		local model = if who then CharacterCopy.of(who) else nil
		if model then
			if e.outcome == "INFECTED" or e.outcome == "ZOMBIE" then
				CharacterCopy.zombify(model, Theme.colors.mint)
			elseif e.outcome == "ALPHA" then
				CharacterCopy.zombify(model, Color3.fromRGB(255, 40, 60))
			end
			stage(vp, model)
		end
		local function caption(y: number, height: number, text: string, color: Color3, size: number)
			return Theme.label(slot, {
				Position = UDim2.new(0, 0, 0.72, y),
				Size = UDim2.new(1, 0, 0, height),
				TextScaled = false,
				TextSize = size,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = color,
				TextTransparency = 1,
				TextStrokeTransparency = 1,
				Text = text,
			})
		end
		local name = caption(4, 16, if who then who.DisplayName else "?", C.bone, 14)
		local role =
			caption(20, 13, Theme.roleText[e.role] or e.role, Theme.roleColor[e.role] or C.lavender, 11)
		local outcome = caption(34, 16, look[1], look[2], 14)
		local winner = caption(52, 14, if e.won then "WINNER" else "", C.butter, 12)
		table.insert(
			slots,
			{ vp = vp, labels = { name, role, outcome, winner }, color = look[2], won = e.won }
		)
	end
	ui.row.Visible = #slots > 0
	task.spawn(function()
		task.wait(1.6)
		for _, slot in slots do
			if not Screen.isCurrent(token) then
				return
			end
			-- the light comes on over this one
			slot.vp.LightColor = slot.color
			slot.vp.Ambient = Color3.fromRGB(45, 38, 60)
			slot.vp.BackgroundColor3 = if slot.won
				then Color3.fromRGB(40, 32, 12)
				else Color3.fromRGB(18, 12, 26)
			slot.vp.BackgroundTransparency = 0.15
			for _, label in slot.labels do
				TweenService
					:Create(
						label,
						TweenInfo.new(0.35),
						{ TextTransparency = 0, TextStrokeTransparency = 0.55 }
					)
					:Play()
			end
			task.wait(RECAP_STEP)
		end
		if not Screen.isCurrent(token) then
			return
		end
		-- the losers fade back into the dark; the winners stay lit
		for _, slot in slots do
			if not slot.won then
				TweenService:Create(slot.vp, TweenInfo.new(0.8), { BackgroundTransparency = 0.6 }):Play()
				slot.vp.LightColor = Color3.fromRGB(60, 60, 70)
			end
		end
		local r = RESULT_TEXT[data.winner] or RESULT_TEXT.NoWinner
		ui.subtitle.Text = ""
		typeText(ui.subtitle, r[1], 0.05, token)
	end)
end

return {
	Recap = {
		seconds = function(data: any): number
			return recapDuration(#(data.players or {}))
		end,
		play = function(data: any, token: number)
			playRecap(data, token)
		end,
	},
	Result = {
		seconds = 4,
		play = function(data: any, _token: number)
			local r = RESULT_TEXT[data.winner] or RESULT_TEXT.NoWinner
			setTitle(r[1], r[2])
			slam()
			doFlash(r[2], 0.4)
		end,
	},
	YourCoins = {
		seconds = 3,
		play = function(data: any, token: number)
			setTitle(`+{data.coins} Z-COINS`, C.butter)
			slam()
			typeText(ui.subtitle, `{data.points} points this round`, 0.03, token)
		end,
	},
	ShotInnocent = {
		seconds = 3.5,
		play = function(_data: any, token: number)
			ui.card.BackgroundColor3 = Color3.fromRGB(30, 4, 8)
			setTitle("YOU SHOT AN INNOCENT", C.blood)
			slam()
			doFlash(Color3.fromRGB(255, 30, 50), 0.8)
			typeText(
				ui.subtitle,
				"They were human. The guilt takes you too... your gun lies in the dirt.",
				0.03,
				token
			)
		end,
	},
	ShotByHunter = {
		seconds = 3.5,
		play = function(_data: any, token: number)
			ui.card.BackgroundColor3 = Color3.fromRGB(14, 10, 20)
			setTitle("THE HUNTER SHOT YOU", C.peach)
			slam()
			doFlash(Color3.new(1, 1, 1), 0.6)
			typeText(
				ui.subtitle,
				"You were human. They didn't believe it. Watch from the safehouse.",
				0.03,
				token
			)
		end,
	},
	Escaped = {
		seconds = 3,
		play = function(_data: any, token: number)
			ui.card.BackgroundColor3 = Color3.fromRGB(10, 14, 30)
			setTitle("YOU ESCAPED", C.baby)
			slam()
			doFlash(C.butter, 0.5)
			typeText(ui.subtitle, "You're safe... for now. The others are still out there.", 0.03, token)
		end,
	},
	Infected = {
		seconds = 2.5,
		play = function(_data: any, token: number)
			ui.card.BackgroundColor3 = Color3.fromRGB(8, 30, 18)
			ui.fog.BackgroundTransparency = 0.6
			setTitle("YOU'VE BEEN INFECTED!", C.blood)
			slam()
			doFlash(C.mint, 0.7)
			local model = CharacterCopy.of(player)
			if model then
				stage(ui.big, model)
				playEmote(model, "Zombie", false, 0) -- no build-up: you're already one of them
				ui.big.LightColor = C.mint
				ui.big.Ambient = Color3.fromRGB(20, 60, 35)
				ui.big.Visible = true
			end
			typeText(
				ui.subtitle,
				"You're one of them now. You look human... until your claws come out.",
				0.03,
				token
			)
		end,
	},
}
