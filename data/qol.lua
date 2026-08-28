-- Quality of Life (QoL) features for Crystal Legacy parity:
-- 1. TM & HM move names in item registry so move names show clearly in the bag.
-- 2. Deletable HM moves (Move Deleter allows removing HMs without restriction).
-- 3. Halved egg hatch step count (Double progress per step).

local TM_ITEM_IDS = {
  TM_DYNAMICPUNCH = "TM01 DYNAMICPUNCH",
  TM_HEADBUTT = "TM02 HEADBUTT",
  TM_CURSE = "TM03 CURSE",
  TM_ROLLOUT = "TM04 ROLLOUT",
  TM_ROAR = "TM05 ROAR",
  TM_TOXIC = "TM06 TOXIC",
  TM_ZAP_CANNON = "TM07 ZAP CANNON",
  TM_ROCK_SMASH = "TM08 ROCK SMASH",
  TM_PSYCH_UP = "TM09 PSYCH UP",
  TM_HIDDEN_POWER = "TM10 HIDDEN POWER",
  TM_SUNNY_DAY = "TM11 SUNNY DAY",
  TM_SWEET_SCENT = "TM12 SWEET SCENT",
  TM_SNORE = "TM13 SNORE",
  TM_BLIZZARD = "TM14 BLIZZARD",
  TM_HYPER_BEAM = "TM15 HYPER BEAM",
  TM_ICY_WIND = "TM16 ICY WIND",
  TM_PROTECT = "TM17 PROTECT",
  TM_RAIN_DANCE = "TM18 RAIN DANCE",
  TM_GIGA_DRAIN = "TM19 GIGA DRAIN",
  TM_ENDURE = "TM20 ENDURE",
  TM_FRUSTRATION = "TM21 FRUSTRATION",
  TM_SOLARBEAM = "TM22 SOLARBEAM",
  TM_IRON_TAIL = "TM23 IRON TAIL",
  TM_DRAGONBREATH = "TM24 DRAGONBREATH",
  TM_THUNDER = "TM25 THUNDER",
  TM_EARTHQUAKE = "TM26 EARTHQUAKE",
  TM_RETURN = "TM27 RETURN",
  TM_DIG = "TM28 DIG",
  TM_PSYCHIC = "TM29 PSYCHIC",
  TM_SHADOW_BALL = "TM30 SHADOW BALL",
  TM_MUD_SLAP = "TM31 MUD-SLAP",
  TM_DOUBLE_TEAM = "TM32 DOUBLE TEAM",
  TM_ICE_PUNCH = "TM33 ICE PUNCH",
  TM_SWAGGER = "TM34 SWAGGER",
  TM_SLEEP_TALK = "TM35 SLEEP TALK",
  TM_SLUDGE_BOMB = "TM36 SLUDGE BOMB",
  TM_SANDSTORM = "TM37 SANDSTORM",
  TM_FIRE_BLAST = "TM38 FIRE BLAST",
  TM_SWIFT = "TM39 SWIFT",
  TM_DEFENSE_CURL = "TM40 DEFENSE CURL",
  TM_THUNDERPUNCH = "TM41 THUNDERPUNCH",
  TM_DREAM_EATER = "TM42 DREAM EATER",
  TM_DETECT = "TM43 DETECT",
  TM_REST = "TM44 REST",
  TM_ATTRACT = "TM45 ATTRACT",
  TM_THIEF = "TM46 THIEF",
  TM_STEEL_WING = "TM47 STEEL WING",
  TM_FIRE_PUNCH = "TM48 FIRE PUNCH",
  TM_FURY_CUTTER = "TM49 FURY CUTTER",
  TM_NIGHTMARE = "TM50 NIGHTMARE",
  HM_CUT = "HM01 CUT",
  HM_FLY = "HM02 FLY",
  HM_SURF = "HM03 SURF",
  HM_STRENGTH = "HM04 STRENGTH",
  HM_FLASH = "HM05 FLASH",
  HM_WHIRLPOOL = "HM06 WHIRLPOOL",
  HM_WATERFALL = "HM07 WATERFALL",
}

local function applyQoL(mod)
  -- 1. Patch static TM & HM item names
  for id, name in pairs(TM_ITEM_IDS) do
    mod.content.items:patch(id, { name = name })
  end

  -- 2. Deletable HM Moves: Move Deleter can remove HM moves
  mod.hooks:wrap("move_deleter.can_delete", function(next, moveId)
    return true
  end, 50)

  -- 3. Halved Egg Hatch Step Count (Double progress per step)
  mod.hooks:wrap("egg.step_cycle", function(next, currentSteps)
    local steps = next(currentSteps) or currentSteps
    return steps * 2
  end, 50)

  -- 4. B-Button Running (Hold B to run at 2x walking speed)
  mod.hooks:wrap("movement.speed", function(next, frames, ctx)
    local current = next(frames, ctx) or frames
    if not (ctx and ctx.onBike) and not (ctx and ctx.surfing) then
      local input = ctx and ctx.input
      local isBHeld = input and input.isDown and input:isDown("b")
      if not isBHeld and love and love.keyboard and love.keyboard.isDown then
        local ok, down = pcall(love.keyboard.isDown, "x", "k", "lshift", "rshift")
        if ok and down then isBHeld = true end
      end
      if isBHeld then
        return math.max(1, math.floor(current / 2))
      end
    end
    return current
  end, 50)

  -- 5. Dynamic TM / HM name formatting on mods.loaded
  mod.events:on("mods.loaded", function(payload)
    local target = payload and payload.data
    if not target or not target.items then return end
    for id, def in pairs(target.items) do
      if type(def) == "table" and def.teaches then
        local moveName = (target.moves and target.moves[def.teaches] and target.moves[def.teaches].name) or def.teaches
        if def.tmLabel and moveName then
          def.name = def.tmLabel .. " " .. moveName
        end
      end
    end
  end)
end

return {
  applyQoL = applyQoL,
  TM_ITEM_IDS = TM_ITEM_IDS,
}
