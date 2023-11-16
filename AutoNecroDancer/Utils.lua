local Action = require "necro.game.system.Action"
local AI = require "necro.game.enemy.ai.AI"
local Attack = require "necro.game.character.Attack"
local Direction = Action.Direction
local Map = require "necro.game.object.Map"
local ObjectEvents = require "necro.game.object.ObjectEvents"
local Tile = require "necro.game.tile.Tile"
local Utilities = require "system.utils.Utilities"

local Pathfinding = require("AutoNecroDancer.Pathfinding")

local function getDirections(entity)
	-- TODO dragons breathing fire
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

local function isDangerous(monster, player)
	if monster.shopkeeper then return false end
	if monster.crateLike then return false end
	if monster.explosive then return false end
	if monster.controllable and monster.controllable.playerID ~= 0 then return false end
	return true
end

local function canEverHurt(monster, player)
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

local function shouldKill(monster, player)
	if not isDangerous(monster, player) then return false end
	if not canEverHurt(monster, player) then return false end
	return true
end

local function iterateMonsters(x, y, player, includeUnhurtables)
	local monsters = {}
	for _, entity in Map.entitiesWithComponent(x, y, "health") do
		local checkerFunction = isDangerous
		if not includeUnhurtables then
			checkerFunction = shouldKill
		end
		if checkerFunction(entity, player) then
			table.insert(monsters, entity)
		end
	end
	return ipairs(monsters)
end

local function canDig(entity, x, y)
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
	local isMetalDoor = tileInfo.isDoor and tileInfo.digEntity
	local rising = isMetalDoor or tileInfo.digType and tileInfo.digType[strength] and tileInfo.digType[strength] == "RecededFloor"
	return strength >= tileInfo.digResistance, rising
end

local function coordsInDirection(startX, startY, direction)
	local dx, dy = Action.getMovementOffset(direction)
	local targetX = startX + dx
	local targetY = startY + dy
	return targetX, targetY
end

local function positionInDirection(entity, direction)
	local position = entity.position
	local startX = position.x
	local startY = position.y
	local targetX, targetY = coordsInDirection(startX, startY, direction)
	return startX, startY, targetX, targetY
end

local function unsinkable(entity)
	return not entity.sinkable
end

local function untrappable(entity)
	return not Attack.Flag.check(entity.attackable.currentFlags, Attack.Flag.TRAP)
end

local function positionAfterTrap(entity, x, y, directionOffsets)
	-- TODO wind gargoyles
	if Pathfinding.hasSnag(entity, x, y) then return x, y end
	if not untrappable(entity) then
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

local function stringStartsWith(str, start)
	return str:sub(1, #start) == start
end

local function getBasename(path)
	return string.gsub(path, "(.*/)(.*)", "%2")
end

function convertDotPathToSlashPath(dotPath)
	return string.gsub(dotPath, "%.", "/")
end

local function allScriptsFromPackage(scriptPath)
	local pathPrefix = "mods/AutoNecroDancer/scripts/"
	local pathSuffix = scriptPath
	local path = pathPrefix .. pathSuffix
	local listings = FileIO.listFiles(path, FileIO.List.RECURSIVE + FileIO.List.FILES + FileIO.List.FULL_PATH + FileIO.List.SORTED)
	local mappings = {}
	for _, listing in ipairs(listings) do
		local basename = string.sub(getBasename(listing), 1, -5)
		mappings[basename] = require("AutoNecroDancer." .. scriptPath .. "." .. basename)
	end
	return mappings
end

return {
	stringStartsWith=stringStartsWith,
	getDirections=getDirections,
	canDig = canDig,
	iterateMonsters = iterateMonsters,
	positionInDirection=positionInDirection,
	canEverHurt=canEverHurt,
	positionAfterTrap=positionAfterTrap,
	unsinkable=unsinkable,
	untrappable=untrappable,
	allScriptsFromPackage=allScriptsFromPackage
}