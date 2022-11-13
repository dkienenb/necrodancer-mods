local marker = require "necro.game.tile.Marker"
local currentLevel = require "necro.game.level.CurrentLevel"
local object = require "necro.game.object.Object"
local ecs = require "system.game.Entities"

event.levelLoad.add("BossRush", {order = "training", sequence = 1}, function(ev)
	if not currentLevel.isSafe() and not currentLevel.isBoss() then
		local spawnX, spawnY = marker.lookUpMedian(marker.Type.SPAWN)
		if not spawnX then spawnX = 0 end
		if not spawnY then spawnY = 0 end
		for xOffset = -2, 2 do
			for yOffset = -2, 2 do
				object.spawn("Sync_CrackTrapdoorOpen", spawnX + xOffset, spawnY + yOffset)
			end
		end
		for entity in ecs.entitiesWithComponents {"gameObject", "health", "enemyPoolMiniboss"} do
			object.kill(entity)
		end
	end
end)

