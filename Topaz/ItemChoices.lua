local Entities = require "system.game.Entities"
local Map = require "necro.game.object.Map"
local Utilities = require "system.utils.Utilities"

local ACTION_ITEMS = {
	panic = {
		Food1=true,
		Food2=true,
		Food3=true,
		Food4=true,
		FoodCarrot=true,
		FoodCookies=true,
		HolyWater=true,
		ScrollFreezeEnemies=true,
		ScrollShield=true,
		Sync_ScrollBerzerk=true,
		TomeFreeze=true,
		TomeShield=true,
		TomeEarth=true,
	},
	useAtOnce = {
		FamiliarRat=true,
		FamiliarShopkeeper=true,
		FamiliarIceSpirit=true,
		FoodMagic1=true,
		FoodMagic2=true,
		FoodMagic3=true,
		FoodMagic4=true,
		FoodMagicCarrot=true,
		FoodMagicCookies=true,
		--ScrollEarthquake=true,
		ScrollEnchantWeapon=true,
		ScrollFear=true,
		ScrollGigantism=true,
		-- TODO avoid need glass
		ScrollNeed=true,
		ScrollRiches=true,
	},
	crateOpener = {
		BombGrenade=true,
		BombGrenade3=true,
		ScrollFireball=true,
		ScrollPulse=true,
		ThrowingStars=true,
		TomeFireball=true,
		TomePulse=true,
	},
	health = {
		Food1=true,
		Food2=true,
		Food3=true,
		Food4=true,
		FoodCarrot=true,
		FoodCookies=true,
		FoodMagic1=true,
		FoodMagic2=true,
		FoodMagic3=true,
		FoodMagic4=true,
		FoodMagicCarrot=true,
		FoodMagicCookies=true,
	}
}

local VALUES = {
	weapon = {
		WeaponDagger=-1,
		WeaponDaggerFrost=1,
		WeaponDaggerElectric=2,
	},
	head = {
		HeadglassJaw=-1,
		HeadCrownOfThorns=1,
		HeadBlastHelm=3,
	},
	shovel = {
		ShovelCourage=-4,
		ShovelBasic=-3,
		ShovelBlood=-2,
		ShovelTitanium=-1,
		ShovelBattle=1,
		ShovelStrength=2,
	},
	torch = {
		Torch1=-3,
		-- TODO -3 with map
		TorchForesight=-2.5,
		TorchGlass=-2.3,
		Torch2=-2,
		Torch3=-1,
		TorchObsidian=0,
		TorchInfernal=1,
		-- TODO -3 with map
		TorchWalls=2,
		TorchStrength=3,
	},
	body = {
		ArmorLeather=-4,
		ArmorGi=-3,
		ArmorQuartz=-2,
		ArmorChainmail=-2,
		ArmorPlatemail=-1,
		ArmorHeavyplate=99,
	},
	ring = {
		RingBecoming=0.1,
		RingShadows=0.2,

		RingPiercing=1.1,
		RingPain=1.2,

		RingGold=2.1,
		RingCharisma=2.2,
		RingLuck=2.3,
		RingShielding=2.4,
		-- TODO Becoming before transmog 2.5
		RingMana=2.6,

		RingProtection=3.1,
		RingMight=3.2,

		RingWar=4.1,
		-- TODO Shadows with map 4.2
		-- TODO Mana with one spell 4.3
		-- TODO Become with quartz before transmog 4.4

		RingPeace=5.1,
		RingRegeneration=5.2,
		RingFrost=5.3,
		-- Mana with two spells 5.4
		RingWonder=5.5
		-- Mana with heal 5.6
	},
	shield = {
		Sync_ShieldWooden=-3,
		Sync_ShieldTitanium=-2,
		Sync_ShieldObsidian=-1,
		Sync_ShieldStrength=1,
	},
	feet = {
		FeetBootsGlass=1,
		FeetBootsExplorers=1,
		FeetBootsWinged=2,
		FeetBootsLead=3,
	},
}

local function canPurchase(item, player)
	if player.shoplifter then return true end
	local tagID = item.sale and item.sale.priceTag
	local tag = Entities.getEntityByID(tagID)
	local cost = tag and tag.priceTagCostCurrency and tag.priceTagCostCurrency.cost or 0
	local gold = player.goldCounter.amount
	return gold >= cost
end

local function isPanicItem(item)
	return ACTION_ITEMS.panic[item.name]
end

local function isUseAtOnceItem(item, player)
	if player.health and player.health.health < player.health.maxHealth and ACTION_ITEMS.health[item.name] then
		return true
	end
	return ACTION_ITEMS.useAtOnce[item.name]
end

local function getNumericalValue(item, slotName, player)
	local value = 0
	local slotValues = VALUES[slotName]
	if slotValues then
		local itemValue = slotValues[item.name]
		if itemValue then
			value = itemValue
		end
	elseif slotName == "action" then
		local name = item.name
		if isUseAtOnceItem(item, player) then
			value = 3
		end
		if isPanicItem(item, player) then
			value = 2
		end
		if ACTION_ITEMS.crateOpener[name] then
			value = 1
		end
	end
	if slotName == "weapon" then
		-- TODO value dmg
		if player.name == "Sync_Chaunter" then
			value = value - 500
		end
		if item.itemIncrementRegenerationKillCounter then
			value = value + 2
		end
		local pattern = item.weaponPattern
		if pattern then
			local tiles = pattern.pattern.tiles
			for _, tile in ipairs(tiles) do
				if tile.targetFlags > 0 and not tile.dashDirection then
					value = value - 5
				end
			end
		end
	end
	value = value * 12
	if item.itemStack then
		value = value + item.itemStack.quantity
	end
	return value
end

local function secondOneIsBetter(item1, item2, item1SlotName, player)
	if item1SlotName == "bomb" or item1SlotName == "misc" then
		return true
	end
	local item1Value = getNumericalValue(item1, item1SlotName, player)
	local item2Value = getNumericalValue(item2, item1SlotName, player)
	local better = item2Value > item1Value
	return better
end

local function shouldTake(newItem, player)
	local slot = newItem.itemSlot
	local conflicts = {}
	local slotName
	if slot then
		slotName = slot.name
		if slotName and getNumericalValue(newItem, slotName, player) < -99 then
			return false
		end
		local conflictIDs = player.inventory.itemSlots[slotName]
		if conflictIDs then
			for _, conflictID in ipairs(conflictIDs) do
				table.insert(conflicts, Entities.getEntityByID(conflictID))
			end
		end
	end
	Utilities.removeIf(conflicts, function(conflict)
		return secondOneIsBetter(conflict, newItem, slotName, player)
	end)
	local notHeld = not newItem.item or newItem.item.holder == 0
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
	canPurchase=canPurchase,
	isPanicItem=isPanicItem,
	isUseAtOnceItem=isUseAtOnceItem,
}