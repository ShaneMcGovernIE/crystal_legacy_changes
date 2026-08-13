-- Phase 4b: overworld sprite art, extracted from CL and converted to gold's
-- mode L 4-shade format (assets/sprites/*.png; see tools/convert_ow_sprites.py).
--
-- Registration target is the global gen2Sprites table (mod.content.sprites:
-- register), keyed by the id strings that data/statics.lua objects and
-- data/rocket_base.lua spriteSwaps reference, resolved by Npc.lua via
-- gen2Sprites[objDef.sprite].
--
-- Per-sprite provenance and palette (all CL-faithful):
--   SPRITE_ARTICUNO  16x96 sheet   gfx/sprites/articuno.png  PAL_OW_BLUE  (CL sprites.asm: PAL_OW_BLUE, 6-frame WALKING_SPRITE)
--   SPRITE_ZAPDOS    16x96 sheet   gfx/sprites/zapdos.png    PAL_OW_BROWN (CL sprites.asm: PAL_OW_BROWN, 6-frame WALKING_SPRITE)
--   SPRITE_MEW       16x32 icon    gfx/icons/mew.png         paletteId 4  (CL Route24 PAL_NPC_PINK slot; gold has no name for slot 4)
--   SPRITE_CELEBI    16x32 icon    gfx/icons/celebi.png      PAL_OW_GREEN (CL menu-icon palette)
--   SPRITE_ELECTRODE 16x32 icon    gfx/icons/electrode.png   PAL_OW_RED   (CL RocketBaseB2F PAL 0)
--   SPRITE_MURKROW   16x32 icon    gfx/icons/murkrow.png     PAL_OW_BLUE  (CL RocketBaseB3F PAL_NPC_BLUE)
--
-- The four pokemon-range sprites are POKEMON_SPRITE icons (frames=1) because
-- that is how CL's engine renders them (LoadOverworldMonIcon, 16x32 icons);
-- gold's SPRITE_MOLTRES/SPRITE_VOLTORB records are the same shape.  The two
-- birds are real 16x96 walking sheets (CL's OverworldSprites entries are
-- WALKING_SPRITE).  All art is genuine CL source converted through the same
-- ladder the runtime bake expects — nothing is synthesized.
--
-- Note: SPRITE_CELEBI is registered for completeness (the shrine cutscene
-- will need it if ever ported) but no object references it: the mod's Celebi
-- is a wild battle by design (see data/statics.lua).
local M = {}
M.sprites = {
  {
    id = "SPRITE_ARTICUNO",
    image = "assets/sprites/articuno.png",
    frames = 6,
    walker = true,
    palette = "PAL_OW_BLUE",
    paletteId = 1,
    spriteType = "WALKING_SPRITE",
    source = "CL Source: gfx/sprites/articuno.png (16x96, PAL_OW_BLUE)",
  },
  {
    id = "SPRITE_ZAPDOS",
    image = "assets/sprites/zapdos.png",
    frames = 6,
    walker = true,
    palette = "PAL_OW_BROWN",
    paletteId = 3,
    spriteType = "WALKING_SPRITE",
    source = "CL Source: gfx/sprites/zapdos.png (16x96, PAL_OW_BROWN)",
  },
  {
    id = "SPRITE_MEW",
    image = "assets/sprites/mew.png",
    frames = 1,
    walker = false,
    paletteId = 4,
    spriteType = "POKEMON_SPRITE",
    species = "MEW",
    icon = "ICON_HUMANSHAPE",
    source = "CL Source: gfx/icons/mew.png (16x32, PAL_NPC_PINK slot)",
  },
  {
    id = "SPRITE_CELEBI",
    image = "assets/sprites/celebi.png",
    frames = 1,
    walker = false,
    palette = "PAL_OW_GREEN",
    paletteId = 2,
    spriteType = "POKEMON_SPRITE",
    species = "CELEBI",
    icon = "ICON_HUMANSHAPE",
    source = "CL Source: gfx/icons/celebi.png (16x32, menu-icon palette)",
  },
  {
    id = "SPRITE_ELECTRODE",
    image = "assets/sprites/electrode.png",
    frames = 1,
    walker = false,
    palette = "PAL_OW_RED",
    paletteId = 0,
    spriteType = "POKEMON_SPRITE",
    species = "ELECTRODE",
    icon = "ICON_VOLTORB",
    source = "CL Source: gfx/icons/electrode.png (16x32, PAL 0)",
  },
  {
    id = "SPRITE_MURKROW",
    image = "assets/sprites/murkrow.png",
    frames = 1,
    walker = false,
    palette = "PAL_OW_BLUE",
    paletteId = 1,
    spriteType = "POKEMON_SPRITE",
    species = "MURKROW",
    icon = "ICON_BIRD",
    source = "CL Source: gfx/icons/murkrow.png (16x32, PAL_NPC_BLUE)",
  },
}
return M
