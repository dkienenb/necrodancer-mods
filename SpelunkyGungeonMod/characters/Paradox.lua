local itemUtil = require "dkienenLib.ItemUtil"
local inventory = require "necro.game.item.Inventory"

local function spawn_items(paradox)
    local item = itemUtil.randomItem(nil, {shovel = true, weapon = true})
    local weapon = itemUtil.randomItem("weapon")
    local shovel = itemUtil.randomItem("shovel")
    inventory.grant(item, paradox, true)
    inventory.grant(weapon, paradox, true)
    inventory.grant(shovel, paradox, true)
end

return {
    character={
        inventory={"Bomb"},
        description="Start with random items!",
        powers={
            {
                depth=1,
                floor=1,
                order = "initialItems",
                action=spawn_items
            }
        }
    }
}