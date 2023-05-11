local metaUtil = require "dkienenLib.MetaUtil"
local miscUtil = require "dkienenLib.MiscUtil"
local entityUtil = require "dkienenLib.EntityUtil"
local customEntities = require "necro.game.data.CustomEntities"
local rng = require "necro.game.system.RNG"

local prefix = "dkienenLib_"

local itemsBySlot = {}

local RNG_ITEMS = rng.Channel.extend(prefix .. "Item_Choice")

event.entitySchemaLoadNamedEntity.add("registerItems", {order = "finalize"}, function (ev)
	local entity = ev.entity
	if entity and entity.item then
		if entity.itemSlot then
			if not itemsBySlot[entity.itemSlot.name] then
				itemsBySlot[entity.itemSlot.name] = {}
			end
			table.insert(itemsBySlot[entity.itemSlot.name], entity.name)
		end
	end
end)

function registerItem(modName, name, templateItem, args)
	local officialName = miscUtil.makeProperIdentifier(name)
	local itemProperties = metaUtil.allScriptsFromPackage("dkienenLib", "itemProperties")
	local components = {
		friendlyName = {name=name},
		sprite = {texture = "mods/" .. modName .. "/images/items/" .. officialName .. ".png"},
	}
	for propertyName, propertyArgs in pairs(args) do
		itemProperties[propertyName].apply(components, propertyArgs, name, modName, officialName)
	end
	entityUtil.registerEntity(modName, customEntities.template.item(templateItem), components, officialName, {})
end

function randomItem(slot, exclude)
	if slot then
		local choice = rng.choice(itemsBySlot[slot], RNG_ITEMS)
		return choice
	end
	if exclude then
		local choices = {}
		for slotName, itemList in pairs(itemsBySlot) do
			if not exclude[slotName] then
				for _, item in ipairs(itemList) do
					table.insert(choices, item)
				end
			end
		end
		local choice = rng.choice(choices, RNG_ITEMS)
		return choice
	end
end

registerItem("dkienenLib", "Test item", nil, {Slot={slot="action"},Spell={spell="SpellcastCrownOfTeleportation", cooldown=30}})

return {
	registerItem=registerItem,
	randomItem=randomItem
}