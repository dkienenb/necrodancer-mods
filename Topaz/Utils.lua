local Action = require "necro.game.system.Action"
local AffectorItem = require "necro.game.item.AffectorItem"
local AI = require "necro.game.enemy.ai.AI"
local Attack = require "necro.game.character.Attack"
local CurrentLevel = require "necro.game.level.CurrentLevel"
local Direction = Action.Direction
local Entities = require "system.game.Entities"
local Map = require "necro.game.object.Map"
local ObjectEvents = require "necro.game.object.ObjectEvents"
local SizeModifier = require "necro.game.character.SizeModifier"
local Tile = require "necro.game.tile.Tile"
local Utilities = require "system.utils.Utilities"

local Pathfinding = require("Topaz.Pathfinding")

local Utils = {}

function Utils.tAlloc()

end

function Utils.getDirections(entity)
	-- TODO dragons breathing fire
	if entity.freezable and (entity.freezable.remainingTurns > 0 or entity.freezable.permanent) then return {} end
	if entity.remappedMovement then return {} end
	if entity.ai and entity.ai.id == AI.Type.PAWN then
		return {[Direction.DOWN_LEFT]=true, [Direction.DOWN_RIGHT]=true}
	end
	local allDirections = {Direction.RIGHT, Direction.UP_RIGHT, Direction.UP, Direction.UP_LEFT, Direction.LEFT, Direction.DOWN_LEFT, Direction.DOWN, Direction.DOWN_RIGHT}
	local actionFilter = entity.actionFilter
	if not actionFilter then return Utilities.listToSet(allDirections) end
	local ignoreActions = actionFilter.ignoreActions
	Utilities.removeIf(allDirections, function(direction)
		return ignoreActions[direction]
	end)
	if entity.charge and entity.charge.active then
		Utilities.removeIf(allDirections, function(direction)
			return direction ~= entity.charge.direction
		end)
	end
	if ((entity.ai and entity.ai.id == AI.Type.LINEAR) or (entity.inhibitOnFacingChange and entity.facingDirection))
			and not (entity.controllable and entity.controllable.playerID ~= 0) then
		Utilities.removeIf(allDirections, function(direction)
			return direction ~= entity.facingDirection.direction
		end)
	end
	if entity.aiPattern and entity.aiPattern.moves and entity.aiPattern.index and entity.aiPattern.moves[entity.aiPattern.index]
			and not (entity.controllable and entity.controllable.playerID ~= 0) then
		Utilities.removeIf(allDirections, function(direction)
			return direction ~= entity.aiPattern.moves[entity.aiPattern.index]
		end)
	end
	local filteredDirections = Utilities.listToSet(allDirections)
	return filteredDirections
end

function Utils.isDangerous(monster, player)
	-- TODO evil shoppies
	if monster.shopkeeper then return false end
	if monster.crateLike then return false end
	if monster.explosive then return false end
	if monster.captiveAudience and monster.captiveAudience.active then return false end
	if monster.controllable and monster.controllable.playerID ~= 0 then return false end
	return true
end

function Utils.canEverHurt(monster, player)
	if not monster.health then return false end
	local hp = monster.health.health
	if not hp then return false end
	if monster.name == "DeadRinger" then return false end
	if monster.name == "Trainingsarcophagus" then return false end
	if monster.name == "LuteDragon" then
		if monster.luteBody.headType ~= "LuteHead" then
			return true
		end
	end
	if monster.castOnCollision and monster.castOnCollision.spell and monster.castOnCollision.spell == "SpellcastOrbHit" then return false end
	return true
end

function Utils.shouldKill(monster, player)
	if not Utils.isDangerous(monster, player) then return false end
	if not Utils.canEverHurt(monster, player) then return false end
	return true
end

function Utils.iterateMonsters(x, y, player, includeUnhurtables)
	local monsters = {}
	for _, entity in Map.entitiesWithComponent(x, y, "health") do
		local checkerFunction = Utils.isDangerous
		if not includeUnhurtables then
			checkerFunction = Utils.shouldKill
		end
		if checkerFunction(entity, player) then
			table.insert(monsters, entity)
		end
	end
	return ipairs(monsters)
end

function Utils.canDig(entity, x, y)
	-- TODO zombies and other mons that can't dig, phasing players
	local tileInfo = Tile.getInfo(x, y)
	if tileInfo.isFloor then
		return true
	end
	if not tileInfo.digResistance then
		return false
	end
	if Map.hasComponent(x, y, "Sync_digRetaliation" ) then
		return false
	end
	local parameters = {
		x = x,
		y = y,
		resistance = -2,
		tileInfo = tileInfo,
		flags = {}
	}
	ObjectEvents.fire("computeDigStrength", entity, parameters)
	local strength = parameters.strength
	local dx, dy = math.abs(entity.position.x - x), math.abs(entity.position.y - y)
	if SizeModifier.isTiny(entity) and (dx > 1 or dy > 1) and entity.inventory and entity.inventory.itemSlots and entity.inventory.itemSlots.shovel and entity.inventory.itemSlots.shovel[1] then
		local shovel = Entities.getEntityByID(entity.inventory.itemSlots.shovel[1])
		strength = shovel.shovel.strength
	end
	local isMetalDoor = tileInfo.isDoor and tileInfo.digEntity
	local rising = isMetalDoor or tileInfo.digType and tileInfo.digType[strength] and tileInfo.digType[strength] == "RecededFloor"
	return strength >= tileInfo.digResistance, rising
end

function Utils.coordsInDirection(startX, startY, direction)
	local dx, dy = Action.getMovementOffset(direction)
	local targetX = startX + dx
	local targetY = startY + dy
	return targetX, targetY
end

function Utils.positionInDirection(entity, direction)
	local position = entity.position
	local startX = position.x
	local startY = position.y
	local targetX, targetY = Utils.coordsInDirection(startX, startY, direction)
	return startX, startY, targetX, targetY
end

function Utils.unsinkable(entity)
	return not entity.sinkable or AffectorItem.entityHasItem(entity, "itemTileUnsinkImmunity")
end

function Utils.firewalker(entity)
	return not entity.tileIdleDamageReceiver or AffectorItem.entityHasItem(entity, "itemTileIdleDamageImmunity")
end

function Utils.unableToBeHurtByTraps(entity)
	local item = AffectorItem.getItem(entity, "itemIncomingDamageTypeImmunityEarly")
	local immune = item and item.itemIncomingDamageTypeImmunityEarly.immuneDamageTypes == 256
	local invul = not Attack.Flag.check(entity.attackable.currentFlags, Attack.Flag.TRAP)
	return invul or immune
end

function Utils.ableToBeMovedByTraps(entity)
	return not AffectorItem.entityHasItem(entity, "itemHeavy") and not AffectorItem.entityHasItem(entity, "itemKnockbackImmunity") and not Utils.unableToBeHurtByTraps(entity)
end

function Utils.positionAfterTrap(entity, x, y, directionOffsets)
	-- TODO wind gargoyles
	if Pathfinding.hasSnag(entity, x, y) then return x, y end
	if Utils.ableToBeMovedByTraps(entity) then
		for _, trap in Map.entitiesWithComponent(x, y, "trap") do
			-- TODO secret shops (entity.trapTravel)
			if trap.trapMove then
				local dx, dy
				if trap.facingDirection then
					dx, dy = Action.getMovementOffset(trap.facingDirection.direction)
				elseif trap.trapMoveRelativeDirection then
					dx, dy = 0 - directionOffsets.dx, 0 - directionOffsets.dy
				end
				local newX, newY = x + dx, y + dy
				if not Pathfinding.hasSnag(entity, newX, newY) then
					return newX, newY
				end
			end
		end
	end
	return x, y
end

function Utils.stringStartsWith(str, start)
	return str:sub(1, #start) == start
end

function Utils.doSomethingCached(cache, x, y, thing, ...)
	local prior = cache:getNode(x, y);
	if prior then
		return prior.cachedValue
	else
		local value = thing(x, y, ...)
		cache:insertNode(x, y, {cachedValue=value})
		return value
	end
end

return Utils