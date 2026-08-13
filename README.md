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
- No ROM-derived files or Crystal ROM patch data.

## Deliberately not included yet

- Wild encounters and trainer parties (PLAN.md Phases 1–2).
- Team Rocket, Celebi, fossil, gift, mart, Move Tutor, Battle Tower, and
  rematch story changes (PLAN.md Phase 3).
- Exact Triple Kick 20/60/120 scaling. Gold's native effect currently owns
  that calculation, so changing only the move record would claim the wrong
  behavior.

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
