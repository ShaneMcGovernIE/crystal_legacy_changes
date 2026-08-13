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
-- key.  BLOCKED at the visible object: gold has no SPRITE_MEW overworld art
-- (no SpriteMons row, no icon — Phase 4 item), so no Route 24 object is added
-- yet; the clearevent fires on a flag with no object, ready for the Phase 4
-- sprite drop.  Verified 2026-08-13 against the gold cache (scripts.lua
-- "5e:4c8c"/"5e:4c9a") and CL (maps/CeladonMansion3F.asm:22-38,
-- maps/Route24.asm:31-56).
-- ---------------------------------------------------------------------------
statics.mew = {
  gateKey = "5e:4c8c",      -- designer gate script (readvar/ifgreater — untouched)
  completedKey = "5e:4c9a", -- diploma branch (patched: release spliced in)
  skipKey = "crystal_legacy_changes:mew_release_after", -- iftrue skip target
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
  sprite = "SPRITE_MEW", -- BLOCKED: no overworld art in gold (Phase 4)
  text = {              -- gold text rows reused verbatim (CL wording identical)
    completed = "5e:4d41",      -- "Wow! Excellent! You completed your #DEX!"
    pause = "5e:4d7c",          -- "…"
    after_diploma = "5e:4d7f",  -- CL's GameFreakGameDesignerAfterDiplomaText
  },
}

return statics
