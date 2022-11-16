local ai = require "necro.game.enemy.ai.AI"

function registerAI(modName, name, action)
    local aiID = ai.Type.extend(modName .. name)
    event.aiAct.add("AI" .. modName .. name, aiID, function (ev)
        action(ev)
    end)
    return aiID
end

function getAIByName(name)
    return ai.Type[name]
end

return {
    registerAI=registerAI,
    getAIByName=getAIByName
}