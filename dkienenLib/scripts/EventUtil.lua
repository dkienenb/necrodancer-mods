local currentLevel = require "necro.game.level.CurrentLevel"
local ecs = require "system.game.Entities"

function addLevelEvent(eventName, order, sequence, components, action)
    event.levelLoad.add(eventName, {order = order, sequence = sequence}, function(ev)
        if not currentLevel.isSafe() then
            if components then
                for entity in ecs.entitiesWithComponents(components) do
                    action(entity, ev)
                end
            else
                action(nil, ev)
            end
        end
    end)
end

function addDepthLevelEvent(eventName, order, sequence, components, predicate, action)
    addLevelEvent(eventName, order, sequence, components, function (...)
        if predicate and predicate(currentLevel.getDepth(), currentLevel.getFloor()) then
            action(...)
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