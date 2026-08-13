# Plan: finish crystal_legacy_changes → 1.0.0

**Goal:** full Crystal Legacy v1.3 parity on Gold — data (stats/moves/learnsets/
TMHM/encounters/trainers/marts/evolutions), script (story, gifts, events), QoL —
sandbox-clean, on the standard release workflow. Total estimate: **~2.5 working
weeks** in 6 phases.

## Phase 0 — Foundation (0.5 day)

1. `git init` in `~/dev/crystal_legacy_changes`, initial commit, GitHub repo,
   `modkit add-release-workflow`. (Dir currently has no repo — versioning
   before growth.)
2. Checkout `grandmas-kitchen` in `~/dev/gen1recomp` (has Game2 + Sandbox),
   import a Gold ROM, run `gen2check --strict` + `validate --base imported` +
   the suite. Fix whatever 0.3.0 breaks on a real Gold cache.
3. Create mounted copy `~/dev/Gen1RecompMods/crystal_legacy_changes`
   (three-copy layout; tests exercise the mounted copy).
4. Refresh README/mod.card: delete the stale "no seams" claims, decide
   Sacred Fire (add PP patch — it is one line).

## Phase 1 — Data converters (2–3 days)

Dev-side Python, never shipped (`.modkitignore`), cloning
`cRz-Shadows/Pokemon_Crystal_Legacy` as read-only source. Before writing any
converter, verify the Gold shapes in engine source:

1. `data/wild/*.asm` → `encounters.lua` — confirm slot encoding for
   `encounterBuckets` (Gold = morning/day/night; `encounter.species` ctx
   carries `daytime` as fallback seam).
2. `data/trainers/parties.asm` + `classes.asm` → `trainers.lua` — confirm the
   outer `parties` list = per-badge variants (schema: list of list of
   {level, species}).
3. `data/items/marts.asm` → `marts.lua` (`text_pointers` per-map `mart` = item
   id list).
4. `data/pokemon/evos_attacks.asm` → evolution diff: use-item methods
   (Upgrade/King's Rock/Metal Coat/Brick Piece/Dragon Scale) + early level
   shifts.
5. Cross-check row counts against the TSP doc tables.

## Phase 2 — Data patches (2–3 days, versions 0.4→0.7)

One shipped file + one test per step; each passes `gen2check`/`validate`/
`lint`/`pack` + suite before the next:

1. **Encounters** — assert doc specifics: Larvitar in Dark Cave, starters on
   Routes 26/27, Houndour/Slugma in Burned Tower, Mt. Silver rework.
2. **Trainers** — gym leaders with 3 badge variants, E4, Kanto leaders,
   rival, Red (Lv 93 Pikachu), rematches, Rocket incl. Eto. Held items wait
   on Phase 4.
3. **Marts** — Cianwood/Mahogany/Blackthorn, Celadon TM floors, Goldenrod
   floors.
4. **Evolutions** — item evos via `evolution_methods` registration +
   `pokemon.evolutions` patches; early level evolutions.

## Phase 3 — Script/story layer (3–5 days, 0.8→0.9)

Largest chunk — one event per `map_scripts` patch, each with a test:

1. Fossil revival (`item_effects` for fossils — XaeroChill-style use→revive)
   + Ruins of Alph scripts.
2. Statics/gifts: Snorlax, legendary birds post-defeat release, Mew
   (Route 24, 250-dex), Celebi/GS Ball, game corner prizes, dragon's den
   ExtremeSpeed Dratini.
3. Team Rocket storyline (Eto beats, executive fights, trap-floor Electrode
   gauntlet).
4. Goldenrod Move Tutor (daily, 1000 coins) + Battle Tower trainers/rewards.
5. QoL via data: Berry shop (mart data), fossil items; verify nurse-healing
   seam (likely Phase 4).

## Phase 4 — Engine gaps via the fork (2–4 days) — one decision point

Mod-only work cannot close these; they need engine patches. Plan: fork
branches on `ShaneMcGovernIE/gen1recomp` + upstream PRs, in priority order:

1. **Trainer held items** — add an items field to `trainers` parties entries +
   Gold battle applies them. Highest fidelity impact: every boss row in the
   doc carries a held item.
2. **Hard/Hardcore modes** — battle item-ban hook + forced Set + no-revive
   flag.
3. **HM deletable, running shoes, TM names visible, Repel prompt, faster
   healing** — batch as smaller PRs.
4. **Odd Egg pool seam** — verify whether `give_pokemon` + egg generation is
   hookable; else a small fork patch.

**Decision:** does 1.0 gate on these merging upstream, or ship and document
"requires engine ≥ 0.X"? Recommended: gate on the two big ones (items, hard
modes) landing on the dev line — they are data-visible everywhere; the small
QoL batch can trail into 1.0.1.

## Phase 5 — Release 1.0.0 (0.5 day)

1. Manifest 1.0.0 + CHANGELOG heading + commit
   `crystal_legacy_changes: release 1.0.0` (release workflow rebuilds zip from
   `git archive`).
2. Full gate run: `gen2check --strict`, `validate --base imported`, `lint`,
   `pack`, suite.
3. Real Gold boot checklist on dev (post-Friday): log channel
   (adapter/sandbox warnings) + in-game manager channel, all phases' features
   spot-checked.
4. Update mod.card credits (add cRz-Shadows + sprite artists per upstream
   README).
5. Tag/release via the workflow; verify the zip has manifest.json at root and
   no test/converter files.

## Next action

`cd ~/dev/gen1recomp && git fetch upstream && git checkout -b gold-test
upstream/grandmas-kitchen` — then run the mod's test command once to see the
real gap size before any new work.
