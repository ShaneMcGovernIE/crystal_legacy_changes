-- Crystal Legacy statics & gifts (Phase 3b+c).
--
-- Gold's Gen 2 engine has no Gen-1-style map_scripts runner: story content
-- is driven by the bytecode VM (src/script/gen2/Vm.lua) over decoded script
-- rows in data.gen2Scripts, object rows in data.gen2Maps, and the numeric
-- event-flag bitfield (Events.lua).  Every CL event in this file lands
-- through that seam (see main.lua applyStatics).
--
-- Flag-id budget: gold's highest extracted event-flag id is 1915
-- (initial_events.lua / maps.lua), so 1916+ is free.  Objects are visible
-- while their eventFlag is UNSET, so the static encounters' flags must be
-- SET at NewGame (bootFlags) and cleared by their release scripts.

local statics = {}

-- ---------------------------------------------------------------------------
-- Goldenrod Game Corner prizes.
--
-- CL sells ABRA 100 / PORYGON 800 / DRATINI 1500 (levels 5/15/15); gold sells
-- ABRA 200 / EKANS 700 / DRATINI 2100 (all L10).  The prizes are decoded ROM
-- script rows: the menu strings are inline on the two loadmenu rows (the
-- "57:688f" copy is the post-prize re-entry), and each prize arm carries its
-- coin count little-endian as { lo, hi } (700 = { 188, 2 }).
-- ---------------------------------------------------------------------------
statics.gameCorner = {
  menu = { "57:6880", "57:688f" },
  items = {
    "ABRA        100",
    "PORYGON     800",
    "DRATINI    1500",
    "CANCEL",
  },
  prizes = {
    { script = "57:68a9", price = 100, species = 63,  level = 5,  label = "ABRA" },
    { script = "57:68d7", price = 800, species = 137, level = 15, label = "PORYGON" },
    { script = "57:6905", price = 1500, species = 147, level = 15, label = "DRATINI" },
  },
}

-- ---------------------------------------------------------------------------
-- Dragon's Den Dratini Master (post-Clair shrine gift).
--
-- CL's Elder at the Dragon Shrine (maps/DragonShrine.asm) hands the quiz
-- winner an L15 DRATINI "as proof of worth" -- i.e. once Clair's RISING badge
-- is held.  Gold's Dragon's Den B1F has no Elder object: the shrine tile
-- (18,24) is a plain BGEVENT_READ whose script row "47:4586" is a single
-- jumptext.  We replace that row with the mod command verb, badge-gated
-- (RISING) and one-per-save (mod.save flag).  The gift is CL's "true master"
-- moveset (engine/events/dratini.asm scriptVar 0): WRAP/THUNDER_WAVE/TWISTER/
-- EXTREMESPEED -- PP values from Gold's moves.lua.
-- ---------------------------------------------------------------------------
statics.master = {
  scriptKey = "47:4586", -- Dragon's Den B1F shrine read bgEvent
  verb = "crystal_legacy_changes:dratini_master",
  badge = "RISING",      -- Clair's badge (trainers.lua)
  species = "DRATINI",
  speciesIndex = 147,
  level = 15,
  moves = {
    { id = "WRAP",         pp = 20, maxPp = 20 },
    { id = "THUNDER_WAVE", pp = 20, maxPp = 20 },
    { id = "TWISTER",      pp = 20, maxPp = 20 },
    { id = "EXTREMESPEED", pp = 5,  maxPp = 5 },
  },
  -- CL DragonShrine.asm text in the port's encoding: \n line, \f page.
  text = {
    take_this = "Hm... Good to see\nyou here.\n\fYour arrival is\nmost fortunate.\n\fI have something\nfor you.\n\fTake this DRATINI\nas proof that I\n\fhave recognized\nyour worth.",
    received = "{PLAYER} received\nDRATINI!",
    party_full = "Hm? Your party\nis full.",
    symbolic = "Dragon Pokémon are\nsymbolic of our\nclan.\n\fYou have shown\nthat you can be\n\fentrusted with\none.",
  },
}

-- ---------------------------------------------------------------------------
-- Vermilion City Snorlax — PIN (verification only, no patch).
--
-- The gold cart already ships CL's Snorlax change: the static lives in
-- Vermilion City (34,8) at L50 (CL moved it out of Route 11), woken by the
-- Poke Flute RADIO CHANNEL (Pokegear knob 78, 20.0 MHz) rather than an item,
-- and the channel itself is gated on the EXPN card in Kanto
-- (ui/gen2/Pokegear.lua:826-831).  The wake check is engine special 95
-- (script/gen2/Specials.lua:1741 SnorlaxAwake: current song + 5-cell
-- adjacency), the battle is BATTLETYPE_FORCEITEM L50, and the disappear
-- (world/gen2/World.lua:3596) sets the object's OWN flag 1904 so the next map
-- load keeps it gone; setevent 1872 marks EVENT_FOUGHT_SNORLAX.  Nothing to
-- patch — this section pins the facts so a future gold re-import cannot
-- regress them silently.  Verified 2026-08-13 against the gold cache
-- (maps.lua object, scripts.lua "4f:5291"/"4f:529e", text.lua "4f:5457"/
-- "4f:5477") and CL (maps/VermilionCity.asm:28-101, :166-179).
-- ---------------------------------------------------------------------------
statics.snorlax = {
  mapId = "VERMILION_CITY",
  scriptKey = "4f:5291",    -- Snorlax A-press read script (OBJECTTYPE_SCRIPT)
  wakeScriptKey = "4f:529e", -- iftrue branch of special 95
  coords = { x = 34, y = 8 },
  species = "SNORLAX",
  speciesIndex = 143,
  level = 50,
  wakeSpecial = 95,         -- SnorlaxAwake: Poke Flute channel + adjacency
  channel = "POKE_FLUTE_RADIO", -- Pokegear knob 78, EXPN-gated, Kanto only
  flags = {
    appear = 1904,          -- EVENT_VERMILION_CITY_SNORLAX (object flag)
    fought = 1872,          -- EVENT_FOUGHT_SNORLAX (setevent post-battle)
  },
  battleType = "BATTLETYPE_FORCEITEM",
  text = {
    sleeping = "SNORLAX is snoring\npeacefully…",
    wake = "The POKéGEAR was placed\nnear the sleeping SNORLAX…\n\f…\n\fSNORLAX woke up!",
  },
}

-- ---------------------------------------------------------------------------
-- Route 24 Mew — Celadon Mansion dex-count chain (CL).
--
-- CL releases a wild L60 MEW on Route 24 (8,12) when the Celadon Mansion 3F
-- Game Freak designer sees a complete dex.  The gold cart ALREADY ships the
-- designer chain itself: "5e:4c8c" does readvar 5 (VAR_DEXCAUGHT) / ifgreater
-- 248 -> "5e:4c9a", i.e. releases at caught > 248 = 249 caught — the same
-- NUM_POKEMON - 2 - 1 formula CL uses (251 species minus Mew and Celebi;
-- PLAN.md's "250-dex" is the doc's shorthand for this gate).  The diploma
-- branch "5e:4c9a" (fanfare, special 106 Diploma, setevent 214) is gold's
-- own.  What CL ADDS is the release: checkevent MEW_CAUGHT / iftrue skip /
-- clearevent MEW, spliced into the diploma branch via wholesale row rebuild
-- (fossils pattern) on free gold flags 1940 (EVENT_ROUTE_24_MEW) and 1941
-- (EVENT_ROUTE_24_MEW_CAUGHT); the iftrue skip target is a mod-owned script
-- key.  Phase 4b: SPRITE_MEW overworld art now ships (data/sprites.lua, from
-- CL gfx/icons/mew.png), so the Route 24 object below spawns at (8,12) with
-- CL's MewScript (maps/Route24.asm:31-56: opentext "Myuu..." / cry /
-- loadwildmon MEW, 60 / startbattle / disappear / set MEW / set MEW_CAUGHT /
-- reloadmapafterbattle), index 7 = gold ROUTE_24's next slot (6 objects).
-- Verified 2026-08-13 against the gold cache (scripts.lua
-- "5e:4c8c"/"5e:4c9a") and CL (maps/CeladonMansion3F.asm:22-38,
-- maps/Route24.asm:31-56).
-- ---------------------------------------------------------------------------
statics.mew = {
  gateKey = "5e:4c8c",      -- designer gate script (readvar/ifgreater — untouched)
  completedKey = "5e:4c9a", -- diploma branch (patched: release spliced in)
  skipKey = "crystal_legacy_changes:mew_release_after", -- iftrue skip target
  scriptKey = "crystal_legacy_changes:mew", -- battle script (CL MewScript)
  textKey = "crystal_legacy_changes:mew_battle", -- "Myuu..." (CL MewBattleText)
  battleText = "Myuu...",
  route = "ROUTE_24",
  coords = { x = 8, y = 12 },
  species = "MEW",
  speciesIndex = 151,
  level = 60,
  gate = { var = 5, minCaught = 249 }, -- VAR_DEXCAUGHT > 248; Mew+Celebi excluded
  flags = {
    mew = 1940,   -- EVENT_ROUTE_24_MEW (clearevent = release)
    caught = 1941 -- EVENT_ROUTE_24_MEW_CAUGHT (skips re-release)
  },
  sprite = "SPRITE_MEW", -- Phase 4b: art ships (CL gfx/icons/mew.png, 16x32 icon)
  objectIndex = 7,       -- gold ROUTE_24 has 6 objects (indices 1-6)
  object = {
    mapId = "ROUTE_24",
    eventFlag = 1940,
    index = 7,
    movement = 0x16,  -- SPRITEMOVEDATA_POKEMON (CL)
    palette = 4,      -- PAL_NPC_PINK slot (CL Route24 object PAL_NPC_PINK; gold slot id 4)
    radius = { x = 0, y = 0 },
    script = 0,
    scriptKey = "crystal_legacy_changes:mew",
    sight = 0,
    sprite = "SPRITE_MEW",
    spriteId = 0, -- no ROM OverworldSprites slot (mod-registered sprite)
    type = 0,     -- OBJECTTYPE_SCRIPT (CL)
    x = 8,
    y = 12,
  },
  text = {              -- gold text rows reused verbatim (CL wording identical)
    completed = "5e:4d41",      -- "Wow! Excellent! You completed your #DEX!"
    pause = "5e:4d7c",          -- "…"
    after_diploma = "5e:4d7f",  -- CL's GameFreakGameDesignerAfterDiplomaText
  },
}

-- ---------------------------------------------------------------------------
-- Kanto legendary birds — post-quest L60 wild encounters (CL).
--
-- CL releases each bird as a one-time L60 wild encounter after its quest
-- moment: Moltres after beating Blaine (maps/SeafoamGym.asm:33 clearevent
-- between reloadmapafterbattle and the badge setevent), Articuno after
-- beating Blue (maps/ViridianGym.asm:26, same seam), Zapdos when the player
-- returns the Machine Part to the Power Plant manager (maps/PowerPlant.asm
-- .FoundMachinePart clearevent right after setevent EVENT_RESTORED_POWER_TO_
-- KANTO — the task's "post-Lance" shorthand; the Zapdos L55 in Lance's
-- champion team is a separate trainer row, trainers.lua).  Gold has none of
-- it: the birds never appear and the flags don't exist.
--
-- CL's event is one EVENT_CAUGHT_<BIRD> flag per bird: seeded SET at NewGame
-- (bird hidden), cleared by the release splice (bird appears), set again by
-- the catch script (bird gone — the engine's disappear op also re-sets the
-- object's eventFlag, so a caught bird stays gone).  The catch script is CL's
-- verbatim flow (opentext / writetext "Gyaoo!" / cry / loadwildmon L60 /
-- startbattle / disappear / setevent / reloadmapafterbattle); Zapdos alone
-- adds faceplayer.  speciesIndex is gold's dex-order id (ARTICUNO=144,
-- ZAPDOS=145, MOLTRES=146 — gold's runtime data, same order as CL's
-- pokemon_constants); coords are CL's object_event coords in double-res tile
-- space; seams anchor on the gold script rows (verified in the cache's
-- scripts.lua: "53:5188" Blaine win path, "5f:4002" Blue, "54:4deb" manager
-- FoundMachinePart after setevent 1900 RESTORED_POWER).
--
-- All three visible objects spawn: Moltres reuses gold's SPRITE_MOLTRES
-- (POKEMON_SPRITE, PAL_OW_RED); Phase 4b added the missing art for the other
-- two (data/sprites.lua: SPRITE_ARTICUNO / SPRITE_ZAPDOS 16x96 walking sheets
-- converted from CL gfx/sprites/, palettes per CL's OverworldSprites entries),
-- so ARTICUNO (ROUTE_20, index 4) and ZAPDOS (ROUTE_10_NORTH, index 7 — gold
-- has 6 vanilla objects) spawn now too.  Verified 2026-08-13 against
-- the gold cache (maps.lua VICTORY_ROAD/ROUTE_20/ROUTE_10_NORTH objects,
-- scripts.lua "53:5188"/"5f:4002"/"54:4dbd"+"54:4deb", sprites.lua
-- SPRITE_MOLTRES, initial_events.lua) and CL (maps/SeafoamGym.asm,
-- maps/ViridianGym.asm, maps/PowerPlant.asm, maps/VictoryRoad.asm,
-- maps/Route20.asm, maps/Route10North.asm).
-- ---------------------------------------------------------------------------
statics.birds = {
  {
    id = "moltres",
    flag = 1942,          -- EVENT_CAUGHT_MOLTRES (free in gold's space)
    speciesIndex = 146,   -- MOLTRES
    level = 60,
    faceplayer = false,   -- CL's MoltresScript has no faceplayer
    text = "Gyaoo!",      -- CL's MoltresBattleText, verbatim
    mapId = "VICTORY_ROAD",
    coords = { x = 18, y = 32 },
    objectIndex = 7,      -- gold VICTORY_ROAD has 6 objects (1..6)
    sprite = "SPRITE_MOLTRES", -- gold art exists (POKEMON_SPRITE)
    textKey = "crystal_legacy_changes:birds_moltres",
    scriptKey = "crystal_legacy_changes:birds_moltres",
    seams = {             -- Blaine win path (post-battle, pre-badge)
      { scriptKey = "53:5188", afterOp = "reloadmapafterbattle" },
    },
    object = {            -- added to VICTORY_ROAD now (sprite exists)
      mapId = "VICTORY_ROAD",
      eventFlag = 1942,
      hours = { -1, -1 },
      index = 7,
      movement = 0x16,    -- SPRITEMOVEDATA_POKEMON (CL); engine stands it
      palette = 0,
      radius = { x = 0, y = 0 },
      script = 0,
      scriptKey = "crystal_legacy_changes:birds_moltres",
      sight = 0,
      sprite = "SPRITE_MOLTRES",
      spriteId = 0,       -- no ROM OverworldSprites slot (SpriteMons art)
      type = 0,
      x = 18,
      y = 32,
    },
  },
  {
    id = "articuno",
    flag = 1943,          -- EVENT_CAUGHT_ARTICUNO (free in gold's space)
    speciesIndex = 144,   -- ARTICUNO
    level = 60,
    faceplayer = false,   -- CL's ArticunoScript has no faceplayer
    text = "Gyaoo!",      -- CL's ArticunoBattleText, verbatim
    mapId = "ROUTE_20",
    coords = { x = 31, y = 11 },
    objectIndex = 4,      -- gold ROUTE_20 has 3 objects (1..3)
    sprite = "SPRITE_ARTICUNO", -- Phase 4b: art ships (CL gfx/sprites/articuno.png)
    textKey = "crystal_legacy_changes:birds_articuno",
    scriptKey = "crystal_legacy_changes:birds_articuno",
    seams = {             -- Blue (post-battle, pre-badge)
      { scriptKey = "5f:4002", afterOp = "reloadmapafterbattle" },
    },
    object = {            -- added to ROUTE_20 now (Phase 4b art)
      mapId = "ROUTE_20",
      eventFlag = 1943,
      hours = { -1, -1 },
      index = 4,
      movement = 0x16,    -- SPRITEMOVEDATA_POKEMON (CL); engine stands it
      palette = 1,        -- PAL_NPC_BLUE (CL Route20 articuno object)
      radius = { x = 0, y = 0 },
      script = 0,
      scriptKey = "crystal_legacy_changes:birds_articuno",
      sight = 0,
      sprite = "SPRITE_ARTICUNO",
      spriteId = 0,       -- no ROM OverworldSprites slot (mod-registered sprite)
      type = 0,
      x = 31,
      y = 11,
    },
  },
  {
    id = "zapdos",
    flag = 1944,          -- EVENT_CAUGHT_ZAPDOS (free in gold's space)
    speciesIndex = 145,   -- ZAPDOS
    level = 60,
    faceplayer = true,    -- CL's ZapdosScript starts with faceplayer
    text = "Gyaoo!",      -- CL's ZapdosBattleText, verbatim
    mapId = "ROUTE_10_NORTH",
    coords = { x = 4, y = 11 },
    objectIndex = 7,      -- gold ROUTE_10_NORTH has 6 objects (1..6)
    sprite = "SPRITE_ZAPDOS", -- Phase 4b: art ships (CL gfx/sprites/zapdos.png)
    textKey = "crystal_legacy_changes:birds_zapdos",
    scriptKey = "crystal_legacy_changes:birds_zapdos",
    seams = {             -- Power Plant manager, Machine Part returned
      { scriptKey = "54:4deb", afterOp = "setevent", afterEvent = 1900 },
    },
    object = {            -- added to ROUTE_10_NORTH now (Phase 4b art)
      mapId = "ROUTE_10_NORTH",
      eventFlag = 1944,
      hours = { -1, -1 },
      index = 7,
      movement = 0x16,    -- SPRITEMOVEDATA_POKEMON (CL); engine stands it
      palette = 3,        -- PAL_NPC_BROWN (CL Route10North zapdos object)
      radius = { x = 0, y = 0 },
      script = 0,
      scriptKey = "crystal_legacy_changes:birds_zapdos",
      sight = 0,
      sprite = "SPRITE_ZAPDOS",
      spriteId = 0,       -- no ROM OverworldSprites slot (mod-registered sprite)
      type = 0,
      x = 4,
      y = 11,
    },
  },
}

-- ---------------------------------------------------------------------------
-- Celebi / GS Ball — full Crystal chain (CL), ported to gold.
--
-- CL's chain: the Goldenrod Pokecenter link receptionist gives the GS BALL
-- (coord_events at the doorway, badge gate commented out in CL), the player
-- hands it to Kurt (7-badge gate), Kurt examines it and leaves town (the
-- Azalea Town scene returns the ball and sets the forest restless), and the
-- Ilex Forest shrine consumes the ball for a one-shot L30 Celebi wild battle.
-- The Ruins of Alph Inner Chamber offers the GS BALL as a fallback if the
-- Pokecenter scene was missed.
--
-- Gold has NONE of it: no GS_BALL item, no shrine event (the Ilex Forest
-- (8,22) shrine bg_event is a plain text row), a vanilla apricorn-only Kurt
-- script, and a flavor-only Inner Chamber.  This section wires the whole
-- chain mod-side:
--   * GS_BALL item def at index 251 (free — gold's max is 250).  The bag /
--     checkitem / takeitem / verbosegiveitem ops resolve items by this index
--     (World itemByIndex), so no engine work; the PACK ICON is Phase 4.
--   * A LINK_RECEPTIONIST object appended to GOLDENROD_POKECENTER_1F (gold
--     has no receptionist there; the sprite exists) with the gift script
--     (always-visible, gates on the got flag).
--   * Kurt's script ("55:45e3") splice: two checkevent/iftrue rows right
--     after opentext that branch to the mod's give/gave scripts.  give =
--     CL verbatim (7-badge gate, yesorno, take the ball); gave returns the
--     ball immediately and sets FOREST_IS_RESTLESS.  DELIBERATE
--     SIMPLIFICATION vs CL: Kurt hands the ball back in his house instead of
--     the Azalea Town return scene (gold's Kurt-outside object is the
--     vanilla apricorn quest; no clean scene port) — the functional chain is
--     identical and the shrine checkitem still sees the ball.
--   * The Ilex shrine bg_event repointed to the shrine script (quiet gold
--     text until restless; checkitem GS_BALL -> yesorno -> takeitem -> L30
--     Celebi wild battle).  NO SPRITE_CELEBI needed — Celebi is a wild
--     battle, not an overworld object.
--   * A RESEARCHER object appended to RUINS_OF_ALPH_INNER_CHAMBER offering
--     the GS BALL if the player never got one (gold has no Ho-Oh-puzzle
--     events, so CL's EVENT_SOLVED_HO_OH_PUZZLE gate has no gold equivalent
--     — the offer is open once the chamber is reachable).
-- Flags (all free in gold's space — gold max used 1944; Mew 1940/41, birds
-- 1942-44):
--   1945 EVENT_FOREST_IS_RESTLESS  (set by Kurt's gave branch, cleared by
--                                  the shrine battle)
--   1946 EVENT_CAN_GIVE_GS_BALL_TO_KURT (set by gift/fallback, cleared by
--                                  the gave branch)
--   1947 EVENT_GAVE_GS_BALL_TO_KURT (set by the give branch, cleared by the
--                                  gave branch)
--   1948 EVENT_GOT_GS_BALL_FROM_POKECOM_CENTER (set by gift/fallback; guards
--                                  the fallback offer)
-- Celebi species id is 251 (dex order, gold pokemon.lua); level 30 per CL's
-- loadwildmon CELEBI, 30.  Verified 2026-08-13 against the gold cache
-- (items.lua max index 250 + MYSTERY_EGG row shape; maps.lua
-- GOLDENROD_POKECENTER_1F objects / ILEX_FOREST bgEvent (8,22) /
-- RUINS_OF_ALPH_INNER_CHAMBER; scripts.lua "55:45e3" Kurt, "45:6989" shrine
-- text, "45:6e11" quiet shrine text) and CL (maps/GoldenrodPokecenter1F.asm,
-- maps/KurtsHouse.asm, maps/IlexForest.asm, maps/RuinsOfAlphInnerChamber.asm).
-- ---------------------------------------------------------------------------
statics.celebi = {
  item = {                -- GS_BALL: gold has no GS Ball; MYSTERY_EGG shape.
    battleMenu = "ITEMMENU_NOUSE",
    canSelect = false,
    canToss = false,
    description = "A mysterious BALL.<NEXT>It seems to be<NEXT>connected to the<NEXT>forest.",
    fieldMenu = "ITEMMENU_NOUSE",
    heldEffect = "HELD_NONE",
    heldParameter = 0,
    id = "GS_BALL",
    index = 251,          -- free in gold's space (max 250); pack icon = Phase 4
    name = "GS BALL",
    pocket = "KEY_ITEM",
    pocketId = 2,
    price = 0,
    propertyRaw = 192,
    source = "crystal_legacy_changes:celebi",
  },
  flags = {
    restless = 1945,      -- EVENT_FOREST_IS_RESTLESS
    canGive = 1946,       -- EVENT_CAN_GIVE_GS_BALL_TO_KURT
    gave = 1947,          -- EVENT_GAVE_GS_BALL_TO_KURT
    got = 1948,           -- EVENT_GOT_GS_BALL_FROM_POKECOM_CENTER
  },
  badgeGate = 7,          -- CL's VAR_BADGES < 7 gate on the Kurt hand-off
  speciesIndex = 251,     -- CELEBI (dex order)
  level = 30,             -- CL's loadwildmon CELEBI, 30
  pokecenter = {
    mapId = "GOLDENROD_POKECENTER_1F",
    objectIndex = 5,      -- gold has 4 objects; the receptionist is #5
    coords = { x = 2, y = 5 },
    sprite = "SPRITE_LINK_RECEPTIONIST", -- gold art exists
  },
  kurt = {
    scriptKey = "55:45e3",  -- gold's Kurt (both in-house Kurt objects share it)
  },
  shrine = {
    mapId = "ILEX_FOREST",
    scriptKey = "45:6989",  -- gold's (8,22) shrine bg_event (CL's exact coords)
    quietText = "45:6e11",  -- gold's plain shrine text, reused for the quiet state
    coords = { x = 8, y = 22 },
  },
  fallback = {
    mapId = "RUINS_OF_ALPH_INNER_CHAMBER",
    objectIndex = 4,      -- gold has 3 flavor NPCs; the researcher is #4
    coords = { x = 17, y = 23 },
    sprite = "SPRITE_SCIENTIST", -- gold art exists
  },
  scriptKeys = {
    gift = "crystal_legacy_changes:celebi_gift",
    giftDone = "crystal_legacy_changes:celebi_gift_done",
    kurtGive = "crystal_legacy_changes:celebi_kurt_give",
    kurtGiveDecline = "crystal_legacy_changes:celebi_kurt_decline",
    kurtGave = "crystal_legacy_changes:celebi_kurt_gave",
    shrine = "crystal_legacy_changes:celebi_shrine",
    shrineBattle = "crystal_legacy_changes:celebi_shrine_battle",
    fallback = "crystal_legacy_changes:celebi_fallback",
    fallbackDone = "crystal_legacy_changes:celebi_fallback_done",
  },
  texts = {               -- CL dialogue, verbatim in spirit
    gift = "Congratulations! As a special deal, a GS BALL has been sent just for you! Please accept it!",
    kurtWhat = "Wh-what is that? I've never seen one before. It looks a lot like a #BALL, but it seems to be something else. Let me check it for you.",
    kurtNo = "This one could take a long time. Are you sure you don't want to show it to me?",
    kurtChecking = "I'm checking it now.",
    kurtShake = "…This BALL started to shake while I was checking it! The forest must be restless! Take it to the ILEX FOREST SHRINE!",
    shrinePrompt = "ILEX FOREST SHRINE… It's in honor of the forest's protector… …Want to put the GS BALL in?",
    shrineInsert = "<PLAYER> put in the GS BALL.",
    fallback = "There is a strange presence here… Perhaps this BALL belongs to ILEX FOREST. Take it!",
  },
}

return statics
