local itemUtil = require "dkienenLib.ItemUtil"
local inventory = require "necro.game.item.Inventory"
local object = require "necro.game.object.Object"

local function replace_items(paradox)
    for _, item in ipairs(inventory.getItems(paradox)) do
        if item.itemSlot then
            local choice = itemUtil.randomItem(item.itemSlot.name)
            object.kill(item);
            inventory.grant(choice, paradox, true)
        end
    end
end

return {
    character={
        displayName="Double Paradox",
        inventory={"WeaponDagger", "ShovelBasic", "Bomb"},
        description="Randomize your loadout every zone!",
        powers={
            {
                floor=1,
                order = "initialItems",
                action=replace_items
            }
        }
    }
}