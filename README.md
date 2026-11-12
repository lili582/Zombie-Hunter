# Zombie Hunter

Round-based Roblox horror game: one secret **Alpha Zombie**, one **Hunter** with the only gun, everyone else **Survivors**. Get downed, get revived — or rise as a zombie. 2014 Roblox build, cute-creepy pastel UI.

**Status:** Phase 1 (target v0.1.0) — one playable Classic round on an auto-built greybox Town.

- How to run it in Studio: [STUDIO_GUIDE.md](STUDIO_GUIDE.md)
- Tests: `lune run tests/run`
- Changes: [CHANGELOG.md](CHANGELOG.md)

## Layout

```
src/shared/   -> ReplicatedStorage.Shared   pure rules (no Roblox APIs) + config + remote names
src/server/   -> ServerScriptService.Server thin services: Roblox events -> rule events -> effects
src/client/   -> StarterPlayerScripts.Client HUD, cards, weapon input
tests/        -> Lune specs for the rules core
```

All game decisions go through one function, `RoundRules.apply(state, event) -> (newState, effects)`, which is fully tested headless.
