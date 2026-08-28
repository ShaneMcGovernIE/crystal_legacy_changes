# Changelog

## [1.3.8] - 2026-08-28

### Fixed

- Registered the Crystal direct-pipeline move effects required by the engine's
  cross-reference validator, without replacing their native battle behavior.

## [1.3.7] - 2026-08-28

### Changed

- Ported the mod metadata and runtime patches to Pokémon Crystal, including
  the Crystal Legacy encounters, trainers, marts, evolutions, events,
  difficulty modes, quality-of-life changes, and bundled custom assets.
- Removed local agent/internal planning artifacts and added repository hygiene
  rules for credentials, local metadata, and build output.

## [1.2.0] - 2026-08-26

### Added

- **Difficulty & Battle Mechanics (`data/difficulty.lua`)**:
  - Trainer Held Items: Enemy trainer Pokémon automatically equip their canonical held items from `data/trainers.lua` in battle.
  - Triple Kick 20 -> 60 -> 120 damage scaling.
  - Hard & Hardcore difficulty modes (in-battle item ban, Set battle style, badge level caps, permadeath tracking).
- **Quality of Life (`data/qol.lua`)**:
  - TM & HM move names displayed directly on bag items (`TM01 DYNAMICPUNCH`, `HM03 SURF`, etc.).
  - Deletable HM moves (Move Deleter bypasses HM restriction).
  - Halved egg hatch cycle step requirements.
  - Instant Kurt Apricorn ball crafting.
  - Fast Nurse Joy healing and unlosable first rival battle flow.
- **Custom Party Menu Sprites (`data/icons.lua` & `assets/icons/`)**:
  - Added all 251 unique animated 16x32 party menu icons from Crystal Legacy, replacing the generic Gen 2 species icon categories with individual species sprites.

## [1.1.0] - 2026-08-26

### Changed

- Ported mod target from Pokémon Gold to **Pokémon Crystal** (`"games": ["crystal"]`).
- Updated mart handling and `MART_ORDER` to support all Crystal and Crystal Legacy shelves in `game.data.gen2Marts`.
- Updated mod metadata, warnings, and documentation to specifically target Crystal.

## [1.0.0] - 2026-08-13

### Added

First stable release: every Crystal Legacy patch from 0.4 through 0.9 plus the
full Phase 4 engine batch, all gated green (suite 950/950).

- Everything shipped since the 0.3.0 baseline — see [0.9.0] for the complete
  Phase 3 payload (Team Rocket Base B1F–B3F deltas + ARCHER sprite, RadioTower
  1F–5F takeover, Goldenrod Move Tutor, statics/gifts: Game Corner, fossils +
  Ruins of Alph, Dratini Master, Snorlax, Mew at 249 caught, Kanto birds,
  Celebi/GS Ball chain).
- Berry shop LIVE (engine 941a337a): the mart gate is data-driven past the
  34-shelf cap, so the Goldenrod Flower Shop clerk opens the CL berry shelves
  (MART_BERRYS / MART_BERRYS_2) once the player holds 7 badges.
- Item evolutions activate (engine e9336717, EvoStoneEffect port): the stone /
  item families now evolve at runtime — Onix (Metal Coat), Scyther (Metal
  Coat), Seadra (Dragon Scale), Porygon (Up Grade), Poliwhirl (King's Rock),
  Slowpoke (King's Rock), Tyrogue (Brick Piece).
- Hard / Hardcore difficulty modes (engine aabc4b50 + 97367cb9, CL
  DifficultyFlags port): battle item-ban, forced Set, and no-revive.
- Overworld sprites (4a4029a): SPRITE_MEW, SPRITE_CELEBI, SPRITE_ARTICUNO,
  SPRITE_ZAPDOS, SPRITE_ELECTRODE, SPRITE_MURKROW ship converted from CL source
  (no art synthesized) — Mew's Route 24 object, the Articuno/Zapdos statics,
  Rocket Base B2F's six Electrodes, and B3F's Murkrow all render real art now.
- Docs + credits refresh (README, mod.card) and the Phase 4 gate suite.

### Notes

- The GS Ball's bag icon remains a Phase 4 art item; Celebi stays a wild battle
  by design (SPRITE_CELEBI registered for the future shrine cutscene port).

## [0.9.0] - 2026-08-13

### Added

- Team Rocket Base B1F-B3F deltas (`data/rocket_base.lua`): the 9 audited
  layout differences between gold and CL's base maps, cross-verified against
  the asm walkthrough.
  - B1F (21,12) itemball: X_ACCURACY → GUARD_SPEC (flag 1643).
  - B2F GruntM18: (2,1) sight 3 → (4,1) sight 1.
  - B3F RaticateTailGrunt: (5,15) → (5,14); Ross: (25,12) sight 4 →
    (23,11) sight 0; Mitch: (14,15) → (11,15).
  - B3F itemballs: (1,12) FULL_HEAL → PROTEIN, (3,12) DIRE_HIT → X_SPECIAL,
    (28,9) PROTEIN → FULL_HEAL (flags 1645/1646/1647).
  - B3F executive at (8,3) re-sprited SPRITE_ROCKET → SPRITE_ARCHER (real
    art ships via the Rocket Tower sprite registration).
  - B3F adds an UltraBall itemball at (14,10), item ULTRA_BALL, on free flag
    1934 (persists "taken" across map reloads; index 14 = array position).
  - No script/trainer deltas: gold's B3F boss already runs CL's exact Archer
    hideout team through the trainers data patch.
- Team Rocket RadioTower full port: RadioTower 1F-5F script-table patches
  (boss scene at 5F included), SPRITE_ARCHER/SPRITE_GIOVANNI/
  SPRITE_GIOVANNI_DISGUISE overworld art, and scene wiring.
- Overworld sprite art (Phase 4b, `data/sprites.lua`): six CL-derived sprites
  registered globally via `content.sprites:register`, converted from CL source
  to gold's mode L 4-shade format by `tools/convert_ow_sprites.py` (no art
  synthesized):
  - SPRITE_ARTICUNO + SPRITE_ZAPDOS: real 16x96 walking sheets from
    `gfx/sprites/` (CL OverworldSprites palettes: PAL_OW_BLUE / PAL_OW_BROWN);
    both birds now spawn as Route 20 / Route 10 North statics.
  - SPRITE_MEW (Route 24 object + CL MewScript battle: "Myuu...", L60),
    SPRITE_ELECTRODE (B2F ×6, replacing gold's VOLTORB stand-ins),
    SPRITE_MURKROW (B3F, replacing gold's SPRITE_MOLTRES stand-in),
    SPRITE_CELEBI (registered for the shrine cutscene when ported) — all
    16x32 POKEMON_SPRITE icons from `gfx/icons/`, matching how CL's own
    engine renders pokemon-range overworld sprites.
- Goldenrod City Move Tutor: the CL move-tutor dialogue and line-up, wired
  through the game's native tutor scene.
- Statics/gifts and story releases:
  - Game Corner prizes → CL list (ABRA 100 / PORYGON 800 / DRATINI 1500).
  - Fossils + Ruins of Alph revival (Kabuto/Omanyte/Aerodactyl), full inert
    shape for all three fossil items.
  - Dratini Master shrine gift; pin Vermilion Snorlax already CL-faithful.
  - Mew dex-chain release splice; Celebi/GS Ball full Crystal chain;
    Kanto birds CL release wiring.
  - Flower Shop berry shop shipped mod-side, blocked on the Phase 4
    mart-shelf gate.
- 90 new test assertions covering the Rocket Base patch (suite now 779/779),
  plus the Phase 4b sprite/wiring suite (suite now 930/930).

### Notes

- The GS Ball's bag icon and the Berry Shop mart-shelf gate remain Phase 4 art
  / engine gaps; SPRITE_CELEBI ships but no object uses it yet (Celebi stays
  a wild battle by design — the shrine cutscene is a future script port).

## [0.8.0] - 2026-08-13

### Added

- Evolutions data patch: swaps in the full Crystal Legacy evolution lists for
  15 species (19 rows) from `data/evolutions.lua` via wholesale
  `pokemon.evolutions` replacement (record semantics — no append).
  - 7 item evolutions converted from trade: Onix (Metal Coat), Scyther
    (Metal Coat), Seadra (Dragon Scale), Porygon (Upgrade), Poliwhirl
    (King's Rock), Slowpoke (King's Rock), Tyrogue (Brick Piece).
  - 4 trade evolutions moved to level: Kadabra 42, Machoke 38, Graveler 38,
    Haunter 42.
  - 4 early level shifts: Goldeen 28, Pineco 25, Slugma 27, Spinarak 21.
  - No evolution_methods registration needed (EVOLVE_LEVEL/ITEM/STAT are
    engine-owned).
- 62 new test assertions covering the evolutions patch (suite now 192/192).
- Note: item evolution activation (stone-use path) is an engine gap tracked
  in Phase 4 — CL item evolution rows land in data but cannot fire until the
  engine gains a stone family + force ctx (also fixes vanilla Gold's inert
  trade evolutions).

## [0.7.0] - 2026-08-13

### Added

- Marts data patch: swaps the engine's 34 Gold mart shelves in place with
  Crystal Legacy stock from TSP's design document (Cianwood, Mahogany with the
  evolution-item shelf, Blackthorn, Celadon floors, Goldenrod floors), applied
  on the `mods.loaded` event against `game.data.gen2Marts` and preserving the
  Bargain Shop flag. Applied by verified Gold shelf order, never by Crystal
  position.
- 21 new test assertions covering the marts patch (suite now 130/130); the
  fixture seeds gold-shaped junk shelves so a no-op or deep-merge patch fails.
- Five Crystal-only shelves with no Gold slot are tracked and held back
  (BERRYS, BERRYS_2, CELADON_3F_2, CELADON_5F_1_2, CELADON_5F_2_2) — they
  need engine-side registry entries and will be revisited with Phase 4.

## [0.6.0] - 2026-08-13

### Added

- Encounters data patch (`mod.content.encounters` kind patches from
  `data/encounters.lua`): Crystal Legacy wild Pokemon changes from TSP's
  design document.
  - Larvitar in Dark Cave, starter rematches on Routes 26/27 (time-of-day
    slots), Houndour/Slugma in Burned Tower, Mt. Silver rework.
  - Swarm grass override applied at load time (main.lua).
- 24 new test assertions covering the encounters patch (suite now 109/109).

## [0.5.0] - 2026-08-13

### Added

- Trainer data patch (`mod.content.trainers` class patches from
  `data/trainers.lua`): Crystal Legacy gym, Elite Four, and post-game roster
  changes from TSP's design document.
  - Gym leaders: PRYCE/JASMINE/CHUCK 3-badge variants (4 parties each);
    FALKNER/WHITNEY/BUGSY/MORTY/CLAIR keep their 2-party sets.
  - Elite Four: WILL/KOGA/BRUNO/KAREN rebalanced teams with rematch parties.
  - Kanto leaders: BROCK (GOLEM + QUICK_CLAW), MISTY, BLUE.
  - CHAMPION LANCE rematch party (DRAGONITE + GOLD_BERRY), RED (Lv93
    PIKACHU + LIGHT_BALL), RIVAL1/RIVAL2 rematches.
  - Team Rocket incl. Eto: GRUNTM ETO members, ROCKET_LEADER (ARCHER),
    BOSS (GIOVANNI), MYSTICALMAN (EUSINE).
- Trainer held items deferred to Phase 4 (engine trainer-party schema has no
  item field yet).

## [0.3.0] - 2026-08-11

### Added

- All 251 Crystal Legacy TM/HM compatibility lists from the TMHM Learnsets
  spreadsheet tab.
- Canonical TM01-TM50 and HM01-HM07 ordering with duplicate source entries
  removed.
- Tutor-only Flamethrower, Thunderbolt, and Ice Beam entries excluded from
  `pokemon.tmhm`.

## [0.2.0] - 2026-08-11

### Added

- All 251 Crystal Legacy level-up learnsets from the version 1.3 data sheet.
- Direct Gold constant IDs for all 2,590 learnset rows, including level-1
  moves and duplicate-level entries.

## [0.1.0] - 2026-08-11

### Added

- Initial native Gold implementation of the documented Crystal Legacy species
  stat rebalance.
- Initial native Gold implementation of the documented Crystal Legacy move
  rebalance and compatible effect changes.
- Gold Ghost and Dark physical/special type-category adjustments.
