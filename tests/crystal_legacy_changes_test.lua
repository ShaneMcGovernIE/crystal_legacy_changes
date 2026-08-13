-- Gold-only content test. Run from a Gold-support engine checkout with:
-- luajit mods/crystal_legacy_changes/tests/crystal_legacy_changes_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local data = T.fixtures.fresh()

data.pokemon.growthRates = data.pokemon.growthRates or {}
data.pokemon.growthRates.GROWTH_MEDIUM_FAST = {
  numerator = 1, denominator = 1,
}

data.pokemon.EKANS = {
  id = "EKANS", name = "EKANS", dex = 23, index = 23,
  types = { "POISON", "POISON" },
  baseStats = {
    hp = 35, attack = 60, defense = 44, speed = 55,
    specialAttack = 40, specialDefense = 54,
  },
  catchRate = 255, baseExp = 58, growthRate = "GROWTH_MEDIUM_FAST",
  levelMoves = {}, evolutions = {}, picSize = 5,
  spriteFront = "ekans.png", spriteBack = "ekans_back.png",
}
data.pokemon.PIKACHU = {
  id = "PIKACHU", name = "PIKACHU", dex = 25, index = 25,
  types = { "ELECTRIC", "ELECTRIC" },
  baseStats = {
    hp = 35, attack = 55, defense = 40, speed = 90,
    specialAttack = 50, specialDefense = 50,
  },
  catchRate = 190, baseExp = 82, growthRate = "GROWTH_MEDIUM_FAST",
  levelMoves = {}, evolutions = {}, picSize = 5,
  spriteFront = "pikachu.png", spriteBack = "pikachu_back.png",
}

-- The shared fixture is Gen 1-shaped. Remove its display-name alias so the
-- resolver uses the Gold-shaped CUT row below rather than FIX_CUT.
data.moves.FIX_CUT = nil

local function seedMove(id, name, type, effect)
  data.moves[id] = {
    id = id, name = name, type = type, power = 50, accuracy = 95,
    pp = 15, effect = effect or "EFFECT_NORMAL_HIT",
  }
end

seedMove("WATERFALL", "WATERFALL", "WATER")
seedMove("EGG_BOMB", "EGG BOMB", "NORMAL")
seedMove("CUT", "CUT", "NORMAL")
seedMove("ROCK_SMASH", "ROCK SMASH", "FIGHTING")
seedMove("IRON_TAIL", "IRON TAIL", "STEEL")
seedMove("SKY_ATTACK", "SKY ATTACK", "FLYING", "EFFECT_SKY_ATTACK")
seedMove("TRIPLE_KICK", "TRIPLE KICK", "FIGHTING", "EFFECT_TRIPLE_KICK")

-- Seed every move referenced by the external learnset table so the fixture
-- exercises the real cross-reference pass rather than failing on absent ROM
-- records. The Gold cache supplies these records in an imported run.
local learnsetData = dofile("mods/crystal_legacy_changes/learnsets.lua").learnsets
for _, levelMoves in pairs(learnsetData) do
  for _, entry in ipairs(levelMoves) do
    if not data.moves[entry.move] then
      seedMove(entry.move, entry.move, "NORMAL")
    end
  end
end
local tmhmData = dofile("mods/crystal_legacy_changes/tmhm.lua").tmhm
for _, tmhm in pairs(tmhmData) do
  for _, move in ipairs(tmhm) do
    if not data.moves[move] then
      seedMove(move, move, "NORMAL")
    end
  end
end

-- The converted encounters/trainers tables reference real Gold ids the
-- fixture does not carry.  Collect every species/move/item/music id they
-- reference and stand in minimal records so the post-merge cross-reference
-- pass can resolve them (an imported run supplies the real cache records).
-- Species are omitted: the rebalance registers all 251 learnset ids, so
-- every encounter/trainer species already resolves.
local encountersData = dofile("mods/crystal_legacy_changes/data/encounters.lua")
local trainersData = dofile("mods/crystal_legacy_changes/data/trainers.lua")
local martsData = dofile("mods/crystal_legacy_changes/data/marts.lua")
local evolutionsData = dofile("mods/crystal_legacy_changes/data/evolutions.lua")

local species, moves, items, music = {}, {}, {}, {}
local function collectRefs(root, map)
  if type(root) ~= "table" then return end
  for key, value in pairs(root) do
    local out = map[key]
    if out and type(value) == "string" then
      out[value] = true
    elseif type(value) == "table" then
      if out then
        for _, id in ipairs(value) do
          if type(id) == "string" then out[id] = true end
        end
      else
        collectRefs(value, map)
      end
    end
  end
end
collectRefs(encountersData, { species = species })
collectRefs(trainersData, {
  species = species, moves = moves,
  item = items, items = items,
  encounterMusic = music,
})
-- Mart shelves are plain item-id arrays under each MART_* key.
for _, shelf in pairs(martsData.marts or {}) do
  for _, id in ipairs(shelf) do
    items[id] = true
  end
end
-- Evolution rows carry an `item` field for the EVOLVE_ITEM method
-- (METAL_COAT/UP_GRADE/KINGS_ROCK/WATER_STONE/DRAGON_SCALE/BRICK_PIECE);
-- only METAL_COAT, UP_GRADE and BRICK_PIECE also appear on the Mahogany
-- shelf, so the other three have to be collected from the rows directly.
for _, rows in pairs(evolutionsData.evolutions or {}) do
  for _, row in ipairs(rows) do
    if type(row.item) == "string" then items[row.item] = true end
  end
end

-- The fixture has no audio namespace at all; the music registry backs
-- trainer encounter music.
data.audio = data.audio or { songs = {} }
for id in pairs(music) do
  data.audio.songs[id] = { id = id, name = id, index = 1 }
end
for id in pairs(items) do
  if not data.items[id] then
    data.items[id] = { id = id, name = id, index = 1 }
  end
end
for id in pairs(moves) do
  if not data.moves[id] then
    seedMove(id, id, "NORMAL")
  end
end

data.type_chart = data.type_chart or { types = {}, matchups = {} }
data.type_chart.types = data.type_chart.types or {}
data.type_chart.types.GHOST = {
  id = "GHOST", name = "GHOST", index = 8, category = "physical",
}
data.type_chart.types.DARK = {
  id = "DARK", name = "DARK", index = 27, category = "special",
}
data.type_chart.types.STEEL = {
  id = "STEEL", name = "STEEL", index = 9, category = "physical",
}

-- Gold's fixture has no extracted effect namespace. These records stand in
-- for the imported Gold cache's effect ids during the ROM-free load.
data.gen2MoveEffects = data.gen2MoveEffects or {}
for _, id in ipairs({
  "EFFECT_NORMAL_HIT", "EFFECT_SKY_ATTACK", "EFFECT_TRIPLE_KICK",
  "EFFECT_FLINCH_HIT", "EFFECT_DEFENSE_DOWN_HIT",
}) do
  data.gen2MoveEffects[id] = { kind = "full" }
end

-- The shared fixture's encounters base carries NO swarm rows (the Gen 2
-- encounters registry's base path is data.gen2Encounters, which the fixture
-- leaves empty), so the swarm assertions below would pass even if the loader
-- deep-merged instead of overriding.  Seed Gold's removed swarm rows (Route
-- 38 + Mount Mortar land swarms, Mount Mortar surf swarm) into the base so
-- the override seam is pinned: with a deep-merge patch these rows would
-- survive the load; with override they must be gone.
local function seedSwarmRows()
  local function swarmRow()
    return {
      { level = 16, species = "FIXMON_A" },
      { level = 16, species = "FIXMON_A" },
      { level = 16, species = "FIXMON_A" },
      { level = 16, species = "FIXMON_A" },
      { level = 13, species = "FIXMON_B" },
      { level = 13, species = "FIXMON_B" },
      { level = 13, species = "FIXMON_B" },
    }
  end
  data.gen2Encounters = {
    swarmGrass = {
      ROUTE_38 = {
        map = "ROUTE_38",
        rates = { MORN = 25, DAY = 25, NITE = 25 },
        slots = { MORN = swarmRow(), DAY = swarmRow(), NITE = swarmRow() },
      },
      MOUNT_MORTAR_1F_OUTSIDE = {
        map = "MOUNT_MORTAR_1F_OUTSIDE",
        rates = { MORN = 15, DAY = 15, NITE = 15 },
        slots = { MORN = swarmRow(), DAY = swarmRow(), NITE = swarmRow() },
      },
    },
    swarmWater = {
      MOUNT_MORTAR_1F_OUTSIDE = {
        map = "MOUNT_MORTAR_1F_OUTSIDE",
        rate = 10,
        slots = {
          { level = 20, species = "FIXMON_A" },
          { level = 20, species = "FIXMON_A" },
          { level = 20, species = "FIXMON_A" },
        },
      },
    },
  }
end
seedSwarmRows()

-- The mart patch rides the mods.loaded event and swaps the 34 gold
-- positional shelves in place, preserving bargain.  Seed a gold-shaped base
-- with junk shelves so a no-op or deep-merge patch would visibly fail: the
-- CL shelves must land on the exact gold indices and the junk must vanish.
local function seedGoldMarts()
  local lists = {}
  for i = 1, 34 do
    lists[i] = { "SEEDED_JUNK_" .. i }
  end
  data.gen2Marts = {
    bargain = { { item = "POTION", price = 300 } },
    lists = lists,
  }
end
seedGoldMarts()

-- The berry-shop step appends CL's clerk to the Flower Shop map def (maps
-- registry is Gen 2-active) and the two berry shelves at the first free mart
-- ids (34/35 -> lists[35]/[36]).  Seed a gold-shaped shop with only the two
-- vanilla objects (TEACHER + LASS, no clerk) so a no-op patch would leave it
-- clerk-less and the shelves missing.
local function seedGoldFlowerShop()
  data.gen2Maps = data.gen2Maps or {}
  data.gen2Maps.GOLDENROD_FLOWER_SHOP = {
    id = "GOLDENROD_FLOWER_SHOP",
    name = "GOLDENROD FLOWER SHOP",
    width = 4,
    height = 4,
    objects = {
      {
        eventFlag = 65535,
        hours = { -1, -1 },
        index = 1,
        movement = 9,
        palette = 0,
        radius = { x = 0, y = 0 },
        script = 21201,
        scriptKey = "57:52d1",
        sight = 0,
        sprite = "SPRITE_TEACHER",
        spriteId = 41,
        type = 0,
        x = 2,
        y = 4,
      },
      {
        eventFlag = 65535,
        hours = { -1, -1 },
        index = 2,
        movement = 2,
        palette = 10,
        radius = { x = 1, y = 1 },
        script = 21204,
        scriptKey = "57:52f4",
        sight = 0,
        sprite = "SPRITE_LASS",
        spriteId = 40,
        type = 0,
        x = 5,
        y = 6,
      },
    },
  }
end
seedGoldFlowerShop()

-- The move-tutor step appends the CL tutor object to gold's GoldenrodCity map
-- def (in place, like the berry clerk).  Seed a gold-shaped city with only 3
-- stub objects so a no-op patch would leave it tutor-less: after the load the
-- objects list must have 4 entries with the tutor last.
local function seedGoldenrodCity()
  data.gen2Maps = data.gen2Maps or {}
  data.gen2Maps.GOLDENROD_CITY = {
    id = "GOLDENROD_CITY",
    name = "GOLDENROD CITY",
    width = 18,
    height = 18,
    objects = {
      {
        eventFlag = 65535,
        hours = { -1, -1 },
        index = 1,
        movement = 6,
        palette = 0,
        radius = { x = 0, y = 0 },
        script = 1,
        scriptKey = "1:1",
        sight = 0,
        sprite = "SPRITE_POKEFAN_M",
        spriteId = 45,
        type = 0,
        x = 5,
        y = 5,
      },
      {
        eventFlag = 65535,
        hours = { -1, -1 },
        index = 2,
        movement = 6,
        palette = 0,
        radius = { x = 0, y = 0 },
        script = 2,
        scriptKey = "2:2",
        sight = 0,
        sprite = "SPRITE_LASS",
        spriteId = 40,
        type = 0,
        x = 8,
        y = 8,
      },
      {
        eventFlag = 65535,
        hours = { -1, -1 },
        index = 3,
        movement = 6,
        palette = 0,
        radius = { x = 0, y = 0 },
        script = 3,
        scriptKey = "3:3",
        sight = 0,
        sprite = "SPRITE_YOUNGSTER",
        spriteId = 42,
        type = 0,
        x = 10,
        y = 12,
      },
    },
  }
end
seedGoldenrodCity()

-- The evolutions patch swaps each species' whole `evolutions` list (record
-- semantics: patch replaces arrays wholesale, it does not append).  Seed
-- gold-style rows on base species so a deep-merge patch would visibly keep
-- the junk: after the load the CL rows must be the ONLY rows left.
local function seedGoldEvolutions()
  local goldRows = {
    GOLDEEN = { { into = "SEAKING", level = 33, method = "EVOLVE_LEVEL" } },
    ONIX = {
      { into = "STEELIX", item = "METAL_COAT", method = "EVOLVE_TRADE" },
    },
    KADABRA = {
      { into = "ALAKAZAM", method = "EVOLVE_TRADE" },
    },
    TYROGUE = {
      { into = "HITMONTOP", level = 20, comparison = "ATK_EQ_DEF", method = "EVOLVE_STAT" },
      { into = "HITMONCHAN", level = 20, comparison = "ATK_LT_DEF", method = "EVOLVE_STAT" },
      { into = "HITMONLEE", level = 20, comparison = "ATK_GT_DEF", method = "EVOLVE_STAT" },
    },
    PORYGON = {
      { into = "PORYGON2", item = "UP_GRADE", method = "EVOLVE_TRADE" },
    },
    SLOWPOKE = {
      { into = "SLOWBRO", level = 37, method = "EVOLVE_LEVEL" },
      { into = "SLOWKING", item = "KINGS_ROCK", method = "EVOLVE_TRADE" },
    },
  }
  data.pokemon = data.pokemon or {}
  for species, rows in pairs(goldRows) do
    data.pokemon[species] = data.pokemon[species] or {}
    data.pokemon[species].evolutions = rows
  end
end
seedGoldEvolutions()

-- Phase 3 game-corner step: the prize menu is not a data table -- the strings
-- are inline on gold's loadmenu script rows and each prize arm is its own
-- script row with the price little-endian ({lo, hi}) on checkcoins/takecoins
-- and the species/level on givepoke.  The mod patches those rows in place on
-- mods.loaded (same seam as marts).  Seed gold-shaped rows with junk so a
-- no-op patch would leave the gold ABRA 200 L10 / EKANS 700 L10 / DRATINI
-- 2100 L10 arms and menu strings intact.
local function seedGoldGameCorner()
  local function arm(checkArgs, takeArgs, species, level)
    return {
      { op = "checkcoins", args = checkArgs },
      { op = "ifequal", value = 2, script = "57:6830" },
      { op = "readvar", variable = 1 },
      { op = "ifequal", value = 6, script = "57:6836" },
      { op = "getmonname", buffer = 0, species = species },
      { op = "scall", script = "57:6820" },
      { op = "iffalse", script = "57:683c" },
      { op = "waitsfx" },
      { op = "playsound", id = 34 },
      { op = "writetext", text = "57:6b22" },
      { op = "waitbutton" },
      { op = "setval", args = { species } },
      { op = "special", id = 56 },
      { op = "givepoke", species = species, level = level },
      { op = "takecoins", args = takeArgs },
      { op = "sjump", script = "57:688f" },
    }
  end
  local goldMenuItems = {
    "ABRA        200",
    "EKANS       700",
    "DRATINI    2100",
    "CANCEL",
  }
  data.gen2Scripts = data.gen2Scripts or {}
  -- "57:688f" is the post-prize re-entry copy of the menu.
  for _, key in ipairs({ "57:6880", "57:688f" }) do
    data.gen2Scripts[key] = {
      { op = "writetext", text = "57:6a97" },
      { op = "loadmenu", menu = { items = goldMenuItems } },
      { op = "verticalmenu" },
      { op = "ifequal", value = 1, script = "57:68a9" },
      { op = "ifequal", value = 2, script = "57:68d7" },
      { op = "ifequal", value = 3, script = "57:6905" },
      { op = "sjump", script = "57:683c" },
    }
  end
  -- Gold arms: ABRA 200 L10 / EKANS 700 L10 / DRATINI 2100 L10.
  data.gen2Scripts["57:68a9"] = arm({ 200, 0 }, { 200, 0 }, 63, 10)
  data.gen2Scripts["57:68d7"] = arm({ 188, 2 }, { 188, 2 }, 23, 10)
  data.gen2Scripts["57:6905"] = arm({ 52, 8 }, { 52, 8 }, 147, 10)
end
seedGoldGameCorner()

-- Phase 3b Mew: the gold Celadon Mansion 3F Game Freak designer already runs
-- the dex-completion chain (readvar VAR_DEXCAUGHT > 248 -> diploma branch);
-- CL splices a Route 24 Mew release into the diploma branch.  Seed gold-shaped
-- rows so a no-op patch would leave the vanilla chain with no Mew release.
local function seedGoldMewChain()
  data.gen2Scripts = data.gen2Scripts or {}
  -- Designer gate: vanilla gold (reads VAR_DEXCAUGHT, diplomas at 249 caught).
  data.gen2Scripts["5e:4c8c"] = {
    { op = "faceplayer" },
    { op = "opentext" },
    { op = "writetext", text = "5e:4cea" },
    { op = "readvar", var = 5 },
    { op = "ifgreater", value = 248, script = "5e:4c9a" },
    { op = "waitbutton" },
    { op = "closetext" },
    { op = "end" },
  }
  -- Diploma branch: vanilla gold (fanfare, Diploma special, print-flag, end).
  data.gen2Scripts["5e:4c9a"] = {
    { op = "promptbutton" },
    { op = "writetext", text = "5e:4d41" },
    { op = "playsound", id = 163 },
    { op = "waitsfx" },
    { op = "writetext", text = "5e:4d7c" },
    { op = "promptbutton" },
    { op = "special", id = 106 },
    { op = "writetext", text = "5e:4d7f" },
    { op = "waitbutton" },
    { op = "closetext" },
    { op = "setevent", event = 214 },
    { op = "end" },
  }
  -- Gold ROUTE_24 with its 6 vanilla objects, so the Mew object must land as
  -- #7 (index 7) when the mod appends it.
  data.gen2Maps = data.gen2Maps or {}
  data.gen2Maps.ROUTE_24 = {
    id = "ROUTE_24",
    objects = {},
  }
  for i, def in ipairs({
    { sprite = "SPRITE_COOLTRAINER_M", x = 15, y = 23 },
    { sprite = "SPRITE_SUPER_NERD", x = 23, y = 15 },
    { sprite = "SPRITE_SLOWPOKE", x = 20, y = 24 },
    { sprite = "SPRITE_COOLTRAINER_F", x = 21, y = 24 },
    { sprite = "SPRITE_FISHER", x = 30, y = 26 },
    { sprite = "SPRITE_YOUNGSTER", x = 6, y = 12 },
  }) do
    data.gen2Maps.ROUTE_24.objects[i] = {
      eventFlag = 65535, index = i, sprite = def.sprite,
      script = 0, scriptKey = "45:4db9", x = def.x, y = def.y,
    }
  end
end
seedGoldMewChain()

-- Phase 3a fossils + Ruins of Alph: the gold ROM ships no fossil items and
-- no revival flow (the Research Center scientists are flavor text only), so
-- the mod registers the three inert fossil items, replaces the top-right
-- scientist's script row with a revival command run, and patches the three
-- chamber puzzles' solved sequences + MAPCALLBACK_TILES scripts with the
-- reward / deferred-claim arms.  Seed gold-shaped rows so a no-op patch
-- would leave the vanilla text-only scientist and unrewarded solves.
local function seedGoldFossils()
  data.gen2Scripts = data.gen2Scripts or {}
  -- Top-right Research Center scientist (vanilla: flavor text only).
  data.gen2Scripts["44:4ac6"] = {
    { op = "faceplayer" },
    { op = "opentext" },
    { op = "writetext", text = "44:4d71" },
    { op = "waitbutton" },
    { op = "closetext" },
    { op = "end" },
  }
  -- Chamber solved sequences: solve commits the events, no reward.
  data.gen2Scripts["44:44ea"] = {
    { op = "setevent", event = 1797 },
    { op = "setevent", event = 673 },
    { op = "setflag", flag = 42 },
    { op = "setevent", event = 1870 },
    { op = "setmapscene", args = { 27, 1 } },
    { op = "end" },
  }
  data.gen2Scripts["44:4692"] = {
    { op = "setevent", event = 1797 },
    { op = "setevent", event = 674 },
    { op = "setflag", flag = 43 },
    { op = "setmapscene", args = { 27, 1 } },
    { op = "end" },
  }
  data.gen2Scripts["44:476c"] = {
    { op = "setevent", event = 1797 },
    { op = "setevent", event = 675 },
    { op = "setflag", flag = 44 },
    { op = "setmapscene", args = { 27, 1 } },
    { op = "end" },
  }
  -- Chamber MAPCALLBACK_TILES: vanilla guard only.
  data.gen2Scripts["44:44ce"] = {
    { op = "checkevent", event = 673 },
    { op = "iffalse", script = "44:44d6" },
    { op = "endcallback" },
  }
  data.gen2Scripts["44:4676"] = {
    { op = "checkevent", event = 674 },
    { op = "iffalse", script = "44:467d" },
    { op = "endcallback" },
  }
  data.gen2Scripts["44:4750"] = {
    { op = "checkevent", event = 675 },
    { op = "iffalse", script = "44:4757" },
    { op = "endcallback" },
  }
end
seedGoldFossils()

-- Phase 3c Kanto legendary birds: CL releases each bird as a one-time L60
-- wild encounter after its quest moment (Blaine -> Moltres, Blue ->
-- Articuno, Machine Part returned to the Power Plant manager -> Zapdos);
-- gold has none of it.  Seed gold-shaped rows so a no-op patch would leave
-- the vanilla scripts release-free and the bird flags unseeded.
local function seedGoldBirds()
  data.gen2Scripts = data.gen2Scripts or {}
  -- Blaine win path (Seafoam Gym): reloadmapafterbattle -> badge setevent.
  data.gen2Scripts["53:5188"] = {
    { op = "reloadmapafterbattle" },
    { op = "setevent", event = 1227 },
    { op = "opentext" },
    { op = "writetext", text = "53:52fb" },
    { op = "setflag", flag = 40 },
    { op = "end" },
  }
  -- Blue (Viridian Gym): reloadmapafterbattle -> badge setevent.
  data.gen2Scripts["5f:4002"] = {
    { op = "faceplayer" },
    { op = "opentext" },
    { op = "winlosstext" },
    { op = "loadtrainer", class = 64, member = 1 },
    { op = "startbattle" },
    { op = "reloadmapafterbattle" },
    { op = "setevent", event = 1228 },
    { op = "setflag", flag = 41 },
    { op = "end" },
  }
  -- Power Plant manager, Machine Part returned branch: RESTORED_POWER
  -- setevent is the anchor; the vanilla branch hands out TM07 after it.
  data.gen2Scripts["54:4deb"] = {
    { op = "writetext", text = "54:52bf" },
    { op = "promptbutton" },
    { op = "takeitem", item = 128 },
    { op = "setevent", event = 201 },
    { op = "clearevent", event = 1906 },
    { op = "setevent", event = 1905 },
    { op = "setevent", event = 1900 },   -- EVENT_RESTORED_POWER_TO_KANTO
    { op = "setevent", event = 205 },
    { op = "clearevent", event = 1865 },
    { op = "end" },
  }
  -- New-game seeding target: gold's initial-event flag list.
  data.gen2InitialEvents = data.gen2InitialEvents or {}
  data.gen2InitialEvents.flags = data.gen2InitialEvents.flags or {}
  -- Gold VICTORY_ROAD with its 6 vanilla objects, so the Moltres object must
  -- land as #7 (index 7) when the mod appends it.
  data.gen2Maps = data.gen2Maps or {}
  data.gen2Maps.VICTORY_ROAD = {
    id = "VICTORY_ROAD",
    objects = {},
  }
  for i = 1, 6 do
    data.gen2Maps.VICTORY_ROAD.objects[i] = {
      eventFlag = 65535, index = i, sprite = "SPRITE_TEAL",
      script = 0, scriptKey = "54:4d4d", x = i, y = i,
    }
  end
  -- Gold ROUTE_20 with its 3 vanilla objects, so the Articuno object must
  -- land as #4 (index 4).
  data.gen2Maps.ROUTE_20 = {
    id = "ROUTE_20",
    objects = {},
  }
  for i, def in ipairs({
    { sprite = "SPRITE_SWIMMER_F", x = 9, y = 6 },
    { sprite = "SPRITE_SWIMMER_F", x = 25, y = 20 },
    { sprite = "SPRITE_SWIMMER_M", x = 28, y = 29 },
  }) do
    data.gen2Maps.ROUTE_20.objects[i] = {
      eventFlag = 65535, index = i, sprite = def.sprite,
      script = 0, scriptKey = "54:4d4d", x = def.x, y = def.y,
    }
  end
  -- Gold ROUTE_10_NORTH with its 6 vanilla objects, so the Zapdos object must
  -- land as #7 (index 7).
  data.gen2Maps.ROUTE_10_NORTH = {
    id = "ROUTE_10_NORTH",
    objects = {},
  }
  for i, def in ipairs({
    { sprite = "SPRITE_RECEPTIONIST", x = 9, y = 14 },
    { sprite = "SPRITE_LASS", x = 6, y = 22 },
    { sprite = "SPRITE_YOUNGSTER", x = 17, y = 23 },
    { sprite = "SPRITE_LASS", x = 24, y = 17 },
    { sprite = "SPRITE_YOUNGSTER", x = 30, y = 25 },
    { sprite = "SPRITE_COOLTRAINER_F", x = 13, y = 9 },
  }) do
    data.gen2Maps.ROUTE_10_NORTH.objects[i] = {
      eventFlag = 65535, index = i, sprite = def.sprite,
      script = 0, scriptKey = "54:4d4d", x = def.x, y = def.y,
    }
  end
end
seedGoldBirds()

-- Phase 3c Celebi / GS Ball chain: gold ships NONE of it — no GS_BALL item
-- (items.lua max index is 250), no Ilex shrine event (the (8,22) shrine
-- bg_event is a plain text row), a vanilla apricorn-only Kurt, and a
-- flavor-only Inner Chamber.  Seed gold-shaped rows so a no-op patch would
-- leave the whole chain absent: no item at 251, no receptionist, no Kurt
-- branch, no shrine repoint, no fallback researcher.
local function seedGoldCelebi()
  data.gen2Scripts = data.gen2Scripts or {}
  -- Kurt (KurtsHouse): vanilla apricorn quest — faceplayer/opentext/...; the
  -- mod splices two branch rows right after the opentext.
  data.gen2Scripts["55:45e3"] = {
    { op = "faceplayer" },
    { op = "opentext" },
    { op = "writetext", text = "55:4d36" },
    { op = "yesorno" },
    { op = "closetext" },
    { op = "end" },
  }
  -- Goldenrod Pokecenter 1F: gold's 4 vanilla objects (NURSE, GAMEBOY_KID,
  -- FISHER, TWIN), so the LINK_RECEPTIONIST must land as object #5.
  data.gen2Maps = data.gen2Maps or {}
  data.gen2Maps.GOLDENROD_POKECENTER_1F = {
    id = "GOLDENROD_POKECENTER_1F",
    objects = {},
  }
  for i, def in ipairs({
    { sprite = "SPRITE_NURSE", x = 3, y = 1 },
    { sprite = "SPRITE_GAMEBOY_KID", x = 7, y = 2 },
    { sprite = "SPRITE_FISHER", x = 8, y = 6 },
    { sprite = "SPRITE_TWIN", x = 0, y = 5 },
  }) do
    data.gen2Maps.GOLDENROD_POKECENTER_1F.objects[i] = {
      eventFlag = 65535, index = i, sprite = def.sprite,
      script = 0, scriptKey = "55:46c2", x = def.x, y = def.y,
    }
  end
  -- Ilex Forest: the (8,22) shrine bg_event is vanilla plain text (the mod
  -- repoints it to the shrine script).
  data.gen2Maps.ILEX_FOREST = {
    id = "ILEX_FOREST",
    bgEvents = {
      { scriptKey = "45:6989", x = 8, y = 22, kind = 0 },
    },
  }
  -- Ruins of Alph Inner Chamber: gold's 3 flavor NPCs (FISHER, TEACHER,
  -- GRAMPS), so the RESEARCHER must land as object #4.
  data.gen2Maps.RUINS_OF_ALPH_INNER_CHAMBER = {
    id = "RUINS_OF_ALPH_INNER_CHAMBER",
    objects = {},
  }
  for i, def in ipairs({
    { sprite = "SPRITE_FISHER", x = 4, y = 6 },
    { sprite = "SPRITE_TEACHER", x = 9, y = 12 },
    { sprite = "SPRITE_GRAMPS", x = 14, y = 9 },
  }) do
    data.gen2Maps.RUINS_OF_ALPH_INNER_CHAMBER.objects[i] = {
      eventFlag = 65535, index = i, sprite = def.sprite,
      script = 0, scriptKey = "44:44ce", x = def.x, y = def.y,
    }
  end
end
seedGoldCelebi()

-- Radio Tower 5F: gold's shipped takeover objects (GENTLEMAN fake director,
-- ROCKET boss, ROCKET_GIRL trainer, ROCKER director), the scene-0 fake
-- director coordEvent and the scene-1 boss coordEvent.  The mod's
-- applyRocketTower appends the two GIOVANNI hologram objects, re-sprites the
-- boss to SPRITE_ARCHER and repoints the scene-1 coordEvent.
local function seedGoldRadioTower()
  data.gen2Maps.RADIO_TOWER_5F = {
    id = "RADIO_TOWER_5F",
    width = 18,
    height = 9,
    objects = {
      {
        eventFlag = 65535, hours = { -1, -1 }, index = 1, movement = 1,
        palette = 0, radius = { x = 0, y = 0 }, script = 26471,
        scriptKey = "43:677d", sight = 0, sprite = "SPRITE_GENTLEMAN",
        spriteId = 46, type = 0, x = 3, y = 6,
      },
      {
        eventFlag = 1742, hours = { -1, -1 }, index = 2, movement = 8,
        palette = 0, radius = { x = 0, y = 0 }, script = 10258,
        scriptKey = "00:2812", sight = 0, sprite = "SPRITE_ROCKET",
        spriteId = 53, type = 0, x = 13, y = 5,
      },
      {
        eventFlag = 1742, hours = { -1, -1 }, index = 3, movement = 8,
        palette = 0, radius = { x = 0, y = 0 }, script = 26490,
        scriptKey = "43:679d", sight = 1, sprite = "SPRITE_ROCKET_GIRL",
        spriteId = 54, type = 2, x = 17, y = 2,
      },
      {
        eventFlag = 1744, hours = { -1, -1 }, index = 4, movement = 8,
        palette = 0, radius = { x = 0, y = 0 }, script = 26471,
        scriptKey = "43:683f", sight = 0, sprite = "SPRITE_ROCKER",
        spriteId = 45, type = 0, x = 13, y = 5,
      },
    },
    coordEvents = {
      { sceneId = 0, scriptKey = "43:6748", x = 0, y = 3 },
      { sceneId = 1, scriptKey = "43:67a5", x = 16, y = 5 },
    },
    sceneScripts = {
      [0] = { sceneId = 0, script = 26437, scriptKey = "43:6745" },
      [1] = { sceneId = 1, script = 26438, scriptKey = "43:6746" },
      [2] = { sceneId = 2, script = 26439, scriptKey = "43:6747" },
    },
    bgEvents = {},
  }
  data.gen2Movement = data.gen2Movement or {}
  data.gen2Sprites = data.gen2Sprites or {}
end
seedGoldRadioTower()

-- Team Rocket Base: gold's shipped objects, exactly as the imported runtime
-- data has them (maps.lua).  applyRocketBase repoints the B1F (21,12) ball,
-- moves B2F GruntM18 and the B3F grunts/scientists, re-sprites the B3F exec
-- to SPRITE_ARCHER and appends the UltraBall at (14,10).
local function seedGoldRocketBase()
  data.gen2Maps.TEAM_ROCKET_BASE_B1F = {
    id = "TEAM_ROCKET_BASE_B1F",
    objects = {
      {
        eventFlag = 1643, hours = { -1, -1 }, index = 9, movement = 1,
        palette = 0, radius = { x = 0, y = 0 }, script = 10258,
        scriptKey = "00:2812", sight = 0, sprite = "SPRITE_POKE_BALL",
        spriteId = 84, type = 1, x = 21, y = 12,
        itemball = { item = 33, quantity = 1 },
      },
    },
  }
  data.gen2Maps.TEAM_ROCKET_BASE_B2F = {
    id = "TEAM_ROCKET_BASE_B2F",
    objects = {
      -- Six SPRITE_VOLTORB "electrodes" (gold indices 5-10; the Phase 4b swap
      -- retargets them to SPRITE_ELECTRODE with real CL art).
      { eventFlag = 1760, index = 5, sprite = "SPRITE_VOLTORB",
        spriteId = 155, movement = 22, palette = 0, type = 0,
        script = 0, scriptKey = "45:4db9", x = 7, y = 5 },
      { eventFlag = 1760, index = 6, sprite = "SPRITE_VOLTORB",
        spriteId = 155, movement = 22, palette = 0, type = 0,
        script = 0, scriptKey = "45:4de4", x = 7, y = 7 },
      { eventFlag = 1760, index = 7, sprite = "SPRITE_VOLTORB",
        spriteId = 155, movement = 22, palette = 0, type = 0,
        script = 0, scriptKey = "45:4e0f", x = 7, y = 9 },
      { eventFlag = 1760, index = 8, sprite = "SPRITE_VOLTORB",
        spriteId = 155, movement = 22, palette = 0, type = 0,
        script = 0, scriptKey = "00:2812", x = 22, y = 5 },
      { eventFlag = 1760, index = 9, sprite = "SPRITE_VOLTORB",
        spriteId = 155, movement = 22, palette = 0, type = 0,
        script = 0, scriptKey = "00:2812", x = 22, y = 7 },
      { eventFlag = 1760, index = 10, sprite = "SPRITE_VOLTORB",
        spriteId = 155, movement = 22, palette = 0, type = 0,
        script = 0, scriptKey = "00:2812", x = 22, y = 9 },
      {
        eventFlag = 1754, hours = { -1, -1 }, index = 11, movement = 9,
        palette = 0, radius = { x = 0, y = 0 }, script = 23932,
        scriptKey = "45:4d9d", sight = 3, sprite = "SPRITE_ROCKET",
        spriteId = 53, type = 2, x = 2, y = 1,
      },
    },
  }
  data.gen2Maps.TEAM_ROCKET_BASE_B3F = {
    id = "TEAM_ROCKET_BASE_B3F",
    objects = {
      {
        eventFlag = 1755, hours = { -1, -1 }, index = 2, movement = 7,
        palette = 0, radius = { x = 0, y = 0 }, script = 10258,
        scriptKey = "00:2812", sight = 0, sprite = "SPRITE_ROCKET",
        spriteId = 53, type = 0, x = 8, y = 3,
      },
      -- Murkrow stand-in: gold reuses SPRITE_MOLTRES (the Phase 4b swap
      -- retargets it to SPRITE_MURKROW with real CL art).  Palette 9 =
      -- PAL_NPC_BLUE, CL's murkrow slot.
      {
        eventFlag = 1754, hours = { -1, -1 }, index = 3, movement = 22,
        palette = 9, radius = { x = 0, y = 0 }, script = 23881,
        scriptKey = "45:5d49", sight = 0, sprite = "SPRITE_MOLTRES",
        spriteId = 158, type = 0, x = 7, y = 2,
      },
      {
        eventFlag = 1754, hours = { -1, -1 }, index = 5, movement = 9,
        palette = 0, radius = { x = 0, y = 0 }, script = 24015,
        scriptKey = "45:5d76", sight = 3, sprite = "SPRITE_ROCKET",
        spriteId = 53, type = 2, x = 5, y = 15,
      },
      {
        eventFlag = 1754, hours = { -1, -1 }, index = 6, movement = 9,
        palette = 0, radius = { x = 0, y = 0 }, script = 24037,
        scriptKey = "45:5d8d", sight = 4, sprite = "SPRITE_SCIENTIST",
        spriteId = 60, type = 2, x = 25, y = 12,
      },
      {
        eventFlag = 1754, hours = { -1, -1 }, index = 7, movement = 9,
        palette = 0, radius = { x = 0, y = 0 }, script = 24057,
        scriptKey = "45:5da1", sight = 3, sprite = "SPRITE_SCIENTIST",
        spriteId = 60, type = 2, x = 14, y = 15,
      },
      {
        eventFlag = 1645, hours = { -1, -1 }, index = 10, movement = 1,
        palette = 0, radius = { x = 0, y = 0 }, script = 10258,
        scriptKey = "00:2812", sight = 0, sprite = "SPRITE_POKE_BALL",
        spriteId = 84, type = 1, x = 1, y = 12,
        itemball = { item = 38, quantity = 1 },
      },
      {
        eventFlag = 1646, hours = { -1, -1 }, index = 11, movement = 1,
        palette = 0, radius = { x = 0, y = 0 }, script = 10258,
        scriptKey = "00:2812", sight = 0, sprite = "SPRITE_POKE_BALL",
        spriteId = 84, type = 1, x = 3, y = 12,
        itemball = { item = 44, quantity = 1 },
      },
      {
        eventFlag = 1647, hours = { -1, -1 }, index = 12, movement = 1,
        palette = 0, radius = { x = 0, y = 0 }, script = 10258,
        scriptKey = "00:2812", sight = 0, sprite = "SPRITE_POKE_BALL",
        spriteId = 84, type = 1, x = 28, y = 9,
        itemball = { item = 27, quantity = 1 },
      },
    },
  }
end
seedGoldRocketBase()

local run = T.sdk.loadMod("mods/crystal_legacy_changes", {
  data = data,
  generation = 2,
})
T.eq(run.mod and run.mod.state, "loaded", "runs on Gold")
T.eq(#run.errors, 0, "loads without errors")

local moves = run.loader.content.moves
local pokemon = run.loader.content.pokemon
local types = run.loader.content.type_chart

T.eq(pokemon:get("EKANS").baseStats.hp, 40, "Ekans HP is 40")
T.eq(pokemon:get("EKANS").baseStats.specialAttack, 40,
  "Ekans Special Attack is 40")
T.eq(pokemon:get("EKANS").baseStats.specialDefense, 54,
  "Ekans Special Defense is 54")
T.eq(pokemon:get("PIKACHU").baseStats.defense, 40,
  "Pikachu Defense remains the documented value")

T.eq(moves:get("WATERFALL").power, 70, "Waterfall power is 70")
T.eq(moves:get("WATERFALL").effect, "EFFECT_FLINCH_HIT",
  "Waterfall flinches")
T.eq(moves:get("WATERFALL").effectChance, 30,
  "Waterfall flinch chance is 30 percent")
T.eq(moves:get("EGG_BOMB").type, "GRASS", "Egg Bomb is Grass")
T.eq(moves:get("CUT").highCrit, true, "Cut has the increased crit rate")
T.eq(moves:get("CUT").type, "BUG", "Cut is Bug")
T.eq(moves:get("ROCK_SMASH").effect, "EFFECT_DEFENSE_DOWN_HIT",
  "Rock Smash lowers Defense")
T.eq(moves:get("IRON_TAIL").effectChance, 20,
  "Iron Tail Defense drop chance is 20 percent")
T.eq(moves:get("SKY_ATTACK").effect, "EFFECT_NORMAL_HIT",
  "Sky Attack does not charge")
T.eq(moves:get("SACRED_FIRE").pp, 10, "Sacred Fire PP is 10")

T.eq(#pokemon:get("BULBASAUR").levelMoves, 11,
  "Bulbasaur gets the Crystal Legacy level-up list")
T.eq(pokemon:get("BULBASAUR").levelMoves[1].move, "TACKLE",
  "Bulbasaur keeps its level-1 Tackle row")
T.eq(pokemon:get("VENUSAUR").levelMoves[13].move, "ANCIENTPOWER",
  "Venusaur gets the late AncientPower row")
T.eq(#pokemon:get("BULBASAUR").tmhm, 24,
  "Bulbasaur gets its TM/HM compatibility list")
T.eq(pokemon:get("BULBASAUR").tmhm[1], "HEADBUTT",
  "Bulbasaur TM/HM entries are canonicalized by move slot")
T.eq(pokemon:get("BULBASAUR").tmhm[#pokemon:get("BULBASAUR").tmhm], "FLASH",
  "Bulbasaur keeps HM05 FLASH as its final entry")
T.eq(pokemon:get("BULBASAUR").tmhm["FLAMETHROWER"], nil,
  "tutor-only moves are not TM/HM entries")

T.eq(types:get("GHOST").category, "special", "Ghost is Special")
T.eq(types:get("DARK").category, "physical", "Dark is Physical")

local encounters = run.loader.content.encounters
local trainers = run.loader.content.trainers

T.eq(encounters:get("grass").SPROUT_TOWER_2F.rates.MORN, 5,
  "Sprout Tower grass keeps its 5% morning rate")
T.eq(encounters:get("grass").SPROUT_TOWER_2F.rates.DAY, 5,
  "Sprout Tower grass keeps its 5% day rate")
T.eq(encounters:get("grass").SPROUT_TOWER_2F.rates.NITE, 5,
  "Sprout Tower grass keeps its 5% night rate")
T.eq(#encounters:get("grass").SPROUT_TOWER_2F.slots.MORN, 7,
  "Sprout Tower morning has seven grass slots")
T.eq(encounters:get("grass").SPROUT_TOWER_2F.slots.MORN[1].species, "RATTATA",
  "Sprout Tower morning slot 1 is Rattata")
T.eq(encounters:get("grass").SPROUT_TOWER_2F.slots.MORN[1].level, 3,
  "Sprout Tower morning slot 1 is level 3")
T.eq(encounters:get("water").RUINS_OF_ALPH_OUTSIDE.rate, 5,
  "Ruins of Alph outside keeps its 5% water rate")
T.eq(encounters:get("water").RUINS_OF_ALPH_OUTSIDE.slots[1].species, "WOOPER",
  "Ruins of Alph outside water slot 1 is Wooper")
T.eq(encounters:get("swarmGrass").DARK_CAVE_VIOLET_ENTRANCE.rates.MORN, 10,
  "Dark Cave swarm keeps its 10% morning rate")
T.eq(encounters:get("fishGroups").FISHGROUP_SHORE.index, 1,
  "Shore rod group keeps its index")
T.eq(encounters:get("fishGroups").FISHGROUP_SHORE.chance, 128,
  "Shore rod group keeps its 128/256 hook chance")

-- Phase 2 encounters step: TSP doc feature coverage -- Dark Cave Larvitar,
-- the Route 26/27 time-of-day starters, the Burned Tower Houndour/Slugma
-- rework, the Mt. Silver room rework, and the swarm-table replacement.
local function slot(encounters, kind, mapId, time, i)
  return encounters:get(kind)[mapId].slots[time][i]
end

T.eq(slot(encounters, "grass", "DARK_CAVE_VIOLET_ENTRANCE", "MORN", 6).species,
  "LARVITAR", "Dark Cave morning slot 6 is Larvitar")
T.eq(slot(encounters, "grass", "DARK_CAVE_VIOLET_ENTRANCE", "MORN", 6).level, 2,
  "Dark Cave Larvitar is level 2")
T.eq(slot(encounters, "grass", "DARK_CAVE_VIOLET_ENTRANCE", "DAY", 6).species,
  "LARVITAR", "Dark Cave day slot 6 is Larvitar")
T.eq(slot(encounters, "grass", "DARK_CAVE_VIOLET_ENTRANCE", "NITE", 6).species,
  "LARVITAR", "Dark Cave night slot 6 is Larvitar")

T.eq(slot(encounters, "grass", "ROUTE_26", "MORN", 7).species, "BULBASAUR",
  "Route 26 morning slot 7 is Bulbasaur")
T.eq(slot(encounters, "grass", "ROUTE_26", "DAY", 7).species, "CHARMANDER",
  "Route 26 day slot 7 is Charmander")
T.eq(slot(encounters, "grass", "ROUTE_26", "NITE", 7).species, "SQUIRTLE",
  "Route 26 night slot 7 is Squirtle")
T.eq(slot(encounters, "grass", "ROUTE_26", "MORN", 7).level, 5,
  "Route 26 starter is level 5")
T.eq(slot(encounters, "grass", "ROUTE_27", "MORN", 5).species, "CHIKORITA",
  "Route 27 morning slot 5 is Chikorita")
T.eq(slot(encounters, "grass", "ROUTE_27", "DAY", 5).species, "CYNDAQUIL",
  "Route 27 day slot 5 is Cyndaquil")
T.eq(slot(encounters, "grass", "ROUTE_27", "NITE", 5).species, "TOTODILE",
  "Route 27 night slot 5 is Totodile")

T.eq(slot(encounters, "grass", "BURNED_TOWER_1F", "MORN", 3).species, "HOUNDOUR",
  "Burned Tower morning slot 3 is Houndour")
T.eq(slot(encounters, "grass", "BURNED_TOWER_1F", "MORN", 5).species, "SLUGMA",
  "Burned Tower morning slot 5 is Slugma")
T.eq(slot(encounters, "grass", "BURNED_TOWER_1F", "DAY", 5).species, "HOUNDOUR",
  "Burned Tower day slot 5 is Houndour")
T.eq(slot(encounters, "grass", "BURNED_TOWER_1F", "NITE", 4).species, "ZUBAT",
  "Burned Tower night slot 4 is Zubat -- Zubat is night-only")

T.eq(slot(encounters, "grass", "SILVER_CAVE_OUTSIDE", "MORN", 5).species,
  "VENUSAUR", "Mt. Silver outside morning slot 5 is Venusaur")
T.eq(slot(encounters, "grass", "SILVER_CAVE_OUTSIDE", "MORN", 5).level, 50,
  "Mt. Silver Venusaur is level 50")
T.eq(slot(encounters, "grass", "SILVER_CAVE_ROOM_3", "MORN", 4).level, 70,
  "Mt. Silver Room 3 morning slot 4 is level 70")
T.eq(slot(encounters, "grass", "SILVER_CAVE_ROOM_3", "MORN", 7).species, "PUPITAR",
  "Mt. Silver Room 3 morning slot 7 is Pupitar")
T.eq(slot(encounters, "grass", "SILVER_CAVE_ROOM_3", "MORN", 7).level, 40,
  "Mt. Silver Room 3 Pupitar is level 40")

-- The swarm kinds are complete replacements: Crystal keeps only the Dark
-- Cave and Route 35 land swarms and ships NO surf swarms.  The rows asserted
-- nil below are seeded into the fixture base above, so this pins the
-- override seam -- a deep-merge patch would let them survive; override
-- removes them.
T.eq(encounters:get("swarmGrass").MOUNT_MORTAR_1F_OUTSIDE, nil,
  "Mount Mortar's land swarm is removed")
T.eq(encounters:get("swarmGrass").ROUTE_38, nil,
  "seeded Route 38 land swarm is gone post-load (override pin)")
T.eq(encounters:get("swarmWater").MOUNT_MORTAR_1F_OUTSIDE, nil,
  "seeded Mount Mortar surf swarm is gone post-load (override pin)")
T.eq(next(encounters:get("swarmWater")), nil,
  "Crystal ships no surf swarms")
local swarmGrassMaps = {}
for mapId in pairs(encounters:get("swarmGrass")) do
  swarmGrassMaps[#swarmGrassMaps + 1] = mapId
end
table.sort(swarmGrassMaps)
T.eq(table.concat(swarmGrassMaps, ","), "DARK_CAVE_VIOLET_ENTRANCE,ROUTE_35",
  "swarmGrass holds exactly Crystal's two maps after the override")

T.eq(trainers:get("FALKNER").baseMoney, 25, "Falkner pays out 25 base money")
T.eq(trainers:get("FALKNER").encounterMusic, "Music_LookYoungster",
  "Falkner keeps his encounter theme")
T.eq(trainers:get("FALKNER").name, "LEADER", "Falkner's class reads LEADER")
T.eq(#trainers:get("FALKNER").trainers, 2,
  "Falkner has his base and rematch parties")
T.eq(trainers:get("FALKNER").trainers[1].party[1].species, "PIDGEY",
  "Falkner leads with Pidgey")
T.eq(trainers:get("FALKNER").trainers[1].party[2].item, "BERRY",
  "Falkner's Pidgeotto holds a Berry")
T.eq(trainers:get("BEAUTY").encounterMusic, "Music_LookBeauty",
  "Beauty keeps her encounter theme")
T.eq(trainers:get("BEAUTY").trainers[1].name, "VICTORIA",
  "Beauty Victoria is first in class")
T.eq(trainers:get("BEAUTY").trainers[1].party[1].species, "TEDDIURSA",
  "Beauty Victoria leads with Teddiursa")

-- Phase 2 trainers step: TSP doc feature coverage -- gym badge variants,
-- Elite Four, Kanto leaders, rival, Red, Rocket (incl. Eto).
T.eq(#trainers:get("PRYCE").trainers, 4,
  "Pryce has his four badge-variant parties")
T.eq(#trainers:get("JASMINE").trainers, 4,
  "Jasmine has her four badge-variant parties")
T.eq(#trainers:get("CHUCK").trainers, 4,
  "Chuck has his four badge-variant parties")

T.eq(#trainers:get("WILL").trainers, 2,
  "Will has his base and rematch parties")
T.eq(trainers:get("WILL").trainers[1].party[1].species, "GIRAFARIG",
  "Will leads with Girafarig")
T.eq(trainers:get("WILL").trainers[1].party[1].level, 48,
  "Will's Girafarig is level 48")
T.eq(trainers:get("KOGA").trainers[1].party[1].species, "ARIADOS",
  "Koga leads with Ariados")
T.eq(trainers:get("BRUNO").trainers[1].party[1].species, "HITMONCHAN",
  "Bruno leads with Hitmonchan")
T.eq(trainers:get("KAREN").trainers[1].party[1].species, "UMBREON",
  "Karen leads with Umbreon")

T.eq(#trainers:get("BROCK").trainers, 1,
  "Brock has his single Kanto party")
T.eq(trainers:get("BROCK").trainers[1].party[1].species, "GOLEM",
  "Brock's Kanto team leads with Golem")
T.eq(trainers:get("BROCK").trainers[1].party[1].level, 66,
  "Brock's Golem is level 66")
T.eq(trainers:get("BROCK").trainers[1].party[1].item, "QUICK_CLAW",
  "Brock's Golem holds the Quick Claw")
T.eq(trainers:get("MISTY").trainers[1].party[1].species, "GOLDUCK",
  "Misty's Kanto team leads with Golduck")
T.eq(trainers:get("BLUE").trainers[1].party[1].species, "ARTICUNO",
  "Blue's champion rematch leads with Articuno")
T.eq(trainers:get("BLUE").trainers[1].party[1].level, 69,
  "Blue's Articuno is level 69")

T.eq(#trainers:get("CHAMPION").trainers, 2,
  "Lance has his base and rematch parties")
T.eq(trainers:get("CHAMPION").trainers[1].name, "LANCE",
  "The champion class's first trainer is Lance")
T.eq(trainers:get("CHAMPION").trainers[1].party[2].species, "DRAGONITE",
  "Lance's second party slot is Dragonite")
T.eq(trainers:get("CHAMPION").trainers[1].party[2].item, "GOLD_BERRY",
  "Lance's Dragonite holds a Gold Berry")

T.eq(#trainers:get("RED").trainers, 2,
  "Red has his base and rematch parties")
T.eq(trainers:get("RED").trainers[1].party[1].species, "PIKACHU",
  "Red leads with Pikachu")
T.eq(trainers:get("RED").trainers[1].party[1].level, 93,
  "Red's Pikachu is level 93")
T.eq(trainers:get("RED").trainers[1].party[1].item, "LIGHT_BALL",
  "Red's Pikachu holds the Light Ball")

T.eq(#trainers:get("RIVAL1").trainers, 15,
  "The rival's fifteen battles span the game")
T.eq(#trainers:get("RIVAL2").trainers, 6,
  "The rival's six rematch battles follow the postgame")

T.eq(#trainers:get("ROCKET_LEADER").trainers, 2,
  "Archer has his base and rematch parties")
T.eq(trainers:get("ROCKET_LEADER").trainers[1].name, "ARCHER",
  "The Rocket leader class's first trainer is Archer")
T.eq(trainers:get("ROCKET_LEADER").trainers[1].party[5].species, "SLOWBRO",
  "Archer's fifth party slot is Slowbro")
T.eq(#trainers:get("GRUNTM").trainers, 31,
  "The male grunt class carries all thirty-one grunt battles")
T.eq(trainers:get("GRUNTM").trainers[2].name, "ETO",
  "The Rocket executive Eto rides the grunt class")
T.eq(trainers:get("GRUNTM").trainers[2].party[1].species, "ELEKID",
  "Eto's first battle leads with Elekid")
T.eq(trainers:get("BOSS").trainers[1].name, "GIOVANNI",
  "Giovanni returns as the boss class")
T.eq(trainers:get("MYSTICALMAN").trainers[1].name, "EUSINE",
  "Eusine rides the mystical man class")

local export = run.loader.exports.crystal_legacy_changes
T.check(export and export.rebalance and export.rebalance.moves > 0,
  "exports report applied move changes")
T.check(export.rebalance.species > 0,
  "exports report applied species changes")
T.eq(export.rebalance.learnsets, 251,
  "exports report all 251 learnsets")
T.eq(export.rebalance.tmhm, 251,
  "exports report all 251 TM/HM lists")
T.eq(export.rebalance.encounters, 10,
  "exports report all ten encounter kinds patched")
T.eq(export.rebalance.trainers, 70,
  "exports report all 70 trainer classes patched")
T.eq(export.rebalance.marts, 34,
  "exports report all 34 gold mart shelves replaced")
T.eq(export.rebalance.clOnly, 5,
  "exports report the five CL-only marts held back")

-- Phase 2 marts step: there is no marts content registry -- the engine seeds
-- game.data.gen2Marts = { bargain, lists = {34 gold-positional shelves} } and
-- World/MartMenu read it by reference, so the mod rides mods.loaded and swaps
-- the shelves in place.  The fixture seeded junk shelves + a bargain above; a
-- no-op or deep-merge patch would keep the junk and never land CL stock on
-- the exact gold indices, so the assertions below pin the in-place swap.
local marts = data.gen2Marts
T.check(type(marts) == "table", "gen2Marts survives the load")
T.check(type(marts.lists) == "table", "gen2Marts.lists survives the load")
T.eq(#marts.lists, 36, "34 gold slots + the two appended berry shelves")
T.eq(marts.bargain[1].item, "POTION", "bargain item is preserved")
T.eq(marts.bargain[1].price, 300, "bargain price is preserved")

local function shelf(i)
  return table.concat(marts.lists[i] or {}, ",")
end
local function clShelf(name)
  return table.concat(martsData.marts[name] or {}, ",")
end
T.eq(shelf(1), clShelf("MART_CHERRYGROVE"),
  "slot 1 is the Cherrygrove CL shelf")
T.eq(shelf(2), clShelf("MART_CHERRYGROVE_DEX"),
  "slot 2 is the Cherrygrove Dex CL shelf")
T.eq(shelf(3), clShelf("MART_VIOLET"),
  "slot 3 is the Violet CL shelf")
T.eq(shelf(6), clShelf("MART_GOLDENROD_2F_1"),
  "slot 6 is the Goldenrod 2F CL shelf")
T.eq(shelf(16), clShelf("MART_MAHOGANY_1"),
  "slot 16 is the Mahogany 1F CL shelf")
T.eq(shelf(17), clShelf("MART_MAHOGANY_2"),
  "slot 17 is the Mahogany 2F CL shelf")
T.eq(shelf(26), clShelf("MART_CELADON_3F"),
  "slot 26 is the Celadon 3F CL shelf")
T.eq(shelf(27), clShelf("MART_CELADON_4F"),
  "slot 27 is the Celadon 4F CL shelf")
T.eq(shelf(28), clShelf("MART_CELADON_5F_1"),
  "slot 28 is the Celadon 5F CL shelf")
T.eq(shelf(34), clShelf("MART_UNDERGROUND"),
  "slot 34 is the Underground herb shelf")
T.check(marts.lists[17][1] == "RAGECANDYBAR"
  and marts.lists[17][2] == "METAL_COAT"
  and marts.lists[17][3] == "UP_GRADE"
  and marts.lists[17][4] == "BRICK_PIECE",
  "Mahogany sells the four evolution items in CL order")

local junkSeen = false
local leakSeen = false
for i = 1, 34 do
  for _, item in ipairs(marts.lists[i] or {}) do
    if item:sub(1, 12) == "SEEDED_JUNK_" then junkSeen = true end
    -- CL-only marts (BERRYS, BERRYS_2, CELADON_3F_2, CELADON_5F_1_2,
    -- CELADON_5F_2_2) have no gold slot (NUM_MARTS = 34); the berry-shop step
    -- appends BERRYS/BERRYS_2 at ids 34/35 (lists[35]/[36]), but their unique
    -- stock must never land on any of the 34 gold slots.  The three unmapped
    -- Celadon shelves stay held back entirely.
    if item == "GOLD_BERRY" or item == "TM_EARTHQUAKE"
      or item == "TM_TOXIC" or item == "TM_RETURN" then
      leakSeen = true
    end
  end
end
T.check(not junkSeen, "no seeded junk survives in any of the 34 slots")
T.check(not leakSeen, "no CL-only mart stock leaks into a gold slot")

-- Phase 3a berry-shop step: the Goldenrod Flower Shop gets CL's clerk selling
-- the MART_BERRYS / MART_BERRYS_2 shelves, badge-gated at 7 badges exactly
-- like CL's BerryMartScript.  The two shelves have no gold slot under
-- NUM_MARTS = 34, so they are appended at the first free mart ids (34/35 ->
-- lists[35]/[36]) and the clerk's script is injected into gen2Scripts.
T.eq(export.rebalance.berryShop.lists, 2, "both berry shelves appended")
T.eq(export.rebalance.berryShop.object, 1, "Flower Shop clerk object added")
T.eq(export.rebalance.berryShop.script, 1, "BerryMartScript injected")

T.eq(shelf(35), clShelf("MART_BERRYS"),
  "slot 35 is the MART_BERRYS shelf (id 34)")
T.eq(shelf(36), clShelf("MART_BERRYS_2"),
  "slot 36 is the MART_BERRYS_2 shelf (id 35)")
T.check(marts.lists[36][9] == "GOLD_BERRY"
  and marts.lists[36][10] == "MIRACLEBERRY",
  "the BERRYS_2 shelf carries the late-game berries")

local shop = data.gen2Maps.GOLDENROD_FLOWER_SHOP
T.check(type(shop) == "table", "Flower Shop map def present in gen2Maps")
T.eq(#shop.objects, 3, "Flower Shop has three objects after the patch")
local clerk = shop.objects[3]
T.eq(clerk.scriptKey, "crystal_legacy_changes:berry_mart",
  "clerk runs the injected berry script")
T.eq(clerk.sprite, "SPRITE_CLERK", "clerk uses the clerk sprite")
T.eq(clerk.x, 5, "clerk at x=5 (CL position)")
T.eq(clerk.y, 3, "clerk at y=3 (CL position)")
T.eq(clerk.movement, 6, "clerk stands still facing down")
T.eq(clerk.type, 0, "clerk is an OBJECTTYPE_SCRIPT")
T.eq(clerk.eventFlag, 65535, "clerk has no flag gate")

local berryScript = data.gen2Scripts["crystal_legacy_changes:berry_mart"]
T.check(type(berryScript) == "table", "BerryMartScript injected into gen2Scripts")
T.eq(berryScript[1].op, "faceplayer", "script opens with faceplayer")
T.eq(berryScript[2].op, "opentext", "script opens the text window")
T.eq(berryScript[3].op, "readvar", "script reads a variable")
T.eq(berryScript[3].var, 0x07, "the variable is VAR_BADGES")
T.eq(berryScript[4].op, "ifless", "script branches on badge count")
T.eq(berryScript[4].value, 7, "the gate is 7 badges (CL BerryMartScript)")
T.eq(berryScript[4].script[1].op, "pokemart", "under-7 arm opens a mart")
T.eq(berryScript[4].script[1].martId, 34, "under-7 arm sells MART_BERRYS (id 34)")
T.eq(berryScript[5].op, "pokemart", "over-7 arm opens a mart")
T.eq(berryScript[5].martId, 35, "over-7 arm sells MART_BERRYS_2 (id 35)")
T.eq(berryScript[6].op, "closetext", "script closes the text window")
T.eq(berryScript[7].op, "end", "script ends")

-- Phase 4 engine fix (fork branch phase4a/berry-shop): MartMenu.inventory is
-- now data-driven — a mart id past the extractor's 34 shelves is legal when
-- the table itself carries a shelf for it, so the appended MART_BERRYS
-- shelves are reachable through the REAL gate function, while a missing list
-- row still falls back to DEFAULT_MART.
local MartMenu = require("src.ui.gen2.MartMenu")
T.eq(MartMenu.inventory(marts, 34), marts.lists[35],
  "inventory(marts, 34) is the MART_BERRYS shelf (appended id 34)")
T.eq(MartMenu.inventory(marts, 35), marts.lists[36],
  "inventory(marts, 35) is the MART_BERRYS_2 shelf (appended id 35)")
local stock34 = MartMenu.inventory(marts, 34)
T.eq(table.concat(stock34 or {}, ","), clShelf("MART_BERRYS"),
  "the reachable shelf is the CL berry stock, not DEFAULT_MART")
T.eq(MartMenu.inventory(marts, 99)[1], "POKE_BALL",
  "an id with no list row still falls back to DEFAULT_MART")

-- Phase 2 evolutions step: the patch swaps each species' whole evolutions
-- list (record semantics), so the gold-style rows seeded above must be gone
-- and the full CL lists must be in their place.  A deep-merge patch would
-- have kept the seeded gold rows alongside the CL ones.
T.eq(export.rebalance.evolutions, 15,
  "exports report all 15 species with CL evolution lists")

local function rowsFor(species)
  return pokemon:get(species).evolutions or {}
end
local function fmtRow(row)
  return (row.method or "?") .. ">" .. (row.into or "?")
end

local goldeen = rowsFor("GOLDEEN")
T.eq(#goldeen, 1, "GOLDEEN has exactly one CL row")
T.eq(goldeen[1].into, "SEAKING", "GOLDEEN evolves into SEAKING")
T.eq(goldeen[1].level, 28, "GOLDEEN evolves at 28 (gold: 33)")
T.eq(goldeen[1].method, "EVOLVE_LEVEL", "GOLDEEN evolves by level")

local onix = rowsFor("ONIX")
T.eq(#onix, 1, "ONIX has exactly one CL row")
T.eq(onix[1].into, "STEELIX", "ONIX evolves into STEELIX")
T.eq(onix[1].item, "METAL_COAT", "ONIX evolves with METAL_COAT")
T.eq(onix[1].method, "EVOLVE_ITEM", "ONIX item evolution replaces gold's EVOLVE_TRADE")

local tyrogue = rowsFor("TYROGUE")
T.eq(#tyrogue, 3, "TYROGUE has three CL rows")
T.eq(fmtRow(tyrogue[1]), "EVOLVE_ITEM>HITMONTOP",
  "TYROGUE->HITMONTOP uses BRICK_PIECE (gold: ATK_EQ_DEF stat)")
T.eq(tyrogue[1].item, "BRICK_PIECE", "HITMONTOP needs BRICK_PIECE")
T.eq(tyrogue[2].comparison, "ATK_LT_DEF", "HITMONCHAN needs ATK_LT_DEF")
T.eq(tyrogue[3].comparison, "ATK_GT_DEF", "HITMONLEE needs ATK_GT_DEF")

local porygon = rowsFor("PORYGON")
T.eq(#porygon, 1, "PORYGON has exactly one CL row")
T.eq(porygon[1].method, "EVOLVE_ITEM", "PORYGON item evolution replaces gold's EVOLVE_TRADE")
T.eq(porygon[1].item, "UP_GRADE", "PORYGON evolves with UP_GRADE")

local slowpoke = rowsFor("SLOWPOKE")
T.eq(#slowpoke, 2, "SLOWPOKE has two CL rows")
T.eq(slowpoke[1].into, "SLOWBRO", "SLOWPOKE->SLOWBRO kept")
T.eq(slowpoke[2].into, "SLOWKING", "SLOWPOKE->SLOWKING kept")
T.eq(slowpoke[2].method, "EVOLVE_ITEM", "SLOWKING item evolution replaces gold's EVOLVE_TRADE")

local poliwhirl = rowsFor("POLIWHIRL")
T.eq(#poliwhirl, 2, "POLIWHIRL has two CL rows")
T.eq(poliwhirl[1].item, "WATER_STONE", "POLIWRATH needs WATER_STONE")
T.eq(poliwhirl[2].item, "KINGS_ROCK", "POLITOED needs KINGS_ROCK")

-- Every seeded gold row must be gone: no EVOLVE_TRADE row survives anywhere.
local tradeLeft = false
for _, species in ipairs({ "GOLDEEN", "ONIX", "TYROGUE", "PORYGON", "SLOWPOKE" }) do
  for _, row in ipairs(rowsFor(species)) do
    if row.method == "EVOLVE_TRADE" then tradeLeft = true end
  end
end
T.check(not tradeLeft, "no gold EVOLVE_TRADE row survives the CL swap")

-- Whole-dataset totals: 15 species, 19 rows, all in the merged registry.
local speciesCount = 0
local rowCount = 0
for species, rows in pairs(evolutionsData.evolutions or {}) do
  speciesCount = speciesCount + 1
  rowCount = rowCount + #rows
  local merged = rowsFor(species)
  T.eq(#merged, #rows, species .. " has the full CL list in the merged registry")
end
T.eq(speciesCount, 15, "data file carries 15 species")
T.eq(rowCount, 19, "data file carries 19 evolution rows")

-- The item evolutions change method, not just the rows: gold's trade-with-
-- item evos (UP_GRADE/KINGS_ROCK/METAL_COAT/BRICK_PIECE/DRAGON_SCALE) become
-- EVOLVE_ITEM, whose engine record the mod re-affirms (patch, not register --
-- the engine owns the id) with requiresForce=true so the stone-style use
-- fires and the after-battle sweep never does.
T.eq(export.rebalance.evolutionMethods, 1,
  "exports report the re-affirmed EVOLVE_ITEM method record")
local evolutionMethods = run.loader.content.evolution_methods
T.eq(evolutionMethods:get("EVOLVE_ITEM").requiresForce, true,
  "EVOLVE_ITEM carries force semantics for the item evolutions")

-- Trade evolutions become level evolutions; the early shifts land.
T.eq(rowsFor("KADABRA")[1].level, 42, "KADABRA evolves at 42 (gold: trade)")
T.eq(rowsFor("MACHOKE")[1].level, 38, "MACHOKE evolves at 38 (gold: trade)")
T.eq(rowsFor("GRAVELER")[1].level, 38, "GRAVELER evolves at 38 (gold: trade)")
T.eq(rowsFor("HAUNTER")[1].level, 42, "HAUNTER evolves at 42 (gold: trade)")
T.eq(rowsFor("PINECO")[1].level, 25, "PINECO evolves at 25 (gold: 31)")
T.eq(rowsFor("SLUGMA")[1].level, 27, "SLUGMA evolves at 27 (gold: 38)")
T.eq(rowsFor("SPINARAK")[1].level, 21, "SPINARAK evolves at 21 (gold: 22)")

-- Behavioral: drive the engine's own row-walk against the merged data.
-- EVOLVE_ITEM only fires from the item's use (force), never from the
-- after-battle sweep; EVOLVE_LEVEL needs no link anymore; EVOLVE_STAT keys
-- off the attack/defense comparison.
local Evolution = require("src.core.gen2.Evolution")
local function fires(mon, ctx)
  local entry = Evolution.check(pokemon:get(mon.species), mon, ctx, data)
  return entry and entry.into
end
T.eq(fires({ species = "ONIX", level = 30 }, { force = true, item = "METAL_COAT" }),
  "STEELIX", "using a Metal Coat on Onix evolves it into Steelix")
T.eq(fires({ species = "ONIX", level = 30 }, { force = true, item = "UP_GRADE" }),
  nil, "the wrong item does not evolve Onix")
T.eq(fires({ species = "ONIX", level = 30 }, { item = "METAL_COAT" }),
  nil, "an item use with no force flag does not evolve Onix")
T.eq(fires({ species = "ONIX", level = 30 }, {}),
  nil, "the after-battle sweep never fires Onix's item evolution")
T.eq(fires({ species = "KADABRA", level = 42 }, {}),
  "ALAKAZAM", "Kadabra evolves into Alakazam at 42 with no link")
T.eq(fires({ species = "KADABRA", level = 30 }, {}),
  nil, "Kadabra does not evolve below level 42")
T.eq(fires({ species = "MACHOKE", level = 38 }, {}),
  "MACHAMP", "Machoke evolves into Machamp at 38 with no link")
T.eq(fires({ species = "GRAVELER", level = 38 }, {}),
  "GOLEM", "Graveler evolves into Golem at 38 with no link")
T.eq(fires({ species = "HAUNTER", level = 42 }, {}),
  "GENGAR", "Haunter evolves into Gengar at 42 with no link")
T.eq(fires({ species = "TYROGUE", level = 20, stats = { attack = 30, defense = 20 } }, {}),
  "HITMONLEE", "high-attack Tyrogue becomes Hitmonlee")
T.eq(fires({ species = "TYROGUE", level = 20, stats = { attack = 20, defense = 30 } }, {}),
  "HITMONCHAN", "high-defense Tyrogue becomes Hitmonchan")

-- Phase 3 game-corner step: the CL prize list is a different list per the
-- legacy design (ABRA 100 / PORYGON 800 / DRATINI 1500, replacing gold's
-- ABRA 200 / EKANS 700 / DRATINI 2100, and PORYGON replaces EKANS), and the
-- givepoke levels drop to L5/L15/L15.  The patch mutates the gold rows in
-- place, so the assertions read data.gen2Scripts -- the same table the VM
-- dispatches at runtime.
local staticsData = dofile("mods/crystal_legacy_changes/data/statics.lua")
local gc = staticsData.gameCorner
T.check(type(gc) == "table", "statics data file carries the gameCorner section")
T.eq(export.rebalance.statics, 26,
  "exports report 3 game-corner prize arms + master command + shrine row + mew release + mew battle + 3 bird catch scripts + 3 bird release splices + 3 bird objects + 10 celebi chain steps")

local scripts = data.gen2Scripts
T.check(type(scripts) == "table", "gen2Scripts survives the load")

local function menuItemsOf(key)
  local items
  for _, step in ipairs(scripts[key] or {}) do
    if step.op == "loadmenu" and step.menu then items = step.menu.items end
  end
  return items
end
local function joinItems(key)
  local items = menuItemsOf(key) or {}
  local out = {}
  for _, item in ipairs(items) do out[#out + 1] = item end
  return table.concat(out, "|")
end

T.eq(joinItems("57:6880"),
  "ABRA        100|PORYGON     800|DRATINI    1500|CANCEL",
  "main prize menu carries the CL item list")
T.eq(joinItems("57:688f"),
  "ABRA        100|PORYGON     800|DRATINI    1500|CANCEL",
  "post-prize re-entry menu carries the CL item list")

local function coins(key)
  for _, step in ipairs(scripts[key] or {}) do
    if step.op == "checkcoins" then
      return step.args[1] + 256 * step.args[2]
    end
  end
end
local function given(key)
  for _, step in ipairs(scripts[key] or {}) do
    if step.op == "givepoke" then
      return step.species, step.level
    end
  end
end
local function namedSpecies(key)
  for _, step in ipairs(scripts[key] or {}) do
    if step.op == "getmonname" then return step.species end
  end
end
local function setvalOf(key)
  for _, step in ipairs(scripts[key] or {}) do
    if step.op == "setval" then return step.args[1] end
  end
end

T.eq(coins("57:68a9"), 100, "ABRA costs 100 coins (gold: 200)")
local abraSpecies, abraLevel = given("57:68a9")
T.eq(abraSpecies, 63, "ABRA arm gives species 63")
T.eq(abraLevel, 5, "ABRA is level 5 (gold: 10)")

T.eq(coins("57:68d7"), 800, "PORYGON costs 800 coins (gold EKANS: 700)")
local porygonSpecies, porygonLevel = given("57:68d7")
T.eq(porygonSpecies, 137, "EKANS arm now gives PORYGON (137)")
T.eq(porygonLevel, 15, "PORYGON is level 15 (gold: 10)")
T.eq(namedSpecies("57:68d7"), 137, "getmonname follows the new species")
T.eq(setvalOf("57:68d7"), 137, "setval follows the new species")

T.eq(coins("57:6905"), 1500, "DRATINI costs 1500 coins (gold: 2100)")
local dratiniSpecies, dratiniLevel = given("57:6905")
T.eq(dratiniSpecies, 147, "DRATINI arm gives species 147")
T.eq(dratiniLevel, 15, "DRATINI is level 15 (gold: 10)")

-- No gold value survives: the arms must carry the CL price on takecoins too
-- (the deduction, not just the check).
local function deducted(key)
  for _, step in ipairs(scripts[key] or {}) do
    if step.op == "takecoins" then
      return step.args[1] + 256 * step.args[2]
    end
  end
end
T.eq(deducted("57:68a9"), 100, "ABRA takecoins deducts 100")
T.eq(deducted("57:68d7"), 800, "PORYGON takecoins deducts 800")
T.eq(deducted("57:6905"), 1500, "DRATINI takecoins deducts 1500")

-- ---- Phase 3b: Dragon's Den Dratini Master ------------------------------
-- CL's Elder hands the post-quiz (post-Clair) champion an L15 DRATINI with
-- the "true master" moveset.  Gold has no Elder in Dragon's Den B1F: the
-- shrine tile (18,24) is a plain read bgEvent whose script row is a single
-- jumptext, so the patch replaces that row with the mod command verb.
local master = staticsData.master
T.check(type(master) == "table", "statics data file carries the master section")
T.eq(master.scriptKey, "47:4586", "shrine read bgEvent script key")
T.eq(master.badge, "RISING", "gift gates on Clair's RISING badge")
T.eq(master.speciesIndex, 147, "master gives DRATINI (147)")
T.eq(master.level, 15, "DRATINI is level 15")
T.eq(#(master.moves or {}), 4, "gift carries the four CL moves")
T.eq(master.moves[4].id, "EXTREMESPEED", "true-master set ends on EXTREMESPEED")
for _, mv in ipairs(master.moves or {}) do
  T.check(type(mv.id) == "string" and type(mv.pp) == "number"
    and mv.maxPp == mv.pp, "move row well-formed: " .. tostring(mv.id))
end

-- Text rows land in data.gen2Text under the mod prefix.
for key, text in pairs(master.text or {}) do
  T.eq(data.gen2Text["crystal_legacy_changes:dratini_" .. key], text,
    "shrine text row registered: dratini_" .. key)
end

-- The command merged into the table the VM dispatches.
T.check(type(data.commands["crystal_legacy_changes:dratini_master"]) == "function",
  "command registered: dratini_master")

-- The shrine read bgEvent script is now a straight command run.
local shrineRow = scripts[master.scriptKey]
T.check(type(shrineRow) == "table" and type(shrineRow[1]) == "table",
  "shrine row replaced with a command row")
T.eq(shrineRow[1][1], "crystal_legacy_changes:dratini_master",
  "shrine row carries the master command")

-- ---- Phase 3b pin: Vermilion City Snorlax ------------------------------
-- Verification only: the gold cart already ships CL's Snorlax (Vermilion
-- 34,8 L50, Poke Flute radio-channel wake, EXPN-gated).  The pin section
-- documents the facts so a gold re-import cannot regress them silently.
local snorlax = staticsData.snorlax
T.check(type(snorlax) == "table", "statics data file carries the snorlax pin")
T.eq(snorlax.mapId, "VERMILION_CITY", "Snorlax lives in Vermilion City")
T.eq(snorlax.coords.x, 34, "Snorlax tile x 34 (matches gold object)")
T.eq(snorlax.coords.y, 8, "Snorlax tile y 8 (matches gold object)")
T.eq(snorlax.speciesIndex, 143, "species is SNORLAX (143)")
T.eq(snorlax.level, 50, "level is CL's L50")
T.eq(snorlax.wakeSpecial, 95, "wake check is special 95 (SnorlaxAwake)")
T.eq(snorlax.channel, "POKE_FLUTE_RADIO", "woken by the radio channel, not an item")
T.eq(snorlax.scriptKey, "4f:5291", "A-press script key")
T.eq(snorlax.wakeScriptKey, "4f:529e", "wake branch key")
T.eq(snorlax.flags.appear, 1904, "object flag (EVENT_VERMILION_CITY_SNORLAX)")
T.eq(snorlax.flags.fought, 1872, "post-battle flag (EVENT_FOUGHT_SNORLAX)")
T.eq(snorlax.battleType, "BATTLETYPE_FORCEITEM", "battle is FORCEITEM, not Trap")
T.check(snorlax.text.sleeping:match("^SNORLAX is snoring"),
  "sleeping text matches CL wording")
T.check(snorlax.text.wake:match("^The POKéGEAR was placed")
  and snorlax.text.wake:match("SNORLAX woke up!$"),
  "wake text matches CL wording")
T.eq(export.rebalance.statics, 26,
  "pin adds no patched arm (statics count reflects master + mew + mew battle + birds + bird objects + celebi chain)")

-- ---- Phase 3b: Route 24 Mew dex-chain release --------------------------
-- CL splices a Mew release into gold's EXISTING dex-completion branch; the
-- visible Route 24 object ships in Phase 4b (SPRITE_MEW overworld art from
-- data/sprites.lua, CL gfx/icons/mew.png).
local mew = staticsData.mew
T.check(type(mew) == "table", "statics data file carries the mew section")
T.eq(mew.speciesIndex, 151, "Mew species 151")
T.eq(mew.level, 60, "Mew is L60")
T.eq(mew.route, "ROUTE_24", "released on Route 24")
T.eq(mew.coords.x, 8, "Route 24 tile x 8 (CL)")
T.eq(mew.coords.y, 12, "Route 24 tile y 12 (CL)")
T.eq(mew.flags.mew, 1940, "release flag EVENT_ROUTE_24_MEW (free in gold)")
T.eq(mew.flags.caught, 1941, "caught flag EVENT_ROUTE_24_MEW_CAUGHT")
T.eq(mew.gate.minCaught, 249, "gate = 249 caught (251 - Mew - Celebi)")

-- The gold gate row is untouched and already CL-correct.
local gate = scripts[mew.gateKey]
T.check(type(gate) == "table", "designer gate script present")
local readvar, ifgreater
for _, step in ipairs(gate) do
  if step.op == "readvar" then readvar = step end
  if step.op == "ifgreater" then ifgreater = step end
end
T.eq(readvar and readvar.var, 5, "gate reads VAR_DEXCAUGHT")
T.eq(ifgreater and ifgreater.value, 248, "gate: caught > 248 (Mew+Celebi excluded)")
T.eq(ifgreater and ifgreater.script, "5e:4c9a", "gate jumps to the diploma branch")

-- The diploma branch now carries the release between special 106 and the
-- after-diploma text, with the caught check skipping the clearevent.
local completed = scripts[mew.completedKey]
local ops = {}
for _, step in ipairs(completed or {}) do
  ops[#ops + 1] = step.op
end
T.check(#ops >= 15 and ops[1] == "promptbutton" and ops[7] == "special",
  "diploma branch still opens with fanfare + Diploma special")
T.eq(completed[8].op, "checkevent", "release: checkevent caught first")
T.eq(completed[8].event, 1941, "checks EVENT_ROUTE_24_MEW_CAUGHT")
T.eq(completed[9].op, "iftrue", "release: iftrue skips the clearevent")
T.eq(completed[9].script, mew.skipKey, "iftrue target is the mod skip row")
T.eq(completed[10].op, "clearevent", "release: clearevent MEW")
T.eq(completed[10].event, 1940, "clears EVENT_ROUTE_24_MEW")
T.eq(completed[11].op, "writetext", "after-diploma text follows")
T.eq(completed[#completed - 1].op, "setevent", "still sets the diploma-print flag")
T.eq(completed[#completed - 1].event, 214, "EVENT_ENABLE_DIPLOMA_PRINTING (214)")
T.eq(completed[#completed].op, "end", "branch still ends properly")

-- The iftrue skip target exists and runs the same tail.
local skip = scripts[mew.skipKey]
T.check(type(skip) == "table", "skip target row registered")
T.eq(skip[1].op, "writetext", "skip starts at the after-diploma text")
T.eq(skip[1].text, mew.text.after_diploma, "same gold text row")
T.eq(skip[#skip].op, "end", "skip ends cleanly")

-- Phase 4b: the Mew object spawns on Route 24 (index 7) with CL's MewScript.
do
  T.eq(data.gen2Maps.ROUTE_24 and #data.gen2Maps.ROUTE_24.objects, 7,
    "Mew appended as the 7th Route 24 object")
  local mewObject = data.gen2Maps.ROUTE_24 and data.gen2Maps.ROUTE_24.objects[7]
  T.check(type(mewObject) == "table", "Mew object present")
  T.eq(mewObject.index, 7, "object index 7 (matches the disappear arg)")
  T.eq(mewObject.sprite, "SPRITE_MEW", "SPRITE_MEW overworld art")
  T.eq(mewObject.eventFlag, 1940, "object hidden while EVENT_ROUTE_24_MEW is SET")
  T.eq(mewObject.scriptKey, mew.scriptKey, "object runs the MewScript battle script")
  T.eq(mewObject.palette, 4, "PAL_NPC_PINK slot (CL Route24 object)")
  T.eq(mewObject.x, 8, "object at Route 24 x 8")
  T.eq(mewObject.y, 12, "object at Route 24 y 12")
  T.eq(mewObject.movement, 0x16, "SPRITEMOVEDATA_POKEMON (CL)")
  local mewScript = scripts[mew.scriptKey]
  T.check(type(mewScript) == "table", "Mew battle script registered")
  local mewOps = {}
  for _, step in ipairs(mewScript or {}) do
    mewOps[#mewOps + 1] = step.op
  end
  T.eq(mewOps[1], "opentext", "MewScript opens with text (CL maps/Route24.asm)")
  T.eq(mewOps[2], "writetext", "writes the battle text")
  T.eq(mewScript[2].text, mew.textKey, "text key matches the registered row")
  T.eq(mewOps[3], "cry", "cry plays")
  T.eq(mewScript[3].species, 151, "cry for Mew")
  T.eq(mewOps[6], "loadwildmon", "loadwildmon row present")
  T.eq(mewScript[6].species, 151, "loadwildmon Mew")
  T.eq(mewScript[6].level, 60, "loadwildmon L60")
  T.eq(mewOps[8], "disappear", "Mew disappears after the battle")
  T.eq(mewScript[8].object, 7, "disappears the Route 24 object")
  T.eq(mewScript[9].op, "setevent", "re-sets EVENT_ROUTE_24_MEW (stays hidden)")
  T.eq(mewScript[9].event, 1940, "setevent MEW flag")
  T.eq(mewScript[10].op, "setevent", "sets the caught flag (no re-release)")
  T.eq(mewScript[10].event, 1941, "setevent MEW_CAUGHT flag")
  T.eq(mewOps[#mewOps], "end", "MewScript ends cleanly")
  T.eq(run.loader.content.text:get(mew.textKey), "Myuu...",
    "battle text registered verbatim (CL MewBattleText)")
end

-- ---- Phase 3c: Kanto legendary birds ------------------------------------
-- CL releases each bird as a one-time L60 wild encounter after its quest
-- moment; gold has none of it.  CL's event is one EVENT_CAUGHT_<BIRD> flag
-- per bird, seeded SET at NewGame (bird hidden), cleared by the release
-- splice (bird appears), set again by the catch script (bird gone).  All
-- three visible objects spawn: Moltres reuses gold's SPRITE_MOLTRES, and
-- Phase 4b added SPRITE_ARTICUNO/SPRITE_ZAPDOS overworld art (data/sprites
-- .lua, converted from CL gfx/sprites/).
local birds = staticsData.birds
T.check(type(birds) == "table", "statics data file carries the birds section")
T.eq(#birds, 3, "three birds wired (Moltres, Articuno, Zapdos)")
local birdsById = {}
for _, bird in ipairs(birds or {}) do
  birdsById[bird.id] = bird
end

-- CL facts, verbatim (speciesIndex is gold's dex-order id).
local moltres = birdsById.moltres
T.check(type(moltres) == "table", "Moltres section present")
T.eq(moltres.speciesIndex, 146, "Moltres species 146")
T.eq(moltres.level, 60, "Moltres is L60")
T.eq(moltres.mapId, "VICTORY_ROAD", "Moltres spawns on Victory Road")
T.eq(moltres.coords.x, 18, "Victory Road tile x 18 (CL)")
T.eq(moltres.coords.y, 32, "Victory Road tile y 32 (CL)")
T.eq(moltres.flag, 1942, "EVENT_CAUGHT_MOLTRES (free in gold's space)")
T.eq(moltres.faceplayer, false, "CL's MoltresScript has no faceplayer")
T.eq(moltres.text, "Gyaoo!", "MoltresBattleText verbatim")
local articuno = birdsById.articuno
T.check(type(articuno) == "table", "Articuno section present")
T.eq(articuno.speciesIndex, 144, "Articuno species 144")
T.eq(articuno.level, 60, "Articuno is L60")
T.eq(articuno.mapId, "ROUTE_20", "Articuno spawns on Route 20")
T.eq(articuno.coords.x, 31, "Route 20 tile x 31 (CL)")
T.eq(articuno.coords.y, 11, "Route 20 tile y 11 (CL)")
T.eq(articuno.flag, 1943, "EVENT_CAUGHT_ARTICUNO (free in gold's space)")
T.eq(articuno.faceplayer, false, "CL's ArticunoScript has no faceplayer")
T.eq(articuno.text, "Gyaoo!", "ArticunoBattleText verbatim")
local zapdos = birdsById.zapdos
T.check(type(zapdos) == "table", "Zapdos section present")
T.eq(zapdos.speciesIndex, 145, "Zapdos species 145")
T.eq(zapdos.level, 60, "Zapdos is L60")
T.eq(zapdos.mapId, "ROUTE_10_NORTH", "Zapdos spawns on Route 10 North")
T.eq(zapdos.coords.x, 4, "Route 10 North tile x 4 (CL)")
T.eq(zapdos.coords.y, 11, "Route 10 North tile y 11 (CL)")
T.eq(zapdos.flag, 1944, "EVENT_CAUGHT_ZAPDOS (free in gold's space)")
T.eq(zapdos.faceplayer, true, "CL's ZapdosScript starts with faceplayer")
T.eq(zapdos.text, "Gyaoo!", "ZapdosBattleText verbatim")

-- Catch scripts: CL's verbatim flow (cry / loadwildmon 60 / startbattle /
-- disappear / setevent / reloadmapafterbattle), text "Gyaoo!" registered.
local function birdScript(bird)
  local rows = scripts[bird.scriptKey]
  T.check(type(rows) == "table", bird.id .. " catch script registered")
  return rows
end
local moltresRows = birdScript(moltres)
T.eq(moltresRows[1].op, "opentext", "Moltres: opens text first (no faceplayer)")
T.eq(moltresRows[2].op, "writetext", "Moltres: battle text")
T.eq(moltresRows[2].text, moltres.textKey, "Moltres: text key points at the cry")
T.eq(moltresRows[3].op, "cry", "Moltres: cry")
T.eq(moltresRows[3].id, 146, "Moltres: cries as species 146")
T.eq(moltresRows[6].op, "loadwildmon", "Moltres: loadwildmon")
T.eq(moltresRows[6].species, 146, "Moltres: species 146")
T.eq(moltresRows[6].level, 60, "Moltres: L60")
T.eq(moltresRows[7].op, "startbattle", "Moltres: startbattle")
T.eq(moltresRows[8].op, "disappear", "Moltres: disappears after the fight")
T.eq(moltresRows[8].object, 7, "Moltres: hides the Victory Road object (index 7)")
T.eq(moltresRows[9].op, "setevent", "Moltres: sets the caught flag")
T.eq(moltresRows[9].event, 1942, "Moltres: EVENT_CAUGHT_MOLTRES")
T.eq(moltresRows[10].op, "reloadmapafterbattle", "Moltres: reload after battle")
T.eq(moltresRows[#moltresRows].op, "end", "Moltres: script ends cleanly")
local articunoRows = birdScript(articuno)
T.eq(articunoRows[1].op, "opentext", "Articuno: opens text first (no faceplayer)")
T.eq(articunoRows[3].id, 144, "Articuno: cries as species 144")
T.eq(articunoRows[6].species, 144, "Articuno: species 144")
T.eq(articunoRows[6].level, 60, "Articuno: L60")
T.eq(articunoRows[8].object, 4, "Articuno: hides the Route 20 object (index 4)")
T.eq(articunoRows[9].event, 1943, "Articuno: EVENT_CAUGHT_ARTICUNO")
local zapdosRows = birdScript(zapdos)
T.eq(zapdosRows[1].op, "faceplayer", "Zapdos: faces the player first (CL)")
T.eq(zapdosRows[4].id, 145, "Zapdos: cries as species 145")
T.eq(zapdosRows[7].op, "loadwildmon", "Zapdos: loadwildmon (faceplayer shifts rows)")
T.eq(zapdosRows[7].species, 145, "Zapdos: species 145")
T.eq(zapdosRows[7].level, 60, "Zapdos: L60")
T.eq(zapdosRows[9].op, "disappear", "Zapdos: disappears after the fight")
T.eq(zapdosRows[9].object, 7, "Zapdos: hides the Route 10 North object (index 7)")
T.eq(zapdosRows[10].event, 1944, "Zapdos: EVENT_CAUGHT_ZAPDOS")

-- Release seams: the clearevent lands right after each quest's anchor row.
local function seamRow(bird, seam, birdIdx)
  local row = scripts[seam.scriptKey]
  local pos
  for i, step in ipairs(row) do
    if step.op == seam.afterOp
      and (seam.afterEvent == nil or step.event == seam.afterEvent) then
      pos = i
      break
    end
  end
  T.check(type(pos) == "number", bird.id .. ": seam anchor found in " .. seam.scriptKey)
  local after = row[pos + 1]
  T.eq(after.op, "clearevent", bird.id .. ": clearevent right after the anchor")
  T.eq(after.event, bird.flag, bird.id .. ": clears EVENT_CAUGHT_" .. bird.id:upper())
  return after
end
local blaineSeam = moltres.seams[1]
T.eq(blaineSeam.scriptKey, "53:5188", "Moltres seam is Blaine's win path")
local blueSeam = articuno.seams[1]
T.eq(blueSeam.scriptKey, "5f:4002", "Articuno seam is Blue")
local zapSeam = zapdos.seams[1]
T.eq(zapSeam.scriptKey, "54:4deb", "Zapdos seam is the manager's FoundMachinePart")
seamRow(moltres, blaineSeam)
seamRow(articuno, blueSeam)
seamRow(zapdos, zapSeam)

-- The Zapdos clearevent sits after RESTORED_POWER (setevent 1900), not after
-- the badge — CL's PowerPlant.asm puts it there, between the RESTORED_POWER
-- setevent and the TM07 hand-out.
local zapRow = scripts["54:4deb"]
local afterPower
for i, step in ipairs(zapRow) do
  if step.op == "setevent" and step.event == 1900 then afterPower = zapRow[i + 1] end
end
T.eq(afterPower.op, "clearevent", "Zapdos: released the moment power is restored")
T.eq(afterPower.event, 1944, "Zapdos: clears EVENT_CAUGHT_ZAPDOS")

-- New-game seeding: the bird flags join gold's initial events so a fresh
-- save starts with all three birds hidden.
local initial = data.gen2InitialEvents
T.check(type(initial) == "table" and type(initial.flags) == "table",
  "gen2InitialEvents present after the load")
local seen = {}
for _, id in ipairs(initial.flags or {}) do seen[id] = true end
T.eq(seen[1942], true, "Moltres flag seeded at NewGame")
T.eq(seen[1943], true, "Articuno flag seeded at NewGame")
T.eq(seen[1944], true, "Zapdos flag seeded at NewGame")

-- Visible object: only Moltres spawns now (gold ships SPRITE_MOLTRES); it is
-- the 7th object on VICTORY_ROAD, hidden while flag 1942 is SET.
local victoryRoad = data.gen2Maps.VICTORY_ROAD
T.check(type(victoryRoad) == "table" and type(victoryRoad.objects) == "table",
  "VICTORY_ROAD survives the load")
T.eq(#victoryRoad.objects, 7, "Moltres appended as the 7th Victory Road object")
local moltresObject = victoryRoad.objects[7]
T.check(type(moltresObject) == "table", "Moltres object present")
T.eq(moltresObject.index, 7, "object index 7 (matches the disappear arg)")
T.eq(moltresObject.sprite, "SPRITE_MOLTRES", "SPRITE_MOLTRES overworld art")
T.eq(moltresObject.eventFlag, 1942, "object hidden while EVENT_CAUGHT_MOLTRES is SET")
T.eq(moltresObject.scriptKey, moltres.scriptKey, "object runs the catch script")
T.eq(moltresObject.x, 18, "object at Victory Road x 18")
T.eq(moltresObject.y, 32, "object at Victory Road y 32")
T.eq(moltresObject.movement, 0x16, "SPRITEMOVEDATA_POKEMON (CL)")
-- Phase 4b: Articuno and Zapdos objects spawn too (art now ships via
-- data/sprites.lua registrations; CL palettes: articuno PAL_NPC_BLUE (id 1),
-- zapdos PAL_NPC_BROWN (id 3)).
do
  local route20 = data.gen2Maps.ROUTE_20
  T.check(type(route20) == "table" and type(route20.objects) == "table",
    "ROUTE_20 survives the load")
  T.eq(#route20.objects, 4, "Articuno appended as the 4th Route 20 object")
  local articunoObject = route20.objects[4]
  T.check(type(articunoObject) == "table", "Articuno object present")
  T.eq(articunoObject.index, 4, "object index 4 (matches the disappear arg)")
  T.eq(articunoObject.sprite, "SPRITE_ARTICUNO", "SPRITE_ARTICUNO overworld art")
  T.eq(articunoObject.eventFlag, 1943, "object hidden while EVENT_CAUGHT_ARTICUNO is SET")
  T.eq(articunoObject.scriptKey, articuno.scriptKey, "object runs the catch script")
  T.eq(articunoObject.palette, 1, "PAL_NPC_BLUE (CL Route20 object)")
  T.eq(articunoObject.x, 31, "object at Route 20 x 31")
  T.eq(articunoObject.y, 11, "object at Route 20 y 11")
  T.eq(articunoObject.movement, 0x16, "SPRITEMOVEDATA_POKEMON (CL)")
  local route10N = data.gen2Maps.ROUTE_10_NORTH
  T.check(type(route10N) == "table" and type(route10N.objects) == "table",
    "ROUTE_10_NORTH survives the load")
  T.eq(#route10N.objects, 7, "Zapdos appended as the 7th Route 10 North object")
  local zapdosObject = route10N.objects[7]
  T.check(type(zapdosObject) == "table", "Zapdos object present")
  T.eq(zapdosObject.index, 7, "object index 7 (matches the disappear arg)")
  T.eq(zapdosObject.sprite, "SPRITE_ZAPDOS", "SPRITE_ZAPDOS overworld art")
  T.eq(zapdosObject.eventFlag, 1944, "object hidden while EVENT_CAUGHT_ZAPDOS is SET")
  T.eq(zapdosObject.scriptKey, zapdos.scriptKey, "object runs the catch script")
  T.eq(zapdosObject.palette, 3, "PAL_NPC_BROWN (CL Route10North object)")
  T.eq(zapdosObject.x, 4, "object at Route 10 North x 4")
  T.eq(zapdosObject.y, 11, "object at Route 10 North y 11")
  T.eq(zapdosObject.movement, 0x16, "SPRITEMOVEDATA_POKEMON (CL)")
end

-- ---- Phase 4b: overworld sprite registrations -----------------------------
-- Six CL-derived sprites registered globally into target.gen2Sprites (the
-- engine resolves objects via gen2Sprites[objDef.sprite]).  Birds are 16x96
-- walking sheets; the four pokemon-range sprites are 16x32 POKEMON_SPRITE
-- icons (how CL's own engine renders them, LoadOverworldMonIcon).
local function spriteDef(id)
  local def = data.gen2Sprites and data.gen2Sprites[id]
  T.check(type(def) == "table", id .. " registered in gen2Sprites")
  return def
end
do
  local articunoDef = spriteDef("SPRITE_ARTICUNO")
  T.eq(articunoDef.image, "assets/sprites/articuno.png", "Articuno ships the CL sheet")
  T.eq(articunoDef.frames, 6, "Articuno: 6 frames (16x96 walking sheet)")
  T.eq(articunoDef.walker, true, "Articuno: walker")
  T.eq(articunoDef.paletteId, 1, "Articuno: PAL_OW_BLUE (CL sprites.asm)")
  T.eq(articunoDef.spriteType, "WALKING_SPRITE", "Articuno: walking sprite type")
  local zapdosDef = spriteDef("SPRITE_ZAPDOS")
  T.eq(zapdosDef.image, "assets/sprites/zapdos.png", "Zapdos ships the CL sheet")
  T.eq(zapdosDef.frames, 6, "Zapdos: 6 frames (16x96 walking sheet)")
  T.eq(zapdosDef.walker, true, "Zapdos: walker")
  T.eq(zapdosDef.paletteId, 3, "Zapdos: PAL_OW_BROWN (CL sprites.asm)")
  T.eq(zapdosDef.spriteType, "WALKING_SPRITE", "Zapdos: walking sprite type")
  local mewDef = spriteDef("SPRITE_MEW")
  T.eq(mewDef.image, "assets/sprites/mew.png", "Mew ships the CL icon")
  T.eq(mewDef.frames, 1, "Mew: static icon (POKEMON_SPRITE)")
  T.eq(mewDef.walker, false, "Mew: not a walker")
  T.eq(mewDef.paletteId, 4, "Mew: PAL_NPC_PINK slot (CL Route24 object)")
  T.eq(mewDef.spriteType, "POKEMON_SPRITE", "Mew: pokemon sprite type")
  T.eq(mewDef.species, "MEW", "Mew: species tagged")
  local celebiDef = spriteDef("SPRITE_CELEBI")
  T.eq(celebiDef.image, "assets/sprites/celebi.png", "Celebi ships the CL icon")
  T.eq(celebiDef.frames, 1, "Celebi: static icon (POKEMON_SPRITE)")
  T.eq(celebiDef.paletteId, 2, "Celebi: PAL_OW_GREEN slot (menu-icon palette)")
  T.eq(celebiDef.spriteType, "POKEMON_SPRITE", "Celebi: pokemon sprite type")
  local electrodeDef = spriteDef("SPRITE_ELECTRODE")
  T.eq(electrodeDef.image, "assets/sprites/electrode.png", "Electrode ships the CL icon")
  T.eq(electrodeDef.frames, 1, "Electrode: static icon (POKEMON_SPRITE)")
  T.eq(electrodeDef.paletteId, 0, "Electrode: PAL 0 (CL RocketBaseB2F)")
  T.eq(electrodeDef.spriteType, "POKEMON_SPRITE", "Electrode: pokemon sprite type")
  local murkrowDef = spriteDef("SPRITE_MURKROW")
  T.eq(murkrowDef.image, "assets/sprites/murkrow.png", "Murkrow ships the CL icon")
  T.eq(murkrowDef.frames, 1, "Murkrow: static icon (POKEMON_SPRITE)")
  T.eq(murkrowDef.paletteId, 1, "Murkrow: PAL_NPC_BLUE (CL RocketBaseB3F)")
  T.eq(murkrowDef.spriteType, "POKEMON_SPRITE", "Murkrow: pokemon sprite type")
end

-- ---- Phase 3c: Celebi / GS Ball chain -----------------------------------
-- Full Crystal chain mod-side (gold ships none of it): GS_BALL item at 251,
-- Pokecenter receptionist gift, Kurt hand-off (7-badge gate), Ilex shrine
-- battle, Ruins of Alph fallback.  CL's Azalea return scene is simplified
-- away (Kurt returns the ball in-house and sets the forest restless).
local celebi = staticsData.celebi
T.check(type(celebi) == "table", "statics data file carries the celebi section")
T.eq(celebi.speciesIndex, 251, "Celebi species id 251 (dex order)")
T.eq(celebi.level, 30, "Celebi is L30 (CL loadwildmon CELEBI, 30)")
T.eq(celebi.badgeGate, 7, "Kurt hand-off gates on 7 badges")

-- (a) GS_BALL item def at index 251 (free — gold's max is 250); MYSTERY_EGG
-- row shape (KEY_ITEM, no menu use either way, not tossable, price 0).
local gsBall = data.items and data.items.GS_BALL
T.check(type(gsBall) == "table", "GS_BALL item def injected")
T.eq(gsBall.index, 251, "GS_BALL sits at index 251 (free in gold's space)")
T.eq(gsBall.id, "GS_BALL", "GS_BALL registered under its own id")
T.eq(gsBall.pocket, "KEY_ITEM", "GS_BALL lives in the KEY_ITEM pocket")
T.eq(gsBall.pocketId, 2, "KEY_ITEM pocket id 2")
T.eq(gsBall.price, 0, "GS_BALL is price 0")
T.eq(gsBall.canToss, false, "GS_BALL cannot be tossed")
T.eq(gsBall.canSelect, false, "GS_BALL has no menu selection")
T.eq(gsBall.battleMenu, "ITEMMENU_NOUSE", "GS_BALL has no battle use")
T.eq(gsBall.fieldMenu, "ITEMMENU_NOUSE", "GS_BALL has no field use")
T.eq(gsBall.heldEffect, "HELD_NONE", "GS_BALL carries no held effect")

-- Flags 1945-48: all free in gold's space (birds hold 1942-44).
T.eq(celebi.flags.restless, 1945, "EVENT_FOREST_IS_RESTLESS")
T.eq(celebi.flags.canGive, 1946, "EVENT_CAN_GIVE_GS_BALL_TO_KURT")
T.eq(celebi.flags.gave, 1947, "EVENT_GAVE_GS_BALL_TO_KURT")
T.eq(celebi.flags.got, 1948, "EVENT_GOT_GS_BALL_FROM_POKECOM_CENTER")

-- (b) The gift: a LINK_RECEPTIONIST appended as the 5th Goldenrod Pokecenter
-- object (gold has 4), always visible, running the mod-owned gift script.
local pc = data.gen2Maps and data.gen2Maps.GOLDENROD_POKECENTER_1F
T.check(type(pc) == "table" and type(pc.objects) == "table",
  "GOLDENROD_POKECENTER_1F survives the load")
T.eq(#pc.objects, 5, "receptionist appended as the 5th Pokecenter object")
local receptionist = pc.objects[5]
T.check(type(receptionist) == "table", "receptionist object present")
T.eq(receptionist.index, 5, "object index 5 (matches the gift script)")
T.eq(receptionist.sprite, "SPRITE_LINK_RECEPTIONIST", "receptionist sprite")
T.eq(receptionist.eventFlag, 65535, "always visible (in-script gates)")
T.eq(receptionist.scriptKey, celebi.scriptKeys.gift, "object runs the gift script")
T.eq(receptionist.x, 2, "receptionist at Pokecenter x 2")
T.eq(receptionist.y, 5, "receptionist at Pokecenter y 5")
T.eq(receptionist.movement, 6, "STANDING_DOWN (CL)")
local giftRows = scripts[celebi.scriptKeys.gift]
T.check(type(giftRows) == "table", "gift script registered")
T.eq(giftRows[1].op, "faceplayer", "gift: faces the player")
local giftGives
for _, step in ipairs(giftRows) do
  if step.op == "verbosegiveitem" then giftGives = step.item end
end
T.eq(giftGives, 251, "gift hands over the GS BALL (index 251)")
local giftSetsGot, giftSetsCanGive
for _, step in ipairs(giftRows) do
  if step.op == "setevent" then
    if step.event == 1948 then giftSetsGot = true end
    if step.event == 1946 then giftSetsCanGive = true end
  end
end
T.check(giftSetsGot, "gift sets EVENT_GOT_GS_BALL_FROM_POKECOM_CENTER")
T.check(giftSetsCanGive, "gift sets EVENT_CAN_GIVE_GS_BALL_TO_KURT")

-- (c) Kurt: two checkevent/iftrue rows spliced right after his opentext,
-- branching to the mod's give/gave scripts; the vanilla apricorn flow is
-- preserved further down.
local kurtRows = scripts[celebi.kurt.scriptKey]
T.check(type(kurtRows) == "table", "Kurt script survives the load")
local kurtOpenPos
for i, step in ipairs(kurtRows) do
  if step.op == "opentext" then kurtOpenPos = i break end
end
T.check(type(kurtOpenPos) == "number", "Kurt opentext row found")
T.eq(kurtRows[kurtOpenPos + 1].op, "checkevent", "splice row 1: checkevent")
T.eq(kurtRows[kurtOpenPos + 1].event, 1947, "splice row 1 checks EVENT_GAVE_GS_BALL_TO_KURT")
T.eq(kurtRows[kurtOpenPos + 2].op, "iftrue", "splice row 2: iftrue")
T.eq(kurtRows[kurtOpenPos + 2].script, celebi.scriptKeys.kurtGave, "splice row 2 -> kurtGave")
T.eq(kurtRows[kurtOpenPos + 3].op, "checkevent", "splice row 3: checkevent")
T.eq(kurtRows[kurtOpenPos + 3].event, 1946, "splice row 3 checks EVENT_CAN_GIVE_GS_BALL_TO_KURT")
T.eq(kurtRows[kurtOpenPos + 4].op, "iftrue", "splice row 4: iftrue")
T.eq(kurtRows[kurtOpenPos + 4].script, celebi.scriptKeys.kurtGive, "splice row 4 -> kurtGive")
local kurtGiveRows = scripts[celebi.scriptKeys.kurtGive]
T.check(type(kurtGiveRows) == "table", "kurtGive script registered")
local badgeGate, kurtTakes
for _, step in ipairs(kurtGiveRows) do
  if step.op == "readvar" then badgeGate = step.var end
  if step.op == "takeitem" then kurtTakes = step.item end
end
T.eq(badgeGate, 0x07, "kurtGive gates on VAR_BADGES")
T.eq(kurtTakes, 251, "kurtGive takes the GS BALL")
local kurtGaveRows = scripts[celebi.scriptKeys.kurtGave]
T.check(type(kurtGaveRows) == "table", "kurtGave script registered")
local setsRestless, givesBack
for _, step in ipairs(kurtGaveRows) do
  if step.op == "setevent" and step.event == 1945 then setsRestless = true end
  if step.op == "verbosegiveitem" then givesBack = step.item end
end
T.check(setsRestless, "kurtGave sets EVENT_FOREST_IS_RESTLESS")
T.eq(givesBack, 251, "kurtGave returns the ball (simplified in-house return)")

-- (d) Ilex shrine: the (8,22) bg_event repointed to the shrine script; quiet
-- gold text until restless, then checkitem -> yesorno -> takeitem -> L30
-- Celebi wild battle (no SPRITE_CELEBI needed — wild battle).
local ilex = data.gen2Maps and data.gen2Maps.ILEX_FOREST
T.check(type(ilex) == "table" and type(ilex.bgEvents) == "table",
  "ILEX_FOREST survives the load")
local shrineBg
for _, bg in ipairs(ilex.bgEvents) do
  if bg.x == 8 and bg.y == 22 then shrineBg = bg end
end
T.check(type(shrineBg) == "table", "shrine bg_event present at (8,22)")
T.eq(shrineBg.scriptKey, celebi.scriptKeys.shrine, "shrine bg_event repointed to the shrine script")
local shrineRows = scripts[celebi.scriptKeys.shrine]
T.check(type(shrineRows) == "table", "shrine script registered")
T.eq(shrineRows[1].op, "checkevent", "shrine: quiet until restless")
T.eq(shrineRows[1].event, 1945, "shrine: checks EVENT_FOREST_IS_RESTLESS")
local shrineBattleRows = scripts[celebi.scriptKeys.shrineBattle]
T.check(type(shrineBattleRows) == "table", "shrine battle script registered")
local takesBall, wildCelebi
for _, step in ipairs(shrineBattleRows) do
  if step.op == "takeitem" then takesBall = step.item end
  if step.op == "loadwildmon" then wildCelebi = step end
end
T.eq(takesBall, 251, "shrine consumes the GS BALL")
T.check(type(wildCelebi) == "table", "shrine loads a wild mon")
T.eq(wildCelebi.species, 251, "wild Celebi species 251")
T.eq(wildCelebi.level, 30, "wild Celebi L30")

-- (e) Ruins of Alph fallback: a RESEARCHER appended as the 4th Inner Chamber
-- object (gold has 3 flavor NPCs) offering the ball if never gotten.
local ruins = data.gen2Maps and data.gen2Maps.RUINS_OF_ALPH_INNER_CHAMBER
T.check(type(ruins) == "table" and type(ruins.objects) == "table",
  "RUINS_OF_ALPH_INNER_CHAMBER survives the load")
T.eq(#ruins.objects, 4, "researcher appended as the 4th Inner Chamber object")
local researcher = ruins.objects[4]
T.check(type(researcher) == "table", "researcher object present")
T.eq(researcher.index, 4, "object index 4 (matches the fallback script)")
T.eq(researcher.sprite, "SPRITE_SCIENTIST", "researcher sprite")
T.eq(researcher.eventFlag, 65535, "always visible (in-script gates)")
T.eq(researcher.scriptKey, celebi.scriptKeys.fallback, "object runs the fallback script")
T.eq(researcher.x, 17, "researcher at Inner Chamber x 17")
T.eq(researcher.y, 23, "researcher at Inner Chamber y 23")
local fallbackRows = scripts[celebi.scriptKeys.fallback]
T.check(type(fallbackRows) == "table", "fallback script registered")
local fallbackGives, fallbackSetsGot
for _, step in ipairs(fallbackRows) do
  if step.op == "verbosegiveitem" then fallbackGives = step.item end
  if step.op == "setevent" and step.event == 1948 then fallbackSetsGot = true end
end
T.eq(fallbackGives, 251, "fallback offers the GS BALL")
T.check(fallbackSetsGot, "fallback sets EVENT_GOT_GS_BALL_FROM_POKECOM_CENTER")

-- Texts: all CL dialogue rows land in data.gen2Text under the mod prefix.
for key, text in pairs(celebi.texts or {}) do
  T.eq(data.gen2Text["crystal_legacy_changes:celebi_" .. key], text,
    "celebi text row registered: " .. key)
end

-- ---- Phase 3a: fossils + Ruins of Alph --------------------------------
local fossilsData = dofile("mods/crystal_legacy_changes/data/fossils.lua")
local fossils = export.fossils
T.check(type(fossils) == "table", "exports carry the fossils section")

-- Items: registered, inert gold-shaped items at the CL indices (above the
-- ROM's max of 250 -- the ROM renumbered the item table and dropped the
-- fossils entirely, so these are brand-new records).
local domeItem = data.items and data.items.DOME_FOSSIL
T.check(type(domeItem) == "table", "DOME_FOSSIL registered as an item")
T.eq(domeItem.index, 251, "DOME_FOSSIL sits at index 251")
T.eq(domeItem.pocketId, 1, "DOME_FOSSIL lives in the ITEMS pocket")
T.eq(domeItem.price, 0, "DOME_FOSSIL is price 0")
T.eq(domeItem.canSelect, false, "DOME_FOSSIL cannot be selected")
T.eq(domeItem.canToss, true, "DOME_FOSSIL is tossable")
T.eq(domeItem.battleMenu, "ITEMMENU_NOUSE", "DOME_FOSSIL has no battle use")
T.eq(domeItem.fieldMenu, "ITEMMENU_NOUSE", "DOME_FOSSIL has no field use")
T.eq(domeItem.heldEffect, "HELD_NONE", "DOME_FOSSIL carries no held effect")
local helixItem = data.items and data.items.HELIX_FOSSIL
T.check(type(helixItem) == "table", "HELIX_FOSSIL registered as an item")
T.eq(helixItem.index, 252, "HELIX_FOSSIL sits at index 252")
T.eq(helixItem.pocketId, 1, "HELIX_FOSSIL lives in the ITEMS pocket")
T.eq(helixItem.price, 0, "HELIX_FOSSIL is price 0")
T.eq(helixItem.canSelect, false, "HELIX_FOSSIL cannot be selected")
T.eq(helixItem.canToss, true, "HELIX_FOSSIL is tossable")
T.eq(helixItem.battleMenu, "ITEMMENU_NOUSE", "HELIX_FOSSIL has no battle use")
T.eq(helixItem.fieldMenu, "ITEMMENU_NOUSE", "HELIX_FOSSIL has no field use")
T.eq(helixItem.heldEffect, "HELD_NONE", "HELIX_FOSSIL carries no held effect")
local amberItem = data.items and data.items.OLD_AMBER
T.check(type(amberItem) == "table", "OLD_AMBER registered as an item")
T.eq(amberItem.index, 253, "OLD_AMBER sits at index 253")
T.eq(amberItem.pocketId, 1, "OLD_AMBER lives in the ITEMS pocket")
T.eq(amberItem.price, 0, "OLD_AMBER is price 0")
T.eq(amberItem.canSelect, false, "OLD_AMBER cannot be selected")
T.eq(amberItem.canToss, true, "OLD_AMBER is tossable")
T.eq(amberItem.battleMenu, "ITEMMENU_NOUSE", "OLD_AMBER has no battle use")
T.eq(amberItem.fieldMenu, "ITEMMENU_NOUSE", "OLD_AMBER has no field use")
T.eq(amberItem.heldEffect, "HELD_NONE", "OLD_AMBER carries no held effect")
T.eq(export.rebalance.fossils.items, 3, "exports report the three fossil items")

-- Text rows land in data.gen2Text under the mod prefix.
for key, text in pairs(fossilsData.text or {}) do
  T.eq(data.gen2Text["crystal_legacy_changes:" .. key], text,
    "text row registered: " .. key)
end

-- Commands are merged into the table the VM dispatches (runModCommand).
T.check(type(data.commands) == "table", "commands table merged on Gold")
for _, verb in ipairs({
  "crystal_legacy_changes:revive_fossil",
  "crystal_legacy_changes:ruins_reward",
  "crystal_legacy_changes:ruins_deferred",
}) do
  T.check(type(data.commands[verb]) == "function", "command registered: " .. verb)
end
T.eq(export.rebalance.fossils.commands, 3, "exports report the three commands")

-- The scientist script row is replaced by a straight command run.
local scientistScript = scripts["44:4ac6"]
T.check(type(scientistScript) == "table", "scientist script row replaced")
local reviveRows = 0
for _, step in ipairs(scientistScript) do
  if type(step) == "table" and step[1] == "crystal_legacy_changes:revive_fossil" then
    reviveRows = reviveRows + 1
  end
end
T.eq(reviveRows, 1, "scientist talks to the revival command")

-- Chamber solved sequences carry the reward arm after the event flags.
local function rewardChamberOf(key)
  local chamber
  for _, step in ipairs(scripts[key] or {}) do
    if type(step) == "table" and step[1] == "crystal_legacy_changes:ruins_reward" then
      chamber = step[2]
    end
  end
  return chamber
end
T.eq(rewardChamberOf("44:44ea"), "KABUTO", "KABUTO solve rewards")
T.eq(rewardChamberOf("44:4692"), "OMANYTE", "OMANYTE solve rewards")
T.eq(rewardChamberOf("44:476c"), "AERODACTYL", "AERODACTYL solve rewards")
T.eq(export.rebalance.fossils.scripts, 7,
  "exports report 7 script patches (scientist + 3 solves + 3 callbacks)")

-- Callbacks carry the deferred-claim arm first.
local function deferredChamberOf(key)
  local step = (scripts[key] or {})[1]
  if type(step) == "table" and step[1] == "crystal_legacy_changes:ruins_deferred" then
    return step[2]
  end
end
T.eq(deferredChamberOf("44:44ce"), "KABUTO", "KABUTO callback claims")
T.eq(deferredChamberOf("44:4676"), "OMANYTE", "OMANYTE callback claims")
T.eq(deferredChamberOf("44:4750"), "AERODACTYL", "AERODACTYL callback claims")

-- Behavior: drive the handlers against a stub game + vm (headless).  The vm
-- mirrors the World's hook closures (dot-called, index-based), mod.save backs
-- the one-per-save flags, mod.game is the injected stub.
local function fakeVm(inventory)
  local state = { given = nil }
  return {
    inventory = inventory,
    seen = {},
    state = state,
    showText = function(self, key) self.seen[#self.seen + 1] = key end,
    hasItemFn = function(idx) return inventory[idx] ~= nil end,
    takeItemFn = function(idx) inventory[idx] = nil end,
    giveItemFn = function(idx, qty)
      inventory[idx] = (inventory[idx] or 0) + (qty or 1)
      return true
    end,
    givePokeFn = function(species, level, item)
      state.given = { species = species, level = level, item = item }
    end,
  }
end
local function stubSave(badges, engineFlags, partySize)
  local party = {}
  for i = 1, partySize or 0 do party[i] = { species = "PICHU" } end
  return {
    player = { badges = badges or {} },
    engineFlags = engineFlags or {},
    party = party,
  }
end
local function withGame(save)
  run.loader.game = { save = save }
end
local function clearSaveFlags()
  run.loader.modSave["crystal_legacy_changes"] = {}
end

-- Scientist: no fossil -> greet + none, nothing revived.
local vm = fakeVm({})
withGame(stubSave({}, {}, 0))
fossils.revive({ vm = vm })
T.eq(vm.seen[1], "crystal_legacy_changes:revive_greet", "scientist greets first")
T.eq(vm.seen[2], "crystal_legacy_changes:revive_none", "no fossil -> none text")
T.eq(vm.state.given, nil, "no fossil: nothing revived")

-- Scientist: Dome Fossil -> Kabuto L15, fossil consumed.
vm = fakeVm({ [251] = 1 })
withGame(stubSave({}, {}, 0))
fossils.revive({ vm = vm })
T.eq(vm.seen[2], "crystal_legacy_changes:revive_kabuto", "Dome -> Kabuto intro")
T.eq(vm.seen[3], "crystal_legacy_changes:got_kabuto", "Dome -> received text")
T.eq(vm.inventory[251], nil, "Dome Fossil consumed on revival")
T.check(type(vm.state.given) == "table", "a mon is given")
T.eq(vm.state.given.species, 140, "Kabuto species index 140")
T.eq(vm.state.given.level, 15, "Kabuto level 15 (post-Gym 3)")
T.eq(vm.state.given.item, nil, "revived mon carries no held item")

-- Scientist: Helix -> Omanyte L20, Old Amber -> Aerodactyl L25.
vm = fakeVm({ [252] = 1 })
withGame(stubSave({}, {}, 0))
fossils.revive({ vm = vm })
T.eq(vm.state.given.species, 138, "Omanyte species index 138")
T.eq(vm.state.given.level, 20, "Omanyte level 20 (post-Gym 4)")
vm = fakeVm({ [253] = 1 })
withGame(stubSave({}, {}, 0))
fossils.revive({ vm = vm })
T.eq(vm.state.given.species, 142, "Aerodactyl species index 142")
T.eq(vm.state.given.level, 25, "Aerodactyl level 25 (post-Gym 7)")

-- Scientist: full party -> fossil kept, nothing revived.  (The engine's
-- World:givePoke ignores Party.add's return, so the mod must check first.)
vm = fakeVm({ [252] = 1 })
withGame(stubSave({}, {}, 6))
fossils.revive({ vm = vm })
T.eq(vm.seen[2], "crystal_legacy_changes:revive_party_full",
  "full party -> party full text")
T.eq(vm.inventory[252], 1, "fossil kept at a full party")
T.eq(vm.state.given, nil, "full party: nothing revived")

-- Puzzle reward: badge-gated and one-per-save.
clearSaveFlags()
vm = fakeVm({})
withGame(stubSave({}, { [673] = true }, 0))
fossils.reward({ vm = vm }, "KABUTO")
T.eq(#vm.seen, 0, "no badge: no reward text")
T.eq(vm.inventory[251], nil, "no badge: no fossil given")
vm = fakeVm({})
withGame(stubSave({ PLAIN = true }, { [673] = true }, 0))
fossils.reward({ vm = vm }, "KABUTO")
T.eq(vm.seen[1], "crystal_legacy_changes:ruins_got_kabuto",
  "reward text on solve with badge")
T.eq(vm.inventory[251], 1, "Dome Fossil handed out")
fossils.reward({ vm = vm }, "KABUTO")
T.eq(vm.inventory[251], 1, "reward is one-per-save")

-- Deferred claim: solved before the badge -> claimed on chamber entry after.
clearSaveFlags()
vm = fakeVm({})
withGame(stubSave({ GLACIER = true }, { [675] = true }, 0))
fossils.deferred({ vm = vm }, "AERODACTYL")
T.eq(vm.seen[1], "crystal_legacy_changes:ruins_got_aerodactyl", "deferred claim text")
T.eq(vm.inventory[253], 1, "Old Amber claimed on entry")
vm = fakeVm({})
withGame(stubSave({ GLACIER = true }, {}, 0))
fossils.deferred({ vm = vm }, "AERODACTYL")
T.eq(#vm.seen, 0, "unsolved chamber: nothing claimed")
vm = fakeVm({})
withGame(stubSave({}, { [675] = true }, 0))
fossils.deferred({ vm = vm }, "AERODACTYL")
T.eq(#vm.seen, 0, "no badge: nothing claimed on entry")

-- ---- Phase 3b behavior: Dratini Master gift flow ----------------------
-- Same harness as fossils: mod.save backs the one-per-save flag, mod.game
-- is the stub save, and the vm's givePokeFn appends to the save's party
-- like the engine's World:givePoke (so the post-give moves override the
-- verb performs is observable).
local masterExport = export.statics
T.check(type(masterExport) == "table", "exports carry the statics handlers")

local function masterVm()
  local state = { given = nil }
  return {
    seen = {},
    state = state,
    showText = function(self, key) self.seen[#self.seen + 1] = key end,
    givePokeFn = function(species, level, item)
      state.given = { species = species, level = level, item = item }
      local save = run.loader.game and run.loader.game.save
      if save and type(save.party) == "table" then
        save.party[#save.party + 1] = { species = species, level = level }
      end
    end,
  }
end

-- No RISING badge -> symbolic refusal, nothing given.
clearSaveFlags()
vm = masterVm()
withGame(stubSave({}, {}, 0))
masterExport.master({ vm = vm })
T.eq(vm.seen[1], "crystal_legacy_changes:dratini_symbolic",
  "no badge -> symbolic text")
T.eq(#vm.seen, 1, "no badge: single text, no gift")
T.eq(vm.state.given, nil, "no badge: nothing given")

-- Badge held -> take-this, L15 DRATINI with the CL moveset, received.
clearSaveFlags()
vm = masterVm()
withGame(stubSave({ RISING = true }, {}, 0))
masterExport.master({ vm = vm })
T.eq(vm.seen[1], "crystal_legacy_changes:dratini_take_this",
  "badge -> take-this text")
T.eq(vm.seen[2], "crystal_legacy_changes:dratini_received",
  "badge -> received text")
T.eq(#vm.seen, 2, "badge: exactly take-this + received")
T.eq(vm.state.given.species, 147, "DRATINI species index 147")
T.eq(vm.state.given.level, 15, "DRATINI level 15")
local masterMon = run.loader.game.save.party[1]
T.check(type(masterMon.moves) == "table", "gift moves overridden")
T.eq(masterMon.moves[1].id, "WRAP", "move 1 WRAP")
T.eq(masterMon.moves[2].id, "THUNDER_WAVE", "move 2 THUNDER_WAVE")
T.eq(masterMon.moves[3].id, "TWISTER", "move 3 TWISTER")
T.eq(masterMon.moves[4].id, "EXTREMESPEED", "move 4 EXTREMESPEED")
T.eq(masterMon.moves[1].pp, 20, "WRAP PP 20 (gold moves.lua)")
T.eq(masterMon.moves[1].maxPp, 20, "WRAP maxPp 20")
T.eq(masterMon.moves[4].pp, 5, "EXTREMESPEED PP 5 (gold moves.lua)")

-- One-per-save: re-talking the shrine after the gift is just the reflection.
vm = masterVm()
withGame(run.loader.game.save)
masterExport.master({ vm = vm })
T.eq(vm.seen[1], "crystal_legacy_changes:dratini_symbolic",
  "re-talk -> symbolic reflection")
T.eq(#run.loader.game.save.party, 1, "no second gift")

-- Full party -> party-full text, nothing given.
clearSaveFlags()
vm = masterVm()
withGame(stubSave({ RISING = true }, {}, 6))
masterExport.master({ vm = vm })
T.eq(vm.seen[1], "crystal_legacy_changes:dratini_party_full",
  "full party -> party full text")
T.eq(#vm.seen, 1, "full party: no gift attempt")
T.eq(vm.state.given, nil, "full party: nothing given")

-- ---- Phase 3d: Goldenrod City Move Tutor ---------------------------------
-- CL's tutor (maps/GoldenrodCity.asm:52-165, texts 486-548, object 12,22)
-- teaches FLAMETHROWER / THUNDERBOLT / ICE BEAM for 1000 coins (NOT 4000 --
-- Ask4000CoinsOkayText is a stale label in CL; TSP doc agrees on 1000),
-- daily, gated on 7 Badges + Coin Case.  CL hides the tutor via
-- MAPCALLBACK_OBJECTS until eligible; the mod appends an always-visible
-- POKEFAN_M and moves every gate into the talk script.  The teach flow rides
-- the engine's own TM path (learnMoveOn) behind a party-picker bridge.
local moveTutorData = export.moveTutor.data
T.check(type(export.moveTutor) == "table", "exports carry the move tutor handlers")
T.eq(moveTutorData.cost, 1000, "tutor charges 1000 coins (CL source, TSP doc)")
T.eq(moveTutorData.badgeGate, 7, "tutor gated on 7 badges (CL callback)")
T.eq(moveTutorData.coinCaseItem, 54, "Coin Case is gold item 54")
T.eq(moveTutorData.map, "GOLDENROD_CITY", "tutor map is Goldenrod City")
T.eq(moveTutorData.scriptKey, "crystal_legacy_changes:goldenrod_move_tutor",
  "tutor script key")
T.eq(#moveTutorData.menu.items, 4, "menu has 4 options")
T.eq(moveTutorData.menu.items[1], "FLAMETHROWER", "menu option 1")
T.eq(moveTutorData.menu.items[2], "THUNDERBOLT", "menu option 2")
T.eq(moveTutorData.menu.items[3], "ICE BEAM", "menu option 3 (ROM string, space)")
T.eq(moveTutorData.menu.items[4], "CANCEL", "menu option 4 CANCEL")

-- Text rows land in data.gen2Text under the mod prefix.
for key, text in pairs(moveTutorData.texts) do
  T.eq(data.gen2Text["crystal_legacy_changes:" .. key], text,
    "tutor text row registered: " .. key)
end

-- The two commands merged into the table the VM dispatches.
T.check(type(data.commands["crystal_legacy_changes:move_tutor_daily"]) == "function",
  "command registered: move_tutor_daily")
T.check(type(data.commands["crystal_legacy_changes:move_tutor_teach"]) == "function",
  "command registered: move_tutor_teach")

-- Object appended last to gold's GoldenrodCity objects (in-place append).
local goldenrod = data.gen2Maps.GOLDENROD_CITY
T.check(type(goldenrod) == "table", "GoldenrodCity map def reachable")
T.eq(#goldenrod.objects, 4, "3 seeded objects + the tutor")
local tutorObj = goldenrod.objects[4]
T.eq(tutorObj.scriptKey, "crystal_legacy_changes:goldenrod_move_tutor",
  "tutor object scriptKey")
T.eq(tutorObj.sprite, "SPRITE_POKEFAN_M", "tutor sprite POKEFAN_M")
T.eq(tutorObj.x, 12, "tutor tile x 12 (CL)")
T.eq(tutorObj.y, 22, "tutor tile y 22 (CL)")
T.eq(tutorObj.movement, 3, "tutor movement SPINRANDOM_SLOW (CL)")
T.eq(tutorObj.eventFlag, 65535, "tutor always visible (no flag gate)")
T.eq(tutorObj.type, 0, "tutor OBJECTTYPE_SCRIPT")
T.eq(tutorObj.palette, 0, "tutor default palette (~= CL PAL_NPC_RED)")

-- Talk script: CL MoveTutorScript as VM rows, callback gates moved into talk.
local tutorScript = scripts[moveTutorData.scriptKey]
T.check(type(tutorScript) == "table", "tutor script registered")
T.eq(tutorScript[1].op, "faceplayer", "row 1 faceplayer")
T.eq(tutorScript[2].op, "opentext", "row 2 opentext")
-- badge gate
T.eq(tutorScript[3].op, "readvar", "row 3 reads VAR_BADGES")
T.eq(tutorScript[3].var, 0x07, "VAR_BADGES id 0x07")
T.eq(tutorScript[4].op, "ifless", "row 4 badge gate branch")
T.eq(tutorScript[4].value, 7, "badge gate threshold 7")
T.eq(tutorScript[4].script[1].text, "crystal_legacy_changes:badge",
  "badge gate refusal text")
-- coin case gate
T.eq(tutorScript[5].op, "checkitem", "row 5 checks the Coin Case")
T.eq(tutorScript[5].args[1], 54, "Coin Case item id 54")
T.eq(tutorScript[6].op, "iffalse", "row 6 coin-case branch")
T.eq(tutorScript[6].script[1].text, "crystal_legacy_changes:coinCase",
  "coin-case refusal text")
-- daily gate
T.eq(tutorScript[7][1], "crystal_legacy_changes:move_tutor_daily",
  "row 7 runs the daily gate command")
-- greet / coins ask
T.eq(tutorScript[8].op, "writetext", "row 8 greet text")
T.eq(tutorScript[8].text, "crystal_legacy_changes:greet", "greet key")
T.eq(tutorScript[9].op, "yesorno", "row 9 greet yes/no")
T.eq(tutorScript[10].op, "iffalse", "row 10 greet decline branch")
T.eq(tutorScript[10].script[1].text, "crystal_legacy_changes:no", "decline text")
T.eq(tutorScript[11].op, "writetext", "row 11 coins ask text")
T.eq(tutorScript[11].text, "crystal_legacy_changes:coinsAsk", "coins ask key")
T.eq(tutorScript[12].op, "yesorno", "row 12 coins yes/no")
T.eq(tutorScript[13].op, "iffalse", "row 13 coins decline branch")
T.eq(tutorScript[13].script[1].text, "crystal_legacy_changes:tooBad",
  "coins decline text")
-- coins ladder
T.eq(tutorScript[14].op, "checkcoins", "row 14 checks the coin count")
T.eq(tutorScript[14].args[1], 232, "checkcoins low byte 232")
T.eq(tutorScript[14].args[2], 3, "checkcoins high byte 3 (1000 coins)")
T.eq(tutorScript[15].op, "ifequal", "row 15 HAVE_LESS branch")
T.eq(tutorScript[15].value, 2, "HAVE_LESS = scriptVar 2")
T.eq(tutorScript[15].script[1].text, "crystal_legacy_changes:insufficient",
  "not-enough-coins text")
-- menu
T.eq(tutorScript[16].op, "special", "row 16 DisplayCoinCaseBalance")
T.eq(tutorScript[16].id, 78, "DisplayCoinCaseBalance special id 78")
T.eq(tutorScript[17].op, "writetext", "row 17 which-move text")
T.eq(tutorScript[17].text, "crystal_legacy_changes:which", "which-move key")
T.eq(tutorScript[18].op, "loadmenu", "row 18 loads the menu")
T.eq(#tutorScript[18].menu.items, 4, "menu header carries 4 items")
T.eq(tutorScript[19].op, "verticalmenu", "row 19 verticalmenu")
T.eq(tutorScript[20].op, "closewindow", "row 20 closewindow")
-- branches
T.eq(tutorScript[21].op, "ifequal", "row 21 branch 1")
T.eq(tutorScript[21].value, 1, "choice 1")
T.eq(tutorScript[21].script[1][1], "crystal_legacy_changes:move_tutor_teach",
  "choice 1 -> teach command")
T.eq(tutorScript[21].script[1][2], "FLAMETHROWER", "choice 1 move")
T.eq(tutorScript[22].script[1][2], "THUNDERBOLT", "choice 2 move")
T.eq(tutorScript[23].script[1][2], "ICE_BEAM", "choice 3 move")
T.eq(tutorScript[24].op, "end", "row 24 ends on CANCEL")
T.eq(export.rebalance.moveTutorObjects, 1, "counts: tutor object appended")
T.eq(export.rebalance.moveTutorScripts, 1, "counts: tutor script registered")

-- Behavior: daily gate ------------------------------------------------
-- Unused today -> fall through (nil), no text.
clearSaveFlags()
vm = fakeVm({})
withGame(stubSave({}, {}, 0))
T.eq(export.moveTutor.daily({ vm = vm }), nil, "daily gate: nil when unused")
T.eq(#vm.seen, 0, "daily gate: no text when unused")

-- Taught today -> refusal text + "end" halts the row list.
local usedSave = stubSave({}, {}, 0)
usedSave.dailyFlags = { goldenrodMoveTutor = true }
withGame(usedSave)
T.eq(export.moveTutor.daily({ vm = vm }), "end", "daily gate: end when used today")
T.eq(vm.seen[1], "crystal_legacy_changes:daily", "daily refusal text shown")

-- Behavior: teach flow (party-picker bridge) --------------------------
-- The teach command parks the VM coroutine on {kind="mod_party_picker"};
-- the Gen2PartyMenu onChoose would resume the vm.  Headlessly drive the
-- same contract with coroutine.wrap: first call runs to the yield and
-- returns the request, the second call resumes with the chosen mon.
local function driveTeach(game, moveName)
  local co = coroutine.wrap(function()
    -- the wrapped fn must return the command's result or coroutine.wrap
    -- swallows it (the engine's runCmd reads that return)
    return export.moveTutor.teach({ vm = vm }, moveName)
  end)
  local req = co()
  T.eq(type(req) == "table" and req.kind, "mod_party_picker",
    "teach parks on the party picker")
  return co, req
end

-- Species gate: EKANS carries none of the tutor moves in CL -> refused.
clearSaveFlags()
vm = fakeVm({})
local learnCalls, said
-- learnMoveOn/say are engine METHODS (Game2:learnMoveOn): the colon call in
-- the command injects the game as arg 1, so the stubs must be colon-shaped.
local gateGame = {
  save = stubSave({}, {}, 0),
  learnMoveOn = function(game, mon, moveId, onDone)
    learnCalls[#learnCalls + 1] = { mon = mon, move = moveId, onDone = onDone }
  end,
  say = function(game, text) said = text end,
}
learnCalls = {}
-- NOT withGame(): it wraps the arg in { save = ... } and would drop the
-- learnMoveOn/say stubs; the teach command needs the full game object.
run.loader.game = gateGame
local co = driveTeach(gateGame, "FLAMETHROWER")
T.eq(co({ species = "EKANS", moves = {} }), "end", "invalid species ends the script")
T.eq(vm.seen[1], "crystal_legacy_changes:incompatible", "species refusal text")
T.eq(#learnCalls, 0, "species gate: no learn attempt")

-- KnowsMove gate: already knowing the move -> refused, no re-teach.
co = driveTeach(gateGame, "FLAMETHROWER")
T.eq(co({ species = "CHARIZARD", moves = { { id = "FLAMETHROWER" } } }), "end",
  "known move ends the script")
T.eq(vm.seen[1], "crystal_legacy_changes:incompatible", "known-move refusal text")
T.eq(#learnCalls, 0, "known-move gate: no learn attempt")

-- Success: CHARIZARD (CL tmhm FLAMETHROWER) -> understood, learnMoveOn with
-- the move name; onDone takes 1000 coins, sets the daily flag, farewell.
local paySave = stubSave({}, {}, 0)
paySave.player.coins = 3000
local payGame = {
  save = paySave,
  learnMoveOn = function(game, mon, moveId, onDone)
    learnCalls[#learnCalls + 1] = { mon = mon, move = moveId, onDone = onDone }
  end,
  say = function(game, text) said = text end,
}
learnCalls = {}
said = nil
vm = fakeVm({})
run.loader.game = payGame
co = driveTeach(payGame, "FLAMETHROWER")
local mon = { species = "CHARIZARD", moves = {} }
T.eq(co(mon), "end", "successful teach ends the script")
T.eq(vm.seen[1], "crystal_legacy_changes:understood", "understood text shown")
T.eq(#learnCalls, 1, "learnMoveOn called once")
T.eq(learnCalls[1].mon, mon, "learnMoveOn carries the chosen mon")
T.eq(learnCalls[1].move, "FLAMETHROWER", "learnMoveOn carries the move name")
T.eq(paySave.player.coins, 3000, "coins unchanged until the learn completes")
-- The learn flow completes later (async): coins taken, daily flag set, farewell.
learnCalls[1].onDone(true)
T.eq(paySave.player.coins, 2000, "1000 coins taken on success")
T.eq(paySave.dailyFlags.goldenrodMoveTutor, true, "daily flag set on success")
T.eq(said, moveTutorData.texts.farewell, "farewell said after the lesson")
-- Learned=false -> nothing charged, no farewell.
learnCalls[1].onDone(false)
T.eq(paySave.player.coins, 2000, "failed learn charges nothing")

-- Teach with the daily flag already set -> daily refusal, no picker request.
clearSaveFlags()
vm = fakeVm({})
usedSave = stubSave({}, {}, 0)
usedSave.dailyFlags = { goldenrodMoveTutor = true }
withGame(usedSave)
T.eq(export.moveTutor.teach({ vm = vm }, "FLAMETHROWER"), "end",
  "teach refuses when today's lesson is used")
T.eq(vm.seen[1], "crystal_legacy_changes:daily", "teach daily refusal text")

-- ---- Phase 3d2: Team Rocket RadioTower 5F boss scene ----------------------
-- Gold already ships the full 1F-5F Rocket takeover (fake director giving the
-- BASEMENT_KEY, EXECUTIVEM_2 on 4F, EXECUTIVEF_1 on 5F, the takeover flag
-- cascade); the mod ports the CL-only 5F boss scene as script-table patches:
-- ROCKET_LEADER/Archer replaces the EXECUTIVEM_1 battle, the GIOVANNI
-- hologram + ARCHER disband sequences are added, and the boss object wears
-- SPRITE_ARCHER.  The reward stays gold's RAINBOW_WING (CL's CLEAR_BELL does
-- not exist in gold) and gold's 12-flag cascade (== CL's set) is kept.
local function sceneHasOp(scene, op, object)
  for _, row in ipairs(scene) do
    if row.op == op and (object == nil or row.object == object) then
      return row
    end
  end
  return nil
end

local rt = export.rocketTower.data
T.check(type(export.rocketTower) == "table", "exports carry the rocket tower handlers")
T.eq(rt.map, "RADIO_TOWER_5F", "rocket tower targets 5F")
T.eq(rt.flags.giovanniDisguise, 1932, "GIOVANNI disguise flag 1932 (free above gold)")
T.eq(rt.flags.giovanniReal, 1933, "GIOVANNI real flag 1933 (free above gold)")
T.eq(rt.flags.clearedRadioTower, 33, "cascade uses gold's EVENT_CLEARED_RADIO_TOWER 33")
T.eq(rt.flags.engineRocketsInTower, 18, "cascade clears gold's ENGINE_ROCKETS_IN_RADIO_TOWER 18")
T.eq(rt.flags.beatExecutivem1, 1393, "cascade sets EVENT_BEAT_ROCKET_EXECUTIVEM_1 1393")
T.eq(rt.flags.teamRocketDisbanded, 1889, "cascade sets EVENT_TEAM_ROCKET_DISBANDED 1889")

-- Sprites: CL art (16x96 4-shade sheets, copied verbatim from CL_source).
T.eq(run.loader.content.sprites:get("SPRITE_ARCHER").image,
  "assets/sprites/archer.png", "Archer sprite registered with CL art")
T.eq(run.loader.content.sprites:get("SPRITE_GIOVANNI").image,
  "assets/sprites/giovanni.png", "Giovanni sprite registered")
T.eq(run.loader.content.sprites:get("SPRITE_GIOVANNI_DISGUISE").image,
  "assets/sprites/giovanni_disguise.png", "Giovanni disguise sprite registered")
T.eq(run.loader.content.sprites:get("SPRITE_GIOVANNI").palette, "PAL_OW_BROWN",
  "Giovanni uses the brown OW palette (CL PAL_NPC_BROWN)")

-- Texts + movements land under the mod prefix.
for key in pairs(rt.texts) do
  T.check(data.gen2Text["crystal_legacy_changes:" .. key] ~= nil, "text " .. key)
end
for key in pairs(rt.movements) do
  T.eq(type(data.gen2Movement["crystal_legacy_changes:" .. key]), "table",
    "movement " .. key)
end

-- Map: 6 objects after the patch, boss re-sprited, coordEvent repointed.
local rtMap = data.gen2Maps.RADIO_TOWER_5F
T.eq(#rtMap.objects, 6, "5F carries 6 objects (4 gold + 2 GIOVANNI)")
T.eq(rtMap.objects[2].sprite, "SPRITE_ARCHER", "boss object wears Archer's sprite")
T.eq(rtMap.objects[5].sprite, "SPRITE_GIOVANNI_DISGUISE", "hologram object appended")
T.eq(rtMap.objects[5].eventFlag, 1932, "hologram hidden by flag 1932")
T.eq(rtMap.objects[5].x, 12, "hologram stands at (12,0)")
T.eq(rtMap.objects[6].sprite, "SPRITE_GIOVANNI", "real GIOVANNI object appended")
T.eq(rtMap.objects[6].eventFlag, 1933, "real GIOVANNI hidden by flag 1933")
local rtBossCe
for _, ce in ipairs(rtMap.coordEvents) do
  if ce.sceneId == 1 then rtBossCe = ce end
end
T.check(rtBossCe ~= nil, "boss coordEvent (16,5) present")
T.eq(rtBossCe.scriptKey, "crystal_legacy_changes:radiotower_boss_scene",
  "boss coordEvent repointed to the mod scene")
T.eq(data.gen2Scripts[rt.objectEventKey][1].op, "end",
  "hologram objects carry a no-op talk script")

-- The boss scene itself.
local rtScene = data.gen2Scripts[rt.bossSceneKey]
T.check(type(rtScene) == "table", "boss scene injected into gen2Scripts")
T.eq(#rtScene, 146, "boss scene row count (CL flow, gold row format)")
T.eq(rtScene[1].op, "applymovement", "scene opens moving the player")
T.eq(rtScene[1].object, 0, "player walks left from the stairs")
T.eq(rtScene[3].op, "turnobject", "boss turns to face the player")
T.eq(rtScene[3].facing, 3, "boss faces RIGHT")
local rtBattle = sceneHasOp(rtScene, "loadtrainer")
T.eq(rtBattle.class, 69, "boss battle class 69 (ROCKET_LEADER, Phase 2)")
T.eq(rtBattle.member, 1, "boss battle member 1 (ARCHER)")
T.check(sceneHasOp(rtScene, "startbattle") ~= nil, "boss battle runs")
T.check(sceneHasOp(rtScene, "reloadmapafterbattle") ~= nil, "map reloads after battle")
-- Giovanni hologram: disguise appears, then the reveal swaps to the real one.
T.eq(sceneHasOp(rtScene, "appear", 5).object, 5, "disguise object appears")
T.check(sceneHasOp(rtScene, "disappear", 5) ~= nil, "disguise disappears for the reveal")
T.eq(sceneHasOp(rtScene, "appear", 6).object, 6, "real GIOVANNI appears")
T.check(sceneHasOp(rtScene, "disappear", 6) ~= nil, "GIOVANNI leaves after the speech")
T.check(sceneHasOp(rtScene, "special", nil) ~= nil, "scene uses special ops")
-- Disband: Archer + ROCKET_GIRL fade out before the cascade.
T.check(sceneHasOp(rtScene, "disappear", 2) ~= nil, "Archer disappears at disband")
T.check(sceneHasOp(rtScene, "disappear", 3) ~= nil, "ROCKET_GIRL disappears at disband")
-- Cascade: gold's 12 takeover flags + the two GIOVANNI flags, in order.
local rtSetEvents, rtSetFlags, rtClearEvents, rtClearFlags = {}, {}, {}, {}
for _, row in ipairs(rtScene) do
  if row.op == "setevent" then rtSetEvents[#rtSetEvents + 1] = row.event end
  if row.op == "setflag" then rtSetFlags[#rtSetFlags + 1] = row.flag end
  if row.op == "clearevent" then rtClearEvents[#rtClearEvents + 1] = row.event end
  if row.op == "clearflag" then rtClearFlags[#rtClearFlags + 1] = row.flag end
end
T.eq(table.concat(rtSetEvents, ","),
  "1393,33,1740,1741,1742,1763,1932,1933,120,1889",
  "setevents: takeover cascade + GIOVANNI + reward flags")
T.eq(table.concat(rtClearEvents, ","), "1846,1743,1744,1764",
  "clearevents: civilians/nerd flags match gold's shipped cascade")
T.eq(table.concat(rtSetFlags, ","), "", "no setflags in the cascade")
T.eq(table.concat(rtClearFlags, ","), "18,22",
  "clearflags: ENGINE_ROCKETS_IN_RADIO_TOWER + MAHOGANY")
-- Director: the GENTLEMAN (object 1) is reused, CL-style, for the walk-in.
local rtMove = sceneHasOp(rtScene, "moveobject")
T.eq(rtMove.object, 1, "director object is the GENTLEMAN (CL reuses it)")
T.eq(rtMove.x, 12, "director teleports to (12,0)")
T.eq(rtMove.y, 0, "director teleports to (12,0)")
T.check(sceneHasOp(rtScene, "disappear", 1) ~= nil, "GENTLEMAN hides for the walk-in")
-- Reward: gold's RAINBOW_WING (178) + flags 120/1889, gold's director texts.
local rtGive = sceneHasOp(rtScene, "verbosegiveitem")
T.eq(rtGive.item, 178, "director gives gold's RAINBOW_WING (178)")
T.eq(rtGive.quantity, 1, "one RAINBOW_WING")
T.eq(rtScene[#rtScene].op, "end", "scene ends")
T.check(sceneHasOp(rtScene, "setscene") ~= nil, "scene closes with setscene 2")
-- The mod.save flags are set at mods.loaded (CL's new-game-init equivalent).
-- The suite's clearSaveFlags wipes the loader save bucket mid-suite, so
-- re-fire mods.loaded with the same payload the loader uses; the handler's
-- one-per-session guard keeps the injections idempotent while the flag
-- writes (idempotent themselves) run again.
run.loader.events:emit("mods.loaded",
  { loader = run.loader, data = run.loader.baseData })
T.eq(run.loader.modSave["crystal_legacy_changes"][1932], true,
  "GIOVANNI disguise hidden from the start")
T.eq(run.loader.modSave["crystal_legacy_changes"][1933], true,
  "real GIOVANNI hidden from the start")
T.eq(#rtMap.objects, 6, "re-fire is idempotent (no duplicate GIOVANNI objects)")
-- Counts reported.
T.eq(export.rebalance.rocketTower.sprites, 3, "3 sprites registered")
T.eq(export.rebalance.rocketTower.texts, 15, "15 CL texts registered")
T.eq(export.rebalance.rocketTower.movements, 16, "16 movement tables injected")
T.eq(export.rebalance.rocketTower.objects, 3, "boss re-sprite + 2 GIOVANNI objects")
T.eq(export.rebalance.rocketTower.scripts, 1, "1 boss scene script injected")

-- Team Rocket Base (Phase 3d1): all 9 deltas + the executive sprite land.
local rbB1F = data.gen2Maps.TEAM_ROCKET_BASE_B1F
local rbB2F = data.gen2Maps.TEAM_ROCKET_BASE_B2F
local rbB3F = data.gen2Maps.TEAM_ROCKET_BASE_B3F
local function rbFind(map, x, y)
  for _, obj in ipairs(map.objects) do
    if obj.x == x and obj.y == y then return obj end
  end
  return nil
end
-- Delta 1: B1F (21,12) X_ACCURACY(33) -> GUARD_SPEC(41).
local rbB1Ball = rbFind(rbB1F, 21, 12)
T.check(rbB1Ball ~= nil, "B1F ball at (21,12) present")
T.eq(rbB1Ball.itemball.item, 41, "B1F (21,12) is GUARD_SPEC (41)")
-- Delta 2: B2F GruntM18 (2,1) sight 3 -> (4,1) sight 1.
T.check(rbFind(rbB2F, 2, 1) == nil, "GruntM18 no longer at (2,1)")
local rbGrunt = rbFind(rbB2F, 4, 1)
T.check(rbGrunt ~= nil, "GruntM18 now at (4,1)")
T.eq(rbGrunt.sight, 1, "GruntM18 sight tightened to 1")
-- Deltas 3-5: B3F grunts/scientists moved.
T.check(rbFind(rbB3F, 5, 15) == nil, "RaticateTailGrunt no longer at (5,15)")
T.check(rbFind(rbB3F, 5, 14) ~= nil, "RaticateTailGrunt now at (5,14)")
T.check(rbFind(rbB3F, 25, 12) == nil, "Ross no longer at (25,12)")
local rbRoss = rbFind(rbB3F, 23, 11)
T.check(rbRoss ~= nil, "Ross now at (23,11)")
T.eq(rbRoss.sight, 0, "Ross no longer chases (sight 0)")
T.check(rbFind(rbB3F, 14, 15) == nil, "Mitch no longer at (14,15)")
local rbMitch = rbFind(rbB3F, 11, 15)
T.check(rbMitch ~= nil, "Mitch now at (11,15)")
T.eq(rbMitch.sight, 3, "Mitch keeps sight 3")
-- Delta 11: exec at (8,3) re-sprited to SPRITE_ARCHER (real art ships).
local rbExec = rbFind(rbB3F, 8, 3)
T.check(rbExec ~= nil, "exec stays at (8,3)")
T.eq(rbExec.sprite, "SPRITE_ARCHER", "exec wears ARCHER's sprite")
-- Phase 4b deltas 10 + 12: the six B2F electrodes and the B3F Murkrow now
-- wear real CL art (SPRITE_ELECTRODE / SPRITE_MURKROW, data/sprites.lua).
do
  for _, coord in ipairs({ { 7, 5 }, { 7, 7 }, { 7, 9 }, { 22, 5 }, { 22, 7 }, { 22, 9 } }) do
    local obj = rbFind(rbB2F, coord[1], coord[2])
    T.check(obj ~= nil, string.format("B2F electrode at (%d,%d) present", coord[1], coord[2]))
    T.eq(obj.sprite, "SPRITE_ELECTRODE",
      string.format("B2F (%d,%d) wears ELECTRODE's sprite", coord[1], coord[2]))
  end
  local rbMurkrow = rbFind(rbB3F, 7, 2)
  T.check(rbMurkrow ~= nil, "B3F Murkrow at (7,2) present")
  T.eq(rbMurkrow.sprite, "SPRITE_MURKROW", "Murkrow wears MURKROW's sprite")
  T.eq(rbMurkrow.palette, 9, "Murkrow keeps PAL_NPC_BLUE (CL's murkrow slot)")
end
-- Deltas 6-8: B3F itemball item swaps.
T.eq(rbFind(rbB3F, 1, 12).itemball.item, 27, "B3F (1,12) is PROTEIN (27)")
T.eq(rbFind(rbB3F, 3, 12).itemball.item, 53, "B3F (3,12) is X_SPECIAL (53)")
T.eq(rbFind(rbB3F, 28, 9).itemball.item, 38, "B3F (28,9) is FULL_HEAL (38)")
-- Delta 9: UltraBall appended at (14,10), flag 1934 free.
local rbUltra = rbFind(rbB3F, 14, 10)
T.check(rbUltra ~= nil, "UltraBall added at (14,10)")
T.eq(rbUltra.itemball.item, 2, "appended ball holds ULTRA_BALL (2)")
T.eq(rbUltra.eventFlag, 1934, "UltraBall keyed to free flag 1934")
-- The UltraBall must not duplicate on re-fire (one-per-session guard).
T.eq(#rbB3F.objects, 9, "re-fire is idempotent (no duplicate UltraBall)")
-- Counts reported.
T.eq(export.rebalance.rocketBase.items, 4, "4 itemball item repoints")
T.eq(export.rebalance.rocketBase.objects, 4, "4 NPC moves")
T.eq(export.rebalance.rocketBase.sprites, 8,
  "8 sprite swaps (exec -> ARCHER, 6x VOLTORB -> ELECTRODE, MOLTRES -> MURKROW)")
T.eq(export.rebalance.rocketBase.added, 1, "1 appended object (UltraBall)")

-- Phase 4a #5 (item evolutions): the engine's EvoStoneEffect port is
-- data-driven -- the RECORDS rows only know the family, Evolution.checkMon
-- names the target from this mod's evolutions.lua -- so every stone in the
-- CL item set must carry the evolve row and honour the mod's rows untouched.
local ItemEffects = require("src.core.gen2.ItemEffects")
local Mon = require("src.battle.gen2.Mon")
local pokemon = run.loader.content.pokemon
-- The fixture has no base data for the CL evo species (the loader folded the
-- mod's evolutions over an empty base), so give the two species under test
-- real stats; Mon.new and Evolution.checkMon read data.pokemon directly.
local function evoBase(id, stats)
  local def = pokemon:get(id) or {}
  def.baseStats = { hp = stats[1], attack = stats[2], defense = stats[3],
                    speed = stats[4], specialAttack = stats[5], specialDefense = stats[6] }
  def.growthRate = def.growthRate or "GROWTH_MEDIUM_FAST"
  def.types = def.types or { "WATER", "WATER" }
  def.name = def.name or id
  data.pokemon[id] = def
  return def
end
evoBase("POLIWHIRL", { 65, 65, 65, 90, 50, 50 })
evoBase("GOLDEEN", { 45, 67, 60, 63, 35, 50 })
-- The six CL evo items all carry the family (action/needsTarget/battle).
local function evoItem(id)
  local row = ItemEffects.RECORDS[id]
  T.check(row ~= nil, id .. " has an item-effects row")
  T.eq(row.action, "evolve", id .. " family is evolve")
  T.eq(row.needsTarget, true, id .. " needs a party target")
  T.eq(row.battle, true, id .. " is legal in the battle pack")
end
evoItem("WATER_STONE")
evoItem("UP_GRADE")
evoItem("KINGS_ROCK")
evoItem("METAL_COAT")
evoItem("DRAGON_SCALE")
evoItem("BRICK_PIECE")
-- POLIWHIRL -> POLIWRATH: the engine never names the target, the mod's row does.
local poliwhirl = Mon.new(data, "POLIWHIRL", 40, { moves = {} })
local stone = ItemEffects.useOnMon("WATER_STONE", poliwhirl, data)
T.check(stone.used, "WATER_STONE activates on POLIWHIRL")
T.eq(stone.entry.into, "POLIWRATH", "target comes from the mod's evolutions.lua")
-- A held EVERSTONE refuses (EvoStoneEffect's check before wForceEvolution).
local holder = Mon.new(data, "POLIWHIRL", 40, { moves = {}, item = "EVERSTONE" })
local refused = ItemEffects.useOnMon("WATER_STONE", holder, data)
T.check(not refused.used, "EVERSTONE holder refuses the stone")
T.eq(refused.text, ItemEffects.TEXT_NO_EFFECT, "refusal is the no-effect line")
-- A stone with no row for the species is a no-op, and wForceEvolution shuts
-- every non-ITEM method, so GOLDEEN's EVOLVE_LEVEL row cannot fire from a pack.
local wrong = ItemEffects.useOnMon("MOON_STONE", poliwhirl, data)
T.check(not wrong.used, "a stone with no row is a no-op")
local goldeen = Mon.new(data, "GOLDEEN", 40, { moves = {} })
local levelOnly = ItemEffects.useOnMon("WATER_STONE", goldeen, data)
T.check(not levelOnly.used, "wForceEvolution shuts the EVOLVE_LEVEL row")
-- Pack routing answers the family before a target exists.
T.eq(ItemEffects.partyAction("WATER_STONE"), "evolve", "pack menu routes to the party picker")

run.release()
T.finish("crystal_legacy_changes")
