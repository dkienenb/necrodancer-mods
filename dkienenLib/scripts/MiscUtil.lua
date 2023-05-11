local object = require "necro.game.object.Object"
local map = require "necro.game.object.Map"
local tile = require "necro.game.tile.Tile"
local ecs = require "system.game.Entities"

function makeProperIdentifier(name)
	name = string.gsub(name, "%s+", "")
	name = string.gsub(name, "'+", "")
	return name
end

local function banSingleZones()
	event.lobbyGenerate.add("removeStairs", {order="amplified", sequence=2}, function ()
		for entity in ecs.entitiesWithComponents { "trapStartRun" } do
			if entity.trapStartRun.mode == "SingleZone" then
				local x, y = entity.position.x, entity.position.y
				object.delete(entity)
				tile.setType(x, y, "Floor")
				local label = map.firstWithComponent(x, y, "worldLabel")
				if label then
					object.delete(label)
				end
			end
		end
	end)
end

function makePrefix(modName)
	return modName .. "_"
end

return {
	makeProperIdentifier=makeProperIdentifier,
	makePrefix = makePrefix,
	banSingleZones=banSingleZones
}
