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

-- KNOWN-BLOCKED STATE (Phase 4, engine): MartMenu.inventory
-- (src/ui/gen2/MartMenu.lua:347) unconditionally returns DEFAULT_MART for
-- martId >= NUM_MARTS (34), so the appended shelves are unreachable until the
-- data-driven gate fix lands.  Pin the current fallback against the REAL gate
-- function; the Phase 4 change should flip these on purpose.
local MartMenu = require("src.ui.gen2.MartMenu")
local fallback34 = MartMenu.inventory(marts, 34)
local fallback35 = MartMenu.inventory(marts, 35)
T.check(type(fallback34) == "table" and fallback34[1] == "POKE_BALL",
  "gate documented: martId 34 currently falls back to DEFAULT_MART")
T.check(type(fallback35) == "table" and fallback35[1] == "POKE_BALL",
  "gate documented: martId 35 currently falls back to DEFAULT_MART")
T.check(MartMenu.inventory(marts, 34) ~= marts.lists[35],
  "blocked: inventory(marts, 34) is not the MART_BERRYS shelf yet")
T.check(MartMenu.inventory(marts, 35) ~= marts.lists[36],
  "blocked: inventory(marts, 35) is not the MART_BERRYS_2 shelf yet")

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
T.eq(export.rebalance.statics, 3,
  "exports report all three game-corner prize arms patched")

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

run.release()
T.finish("crystal_legacy_changes")
