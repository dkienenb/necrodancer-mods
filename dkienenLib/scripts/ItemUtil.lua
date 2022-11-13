local metaUtil = require "dkienenLib.MetaUtil"
local miscUtil = require "dkienenLib.MiscUtil"
local entityUtil = require "dkienenLib.EntityUtil"
local customEntities = require "necro.game.data.CustomEntities"

function registerItem(modName, name, templateItem, hint, slot, args)
	local officialName = miscUtil.makeProperIdentifier(name)
	local itemProperties = metaUtil.allScriptsFromPackage("dkienenLib", "itemProperties")
	local components = {
		friendlyName = {name=name},
		sprite = {texture = "mods/" .. modName .. "/images/items/" .. officialName .. ".png"}
	}	
	for propertyName, propertyArgs in pairs(args) do
		itemProperties[propertyName].apply(components, propertyArgs, name, modName)
	end
	local data = {
		hint=hint,
		slot=slot
	}
	entityUtil.registerEntity(modName, customEntities.template.item(templateItem), components, officialName, data)
end

registerItem("dkienenLib", "Test item", nil, "Yargs", "misc", {Failsafe={drop={depth=2, floor=2, components={"enemyPoolMiniboss"}}}, Unban=true, BloodRegen={}, Breakable={purchase=true, depth={depth=2, floor=3}}})

return {
	registerItem=registerItem
}