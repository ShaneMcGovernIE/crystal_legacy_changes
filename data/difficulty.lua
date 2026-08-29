-- Difficulty and battle mechanics for Crystal Legacy parity:
-- 1. Interactive Oak intro difficulty selection with live descriptions on hover & confirmation prompt.
-- 2. Trainer held items from data/trainers.lua attached to enemy party in battle.
-- 3. Triple Kick 20 -> 60 -> 120 power progression.
-- 4. Hard / Hardcore difficulty modes (item ban, set mode, level caps, permadeath).

-- Exact Crystal Legacy level caps from cRz-Shadows/Pokemon_Crystal_Legacy source:
-- PlayersHouse1F.asm (0 Badges): 10 (Falkner's ace Noctowl is Lv 10)
-- VioletGym.asm (1 Badge): 16 (Bugsy's ace Scyther is Lv 16)
-- AzaleaGym.asm (2 Badges): 21 (Whitney's ace Miltank is Lv 21)
-- GoldenrodGym.asm (3 Badges): 25 (Morty's ace Gengar is Lv 25)
-- EcruteakGym.asm (4 Badges): 31 (Chuck's ace Poliwrath is Lv 31)
-- Cianwood/Olivine/Mahogany (5 Badges): 36 (2nd Mid-gym)
-- Cianwood/Olivine/Mahogany (6 Badges): 38 (3rd Mid-gym)
-- Cianwood/Olivine/Mahogany (7 Badges): 45 (Clair's ace Kingdra is Lv 45)
-- DragonShrine.asm (8 Badges): 50 (Will's ace Xatu is Lv 50)
-- WillsRoom.asm (Will beaten): 52 (Koga's ace Crobat is Lv 52)
-- KogasRoom.asm (Koga beaten): 54 (Bruno's ace Machamp is Lv 54)
-- BrunosRoom.asm (Bruno beaten): 55 (Karen's ace Houndoom is Lv 55).
-- KarensRoom.asm sets no cap, so Lance (ace Dragonite Lv 56) is fought at 55
-- too; LancesRoom.asm raises the cap to 60 only AFTER the Lance battle.
-- LancesRoom.asm (Lance beaten / Kanto intro): 60 (Kanto routes; Lt. Surge's
-- ace Raichu is Lv 60, fought later under the 10-badge cap of 63).
-- std_scripts.asm (9 Badges): 62
-- std_scripts.asm (10 Badges): 63
-- std_scripts.asm (11 Badges): 64
-- std_scripts.asm (12 Badges): 66
-- std_scripts.asm (13 Badges): 66
-- std_scripts.asm (14 Badges): 67
-- std_scripts.asm (15 Badges): 69
-- std_scripts.asm (16 Badges): 69 -> 77 (post-Lance rematch) -> 93 (Red's Pikachu is Lv 93)
-- SilverCaveRoom3.asm (Red beaten): 100

local BADGE_LEVEL_CAPS = {
  [0] = 10,  -- Falkner (Noctowl Lv 10)
  [1] = 16,  -- Bugsy (Scyther Lv 16)
  [2] = 21,  -- Whitney (Miltank Lv 21)
  [3] = 25,  -- Morty (Gengar Lv 25)
  [4] = 31,  -- Chuck (Poliwrath Lv 31)
  [5] = 36,  -- 2nd Mid-gym
  [6] = 38,  -- 3rd Mid-gym
  [7] = 45,  -- Clair (Kingdra Lv 45)
  [8] = 50,  -- Elite Four: Will (Xatu Lv 50)
  [9] = 62,  -- Kanto 1st Gym
  [10] = 63, -- Kanto 2nd Gym
  [11] = 64, -- Kanto 3rd Gym
  [12] = 66, -- Kanto 4th Gym
  [13] = 66, -- Kanto 5th Gym
  [14] = 67, -- Kanto 6th Gym
  [15] = 69, -- Kanto 7th Gym
  [16] = 93, -- Red (Pikachu Lv 93)
}

local JOHTO_BADGE_NAMES = { "ZEPHYR", "HIVE", "PLAIN", "FOG", "MINERAL", "STORM", "GLACIER", "RISING" }
local KANTO_BADGE_NAMES = { "BOULDER", "CASCADE", "THUNDER", "RAINBOW", "SOUL", "MARSH", "VOLCANO", "EARTH" }

local function countPlayerBadges(save)
  if not save then return 0 end
  local player = save.player or {}
  local johto = player.badges or player.johtoBadges or {}
  local kanto = player.kantoBadges or {}
  local engineFlags = save.engineFlags or {}

  local count = 0
  for _, has in pairs(johto) do
    if has then count = count + 1 end
  end
  for _, has in pairs(kanto) do
    if has then count = count + 1 end
  end

  if count == 0 then
    -- Check engine flags (ENGINE_ZEPHYRBADGE etc)
    for idx, name in ipairs(JOHTO_BADGE_NAMES) do
      local flagId = 25 + idx
      if engineFlags[flagId] == true or engineFlags["ENGINE_" .. name .. "BADGE"] == true then
        count = count + 1
      end
    end
    for idx, name in ipairs(KANTO_BADGE_NAMES) do
      local flagId = 33 + idx
      if engineFlags[flagId] == true or engineFlags["ENGINE_" .. name .. "BADGE"] == true then
        count = count + 1
      end
    end
  end

  if count == 0 and type(save.badges) == "number" then
    count = save.badges
  end

  return count
end

local function getLevelCap(save)
  local badges = countPlayerBadges(save)
  local events = (save and save.events) or {}

  -- 16 Badges (All Kanto Gyms defeated)
  if badges >= 16 then
    if events.EVENT_RED_IN_MT_SILVER or events[1890] then
      return 100
    end
    return 93
  end

  -- 8 Badges (Beat Clair, progressing through Indigo Plateau)
  if badges == 8 then
    if events.EVENT_BEAT_ELITE_FOUR or events[68] then
      return 60 -- Post-Lance / entering Kanto
    elseif events.EVENT_BEAT_ELITE_4_BRUNO or events[1466] then
      return 55 -- Karen is Lv 55, Lance is Lv 56
    elseif events.EVENT_BEAT_ELITE_4_KOGA or events[1465] then
      return 54 -- Bruno is Lv 54
    elseif events.EVENT_BEAT_ELITE_4_WILL or events[1464] then
      return 52 -- Koga is Lv 52
    else
      return 50 -- Will is Lv 50
    end
  end

  return BADGE_LEVEL_CAPS[badges] or (badges >= 16 and 93 or 10)
end

local function getTrainerHeldItems(trainersData)
  local itemMap = {}
  for classId, classData in pairs(trainersData.classes or {}) do
    itemMap[classId] = {}
    for _, tr in ipairs(classData.trainers or {}) do
      local partyItems = {}
      for slotIdx, slot in ipairs(tr.party or {}) do
        if slot.item then
          partyItems[slotIdx] = slot.item
        end
      end
      itemMap[classId][tr.index or 1] = partyItems
    end
  end
  return itemMap
end

local function getDifficultyMode(mod, save)
  save = save or (rawget(_G, "Game") and Game.save)
  if save then
    if save.difficulty and save.difficulty ~= "" then return save.difficulty end
    if save.options and save.options.difficulty and save.options.difficulty ~= "" then return save.options.difficulty end
  end
  if mod and mod.difficultyMode and mod.difficultyMode ~= "" then return mod.difficultyMode end
  local mode = mod and mod.save and mod.save:get("difficulty")
  if mode and mode ~= "" then return mode end
  return "normal"
end

local function isHardMode(mode)
  return mode == "hard" or mode == "hardcore"
end

local function installRareCandyCap(mod)
  if mod.content and mod.content.item_effects and mod.content.item_effects.get then
    local vanilla = mod.content.item_effects:get("RARE_CANDY")
    if vanilla and vanilla.use then
      mod.content.item_effects:patch("RARE_CANDY", {
        use = function(ctx)
          local game = mod.game
          local save = (game and game.save)
            or (rawget(_G, "Game") and Game.save)
          local mode = getDifficultyMode(mod, save)
          if isHardMode(mode) and ctx.mon
              and (ctx.mon.level or 1) >= getLevelCap(save) then
            local ItemEffects = require("src.core.gen2.ItemEffects")
            return { used = false, text = ItemEffects.TEXT_NO_EFFECT }
          end
          return vanilla.use(ctx)
        end,
      })
    end
  end

  local okIE, ItemEffects = pcall(require, "src.core.gen2.ItemEffects")
  if okIE and ItemEffects and ItemEffects.useOnMon then
    local origUseOnMon = ItemEffects.useOnMon
    ItemEffects.useOnMon = function(itemId, mon, data)
      if mon and not mon.isEgg then
        local save = rawget(_G, "Game") and Game.save
        local mode = getDifficultyMode(mod, save)
        if isHardMode(mode) then
          if itemId == "RARE_CANDY" then
            local cap = getLevelCap(save)
            if (mon.level or 1) >= cap then
              return { used = false, text = ItemEffects.TEXT_NO_EFFECT }
            end
          elseif (mode == "hardcore") and (mon.dead or mon.permaFainted) then
            if itemId == "REVIVE" or itemId == "MAX_REVIVE" or itemId == "REVIVAL_HERB"
                or (ItemEffects.REVIVE and ItemEffects.REVIVE[itemId]) then
              return { used = false, text = ItemEffects.TEXT_NO_EFFECT }
            end
          end
        end
      end
      return origUseOnMon(itemId, mon, data)
    end
  end
end

local function openDifficultySelect(mod, oakSpeech, onDone)
  local game = oakSpeech.game
  local data = game and game.data
  local choices = {
    {
      label = "NORMAL",
      val = "normal",
      desc1 = "Standard Crystal",
      desc2 = "Legacy gameplay.",
      confirm = "Play NORMAL mode?",
    },
    {
      label = "HARD",
      val = "hard",
      desc1 = "Item ban, SET mode",
      desc2 = "& gym level caps.",
      confirm = "Play HARD mode?",
    },
    {
      label = "HARDCORE",
      val = "hardcore",
      desc1 = "Hard mode plus",
      desc2 = "permadeath rules!",
      confirm = "Play HARDCORE?",
    },
  }

  local screen = {
    cursor = 1,
    state = "select", -- "select" | "confirm"
    yesCursor = 1,
    isOpaque = true,
  }

  function screen:wantsFillScale() return true end
  function screen:drawsWidescreen() return true end

  function screen:playSfx(name)
    pcall(function()
      local Sound = require("src.core.Sound")
      if data then Sound.play(data, name) end
    end)
  end

  function screen:update(_dt)
    local input = game and game.input
    if not input then return end

    if self.state == "select" then
      if input:wasPressed("up") then
        self.cursor = (self.cursor > 1) and (self.cursor - 1) or #choices
        self:playSfx("Sfx_ChooseAChoice")
      elseif input:wasPressed("down") then
        self.cursor = (self.cursor < #choices) and (self.cursor + 1) or 1
        self:playSfx("Sfx_ChooseAChoice")
      elseif input:wasPressed("a") or input:wasPressed("confirm") or input:wasPressed("start") then
        self.state = "confirm"
        self.yesCursor = 1
        self:playSfx("Sfx_PressABtn")
      end
    elseif self.state == "confirm" then
      if input:wasPressed("up") or input:wasPressed("down") then
        self.yesCursor = (self.yesCursor == 1) and 2 or 1
        self:playSfx("Sfx_ChooseAChoice")
      elseif input:wasPressed("b") or input:wasPressed("cancel") then
        self.state = "select"
        self:playSfx("Sfx_ChooseAChoice")
      elseif input:wasPressed("a") or input:wasPressed("confirm") or input:wasPressed("start") then
        if self.yesCursor == 1 then
          self:playSfx("Sfx_PressABtn")
          local chosen = choices[self.cursor].val
          mod.difficultyMode = chosen
          if mod.save then
            mod.save:set("difficulty", chosen)
          end
          if game and game.save then
            game.save.difficulty = chosen
          end
          if oakSpeech.answers then
            oakSpeech.answers.difficulty = chosen
          end
          if isHardMode(chosen) then
            if game and game.options then
              game.options.battleStyle = "SET"
            end
            if game and game.save and game.save.options then
              game.save.options.battleStyle = "SET"
            end
          end
          if game and game.stack then
            game.stack:pop()
          end
          onDone()
        else
          self.state = "select"
          self:playSfx("Sfx_ChooseAChoice")
        end
      end
    end
  end

  function screen:drawPanel()
    -- The released engine's only Chrome is src.ui.gen2.Chrome (clear/box/
    -- print/cursor/printThrough).  src.ui.Chrome (drawBox) does not exist on
    -- any shipped build, and requiring it crashes the game the first frame
    -- this screen draws -- right before the demo-mon reveal.  Keep the Gen 2
    -- chrome here; a fullscreen pixel-menu restyle can land with the engine
    -- build that actually ships src.ui.Chrome.
    local Chrome = require("src.ui.gen2.Chrome")
    Chrome.clear()
    oakSpeech:drawPic()

    -- 1. Mode options box
    Chrome.box(4, 1, 14, 8)
    for idx, c in ipairs(choices) do
      local y = 1 + idx * 2
      Chrome.print(c.label, 7, y)
    end
    -- Cursor
    Chrome.cursor(5, 1 + self.cursor * 2)

    -- 2. Bottom Description / Confirmation Textbox
    Chrome.box(0, 10, 20, 8)
    local curChoice = choices[self.cursor]

    if self.state == "select" then
      Chrome.print(curChoice.desc1, 1, 12)
      Chrome.print(curChoice.desc2, 1, 14)
      Chrome.print("A: SELECT", 1, 16)
    elseif self.state == "confirm" then
      Chrome.print(curChoice.confirm, 1, 12)
      Chrome.print("Are you sure?", 1, 14)

      -- YES / NO prompt box
      Chrome.box(13, 4, 6, 5)
      Chrome.print("YES", 15, 5)
      Chrome.print("NO", 15, 7)
      Chrome.cursor(14, 5 + (self.yesCursor - 1) * 2)
    end
  end

  function screen:draw()
    self:drawPanel()
  end

  function screen:drawWidescreen(winW, winH)
    local Chrome = require("src.ui.gen2.Chrome")
    local G = love.graphics
    G.setColor(1, 1, 1, 1)
    G.rectangle("fill", 0, 0, winW, winH)
    local scale = Chrome.fitScale(winW, winH)
    local ox, oy = Chrome.fitOrigin(winW, winH, scale)
    G.push()
    G.translate(ox, oy)
    G.scale(scale, scale)
    self:drawPanel()
    G.pop()
  end

  if game and game.stack then
    game.stack:push(screen)
  else
    onDone()
  end
end

local function applyDifficulty(mod, trainersData)
  local trainerItemMap = getTrainerHeldItems(trainersData)
  installRareCandyCap(mod)

  -- Sync difficulty mode on save events
  mod.events:on("save.loaded", function(payload)
    local save = payload and payload.save
    local mode = (mod.save and mod.save:get("difficulty")) or (save and save.difficulty)
    if mode and mode ~= "" then
      mod.difficultyMode = mode
      if save then save.difficulty = mode end
      if isHardMode(mode) and save and save.options then
        save.options.battleStyle = "SET"
      end
    end
  end)

  mod.events:on("save.created", function(payload)
    local save = payload and payload.save
    local mode = (mod.save and mod.save:get("difficulty")) or mod.difficultyMode
    if mode and mode ~= "" and save then
      save.difficulty = mode
      if isHardMode(mode) and save.options then
        save.options.battleStyle = "SET"
      end
    end
  end)

  -- 1. Oak Speech New Game: Interactive difficulty picker with descriptions & confirm
  mod.hooks:wrap("intro.oak_speech.build", function(next, steps, speech)
    local res = next(steps, speech) or steps
    local custom = {}
    for _, st in ipairs(res) do
      custom[#custom + 1] = st
      if st.id == "oak_welcome" then
        custom[#custom + 1] = {
          id = "cl_difficulty_select",
          kind = "fn",
          run = function(oakSpeech, onDone)
            openDifficultySelect(mod, oakSpeech, onDone)
          end,
        }
      end
    end
    return custom
  end, 50)

  -- 1b. Crystal Legacy's intro demo mon is WOOPER (`ld a, WOOPER` in CL and
  -- vanilla pokecrystal engine/menus/intro_menu.asm), revealed between
  -- oak_welcome and the difficulty pick.  Engine builds that predate the
  -- edition-aware extractor hardcode MARILL, so pin the species, sprite, and
  -- palette from the mod on every build.  intro.oak_speech.started fires in
  -- enter() before any step runs, and the demo step reads these fields at
  -- draw/cry time, so overwriting them there is safe.
  mod.events:on("intro.oak_speech.started", function(payload)
    local speech = payload and payload.speech
    if not speech then return end
    speech.demoSpecies = "WOOPER"
    local okAssets, Assets = pcall(require, "src.render.Assets")
    if okAssets and type(Assets) == "table" and type(Assets.image) == "function" then
      local okImg, img = pcall(Assets.image, "assets/generated/battle/front/wooper.png")
      if okImg and img then speech.marillPic = img end
    end
    local okPal, Palettes = pcall(require, "src.world.gen2.Palettes")
    if okPal and type(Palettes) == "table" and type(Palettes.monColors) == "function" then
      local okColors, colors = pcall(Palettes.monColors,
        speech.game and speech.game.data and speech.game.data.gen2Palettes, "WOOPER")
      if okColors and colors then speech.marillColors = colors end
    end
  end)

  -- 2. Trainer Held Items: Hook trainer party / battle start to equip canonical held items
  mod.hooks:wrap("trainer.party", function(next, oppClass, partyIndex, partyDef)
    local party = next(oppClass, partyIndex, partyDef) or partyDef
    local classItems = trainerItemMap[oppClass]
    local items = classItems and (classItems[partyIndex] or classItems[1])
    if items and type(party) == "table" then
      for idx, slot in ipairs(party) do
        if items[idx] and not slot.item then
          slot.item = items[idx]
        end
      end
    end
    return party
  end, 50)

  mod.events:on("battle.started", function(payload)
    local battle = payload and payload.battle
    if not battle or not battle.enemyParty then return end
    local save = (battle.game and battle.game.save) or battle.save
    local mode = getDifficultyMode(mod, save)
    if isHardMode(mode) then
      if battle.game and battle.game.options then
        battle.game.options.battleStyle = "SET"
      end
      if battle.game and battle.game.save and battle.game.save.options then
        battle.game.save.options.battleStyle = "SET"
      end
      if battle.save and battle.save.options then
        battle.save.options.battleStyle = "SET"
      end
    end
    local oppClass = battle.trainer and (battle.trainer.classId or battle.trainer.id or battle.trainer.class) or battle.oppClass
    local partyIndex = battle.partyIndex or (battle.trainer and battle.trainer.index) or 1
    local classItems = oppClass and trainerItemMap[oppClass]
    local items = classItems and (classItems[partyIndex] or classItems[1])
    if items then
      for idx, mon in ipairs(battle.enemyParty) do
        if items[idx] then
          mon.item = items[idx]
          mon.heldItem = items[idx]
        end
      end
    end
    if battle.enemy and battle.enemy.mon and items and items[1] then
      battle.enemy.mon.item = items[1]
      battle.enemy.mon.heldItem = items[1]
    end
  end)

  -- 3. Triple Kick Scaling (20 -> 60 -> 120)
  mod.hooks:wrap("battle.damage", function(next, ctx)
    if ctx and (ctx.moveId == "TRIPLE_KICK" or (ctx.move and ctx.move.id == "TRIPLE_KICK")) then
      local hit = (ctx.battle and ctx.battle.multiHitCount) or (ctx.hitNum or ctx.hit or 1)
      local basePower = 20
      if hit == 2 then
        basePower = 60
      elseif hit >= 3 then
        basePower = 120
      end
      if ctx.opts then
        ctx.opts.power = basePower
      end
      if ctx.move then
        ctx.move.power = basePower
      end
    end
    return next(ctx)
  end, 50)

  -- 4. Hard / Hardcore Battle Item Ban.  Every engine build's BagMenu routes
  -- bag use through ItemEffects.use (src/inventory/ItemEffects.lua); newer
  -- builds wrap that same dispatch with an "item.use" hook.  Patching the
  -- function itself covers both.  (The historical "battle.item_usable" hook
  -- name is emitted by no engine build, so wrapping it was a silent no-op
  -- and the ban never fired.)
  local okInv, InvItemEffects = pcall(require, "src.inventory.ItemEffects")
  if okInv and type(InvItemEffects) == "table" and type(InvItemEffects.use) == "function" then
    local origUse = InvItemEffects.use
    InvItemEffects.use = function(data, save, itemId, target, battle, moveIndex, ow)
      local mode = getDifficultyMode(mod, save)
      if isHardMode(mode) and battle
          and (battle.trainer ~= nil or battle.isTrainerBattle) then
        -- Refuse like a vanilla failed use ("failed" + a message row): the
        -- bag closes with the ban line and no battle turn is spent.
        return "failed",
          { "Bag items cannot be used in trainer battles during Hard Mode!" }
      end
      return origUse(data, save, itemId, target, battle, moveIndex, ow)
    end
  end

  -- 5. Hard / Hardcore Level Caps: Clamp experience in exp.gain so mon cannot exceed gym level cap
  mod.hooks:wrap("exp.gain", function(next, c)
    local vanillaAmount = next(c)
    local save = (c.battle and c.battle.save)
      or (c.battle and c.battle.game and c.battle.game.save)
      or (rawget(_G, "Game") and Game.save)
    local mode = getDifficultyMode(mod, save)
    if not isHardMode(mode) then
      return vanillaAmount
    end

    local mon = c.mon
    if not mon then return vanillaAmount end

    local cap = getLevelCap(save)

    -- If already at or above cap, award 0 exp
    if (mon.level or 1) >= cap then
      return 0
    end

    -- If gaining vanilla exp would push mon past the level cap, clamp it
    local Mon = require("src.battle.gen2.Mon")
    local data = (c.battle and c.battle.data) or (rawget(_G, "Game") and Game.data)
    local def = data and data.pokemon and data.pokemon[mon.species]
    local growth = Mon.growthFor(data, def and def.growthRate)
    local maxExpForCap = Mon.experienceForLevel(growth, cap)
    local currentExp = mon.experience or Mon.experienceForLevel(growth, mon.level)
    local maxGain = math.max(0, maxExpForCap - currentExp)

    return math.min(vanillaAmount, maxGain)
  end, 100)

  -- 6. In-game Options Menu: allow player to view and toggle difficulty anytime
  mod.hooks:wrap("ui.options.rows", function(next, game, rows)
    local out = next(game, rows)
    if type(out) ~= "table" then return out end

    out[#out + 1] = {
      id = "difficulty",
      label = "DIFFICULTY",
      value = function(g)
        local save = (g and g.save) or (rawget(_G, "Game") and Game.save)
        local mode = getDifficultyMode(mod, save)
        if mode == "hardcore" then return "HARDCORE" end
        if mode == "hard" then return "HARD" end
        return "NORMAL"
      end,
      step = function(g, dir)
        local save = (g and g.save) or (rawget(_G, "Game") and Game.save)
        local mode = getDifficultyMode(mod, save)
        local order = { "normal", "hard", "hardcore" }
        local cur = 1
        for i, m in ipairs(order) do
          if m == mode then cur = i break end
        end
        local nextMode = order[((cur - 1 + (dir or 1)) % #order) + 1]

        mod.difficultyMode = nextMode
        if mod.save then mod.save:set("difficulty", nextMode) end
        if save then
          save.difficulty = nextMode
          if save.options then
            save.options.difficulty = nextMode
            if isHardMode(nextMode) then
              save.options.battleStyle = "SET"
            end
          end
        end
        if g and g.options and isHardMode(nextMode) then
          g.options.battleStyle = "SET"
        end
        if g and g.writeOptions then g:writeOptions() end
        return true
      end,
    }
    return out
  end, 50)

  -- 7. Hardcore Permadeath Tracking
  mod.events:on("battle.fainted", function(payload)
    local battler = payload and payload.battler
    local save = (payload and payload.battle and payload.battle.game and payload.battle.game.save) or (payload and payload.battle and payload.battle.save)
    local mode = getDifficultyMode(mod, save)
    if (mode == "hardcore") and battler and battler.isPlayer and battler.mon then
      battler.mon.dead = true
      battler.mon.permaFainted = true
    end
  end)
end

return {
  applyDifficulty = applyDifficulty,
  BADGE_LEVEL_CAPS = BADGE_LEVEL_CAPS,
  getLevelCap = getLevelCap,
  levelCapFor = getLevelCap,
  isHardMode = isHardMode,
}
