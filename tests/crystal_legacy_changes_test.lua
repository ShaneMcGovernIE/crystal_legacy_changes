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

run.release()
T.finish("crystal_legacy_changes")
