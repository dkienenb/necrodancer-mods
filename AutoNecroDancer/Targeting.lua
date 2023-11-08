local Action = require "necro.game.system.Action"
local Direction = Action.Direction
local Character = require "necro.game.character.Character"
local CommonEnemy = require "necro.game.data.enemy.CommonEnemy"
local CurrentLevel = require "necro.game.level.CurrentLevel"
local Entities = require "system.game.Entities"
local Map = require "necro.game.object.Map"
local Snapshot = require "necro.game.system.Snapshot"
local Tile = require "necro.game.tile.Tile"
local Utilities = require "system.utils.Utilities"
local Vision = require "necro.game.vision.Vision"

local Utils = require("AutoNecroDancer.Utils")
local Pathfinding = require("AutoNecroDancer.Pathfinding")
local Safety = require("AutoNecroDancer.Safety")

local LuteScript = require("AutoNecroDancer.ScriptedBosses.GoldenLute")
local CoralRiffScript = require("AutoNecroDancer.ScriptedBosses.CoralRiff")
local DeathMetalScript = require("AutoNecroDancer.ScriptedBosses.DeathMetal")
local FortissimoleScript = require("AutoNecroDancer.ScriptedBosses.Fortissimole")
targets = Snapshot.levelVariable({})

local PRIORITY = {
	OVERRIDE=99,
	MONSTER = 4,
	GOLD = -1,
	EXIT = 2,
	WALL = 1
}

local SCAN_HEIGHT_RADIUS = 50
local SCAN_WIDTH_RADIUS = 50

local function getTargetCoords(target)
	local entity = target.entityID and Entities.getEntityByID(target.entityID) or {position={x=target.x, y=target.y}}
	return entity.position.x, entity.position.y
end

local function hasExit(x, y, player)
	local tileInfo = Tile.getInfo(x, y)
	if tileInfo.descent then return true end
	for _, entity in Map.entitiesWithComponent(x, y, "trap") do
		if not (player.grooveChainDropOnDescent and player.grooveChainInflictDamageOnDrop and entity.trapDescend and (not entity.trapDescend.type or entity.trapDescend.type ~= 4) ) and entity.trapDescend then
			if not player.hoverEffect and player.hoverEffect.active then
				return true
			end
		end
	end
	return false
end

local function hasGold(x, y, player)
	if player.goldHater then return false end
	-- FIXME very bad bandaid fix for z5 gorgons (for lag)
	if Map.firstWithComponent(x, y, "crateLike") then return false end
	if Map.firstWithComponent(x, y, "itemCurrency") then return true end
	local tileInfo = Tile.getInfo(x, y)
	if tileInfo.digEntity == "ResourceHoardGoldSmall" then
		return true
	end
	return false
end

local function scanSpaceForTargets(x, y, player)
	if Vision.isVisible(x, y) then
		local tileInfo = Tile.getInfo(x, y)
		local digable, rising = Utils.canDig(player, x, y)
		if digable and not rising and not tileInfo.isFloor then
			table.insert(targets, {x=x,y=y,wall=true,priority=PRIORITY.WALL})
		end
		if hasExit(x, y, player) then
			table.insert(targets, {x=x,y=y,exit=true,priority=PRIORITY.EXIT})
		end
		if hasGold(x, y, player) then
			table.insert(targets, {x=x,y=y,gold=true,priority=PRIORITY.GOLD})
		end
		for _, entity in Utils.iterateMonsters(x, y, player, false) do
			-- TODO properly pathfind to these
			-- TODO target spaces 2 from standing armadillos
			if entity.name ~= "Spider" and not Utils.stringStartsWith(entity.name, "Armadillo") and entity.name ~= "Clone" and entity.name ~= "Mole" and entity.name ~= "Slime3" then
				if not entity.playableCharacter then
					if not (entity.controllable and entity.controllable.playerID ~= 0) then
						table.insert(targets, {entityID=entity.id, priority=PRIORITY.MONSTER})
					end
				end
			end
		end
	end
end

local function checkIfTargetDead(target, player)
	if target.override then return true end
	if target.entityID then
		local monster = Entities.getEntityByID(target.entityID)
		if not Character.isAlive(monster) then
			return true
		end
		if monster.controllable and monster.controllable.playerID ~= 0 then
			return true
		end
	end
	if target.gold then
		local x, y = getTargetCoords(target)
		if not hasGold(x, y, player) then return true end
	end
	if target.exit then
		local x, y = getTargetCoords(target)
		if not hasExit(x, y, player) then return true end
	end
	if target.wall then
		local x, y = getTargetCoords(target)
		if not Utils.canDig(player, x, y) then
			return true
		end
		local tileInfo = Tile.getInfo(x, y)
		if tileInfo.isFloor then return true end
		if tileInfo.digType == "MetalDoorOpen" then return true end
	end
	return false
end

local function cleanDeadTargets(player)
	Utilities.removeDuplicates(targets)
	Utilities.removeIfArg(targets, checkIfTargetDead, player)
	for _, target in ipairs(targets) do
		target.unreachable = nil
	end
end

local function targetingOverride(player)
	--[[
		TODO KC
		kill extras then zombies
	--]]
	DeathMetalScript.deathMetalOverride(player, targets)
	FortissimoleScript.fortissimoleOverride(player, targets)
	LuteScript.luteOverride(player, targets)
	CoralRiffScript.coralRiffOverride(player, targets)
end

local function scanForTargets(player)
	cleanDeadTargets(player)
	local playerX, playerY = player.position.x, player.position.y
	for dx = -SCAN_WIDTH_RADIUS, SCAN_WIDTH_RADIUS do
		for dy = -SCAN_HEIGHT_RADIUS, SCAN_HEIGHT_RADIUS do
			scanSpaceForTargets(playerX + dx, playerY + dy, player)
		end
	end
	if CurrentLevel.isBoss() then
		local has = false
		for _ in Entities.entitiesWithComponents({"boss"}) do
			has = true
			break
		end
		if not has then
			table.insert(targets, {x=0, y=player.position.y, override=true, priority=PRIORITY.WALL})
		end
	end
	targetingOverride(player)
end

local function getTarget(player)
	local selected
	local selectedPriority
	for _, next in ipairs(targets) do
		if not next.unreachable then
			selectedPriority = selected and selected.priority or 0
			local nextPriority = next.priority
			if nextPriority > selectedPriority then
				selected = next
			elseif nextPriority == selectedPriority then
				local distanceNext = Pathfinding.distanceBetween(player, next)
				local distanceSelected = Pathfinding.distanceBetween(player, selected)
				if distanceSelected >= distanceNext then
					selected = next
				end
			end
		end
	end
	return selected
end

return {
	scanForTargets = scanForTargets,
	getTargetCoords = getTargetCoords,
	hasExit=hasExit,
	getTarget=getTarget,
	PRIORITY=PRIORITY
}