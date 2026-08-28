-- Crystal Legacy: Fossil revival + Ruins of Alph (Phase 3a).
--
-- The Gold ROM this engine ships with carries NO fossil items: the item
-- table is renumbered (REPEL is index 20, where vanilla Gold keeps
-- OLD_AMBER) and the Research Center's three scientists resolve to flavor
-- text only -- there is no reachable revival flow in the ROM cache.  Crystal
-- Legacy restores the fossils as inert items and wires a revival scientist
-- plus the three chamber puzzles that hand the fossils out.
--
-- Maps of the surfaces this mod touches (all verified against the Gold
-- cache under the engine's data/generated):
--   * the top-right Research Center scientist is map object 2, script key
--     "44:4ac6" (RUINS_OF_ALPH_RESEARCH_CENTER).  Its vanilla rows are
--     faceplayer/opentext/writetext flavor text.
--   * each chamber's puzzle is the UnownPuzzle special (already ported); the
--     solved sequence is its own script row, reached via iftrue from the
--     puzzle tile script.  The MAPCALLBACK_TILES script runs on every load
--     of the map (Vm:runCallback, same VM path as a talk), which is the arm
--     that claims the fossil once the player later earns the badge.
--     KABUTO:   solved "44:44ea" (sets event 673), callback "44:44ce"
--     OMANYTE:  solved "44:4692" (sets event 674), callback "44:4676"
--     AERODACTYL: solved "44:476c" (sets event 675), callback "44:4750"
--   * badge engine flags are 25 + Johto index (FieldMoves.BADGE_FLAG):
--     PLAIN=28 (Gym 3), FOG=29 (Gym 4), GLACIER=32 (Gym 7).  The save also
--     keys player.badges by the same uppercase names, which is what the
--     reward handlers read.
--   * species indices are the Gold data.pokemon `index` field (the
--     extractor's 1-based dex order, what speciesByIndex matches):
--     KABUTO=140, OMANYTE=138, AERODACTYL=142.
return {
  -- The three inert fossil items, registered at indices above the ROM's max
  -- (250).  Inert per vanilla GSC: no battle/field use, no held effect,
  -- tossable, price 0.
  items = {
    {
      id = "DOME_FOSSIL",
      index = 251,
      name = "DOME FOSSIL",
      pocket = "ITEM",
      pocketId = 1,
      price = 0,
      description = "A fossil. It resembles a rare Pokémon.",
      heldEffect = "HELD_NONE",
      heldParameter = 0,
      canSelect = false,
      canToss = true,
      battleMenu = "ITEMMENU_NOUSE",
      fieldMenu = "ITEMMENU_NOUSE",
    },
    {
      id = "HELIX_FOSSIL",
      index = 252,
      name = "HELIX FOSSIL",
      pocket = "ITEM",
      pocketId = 1,
      price = 0,
      description = "A fossil. It resembles a rare Pokémon.",
      heldEffect = "HELD_NONE",
      heldParameter = 0,
      canSelect = false,
      canToss = true,
      battleMenu = "ITEMMENU_NOUSE",
      fieldMenu = "ITEMMENU_NOUSE",
    },
    {
      id = "OLD_AMBER",
      index = 253,
      name = "OLD AMBER",
      pocket = "ITEM",
      pocketId = 1,
      price = 0,
      description = "A stone containing the genes of an ancient Pokémon.",
      heldEffect = "HELD_NONE",
      heldParameter = 0,
      canSelect = false,
      canToss = true,
      battleMenu = "ITEMMENU_NOUSE",
      fieldMenu = "ITEMMENU_NOUSE",
    },
  },

  -- The revival scientist (top-right of the Research Center).
  scientist = {
    mapId = "RUINS_OF_ALPH_RESEARCH_CENTER",
    scriptKey = "16:5214",
    scriptKeys = { "16:5214", "44:4ac6" },
    -- Dome -> Kabuto L15 (after Gym 3), Helix -> Omanyte L20 (after Gym 4),
    -- Old Amber -> Aerodactyl L25 (after Gym 7).  The per-mon level is fixed
    -- per the Crystal Legacy spec; the gym gates the FOSSIL's obtainability
    -- (the chamber rewards below), not the revival.
    revive = {
      { itemId = "DOME_FOSSIL", itemIndex = 251,
        species = "KABUTO", speciesIndex = 140, level = 15 },
      { itemId = "HELIX_FOSSIL", itemIndex = 252,
        species = "OMANYTE", speciesIndex = 138, level = 20 },
      { itemId = "OLD_AMBER", itemIndex = 253,
        species = "AERODACTYL", speciesIndex = 142, level = 25 },
    },
  },

  -- Chamber puzzles: solving hands out the fossil, badge-gated and
  -- one-per-save (mod.save flags, so a NEW GAME restarts the hunt).  Solving
  -- early without the badge still solves the puzzle; the deferred arm on map
  -- entry claims the fossil once the badge is earned, so it can never be
  -- stranded.  The Ho-Oh chamber is untouched (it stays the GS Ball arm).
  chambers = {
    {
      id = "KABUTO",
      solvedScript = "16:4778",
      callbackScript = "16:4737",
      solvedScripts = { "16:4778", "44:44ea" },
      callbackScripts = { "16:4737", "44:44ce" },
      solvedEvent = 673,
      badge = "PLAIN",            -- Gym 3 (engine flag 28)
      itemId = "DOME_FOSSIL",
      itemIndex = 251,
    },
    {
      id = "OMANYTE",
      solvedScript = "16:4c36",
      callbackScript = "16:4bf8",
      solvedScripts = { "16:4c36", "44:4692" },
      callbackScripts = { "16:4bf8", "44:4676" },
      solvedEvent = 674,
      badge = "FOG",              -- Gym 4 (engine flag 29)
      itemId = "HELIX_FOSSIL",
      itemIndex = 252,
    },
    {
      id = "AERODACTYL",
      solvedScript = "16:4df7",
      callbackScript = "16:4db9",
      solvedScripts = { "16:4df7", "44:476c" },
      callbackScripts = { "16:4db9", "44:4750" },
      solvedEvent = 675,
      badge = "GLACIER",          -- Gym 7 (engine flag 32)
      itemId = "OLD_AMBER",
      itemIndex = 253,
    },
  },

  -- Custom text rows, keyed by name; applyFossils registers them under the
  -- "crystal_legacy_changes:" prefix into data.gen2Text (text registry,
  -- routed on Gen 2) and the commands show them via Vm:showText, which blocks
  -- until the A press -- the ordinary writetext/waitbutton run.
  text = {
    revive_greet = "I study the Fossil\nRevival machine!\fHand me a Fossil and\nI'll revive it!",
    revive_none = "You don't have any\nFossils with you.\fCome back when you\nfind one!",
    revive_party_full = "Your party is full!\fMake room in your\nparty and return!",
    revive_kabuto = "A Dome Fossil!\nIt's a KABUTO!\fI'll revive it now!",
    revive_omanyte = "A Helix Fossil!\nIt's an OMANYTE!\fI'll revive it now!",
    revive_aerodactyl = "An Old Amber!\nIt's an AERODACTYL!\fI'll revive it now!",
    got_kabuto = "{PLAYER} received\nKABUTO!",
    got_omanyte = "{PLAYER} received\nOMANYTE!",
    got_aerodactyl = "{PLAYER} received\nAERODACTYL!",
    ruins_got_kabuto = "{PLAYER} found\nDOME FOSSIL!",
    ruins_got_omanyte = "{PLAYER} found\nHELIX FOSSIL!",
    ruins_got_aerodactyl = "{PLAYER} found\nOLD AMBER!",
    ruins_bag_full = "The BAG is full...\nThe fossil stayed put.",
  },
}
