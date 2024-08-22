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

local TablePool = require("Topaz.libs.TablePool")

local LuteScript = require("Topaz.ScriptedBosses.GoldenLute")
local CoralRiffScript = require("Topaz.ScriptedBosses.CoralRiff")
local DeathMetalScript = require("Topaz.ScriptedBosses.DeathMetal")
local FortissimoleScript = require("Topaz.ScriptedBosses.Fortissimole")

-- TODO use a data structure to sort by priority
targets = TablePool.fetch(40, 0)
shopped = Snapshot.levelVariable(false)
gotChest = Snapshot.levelVariable(false)
lastSeenShrine = Snapshot.runVariable(0)

local clearTargetsArgs = TablePool.fetch(0, 1)
clearTargetsArgs.order = "spawnPlayers"
event.levelLoad.add("clearTargets", clearTargetsArgs, function()
	Utils.tableClear(targets)
end)

local Targeting = TablePool.fetch(0, 14)

local FARM_AMOUNT = TopazSettings.FARM_AMOUNT

local switchExitPriority = TablePool.fetch(0, 7)
switchExitPriority[FARM_AMOUNT.THE_NUCLEAR_OPTION] = "WALL"
switchExitPriority[FARM_AMOUNT.VERY_FULL_CLEAR] = "EXPLORE_NEAR_WALL"
switchExitPriority[FARM_AMOUNT.FULL_CLEAR] = "EXPLORE_NEAR_FLOOR"
switchExitPriority[FARM_AMOUNT.ALL_LOOT] = "LOOT"
switchExitPriority[FARM_AMOUNT.ALL_ITEMS_SEARCH] = "LOOT"
switchExitPriority[FARM_AMOUNT.ALL_ITEMS] = "LOOT"
switchExitPriority[FARM_AMOUNT.SOME_ITEMS] = "OVERRIDE"
switchExitPriority[FARM_AMOUNT.IGNORE_LOOT] = "OVERRIDE"

local PRIORITY_LOOT_MONSTER_DEFAULT = 5
-- TODO give excessively high prio to weapons when one is not held
function Targeting.makePriorityTable()
	local priorityTable = TablePool.fetch(0, 9)
	priorityTable.OVERRIDE = 99
	priorityTable.MONSTER_CHASING_LOW_PERCENT = PRIORITY_LOOT_MONSTER_DEFAULT + 10
	priorityTable.LOW_PERCENT_COMBAT_STRATS = priorityTable.MONSTER_CHASING_LOW_PERCENT + 1
	priorityTable.MONSTER = TopazSettings.lootMonsterRelations() == TopazSettings.LOOT_MONSTER_RELATIONS_TYPE.LOOT_LOW and PRIORITY_LOOT_MONSTER_DEFAULT + 1 or PRIORITY_LOOT_MONSTER_DEFAULT
	priorityTable.LOOT = LowPercent.isEnforced() and -1 or TopazSettings.lootMonsterRelations() == TopazSettings.LOOT_MONSTER_RELATIONS_TYPE.LOOT_HIGH and PRIORITY_LOOT_MONSTER_DEFAULT + 1 or PRIORITY_LOOT_MONSTER_DEFAULT
	priorityTable.GOLD = priorityTable.LOOT
	priorityTable.LOW_PERCENT_EXPLORE_STRATS = 4
	priorityTable.EXPLORE_NEAR_FLOOR = 3
	priorityTable.EXPLORE_NEAR_WALL = 2
	priorityTable.WALL = 1
	local farmAmount = TopazSettings.farmAmount() or TopazSettings.defaultFarmAmount()
	priorityTable.EXIT = LowPercent.isEnforced() and priorityTable.MONSTER_CHASING_LOW_PERCENT or priorityTable[switchExitPriority[farmAmount]] - 0.5
	return priorityTable
end

Targeting.PRIORITY = Targeting.makePriorityTable()
local updatePriorityTableArgs = TablePool.fetch(0, 1)
updatePriorityTableArgs.filter = "topazPriority"
event.taggedSettingChanged.add("updatePriorityTable", updatePriorityTableArgs, function()
	Targeting.PRIORITY = Targeting.makePriorityTable()
end)

event.levelLoad.add("updatePriorityTable", {order = "training", sequence = 10}, function()
	Targeting.PRIORITY = Targeting.makePriorityTable()
end)

local visibilityCache = Data.NodeCache:new()
local wireCache = Data.NodeCache:new()
local resetVisibilityCacheArgs = TablePool.fetch(0, 1)
resetVisibilityCacheArgs.order = "seenItems"
event.runStateInit.add("resetVisibilityCache", resetVisibilityCacheArgs, function()
	visibilityCache.levelNumber = -4
	wireCache.levelNumber = -4
end)

local SCAN_HEIGHT_RADIUS = 50
local SCAN_WIDTH_RADIUS = 50

function Targeting.getTargetCoords(target)
	local entity = target.entityID and Entities.getEntityByID(target.entityID)
	if not entity then
		entity = TablePool.fetch(0, 1)
		local position = TablePool.fetch(0, 2)
		position.x, position.y = target.x, target.y
		entity.position = position
	end
	return entity.position.x, entity.position.y
end

function Targeting.hasExit(x, y, player)
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

function Targeting.hasGold(x, y, player)
	if AffectorItem.entityHasItem(player, "itemAutoCollectCurrencyOnMove") then
		return false
	end
	if TopazSettings.farmAmount() >= FARM_AMOUNT.ALL_ITEMS_SEARCH or player.goldCounter.amount >= TopazSettings.goldReserves() then
		return false
	end
	if player.goldHater then return false end
	if Targeting.hasExit(x, y, player) then return false end
	-- FIXME bandaid fix for lagging on unreachable gold
	if Safety.hasPathBlocker(x, y, player) then return false end
	if Map.hasComponent(x, y, "itemCurrency") then return true end
	if Map.hasComponent(x, y, "Sync_trapDice") then return true end
	local tileInfo = Tile.getInfo(x, y)
	if tileInfo.digEntity == "ResourceHoardGoldSmall" then
		return true
	end
	return false
end

function Targeting.hasShopped()
	return shopped
end

function Targeting.seenChest()
	return gotChest
end

function Targeting.seenShrine()
	return CurrentLevel.getDepth() == lastSeenShrine
end

function Targeting.hasTargetWithProperty(property, value)
	for _, target in ipairs(targets) do
		if target[property] == value then
			return true
		end
	end
	return false
end

function Targeting.isReadyToExit()
	-- TODO secret shops, level crates, locked shops, shrines, potion rooms
	local shopped = Targeting.hasShopped()
	local gotChest = Targeting.seenChest()
	local shrine = Targeting.seenShrine() or CurrentLevel.getDepth() == 1 and CurrentLevel.getFloor() == 1
	local ignoreShrine = TopazSettings.farmAmount () <= FARM_AMOUNT.ALL_ITEMS_SEARCH
	local explored = not Targeting.hasTargetWithProperty("priority", Targeting.PRIORITY.EXPLORE_NEAR_FLOOR)
	local boss = CurrentLevel.isBoss()
	local low = LowPercent.isEnforced()
	local forcedExit = TopazSettings.farmAmount() >= FARM_AMOUNT.SOME_ITEMS
	return (shopped and gotChest and (shrine or explored or ignoreShrine)) or boss or low or forcedExit
end

function Targeting.isSpaceVisible(x, y)
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

local TAGGED_PRIORITY = {
	wall = Targeting.PRIORITY.WALL,
	shop = Targeting.PRIORITY.LOOT,
	gold = Targeting.PRIORITY.GOLD,
	item = Targeting.PRIORITY.LOOT,
	monster = Targeting.PRIORITY.MONSTER,
	override = Targeting.PRIORITY.OVERRIDE,
	exit = Targeting.PRIORITY.EXIT,
}

function Targeting.determinePriority(tag)
	return TAGGED_PRIORITY[tag]
end

function Targeting.addTarget(x, y, tag, priority, entityID, overrideAction)
	local target = TablePool.fetch(0, 4)
	target.x = x
	target.y = y
	if priority == nil then
		priority = Targeting.determinePriority(tag)
	elseif type(priority) == "string" then
		priority = Targeting.PRIORITY[priority]
	end
	target.priority = priority
	target.tag = tag
	target.entityID = entityID
	target.overrideAction = overrideAction
	table.insert(targets, target)
end

-- TODO get hash of current pos and only apply strats with a higher prio value
function Targeting.scanSpaceForTargets(x, y, player)
	-- TODO use map, walltorch, glasstorch, telepathy, monocle, compass
	if Vision.isVisible(x, y) then
		visibilityCache:insertNode(x, y, true)
		local tileInfo = Tile.getInfo(x, y)
		if tileInfo.wire then
			wireCache:insertNode(x, y, true)
		end
		local digable, rising = Utils.canDig(player, x, y)
		if digable and not rising and not tileInfo.isFloor then
			Targeting.addTarget(x, y, "wall")
		elseif not LowPercent.isEnforced() and TopazSettings.farmAmount() ~= FARM_AMOUNT.IGNORE_LOOT and not Targeting.hasShopped() and (tileInfo.name == "ShopWall" or tileInfo.name == "DarkShopWall") and Segment.contains(Segment.MAIN, x, y) then
			local shopX, shopY = Marker.lookUpMedian(Marker.Type.SHOP)
			-- TODO stop upon seeing shop items instead of standing in shop
			if player.position.x == shopX and player.position.y == shopY + 1 then
				shopped = true
			else
				-- TODO follow shop wall instead of targeting marker when not visible
				Targeting.addTarget(shopX, shopY + 1, "shop")
			end
		elseif not Targeting.hasShopped() and (tileInfo.name == "ShopWallCracked" or tileInfo.name == "DarkShopWallCracked") then
			shopped = true
		elseif Targeting.hasExit(x, y, player) then
			Targeting.addTarget(x, y, "exit")
		end
		if not LowPercent.isEnforced() and Targeting.hasGold(x, y, player) then
			Targeting.addTarget(x, y, "gold")
		end
		local lowPercentCombat = false
		for _, monster in Utils.iterateMonsters(x, y, player, false) do
			-- TODO properly pathfind to these
			-- TODO target spaces 2 from standing armadillos, 3 from 2 hp beholders
			-- TODO avoid spiders on walls you cannot dig or that have no movement options on non diag chars
			if (Pathfinding.hasDiagonal(player) or monster.name ~= "Spider" and monster.name ~= "Slime3" and monster.name ~= "Mole")
					and monster.name ~= "Clone" then
				if not monster.playableCharacter then
					if not (monster.controllable and monster.controllable.playerID ~= 0) then
						local chests = TablePool.fetch(0, 3)
						chests.Trapchest=true
						chests.Trapchest2=true
						chests.Trapchest3=true
						if chests[monster.name] then
							gotChest = true
						end
						TablePool.release(chests)
						local priority
						if LowPercent.isEnforced() and Utils.isChasingMonster(monster) then
							priority = "MONSTER_CHASING_LOW_PERCENT"
							lowPercentCombat = true
						end
						if monster.amplifiedMovement and monster.health.health < 1 and monster.actionDelay.currentAction == 0 and
								not Utils.distanceL1(player.position.x - monster.position.x, player.position.y - monster.position.y) == 1
						then
							local distance = 3
							-- TODO walls blocking evil eye
							Targeting.addTarget(monster.position.x + distance, monster.position.y, "monster", priority)
							Targeting.addTarget(monster.position.x - distance, monster.position.y, "monster", priority)
							Targeting.addTarget(monster.position.x, monster.position.y + distance, "monster", priority)
							Targeting.addTarget(monster.position.x, monster.position.y - distance, "monster", priority)
						else
							Targeting.addTarget(nil, nil, "monster", priority, monster.id)
						end
					end
				end
			end
		end
		if lowPercentCombat then
			if CurrentLevel.getZone() == 5 then
				if player.wired.level < 1 then
					for key, node in pairs(wireCache.hashMap) do
						if node == true then
							local x, y = key:match("([^_]+)_([^_]+)")

							x = tonumber(x)
							y = tonumber(y)

							Targeting.addTarget(x, y, "override", "LOW_PERCENT_COMBAT_STRATS")
						end
					end
				end
			end
		end
		if not LowPercent.isEnforced() then
			local farmAmount = TopazSettings.farmAmount()
			if farmAmount <= FARM_AMOUNT.ALL_ITEMS_SEARCH then
				for _, shrine in Map.entitiesWithComponent(x, y, "shrine") do
					lastSeenShrine = CurrentLevel.getDepth()
				end
			end
			if farmAmount ~= FARM_AMOUNT.IGNORE_LOOT then
				for _, chest in Map.entitiesWithComponent(x, y, "chestLike") do
					if not chest.sale or chest.sale.priceTag == 0 then
						gotChest = true
					end
					if ItemChoices.canPurchase(chest, player) then
						Targeting.addTarget(nil, nil, "item", nil, chest.id)
					end
				end
				for _, item in ipairs(ItemChoices.getTargetItems(x, y, player)) do
					Targeting.addTarget(nil, nil, "item", nil, item.id)
				end
			end
		end
	elseif not TopazSettings.useOldExploreMethod() and not Targeting.isSpaceVisible(x, y) and not CurrentLevel.isBoss() then
		local floor = false
		local wall = false
		local lowStrats = false
		for dx = -1, 1 do
			for dy = -1, 1 do
				if Targeting.isSpaceVisible(x + dx, y + dy) then
					local tileInfo = Tile.getInfo(x, y)
					if LowPercent.isEnforced() then
						if CurrentLevel.getZone() == 5 then
							if tileInfo.wire and (dx == 0 or dy == 0) then
								lowStrats = true
								break
							end
						end
					end
					if tileInfo.isFloor then
						floor = true
						if not LowPercent.isEnforced() then
							break
						end
					else
						if Utils.canDig(player, x + dx, y + dy) then
							wall = true
						end
					end
				end
			end
			if floor then
				break
			end
		end
		local create = floor or wall
		if create then
			local priority = Targeting.PRIORITY.EXPLORE_NEAR_WALL
			if floor then
				priority = Targeting.PRIORITY.EXPLORE_NEAR_FLOOR
			end
			if lowStrats then
				priority = Targeting.PRIORITY.LOW_PERCENT_EXPLORE_STRATS
			end
			Targeting.addTarget(x, y, "explore", priority)
		end
	end
end

function Targeting.checkIfTargetDead(target, player)
	-- TODO use functional switch case
	if target.tag == "override" then return true end
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
		if target.tag == "item" and not ItemChoices.shouldTake(monster, player) then
			return true
		end
	end
	if target.tag == "gold" then
		local x, y = Targeting.getTargetCoords(target)
		if not Targeting.hasGold(x, y, player) then return true end
	end
	if target.tag == "exit" then
		local x, y = Targeting.getTargetCoords(target)
		if not Targeting.hasExit(x, y, player) then return true end
	end
	if target.tag == "wall" then
		local x, y = Targeting.getTargetCoords(target)
		if not Utils.canDig(player, x, y) then
			return true
		end
		local tileInfo = Tile.getInfo(x, y)
		if tileInfo.isFloor then return true end
		if tileInfo.digType == "MetalDoorOpen" then return true end
	end
	if target.tag == "shop" then
		if Targeting.hasShopped() then return true end
	end
	if target.tag == "explore" then
		local x, y = Targeting.getTargetCoords(target)
		if Targeting.isSpaceVisible(x, y) then
			return true
		end
	end
	return false
end

function Targeting.cleanDeadTargets(player)
	local i = #targets
	local hashes = TablePool.fetch(i, 0)
	while i > 0 do
		local target = targets[i]
		local x, y = Targeting.getTargetCoords(target)
		local hash
		if x and y then
			hash = x .. "_" .. y .. "_" .. (target.tag or "none")
		end
		if not hash or hashes[hash] or Targeting.checkIfTargetDead(target, player) then
			table.remove(targets, i)
		else
			target.unreachable = nil
			hashes[hash] = true
		end
		i = i - 1
	end
	TablePool.release(hashes)
end

function Targeting.targetingOverride(player)
	--[[
		TODO KC
		kill extras then zombies
	--]]
	-- TODO ensure proper script per player items is followed
	DeathMetalScript.deathMetalOverride(player, targets)
	-- TODO Fix FM script
	-- FortissimoleScript.fortissimoleOverride(player)
	LuteScript.luteOverride(player)
	CoralRiffScript.coralRiffOverride(player)
end

function Targeting.scanForTargets(player, cowardStrats)
	Targeting.cleanDeadTargets(player)
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
			Targeting.scanSpaceForTargets(playerX + dx, playerY + dy, player)
		end
	end
	if CurrentLevel.isBoss() then
		local has = false
		local args = TablePool.fetch(1, 0)
		args[1] = "boss"
		for _ in Entities.entitiesWithComponents(args) do
			has = true
			break
		end
		if not has then
			Targeting.addTarget(0, playerY-1, "override", "WALL")
		end
	elseif cowardStrats then
		Targeting.addTarget(0, 0, "override", "WALL")
	end
	Targeting.targetingOverride(player)
end

function Targeting.getTarget(player)
	local selected
	local selectedPriority
	local ready = Targeting.isReadyToExit()
	for _, next in ipairs(targets) do
		-- TODO target filtering method (hasPathBlocker gold and standing armdillos, as well as this not exit if not ready code)
		if not next.unreachable and (next.tag ~= "exit" or ready) then
			selectedPriority = selected and selected.priority or 0
			local nextPriority = next.priority
			if next.priority then
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
	end
	return selected
end

return Targeting