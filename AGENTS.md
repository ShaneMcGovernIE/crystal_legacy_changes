# crystal_legacy_changes

Gen1Recomp mod reimplementing Crystal Legacy (TSP) v1.3 data on **Gold only**
(`"games": ["gold"]` — never loads on Gen 1). Pure Lua data patches, no build
step. `PLAN.md` is the 6-phase roadmap to 1.0; work follows it.

## Layout

- `main.lua` — entry. Loads `rebalance.lua` / `learnsets.lua` / `tmhm.lua` via
  `mod:read` + `load` + `pcall` (the sandbox-sanctioned pattern), resolves doc
  names to ids by iterating the registries (no ROM-derived ids shipped), then
  patches. Counts land on `mod.exports.rebalance`.
- `rebalance.lua` — 88 of 89 documented move rows, 48 species baseStats,
  Ghost/Dark type categories. No `require`s.
- `learnsets.lua` / `tmhm.lua` — GENERATED from the Crystal Legacy v1.3 Google
  Sheet. Do not hand-edit rows without noting it; the regenerating converter
  does not exist yet (PLAN.md Phase 1).
- `tests/crystal_legacy_changes_test.lua` — seeds a synthetic Gold-shaped
  fixture via `T.sdk.loadMod(..., { generation = 2 })`. Does NOT call
  `Data:load()`, so no `POKEPORT_DATA_DIR`. Must run from the engine root.
  Uses `dofile`/`package.path` freely — tests are dev-side only.

## Engine requirement (easy to trip on)

`~/dev/gen1recomp` on `find-mods-release-stats` has **no Gold support**
(no `src/core/Game2.lua`; 60 commits behind upstream). Tests cannot run there.
Use `upstream/grandmas-kitchen` (has Game2 + the mod sandbox) until the Friday
release lands on dev/main. The suite has never run against a real Gold cache.

## Gates (from the engine root, Gold checkout required)

```sh
python3 tools/modkit.py gen2check mods/crystal_legacy_changes --strict
python3 tools/modkit.py validate mods/crystal_legacy_changes --base imported  # needs Gold ROM import
python3 tools/modkit.py lint mods/crystal_legacy_changes
python3 tools/modkit.py pack mods/crystal_legacy_changes
luajit mods/crystal_legacy_changes/tests/crystal_legacy_changes_test.lua
```

A clean `gen2check` means "nothing known-broken", not "works" — boot it.

## Sandbox (next engine release)

Shipped code must stay sandbox-clean: no `io`, `os.*` side-effects,
`love.filesystem`, `package`, `dofile`, `loadfile`, `debug`. `load()` and
`mod:read` in `main.lua` are legal. Check with:

```sh
grep -rnE '\bio\.|os\.(getenv|execute|remove|rename|exit|tmpname)|love\.(filesystem|thread|system|event)|require\("(io|os|debug|package|ffi|love\.)' *.lua
```

No output = clean. `mod.storage` is irrelevant here: the mod persists nothing.

## Known fidelity gaps (keep README/PLAN in sync)

- Sacred Fire missing (1 doc row) — patch it or document the omission.
- Triple Kick 20/60/120 scaling is engine-owned; Faint Attack 101% → 100%.
- Encounters, trainers, marts, evolutions, story: not implemented yet
  (PLAN.md Phases 1–3).
- Engine gaps needing fork patches (PLAN.md Phase 4): trainer held items
  (no item field in `trainers` schema), battle item-ban/Hard modes, Odd Egg
  pool. `encounter.species` on Gold carries `ctx.daytime`/`kind` — the seam
  for time-of-day encounters.

## Repo state quirks

- NOT a git repo yet (PLAN.md Phase 0). No mounted/installed copies exist —
  not in the three-copy sync loop used by other mods.
- Trainer party fidelity requires per-badge variants (`parties` =
  list-of-lists); verify engine selection behavior before writing trainer data.

## Sources

- TSP design doc (v1.3): `~/Downloads/Crystal Legacy by TSP.md`
- Upstream hack (data source for converters):
  `github.com/cRz-Shadows/Pokemon_Crystal_Legacy` — `data/` holds wild,
  trainers, marts, evos as `.asm`
- Engine mod docs: `~/Gen1Recomp-Developer-Guide` (Reference-Registries and
  Reference-Hooks are generated from the engine — treat as ground truth)
