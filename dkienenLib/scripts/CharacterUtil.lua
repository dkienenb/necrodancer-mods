local miscUtil = require "dkienenLib.MiscUtil"
local entityUtil = require "dkienenLib.EntityUtil"
local customEntities = require "necro.game.data.CustomEntities"
local multiCharacter = require "necro.game.data.modifier.MultiCharacter"
local extraMode = require "necro.game.data.modifier.ExtraMode"
local enum = require "system.utils.Enum"
local modChars = {}
local color = require "system.utils.Color"

function registerCharacter(modName, charName, inventory, charSelectText, cursedSlots, overrideCharName)
    local officialName = miscUtil.makeProperIdentifier(charName)
    local prefix = miscUtil.makePrefix(modName)
    if overrideCharName then charName = overrideCharName end
    if not inventory then inventory = {"WeaponDagger", "ShovelBasic", "Bomb"} end
    if not charSelectText then charSelectText = "" end
    charSelectText = charName .. " mode!\n" .. charSelectText
    local components = {
        {
            friendlyName={name=charName},
            initialInventory={
                items=inventory
            },
            playableCharacter={
                lobbyOrder=0
            },
            sprite={
               -- texture="mods/" .. modName .. "/images/chars/" .. officialName .. "Body.png"
                texture="mods/" .. modName .. "/images/chars/" .. "Hunter" .. "Body.png"
            },
            textCharacterSelectionMessage = {
                text = charSelectText
            },
        },
        {
           -- sprite={texture="mods/" .. modName .. "/images/chars/" .. officialName .. "Heads.png"}
            sprite={texture="mods/" .. modName .. "/images/chars/" .. "Hunter" .. "Heads.png"}
        }
    }
    if cursedSlots then
        components[1].inventoryCursedSlots={slots=cursedSlots}
    end
    components[1][prefix .. officialName] = {}
    local template = customEntities.template.player()
    entityUtil.registerEntity(modName, template, components, officialName)
    table.insert(modChars, prefix .. officialName)
end

local mode = multiCharacter.Mode.extend("All Chars Modded", enum.data {
    characters = modChars,
    order = multiCharacter.Order.PLAYER_CHOICE,
})

extraMode.Type.extend("A_LOT_OF_CHARS", enum.data({
    order = -100,
    key = "gameplay.modifiers.multiChar",
    value = mode,
    i18n = "label.lobby.stair.extraMode.allCharsModded",
    displayName = "Absolutely All Characters Mode",
    shrine = {
        texture = "gfx/necro/level/lobby/shrine_absolutely_all_char.png",
        color = color.rgb(240, 240, 240),
        offsetY = -46,
    },
}))

return {
    registerCharacter=registerCharacter
}
