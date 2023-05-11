local prefix = require "dkienenLib.PrefixUtil".prefix()

return {
    item = {
        properties = {
            Hint = {
                hint = "Target down!"
            },
            Slot = {
                slot = "misc"
            },
            FloorDrop = {
                requiredPlayerComponent = prefix .. "Hunter"
            },
            Stack = {},
            Breakable = {
                sound = "drinkPotion",
                depth = {},
                requiredComponent = prefix .. "Hunter"
            }
        }
    }
}