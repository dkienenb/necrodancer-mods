local miscUtil = require "dkienenLib.MiscUtil"
local entityUtil = require "dkienenLib.EntityUtil"
local eventUtil = require "dkienenLib.EventUtil"
local customEntities = require "necro.game.data.CustomEntities"
local multiCharacter = require "necro.game.data.modifier.MultiCharacter"
local extraMode = require "necro.game.data.modifier.ExtraMode"
local enum = require "system.utils.Enum"
local modChars = {}
local color = require "system.utils.Color"
local utils = require "system.utils.Utilities"

function registerCharacter(modName, charName, inventory, charSelectText, cursedSlots, overrideCharName, levelEvents)
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
               texture="mods/" .. modName .. "/images/characters/" .. officialName .. "Body.png"
            },
            textCharacterSelectionMessage = {
                text = charSelectText
            },
        },
        {
           sprite={texture="mods/" .. modName .. "/images/characters/" .. officialName .. "Heads.png"}
        }
    }
    if cursedSlots then
        components[1].inventoryCursedSlots={slots=cursedSlots}
    end
    components[1][prefix .. officialName] = {}
    local template = customEntities.template.player()
    entityUtil.registerEntity(modName, template, components, officialName)
    utils.removeIf(modChars, function(name) return name == prefix .. officialName end)
    table.insert(modChars,prefix .. officialName)
    if levelEvents then
        local filter = {}
        table.insert(filter, prefix .. officialName)
        for index, levelEvent in ipairs(levelEvents) do
            local predicate = levelEvent.predicate
            if not predicate and levelEvent.notBoss then
                predicate = function(_, floor)
                    return floor < 4
                end
            end
            if not predicate and levelEvent.notFirstLevel then
                predicate = function (depth, floor)
                    return (depth ~= 1) or (floor ~= 1)
                end
            end
            if not predicate and (levelEvent.depth or levelEvent.floor) then
                predicate = eventUtil.makeDepthPredicate(levelEvent.depth, levelEvent.floor)
            end
            if not predicate then
                predicate = function() return true end
            end
            eventUtil.addDepthLevelEvent(modName, officialName .. "Power" .. index, levelEvent.order or "spawnPlayers", levelEvent.sequence, filter, predicate, levelEvent.action)
        end
    end
end

utils.concatArrays(modChars, {"Cadence", "Melody", "Aria", "Dorian", "Eli", "Monk", "Dove", "Bolt", "Bard", "Reaper", "Nocturna", "Diamond", "Mary", "Tempo", "Sync_Klarinetta", "Sync_Chaunter", "Sync_Suzu"})
utils.removeDuplicates(modChars)
local mode = multiCharacter.Mode.extend("All Chars Modded", enum.data {
    characters = modChars,
    order = multiCharacter.Order.PLAYER_CHOICE,
})

local mode_ensemble = multiCharacter.Mode.extend("Modded Ensemble", enum.data {
    characters = modChars,
    storyBossCharacters = {},
    defaultCharacter = "Cadence",
    ensemble = true,
    columns = 7
})

extraMode.Type.extend("A_LOT_OF_CHARS", enum.data({
    order = -143,
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

extraMode.Type.extend("MODDED_ENSEMBLE", enum.data({
    order = -144,
    key = "gameplay.modifiers.multiChar",
    value = mode_ensemble,
    displayName = "Modded Ensemble Mode",
    shrine = {
        texture = "gfx/necro/level/lobby/shrine_ensemble.png",
        color = color.rgb(240, 240, 240)
    },
}))

return {
    registerCharacter=registerCharacter
}
