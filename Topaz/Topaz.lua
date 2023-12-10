local Action = require "necro.game.system.Action"
local CurrentLevel = require "necro.game.level.CurrentLevel"
local Entities = require "system.game.Entities"
local Map = require "necro.game.object.Map"
local RNG = require "necro.game.system.RNG"
local Snapshot = require "necro.game.system.Snapshot"
local Utilities = require "system.utils.Utilities"

local Direction = Action.Direction
local prefix = "Topaz" .. "_"
local RNG_MOVEMENT = RNG.Channel.extend(prefix .. "Movement")

local Data = require("Topaz.Data")
local ItemChoices = require("Topaz.ItemChoices")
local Pathfinding = require("Topaz.Pathfinding")
local Safety = require("Topaz.Safety")
local Targeting = require("Topaz.Targeting")
local Utils = require("Topaz.Utils")

local targetExit = Snapshot.levelVariable(false)

local function isSliding(entity)
	return entity.slide and entity.slide.direction ~= Direction.NONE
end

event.entitySchemaLoadNamedEntity.add("debug", {key="FeetBootsLead"}, function (ev)
	--dbg(ev.entity)
end)

local function goTowards(player, target, currentDirectionOptions, blockedCache)
	return Pathfinding.findPath(player, target, Utilities.listToSet(currentDirectionOptions), blockedCache)
end

local function getNextDirection(player)
	local badPossesions = {Pawn=true,Pawn2=true,Slime=true,Slime2=true,Slime4=true,Slime5=true,Cauldron=true,Cauldron2=true,MushroomLight=true,Mushroom=true,Mushroom2=true,SpiderFallen=true}
	if badPossesions[player.name] then
		return Action.Special.ITEM_2
	end
	if player.grab and player.grab.target ~= 0 then
		return Action.Special.ITEM_2
	end
	local actionSlot = player.inventory.itemSlots.action
	local hasActionItem = actionSlot and actionSlot[1] ~= nil
	local actionItem = hasActionItem and Entities.getEntityByID(actionSlot[1])
	local playerX, playerY = player.position.x, player.position.y
	if actionItem and ItemChoices.isUseAtOnceItem(actionItem, player) and Safety.isValidSpace(playerX, playerY, playerX, playerY, player) then
		if not (actionItem.itemActivable and actionItem.itemActivable.active) then
			return Action.Special.ITEM_1
		end
	end
	local choices = Utils.getDirections(player)
	local filteredChoices = {}
	for direction in pairs(choices) do
		if Safety.isValidDirection(direction, player) then
			table.insert(filteredChoices, direction)
		end
	end
	-- one choice not targetting override
	local count = #filteredChoices
	if count == 1 and (not CurrentLevel.isBoss() or not player.playableCharacter) then
		return filteredChoices[1]
	end
	if count ~= 0 or CurrentLevel.isBoss() then
		local blockedCache = Data.NodeCache:new()
		while true do
			local target = Targeting.getTarget(player)
			if target then
				targetExit = target.tag == "exit"
				local nextDirection = goTowards(player, target, filteredChoices, blockedCache)
				if nextDirection then
					if player.confusable and player.confusable.remainingTurns > 0 then
						return Action.rotateDirection(nextDirection, Action.Rotation.MIRROR)
					end
					return nextDirection
				else
					-- TODO for targets that are unreachable five turns in a row ignore for a while
					target.unreachable = true
				end
			else
				break
			end
		end
	end
	if not player.playableCharacter then
		return Action.Special.ITEM_2
	end
	if not CurrentLevel.isBoss() then
		if actionItem then
			if ItemChoices.isPanicItem(actionItem) then
				return Action.Special.ITEM_1
			end
		end
		if not Map.hasComponent(playerX, playerY, "explosive") then
			return Action.Special.BOMB
		end
		return Direction.LEFT
	else
		--local Damage = require "necro.game.system.Damage"
		--Damage.inflict({victim=player, damage=999})
		return Direction.UP
	end
end

local function isTargetExit()
	return targetExit
end

event.objectCheckAbility.add("automate", {order = "ignoreRhythm", sequence = 5}, function (ev)
	if ev.client then
		local playerID = ev.entity.controllable.playerID
		if playerID == 0 or isSliding(ev.entity) then return end
		Targeting.scanForTargets(ev.entity, false)
		if ev.action == 0 then
			ev.action = getNextDirection(ev.entity)
		end
	end
end)

return {
	isTargetExit=isTargetExit
}