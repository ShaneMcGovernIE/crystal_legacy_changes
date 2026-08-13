# Crystal Legacy Changes

Applies the explicit Pokemon stat and move changes documented in the supplied
Crystal Legacy design document to Pokemon Gold through the native Gen1Recomp
mod API. Documented names are resolved to Gold registry ids by iterating the
content registries at load time.

## Implemented

- 48 documented Gold species stat records, using Gold's split Special Attack
  and Special Defense fields.
- 251 species level-up learnsets and 2,590 level-up move rows from the Crystal
  Legacy version 1.3 data sheet.
- 251 species TM/HM compatibility lists and 6,485 unique compatibility rows
  from the TMHM Learnsets tab. The three tutor-only columns are excluded.
- Documented move power, accuracy, PP, type, priority, critical-rate, and
  compatible effect changes, including Sacred Fire's PP.
- Gold physical/special type categories for Ghost and Dark.
- Wild encounters and trainer parties from the Crystal Legacy data sheet
  (`data/encounters.lua`, `data/trainers.lua`).
- Gold marts reshelved to the CL lists (`data/marts.lua`). Celadon 4F's mail
  shelf is repurposed to CL vitamins (intentional, matches CL).
- Evolution changes from the CL data sheet (`data/evolutions.lua`).
- Story and event content: Team Rocket Base and RadioTower, the Goldenrod Move
  Tutor, Game Corner prizes, fossils + Ruins of Alph revival, the Dratini
  Master, Mew (Route 24, releases at 249 caught — >248), Celebi/GS Ball, and
  the Kanto birds (`data/rocket_base.lua`, `data/rocket_tower.lua`,
  `data/move_tutor.lua`, `data/statics.lua`, `data/fossils.lua`,
  `data/berry_shop.lua`).
- No ROM-derived files or Crystal ROM patch data.

## Deliberately not included yet

The remaining items are Phase 4 engine-gap work (they need engine/fork
patches, not mod data) and are never faked:

- Battle Tower trainers and rewards.
- Hard and Hardcore modes (battle item-ban hook, forced Set, no-revive).
- Trainer held items (every boss row in the CL doc carries one).
- Sprites — known overworld art gaps, never faked:
  - Rocket Base B2F's six electrodes still render Gold's VOLTORB art (no
    SPRITE_ELECTRODE overworld art ships), and Rocket Base B3F's Murkrow
    still reuses Gold's SPRITE_MOLTRES bird art.
  - Mew (Route 24) and Articuno/Zapdos (Route 20 / Route 10 North) have no
    overworld art in Gold — their story wiring ships in `data/statics.lua`
    (flags/scripts/coords) and activates with the Phase 4 sprite drop.
    Moltres (Victory Road) and Celebi (Ilex shrine) are live today: Gold
    ships SPRITE_MOLTRES and Celebi is a wild battle, so it needs no sprite.
    The GS Ball's bag icon is a Phase 4 art gap too.
- The Flower Shop berry shop (`data/berry_shop.lua`) ships mod-side but its
  mart-shelf gate is a Phase 4 engine item.
- The Goldenrod Move Tutor's proper UI (the tutor scene ships now through
  Gold's native tutor scene).
- The QoL batch: HM deletable, running shoes, TM names visible, Repel
  prompt, faster healing.

Exact Triple Kick 20/60/120 scaling is likewise not represented: Gold's
native effect owns that calculation, so changing only the move record would
claim the wrong behavior.

The document's `Faint Attack` accuracy is written as 101%. The engine schema
allows at most 100%, so this implementation uses 100% as the valid equivalent.

## Test

Run from a Gold-support engine checkout:

```sh
  python3 tools/modkit.py gen2check mods/crystal_legacy_changes --notes
python3 tools/modkit.py validate mods/crystal_legacy_changes --base imported
python3 tools/modkit.py lint mods/crystal_legacy_changes
POKEPORT_DATA_DIR=tests/fixture_data luajit mods/crystal_legacy_changes/tests/crystal_legacy_changes_test.lua
```

The mod targets Gold only. It must be tested against a Gold-support commit and
a freshly imported Gold cache, not a Gen 1-only checkout.
