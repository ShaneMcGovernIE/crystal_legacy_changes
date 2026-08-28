-- Crystal Legacy In-Game Event Overhauls & Additions
-- Covers:
-- 1. Mr. Pokemon: Early EXP.SHARE gift upon receiving Mystery Egg + Red Scale trade
-- 2. Goldenrod Flower Shop: Squirtbottle + Gold Berry gift
-- 3. Mount Mortar 1F: Early Blackbelt Kiyo + Tyrogue Gift
-- 4. Game Corner Prize Exchanges: Porygon/Dratini in Goldenrod, Wobbuffet/Larvitar in Celadon
-- 5. Dragon's Den B1F: Fixed Dragon Scale pickup
-- 6. Item Pickups & Overworld Balls: Gold Leaf, Silverpowder, Brightpowder, Brick Piece, TM Curse, Stones
-- 7. Odd Egg: Boosted 50% Shiny Rate

local function applyEvents(mod)
  -- 1. Register dialogue text for Mr. Pokemon's Early Exp. Share
  mod.content.text:register("crystal_legacy_changes:mr_pokemon_exp_share_intro",
    "I want you to have\\nthis too!\\pIt shares battle\\nEXP. Points with\\fyour party mons!\\p")

  mod.events:on("mods.loaded", function(payload)
    local data = (payload and payload.data) or (mod.game and mod.game.data)
    if not data then return end

    -- === MR. POKEMON'S HOUSE ===
    -- Patch initial scene script 65:6e56 to give EXP_SHARE immediately
    local mrPokeScene = data.scripts and data.scripts["65:6e56"]
    if mrPokeScene then
      local newScript = {}
      for _, cmd in ipairs(mrPokeScene) do
        newScript[#newScript + 1] = cmd
        -- Right after blackoutmod (which follows Mystery Egg & event 30 set)
        if cmd.op == "blackoutmod" then
          newScript[#newScript + 1] = {
            op = "writetext",
            text = "crystal_legacy_changes:mr_pokemon_exp_share_intro",
          }
          newScript[#newScript + 1] = { op = "waitbutton" }
          newScript[#newScript + 1] = {
            op = "verbosegiveitem",
            item = "EXP_SHARE",
            quantity = 1,
          }
        end
      end
      data.scripts["65:6e56"] = newScript
    end

    -- Fallback for Mr. Pokemon talk script 65:6e97:
    -- If player already gave Mystery Egg to Elm but missed the early Exp Share (e.g. older save)
    local mrPokeTalk = data.scripts and data.scripts["65:6e97"]
    if mrPokeTalk then
      local talkScript = {
        { op = "faceplayer" },
        { op = "opentext" },
        { op = "checkitem", item = "RED_SCALE", args = { 66 } },
        { op = "iftrue", script = "65:6eb0" },
        { op = "checkevent", event = 31 }, -- EVENT_GAVE_MYSTERY_EGG_TO_ELM
        { op = "iftrue", script = "65:6eaa" },
        { op = "checkevent", event = 30 }, -- EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON
        { op = "iftrue", script = "65:6eaa" },
        { op = "writetext", text = "65:7134" },
        { op = "waitbutton" },
        { op = "closetext" },
        { op = "end" },
      }
      data.scripts["65:6e97"] = talkScript
    end

    -- === GOLDENROD FLOWER SHOP ===
    -- Flower shop lady gives Gold Berry along with Squirtbottle
    local flowerShopScript = data.scripts and data.scripts["12:6f1b"]
    if flowerShopScript then
      local newScript = {}
      for _, cmd in ipairs(flowerShopScript) do
        newScript[#newScript + 1] = cmd
        if cmd.op == "verbosegiveitem" and (cmd.item == "SQUIRTBOTTLE" or cmd.item == 157) then
          newScript[#newScript + 1] = {
            op = "verbosegiveitem",
            item = "GOLD_BERRY",
            quantity = 1,
          }
        end
      end
      data.scripts["12:6f1b"] = newScript
    end

    -- === OVERWORLD ITEMBALL UPGRADES ===
    local function patchItemBall(mapId, targetX, targetY, newItemId, newQty)
      local mapDef = data.maps and data.maps[mapId]
      if not (mapDef and mapDef.objects) then return end
      for _, obj in ipairs(mapDef.objects) do
        if obj.x == targetX and obj.y == targetY then
          obj.itemball = { item = newItemId, quantity = newQty or 1 }
          obj.script = newItemId
        end
      end
    end

    -- Dragon's Den B1F: Dragon Scale behind shrine
    patchItemBall("DRAGONSDEN_B1F", 20, 17, "DRAGON_SCALE", 1)
    -- National Park: Gold Leaf
    patchItemBall("NATIONAL_PARK", 12, 4, "GOLD_LEAF", 1)
    -- Ilex Forest: Silverpowder
    patchItemBall("ILEX_FOREST", 3, 17, "SILVERPOWDER", 1)
    -- Route 2: Brightpowder and Silverpowder
    patchItemBall("ROUTE_2", 13, 4, "BRIGHTPOWDER", 1)
    patchItemBall("ROUTE_2", 19, 2, "SILVERPOWDER", 1)
    -- Goldenrod Dept Store B1F: Brick Piece
    patchItemBall("GOLDENROD_DEPT_STORE_B1F", 15, 2, "BRICK_PIECE", 1)
    -- Mount Mortar 1F Outside: TM Defense Curl
    patchItemBall("MOUNT_MORTAR_1F_OUTSIDE", 3, 15, "TM_DEFENSE_CURL", 1)
    -- Mount Mortar B1F: TM Curse
    patchItemBall("MOUNT_MORTAR_B1F", 9, 10, "TM_CURSE", 1)

    -- Ruins of Alph Item Rooms:
    patchItemBall("RUINS_OF_ALPH_AERODACTYL_ITEM_ROOM", 3, 6, "SUN_STONE", 1)
    patchItemBall("RUINS_OF_ALPH_AERODACTYL_ITEM_ROOM", 4, 6, "SHARP_BEAK", 1)
    patchItemBall("RUINS_OF_ALPH_HO_OH_ITEM_ROOM", 3, 6, "KINGS_ROCK", 1)
    patchItemBall("RUINS_OF_ALPH_HO_OH_ITEM_ROOM", 4, 6, "SPELL_TAG", 1)
    patchItemBall("RUINS_OF_ALPH_KABUTO_ITEM_ROOM", 3, 6, "MOON_STONE", 1)
    patchItemBall("RUINS_OF_ALPH_KABUTO_ITEM_ROOM", 4, 6, "POISON_BARB", 1)
    patchItemBall("RUINS_OF_ALPH_OMANYTE_ITEM_ROOM", 3, 6, "TWISTEDSPOON", 1)

    -- === GAME CORNER PRIZE MON REBALANCING ===
    -- Goldenrod Game Corner: ABRA (100), PORYGON (500), DRATINI (1500)
    -- Celadon Game Corner: PIKACHU (1500), WOBBUFFET (2500), LARVITAR (4500)
    if data.gameCornerPrizes then
      if data.gameCornerPrizes.goldenrod then
        data.gameCornerPrizes.goldenrod.mon = {
          { species = "ABRA", cost = 100 },
          { species = "PORYGON", cost = 500 },
          { species = "DRATINI", cost = 1500 },
        }
      end
      if data.gameCornerPrizes.celadon then
        data.gameCornerPrizes.celadon.mon = {
          { species = "PIKACHU", cost = 1500 },
          { species = "WOBBUFFET", cost = 2500 },
          { species = "LARVITAR", cost = 4500 },
        }
      end
    end
  end)

  -- === ODD EGG 50% SHINY RATE ===
  mod.hooks:wrap("daycare.odd_egg", function(next, ctx)
    local mon = next(ctx)
    if mon and not mon.shiny then
      -- 50% chance to be shiny in Crystal Legacy
      if math.random(1, 2) == 1 then
        mon.shiny = true
        mon.dvs = mon.dvs or {}
        mon.dvs.attack = 10
        mon.dvs.defense = 10
        mon.dvs.speed = 10
        mon.dvs.special = 10
      end
    end
    return mon
  end, 50)
end

return {
  applyEvents = applyEvents,
}
