-- Difficulty and battle mechanics for Crystal Legacy parity:
-- 1. Interactive Oak intro difficulty selection with live descriptions on hover & confirmation prompt.
-- 2. Trainer held items from data/trainers.lua attached to enemy party in battle.
-- 3. Triple Kick 20 -> 60 -> 120 power progression.
-- 4. Hard / Hardcore difficulty modes (item ban, set mode, level caps, permadeath).

local BADGE_LEVEL_CAPS = {
  [0] = 12,  -- Falkner
  [1] = 16,  -- Bugsy
  [2] = 20,  -- Whitney
  [3] = 25,  -- Morty
  [4] = 30,  -- Chuck
  [5] = 35,  -- Jasmine & Pryce
  [6] = 35,
  [7] = 40,  -- Clair
  [8] = 50,  -- Elite Four
  [9] = 55,  -- Kanto Early
  [10] = 60,
  [11] = 65,
  [12] = 70,
  [13] = 75,
  [14] = 80,
  [15] = 85,
  [16] = 93, -- Red
}

local JOHTO_BADGE_NAMES = { "ZEPHYR", "HIVE", "PLAIN", "FOG", "MINERAL", "STORM", "GLACIER", "RISING" }
local KANTO_BADGE_NAMES = { "BOULDER", "CASCADE", "THUNDER", "RAINBOW", "SOUL", "MARSH", "VOLCANO", "EARTH" }

local function countPlayerBadges(save)
  if not save then return 0 end
  local count = 0
  local player = save.player or {}
  local johto = player.badges or player.johtoBadges or {}
  local kanto = player.kantoBadges or {}
  local engineFlags = save.engineFlags or {}

  -- 1. Check Johto badges by name, index, or engine flag (26..33)
  for idx, name in ipairs(JOHTO_BADGE_NAMES) do
    local flagId = 25 + idx
    if johto[name] == true or johto[idx] == true or engineFlags[flagId] == true or engineFlags["ENGINE_" .. name .. "BADGE"] == true then
      count = count + 1
    end
  end

  -- 2. Check Kanto badges by name, index, or engine flag (34..41)
  for idx, name in ipairs(KANTO_BADGE_NAMES) do
    local flagId = 33 + idx
    if kanto[name] == true or kanto[idx] == true or engineFlags[flagId] == true or engineFlags["ENGINE_" .. name .. "BADGE"] == true then
      count = count + 1
    end
  end

  -- Fallback for direct badge count
  if count == 0 and type(save.badges) == "number" then
    count = save.badges
  end

  return count
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

local function levelCapFor(save)
  local badges = countPlayerBadges(save)
  return BADGE_LEVEL_CAPS[badges] or (badges >= 16 and 100 or 12)
end

local function installRareCandyCap(mod)
  local vanilla = mod.content.item_effects:get("RARE_CANDY")
  if not vanilla or not vanilla.use then return end

  mod.content.item_effects:patch("RARE_CANDY", {
    use = function(ctx)
      local game = mod.game
      local save = (game and game.save)
        or (rawget(_G, "Game") and Game.save)
      local mode = getDifficultyMode(mod, save)
      if isHardMode(mode) and ctx.mon
          and (ctx.mon.level or 1) >= levelCapFor(save) then
        local ItemEffects = require("src.core.gen2.ItemEffects")
        return { used = false, text = ItemEffects.TEXT_NO_EFFECT }
      end
      return vanilla.use(ctx)
    end,
  })
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

  -- 4. Hard / Hardcore Battle Item Ban
  mod.hooks:wrap("battle.item_usable", function(next, ctx)
    local save = (ctx and ctx.game and ctx.game.save) or (ctx and ctx.battle and ctx.battle.save)
    local mode = getDifficultyMode(mod, save)
    if isHardMode(mode) then
      if ctx and ctx.battle and (ctx.battle.trainer ~= nil or ctx.battle.isTrainerBattle) then
        return false, "Bag items cannot be used in trainer battles during Hard Mode!"
      end
    end
    return next(ctx)
  end, 50)

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

    local cap = levelCapFor(save)

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
}
