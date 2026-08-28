-- Goldenrod City Move Tutor (Phase 3d; CL maps/GoldenrodCity.asm:52-165,
-- texts 486-548, object_event 12,22).
--
-- CL gates the tutor's APPEARANCE via MAPCALLBACK_OBJECTS: he only shows once
-- the player has 7 Badges AND a Coin Case, and he hides again after today's
-- lesson (ENGINE_DAILY_MOVE_TUTOR).  Gold has no tutor at all.  Gold object
-- visibility is flag-driven (flag SET = hidden, flag-less = always visible)
-- and transient appear/disappear does not survive a map reload, so the mod
-- adds an ALWAYS-VISIBLE POKEFAN_M at CL's (12,22) and moves every gate into
-- the talk script (badge gate, Coin Case gate, daily gate).  Same contract,
-- headless-testable.
--
-- The 4-option menu and its branches are plain VM rows (verticalmenu stores
-- the 1-based choice in scriptVar, 0 on cancel); the DAILY gate and the TEACH
-- flow are mod commands.  The teach command parks the VM coroutine on the
-- party picker ({kind="mod_party_picker"} is unknown to Vm:resume so it parks
-- with self.pending set), a Gen2PartyMenu onChoose calls vm:resume(mon), then
-- the command gates the chosen mon against CL's tmhm table (data/tutor_moves
-- .lua -- NEVER patch species.tmhm, that is the egg-move list) plus a
-- KnowsMove check, and hands off to Game2:learnMoveOn (the engine's own TM
-- teach path).  The async onDone takes the 1000 coins from save.player.coins,
-- sets the daily flag, and says CL's farewell.
return {
  generation = 2,
  source = "crystal_legacy_changes/data/move_tutor.lua",
  map = "GOLDENROD_CITY",
  scriptKey = "crystal_legacy_changes:goldenrod_move_tutor",
  cost = 1000,       -- CL charges 1000 (Ask4000CoinsOkayText is a stale name;
                     -- TSP doc: "now costs 1000 Coins instead")
  badgeGate = 7,     -- CL callback: readvar VAR_BADGES; ifless 7 -> no tutor
  coinCaseItem = 54, -- gold items.lua: COIN_CASE = 54 (cache scripts checkitem 54)
  dailyKey = "goldenrodMoveTutor", -- save.dailyFlags.<key>, wiped each new day
  menu = {
    left = 0,
    right = 15,
    top = 2,
    bottom = 11,
    cursor = 1,
    flags = 64,      -- MENU_BACKUP_TILES (gold cache coin-vendor header)
    dataFlags = 128, -- STATICMENU_CURSOR
    -- ROM strings; the MoveTutor special's own move order is the same.
    items = { "FLAMETHROWER", "THUNDERBOLT", "ICE BEAM", "CANCEL" },
  },
  tutor = {
    eventFlag = 65535, -- 0xFFFF: no flag gate (always visible)
    hours = { -1, -1 },
    index = 15,        -- gold GoldenrodCity has 14 objects; the tutor is #15
    movement = 3,      -- SPRITEMOVEDATA_SPINRANDOM_SLOW (CL)
    palette = 0,       -- default POKEFAN_M colors (~= CL's PAL_NPC_RED)
    radius = { x = 0, y = 0 },
    script = 0,        -- no ROM pointer; the port resolves via scriptKey
    scriptKey = "crystal_legacy_changes:goldenrod_move_tutor",
    sight = 0,
    sprite = "SPRITE_POKEFAN_M",
    spriteId = 45,     -- gold cache: GoldenrodCity POKEFAN_M is spriteId 45
    type = 0,          -- OBJECTTYPE_SCRIPT
    x = 12,
    y = 22,            -- CL object_event 12, 22
  },
  texts = {
    -- CL text rows, adapted to the port's textbox (plain \n line breaks; the
    -- TextBox paginates at 4 lines).  #MON -> Pokemon.
    greet = "I can teach your\nPokémon amazing\nmoves if you'd\nlike.\nShould I teach a\nnew move?",
    no = "Aww… But they're\namazing…",
    coinsAsk = "It will cost you\n1000 coins. Okay?",
    tooBad = "Hm, too bad. I'll\nhave to get some\ncash from home…",
    insufficient = "…You don't have\nenough coins here…",
    which = "Wahahah! You won't\nregret it!\nWhich move should\nI teach?",
    understood = "If you understand\nwhat's so amazing\nabout this move,\nyou've made it as\na trainer.",
    farewell = "Wahahah!\nFarewell, kid!",
    incompatible = "B-but…",
    -- ORIGINAL gate lines: CL hides the tutor entirely in these states, so it
    -- has no texts for them; the always-visible script needs refusal text.
    badge = "I only teach moves\nto trainers who've\nbeaten seven Gyms.\nCome back when\nyou've earned more\nBadges.",
    coinCase = "You'll need a Coin\nCase to pay me.\nThere's one at the\nGoldenrod Game\nCorner.",
    daily = "I've done all I\ncan for today.\nCome back tomorrow!",
  },
}
