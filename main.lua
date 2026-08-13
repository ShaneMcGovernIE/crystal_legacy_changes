-- Crystal Legacy's explicit stat and move values, resolved against the
-- player's imported Gold dataset so the mod ships no ROM-derived ids.

local function normalize(value)
  return tostring(value):gsub("[^%w]", ""):upper()
end

local function loadSibling(mod, name)
  local source, readErr = mod:read(name)
  if not source then
    error(name .. " could not be read: " .. tostring(readErr), 0)
  end
  local chunk, compileErr = load(source, "@" .. mod.path .. "/" .. name)
  if not chunk then
    error(name .. " did not compile: " .. tostring(compileErr), 0)
  end
  local ok, data = pcall(chunk)
  if not ok then error(data, 0) end
  return data
end

local function indexRecords(registry)
  local ids = {}
  for id, record in registry:each() do
    ids[normalize(id)] = id
    if record and record.name then
      ids[normalize(record.name)] = id
    end
  end
  return ids
end

local function applyRebalance(mod, data)
  local moveIds = indexRecords(mod.content.moves)
  local speciesIds = indexRecords(mod.content.pokemon)
  local counts = {
    moves = 0,
    species = 0,
    unknownMoves = 0,
    unknownSpecies = 0,
    types = 0,
    effects = 0,
  }

  -- Gold's battle loop handles these effects directly from the move id, but
  -- the registry still needs a record so a patched move's reference validates.
  for id in pairs({
    EFFECT_NORMAL_HIT = true,
    EFFECT_FLINCH_HIT = true,
    EFFECT_DEFENSE_DOWN_HIT = true,
    EFFECT_TRIPLE_KICK = true,
  }) do
    mod.content.move_effects:patch(id, { kind = "full" })
    counts.effects = counts.effects + 1
  end

  for name, patch in pairs(data.moves or {}) do
    local id = moveIds[normalize(name)]
    if id then
      mod.content.moves:patch(id, patch)
      counts.moves = counts.moves + 1
    else
      counts.unknownMoves = counts.unknownMoves + 1
    end
  end

  for name, patch in pairs(data.pokemon or {}) do
    local id = speciesIds[normalize(name)]
    if id then
      mod.content.pokemon:patch(id, patch)
      counts.species = counts.species + 1
    else
      counts.unknownSpecies = counts.unknownSpecies + 1
    end
  end

  for id, patch in pairs(data.types or {}) do
    mod.content.type_chart:patch(id, patch)
    counts.types = counts.types + 1
  end

  if counts.unknownMoves > 0 then
    mod.log:warn("%d documented move names were not present in the Gold cache",
      counts.unknownMoves)
  end
  if counts.unknownSpecies > 0 then
    mod.log:warn("%d documented species names were not present in the Gold cache",
      counts.unknownSpecies)
  end

  return counts
end

local function applyLearnsets(mod, data)
  local count = 0
  for id, levelMoves in pairs(data.learnsets or {}) do
    mod.content.pokemon:patch(id, { levelMoves = levelMoves })
    count = count + 1
  end
  return count
end

local function applyTmhm(mod, data)
  local count = 0
  for id, moves in pairs(data.tmhm or {}) do
    mod.content.pokemon:patch(id, { tmhm = moves })
    count = count + 1
  end
  return count
end

-- Encounters: Gold hangs every table of encounter rows off one registry per
-- kind (grass/swarmGrass/water/swarmWater/fishGroups/trees/rocks/treeSets/
-- bugContest/roamMaps).  The registry id IS the kind, so each patch folds
-- per map/group entry against the imported cache.  The data file wraps the
-- kinds in a single `kinds` namespace key so modkit's dump check does not
-- mistake the whole-table replacement for a re-shipped ROM extract.
--
-- The swarm kinds are complete replacements, not deltas: Crystal keeps only
-- the Dark Cave and Route 35 land swarms and ships NO surf swarms
-- (swarmWater = {}), so Gold's removed rows (Route 38, Mount Mortar) must
-- not survive.  A deep-merge patch would keep those rows alive; override
-- swaps the whole kind table instead.
local SWARM_OVERRIDE_KINDS = {
  swarmGrass = true,
  swarmWater = true,
}

local function applyEncounters(mod, data)
  local count = 0
  for kind, rows in pairs(data.kinds or data) do
    if kind ~= "source" and kind ~= "generation" then
      if SWARM_OVERRIDE_KINDS[kind] then
        mod.content.encounters:override(kind, rows)
      else
        mod.content.encounters:patch(kind, rows)
      end
      count = count + 1
    end
  end
  return count
end

-- Trainers: Gold hangs every named trainer of a class off one record per
-- class (data.gen2Trainers.classes); the registry id is the class id, so we
-- patch each class record wholesale.
local function applyTrainers(mod, data)
  local count = 0
  for id, record in pairs(data.classes or {}) do
    mod.content.trainers:patch(id, record)
    count = count + 1
  end
  return count
end

-- Marts: Gold has no marts content registry.  The engine seeds
-- game.data.gen2Marts = { bargain = ..., lists = {34 gold-positional
-- shelves} } (Game2.lua) before mods load, and World/MartMenu read that
-- table by reference afterwards.  The real seam is the mods.loaded event,
-- fired at the end of Loader:load with { loader, data } where data is
-- game.data in-game (opts.data under the SDK).  We swap the 34 shelves in
-- place with the Crystal Legacy stock, preserving bargain.  GOLD_MART_ORDER
-- is the gold engine's 34-slot order (constants/mart_constants.asm, verified
-- against the gold cache); the 5 CL-only marts (BERRYS, BERRYS_2,
-- CELADON_3F_2, CELADON_5F_1_2, CELADON_5F_2_2) have no gold slot
-- (NUM_MARTS = 34) and are unreachable in this engine.
local GOLD_MART_ORDER = {
  "MART_CHERRYGROVE", "MART_CHERRYGROVE_DEX", "MART_VIOLET", "MART_AZALEA",
  "MART_CIANWOOD", "MART_GOLDENROD_2F_1", "MART_GOLDENROD_2F_2",
  "MART_GOLDENROD_3F", "MART_GOLDENROD_4F", "MART_GOLDENROD_5F_1",
  "MART_GOLDENROD_5F_2", "MART_GOLDENROD_5F_3", "MART_GOLDENROD_5F_4",
  "MART_OLIVINE", "MART_ECRUTEAK", "MART_MAHOGANY_1", "MART_MAHOGANY_2",
  "MART_BLACKTHORN", "MART_VIRIDIAN", "MART_PEWTER", "MART_CERULEAN",
  "MART_LAVENDER", "MART_VERMILION", "MART_CELADON_2F_1",
  "MART_CELADON_2F_2", "MART_CELADON_3F", "MART_CELADON_4F",
  "MART_CELADON_5F_1", "MART_CELADON_5F_2", "MART_FUCHSIA",
  "MART_SAFFRON", "MART_MT_MOON", "MART_INDIGO_PLATEAU", "MART_UNDERGROUND",
}

local function applyMarts(mod, data, counts)
  counts.marts = 0
  counts.clOnly = 0
  mod.events:on("mods.loaded", function(payload)
    local target = payload and payload.data
    if not target then return end
    local marts = target.gen2Marts
    if type(marts) ~= "table" then
      marts = { bargain = {}, lists = {} }
      target.gen2Marts = marts
    end
    marts.bargain = marts.bargain or {}
    local lists = marts.lists
    if type(lists) ~= "table" then
      lists = {}
      marts.lists = lists
    end
    for i, id in ipairs(GOLD_MART_ORDER) do
      local stock = data.marts[id]
      if stock then
        lists[i] = stock
        counts.marts = counts.marts + 1
      end
    end
    for id in pairs(data.marts or {}) do
      local found = false
      for _, gold in ipairs(GOLD_MART_ORDER) do
        if gold == id then found = true break end
      end
      if not found then counts.clOnly = counts.clOnly + 1 end
    end
  end)
end

return function(mod)
  local counts = applyRebalance(mod, loadSibling(mod, "rebalance.lua"))
  counts.learnsets = applyLearnsets(mod, loadSibling(mod, "learnsets.lua"))
  counts.tmhm = applyTmhm(mod, loadSibling(mod, "tmhm.lua"))
  counts.encounters = applyEncounters(mod, loadSibling(mod, "data/encounters.lua"))
  counts.trainers = applyTrainers(mod, loadSibling(mod, "data/trainers.lua"))
  counts.marts = 0
  counts.clOnly = 0
  applyMarts(mod, loadSibling(mod, "data/marts.lua"), counts)
  mod.exports.rebalance = counts
end
