local currentLevel = require "necro.game.level.CurrentLevel"
local ecs = require "system.game.Entities"

function addLevelEvent(modName, eventHandlerName, order, sequence, components, action)
    local eventName = "levelLoad"
    if order == "processPendingObjects" then
        eventName = "gameStateLevel";
    end
    event[eventName].add(modName .. eventHandlerName, {order = order, sequence = sequence}, function(ev)
        if not currentLevel.isSafe() then
            local depth = currentLevel.getDepth()
            local floor = currentLevel.getFloor()
            if components then
                for entity in ecs.entitiesWithComponents(components) do
                    action(entity, depth, floor, ev, modName)
                end
            else
                action(nil, depth, floor, ev, modName)
            end
        end
    end)
end

function addDepthLevelEvent(modName, eventHandlerName, order, sequence, components, predicate, action)
    addLevelEvent(modName, eventHandlerName, order, sequence, components, function (entity, depth, floor, ...)
        if predicate and predicate(depth, floor) then
            action(entity, depth, floor, ...)
        end
    end)
end

function makeDepthPredicate(depth, floor)
    return function(currentDepth, currentFloor)
        return (not depth or (currentDepth == depth)) and (not floor or (currentFloor == floor))
    end
end

return {
    addLevelEvent=addLevelEvent,
    addDepthLevelEvent=addDepthLevelEvent,
    makeDepthPredicate=makeDepthPredicate
}