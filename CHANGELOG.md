# Changelog

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
