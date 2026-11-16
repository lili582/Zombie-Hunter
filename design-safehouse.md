# Waiting Room — "Relay Station 9" Safehouse (design brief)

Status: built (slices 1-3 and the scare director; see Build status at the end)
Owner: Lili · Producer: roblox-game-ux · Consumers: roblox-world-level-design, roblox-ui-implementation, roblox-animation-audio-feedback
Builds on: `claude/SPEC.md` (Look & Feel, Mystery & Fear "The Unknown", Player Flows 1/3/4/5), `docs/decisions/2026-11-12-secret-roles.md`
Replaces: the Phase 1 placeholder lobby ("purple room in the sky").

---

## 1. Concept

**One line:** *The last lit room in a town that went dark.* Your safe place still doesn't feel safe.

The safehouse is the **basement of Relay Station 9**, the old radio station that ran the towers. In the lore it is where the Signal came from. That's why it holds the radio desk, the tape archive and the CCTV monitors, and why the radio still picks up voices. Players descend a stairwell into a low, damp concrete room lit by one hanging bulb, a fire in an oil drum and candles. Every station (vote, shop, loadout, catalog) is a **physical object in the room**, so waiting feels like part of the game instead of a menu screen.

**The feelings we design for, in order:**
1. **Relief.** You made it back. There's warm light, other players and a fire.
2. **Unease.** Something is wrong at the edges: the window, the ceiling, the mirror, the posters.
3. **Dread on the countdown.** In the last 10 seconds the room turns against you and the deploy door opens into fog.

**The rule of the room:** *the center is warm, the edges are cold.* Gameplay and social stations sit in warm light. Every scare lives in a cold corner. Players choose how close to the edges they go.

**Hard constraints from existing decisions:**
- **Secret roles.** The lobby shows **no** role hints, name tags or head-floating names (`Classic.nameTagDistance = 0` applies here too). The Alpha class pick is private (UI only, no world change other players can see).
- **No gore.** Blood is blocky and candy-pink/dark-red, never wounds. Scares use darkness, sound and things that move when you aren't looking.
- **Fair scares.** Nothing in the lobby blocks UI, interrupts a menu or plays while a player has a panel open. No full-screen jumpscares. Flicker stays under 3/s and respects the "reduce flicker" setting.
- **Two layers.** The room itself is dark and realistic. The **UI** keeps the cute-creepy pastel kit (Griffy + Fredoka, candy buttons, stitched panels).

---

## 2. Layout

Footprint **64 × 48 studs**, ceiling **16 studs**. The low ceiling is oppressive, but there's still room for the camera. From the hearth, any station is at most **~5 s** of walking (~80 studs) away, and all of them are visible from the center so new players can find them without text.

```
            N
  ┌───────────────────────────────────────────────┐
  │ [STAIRS/SPAWN] → [MAP VOTE CHALKBOARD] → [DEPLOY DOOR]│
  │                   pad1  pad2  pad3                    │
  │ [LOADOUT RACK]                        [SHOP CAGE]     │
  │                    ( THE HEARTH )                     │
  │ [SPECIMEN JARS]   drum fire · cots    [MIRROR ALCOVE] │
  │                     hanging bulb                      │
  │ [ARCHIVE + CCTV]  [BOARDED WINDOWS]  [MISSING POSTERS]│
  └───────────────────────────────────────────────┘
            S   (windows face the street, at ground level)
```

**Player flow:** spawn at the bottom of the stairs (NW), facing the hearth → the room fans out around you → the deploy door (NE) is the goal and always visible, with the red bulb as its "beacon" (same language as the tower beacons in rounds).

| # | Zone | Size (studs) | Function | Hook |
|---|---|---|---|---|
| 1 | **Stairwell spawn** | 10 × 8 | Join / return point | Steps continue *up* into pure black. Footsteps on them sometimes, nobody there. |
| 2 | **Map vote chalkboard** | 18 wide | Vote (Flow 1) | 3 chalk-drawn map sketches, chalk tally marks appear as votes come in. 3 **floor pads** under it: step on one to vote (also a UI button). |
| 3 | **Deploy door** | 8 × 12 | Round start / return | Steel blast door, wheel lock, red caged bulb, flip-clock countdown above. Opens on round start. |
| 4 | **Loadout rack** | 14 wide | Hunter + Survivor loadouts (Flow 3) | Pegboard weapon wall + 4 dented lockers. The equipped bat physically hangs on the hook. |
| 5 | **Specimen jars** | 8 wide | Pre-select Alpha class (private) | A shelf of 3 murky jars labelled RUNNER / TANK / SCREAMER, each holding a faint silhouette. Opening the prompt shows a UI picker. **Nothing changes in the world**, so the pick stays secret. |
| 6 | **The hearth** | 18 × 14 | Social center, AFK spot | Oil-drum fire, 4 army cots, crates as seats, sandbag half-ring, the one hanging bulb. The PLAY / READY prompt also lives here. |
| 7 | **Shop cage** | 12 wide | Shop (Flow 3) | Chain-link cage counter with a brass bell, crates of stock, a flickering sickly-green tube light. Ringing the bell opens the shop. |
| 8 | **Mirror alcove** | 8 × 8 | Catalog (Flow 5) | A tall cracked mirror behind a moth-eaten curtain. Dressing happens "in" the mirror. |
| 9 | **Archive + CCTV** | 16 wide | Lore tapes (Archive), stats, live spectate | Radio desk with reel-to-reel deck, a CRT TV playing static, and a bank of 4 small CCTV monitors showing the **live round** (spectate feed for people waiting mid-round). |
| 10 | **Boarded windows** | 2 windows | Scare point | Gaps between planks let in lavender moonbeams. Zombie hands, eyes and bangs happen here. |
| 11 | **Missing posters** | 6 wide | Scare point / lore | A corkboard of "MISSING" posters showing **last round's infected players' avatars** (the spec's Missing posters phantom). |

**Sightlines.** From the spawn, the eye travels across the chalkboard (warm lantern), then to the red door bulb (goal), then down to the hearth (fire). The only unlit areas are the NE corner behind the door and the far ends of the south wall. That's where the dark lives.

**Safety and readability.** No dead ends deeper than 6 studs. All prompts are within 8 studs and line-of-sight. Floor pads and prompts are **≥ 6 studs apart** so phone players don't trigger the wrong one.

---

## 3. Visual direction ("good rendered graphics")

### 3.1 Style

Blocky Roblox shapes with **modern, physically based materials and lighting**: think "2014 silhouettes, 2026 render." Shapes stay chunky and readable, while surfaces get real wear (damp concrete, rust, peeling paint, grime) and light behaves realistically (soft shadows, haze, light shafts, glow).

Nostalgia touches from the spec stay: **studded floor tiles** in the hearth area only, the CRT, a 2014-style poster or two, a retro visitor counter scratched into the wall near the stairs.

> **Decision needed (see §10):** the spec says "classic/compatibility lighting, flat, almost no soft shadows". A rendered, cinematic waiting room needs **Future** lighting. `Lighting.Technology` is one setting for the whole place, so this changes the look of the maps too.

### 3.2 Materials (MaterialVariants, one per surface)

| Surface | Base material | Variant | Notes |
|---|---|---|---|
| Walls | Concrete | `DampConcrete` | Darker at the bottom (water line), drip streak decals |
| Floor | Slate / Concrete | `CrackedTile` + studded tiles at the hearth | Puddle decal under the leaking pipe, specular high |
| Ceiling | Concrete | `StainedConcrete` | Exposed pipes and a cable tray running across |
| Door, cage, lockers | Metal / DiamondPlate | `RustyMetal` | Orange rust bleeding at edges |
| Planks, crates, shelves | Wood / WoodPlanks | `RottenPlanks` | Grey-green and warped |
| Cot fabric, curtain | Fabric | `MothFabric` | Olive drab and dusty purple |
| Sandbags | Fabric | `Burlap` | |
| Mirror | Glass | — | Reflectance 0.4, crack decal |
| Jars | Glass | — | Transparency 0.35, murky green liquid part inside |

Use `SurfaceAppearance` (PBR, 1024 px max, 512 px on hero props) only on **hero props**: the deploy door, mirror frame, radio desk, jars, drum. Everything else uses MaterialVariants to keep memory down.

### 3.3 Color palette in the room

The world stays near-black (`#040307`–`#15101F`), and color comes **only from light sources**, matching the spec's two-layer rule:

| Light | Color | Hex | Meaning |
|---|---|---|---|
| Hanging bulb, candles, fire | Butter / ember | `#FFE08A` / `#FFB86B` | Safety |
| Moonbeams through boards | Lavender fog | `#BFA9F2` | The outside |
| Deploy door bulb | Candy blood (deepened) | `#FF4A5C` | Danger / go |
| Shop tube | Zombie mint (sick) | `#CDEFD9` | Unease |
| CRT and CCTV | Cold blue-white | `#BFD8FF` | The Signal |
| Specimen jars | Faint mint glow | `#A3EAC8` @ low | Infection |

### 3.4 Lighting rig (starting values, *tune* in a dark playtest)

**Lighting (service):**
`Technology = Future` · `Ambient = 10,8,14` · `OutdoorAmbient = 22,18,34` · `Brightness = 0.4` · `ClockTime = 0` · `EnvironmentDiffuseScale = 0.15` · `EnvironmentSpecularScale = 0.6` · `ExposureCompensation = -0.25` · `GlobalShadows = true`

**Atmosphere:** `Density 0.42` · `Offset 0.1` · `Color #3A2856` · `Decay #1B1428` · `Glare 0` · `Haze 2.4`. The haze is what turns moonbeams and the bulb into visible light shafts.

**Post-processing:**
- `ColorCorrection`: Brightness -0.04, Contrast 0.18, Saturation -0.25, Tint `#F2E6FF`
- `Bloom`: Intensity 0.6, Size 28, Threshold 1.6 (only bulbs, flames and screens bloom)
- `DepthOfField`: FarIntensity 0.12, FocusDistance 28, InFocusRadius 40, NearIntensity 0. Off on low-quality devices.
- `SunRays`: off (indoor)
- Optional client-side vignette ImageLabel (UI layer), 25% dark edges

**Light sources (shadow-casting lights are expensive, so at most 4 cast shadows):**

| Light | Type | Brightness | Range | Color | Shadows | Behavior |
|---|---|---|---|---|---|---|
| Hanging bulb (hearth) | PointLight | 1.6 | 22 | `255,214,150` | **yes** | Sways slightly (hinge), flickers every 15–40 s |
| Drum fire | PointLight | 1.1 | 16 | `255,150,80` | **yes** | Brightness noise ±0.25 at ~8 Hz smoothing (not a flicker) |
| Moonbeam × 2 | SpotLight | 2.2 | 40 | `#BFA9F2` | **yes** | Angle 30°, shining down through the boards. Gaps cut the beam into stripes. |
| Deploy door bulb | PointLight | 1.4 | 14 | `#FF4A5C` | **yes** | Steady, then pulses in the final 10 s |
| Chalkboard lantern | PointLight | 0.9 | 12 | `#FFC79A` | no | Steady (readability) |
| Candles × 6 | PointLight | 0.5 | 7 | `#FFB86B` | no | Tiny noise |
| Shop tube | SurfaceLight | 1.0 | 12 | `#CDEFD9` | no | Buzz + stutter every 20–60 s |
| CRT + CCTV | SurfaceLight | 0.9 | 9 | `#BFD8FF` | no | Brightness follows the screen content |
| Jars | PointLight | 0.25 | 5 | `#A3EAC8` | no | Slow "breathing" |

### 3.5 Particles and small motion

- **Dust motes** in each moonbeam (ParticleEmitter, Rate 4, slow drift, LightInfluence 1)
- **Drum fire:** flame (Rate 30), embers rising (Rate 6), thin smoke into the ceiling haze
- **Candle flames:** tiny flipbook or Fire-style emitter, one per candle cluster
- **Ceiling leak:** a drip every 2–4 s into the puddle, with a ripple decal
- **Breath vapor:** only at the deploy door in the final 10 s (cold air from outside)
- **Cobwebs:** decals in corners. **Moths** (2–3 particles) circle the hanging bulb.

---

## 4. Station designs (in-world object + UI)

Every station = **a physical object + a ProximityPrompt + the existing UI panel** (pastel kit). The prompt is the world-to-UI handoff. Every station is **also** reachable from the lobby menu buttons, so phone players never *have* to walk.

| Station | World object detail | Prompt | Opens |
|---|---|---|---|
| **Ready** | A wall switch beside the hearth's sandbags, wired to the door bulb | `[E] READY` | Toggles ready, door bulb blinks once for you |
| **Map vote** | Chalkboard + 3 floor pads with chalk outlines. A chalk hand writes tally marks live. | Step on a pad / `[E] Vote` | Vote UI (3 cards) |
| **Loadout** | Pegboard: revolver outline, bat hook, medkit tin. Locker doors creak open. | `[E] Loadout` | Loadout panel. The camera dollies to the rack. |
| **Alpha pick** | 3 jars on a shelf, murky silhouettes inside | `[E] Choose your nightmare` | Private class picker. No world change. |
| **Shop** | Cage counter + bell | `[E] Ring the bell` | Shop panel. Bell *ding* sound. |
| **Catalog** | Mirror + curtain | `[E] Look in the mirror` | Catalog editor. The camera faces your reflection. |
| **Archive** | Reel-to-reel + tape shelf (empty slots for 12 tapes) | `[E] Listen` | Archive panel. Collected tapes fill the shelf physically. |
| **Stats** | Clipboard nailed by the radio desk | `[E] Your record` | Stats panel |
| **Spectate** | CCTV bank | `[E] Watch the night` | Spectate camera (only during an active round) |

**Camera moments:** when a station panel opens, the camera eases (0.4 s, Quad Out) to a fixed framing of that object, then the panel slides in. On close, it eases back. This one trick is what makes the room feel "rendered" and premium.

---

## 5. Scare director (lobby edition)

The lobby uses a small, gentle version of the spec's PhantomDirector. **Client-only, never replicated** (everyone sees a different night), no collision, no damage.

**Budget:** at most **1 scare per player every 35–70 s**. **None** while a UI panel is open, none in the first 20 s after joining, and none during the first-time player flow.

| Event | Where | What happens | Weight |
|---|---|---|---|
| **Window bang** | Boarded windows | 3 heavy thumps, boards jolt, dust falls, a hand slides between planks and withdraws | 25 |
| **Bulb dip** | Hearth bulb | Bulb buzzes, dims to 20% for 1.2 s (max 2 flickers), comes back | 20 |
| **Upstairs footsteps** | Ceiling / stairs | Slow footsteps cross the ceiling and stop above you. Dust sifts down. | 15 |
| **The wrong radio** | Radio desk | Static resolves into a whisper of the **name of a player infected last round**, then cuts | 10 |
| **Mirror lag** | Mirror | If you stand in front of it, your reflection turns its head **0.5 s late** once | 10 |
| **Door test** | Deploy door | The wheel lock turns 10° by itself and the door shudders, as if something outside tried it | 10 |
| **Poster swap** | Missing posters | When you look away, one poster's face is now **looking at the camera** | 7 |
| **The Tall One** | Moonbeam gap | 1 in ~40 events: a very tall silhouette blocks a moonbeam for 2 s. Never explained. | 3 |

Each event logs nothing to other players and has a caption for accessibility (e.g. `[something bangs on the window]`).

### Countdown escalation (the "door opens" moment)

| Time left | Room | Sound |
|---|---|---|
| > 10 s | Normal | Music box loop |
| 10 s | Music box **detunes and slows**. Door bulb starts pulsing. Haze density +0.1. | Low drone fades in |
| 5 s | Bulb flickers twice and settles dimmer (60%). Candles gutter. Breath vapor at the door. | Heartbeat (slow), wind outside builds |
| 3 s | Wheel lock spins. Steam hisses from the hinges. | Metal groan |
| 0 s | **Door swings open into lavender fog.** Cold light floods in. Camera fades to black and the round-start cards begin (Map, Mode, "A HUNTER WALKS AMONG YOU"). | Music cuts, a single distant scream |

**Return after the round:** players fade in **at the bottom of the stairs** with the door already closing behind the fog, and the Results cards play over it. The missing posters update with the round's newly infected.

---

## 6. Audio

| Layer | Content | Notes |
|---|---|---|
| Music | Music box chiptune loop (spec), ~60 BPM, slightly out of tune. Original composition. | Volume 0.35. Ducks under UI sounds. |
| Room tone | Low concrete hum, distant wind, pipe ticks | Always on, non-directional |
| Positional | Fire crackle (hearth), bulb buzz, tube buzz (shop), CRT whine + static, drip, clock tick (door) | `RollOffMaxDistance` 20–30 so each station "owns" its sound |
| Outside | Muffled groans and shuffles behind the windows, occasional far siren | Plays only from the south wall emitters |
| Reverb | `SoundService.AmbientReverb = ConcreteSmall`-style (or `ReverbSoundEffect` group), short tail | Makes the room feel enclosed |
| UI | Pastel kit sounds (soft clicks, bell, chalk scratch on vote) | Never scary, so UI always feels safe |

Captions appear for every scare and the countdown ("[the door unlocks]").

---

## 7. UI overlay in the lobby

Keep the HUD minimal so the room is the star.

- **Top-center:** a stitched pastel pill: `NEXT NIGHT IN 0:18` + mode icon once rolled (`WAITING FOR PLAYERS 3/5` before that). Turns candy-pink and shakes at ≤ 10 s.
- **Bottom-right:** big glossy **READY** button (candy blood, drip), plus a row of round icon buttons: Shop · Loadout · Catalog · Vote · Archive · Players. Same as the stations, for phone and menu players.
- **Top-left:** chat. **Top-right:** coin balance (Z-coin) + compact PLAYERS toggle (roles are `?` / not shown).
- **First-time flow (Flow 4):** welcome card, then three **glowing footprints** on the floor leading to the shop bell, the loadout rack and the chalkboard. No arrows floating in the air.
- **Phone:** all buttons ≥ 64 px, right-thumb zone. Prompts use the tap button. Safe-area insets respected.

---

## 8. Performance budget (phones first)

| Item | Budget |
|---|---|
| Parts + meshes (whole lobby) | ≤ 1,800 |
| Unique MaterialVariants | ≤ 10 |
| SurfaceAppearances | ≤ 6 (hero props) |
| Shadow-casting lights visible at once | ≤ 4 |
| Total lights | ≤ 20 |
| Particle emitters | ≤ 14, combined rate ≤ 120 |
| Sounds playing at once | ≤ 10 |
| Draw target | 60 FPS mid-range phone, 30 FPS floor on low-end |

**Quality fallback (client, by `UserGameSettings.SavedQualityLevel`):** at low quality → DepthOfField off, Bloom size 18, dust motes off, candle lights reduced to 3, fire shadows off (keep bulb + moonbeams).

The lobby sits **far from map space** (e.g. 5,000 studs away), so the round map's streaming and lighting profile never overlap it.

---

## 9. Build plan (vertical slices, playtest each before the next)

1. **Greybox + flow.** Room shell, zones as grey blocks, spawn, deploy door teleport, all prompts wired to the existing panels. *Check: a new player finds every station without text in < 60 s.*
2. **Lighting + atmosphere.** Future rig, Atmosphere, post-FX, the 4 shadow lights. *Check: dark playtest on PC + phone, every station readable, center warm / edges cold.*
3. **Materials + hero props.** MaterialVariants, door, mirror, radio desk, jars, drum, cots, chalkboard. *Check: performance budget on phone.*
4. **Living room.** Particles, positional audio, music box, reverb, camera moments on stations.
5. **Scare director + countdown escalation.** Client-only events, budget rules (pure logic, Lune-testable), captions, reduce-flicker respect. *Check: scares never fire with a panel open.*
6. **Polish + mobile pass.** Quality fallback, button sizes, first-time footprints, missing-posters update, CCTV spectate.

Assets: build props from parts/unions/MeshParts made in Studio. Any Creator Store model must pass a **creator-store security audit** before insertion. No copyrighted posters, songs or characters: every poster, tape label and the music box tune are original.

---

## 10. Open decisions for Lili

1. **Lighting technology.** Switch the whole place to **Future** for the rendered look (recommended; the maps also gain real flashlight shadows, which fits "The Unknown"), or keep the spec's flat classic lighting and fake depth with decals? This updates the spec's Look & Feel rule 1.
2. **Setting.** Relay Station 9 basement (recommended, because it ties into the towers, the Signal and the Archive) or the spec's generic boarded-up room?
3. **Countdown door.** Should the door opening be the actual transition into the round (recommended), or stay decorative while the existing fade-to-black does the work?

---

## Build status

Built with the recommended answers to §10: Future lighting, Relay Station 9, and the door opening at the end of the countdown.

- **Done:** the room and every zone in §2 (`src/server/Maps/Safehouse.luau`), the lighting rig with 4 shadow casters and 15 lights, particles (fire, embers, moths, dust motes in the moonbeams, the leak, breath at the door), MISSING posters with the last round's infected (`LobbyService`, `Lobby.missingIds`), the scare director with captions and its budget rules (`SafehouseController`, `Rules/LobbyScares`, tested), and the countdown escalation and door.
- **Scares built:** window bang + hand, bulb dip, footsteps (dust only), door test, eyes in the boards, the Tall One.
- **Not yet:** audio and music, MaterialVariants / SurfaceAppearance, the loadout / archive / stats / spectate panels (the rack, tape shelf and CCTV are props), camera moments, the ready switch, first-time footprints, mirror lag, poster swap, the wrong radio, and the reduce-flicker setting.
