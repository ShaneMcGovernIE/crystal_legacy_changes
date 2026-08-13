-- Phase 3d2: Team Rocket RadioTower 5F rework (CL RadioTower5F.asm port).
--
-- Gold ALREADY ships the full 1F-5F Rocket takeover (fake director giving the
-- BASEMENT_KEY, EXECUTIVEM_2 on 4F, EXECUTIVEF_1 on 5F, the flag cascade).
-- The CL-only deltas this file carries are the 5F boss scene:
--   * the boss battle is ROCKET_LEADER/ARCHER (class 69 member 1, Phase 2 data)
--     instead of EXECUTIVEM_1, and the boss object wears SPRITE_ARCHER;
--   * the GIOVANNI hologram scene (disguise sprite -> reveal -> leaves);
--   * the ARCHER disband sequence (7 speeches, rockets flee);
--   * the takeover flag cascade (gold's 12 flags == CL's set) plus the two
--     mod-invented GIOVANNI flags, then the director walks in (the GENTLEMAN
--     at (3,6) is reused, CL-style) and hands over the RAINBOW_WING.
--
-- NOT ported (Crystal-only, absent from gold): the CLEAR_BELL reward item and
-- EVENT_GOT_CLEAR_BELL (gold's story gives the RAINBOW_WING for Ho-Oh), and
-- setmapscene ECRUTEAK_TIN_TOWER_ENTRANCE SCENE_DEFAULT (gold's Tin Tower
-- entrance is event-gated by 1894/1895, not scene-gated).
--
-- Flag numbers are gold's (tests/drivers/gold/flag_names.lua).  Free mod flags
-- above gold's max (1931) hide the two GIOVANNI objects until the scene.
local M = {}

M.map = "RADIO_TOWER_5F"

-- The boss scene replaces gold's coordEvent scene-1 script (43:67a5).
M.bossSceneKey = "crystal_legacy_changes:radiotower_boss_scene"
M.coordEvent = { sceneId = 1, x = 16, y = 5 }

-- No-op talk script for the two hologram objects (CL's ObjectEvent).
M.objectEventKey = "crystal_legacy_changes:object_event"

-- Gold flags (raw numbers; gold has no named constants table).
M.flags = {
  clearedRadioTower = 33,        -- EVENT_CLEARED_RADIO_TOWER
  engineRocketsInTower = 18,     -- ENGINE_ROCKETS_IN_RADIO_TOWER
  beatExecutivem1 = 1393,        -- EVENT_BEAT_ROCKET_EXECUTIVEM_1
  goldenrodRocketScout = 1740,   -- EVENT_GOLDENROD_CITY_ROCKET_SCOUT
  goldenrodRocketTakeover = 1741,-- EVENT_GOLDENROD_CITY_ROCKET_TAKEOVER
  towerRocketTakeover = 1742,    -- EVENT_RADIO_TOWER_ROCKET_TAKEOVER
  mahoganyMartOwners = 1846,     -- EVENT_MAHOGANY_MART_OWNERS
  engineRocketsInMahogany = 22,  -- ENGINE_ROCKETS_IN_MAHOGANY
  goldenrodCivilians = 1743,     -- EVENT_GOLDENROD_CITY_CIVILIANS
  towerCiviliansAfter = 1744,    -- EVENT_RADIO_TOWER_CIVILIANS_AFTER
  blackthornNerdBlocks = 1763,   -- EVENT_BLACKTHORN_CITY_SUPER_NERD_BLOCKS_GYM
  blackthornNerdClear = 1764,    -- ..._DOES_NOT_BLOCK_GYM
  gotRainbowWing = 120,          -- EVENT_GOT_RAINBOW_WING
  teamRocketDisbanded = 1889,    -- EVENT_TEAM_ROCKET_DISBANDED
  -- Mod-invented (free above gold's 1931): hide GIOVANNI objects at boot.
  giovanniDisguise = 1932,
  giovanniReal = 1933,
}

-- Sprite registrations.  Art from CL_source/gfx/sprites/*.png (16x96 4-shade
-- sheets, verified pixel-identical format to gold's generated sprite cache).
M.sprites = {
  {
    id = "SPRITE_ARCHER",
    image = "assets/sprites/archer.png",
    palette = "PAL_OW_BROWN",
    paletteId = 3,
  },
  {
    id = "SPRITE_GIOVANNI",
    image = "assets/sprites/giovanni.png",
    palette = "PAL_OW_BROWN",
    paletteId = 3,
  },
  {
    id = "SPRITE_GIOVANNI_DISGUISE",
    image = "assets/sprites/giovanni_disguise.png",
    palette = "PAL_OW_BROWN",
    paletteId = 3,
  },
}

-- Movement tables (gold/pokecrystal movement bytes; step_end = 0x47).
--   turn_head: down 0x00 up 0x01 left 0x02 right 0x03
--   slow_step: down 0x08 up 0x09 left 0x0A right 0x0B
--   step:      down 0x0C up 0x0D left 0x0E right 0x0F
M.movements = {
  -- CL RadioTower5FPlayerTwoStepsLeftMovement (player, from (16,5) to (14,5))
  rt_player_steps = { 0x0E, 0x0E, 0x47 },
  -- CL GiovanniEnterenceMovement: slow DOWN x4, slow RIGHT x4, slow DOWN x4
  rt_giovanni_enter = { 0x08, 0x08, 0x08, 0x08, 0x0B, 0x0B, 0x0B, 0x0B, 0x08, 0x08, 0x08, 0x08, 0x47 },
  -- CL LookRightMovement: turn_head RIGHT, UP, DOWN, RIGHT
  rt_look_right = { 0x03, 0x01, 0x00, 0x03, 0x47 },
  -- CL LookDownMovement
  rt_look_down = { 0x00, 0x47 },
  -- CL GiovanniMoveTowerdsExecutive: slow LEFT x3
  rt_giovanni_toward = { 0x0A, 0x0A, 0x0A, 0x47 },
  -- CL GiovanniMoveAway: step RIGHT x3, step UP x2
  rt_giovanni_away = { 0x0F, 0x0F, 0x0F, 0x0D, 0x0D, 0x47 },
  -- CL RADIOTOWER_GiovanniLeavesMovement: step UP x2, LEFT x4, UP x2
  rt_giovanni_leave = { 0x0D, 0x0D, 0x0E, 0x0E, 0x0E, 0x0E, 0x0D, 0x0D, 0x47 },
  -- CL ArcherMovement1: slow DOWN x2, slow RIGHT x2, slow DOWN x1, slow RIGHT x1
  rt_archer_move_1 = { 0x08, 0x08, 0x0B, 0x0B, 0x08, 0x0B, 0x47 },
  -- CL ArcherMovement2: step LEFT, big_step DOWN x2, step RIGHT
  rt_archer_move_2 = { 0x0E, 0x10, 0x10, 0x0F, 0x47 },
  -- CL LookLeftMovement
  rt_look_left = { 0x02, 0x47 },
  -- CL LookUpMovement
  rt_look_up = { 0x01, 0x47 },
  -- CL RadioTower5FRocketGirlLeaveMovement: step UP, LEFT, LEFT
  rt_girl_leave = { 0x0D, 0x0E, 0x0E, 0x47 },
  -- CL ArcherMovement3: step DOWN x2, step RIGHT x2
  rt_archer_move_3 = { 0x0C, 0x0C, 0x0F, 0x0F, 0x47 },
  -- CL ArcherMovement4: step RIGHT, step UP
  rt_archer_move_4 = { 0x0F, 0x0D, 0x47 },
  -- CL RadioTower5FDirectorWalksIn: step DOWN x4 (from (12,0))
  rt_dir_in = { 0x0C, 0x0C, 0x0C, 0x0C, 0x47 },
  -- CL RadioTower5FDirectorWalksOut: step RIGHT, UP x3, LEFT x4, UP x2
  rt_dir_out = { 0x0F, 0x0D, 0x0D, 0x0D, 0x0E, 0x0E, 0x0E, 0x0E, 0x0D, 0x0D, 0x47 },
}

-- CL text rows (plain \n breaks; the TextBox paginates).  {PLAYER} macro.
M.texts = {
  rt_boss_before = [[Oh? You managed to
get this far?
You must be quite
the trainer.
We intend to take
over this RADIO
STATION and an-
nounce our come-
back.
That should bring
our boss GIOVANNI
back from his solo
training.
We are going to
regain our former
glory.
I won't allow you
to interfere with
our plans.]],
  rt_boss_win = [[No! Forgive me,
GIOVANNI!]],
  rt_boss_after = [[How could this be?
TEAM ROCKET was
destined to rise
again...
For GIOVANNI, for
our legacy. We
cannot fall now!
You may have won
this battle,
but the war?
It's far from over.
You'll see.
Our ambition, our
dream will not
fade.
The world will
fear TEAM ROCKET
once again.
This is only
a setback!]],
  rt_giovanni_1 = [[???: Such convic-
tion.
Reminds me of a
time when I, too,
was so sure.]],
  rt_giovanni_2 = [[You speak of
legacy,
of taking
over...
But recall,
ARCHER.
Why did I choose
to disband it?]],
  rt_giovanni_3 = [[GIOVANNI: It wasn't
mere defeat or
whim,
It was an
awakening.
See the state of
this group now.
Desperate acts,
hiding.
A far cry from
where we once
stood.]],
  rt_giovanni_4 = [[Power isn't just
about domination.
It's understanding
and respect.
Is this the legacy
you imagined?
Reduced to
skulking in the
shadows?]],
  rt_giovanni_5 = [[Rethink this path.
Do you truly see a
future for this
TEAM ROCKET?]],
  rt_disband_1 = [[ARCHER: I...
I did this for
you. For the glory
of TEAM ROCKET.
All my efforts,
all these
sacrifices.
And you just...
Was it all in
vain?
Did I
misunderstand
our purpose?]],
  rt_disband_2 = [[You left.
You vanished
without a word.
We were lost.
I tried to carry
your legacy.]],
  rt_disband_3 = [[You were the
leader,
the visionary.
And I...
I'm just...]],
  rt_disband_4 = [[Was I a mere
puppet?
Chasing a dream
you never shared?]],
  rt_disband_5 = [[But... but I can't
just let go. Not
after everything.
Do you expect me
to just walk away,
to abandon our
cause?]],
  rt_disband_6 = [[I... I need time.
I need to get out
of here.]],
  rt_disband_7 = [[But know this,
GIOVANNI. Even if
the path was
wrong...
My intentions were
true!]],
}

-- The 5F boss scene (CL RadioTower5FRocketBossScene, gold object numbering:
--   0 = player, 1 = GENTLEMAN (fake director, reused for the walk-in),
--   2 = ROCKET (boss object, re-sprited to ARCHER), 3 = ROCKET_GIRL,
--   5 = GIOVANNI_DISGUISE hologram object, 6 = real GIOVANNI object).
-- Rows use the named fields Vm.lua's runCmd reads directly.
M.scene = {
  { op = "applymovement", object = 0, movement = "crystal_legacy_changes:rt_player_steps" },
  { op = "playmusic", id = 57 }, -- MUSIC_ROCKET_ENCOUNTER
  { op = "turnobject", object = 2, facing = 3 }, -- Archer faces RIGHT
  { op = "opentext" },
  { op = "writetext", text = "crystal_legacy_changes:rt_boss_before" },
  { op = "waitbutton" },
  { op = "closetext" },
  { op = "winlosstext", winText = "crystal_legacy_changes:rt_boss_win" },
  { op = "setlasttalked", object = 2 },
  { op = "loadtrainer", class = 69, member = 1 }, -- ROCKET_LEADER / ARCHER
  { op = "startbattle" },
  { op = "reloadmapafterbattle" },
  { op = "opentext" },
  { op = "writetext", text = "crystal_legacy_changes:rt_boss_after" },
  { op = "waitbutton" },
  { op = "closetext" },
  -- GIOVANNI hologram (CL :106-162)
  { op = "showemote", emote = 0, object = 3, frames = 15 }, -- shock on ROCKET_GIRL
  { op = "appear", object = 5 },
  { op = "applymovement", object = 5, movement = "crystal_legacy_changes:rt_giovanni_enter" },
  { op = "faceobject", a = 2, b = 5 },
  { op = "showemote", emote = 0, object = 2, frames = 15 },
  { op = "faceobject", a = 0, b = 5 },
  { op = "showemote", emote = 0, object = 0, frames = 15 },
  { op = "opentext" },
  { op = "writetext", text = "crystal_legacy_changes:rt_giovanni_1" },
  { op = "waitbutton" },
  { op = "closetext" },
  { op = "faceobject", a = 5, b = 2 },
  { op = "opentext" },
  { op = "writetext", text = "crystal_legacy_changes:rt_giovanni_2" },
  { op = "waitbutton" },
  { op = "closetext" },
  { op = "applymovement", object = 5, movement = "crystal_legacy_changes:rt_look_right" },
  { op = "pause", frames = 50 },
  { op = "special", id = 47 }, -- FadeBlackQuickly
  { op = "special", id = 50 }, -- ReloadSpritesNoPalettes
  { op = "disappear", object = 5 },
  { op = "appear", object = 6 }, -- hologram revealed as the real GIOVANNI
  { op = "pause", frames = 15 },
  { op = "special", id = 49 }, -- FadeInQuickly
  { op = "pause", frames = 30 },
  { op = "applymovement", object = 6, movement = "crystal_legacy_changes:rt_look_down" },
  { op = "pause", frames = 50 },
  { op = "faceobject", a = 6, b = 2 },
  { op = "opentext" },
  { op = "writetext", text = "crystal_legacy_changes:rt_giovanni_3" },
  { op = "waitbutton" },
  { op = "closetext" },
  { op = "applymovement", object = 6, movement = "crystal_legacy_changes:rt_giovanni_toward" },
  { op = "faceobject", a = 2, b = 6 },
  { op = "faceobject", a = 0, b = 6 },
  { op = "opentext" },
  { op = "writetext", text = "crystal_legacy_changes:rt_giovanni_4" },
  { op = "waitbutton" },
  { op = "closetext" },
  { op = "applymovement", object = 6, movement = "crystal_legacy_changes:rt_look_down" },
  { op = "pause", frames = 50 },
  { op = "applymovement", object = 6, movement = "crystal_legacy_changes:rt_giovanni_away" },
  { op = "faceobject", a = 2, b = 6 },
  { op = "faceobject", a = 0, b = 6 },
  { op = "opentext" },
  { op = "writetext", text = "crystal_legacy_changes:rt_giovanni_5" },
  { op = "waitbutton" },
  { op = "closetext" },
  { op = "applymovement", object = 6, movement = "crystal_legacy_changes:rt_giovanni_leave" },
  { op = "disappear", object = 6 },
  -- ARCHER disband (CL :164-237)
  { op = "faceobject", a = 2, b = 0 },
  { op = "opentext" },
  { op = "writetext", text = "crystal_legacy_changes:rt_disband_1" },
  { op = "waitbutton" },
  { op = "closetext" },
  { op = "applymovement", object = 2, movement = "crystal_legacy_changes:rt_archer_move_1" },
  { op = "faceobject", a = 2, b = 5 }, -- faces where GIOVANNI stood
  { op = "opentext" },
  { op = "writetext", text = "crystal_legacy_changes:rt_disband_2" },
  { op = "waitbutton" },
  { op = "closetext" },
  { op = "applymovement", object = 2, movement = "crystal_legacy_changes:rt_archer_move_2" },
  { op = "opentext" },
  { op = "writetext", text = "crystal_legacy_changes:rt_disband_3" },
  { op = "waitbutton" },
  { op = "closetext" },
  { op = "applymovement", object = 2, movement = "crystal_legacy_changes:rt_look_left" },
  { op = "opentext" },
  { op = "writetext", text = "crystal_legacy_changes:rt_disband_4" },
  { op = "waitbutton" },
  { op = "closetext" },
  { op = "applymovement", object = 2, movement = "crystal_legacy_changes:rt_look_up" },
  { op = "applymovement", object = 3, movement = "crystal_legacy_changes:rt_girl_leave" },
  { op = "opentext" },
  { op = "writetext", text = "crystal_legacy_changes:rt_disband_5" },
  { op = "waitbutton" },
  { op = "closetext" },
  { op = "applymovement", object = 2, movement = "crystal_legacy_changes:rt_archer_move_3" },
  { op = "opentext" },
  { op = "writetext", text = "crystal_legacy_changes:rt_disband_6" },
  { op = "waitbutton" },
  { op = "closetext" },
  { op = "applymovement", object = 2, movement = "crystal_legacy_changes:rt_look_down" },
  { op = "opentext" },
  { op = "writetext", text = "crystal_legacy_changes:rt_disband_7" },
  { op = "waitbutton" },
  { op = "closetext" },
  { op = "applymovement", object = 2, movement = "crystal_legacy_changes:rt_archer_move_4" },
  { op = "special", id = 47 }, -- FadeBlackQuickly
  { op = "special", id = 50 }, -- ReloadSpritesNoPalettes
  { op = "disappear", object = 2 },
  { op = "disappear", object = 3 },
  { op = "pause", frames = 15 },
  { op = "special", id = 49 }, -- FadeInQuickly
  -- Flag cascade: gold's 12 (== CL's set) + the two GIOVANNI flags + music
  { op = "setevent", event = 1393 },
  { op = "setevent", event = 33 },
  { op = "clearflag", flag = 18 },
  { op = "setevent", event = 1740 },
  { op = "setevent", event = 1741 },
  { op = "setevent", event = 1742 },
  { op = "clearevent", event = 1846 },
  { op = "clearflag", flag = 22 },
  { op = "clearevent", event = 1743 },
  { op = "clearevent", event = 1744 },
  { op = "setevent", event = 1763 },
  { op = "clearevent", event = 1764 },
  { op = "setevent", event = 1932 },
  { op = "setevent", event = 1933 },
  { op = "special", id = 59 }, -- PlayMapMusic
  -- Director: the GENTLEMAN (object 1) is revealed as the real director and
  -- walks in from (12,0); gold's RAINBOW_WING reward + flags (CL gives the
  -- CLEAR_BELL, which does not exist in gold).
  { op = "disappear", object = 1 },
  { op = "moveobject", object = 1, x = 12, y = 0 },
  { op = "appear", object = 1 },
  { op = "applymovement", object = 1, movement = "crystal_legacy_changes:rt_dir_in" },
  { op = "turnobject", object = 0, facing = 3 }, -- player faces RIGHT
  { op = "opentext" },
  { op = "writetext", text = "43:6d04" }, -- gold's DIRECTOR thank-you
  { op = "waitbutton" },
  { op = "closetext" },
  { op = "verbosegiveitem", item = 178, quantity = 1 }, -- RAINBOW_WING
  { op = "writetext", text = "43:6d7e" }, -- gold's after-give (Ho-Oh lore)
  { op = "waitbutton" },
  { op = "closetext" },
  { op = "setscene", scene = 2 },
  { op = "setevent", event = 120 }, -- EVENT_GOT_RAINBOW_WING
  { op = "setevent", event = 1889 }, -- EVENT_TEAM_ROCKET_DISBANDED
  { op = "applymovement", object = 1, movement = "crystal_legacy_changes:rt_dir_out" },
  { op = "playsound", id = 35 }, -- SFX_EXIT_BUILDING
  { op = "disappear", object = 1 },
  { op = "setscene", scene = 2 },
  { op = "end" },
}

-- Giovanni hologram objects (appended to the 5F map def; flags 1932/1933 are
-- set at mods.loaded so both stay hidden until the scene appears them).
-- movement 8 = SPRITEMOVEDATA_STANDING_LEFT (CL uses STANDING_LEFT).
local function giovanniObject(index, sprite, flag)
  return {
    eventFlag = flag,
    hours = { -1, -1 },
    index = index,
    movement = 8,
    palette = 0,
    radius = { x = 0, y = 0 },
    script = 0,
    scriptKey = M.objectEventKey,
    sight = 0,
    sprite = sprite,
    spriteId = 0,
    type = 0,
    x = 12,
    y = 0,
  }
end

M.objects = {
  giovanniObject(5, "SPRITE_GIOVANNI_DISGUISE", M.flags.giovanniDisguise),
  giovanniObject(6, "SPRITE_GIOVANNI", M.flags.giovanniReal),
}

return M
