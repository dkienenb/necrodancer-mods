local Action = require "necro.game.system.Action"
local AffectorItem = require "necro.game.item.AffectorItem"
local Direction = Action.Direction
local Entities = require "system.game.Entities"
local Map = require "necro.game.object.Map"
local Ping = require "necro.client.Ping"
local Snapshot = require "necro.game.system.Snapshot"
local Tile = require "necro.game.tile.Tile"
local Utilities = require "system.utils.Utilities"

local Data = require("Topaz.Data")
local Safety = require("Topaz.Safety")
local Targeting = require("Topaz.Targeting")
local Utils = require("Topaz.Utils")

lutePhase = Snapshot.levelVariable(0)
freeze = Snapshot.levelVariable(false)

local function hasSnag(player, targetX, targetY)
	-- TODO return false if we don't know
	-- TODO monster on trapdoor
	-- TODO different weapon types
	local tileInfo = Tile.getInfo(targetX, targetY)
	if not tileInfo.isFloor then
		return true
	end
	if Map.hasComponent(targetX, targetY, "chestLike") then return true end
	for _, entity in Map.entitiesWithComponent(targetX, targetY, "health") do
		if not (entity.controllable and entity.controllable.playerID ~= 0) then
			if not Safety.hasCourage(player, targetX, targetY) then
				return true
			end
		end
	end
end

local function chebyshevDistance(dx, dy)
	return math.max(math.abs(dx), math.abs(dy))
end

local function getHeuristicFunction(hasDiag)
	if hasDiag then return chebyshevDistance end
	return Utilities.distanceL1
end

local function hasDiagonal(player)
	local directionOptions = Utils.getDirections(player)
	return directionOptions[Direction.UP_LEFT]
end

local function movesEveryBeat(monster)
	if not Safety.aiAllowsMovement(monster) then
		return false
	end
	if monster.beatDelay and monster.beatDelay.interval > 1 then
		return false
	end
	return true
end

local function hasParityIssue(player, target, path)
	-- TODO moles
	if not target.entityID then
		return false
	end
	local monster = Entities.getEntityByID(target.entityID)
	if hasDiagonal(player) then
		return false
	end
	if #path ~= 2 and #path ~= 4 then
		return false
	end
	if not movesEveryBeat(monster) then
		return false
	end
	if AffectorItem.entityHasItem(monster, "weaponShove") then
		return false
	end
	if monster.charge and monster.charge.active then
		return false
	end
	return true
end

local function distanceBetween(player, target)
	local playerX = player.position.x
	local playerY = player.position.y
	local entityX, entityY = Targeting.getTargetCoords(target)
	local dxe = playerX - entityX
	local dye = playerY - entityY
	return getHeuristicFunction(hasDiagonal(player))(dxe, dye)
end

-- TODO cache every turn instead of every time we want to find a path

local function convertDirectionsToOffsets(directions)
	local offsets = {}
	for direction in pairs(directions) do
		local dx, dy = Action.getMovementOffset(direction)
		table.insert(offsets,{dx=dx,dy=dy})
	end
	return offsets
end

local function findSnag(player, directions)
	for direction in pairs(directions) do
		local _, _, x, y = Utils.positionInDirection(player, direction)
		if hasSnag(player, x, y) then
			return direction
		end
	end
end

-- TODO pathfind to immobile snaggys near coals

local function findPath(player, target, startingDirectionOptions, blockedCache)
	if target.overrideAction then
		return target.overrideAction
	end
	local directionOptions = Utils.getDirections(player)
	local hasDiag = hasDiagonal(player)
	local heuristicFunction = getHeuristicFunction(hasDiag)
	local directionOffsets = convertDirectionsToOffsets(directionOptions)
	local closedCache = Data.NodeCache:new()
	local targetX, targetY = Targeting.getTargetCoords(target)
	-- TODO use the cached version here
	local possible = hasSnag(player, targetX, targetY) or not Safety.hasPathBlocker(targetX, targetY, player)
	if not possible then return end
	local choices = Data.MinHeap:new()
	local playerX, playerY = player.position.x, player.position.y
	local cost = heuristicFunction(playerX - targetX, playerY - targetY)
	local startingDirectionOffsets = convertDirectionsToOffsets(startingDirectionOptions)
	choices:push({ x=playerX, y=playerY, distance=0, directionOffsets=startingDirectionOffsets, path={}}, cost)
	local found = false
	while not found do
		local node = choices:pop()
		if not node then break end
		local nodeX, nodeY = node.x, node.y
		local closed = closedCache:getNode(nodeX, nodeY)
		if not closed then
			closedCache:insertNode(nodeX, nodeY, true)
			for _, offset in ipairs(node.directionOffsets) do
				local dx, dy = offset.dx, offset.dy
				local newX, newY = nodeX + dx, nodeY + dy
				local arrived = newX == targetX and newY == targetY
				local trapX, trapY = Utils.positionAfterTrap(player, newX, newY, offset)
				if trapX ~= newX or trapY ~= newY and not arrived then
					closedCache:insertNode(newX, newY, true)
					if not Utils.doSomethingCached(blockedCache, newX, newY, Safety.hasPathBlocker, player) then
						newX, newY = trapX, trapY
						arrived = arrived or (newX == targetX and newY == targetY)
					end
				end
				if arrived or (not closedCache:getNode(newX, newY) and not Utils.doSomethingCached(blockedCache, newX, newY, Safety.hasPathBlocker, player)) then
					local spaceCost = hasSnag(player, newX, newY) and 2 or 1
					if Safety.hasLiquid(newX, newY) then
						spaceCost = spaceCost + 1
					end
					local newDistance = spaceCost + node.distance
					local newPath = Utilities.arrayCopy(node.path)
					table.insert(newPath, offset)
					local newNode = {x=newX, y=newY, distance=newDistance, directionOffsets=directionOffsets, path=newPath}
					choices:push(newNode, newDistance + heuristicFunction(newX - targetX, newY - targetY))
					if arrived then found = newNode end
				end
			end
		end
	end
	if found then
		if hasParityIssue(player, target, found.path) then
			local snag = findSnag(player, startingDirectionOptions)
			if snag then return snag end
		end
		local offset = found.path[1]
		Ping.perform(targetX, targetY, target.id)
		return Action.getDirection(offset.dx, offset.dy)
	end
end

return {
	distanceBetween=distanceBetween,
	findPath=findPath,
	hasSnag=hasSnag,
	hasDiagonal=hasDiagonal
}