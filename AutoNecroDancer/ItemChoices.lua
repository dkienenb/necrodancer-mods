local Entities = require "system.game.Entities"
local Map = require "necro.game.object.Map"
local Utilities = require "system.utils.Utilities"

local VALUES = {
	weapon={
		WeaponDagger=-1
	},
	shovel = {
		ShovelBasic=-2,
		ShovelBlood=-1,
	},
	torch = {
		Torch1=-2,
		Torch2=-1,
	},
	body = {
		ArmorLeather=-3,
		ArmorQuartz=-2,
		ArmorChainmail=-2,
		ArmorPlatemail=-1,
	},
	shield = {
		Sync_ShieldWooden=-3,
		Sync_ShieldTitanium=-2,
		Sync_ShieldObsidian=-1,
		Sync_ShieldStrength=1,
	}
}

local function canPurchase(item, player)
	local tagID = item.sale and item.sale.priceTag
	local tag = Entities.getEntityByID(tagID)
	local cost = tag and tag.priceTagCostCurrency and tag.priceTagCostCurrency.cost or 0
	local gold = player.goldCounter.amount
	return gold >= cost
end

local function getNumericalValue(item, slotName)
	local value = 0
	local slotValues = VALUES[slotName]
	if slotValues then
		local itemValue = slotValues[item.name]
		if itemValue then
			value = itemValue
		end
	end
	if slotName == "weapon" then
		local pattern = item.weaponPattern
		if pattern then
			local tiles = pattern.pattern.tiles
			for _, tile in ipairs(tiles) do
				if tile.targetFlags > 0 and not tile.dashMoveType then
					value = value - 5
				end
			end
		end
	end
	return value
end

local function secondOneIsBetter(item1, item2, item1SlotName)
	if item1SlotName == "bomb" or item1SlotName == "misc" then
		return true
	end
	local item1Value = getNumericalValue(item1, item1SlotName)
	local item2Value = getNumericalValue(item2, item1SlotName)
	local better = item2Value > item1Value
	return better
end

local function shouldTake(newItem, player)
	local slot = newItem.itemSlot
	local conflicts = {}
	local slotName
	if slot then
		slotName = slot.name
		local conflictIDs = player.inventory.itemSlots[slotName]
		if conflictIDs then
			for _, conflictID in ipairs(conflictIDs) do
				table.insert(conflicts, Entities.getEntityByID(conflictID))
			end
		end
	end
	Utilities.removeIf(conflicts, function(conflict)
		return secondOneIsBetter(conflict, newItem, slotName)
	end)
	local notHeld = newItem.item.holder == 0
	local notGold = not newItem.itemCurrency
	local noConflicts = #conflicts == 0
	return notHeld and notGold and noConflicts and canPurchase(newItem, player)
end

local function getTargetItems(x, y, player)
	local items = {}
	for _, item in Map.entitiesWithComponent(x, y, "item") do
		if shouldTake(item, player) then
			table.insert(items, item)
		end
	end
	return items
end

return {
	getTargetItems=getTargetItems,
	shouldTake=shouldTake,
	canPurchase=canPurchase
}