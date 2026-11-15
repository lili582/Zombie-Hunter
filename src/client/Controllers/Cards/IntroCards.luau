--!strict
-- The round intro, in order: the map, the mode, "someone is infected" (every player a faceless
-- shadow while a red light searches them), YOUR ROLE (a heartbeat in the dark, then your
-- character acting out the role), your rules, and the Hunter / everyone-armed card.
-- Card times must add up to Classic.introLength (32s). Each card: { seconds, play }.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AlphaClasses = require(Shared.Config.AlphaClasses)
local RoleGuide = require(Shared.Config.RoleGuide)
local Theme = require(script.Parent.Parent.Theme)
local CharacterCopy = require(script.Parent.Parent.CharacterCopy)
local Screen = require(script.Parent.Screen)

local C = Theme.colors
local player = Players.LocalPlayer
local ui = Screen.ui
local setTitle, slam, doFlash, typeText = Screen.setTitle, Screen.slam, Screen.flash, Screen.typeText
local stage, playEmote, silhouetteRow = Screen.stage, Screen.playEmote, Screen.silhouetteRow

local ROLE_TITLE = {
	Survivor = "YOU ARE A SURVIVOR",
	Hunter = "YOU ARE THE HUNTER",
	Alpha = "YOU ARE THE ALPHA ZOMBIE",
	Zombie = "YOU ARE A ZOMBIE",
}
local ROLE_RULES = {
	Survivor = "No weapons  -  Repair 3 radio towers  -  Hide in lockers  -  Revive friends\nZombie attack? CLICK IN TIME to escape!",
	Hunter = "Your role is SECRET  -  Only you have a gun\nShoot a HUMAN and you both die  -  Ammo boxes  -  [R] reload",
	Alpha = "You look like them. Blend in.\nClaws wake up at release  -  [1] takes them out: your face shows until you put them away",
	Zombie = "You still look human. Blend in.\n[1] takes your claws out: your face shows until you put them away  -  3 hits downs a human",
}
-- Rules that change in a mode (role -> text)
local MODE_RULES = {
	Outbreak = {
		Survivor = "You have a PISTOL  -  [R] reload  -  Survive 4:00\nZombie attack? CLICK IN TIME to escape!",
		Alpha = "There are more of you. Blend in.\nClaws wake up at release  -  claws out = your face shows",
	},
}
-- YourRole: heartbeat gaps (seconds), slow then faster; the reveal comes right after.
local HEARTBEAT = { 0.85, 0.8, 0.72, 0.65, 0.6 }
local ROLE_REVEAL = 0.85 + 0.8 + 0.72 + 0.65 + 0.6 -- when the light comes on (emote starts)

return {
	Map = {
		seconds = 2.5,
		play = function(data: any, token: number)
			setTitle("", C.bone)
			local mapName = data.name or "???"
			typeText(ui.title, mapName, 0.8 / math.max(#mapName, 1), token)
			typeText(ui.subtitle, data.line or "", 0.035, token)
			task.delay(0.9, function()
				if Screen.isCurrent(token) then
					setTitle(mapName, C.bone)
					slam()
				end
			end)
		end,
	},
	Mode = {
		seconds = 3,
		play = function(data: any, token: number)
			ui.kicker.Text = "MODE"
			setTitle(data.name or "", C.blood)
			slam()
			doFlash(C.blood, 0.35)
			typeText(ui.subtitle, data.line or "", 0.03, token)
		end,
	},
	SomeoneInfected = {
		seconds = 8.5,
		play = function(_data: any, token: number)
			local cardStart = os.clock()
			-- slow and quiet: the title creeps in, whispers, and a red light searches the crowd
			setTitle("", C.blood)
			typeText(ui.title, "SOMEONE IS INFECTED...", 0.09, token)
			local frames = silhouetteRow()
			task.spawn(function()
				-- two slow whispers, each left up long enough to read
				local whispers = { { 1.0, "who is it..." }, { 3.2, "they're standing right next to you" } }
				for _, w in whispers do
					task.wait(math.max(0, w[1] - (os.clock() - cardStart)))
					if not Screen.isCurrent(token) then
						return
					end
					typeText(ui.subtitle, w[2], 0.06, token)
				end
			end)
			-- the red light drifts from shadow to shadow, slower and slower. Sometimes it lingers on
			-- someone... then moves on. It never stops on anyone: the Alpha stays secret.
			task.spawn(function()
				if #frames == 0 then
					return
				end
				task.wait(0.8)
				local last = 0
				local steps = 14
				for i = 1, steps do
					if not Screen.isCurrent(token) then
						return
					end
					local pick = math.random(1, #frames)
					if pick == last and #frames > 1 then
						pick = pick % #frames + 1
					end
					last = pick
					for j, vp in frames do
						vp.LightColor = if j == pick then C.blood else Color3.new(0, 0, 0)
						vp.Ambient = if j == pick then Color3.fromRGB(40, 0, 10) else Color3.new(0, 0, 0)
						vp.BackgroundTransparency = if j == pick then 0.2 else 0.7
					end
					local linger = math.random() < 0.2 and i > 4
					task.wait((0.1 + (i / steps) * 0.3) * (if linger then 2.6 else 1))
				end
				if not Screen.isCurrent(token) then
					return
				end
				for _, vp in frames do
					vp.LightColor = Color3.new(0, 0, 0)
					vp.Ambient = Color3.new(0, 0, 0)
					vp.BackgroundTransparency = 0.9
				end
				-- the last line only after the second whisper has had time to be read
				task.wait(math.max(0, 6 - (os.clock() - cardStart)))
				if not Screen.isCurrent(token) then
					return
				end
				doFlash(Color3.new(0, 0, 0), 1)
				typeText(ui.subtitle, "...and it could be you.", 0.08, token)
			end)
		end,
	},
	YourRole = {
		seconds = 8.5,
		play = function(data: any, token: number)
			local role = data.role
			local color = Theme.roleColor[role] or C.bone
			local guide = RoleGuide.get(role, data.mode)
			setTitle("", color)
			local model = CharacterCopy.of(player)
			if model then
				stage(ui.big, model)
				playEmote(model, role, false, ROLE_REVEAL)
				ui.big.Visible = true
			end
			ui.subtitle.Text = ""
			typeText(ui.subtitle, "who are you...?", 0.08, token)
			-- a slow heartbeat in the dark, getting faster; the light stutters... then the reveal
			task.spawn(function()
				for beat, gap in HEARTBEAT do
					if not Screen.isCurrent(token) then
						return
					end
					ui.big.Size = UDim2.fromScale(0.28, 0.54)
					TweenService:Create(ui.big, TweenInfo.new(0.3), { Size = UDim2.fromScale(0.26, 0.5) })
						:Play()
					if beat >= #HEARTBEAT - 1 then
						for _ = 1, 3 do -- the light tries to come on
							ui.big.LightColor = color
							ui.big.Ambient = Color3.fromRGB(50, 40, 60)
							task.wait(0.05)
							ui.big.LightColor = Color3.new(0, 0, 0)
							ui.big.Ambient = Color3.new(0, 0, 0)
							task.wait(0.07)
						end
						task.wait(math.max(0, gap - 0.36))
					else
						task.wait(gap)
					end
				end
				if not Screen.isCurrent(token) then
					return
				end
				ui.big.LightColor = color
				ui.big.Ambient = Color3.fromRGB(55, 45, 70)
				setTitle(ROLE_TITLE[role] or "", color)
				slam()
				-- the quick explanation of the role, typed under the title
				ui.subtitle.Text = ""
				if guide then
					typeText(ui.subtitle, guide.quick, 0.08, token) -- slow enough to read
				end
				if role == "Alpha" then
					doFlash(Color3.fromRGB(255, 30, 50), 0.8) -- red flash + shake
					for _ = 1, 10 do
						ui.card.Position = UDim2.fromOffset(math.random(-8, 8), math.random(-6, 6))
						task.wait(0.03)
					end
					ui.card.Position = UDim2.fromOffset(0, 0)
				else
					doFlash(color, 0.45)
				end
			end)
		end,
	},
	YourRules = {
		seconds = 7,
		play = function(data: any, token: number)
			local role = data.role
			local model = CharacterCopy.of(player)
			if model then
				stage(ui.big, model)
				playEmote(model, role, true) -- keeps going from the role card
				ui.big.LightColor = Theme.roleColor[role] or C.bone
				ui.big.Ambient = Color3.fromRGB(55, 45, 70)
				ui.big.Visible = true
			end
			local modeRules = MODE_RULES[data.mode or ""]
			local rules = (modeRules and modeRules[role]) or ROLE_RULES[role] or ""
			if role == "Alpha" then
				local class = AlphaClasses.get(data.alphaClass)
				setTitle(`ALPHA - {class.name}`, Theme.roleColor[role])
				rules ..= "\n" .. class.line
			else
				setTitle(Theme.roleText[role] or "", Theme.roleColor[role] or C.bone)
			end
			typeText(ui.subtitle, rules, 0.035, token)
		end,
	},
	HunterChosen = {
		seconds = 2.5,
		play = function(_data: any, _token: number)
			setTitle("A HUNTER WALKS AMONG YOU", C.peach)
			slam()
			local frames = silhouetteRow()
			-- a warm light sweeps over everyone at once: no one is singled out
			for _, vp in frames do
				vp.Ambient = Color3.fromRGB(30, 20, 15)
				vp.LightColor = C.peach
				vp.BackgroundColor3 = Color3.fromRGB(40, 25, 15)
			end
			ui.subtitle.Text = "Nobody knows who. Trust no one."
		end,
	},
	EveryoneArmed = {
		seconds = 2.5,
		play = function(_data: any, _token: number)
			setTitle("EVERYONE IS ARMED", C.baby)
			slam()
			silhouetteRow()
			ui.subtitle.Text = "No Hunter tonight. Shoot anything that bites."
		end,
	},
}
