local metaUtil = require "dkienenLib.MetaUtil"
local miscUtil = require "dkienenLib.MiscUtil"
local entityUtil = require "dkienenLib.EntityUtil"
local customEntities = require "necro.game.data.CustomEntities"

function registerItem(modName, name, templateItem, args)
	local officialName = miscUtil.makeProperIdentifier(name)
	local itemProperties = metaUtil.allScriptsFromPackage("dkienenLib", "itemProperties")
	local components = {
		friendlyName = {name=name},
		sprite = {texture = "mods/" .. modName .. "/images/items/" .. officialName .. ".png"},
	}
	for propertyName, propertyArgs in pairs(args) do
		itemProperties[propertyName].apply(components, propertyArgs, name, modName)
	end
	entityUtil.registerEntity(modName, customEntities.template.item(templateItem), components, officialName, {})
end

registerItem("dkienenLib", "Test item", nil, {Slot={slot="action"},Spell={spell="SpellcastCrownOfTeleportation", cooldown=30}})

return {
	registerItem=registerItem
}