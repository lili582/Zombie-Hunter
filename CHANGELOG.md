# Changelog

All notable changes to Zombie Hunter. Versions follow [SemVer](https://semver.org/).

## [Unreleased]

### Changed
- Survivors carry no weapons (the bat is Hunter-only).
- The Alpha is the same height as all other players (no longer 1.3x bigger).

### Added
- Survivor escape: when a zombie attacks a Survivor, a timing bar appears; clicking/tapping/Space while the needle is in the green zone escapes the hit (+5 points, short speed burst, 1.2s safe). The server checks the timing (`Rules/Dodge`, 8 tests).
- Compact player list (smaller rows, narrower, see-through), toggled with Tab or the small PLAYERS button; closed by default on phones. Roblox's default player list is hidden.
- No floating player names or health bars over heads (`Classic.nameTagDistance = 0`), so players can't be spotted or identified from far away.
- Secret roles: nobody is told who the Alpha or the Hunter is. Cards and banners never name them, the player list shows `?` for every other non-zombie player all round, and the Hunter has no hat or name tag. Basic (infected) zombies are still shown.
- Studio playtests start a round with 2+ players automatically (`Classic.studioMinPlayers`); live servers still need 5.
- Phase 1 playable Classic round (target v0.1.0):
  - Pure rules core (`src/shared/Rules`): role picker with anti-repeat, round phases and timers,
    hidden Alpha until release, hits → downed → revive or turn into a basic zombie, Hunter gun
    hand-off, special roles leaving mid-round, win checks, round points and coins.
  - 56 headless Lune tests (`lune run tests/run`).
  - Server: RoundManager, CharacterService (role looks, flashlight, downed crawl), CombatService
    (server-raycast revolver, bat, claws, ammo boxes), MapService (auto-built greybox Town + lobby),
    AnnouncementService.
  - Client: HUD (timer, player list, health/wounds, ammo, crosshair, downed screen, +points,
    edge tint, phone reload), round cards and banners, weapon input.
  - Tooling: Rojo project, Rokit pins, Selene, StyLua, GitHub Actions CI.
