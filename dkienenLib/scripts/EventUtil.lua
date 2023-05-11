local currentLevel = require "necro.game.level.CurrentLevel"
local ecs = require "system.game.Entities"
local prefixUtil = require "dkienenLib.PrefixUtil"

local function addEvent(eventName, eventHandlerName, order, sequence, action)
    event[eventName].add(prefixUtil.getMod() .. eventHandlerName, {order = order, sequence = sequence}, action)
end

local function addLevelEvent(modName, eventHandlerName, order, sequence, components, action)
    modName = modName or prefixUtil.getMod()
    local eventName = "levelLoad"
    if order == "processPendingObjects" then
        eventName = "gameStateLevel";
    end
    addEvent(eventName, eventHandlerName, order, sequence, function(ev)
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

local function addDepthLevelEvent(modName, eventHandlerName, order, sequence, components, predicate, action)
    modName = modName or prefixUtil.getMod()
    addLevelEvent(modName, eventHandlerName, order, sequence, components, function (entity, depth, floor, ...)
        if predicate and predicate(depth, floor) then
            action(entity, depth, floor, ...)
        end
    end)
end

local function makeDepthPredicate(depth, floor)
    return function(currentDepth, currentFloor)
        return (not depth or (currentDepth == depth)) and (not floor or (currentFloor == floor))
    end
end

return {
    addEvent=addEvent,
    addLevelEvent=addLevelEvent,
    addDepthLevelEvent=addDepthLevelEvent,
    makeDepthPredicate=makeDepthPredicate
}