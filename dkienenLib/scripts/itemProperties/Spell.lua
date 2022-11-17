local cast = require "dkienenLib.itemProperties.Cast"

function apply(itemComponents, args)
    local spell = args.spell
    local spellType = args.spellType -- "greater"
    local cooldown = args.cooldown
    local bloodMagicCost = args.bloodMagicCost
    if cooldown then
        itemComponents.spellCooldownKills = {cooldown = cooldown}
        itemComponents.itemHUDCooldown = {}
    end
    if bloodMagicCost then
        itemComponents.spellBloodMagic = {damage = bloodMagicCost}
    end
    if spellType then
        itemComponents.spellUpgrade = {upgradeType = spellType}
    end
    itemComponents.spellReusable = {}
    itemComponents.activeItemConsumable = false
    cast.apply(itemComponents, {spell=spell})
end

return {
    apply=apply
}
