local componentUtil = require "dkienenLib.ComponentUtil"
local eventUtil = require "dkienenLib.EventUtil"
local ecs = require "system.game.Entities"
local health = require "necro.game.character.Health"

function apply(components)
	components.dkienenLib_gradualMaxHealthIncrease = {}
end

componentUtil.registerComponent("dkienenLib", "gradualMaxHealthIncrease", {levels={type="int32", default=0}, healthGranted={type="int32", default=0}})
eventUtil.addLevelEvent("dkienenLib", "maxHealthIncrease", "runState", -1, {"dkienenLib_gradualMaxHealthIncrease"}, function (entity)
	local levels = entity.dkienenLib_gradualMaxHealthIncrease.levels
	local healthGranted = entity.dkienenLib_gradualMaxHealthIncrease.healthGranted
	levels = levels + 1
	local healthIncrease = (levels * 2) - healthGranted
	if entity.item and entity.item.holder then
		local holder = ecs.getEntityByID(entity.item.holder)
		health.increaseMaxHealth(holder, healthIncrease, entity)
		healthGranted = healthGranted + healthIncrease
	end
	entity.dkienenLib_gradualMaxHealthIncrease.levels = levels
	entity.dkienenLib_gradualMaxHealthIncrease.healthGranted = healthGranted
end)

event.inventoryUnequipItem.add("loseGradualMaxHP", {order = "health", filter = "dkienenLib_gradualMaxHealthIncrease"}, function (ev)
	if ev.holder and ev.holder.health then
		local loss = ev.item.dkienenLib_gradualMaxHealthIncrease.healthGranted
		health.increaseMaxHealth(ev.holder, -loss)
	end
end)

return {
	apply=apply
}
