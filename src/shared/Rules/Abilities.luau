--!strict
-- Alpha classes: the class each player prefers (picked in the safehouse) and the Alpha's
-- ability with its cooldown. Pure. Works on RoundRules' working copy `s`.
local Types = require("../Types")
local AlphaClasses = require("../Config/AlphaClasses")

type State = Types.RoundState
type Effect = Types.Effect

local Abilities = {}

-- Gives a player who just became the Alpha their preferred class, ability ready.
function Abilities.makeAlpha(s: State, p: Types.PlayerState)
	p.alphaClass = if AlphaClasses.isValid(s.alphaPrefs[p.id])
		then s.alphaPrefs[p.id]
		else AlphaClasses.default
	p.abilityReadyAt = 0
end

function Abilities.readyIn(s: State, p: Types.PlayerState): number
	return math.max(0, p.abilityReadyAt - s.clock)
end

function Abilities.step(s: State, event: Types.Event, fx: { Effect })
	if event.type == "SetAlphaClass" then
		-- Any time, but it only applies the next time you become the Alpha (no mid-round swaps).
		local p = s.players[event.playerId]
		if p and AlphaClasses.isValid(event.class) then
			s.alphaPrefs[event.playerId] = event.class
			table.insert(fx, { type = "AlphaClassSet", playerId = event.playerId, class = event.class })
			table.insert(fx, {
				type = "Announce",
				card = "AlphaPicked",
				toPlayerId = event.playerId,
				data = { class = event.class },
			})
		end
	elseif event.type == "UseAbility" then
		local p = s.players[event.playerId]
		if s.phase ~= "Active" or not p or p.role ~= "Alpha" or p.life ~= "Alive" then
			return
		end
		if Abilities.readyIn(s, p) > 1e-9 then
			return -- still cooling down
		end
		local class = AlphaClasses.get(p.alphaClass)
		p.abilityReadyAt = s.clock + class.cooldown
		table.insert(fx, {
			type = "AbilityUsed",
			playerId = p.id,
			class = p.alphaClass or AlphaClasses.default,
			ability = class.ability,
		})
	end
end

return Abilities
