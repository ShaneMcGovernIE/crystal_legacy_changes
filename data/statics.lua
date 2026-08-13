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

return statics
