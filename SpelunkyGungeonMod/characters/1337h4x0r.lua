local entityUtil = require "dkienenLib.EntityUtil"
local ecs = require "system.game.Entities"
local player = require "necro.game.character.Player"
local marker = require "necro.game.tile.Marker"
local itemGeneration = require "necro.game.item.ItemGeneration"
local object = require "necro.game.object.Object"
local map = require "necro.game.object.Map"
local move = require "necro.game.system.Move"

local function killAll(hacker)
    for entity in ecs.entitiesWithComponents {"health"} do
        if not (player.isPlayerEntity(entity)) then
            entityUtil.destroy(entity, "]", hacker)
        end
    end
end

local function spawnImportantShopItems()
    local items = {}
    for _, itemName in ipairs(ecs.getEntityTypesWithComponents({"itemPoolShop"})) do
        local item = ecs.getEntityPrototype(itemName)
        if item.itemPoolShop.weights and item.itemPoolShop.weights[2] and item.itemPoolShop.weights[2] > 3000 then
            table.insert(items, itemName)
            itemGeneration.markSeen(itemName, 1)
        end
    end
    local shopX, shopY = marker.lookUpMedian(marker.Type.SHOP)
    if shopX and shopY then
        object.spawn("ChestRed", shopX, shopY, {
            storage = { items = items },
        })
    end
end

local function collectItems()
    local shopX, shopY = marker.lookUpMedian(marker.Type.SHOP)
    local exitX, exitY = marker.lookUpMedian(marker.Type.STAIRS)
    if shopX and shopY then
        for _, entity in map.entitiesWithComponent (exitX, exitY, "item") do
            local xOffset = 0
            local yOffset = 0
            if entity.itemCurrency then yOffset = 1 end
            move.absolute(entity, shopX + xOffset, shopY + yOffset, move.Type.NONE)
        end
    end
end

return {
    character={
        displayName="]",
        description="",
        powers={
            {
                order="processPendingObjects",
                sequence=-2,
                action=killAll
            },
            {
                order="processPendingObjects",
                sequence=-1,
                action=collectItems
            },
            {
                order="initialItems",
                depth=1,
                floor=2,
                action=spawnImportantShopItems
            }
        }
    }
}