local miscUtil = require "dkienenLib.MiscUtil"
local eventUtil = require "dkienenLib.EventUtil"
local marker = require "necro.game.tile.Marker"
local object = require "necro.game.object.Object"
local snapshot = require "necro.game.system.Snapshot"
local rng = require "necro.game.system.RNG"
local ecs = require "system.game.Entities"
local map = require "necro.game.object.Map"
local player = require "necro.game.character.Player"
local itemGeneration = require "necro.game.item.ItemGeneration"

trackedItemDroppingEntities = snapshot.runVariable({});
local prefix = miscUtil.makePrefix("dkienenLib");
local RNG_RANDOMDROPS = rng.Channel.extend(prefix .. "RandomDrops")

function addOneDrop(item)
	local candidates = {}
	for entity in ecs.entitiesWithComponents {"gameObject", "health"} do
		if not entity.shopkeeper and not (entity.controllable and entity.controllable.playerID ~= 0) and not entity.crateLike then
			table.insert(candidates, entity)
		end
	end
	local chosen = rng.choice(candidates, RNG_RANDOMDROPS)
	if not chosen then
		local spawnX, spawnY = marker.lookUpMedian(marker.Type.SPAWN)
		local thing = object.spawn(item, spawnX, spawnY)
		itemGeneration.markSeen(thing, 1)
	else
		if not trackedItemDroppingEntities[chosen.id] then
			trackedItemDroppingEntities[chosen.id] = {}
		end
		table.insert(trackedItemDroppingEntities[chosen.id], item)
	end
end

function addRandomDrop(modName, itemName, requiredPlayerComponent, depth, floor)
	itemName = miscUtil.makeProperIdentifier(itemName)
	local item = miscUtil.makePrefix(modName) .. itemName
	local tableKey = modName .. itemName;
	local components
	if requiredPlayerComponent then
		components = {requiredPlayerComponent}
	end
	eventUtil.addDepthLevelEvent("AddRandomItemDrop" .. tableKey, "training", 9, components, eventUtil.makeDepthPredicate(depth, floor), function()
		addOneDrop(item)
	end)
end

event.objectDeath.add("RandomItemDrops", {order="itemDrop"}, function(ev)
	if trackedItemDroppingEntities[ev.entity.id] then
		for _, item in ipairs(trackedItemDroppingEntities[ev.entity.id]) do
			local thing = object.spawn(item, ev.entity.position.x, ev.entity.position.y, {})
			itemGeneration.markSeen(thing, 1)
			if ev.killer and ev.killer.goldHater then
				ev.credit = -2
			end
			trackedItemDroppingEntities[ev.entity.id] = nil
		end
	end
end)

function apply(_, args, name, modName)
	addRandomDrop(modName, name, args.requiredPlayerComponent, args.depth, args.floor)
end

return {
	apply=apply
}
