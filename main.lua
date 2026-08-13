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

-- Evolutions: Gold hangs every species' evolution rows off the pokemon
-- record's `evolutions` list; the loader's deep-merge replaces whole arrays,
-- so patching `{ evolutions = rows }` swaps in the full CL list per species
-- (record semantics -- no gold row survives).
--
-- The rows also change method for the five item evolutions: Gold evolves
-- Onix, Scyther, Seadra, Porygon, Poliwhirl, Slowpoke and Tyrogue by trading
-- a mon holding UP_GRADE / KINGS_ROCK / METAL_COAT / BRICK_PIECE /
-- DRAGON_SCALE (EVOLVE_TRADE); Crystal uses the item directly on the mon
-- (EVOLVE_ITEM).  EVOLVE_ITEM is engine-seeded with requiresForce=true
-- (src/core/gen2/Evolution.lua), so the mod re-affirms that record instead
-- of registering it -- register would collide with the engine's ownership of
-- the id, while patch deep-merges into the engine record and keeps its check
-- function.  requiresForce makes the stone-style item-use path fire while
-- the after-battle sweep never does.
local function applyEvolutions(mod, data, counts)
  counts.evolutionMethods = 0
  counts.evolutions = 0
  mod.content.evolution_methods:patch("EVOLVE_ITEM", { requiresForce = true })
  counts.evolutionMethods = 1
  for id, rows in pairs(data.evolutions or {}) do
    mod.content.pokemon:patch(id, { evolutions = rows })
    counts.evolutions = counts.evolutions + 1
  end
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

-- Statics & gifts (Phase 3b+c): story content rides the Gen 2 bytecode VM,
-- which dispatches decoded rows from data.gen2Scripts (merged mod rows and
-- gold's ROM rows by ANY key).  Prize menus are inline on loadmenu rows and
-- each prize arm is its own script row, so we patch those rows in place on
-- mods.loaded -- the same seam applyMarts uses (payload.data is game.data
-- in-game, opts.data under the SDK).
local function applyStatics(mod, data, counts)
  counts.statics = 0
  local birds = data.birds

  -- Dragon's Den Dratini Master (Phase 3b).  Gold's B1F shrine is a plain
  -- read bgEvent whose script row is a single jumptext; we replace that row
  -- with the mod command verb (badge-gated, one-per-save) and register the
  -- verb + its text rows through the same registries fossils uses.
  local master = data.master
  local masterVerb
  if type(master) == "table" then
    for key, text in pairs(master.text or {}) do
      mod.content.text:register("crystal_legacy_changes:dratini_" .. key, text)
    end

    local function saveOf()
      local game = mod.game
      return game and game.save
    end
    local function hasBadge(save, name)
      local badges = save and save.player and save.player.badges
      return type(badges) == "table" and badges[name] == true
    end
    local flag = "master.dratini"
    local function copyMoves(list)
      local out = {}
      for _, mv in ipairs(list or {}) do
        out[#out + 1] = { id = mv.id, pp = mv.pp, maxPp = mv.maxPp }
      end
      return out
    end
    masterVerb = function(ctx)
      local vm = ctx and ctx.vm
      if not vm then return end
      local function say(key) vm:showText("crystal_legacy_changes:dratini_" .. key) end
      if mod.save:get(flag) then
        say("symbolic")
        return
      end
      local save = saveOf()
      if not hasBadge(save, master.badge) then
        say("symbolic")
        return
      end
      if type(save) == "table" and type(save.party) == "table"
        and #save.party >= 6 then
        say("party_full")
        return
      end
      say("take_this")
      if vm.givePokeFn then vm.givePokeFn(master.speciesIndex, master.level, nil) end
      local mon = save and save.party and save.party[#save.party]
      if mon then mon.moves = copyMoves(master.moves) end
      mod.save:set(flag, true)
      say("received")
    end
    mod.commands:register(master.verb, masterVerb)
    counts.statics = counts.statics + 1
    mod.exports.statics = { master = masterVerb, hasBadge = hasBadge, data = data }
  end

  -- Kanto bird cries: CL's text is "Gyaoo!" for all three (Moltres/Articuno/
  -- Zapdos scripts in maps/VictoryRoad.asm, maps/Route20.asm,
  -- maps/Route10North.asm).
  if type(birds) == "table" then
    for _, bird in ipairs(birds) do
      if type(bird) == "table" and type(bird.textKey) == "string"
        and type(bird.text) == "string" then
        mod.content.text:register(bird.textKey, bird.text)
      end
    end
  end

  -- Celebi / GS Ball dialogue (CL, in spirit): the receptionist gift, Kurt's
  -- hand-off, the shrine prompt + insertion, and the Ruins of Alph fallback.
  local celebi = data.celebi
  if type(celebi) == "table" and type(celebi.texts) == "table" then
    for key, text in pairs(celebi.texts) do
      if type(key) == "string" and type(text) == "string" then
        mod.content.text:register("crystal_legacy_changes:celebi_" .. key, text)
      end
    end
  end

  mod.events:on("mods.loaded", function(payload)
    local target = payload and payload.data
    if not target then return end
    local scripts = target.gen2Scripts
    if type(scripts) ~= "table" then return end

    -- Shrine read bgEvent: the Dragon's Den B1F script becomes a straight
    -- mod command run (the VM normalizes { "verb" } rows to MOD_COMMAND).
    if type(master) == "table" and type(master.scriptKey) == "string"
      and type(master.verb) == "string" then
      scripts[master.scriptKey] = { { master.verb } }
      counts.statics = counts.statics + 1
    end

    -- Route 24 Mew (Phase 3b): splice CL's release into gold's EXISTING
    -- dex-completion diploma branch ("5e:4c9a" — gold's gate at "5e:4c8c"
    -- is already the CL formula, caught > 248 with Mew+Celebi excluded).
    -- After special 106, clear the Mew object flag unless the Route 24 Mew
    -- was already caught; the iftrue lands on a mod-owned script key.
    local mew = data.mew
    if type(mew) == "table" and type(mew.completedKey) == "string"
      and type(mew.flags) == "table" and type(mew.text) == "table" then
      scripts[mew.skipKey] = {
        { op = "writetext", text = mew.text.after_diploma },
        { op = "waitbutton" },
        { op = "closetext" },
        { op = "setevent", event = 214 },
        { op = "end" },
      }
      scripts[mew.completedKey] = {
        { op = "promptbutton" },
        { op = "writetext", text = mew.text.completed },
        { op = "playsound", id = 163 },
        { op = "waitsfx" },
        { op = "writetext", text = mew.text.pause },
        { op = "promptbutton" },
        { op = "special", id = 106 },
        { op = "checkevent", event = mew.flags.caught },
        { op = "iftrue", script = mew.skipKey },
        { op = "clearevent", event = mew.flags.mew },
        { op = "writetext", text = mew.text.after_diploma },
        { op = "waitbutton" },
        { op = "closetext" },
        { op = "setevent", event = 214 },
        { op = "end" },
      }
      counts.statics = counts.statics + 1
    end

    -- Kanto legendary birds (Phase 3c).  CL releases each bird as a one-time
    -- L60 wild encounter after its quest moment (Blaine -> Moltres, Blue ->
    -- Articuno, Machine Part returned -> Zapdos); gold has none of it.  CL's
    -- event is one EVENT_CAUGHT_<BIRD> flag per bird, seeded SET at NewGame
    -- so the static stays hidden until its release: we (a) seed the flags via
    -- gen2InitialEvents, (b) splice the clearevent into the release script at
    -- the anchor row, (c) register the catch script (opentext / "Gyaoo!" /
    -- cry / loadwildmon 60 / startbattle / disappear / setevent /
    -- reloadmapafterbattle) and (d) spawn the Moltres object (gold ships
    -- SPRITE_MOLTRES; Articuno and Zapdos are wired but their objects wait
    -- for Phase 4 overworld art — the object rows are in data.birds).  The
    -- engine's disappear op re-sets the object's eventFlag, so a caught bird
    -- stays gone on later map loads.
    if type(birds) == "table" then
      local initial = target.gen2InitialEvents
      if type(initial) == "table" and type(initial.flags) == "table" then
        for _, bird in ipairs(birds) do
          if type(bird) == "table" and type(bird.flag) == "number" then
            local known = false
            for _, id in ipairs(initial.flags) do
              if id == bird.flag then known = true break end
            end
            if not known then initial.flags[#initial.flags + 1] = bird.flag end
          end
        end
      end
      local maps = target.gen2Maps
      for _, bird in ipairs(birds) do
        if type(bird) == "table" and type(bird.scriptKey) == "string"
          and type(bird.speciesIndex) == "number" and type(bird.flag) == "number" then
          local rows = {
            { op = "opentext" },
            { op = "writetext", text = bird.textKey },
            { op = "cry", id = bird.speciesIndex },
            { op = "waitbutton" },
            { op = "closetext" },
            { op = "loadwildmon", species = bird.speciesIndex, level = bird.level },
            { op = "startbattle" },
            { op = "disappear", object = bird.objectIndex },
            { op = "setevent", event = bird.flag },
            { op = "reloadmapafterbattle" },
            { op = "end" },
          }
          if bird.faceplayer then
            table.insert(rows, 1, { op = "faceplayer" })
          end
          scripts[bird.scriptKey] = rows
          counts.statics = counts.statics + 1
          for _, seam in ipairs(bird.seams or {}) do
            local row = scripts[seam.scriptKey]
            if type(row) == "table" then
              for i, step in ipairs(row) do
                if type(step) == "table" and step.op == seam.afterOp
                  and (seam.afterEvent == nil or step.event == seam.afterEvent) then
                  table.insert(row, i + 1, { op = "clearevent", event = bird.flag })
                  counts.statics = counts.statics + 1
                  break
                end
              end
            end
          end
          if type(bird.object) == "table" and type(bird.object.mapId) == "string"
            and type(maps) == "table" then
            local map = maps[bird.object.mapId]
            if type(map) == "table" and type(map.objects) == "table" then
              table.insert(map.objects, bird.object)
              counts.statics = counts.statics + 1
            end
          end
        end
      end
    end

    -- Celebi / GS Ball (Phase 3c): full Crystal chain, mod-side (gold has
    -- none of it — no GS_BALL item, no shrine event, vanilla-only Kurt).
    -- (a) GS_BALL item def at index 251 (bag/checkitem/takeitem/verbosegiveitem
    -- resolve by index — no engine work; pack icon Phase 4).  (b) The gift:
    -- a LINK_RECEPTIONIST appended to the Goldenrod Pokecenter (gold has no
    -- receptionist there) with CL's gift flow.  (c) Kurt: two checkevent/
    -- iftrue rows spliced after his opentext branch to the give/gave scripts
    -- (give = 7-badge gate + yesorno + take the ball; gave = return it and
    -- set FOREST_IS_RESTLESS — CL's Azalea return scene simplified away, see
    -- data/statics.lua).  (d) The Ilex shrine bg_event repointed to the
    -- shrine script (quiet gold text until restless; checkitem -> yesorno ->
    -- takeitem -> Celebi L30 wild battle — Celebi is a wild battle, no
    -- SPRITE_CELEBI needed).  (e) The Ruins of Alph fallback: a RESEARCHER
    -- appended to the Inner Chamber offering the ball if never gotten (gold
    -- has no Ho-Oh-puzzle events, so no puzzle gate).
    local celebi = data.celebi
    if type(celebi) == "table" then
      local flags = celebi.flags
      local cKeys = celebi.scriptKeys
      local cText = "crystal_legacy_changes:celebi_"
      local gsBall = type(celebi.item) == "table" and celebi.item.index
      -- (a) the item def.
      local items = target.items
      if type(items) == "table" and gsBall then
        items[celebi.item.id] = celebi.item
        counts.statics = counts.statics + 1
      end
      local maps = target.gen2Maps
      if type(maps) == "table" and gsBall and type(flags) == "table" then
        -- (b) the gift (always-visible receptionist; every gate is in-script).
        scripts[cKeys.gift] = {
          { op = "faceplayer" },
          { op = "opentext" },
          { op = "checkevent", event = flags.got },
          { op = "iftrue", script = cKeys.giftDone },
          { op = "writetext", text = cText .. "gift" },
          { op = "verbosegiveitem", item = gsBall },
          { op = "setevent", event = flags.got },
          { op = "setevent", event = flags.canGive },
          { op = "closetext" },
          { op = "end" },
        }
        scripts[cKeys.giftDone] = { { op = "closetext" }, { op = "end" } }
        counts.statics = counts.statics + 1
        local pc = maps[celebi.pokecenter.mapId]
        if type(pc) == "table" and type(pc.objects) == "table" then
          table.insert(pc.objects, {
            eventFlag = 65535,
            index = celebi.pokecenter.objectIndex,
            movement = 6, -- STANDING_DOWN
            palette = 0,
            radius = { x = 0, y = 0 },
            script = 0,
            scriptKey = cKeys.gift,
            sight = 0,
            sprite = celebi.pokecenter.sprite,
            spriteId = 0,
            type = 0,
            x = celebi.pokecenter.coords.x,
            y = celebi.pokecenter.coords.y,
          })
          counts.statics = counts.statics + 1
        end
        -- (c) Kurt: splice the branch rows after his opentext; the give and
        -- gave flows live in mod-owned scripts (CL's KurtScript structure).
        local kurt = scripts[celebi.kurt.scriptKey]
        if type(kurt) == "table" then
          for i, step in ipairs(kurt) do
            if type(step) == "table" and step.op == "opentext" then
              local splice = {
                { op = "checkevent", event = flags.gave },
                { op = "iftrue", script = cKeys.kurtGave },
                { op = "checkevent", event = flags.canGive },
                { op = "iftrue", script = cKeys.kurtGive },
              }
              for k, row in ipairs(splice) do
                table.insert(kurt, i + k, row)
              end
              counts.statics = counts.statics + 1
              break
            end
          end
        end
        scripts[cKeys.kurtGive] = {
          -- CL .CanGiveGSBallToKurt: badge gate, then ask to examine the
          -- ball; YES takes it (the gave flow returns it once examined).
          { op = "writetext", text = cText .. "kurtWhat" },
          { op = "waitbutton" },
          { op = "writetext", text = cText .. "kurtNo" },
          { op = "waitbutton" },
          { op = "readvar", var = 0x07 }, -- VAR_BADGES
          { op = "ifless", value = celebi.badgeGate, script = {
            { op = "writetext", text = cText .. "kurtChecking" },
            { op = "waitbutton" },
            { op = "closetext" },
            { op = "end" },
          } },
          { op = "yesorno" },
          { op = "iftrue", script = cKeys.kurtGiveDecline }, -- NO keeps the ball
          { op = "closetext" },
          { op = "setevent", event = flags.gave },
          { op = "takeitem", item = gsBall },
          { op = "writetext", text = cText .. "kurtChecking" },
          { op = "waitbutton" },
          { op = "closetext" },
          { op = "end" },
        }
        scripts[cKeys.kurtGiveDecline] = { { op = "closetext" }, { op = "end" } }
        scripts[cKeys.kurtGave] = {
          -- CL .NotMakingBalls, simplified: Kurt returns the ball in-house
          -- (CL has him leave town and hand it back in an Azalea scene) and
          -- sets the forest restless so the shrine wakes.
          { op = "writetext", text = cText .. "kurtShake" },
          { op = "waitbutton" },
          { op = "closetext" },
          { op = "setevent", event = flags.restless },
          { op = "clearevent", event = flags.canGive },
          { op = "clearevent", event = flags.gave },
          { op = "verbosegiveitem", item = gsBall },
          { op = "end" },
        }
        counts.statics = counts.statics + 1 -- kurt give
        counts.statics = counts.statics + 1 -- kurt gave
        -- (d) Ilex shrine: repoint the (8,22) bg_event to the shrine script.
        local shrineMap = maps[celebi.shrine.mapId]
        if type(shrineMap) == "table" and type(shrineMap.bgEvents) == "table" then
          for _, bg in ipairs(shrineMap.bgEvents) do
            if type(bg) == "table" and bg.scriptKey == celebi.shrine.scriptKey then
              bg.scriptKey = cKeys.shrine
              counts.statics = counts.statics + 1
              break
            end
          end
        end
        scripts[cKeys.shrine] = {
          -- Quiet until Kurt wakes the forest; then the ball is consumed for
          -- the one-shot Celebi battle (CL IlexForestShrineScript).
          { op = "checkevent", event = flags.restless },
          { op = "iftrue", script = {
            { op = "checkitem", item = gsBall },
            { op = "iftrue", script = {
              { op = "opentext" },
              { op = "writetext", text = cText .. "shrinePrompt" },
              { op = "waitbutton" },
              { op = "yesorno" },
              { op = "iftrue", script = cKeys.shrineBattle },
              { op = "closetext" },
              { op = "end" },
            } },
            { op = "jumptext", text = celebi.shrine.quietText },
          } },
          { op = "jumptext", text = celebi.shrine.quietText },
        }
        scripts[cKeys.shrineBattle] = {
          { op = "takeitem", item = gsBall },
          { op = "clearevent", event = flags.restless },
          { op = "opentext" },
          { op = "writetext", text = cText .. "shrineInsert" },
          { op = "waitbutton" },
          { op = "closetext" },
          { op = "loadwildmon", species = celebi.speciesIndex, level = celebi.level },
          { op = "startbattle" },
          { op = "reloadmapafterbattle" },
          { op = "end" },
        }
        counts.statics = counts.statics + 1 -- shrine script (+battle)
        -- (e) Ruins of Alph fallback: always-visible researcher, gated on
        -- the got flag (no gold Ho-Oh-puzzle events to gate on).
        scripts[cKeys.fallback] = {
          { op = "faceplayer" },
          { op = "opentext" },
          { op = "checkevent", event = flags.got },
          { op = "iftrue", script = cKeys.fallbackDone },
          { op = "writetext", text = cText .. "fallback" },
          { op = "verbosegiveitem", item = gsBall },
          { op = "setevent", event = flags.got },
          { op = "setevent", event = flags.canGive },
          { op = "closetext" },
          { op = "end" },
        }
        scripts[cKeys.fallbackDone] = { { op = "closetext" }, { op = "end" } }
        counts.statics = counts.statics + 1
        local ruins = maps[celebi.fallback.mapId]
        if type(ruins) == "table" and type(ruins.objects) == "table" then
          table.insert(ruins.objects, {
            eventFlag = 65535,
            index = celebi.fallback.objectIndex,
            movement = 6, -- STANDING_DOWN
            palette = 0,
            radius = { x = 0, y = 0 },
            script = 0,
            scriptKey = cKeys.fallback,
            sight = 0,
            sprite = celebi.fallback.sprite,
            spriteId = 0,
            type = 0,
            x = celebi.fallback.coords.x,
            y = celebi.fallback.coords.y,
          })
          counts.statics = counts.statics + 1
        end
      end
    end

    local gc = data.gameCorner
    if type(gc) ~= "table" then return end

    -- Prize menu strings live inline on the loadmenu rows (the "57:688f"
    -- copy is the post-prize re-entry).  Swap both to the CL item list.
    for _, key in ipairs(gc.menu or {}) do
      local row = scripts[key]
      if type(row) == "table" then
        for _, step in ipairs(row) do
          if type(step) == "table" and step.op == "loadmenu" then
            step.menu = step.menu or {}
            step.menu.items = gc.items
          end
        end
      end
    end

    -- Each prize arm carries its price little-endian ({lo, hi}) in the
    -- checkcoins/takecoins ops plus the species/level in givepoke (and the
    -- matching getmonname/setval species for the name + party-scan).
    for _, prize in ipairs(gc.prizes or {}) do
      local row = scripts[prize.script]
      if type(row) == "table" then
        local lo = prize.price % 256
        local hi = math.floor(prize.price / 256)
        for _, step in ipairs(row) do
          if type(step) == "table" then
            if step.op == "checkcoins" or step.op == "takecoins" then
              step.args = { lo, hi }
            elseif step.op == "givepoke" then
              step.species = prize.species
              step.level = prize.level
            elseif step.op == "getmonname" then
              step.species = prize.species
            elseif step.op == "setval" then
              step.args = { prize.species }
            end
          end
        end
        counts.statics = counts.statics + 1
      end
    end
  end)
end

-- Fossils & Ruins of Alph (Phase 3a).  The Gold ROM ships no fossil items
-- (its item table is renumbered -- OLD_AMBER/DOME_FOSSIL/HELIX_FOSSIL were
-- removed) and no reachable revival flow: the Research Center's three
-- scientists resolve to flavor text only.  Crystal Legacy restores the
-- fossils as inert items, makes the top-right scientist revive them (Kabuto
-- L15 / Omanyte L20 / Aerodactyl L25), and has the three chamber puzzles hand
-- the fossils out, gated by the Johto gym badges (Plain=Gym 3, Fog=Gym 4,
-- Glacier=Gym 7).
--
-- map_scripts is gated off on Gen 2 (Schemas.GEN2), so the "script" work
-- rides the seams that ARE routed: the items/text/commands registries plus
-- the same gen2Scripts in-place row patch applyStatics uses on mods.loaded.
-- The scientist's script row is replaced wholesale; each chamber's solved
-- sequence gets a reward command row after its event flags and each
-- MAPCALLBACK_TILES script gets a deferred-claim command row first (the
-- callback runs on every load of the map, so a puzzle solved before the
-- badge is earned is still claimable after -- it can never be stranded).
local function applyFossils(mod, data, counts)
  counts.fossils = { items = 0, text = 0, commands = 0, scripts = 0 }

  -- The three inert fossil items (QoL: real items now -- tossable, unusable
  -- in battle or the field, no held effect, price 0, in the ITEMS pocket).
  for _, item in ipairs(data.items or {}) do
    mod.content.items:register(item.id, item)
    counts.fossils.items = counts.fossils.items + 1
  end

  -- Custom text rows, keyed under the mod prefix into data.gen2Text.
  for key, text in pairs(data.text or {}) do
    mod.content.text:register("crystal_legacy_changes:" .. key, text)
    counts.fossils.text = counts.fossils.text + 1
  end

  local function saveOf()
    local game = mod.game
    return game and game.save
  end

  local function hasBadge(save, name)
    local badges = save and save.player and save.player.badges
    return type(badges) == "table" and badges[name] == true
  end

  -- The scientist's revival flow.  Party-full is checked BEFORE the fossil is
  -- consumed: the engine's World:givePoke ignores Party.add's return and
  -- would silently drop the mon at a full party (it is an unused cart path --
  -- vanilla Gold has no revival).  Each vm:showText blocks until the A press
  -- (the port's TextBox takes it), so the sequence reads like a vanilla talk.
  local function reviveScientist(ctx)
    local vm = ctx and ctx.vm
    if not vm then return end
    local revive = data.scientist and data.scientist.revive
    if not revive then return end
    vm:showText("crystal_legacy_changes:revive_greet")
    local found
    for _, entry in ipairs(revive) do
      local has = vm.hasItemFn and vm.hasItemFn(entry.itemIndex)
      if has then
        found = entry
        break
      end
    end
    if not found then
      vm:showText("crystal_legacy_changes:revive_none")
      return
    end
    local save = saveOf()
    if save and type(save.party) == "table" and #save.party >= 6 then
      vm:showText("crystal_legacy_changes:revive_party_full")
      return
    end
    local speciesLower = string.lower(found.species)
    vm:showText("crystal_legacy_changes:revive_" .. speciesLower)
    if vm.takeItemFn then vm.takeItemFn(found.itemIndex, 1) end
    if vm.givePokeFn then vm.givePokeFn(found.speciesIndex, found.level, nil) end
    vm:showText("crystal_legacy_changes:got_" .. speciesLower)
  end

  -- Puzzle solved: badge-gated, one-per-save fossil hand-out.  Runs as a row
  -- inside the solved sequence after its event flags, so the solve itself is
  -- untouched; without the badge it does nothing and the deferred arm below
  -- claims the fossil once the badge is earned.
  local function giveFossil(vm, ch)
    local flag = "ruins." .. ch.id
    if mod.save:get(flag) then return end
    local ok = vm.giveItemFn and vm.giveItemFn(ch.itemIndex, 1)
    if ok == false then
      vm:showText("crystal_legacy_changes:ruins_bag_full")
      return
    end
    mod.save:set(flag, true)
    vm:showText("crystal_legacy_changes:ruins_got_" .. string.lower(ch.id))
  end

  local function findChamber(chamberId)
    for _, ch in ipairs(data.chambers or {}) do
      if ch.id == chamberId then return ch end
    end
  end

  local function ruinsReward(ctx, chamberId)
    local vm = ctx and ctx.vm
    local ch = vm and findChamber(chamberId)
    if not ch then return end
    if not hasBadge(saveOf(), ch.badge) then return end
    giveFossil(vm, ch)
  end

  -- Chamber entry (MAPCALLBACK_TILES): claim the fossil once the badge is
  -- earned if the puzzle was solved without one.  Runs on every load of the
  -- map; the one-per-save flag makes it a no-op afterwards.
  local function ruinsDeferred(ctx, chamberId)
    local vm = ctx and ctx.vm
    local ch = vm and findChamber(chamberId)
    if not ch then return end
    local save = saveOf()
    if not save or not save.engineFlags then return end
    if not save.engineFlags[ch.solvedEvent] then return end -- puzzle not solved
    if not hasBadge(save, ch.badge) then return end
    giveFossil(vm, ch)
  end

  mod.commands:register("crystal_legacy_changes:revive_fossil", reviveScientist)
  mod.commands:register("crystal_legacy_changes:ruins_reward", ruinsReward)
  mod.commands:register("crystal_legacy_changes:ruins_deferred", ruinsDeferred)
  counts.fossils.commands = 3

  -- Row patches, on the same mods.loaded seam applyMarts/applyStatics use.
  mod.events:on("mods.loaded", function(payload)
    local target = payload and payload.data
    if not target then return end
    local scripts = target.gen2Scripts
    if type(scripts) ~= "table" then return end

    -- The top-right scientist talks to a straight command run.  The vanilla
    -- rows were flavor text only (no checkitem/takeitem/givepoke anywhere
    -- reachable on Gold), so the whole list is replaced.
    local scientist = data.scientist
    if type(scientist) == "table" and type(scientist.scriptKey) == "string" then
      scripts[scientist.scriptKey] = {
        { op = "faceplayer" },
        { op = "opentext" },
        { "crystal_legacy_changes:revive_fossil" },
        { op = "waitbutton" },
        { op = "closetext" },
        { op = "end" },
      }
      counts.fossils.scripts = counts.fossils.scripts + 1
    end

    -- Chamber solved sequences carry the reward arm right after their event
    -- flags (so the solve state is already committed); the MAPCALLBACK_TILES
    -- scripts carry the deferred-claim arm first.
    for _, ch in ipairs(data.chambers or {}) do
      local solved = scripts[ch.solvedScript]
      if type(solved) == "table" then
        local lastFlag
        for i, step in ipairs(solved) do
          if type(step) == "table" and (step.op == "setevent" or step.op == "setflag") then
            lastFlag = i
          end
        end
        if lastFlag then
          table.insert(solved, lastFlag + 1, { "crystal_legacy_changes:ruins_reward", ch.id })
          counts.fossils.scripts = counts.fossils.scripts + 1
        end
      end
      local callback = scripts[ch.callbackScript]
      if type(callback) == "table" then
        table.insert(callback, 1, { "crystal_legacy_changes:ruins_deferred", ch.id })
        counts.fossils.scripts = counts.fossils.scripts + 1
      end
    end
  end)

  mod.exports.fossils = {
    revive = reviveScientist,
    reward = ruinsReward,
    deferred = ruinsDeferred,
    hasBadge = hasBadge,
    data = data,
  }
end

-- Phase 3a berry shop: the Goldenrod Flower Shop gets CL's clerk selling the
-- MART_BERRYS / MART_BERRYS_2 shelves, badge-gated at 7 badges exactly like
-- CL's BerryMartScript.  The two shelves have no gold slot under NUM_MARTS =
-- 34, so they are appended at the first free mart ids (34/35 -> lists[35]/[36])
-- and the clerk's script is injected into gen2Scripts -- the same mods.loaded
-- seam applyMarts/applyStatics/applyFossils use.
--
-- BLOCKED ON PHASE 4 (engine): MartMenu.inventory (src/ui/gen2/MartMenu.lua:347)
-- unconditionally returns DEFAULT_MART for martId >= NUM_MARTS (34), so until
-- the engine fix (data-driven fallback: DEFAULT_MART only when
-- (marts.lists or marts)[martId + 1] is not a table) the clerk opens the menu
-- but shows Poke Ball/Potion.  The suite pins that current fallback.
local function applyBerryShop(mod, data, counts, martsData)
  counts.berryShop = { lists = 0, object = 0, script = 0 }

  mod.events:on("mods.loaded", function(payload)
    local target = payload and payload.data
    if not target then return end

    -- (a) Append the two berry shelves at the first free mart ids (34/35).
    local marts = target.gen2Marts
    if type(marts) == "table" and type(marts.lists) == "table" then
      local lists = marts.lists
      for i, name in ipairs(data.shelves or {}) do
        local stock = martsData and martsData.marts and martsData.marts[name]
        local id = data.martIds and data.martIds[i]
        if type(stock) == "table" and id then
          lists[id + 1] = stock
          counts.berryShop.lists = counts.berryShop.lists + 1
        end
      end
    end

    -- (b) Add CL's clerk object to the Flower Shop map def.
    local maps = target.gen2Maps
    local map = type(maps) == "table" and maps[data.map]
    if type(map) == "table" and type(map.objects) == "table"
      and type(data.clerk) == "table" then
      table.insert(map.objects, data.clerk)
      counts.berryShop.object = counts.berryShop.object + 1
    end

    -- (c) Inject BerryMartScript: faceplayer, opentext, readvar VAR_BADGES,
    --     if badged < 7 -> pokemart MART_BERRYS (id 34), else pokemart
    --     MART_BERRYS_2 (id 35), closetext, end (CL GoldenrodFlowerShop.asm
    --     :106-119).  mod rows use named fields (readvar.var, ifless.value +
    --     ifless.script, pokemart.martId), which runCmd reads directly.
    local scripts = target.gen2Scripts
    if type(scripts) == "table" and type(data.scriptKey) == "string" then
      local ids = data.martIds or {}
      scripts[data.scriptKey] = {
        { op = "faceplayer" },
        { op = "opentext" },
        { op = "readvar", var = 0x07 }, -- VAR_BADGES
        { op = "ifless", value = data.badgeGate or 7, script = {
            { op = "pokemart", martId = ids[1] },
        } },
        { op = "pokemart", martId = ids[2] },
        { op = "closetext" },
        { op = "end" },
      }
      counts.berryShop.script = counts.berryShop.script + 1
    end
  end)

  mod.exports.berryShop = { data = data }
end

-- Phase 3d: Goldenrod City Move Tutor (CL maps/GoldenrodCity.asm:52-165).
-- CL's tutor is a MAPCALLBACK_OBJECTS NPC who appears after 7 Badges with a
-- Coin Case and hides once taught today; gold has none, so the mod appends an
-- always-visible POKEFAN_M at CL's (12,22) and enforces every gate in the talk
-- script.  The 4-option menu is VM rows (verticalmenu -> scriptVar = choice);
-- a daily-gate command stops the script when today's lesson is used up, and a
-- teach command parks the VM coroutine on the party picker, gates the chosen
-- mon against CL's tmhm table (data/tutor_moves.lua -- NEVER species.tmhm,
-- that is the egg-move list), and hands off to Game2:learnMoveOn.  The async
-- onDone takes the 1000 coins, sets the daily flag, and says CL's farewell.
local function applyMoveTutor(mod, data, counts, tutorMoves)
  local prefix = "crystal_legacy_changes:"
  -- Species sets per move, from CL base_stats tmhm lines (conv_move_tutor.py).
  local sets = {}
  for moveName, list in pairs(tutorMoves.tutor_moves) do
    local set = {}
    for _, species in ipairs(list) do set[species] = true end
    sets[moveName] = set
  end
  -- CL text rows (plain \n line breaks; the port's TextBox paginates).
  for key, text in pairs(data.texts) do
    mod.content.text:register(prefix .. key, text)
  end
  -- Daily gate: stop the script ("come back tomorrow") when today's lesson is
  -- used up; return nil to fall through to the greet otherwise.  The handler's
  -- return feeds runCmd ("end" halts the list, nil continues at the next row).
  local function moveTutorDaily(ctx)
    local vm = ctx and ctx.vm
    if not vm then return "end" end
    local save = mod.game and mod.game.save
    if save and save.dailyFlags and save.dailyFlags[data.dailyKey] then
      vm:showText(prefix .. "daily")
      return "end"
    end
    return nil
  end
  -- Teach flow: party picker -> species gate -> KnowsMove gate -> learnMoveOn.
  local function moveTutorTeach(ctx, moveName)
    local vm = ctx and ctx.vm
    if not vm then return "end" end
    local game = mod.game
    local save = game and game.save
    if not (game and save) then return "end" end
    if save.dailyFlags and save.dailyFlags[data.dailyKey] then
      vm:showText(prefix .. "daily")
      return "end"
    end
    -- Party-picker bridge: {kind="mod_party_picker"} is unknown to Vm:resume's
    -- chain, so the coroutine parks with self.pending set; the Gen2PartyMenu
    -- onChoose calls vm:resume(mon) (nil on cancel) to drive it forward.
    local chosen = coroutine.yield({ kind = "mod_party_picker" })
    if not chosen then return "end" end
    local mon = chosen
    -- CL MoveTutor special contract: refuse species CL cannot teach this move
    -- and mons that already know it.  Mod-side species table only.
    local set = sets[moveName]
    if not (set and set[mon.species]) then
      vm:showText(prefix .. "incompatible")
      return "end"
    end
    for _, move in ipairs(mon.moves or {}) do
      if move.id == moveName then
        vm:showText(prefix .. "incompatible")
        return "end"
      end
    end
    vm:showText(prefix .. "understood")
    -- The engine's own TM-teach path (async screens).  onDone fires after the
    -- script has ended, so the coin take, daily flag and farewell go through
    -- game:say (push + callback, coroutine-free).
    game:learnMoveOn(mon, moveName, function(learned)
      if not learned then return end
      if save.player then
        save.player.coins = math.max(0, (save.player.coins or 0) - data.cost)
      end
      save.dailyFlags = save.dailyFlags or {}
      save.dailyFlags[data.dailyKey] = true
      game:say(data.texts.farewell)
    end)
    return "end"
  end
  mod.commands:register(prefix .. "move_tutor_daily", moveTutorDaily)
  mod.commands:register(prefix .. "move_tutor_teach", moveTutorTeach)

  -- Inline refusal/teach branch lists; each ends itself (runCmd semantics).
  local function refuse(textKey)
    return {
      { op = "writetext", text = prefix .. textKey },
      { op = "waitbutton" },
      { op = "closetext" },
      { op = "end" },
    }
  end
  local function teach(moveName)
    return {
      { prefix .. "move_tutor_teach", moveName },
      { op = "waitbutton" },
      { op = "closetext" },
      { op = "end" },
    }
  end
  -- checkcoins/takecoins amounts ride args as a little-endian dw.
  local coinArgs = { data.cost % 256, math.floor(data.cost / 256) }

  mod.events:on("mods.loaded", function(payload)
    local target = payload.data
    local scripts = target.gen2Scripts
    local maps = target.gen2Maps
    if type(scripts) ~= "table" or type(maps) ~= "table" then return end
    -- Append the tutor object in place (the berry clerk pattern); eventFlag
    -- 65535 = always visible, every gate lives in the talk script below.
    local map = maps[data.map]
    if type(map) == "table" and type(map.objects) == "table" then
      table.insert(map.objects, data.tutor)
      counts.moveTutorObjects = (counts.moveTutorObjects or 0) + 1
    end
    -- CL MoveTutorScript re-created as VM rows, with CL's callback gates
    -- (badges / Coin Case / daily) moved into the talk.  Branch targets are
    -- inline { ... } lists (runCmd).
    scripts[data.scriptKey] = {
      { op = "faceplayer" },
      { op = "opentext" },
      -- CL callback gates, moved into the talk (always-visible object).
      { op = "readvar", var = 0x07 }, -- VAR_BADGES
      { op = "ifless", value = data.badgeGate, script = refuse("badge") },
      { args = { data.coinCaseItem }, op = "checkitem" }, -- COIN_CASE
      { op = "iffalse", script = refuse("coinCase") },
      { prefix .. "move_tutor_daily" }, -- returns "end" once taught today
      -- CL MoveTutorScript body (faceplayer/opentext already done).
      { op = "writetext", text = prefix .. "greet" },
      { op = "yesorno" },
      { op = "iffalse", script = refuse("no") },
      { op = "writetext", text = prefix .. "coinsAsk" },
      { op = "yesorno" },
      { op = "iffalse", script = refuse("tooBad") },
      { args = coinArgs, op = "checkcoins" }, -- >= 1000 coins
      { op = "ifequal", value = 2, script = refuse("insufficient") }, -- HAVE_LESS
      { op = "special", id = 78 }, -- DisplayCoinCaseBalance
      { op = "writetext", text = prefix .. "which" },
      { op = "loadmenu", menu = data.menu },
      { op = "verticalmenu" },
      { op = "closewindow" },
      { op = "ifequal", value = 1, script = teach("FLAMETHROWER") },
      { op = "ifequal", value = 2, script = teach("THUNDERBOLT") },
      { op = "ifequal", value = 3, script = teach("ICE_BEAM") },
      { op = "end" }, -- CANCEL
    }
    counts.moveTutorScripts = (counts.moveTutorScripts or 0) + 1
  end)
  mod.exports.moveTutor = {
    data = data,
    daily = moveTutorDaily,
    teach = moveTutorTeach,
  }
  return counts
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
  applyEvolutions(mod, loadSibling(mod, "data/evolutions.lua"), counts)
  counts.statics = 0
  applyStatics(mod, loadSibling(mod, "data/statics.lua"), counts)
  applyFossils(mod, loadSibling(mod, "data/fossils.lua"), counts)
  applyBerryShop(mod, loadSibling(mod, "data/berry_shop.lua"), counts,
    loadSibling(mod, "data/marts.lua"))
  applyMoveTutor(mod, loadSibling(mod, "data/move_tutor.lua"), counts,
    loadSibling(mod, "data/tutor_moves.lua"))
  mod.exports.rebalance = counts
end
