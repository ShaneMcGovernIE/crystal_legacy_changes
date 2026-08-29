# Crystal Legacy Changes

Applies the explicit Pokemon stat, move, encounter, trainer, mart, evolution,
and event changes documented in the Crystal Legacy design document to
Pokemon Crystal through the native Gen1Recomp mod API. Documented names are
resolved to Crystal registry ids by iterating the content registries at load time.

## Implemented

- 48 documented Crystal species stat records, using Crystal's split Special
  Attack and Special Defense fields.
- 251 species level-up learnsets and 2,590 level-up move rows from the Crystal
  Legacy version 1.3 data sheet.
- 251 species TM/HM compatibility lists and 6,485 unique compatibility rows
  from the TMHM Learnsets tab. The three tutor-only columns are excluded.
- Documented move power, accuracy, PP, type, priority, critical-rate, and
  compatible effect changes, including Sacred Fire's PP.
- Crystal physical/special type categories for Ghost and Dark.
- Wild encounters and trainer parties from the Crystal Legacy data sheet
  (`data/encounters.lua`, `data/trainers.lua`).
- Marts reshelved to the CL lists (`data/marts.lua`), including Berry shops
  and Celadon vitamin shelves.
- Evolution changes from the CL data sheet (`data/evolutions.lua`).
- Story and event content: Team Rocket Base and RadioTower, the Goldenrod Move
  Tutor, Game Corner prizes, fossils + Ruins of Alph revival, the Dratini
  Master, Mew (Route 24, releases at 249 caught — >248), Celebi/GS Ball, and
  the Kanto birds (`data/rocket_base.lua`, `data/rocket_tower.lua`,
  `data/move_tutor.lua`, `data/statics.lua`, `data/fossils.lua`,
  `data/berry_shop.lua`).
- No ROM-derived files or Crystal ROM patch data.
- Difficulty & Battle Mechanics (`data/difficulty.lua`):
  - Trainer Held Items: Enemy trainer Pokémon automatically equip their canonical held items in battle.
  - Triple Kick 20 -> 60 -> 120 damage scaling.
  - Hard & Hardcore difficulty modes (in-battle item ban, Set battle style, badge level caps, permadeath tracking).
- Quality of Life (`data/qol.lua`):
  - TM & HM move names displayed directly on bag items (`TM01 DYNAMICPUNCH`, `HM03 SURF`, etc.).
  - Deletable HM moves (Move Deleter bypasses HM restriction).
  - Halved egg hatch cycle step requirements.
  - Instant Kurt Apricorn ball crafting.
  - Fast Nurse Joy healing and unlosable first rival battle flow.
- Custom Party Menu Sprites (`data/icons.lua` & `assets/icons/`):
  - Added all 251 unique animated 16x32 party menu icons from Crystal Legacy, replacing the generic Gen 2 species icon categories with individual species sprites.

## Deliberately not included yet

- Battle Tower custom floor rewards and rosters (Phase 4 side-content).
- GS Ball custom bag icon sprite.

## Test

Run from a Crystal-support engine checkout:

```sh
python3 tools/modkit.py gen2check mods/crystal_legacy_changes --notes
python3 tools/modkit.py validate mods/crystal_legacy_changes --base imported
python3 tools/modkit.py lint mods/crystal_legacy_changes
POKEPORT_DATA_DIR=tests/fixture_data luajit mods/crystal_legacy_changes/tests/crystal_legacy_changes_test.lua
```

The mod targets Crystal specifically. It must be tested against a Crystal-support commit and
a freshly imported Crystal cache, not a Gen 1-only checkout.

## Development notes

- The engine's gen2 icon override copy (overrides/icons/gen2/) is generated
  from the canonical art in assets/icons/ -- after a fresh clone run
  tools/sync_icons.sh before playtesting (the release workflow regenerates
  the copy inside the packed zip automatically).
- The dev-side data converters under tools/ read the Crystal Legacy
  disassembly from the CL_SOURCE env var (default ~/dev/CL_source); they are
  never shipped with the mod.
