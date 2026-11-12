--!strict
-- Shared types for the rules core. Pure: no Roblox APIs.

export type Role = "Alpha" | "Hunter" | "Survivor" | "Zombie"
export type Life = "Alive" | "Downed" | "Out" | "Escaped"
export type Phase = "Waiting" | "Intermission" | "HeadStart" | "Active" | "Results"
export type Winner = "SurvivorsSurvived" | "SurvivorsEscaped" | "ZombiesWin" | "NoWinner"

export type PlayerState = {
	id: number,
	role: Role,
	life: Life,
	hitsTaken: number,
	bleedLeft: number?,
	downedBy: number?,
	reviverId: number?,
	reviveProgress: number,
	points: number,
	wasInfected: boolean,
	infections: number,
	-- Phase 2
	hiddenIn: number?, -- locker id while hiding
	repairing: number?, -- tower id while repairing
	repairCredit: number, -- tower progress this player added (for points)
	medkits: number,
	-- v0.3: Alpha classes
	alphaClass: string?, -- set while this player is an Alpha
	abilityReadyAt: number, -- round clock time the ability can be used again
}

export type Tower = { progress: number, done: boolean }
export type Heli = { phase: "None" | "Inbound" | "Landed" | "Gone", timeLeft: number, zone: number? }
export type MapMeta = { towerSpots: { { x: number, z: number } }, heliZoneCount: number }

export type Rng = {
	int: (self: Rng, min: number, max: number) -> number,
	float: (self: Rng) -> number,
}

export type RoundState = {
	phase: Phase,
	timeLeft: number,
	clock: number, -- seconds of Active time elapsed (for assist windows)
	config: any,
	rng: Rng,
	players: { [number]: PlayerState },
	sinceSpecial: { [number]: number }, -- rounds since each player was Alpha/Hunter
	lastHits: { [number]: { [number]: number } }, -- victim -> attacker -> clock time
	pendingAssists: { [number]: { number } }, -- victim -> attacker ids, set when downed
	gunDropped: boolean,
	alphaRevealed: boolean,
	winner: Winner?,
	-- Phase 2: objectives
	mapMeta: MapMeta?,
	towers: { [number]: Tower }, -- active towers this round, keyed by spot index
	towersDone: number,
	heli: Heli,
	-- v0.3
	alphaPrefs: { [number]: string }, -- Alpha class each player picked in the safehouse
	baseConfig: any, -- config between rounds; `config` is this + the round's mode
	nextMode: string?, -- mode picked for the next round (shown in the lobby)
	lastMode: string?, -- mode of the last round (a special mode never repeats)
}

export type Event =
	{ type: "Tick", dt: number }
	| { type: "PlayerJoined", playerId: number }
	| { type: "PlayerLeft", playerId: number }
	| { type: "Hit", attackerId: number, victimId: number }
	| { type: "ReviveStart", reviverId: number, targetId: number }
	| { type: "ReviveStop", reviverId: number }
	| { type: "PickUpGun", playerId: number }
	| { type: "ZombieKilled", killerId: number, victimId: number }
	| { type: "Dodged", playerId: number, attackerId: number }
	| { type: "RepairStart", playerId: number, towerId: number }
	| { type: "RepairStop", playerId: number }
	| { type: "SkillCheck", playerId: number, success: boolean }
	| { type: "EnterHeliZone", playerId: number }
	| { type: "LockerEnter", playerId: number, lockerId: number }
	| { type: "LockerExit", playerId: number }
	| { type: "LockerSearch", attackerId: number, lockerId: number }
	| { type: "UseMedkit", playerId: number, targetId: number }
	| { type: "SetAlphaClass", playerId: number, class: string }
	| { type: "UseAbility", playerId: number }

export type Effect = { type: string, [string]: any }
-- Effect types:
--   PhaseChanged {phase}            RolesAssigned {}
--   HitLanded {attackerId, victimId}
--   Downed {playerId, byId}         Revived {playerId, byId}
--   ReviveStarted {reviverId, targetId}   ReviveStopped {targetId}
--   BecameZombie {playerId, byId?}  BecameAlpha {playerId}
--   GunDropped {fromId}             NewHunter {playerId}
--   ZombieKilled {killerId, victimId}  Dodged {playerId, attackerId}
--   RepairStarted {playerId, towerId}  RepairStopped {playerId, towerId}
--   RepairPoints {playerId, amount}  TowerRepaired {towerId, repairerIds}  SkillCheckFailed {playerId, towerId}
--   RepairInterrupted {attackerId, victimId}  NoiseAlert {towerId}
--   HeliCalled {zone}  HeliLanded {zone}  HeliLeft {}  Escaped {playerId}
--   EnteredLocker {playerId, lockerId}  LeftLocker {playerId, lockerId, pulledBy?}
--   Healed {playerId, targetId}
--   AlphaClassSet {playerId, class}  AbilityUsed {playerId, class, ability}
--   PointsAwarded {playerId, amount, reason}
--   Announce {card, toPlayerId?, data?}
--   RoundOver {winner}

return {}
