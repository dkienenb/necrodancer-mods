local player = require "necro.game.character.Player"
local ecs = require "system.game.Entities"
local modName = require "dkienenLib.PrefixUtil".getMod()
local prefix = require "dkienenLib.PrefixUtil".prefix()
local eventUtil = require "dkienenLib.EventUtil"
local object = require "necro.game.object.Object"

function apply(_, args, _, _, officialName)
  local monsters = args.monsters
  eventUtil.addLevelEvent(modName, "lichSubstitutions", "processPendingObjects", -1, {prefix .. officialName}, function (item)
    local holder = ecs.getEntityByID(item.item.holder)
    if player.isPlayerEntity(holder) then
      for entity in ecs.entitiesWithComponents({ "health" }) do
        if entity.health and entity.health.health and not entity.crateLike and monsters[entity.health.health] then
          local x = entity.position.x
          local y = entity.position.y
          object.delete(entity)
          object.spawn(monsters[entity.health.health], x, y)
        end
      end
    end
  end)
end

return {
  apply=apply
}
