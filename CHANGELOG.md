# Changelog

All notable changes to Zombie Hunter. Versions follow [SemVer](https://semver.org/).

## [Unreleased]

### Added
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
