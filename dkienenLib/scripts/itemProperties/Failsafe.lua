local miscUtil = require "dkienenLib.MiscUtil"
local marker = require "necro.game.tile.Marker"
local currentLevel = require "necro.game.level.CurrentLevel"
local priceTag = require "necro.game.item.PriceTag"
local itemGeneration = require "necro.game.item.ItemGeneration"
local object = require "necro.game.object.Object"

function addShopFailsafe(modName, itemName, depth, floor)
	itemName = miscUtil.makeProperIdentifier(itemName)
	local name = miscUtil.makePrefix(modName) .. itemName
	event.levelLoad.add("FailsafeShop" .. modName .. itemName, {order = "training", sequence = 10}, function(ev)
		if (not depth or currentLevel.getDepth() == depth) and (not floor or currentLevel.getFloor() == floor) and not (itemGeneration.getSeenCount(name) > 0) then
			local shopX, shopY = marker.lookUpMedian(marker.Type.SHOP)
			if shopX and shopY then
				local thing = object.spawn(name, shopX + 2, shopY)
				itemGeneration.markSeen(thing, 1)
				local tag = object.spawn("PriceTagGold", shopX - 2)
				tag.priceTagCostCurrency.cost = thing.itemPrice.coins * 2.5
				priceTag.add(thing, tag)
			end
		end
	end)
end

function addDropFailsafe(modName, itemName, depth, floor, components)
	itemName = miscUtil.makeProperIdentifier(itemName)
	local name = miscUtil.makePrefix(modName) .. itemName
	event.objectDeath.add("FailsafeDrop" .. modName .. itemName, {order="itemDrop", filter=components}, function(ev)
		if (not depth or currentLevel.getDepth() == depth) and (not floor or currentLevel.getFloor() == floor) and not (itemGeneration.getSeenCount(name) > 0) then
			local thing = object.spawn(name, ev.entity.position.x, ev.entity.position.y, {})
			itemGeneration.markSeen(thing, 1)
		end
	end)
end

function apply(components, args, name, modName)
	if args then
		if args.shop then
			addShopFailsafe(modName, name, args.shop.depth, args.shop.floor);
		end
		if args.drop then
			addDropFailsafe(modName, name, args.drop.depth, args.drop.floor, args.drop.components);
		end
	end
end

return {
	apply=apply
}
