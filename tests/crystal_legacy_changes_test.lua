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
T.eq(#marts.lists, 34, "all 34 gold mart slots are present")
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
    -- CELADON_5F_2_2) have no gold slot (NUM_MARTS = 34); their unique stock
    -- must never land on any reachable shelf.
    if item == "GOLD_BERRY" or item == "TM_EARTHQUAKE"
      or item == "TM_TOXIC" or item == "TM_RETURN" then
      leakSeen = true
    end
  end
end
T.check(not junkSeen, "no seeded junk survives in any of the 34 slots")
T.check(not leakSeen, "no CL-only mart stock leaks into a gold slot")

run.release()
T.finish("crystal_legacy_changes")
