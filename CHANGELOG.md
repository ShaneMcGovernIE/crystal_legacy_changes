# Changelog

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
