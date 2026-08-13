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

local export = run.loader.exports.crystal_legacy_changes
T.check(export and export.rebalance and export.rebalance.moves > 0,
  "exports report applied move changes")
T.check(export.rebalance.species > 0,
  "exports report applied species changes")
T.eq(export.rebalance.learnsets, 251,
  "exports report all 251 learnsets")
T.eq(export.rebalance.tmhm, 251,
  "exports report all 251 TM/HM lists")

run.release()
T.finish("crystal_legacy_changes")
