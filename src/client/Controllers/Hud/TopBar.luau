--!strict
-- The clock at the top centre, and the one line under it (waiting / countdown / humans
-- left, towers, helicopter / round over).
local Theme = require(script.Parent.Parent.Theme)

local C = Theme.colors

local TopBar = {}

local ui: { [string]: any } = {} -- the HUD's shared widget table (set in build)

function TopBar.build(gui: ScreenGui, widgets: { [string]: any })
	ui = widgets
	-- top centre: the clock in a glass pill, and one quiet line under it
	local top = Instance.new("Frame")
	top.BackgroundTransparency = 1
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, 12)
	top.Size = UDim2.fromOffset(520, 80)
	top.Parent = gui
	ui.top = top
	ui.timer = Theme.chip(top, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(0, 44),
		TextSize = 28,
		TextStrokeTransparency = 0.7,
		Text = "",
	})
	ui.sub = Theme.label(top, {
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 18),
		TextScaled = false,
		TextSize = 13,
		TextColor3 = C.lavender,
		Text = "",
	})
end

-- Every frame: draw from the latest round snapshot.
function TopBar.render(frame: any)
	local view, viewStamp, phase, left, role =
		frame.view, frame.viewStamp, frame.phase, frame.left, frame.role
	-- top center
	local lastMinute = phase == "Active" and left < 60
	-- last minute: the clock turns a deep blood red with a dark edge (no shaking)
	ui.timer.TextStrokeColor3 = if lastMinute then Color3.fromRGB(40, 0, 6) else C.ink
	if phase == "Waiting" then
		ui.timer.Text = "ZOMBIE HUNTER"
		ui.timer.TextColor3 = C.mint
		ui.sub.Text = `WAITING FOR PLAYERS {view.count}/{view.needed}`
	elseif phase == "Intermission" then
		ui.timer.Text = Theme.timeText(left)
		ui.timer.TextColor3 = C.bone
		ui.sub.Text = "NEXT ROUND STARTING  -  VOTE FOR A MAP AT THE BOARD"
	elseif phase == "HeadStart" then
		ui.timer.Text = Theme.timeText(left)
		ui.timer.TextColor3 = C.blood
		ui.sub.Text = if role == "Alpha"
			then `BLEND IN... YOUR CLAWS WAKE UP IN {Theme.timeText(left)}`
			else "SOMEONE IS INFECTED... RUN"
	elseif phase == "Active" then
		ui.timer.Text = Theme.timeText(left)
		ui.timer.TextColor3 = if lastMinute then Color3.fromRGB(200, 10, 28) else C.bone
		local line = `HUMANS LEFT: {view.humansLeft}`
		if next(view.towers) ~= nil then
			line ..= `   TOWERS {view.towersDone}/{view.towersNeeded}`
		end
		local heli = view.heli
		local heliLeft = math.max(0, heli.timeLeft - (os.clock() - viewStamp))
		if heli.phase == "Inbound" then
			line = `HELICOPTER IN {Theme.timeText(heliLeft)}   ` .. line
		elseif heli.phase == "Landed" then
			line = `GET TO THE HELICOPTER! {math.ceil(heliLeft)}s   ` .. line
		end
		ui.sub.Text = line
	elseif phase == "Results" then
		ui.timer.Text = "ROUND OVER"
		ui.timer.TextColor3 = C.lavender
		ui.sub.Text = "SAFE IN THE SAFEHOUSE  -  REST UP"
	end
end

return TopBar
