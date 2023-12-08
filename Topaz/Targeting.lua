local Action = require "necro.game.system.Action"
local AffectorItem = require "necro.game.item.AffectorItem"
local Attack = require "necro.game.character.Attack"
local Direction = Action.Direction
local Character = require "necro.game.character.Character"
local CommonEnemy = require "necro.game.data.enemy.CommonEnemy"
local CurrentLevel = require "necro.game.level.CurrentLevel"
local Entities = require "system.game.Entities"
local LowPercent = require "necro.game.item.LowPercent"
local Map = require "necro.game.object.Map"
local Marker = require "necro.game.tile.Marker"
local Segment = require "necro.game.tile.Segment"
local Snapshot = require "necro.game.system.Snapshot"
local Tile = require "necro.game.tile.Tile"
local Utilities = require "system.utils.Utilities"
local Vision = require "necro.game.vision.Vision"

local Data = require("Topaz.Data")
local ItemChoices = require("Topaz.ItemChoices")
local Pathfinding = require("Topaz.Pathfinding")
local Safety = require("Topaz.Safety")
local TopazSettings = require("Topaz.TopazSettings")
local Utils = require("Topaz.Utils")

local LuteScript = require("Topaz.ScriptedBosses.GoldenLute")
local CoralRiffScript = require("Topaz.ScriptedBosses.CoralRiff")
local DeathMetalScript = require("Topaz.ScriptedBosses.DeathMetal")
local FortissimoleScript = require("Topaz.ScriptedBosses.Fortissimole")

-- TODO use a data structure to sort by priority
targets = Snapshot.levelVariable({})
shopped = Snapshot.levelVariable(false)
gotChest = Snapshot.levelVariable(false)

local PRIORITY_LOOT_MONSTER_DEFAULT = 5

-- TODO give excessively high prio to weapons when one is not held
local function makePriorityTable()
	return {
		OVERRIDE = 99,
		MONSTER = TopazSettings.lootMonsterRelations() == TopazSettings.LOOT_MONSTER_RELATIONS_TYPE.LOOT_LOW and PRIORITY_LOOT_MONSTER_DEFAULT + 1 or PRIORITY_LOOT_MONSTER_DEFAULT,
		LOOT = LowPercent.isEnforced() and -1 or TopazSettings.lootMonsterRelations() == TopazSettings.LOOT_MONSTER_RELATIONS_TYPE.LOOT_HIGH and PRIORITY_LOOT_MONSTER_DEFAULT + 1 or PRIORITY_LOOT_MONSTER_DEFAULT,
		EXIT = TopazSettings.exitASAP() and 10 or 4,
		EXPLORE_NEAR_FLOOR = 3,
		EXPLORE_NEAR_WALL = 2,
		WALL = 1
	}
end

local visibilityCache = Data.NodeCache:new()
event.runStateInit.add("resetVisibilityCache", {order="seenItems"}, function()
	visibilityCache.levelNumber = -4
end)

local PRIORITY = makePriorityTable()
event.taggedSettingChanged.add("updatePriorityTable", {filter="topazPriority"}, function()
	PRIORITY = makePriorityTable()
end)

local SCAN_HEIGHT_RADIUS = 50
local SCAN_WIDTH_RADIUS = 50

local function getTargetCoords(target)
	local entity = target.entityID and Entities.getEntityByID(target.entityID) or {position={x=target.x, y=target.y}}
	return entity.position.x, entity.position.y
end

local function hasExit(x, y, player)
	local tileInfo = Tile.getInfo(x, y)
	if tileInfo.descent then return true end
	for _, trapdoor in Map.entitiesWithComponent(x, y, "trap") do
		if not (player.grooveChainDropOnDescent and player.grooveChainInflictDamageOnDrop and trapdoor.trapDescend and (not trapdoor.trapDescend.type or trapdoor.trapDescend.type ~= 4) ) and trapdoor.trapDescend then
			if player.descent and Attack.isAttackable(trapdoor, player, trapdoor.trap.targetFlags) then
				return true
			end
		end
	end
	return false
end

local function hasGold(x, y, player)
	if AffectorItem.entityHasItem(player, "itemAutoCollectCurrencyOnMove") then
		return false
	end
	if player.goldHater then return false end
	if hasExit(x, y, player) then return false end
	-- FIXME bandaid fix for lagging on unreachable gold
	if Safety.hasPathBlocker(x, y, player) then return false end
	if Map.firstWithComponent(x, y, "itemCurrency") then return true end
	local tileInfo = Tile.getInfo(x, y)
	if tileInfo.digEntity == "ResourceHoardGoldSmall" then
		return true
	end
	return false
end

local function hasShopped()
	return shopped
end

local function seenChest()
	return gotChest
end

local function isReadyToExit()
	-- TODO secret shops, level crates, locked shops, shrines, potion rooms
	return hasShopped() and seenChest() or CurrentLevel.isBoss() or LowPercent.isEnforced() or TopazSettings.exitASAP()
end

local function isSpaceVisible(x, y)
	if visibilityCache:getNode(x, y) then
		return true
	else
		if Vision.isVisible(x, y) then
			visibilityCache:insertNode(x, y, true)
			return true
		end
	end
	return false
end

-- TODO get hash of current pos and only apply strats with a higher prio value
local function scanSpaceForTargets(x, y, player)
	-- TODO use map, walltorch, glasstorch, telepathy, monocle
	if Vision.isVisible(x, y) then
		visibilityCache:insertNode(x, y, true)
		local tileInfo = Tile.getInfo(x, y)
		local digable, rising = Utils.canDig(player, x, y)
		if digable and not rising and not tileInfo.isFloor then
			table.insert(targets, {x=x,y=y,wall=true,priority=PRIORITY.WALL})
		elseif not hasShopped() and (tileInfo.name == "ShopWall" or tileInfo.name == "DarkShopWall") and Segment.contains(Segment.MAIN, x, y) then
			local shopX, shopY = Marker.lookUpMedian(Marker.Type.SHOP)
			-- TODO stop upon seeing shop items instead of standing in shop
			if player.position.x == shopX and player.position.y == shopY + 1 then
				shopped = true
			else
				-- TODO follow shop wall instead of targeting marker when not visible
				table.insert(targets, {x=shopX, y=shopY+1, shop=true, priority=PRIORITY.LOOT})
			end
		elseif not hasShopped() and (tileInfo.name == "ShopWallCracked" or tileInfo.name == "DarkShopWallCracked") then
			shopped = true
		elseif hasExit(x, y, player) then
			table.insert(targets, {x=x,y=y,exit=true,priority=PRIORITY.EXIT})
		end
		if hasGold(x, y, player) then
			table.insert(targets, {x=x,y=y,gold=true,priority=PRIORITY.LOOT })
		end
		for _, monster in Utils.iterateMonsters(x, y, player, false) do
			-- TODO properly pathfind to these
			-- TODO target spaces 2 from standing armadillos
			if (Pathfinding.hasDiagonal(player) or monster.name ~= "Spider" and monster.name ~= "Slime3" and monster.name ~= "Mole")
					and monster.name ~= "Clone" then
				if not monster.playableCharacter then
					if not (monster.controllable and monster.controllable.playerID ~= 0) then
						local chests = {
							Trapchest=true,
							Trapchest2=true,
							Trapchest3=true,
						}
						if chests[monster.name] then
							gotChest = true
						end
						table.insert(targets, { entityID=monster.id, priority=PRIORITY.MONSTER})
					end
				end
			end
		end
		for _, chest in Map.entitiesWithComponent(x, y, "chestLike") do
			if not chest.sale or chest.sale.priceTag == 0 then
				gotChest = true
			end
			if ItemChoices.canPurchase(chest, player) then
				table.insert(targets, { entityID=chest.id, item=true, priority=PRIORITY.LOOT})
			end
		end
		for _, item in ipairs(ItemChoices.getTargetItems(x, y, player)) do
			table.insert(targets, { entityID=item.id, item=true, priority=PRIORITY.LOOT})
		end
	elseif not TopazSettings.useOldExploreMethod() and not isSpaceVisible(x, y) and not CurrentLevel.isBoss() then
		local floor = false
		local wall = false
		for dx = -1, 1 do
			for dy = -1, 1 do
				if isSpaceVisible(x + dx, y + dy) then
					local tileInfo = Tile.getInfo(x, y)
					if tileInfo.isFloor then
						floor = true
						break
					else
						wall = true
					end
				end
			end
			if floor then
				break
			end
		end
		local create = floor or wall
		if create then
			local priority = PRIORITY.EXPLORE_NEAR_WALL
			if floor then
				priority = PRIORITY.EXPLORE_NEAR_FLOOR
			end
			table.insert(targets, {x=x, y=y, explore=true, priority=priority})
		end
	end
end

local function checkIfTargetDead(target, player)
	if target.override then return true end
	if target.entityID then
		local monster = Entities.getEntityByID(target.entityID)
		if not monster then
			return true
		end
		if not Character.isAlive(monster) then
			return true
		end
		if monster.controllable and monster.controllable.playerID ~= 0 then
			return true
		end
		if target.item and not ItemChoices.shouldTake(monster, player) then
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
	if target.shop then
		if hasShopped() then return true end
	end
	if target.explore then
		local x, y = getTargetCoords(target)
		if isSpaceVisible(x, y) then
			return true
		end
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
	-- TODO ensure proper script per player items is followed
	DeathMetalScript.deathMetalOverride(player, targets)
	FortissimoleScript.fortissimoleOverride(player, targets)
	LuteScript.luteOverride(player, targets)
	CoralRiffScript.coralRiffOverride(player, targets)
end

local function scanForTargets(player, cowardStrats)
	cleanDeadTargets(player)
	local playerX, playerY = player.position.x, player.position.y
	local scanWidth = SCAN_WIDTH_RADIUS
	local scanHeight = SCAN_HEIGHT_RADIUS
	if cowardStrats and not CurrentLevel.isBoss() then
		playerX, playerY = 0, 0
		scanWidth = 2
		scanHeight = 2
	end
	for dx = -scanWidth, scanWidth do
		for dy = -scanHeight, scanHeight do
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
			table.insert(targets, {x=0, y=playerY - 1, override=true, priority=PRIORITY.WALL})
		end
	elseif cowardStrats then
		table.insert(targets, {x=0, y=0, override=true, priority=PRIORITY.WALL})
	end
	targetingOverride(player)
end

local function getTarget(player)
	local selected
	local selectedPriority
	local ready = isReadyToExit()
	for _, next in ipairs(targets) do
		-- TODO target filtering method (hasPathBlocker gold and standing armdillos, as well as this not exit if not ready code)
		if not next.unreachable and (not next.exit or ready) then
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
	PRIORITY=PRIORITY,
	hasShopped=hasShopped,
	seenChest=seenChest
}