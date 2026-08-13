return {
  generation = 2,
  source = "crystal_legacy_changes/data/berry_shop.lua",
  -- Goldenrod Flower Shop berry clerk (CL: maps/GoldenrodFlowerShop.asm:215).
  -- Gold's shop has no clerk at all (only TEACHER + LASS), so the mod adds
  -- the CL one; it sells the two berry shelves CL appends past the 34 gold
  -- marts, badge-gated at 7 badges (CL's BerryMartScript, same file:106-119).
  map = "GOLDENROD_FLOWER_SHOP",
  clerk = {
    eventFlag = 65535, -- 0xFFFF: no flag gate
    hours = { -1, -1 },
    index = 3,
    movement = 6, -- SPRITEMOVEDATA_STANDING_DOWN (engine MOVE enum matches)
    palette = 0,
    radius = { x = 0, y = 0 },
    script = 0, -- no ROM pointer: the mod script resolves via scriptKey
    scriptKey = "crystal_legacy_changes:berry_mart",
    sight = 0,
    sprite = "SPRITE_CLERK",
    spriteId = 56, -- ROM:OverworldSprites[56]
    type = 0, -- OBJECTTYPE_SCRIPT
    x = 5,
    y = 3,
  },
  -- The two shelves CL defines past the 34 gold marts.  Gold's pokemart
  -- opcodes only use ids 0..33 (enumerated in Phase 2), so ids 34+ are
  -- collision-free; the mod writes the clerk's script bytes, so it uses
  -- 34/35 (not CL's 37/38) to keep the injected lists tightly packed.
  shelves = { "MART_BERRYS", "MART_BERRYS_2" },
  martIds = { 34, 35 },
  scriptKey = "crystal_legacy_changes:berry_mart",
  -- CL gates the shelves on badge count (VAR_BADGES < 7 -> MART_BERRYS).
  badgeGate = 7,
}
