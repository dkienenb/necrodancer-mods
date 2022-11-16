local entityUtil = require "dkienenLib.EntityUtil"
local customEntities = require "necro.game.data.CustomEntities"
local aiUtil = require "dkienenLib.AIUtil"
local boss = require "necro.game.level.Boss"

function registerMonster(modName, name, template, health, ai, components, aiFunction)
    if not components then components = {} end
    components.health= {maxHealth = health, health = health}
    local aiID=aiUtil.getAIByName(ai)
    if not aiID then
        aiID=aiUtil.registerAI(modName, name, aiFunction)
    end
    components.ai = {id=aiID}
    entityUtil.registerEntity(modName, customEntities.template.enemy(template), components, name)
end

function registerBoss(modName, name, template, health, ai, components, ...)
    if not components then components = {} end
    local bossID = boss.Type.extend(modName .. "_" ..name)
    components.boss = { type = bossID }
    components.Sync_enemyPoolBoss = {}
    components.castOnHit = {spell = "SpellcastTeleportBoss"}
    registerMonster(modName, name, template, health, ai, components, ...)
    return bossID
end

return {
    registerMonster=registerMonster,
    registerBoss=registerBoss
}