-- Phase 3d1: Team Rocket Base B1F-B3F (CL maps/TeamRocketBaseB{1,2,3}F.asm).
--
-- The audit (deltas 1-9 + sprite 11) compared gold's shipped Base maps against
-- CL's: almost every gold object/coordEvent/bgEvent/trainer/script already
-- matches CL, so this file carries only the real differences.  Every gold
-- value below was read from the imported runtime maps (data/generated/maps.lua)
-- and cross-checked against the asm walkthrough section 11.
--
--   1  B1F (21,12) itemball flag 1643: X_ACCURACY(33) -> GUARD_SPEC(41)
--   2  B2F GruntM18: (2,1) sight 3 -> (4,1) sight 1
--   3  B3F RaticateTailGrunt: (5,15) sight 3 -> (5,14) sight 3 (sight unchanged)
--   4  B3F Ross: (25,12) sight 4 -> (23,11) sight 0
--   5  B3F Mitch: (14,15) sight 3 -> (11,15) sight 3 (sight unchanged)
--   6  B3F (1,12)  itemball flag 1645: FULL_HEAL(38) -> PROTEIN(27)
--   7  B3F (3,12)  itemball flag 1646: DIRE_HIT(44) -> X_SPECIAL(53)
--   8  B3F (28,9)  itemball flag 1647: PROTEIN(27) -> FULL_HEAL(38)
--   9  B3F ADD UltraBall itemball at (14,10), item 2 (ULTRA_BALL),
--      eventFlag 1934 (free: gold caps at 1931, rocket_tower uses 1932/1933)
--   11 B3F executive at (8,3): SPRITE_ROCKET -> SPRITE_ARCHER (real art ships
--      via rocket_tower's global registration)
--
-- Known Phase 4 art gaps, documented in README/CHANGELOG (never faked):
--   10 B2F six SPRITE_VOLTORB "electrodes" -> SPRITE_ELECTRODE (gold ships no
--      electrode overworld art; CL's sprite is 32x96 but gold's VOLTORB art is
--      what the engine will show until art lands)
--   12 B3F Murkrow at (7,2) (gold reuses SPRITE_MOLTRES; no MURKROW art ships)
--
-- No scripts/coordEvents/bgEvents are patched: gold's B3F boss script already
-- runs class 51 member 4 (EXECUTIVEM_4), which data/trainers.lua re-teams to
-- CL's exact Archer hideout team (WEEZING/TAUROS/HOUNDOOM/SLOWBRO).
local M = {}

-- Itemball item repoints: match by map + eventFlag (unique per ball).
M.itemSwaps = {
  { map = "TEAM_ROCKET_BASE_B1F", eventFlag = 1643, item = 41 },
  { map = "TEAM_ROCKET_BASE_B3F", eventFlag = 1645, item = 27 },
  { map = "TEAM_ROCKET_BASE_B3F", eventFlag = 1646, item = 53 },
  { map = "TEAM_ROCKET_BASE_B3F", eventFlag = 1647, item = 38 },
}

-- NPC position/sight repoints: match by map + sprite + x + y (unique per map).
M.objectMoves = {
  { map = "TEAM_ROCKET_BASE_B2F", sprite = "SPRITE_ROCKET", x = 2, y = 1, toX = 4, toY = 1, sight = 1 },
  { map = "TEAM_ROCKET_BASE_B3F", sprite = "SPRITE_ROCKET", x = 5, y = 15, toX = 5, toY = 14 },
  { map = "TEAM_ROCKET_BASE_B3F", sprite = "SPRITE_SCIENTIST", x = 25, y = 12, toX = 23, toY = 11, sight = 0 },
  { map = "TEAM_ROCKET_BASE_B3F", sprite = "SPRITE_SCIENTIST", x = 14, y = 15, toX = 11, toY = 15 },
}

-- Sprite swaps: match by map + sprite + x + y (executive at (8,3)).
M.spriteSwaps = {
  { map = "TEAM_ROCKET_BASE_B3F", sprite = "SPRITE_ROCKET", x = 8, y = 3, to = "SPRITE_ARCHER" },
}

-- Appended objects (CL objects gold does not ship).  UltraBall at (14,10);
-- index 14 = its array position on gold's 13-object B3F (disappear uses
-- def.index), eventFlag 1934 persists "taken" across map reloads.
M.addedObjects = {
  {
    map = "TEAM_ROCKET_BASE_B3F",
    object = {
      eventFlag = 1934,
      hours = { -1, -1 },
      index = 14,
      itemball = { item = 2, quantity = 1 },
      movement = 1,
      palette = 0,
      radius = { x = 0, y = 0 },
      script = 0,
      sight = 0,
      sprite = "SPRITE_POKE_BALL",
      spriteId = 84,
      type = 1,
      x = 14,
      y = 10,
    },
  },
}

return M
