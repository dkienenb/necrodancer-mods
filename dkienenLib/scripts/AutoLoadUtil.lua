local metaUtil = require "dkienenLib.MetaUtil"
local prefixUtil = require "dkienenLib.PrefixUtil"
local characterUtil = require "dkienenLib.CharacterUtil"
local itemUtil = require "dkienenLib.ItemUtil"
local miscUtil = require "dkienenLib.MiscUtil"
local entityUtil = require "dkienenLib.EntityUtil"

function loadMod(modName)
	prefixUtil.setMod(modName)
	local modJSON = metaUtil.getModJSON(modName)
	local settings = modJSON.dkienenLib
	if settings then
		if settings.banSingleZones then
			miscUtil.banSingleZones()
		end
		if settings.requireAmplified then
			miscUtil.requireAmplified()
		end
		if settings.requireAmplified then
			miscUtil.requireSync()
		end
	end
	local characters = metaUtil.allScriptsFromPackage(modName, "characters")
	for charName, characterFile in pairs(characters) do
		local character = characterFile.character
		characterUtil.registerCharacter(modName, charName, character.inventory, character.description, character.cursedSlots, character.displayName, character.powers)
	end
	local items = metaUtil.allScriptsFromPackage(modName, "items")
	for itemName, itemFile in pairs(items) do
		local item = itemFile.item
		itemUtil.registerItem(modName, itemName, item.template, item.properties)
	end
	--local shrines = metaUtil.allScriptsFromPackage(modName, "shrines")
	--for shrineName, shrineFile in pairs(shrines) do
	--	entityUtil.registerShrine()
	--end
end

return {
	loadMod = loadMod
}
