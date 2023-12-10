local Action = require "necro.game.system.Action"
local AffectorItem = require "necro.game.item.AffectorItem"
local AI = require "necro.game.enemy.ai.AI"
local CurrentLevel = require "necro.game.level.CurrentLevel"
local Damage = require "necro.game.system.Damage"
local Direction = Action.Direction
local Entities = require "system.game.Entities"
local LowPercent = require "necro.game.item.LowPercent"
local Map = require "necro.game.object.Map"
local SizeModifier = require "necro.game.character.SizeModifier"
local Snapshot = require "necro.game.system.Snapshot"
local Tile = require "necro.game.tile.Tile"
local Utilities = require "system.utils.Utilities"

local Topaz = require("Topaz.Topaz")
local Pathfinding = require("Topaz.Pathfinding")
local ItemChoices = require("Topaz.ItemChoices")
local Targeting = require("Topaz.Targeting")
local Utils = require("Topaz.Utils")

local TablePool = require("Topaz.libs.TablePool")

local Safety = TablePool.fetch(0, 19)

function Safety.canHurt(monster, player, entityToPlayerDirection)
	-- TODO crates, blood shoppies, elec zombies on wire with snag behind them
	if not Utils.canEverHurt(monster, player) then return false end
	if monster.captiveAudience and monster.captiveAudience.active then
		return false
	end
	if monster.stasis and monster.stasis.active and monster.stasisAttackableFlags and monster.stasisAttackableFlags.remove then
		return false
	end
	if monster.parryCounterAttack and monster.parryCounterAttack.active then
		return false
	end
	if SizeModifier.isTiny(player) then
		return false
	end
	local inventory = player.inventory
	if inventory then
		local weaponEntityID = inventory.itemSlots.weapon and inventory.itemSlots.weapon[1]
		local weapon = Entities.getEntityByID(weaponEntityID)
		if (not weapon or weapon.name == "WeaponGoldenLute") and not player.innateAttack then return false end
	end
	if monster.shield and monster.shield.active then
		local direction = monster.shieldDirection and monster.shieldDirection.direction
		if not direction or (entityToPlayerDirection and (direction == entityToPlayerDirection)) then
			if monster.shieldBreakOnHit and monster.shieldBreakOnHit.minimumDamage then
				local requiredDamage = monster.shieldBreakOnHit.minimumDamage
				if requiredDamage == -1 and not Utils.stringStartsWith(monster.name, "Lute") and not Utils.stringStartsWith(monster.name, "Devil") then
					return false
				else
					local damage = Damage.getBaseDamage(player)
					if requiredDamage > damage then return false end
				end
			else
				local name = monster.name
				if not Utils.stringStartsWith(name, "Coralriff") and name ~= "LuteDragon" then
					return false
				end
			end
		end
	end
	local tileInfo = Tile.getInfo(monster.position.x, monster.position.y)
	if not tileInfo.isFloor and monster.name ~= "Spider" then return false end
	return true
end

function Safety.canHurtWithoutRetaliation(monster, player, entityToPlayerDirection)
	-- TODO enemies in water, exploding mushroom, warlocks
	if not Safety.canHurt(monster, player, entityToPlayerDirection) then return false end
	local inventory = player.inventory
	if inventory then
		local weaponEntityID = inventory.itemSlots.weapon and inventory.itemSlots.weapon[1]
		local weapon = Entities.getEntityByID(weaponEntityID)
		if weapon and weapon.itemFreezeOnAttack then return true end
	end
	if monster.kingCongaTeleport or monster.deepBluesTeleport or monster.metrognomeTeleportOnHit then
		return true
	end
	if monster.name == "LuteHead" then return true end
	-- TODO shield kb
 	if monster.knockbackable and monster.knockbackable.minimumDistance and monster.knockbackable.minimumDistance > 0 then return true end
	if monster.castOnHit then
		local spell = monster.castOnHit.spell
		if Utils.stringStartsWith(spell, "SpellcastTeleport") then
			return true
		end
	end
	local hp = monster.health.health
	if monster.lowHealthConvert then
		hp = hp - 1
	end
	if hp <= Damage.getBaseDamage(player) then
		if monster.swapEntitiesOnDeath then
			-- TODO warlocks
		end
		return true
	end
	if AffectorItem.entityHasItem(monster, "weaponShove") then
		local playerX, playerY, newX, newY = Utils.positionInDirection(player, entityToPlayerDirection)
		if not Pathfinding.hasSnag(player, newX, newY) then
			if Safety.isValidSpace(newX, newY, playerX, playerY, player) then
				return true
			end
		end
	end
	return false
end

function Safety.monsterHasLifeSave(monster)
	if monster.name == "Ghast" or monster.name == "Ghoul" then
		if monster.shield.active then
			return true
		end
	end
	return false
end

function Safety.canKill(monster, player)
	local hp = monster.health.health
	return
		hp <= Damage.getBaseDamage(player)
				and not Safety.monsterHasLifeSave(monster)
				and Safety.canHurt(monster, player, Action.getDirection(monster.position.x - player.position.x, monster.position.y - player.position.y))
end

function Safety.hasCourage(player, targetX, targetY)
	if AffectorItem.entityHasItem(player, "Sync_itemPossessOnKill") or AffectorItem.entityHasItem(player, "itemDashOnKill") then
		for _, monster in Utils.iterateMonsters(targetX, targetY, player, false) do
			if Safety.canKill(monster, player) then
				return true
			end
		end
	end
	return false
end

function Safety.checkForTraps(x, y, player)
		for _, entity in Map.entitiesWithComponent(x, y, "trap") do
			if not (Utils.unableToBeHurtByTraps(player)) then
				-- TODO automatic spike trap
				if entity.trapInflictDamage then return true end
				if entity.trapScatterInventory then return true end
				if player.grooveChainDropOnDescent and player.grooveChainInflictDamageOnDrop and entity.trapDescend and (not entity.trapDescend.type or entity.trapDescend.type ~= 4) then return true end
			end
			-- TODO let player walk into secret shops later
			if entity.trapTravel then return true end
			-- TODO ban dice traps on low%
		end
	return false
end

function Safety.aiAllowsMovement(monster)
	if monster.actionDelay and monster.actionDelay.currentAction ~= 0 then
		local type = monster.name
		if type == "Dragon2" or type == "Dragon3" or type == "DeathmetalPhase4" or type == "LuteHead" then
			return false
		end
	end
	local ai = monster.ai
	if not ai then return false end
	if not ai.directions then return false end
	if ai.id == AI.Type.IDLE and not monster.charge and not monster.aiAttackWhenPossible and not monster.boss then return false end
	if monster.beatDelay and monster.beatDelay.counter > 0 then return false end
	if monster.stun and monster.stun.counter > 0 then return false end
	return true
end

function Safety.posesAdditionalThreat(monster, x, y, player)
	--TODO dead ringer, ogreclubs
	local allowedToMove = Safety.aiAllowsMovement(monster)
	local monsterX, monsterY = monster.position.x, monster.position.y
	if monster.remappedMovement then
		local allDirections = {Direction.RIGHT, Direction.UP_RIGHT, Direction.UP, Direction.UP_LEFT, Direction.LEFT, Direction.DOWN_LEFT, Direction.DOWN, Direction.DOWN_RIGHT}
		local actionFilter = monster.actionFilter
		if not actionFilter then return allDirections end
		local ignoreActions = actionFilter.ignoreActions
		Utilities.removeIf(allDirections, function(direction)
			return ignoreActions[direction]
		end)
		for _, direction in ipairs(allDirections) do
			local remap = monster.remappedMovement.map[direction]
			local dx, dy = remap[1], remap[2]
			if monsterX + dx == x and monsterY + dy == y then
				return true
			end
		end
	end
	local direction
	local distance
	if monster.parryCounterAttack then
		direction = monster.parryCounterAttack.direction
		distance = monster.parryCounterAttack.distance
	end
	if monster.amplifiedMovement and monster.actionDelay and monster.actionDelay.currentAction ~= 0 and monster.actionDelay.delay == 0 then
		direction = monster.facingDirection.direction
		distance = monster.amplifiedMovement.distance
	end
	if direction and distance then
		local dx, dy = Action.getMovementOffset(direction)
		local currentX, currentY = monsterX, monsterY
		for _ = 1, distance do
			currentX = currentX + dx
			currentY = currentY + dy
			if Pathfinding.hasSnag(monster, currentX, currentY) then
				break
			end
			if currentX == x and currentY == y then
				return true
			end
		end
	end
	if allowedToMove and monster.castOnMoveResult or monster.name == "Fortissimole" then
		local spell = monster.castOnMoveResult and monster.castOnMoveResult.spell
		if spell == "SpellcastSpores" or spell == "SpellcastSpores2" then
			if math.abs(monsterX - x) < 2 and math.abs(monsterY - y) < 2 then
				return true
			end
		end
		if spell == "SpellcastSplash" or spell == "SpellcastClap" or monster.name == "Fortissimole" then
			local dx = math.abs(monsterX - x)
			local dy = math.abs(monsterY - y)
			if dx < 3 and dy < 3 and not (dx == 2 and dy == 2) then
				return true
			end
		end
	end
	if monster.name == "LuteHead" then
		local body = Map.firstWithComponent(monsterX, monsterY - 1, "luteBody")
		if monsterY < -10 and not body.luteBody.forceUp and aiAllowsMovement(body) and monsterX == x and monsterY + 1 == y then
			return true
		end
	end
	if (monster.name == "Dragon2" or Utils.stringStartsWith(monster.name, "Firepig") or monster.name == "DeathmetalPhase4" or monster.name == "LuteHead") and monster.actionDelay and monster.actionDelay.currentAction ~= 0 and monster.actionDelay.delay == 0 then
		if monsterY == y then
			return true
		end
	end
	if monster.name == "Dragon3" then
		if math.abs(monsterX - x) <= 3 and math.abs(monsterY - y) < math.abs(monsterX - x) then
			return true
		end
	end
	if monster.name == "WandWind" then
		-- TODO check space with isValidSpace instead of always declaring invalid
		local dx = math.abs(monsterX - x)
		local dy = math.abs(monsterY - y)
		if (dx == 0 and dy == 2) or (dx == 2 and dy == 0) then
			return true
		end
	end
	return false
end

function Safety.hasAdditionalThreats(x, y, targetX, targetY, player)
	-- TODO courage for additional threats
	local threatComponents = {"castOnMoveResult", "actionDelay", "remappedMovement", "weaponCastOnAttack", "parryCounterAttack", "amplifiedMovement", "fortissimoleJump", "provokeOnProximity"}
	for _, component in ipairs(threatComponents) do
		for entity in Entities.entitiesWithComponents { component } do
			if not (entity.position.x == targetX and entity.position.y == targetY and (entity.parryCounterAttack or Safety.canHurtWithoutRetaliation(entity, player))) then
				if Safety.posesAdditionalThreat(entity, x, y, player) then
					return true
				end
			end
		end
	end
	return false
end

function Safety.protectedFrom(entity, player, targetX, targetY)
	if entity.name == "LuteHead" then
		if entity.luteHead.flee then
			return true
		end
	end
	if entity.name == "LuteBody" then
		if entity.luteBody.forceUp or Map.firstWithComponent(entity.position.x, entity.position.y, "luteHead") then
			return true
		end
	end
	if (entity.name == "Mole" or Utils.stringStartsWith(entity.name, "Tentacle")) and entity.stasis.active then
		return true
	end
	if entity.name == "SleepingGoblin" and entity.confusable.remainingTurns == 0 then
		return true
	end
	if entity.name == "Tarmonster" or entity.name == "ZombieSnake" or entity.name == "Trapchest3" or entity.name == "DeathmetalPhase2" or entity.name == "DeathmetalPhase3" or entity.name == "Leprechaun" or entity.name == "Pixie" then
		return true
	end
	if entity.name == "Ghost" then
		local entityX = entity.position.x
		local entityY = entity.position.y
		local adxp = math.abs(entityX - player.position.x)
		local adyp = math.abs(entityY - player.position.y)
		local adxt = math.abs(entityX - targetX)
		local adyt = math.abs(entityY - targetY)
		local startingDanger = (adxp == 0 and adyp == 1) or (adxp == 1 and adyp == 0)
		local endingDanger = (adxt == 0 and adyt == 1) or (adxt == 1 and adyt == 0)
		if not (startingDanger and (endingDanger or Pathfinding.hasSnag(player, targetX, targetY))) then
			return true
		end
		if not startingDanger and entity.stasis.active then return true end
	end
	return false
	-- TODO clones: okay yeah this one is hard
end

function Safety.canKillAccountingForGold(monster, player)
	if player.goldHater and Safety.canKill(monster, player) then
		local x, y = monster.position.x, monster.position.y
		if Targeting.hasExit(x, y, player) then
			return false
		end
		if not LowPercent.isEnforced() and #ItemChoices.getTargetItems(x, y, player) ~= 0 then
			return false
		end
		if Utils.isChasingMonster(monster.name) then
			dbg("init - ", monster.name)
			local blockerX, blockerY
			local alreadyBlocked
			local flag
			Utils.forEachPosition(x, y, 1, function(newX, newY)
				if Safety.hasPathBlocker(newX, newY, player, true) then
					if (newX ~= 0 or newY ~= 0) then
						if not blockerX then
							dbg("tripped blocker 1")
							blockerX, blockerY = newX, newY
						else
							dbg("tripped flag")
							flag = true
						end
					else
						alreadyBlocked = true
					end
				end
			end)
			if alreadyBlocked then dbg("already blocked") return true end
			if flag then dbg("flag 1 - near 2 blockers") return false end
			if blockerX then
				local flag2
				Utils.forEachPosition(blockerX, blockerY, 1, function(newX, newY)
					if (newX ~= 0 or newY ~= 0) and Safety.hasPathBlocker(newX, newY, player, true) then
						if not flag2 then
							dbg("tripped blocker 2")
							flag2 = 1
						else
							dbg("tripped flag 2")
							flag2 = 2
						end
					end
				end)
				if flag2 == 2 then dbg("flag 2 - 1 blocker near 2 blockers") return false end
			end
			dbg("passthrough")
		end
	end
	return true
end

function Safety.checkForAttackers(checkedX, checkedY, playerX, playerY, player, targetX, targetY)
	local dxp = playerX - checkedX
	local dyp = playerY - checkedY
	local badDirection = Action.getDirection(dxp, dyp)
	local dxt = targetX - checkedX
	local dyt = targetY - checkedY
	local attackMonster = dxt == 0 and dyt == 0
	for _, monster in Utils.iterateMonsters(checkedX, checkedY, player, true) do
		local safeAttack = attackMonster and Safety.canHurtWithoutRetaliation(monster, player, badDirection)
		local frozenMonster = not Safety.aiAllowsMovement(monster)
		local protection = Safety.protectedFrom(monster, player, targetX, targetY)
		if not (safeAttack or frozenMonster or protection) then
			local directions = Utils.getDirections(monster)
			for direction in pairs(directions) do
				if direction == badDirection then
					return true
				end
			end
			TablePool.release(directions)
		end
	end
	if Map.hasComponent(checkedX, checkedY, "trapMove") then
		for dx = -1, 1 do
			for dy =-1, 1 do
				local newX, newY = checkedX + dx, checkedY + dy
				if not (dx == 0 and dy == 0) then
					for _, entity in Utils.iterateMonsters(newX, newY, player, true) do
						local directions = Utils.getDirections(entity)
						if Safety.aiAllowsMovement(entity) and not Safety.protectedFrom(entity, player, targetX, targetY) and directions[Action.move(dx, dy)] then
							local threatX, threatY = Utils.positionAfterTrap(entity, checkedX, checkedY, {dx=dx, dy=dy})
							if threatX == playerX and threatY == playerY then
								return true
							end
						end
						TablePool.release(directions)
					end
				end
			end
		end
	end
	return false
end

function Safety.isDefensiveFromBombs(x, y, player)
	-- TODO blast helm, check bombs for if safe bombs (bomb charm/spell)
	for dx = -1, 1 do
		for dy = -1, 1 do
			local threshold = 1
			if dx == 0 and dy == 0 then
				threshold = 2
			end
			for _, entity in Map.entitiesWithComponent(x + dx, y + dy, "explosive") do
				if entity.name ~= "MushroomExploding" and entity.name ~= "Pixie" then
					local delay = entity.beatDelay
					if delay then
						local delayCount = delay.counter
						if delayCount < threshold then
							return false
						end
					end
				end
			end
		end
	end
	return true
end

function Safety.hasLiquid(x, y)
	local tileInfo = Tile.getInfo(x, y)
	return tileInfo.sink
end

function Safety.invulnerable(player)
	if not player.playableCharacter then
		--return true
	end
	if player.barrier and player.barrier.remainingTurns > 0 and player.barrier.maximumDamageTaken == 0 then
		return true
	end
	return false
end

function Safety.hasNearbyMonsters(radius, x, y, player)
	for dx = -radius, radius do
		for dy = -radius, radius do
			for _, monster in Utils.iterateMonsters(x + dx, y + dy, player, true) do
				if not ((math.abs(dx) > 2 or math.abs(dy) > 2) and (Utils.stringStartsWith(monster.name, "Mushroom") or Utils.stringStartsWith(monster.name, "Armadillo"))) then
					if not Utils.stringStartsWith(monster.name, "Slime") and monster.name ~= "MushroomLight" and not Utils.stringStartsWith(monster.name, "Cauldron") then
						return true
					end
				end
			end
		end
	end
	return false
end

function Safety.isDefensivePosition(playerX, playerY, targetX, targetY, player, startX, startY)
	-- TODO open exit stairs always defensive
	if Safety.invulnerable(player) then
		return true
	end
	local courage = Safety.hasCourage(player, targetX, targetY)
	-- TODO have to actually be able to kill a monster on the attacked tile
	if courage then return true end
	if not Safety.isDefensiveFromBombs(playerX, playerY) then return false end
	local snag = Pathfinding.hasSnag(player, targetX, targetY)
	if snag and Tile.getInfo(playerX, playerY).idleDamage and not Utils.firewalker(player) then
		return false
	end
	for dx = -1, 1 do
		for dy = -1, 1 do
			if Safety.checkForAttackers(playerX + dx, playerY + dy, playerX, playerY, player, targetX, targetY) then
				return false
			end
		end
	end
	if Safety.hasAdditionalThreats(playerX, playerY, targetX, targetY, player) then
		return false
	end
	return true
end

function Safety.hasInsurmountableObstacle(x, y, player, ignoreGold)
	if Map.hasComponent(x, y, "crateLike") then return true end
	if Map.hasComponent(x, y, "shopkeeper") then return true end
	if Map.hasComponent(x, y, "shrine") then return true end
	for _, item in Map.entitiesWithComponent(x, y, "item") do
		if not ItemChoices.canPurchase(item, player) then
			return true
		end
	end
	for _, item in Map.entitiesWithComponent(x, y, "chestLike") do
		if not ItemChoices.canPurchase(item, player) then
			return true
		end
	end
	if LowPercent.isEnforced() then
		if Map.hasComponent(x, y, "itemNegateLowPercent") then
			return true
		end
	end
	if not ignoreGold then
		for _, monster in Utils.iterateMonsters(x, y, player, false) do
			if not Safety.canKillAccountingForGold(monster, player) then
				return true
			end
		end
	end
	local ableToDig = Utils.canDig(player, x, y);
	if not ableToDig then return true end
	local targetExit = Topaz.isTargetExit()
	if Targeting.hasExit(x, y, player) and (not targetExit) and not Pathfinding.hasSnag(player, x, y) then return true end
	for _, monster in Utils.iterateMonsters(x, y, player, true) do
		if not Safety.canHurt(monster, player) then
			return true
		end
	end
	return false
end

function Safety.checkForArmadillos(x, y, player)
	for entity in Entities.entitiesWithComponents({"chargeRedirectOnHit"}) do
		if Utils.stringStartsWith(entity.name, "Armadillo") then
			if not entity.charge.active and entity.stun.counter == 0 then
				local dx, dy = math.abs(entity.position.x - x), math.abs(entity.position.y - y)
				if dx == 1 and dy == 0 or dx == 0 and dy == 1 then
					return true
				end
			end
		end
	end
end

function Safety.hasPathBlocker(x, y, player, ignoreGold)
	-- TODO return false if we have no idea what's on it
	local goldHater = player.goldHater
	if goldHater and Map.hasComponent(x, y, "itemCurrency") then return true end
	if Safety.checkForArmadillos(x, y, player) then return true end
	if Safety.checkForTraps(x, y, player) then return true end
	if Safety.hasInsurmountableObstacle(x, y, player, ignoreGold) then return true end
	local snag = Pathfinding.hasSnag(player, x, y)
	-- todo courage into floor hazards
	if not snag and Safety.hasLiquid(x, y) and not Utils.unsinkable(player) and Safety.hasNearbyMonsters(2, x, y, player) then return true end
	if not snag and player.slideOnSlipperyTile and not AffectorItem.entityHasItem(player, "itemSlideImmunity") and Tile.getInfo(x, y).slippery then
		local dx = x - player.position.x
		local dy = y - player.position.y
		if not Pathfinding.hasSnag(player, x + dx, y + dy) then
			if Safety.hasNearbyMonsters(2, x, y, player) then
				return true
			end
		end
	end
	return false
end

function Safety.isValidSpace(targetX, targetY, startX, startY, player)
	if Safety.hasInsurmountableObstacle(targetX, targetY, player) then return false end
	local playerX, playerY = targetX, targetY
	if Pathfinding.hasSnag(player, targetX, targetY) then
		playerX, playerY = startX, startY
	end
	if Safety.hasPathBlocker(playerX, playerY, player) then return false end
	-- TODO don't walk into dead ends (spots with one or zero safe spots near them)
	local defensivePosition = Safety.isDefensivePosition(playerX, playerY, targetX, targetY, player, startX, startY)
	return defensivePosition
end

function Safety.isValidDirection(direction, player)
	local startX, startY, targetX, targetY = Utils.positionInDirection(player, direction)
	return Safety.isValidSpace(targetX, targetY, startX, startY, player)
end

return Safety