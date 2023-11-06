local Action = require "necro.game.system.Action"
local Direction = Action.Direction
local Entities = require "system.game.Entities"
local Map = require "necro.game.object.Map"
local Snapshot = require "necro.game.system.Snapshot"
local Utilities = require "system.utils.Utilities"

local Utils = require("AutoNecroDancer.Utils")
local Safety = require("AutoNecroDancer.Safety")
local PRIORITY = require("AutoNecroDancer.Targeting").PRIORITY

lutePhase = Snapshot.levelVariable(0)

local function adjacent(dx, dy)
	return Utilities.distanceL1(dx, dy) == 1
end

local function middleLuteX(luteX, luteY)
	local headX = luteX
	if Map.hasComponent(luteX - 1, luteY - 1, "luteBody") then
		headX = headX - 1
	end
	if Map.hasComponent(luteX + 1, luteY - 1, "luteBody") then
		headX = headX + 1
	end
	return headX
end

local function luteOverride(player, targets)
	local playerX, playerY = player.position.x, player.position.y
	for _, lute in ipairs(Entities.getEntitiesByType("LuteHead")) do
		local luteX, luteY = lute.position.x, lute.position.y
		if lutePhase == 0 then
			if playerY == -12 then
				lutePhase = 1
			else
				table.insert(targets, {x=0,y=-12,tile=true,override=true,priority=PRIORITY.OVERRIDE})
			end
		end
		if lutePhase == 1 then
			if playerY == -7 then
				lutePhase = 2
			else
				table.insert(targets, {x=0,y=-7,tile=true,override=true,priority=PRIORITY.OVERRIDE})
			end
		end
		if lutePhase == 2 then
			if playerY == -10 then
				lutePhase = 3
			else
				table.insert(targets, {x=0,y=-10,tile=true,override=true,priority=PRIORITY.OVERRIDE})
			end
		end
		if lutePhase == 3 then
			if #Entities.getEntitiesByType("Sarcophagus") ~= 0 or #Entities.getEntitiesByType("Sarcophagus2") ~= 0 then
				if not Map.firstWithComponent(1, -9, "enemyPoolZone3") then
					if not Map.firstWithComponent(1, -10, "enemyPoolZone3") then
						if playerY ~= -7 then
							table.insert(targets, {x=0,y=-7,tile=true,override=true,priority=PRIORITY.OVERRIDE})
						else
							table.insert(targets, {x=0,y=-8,tile=true,override=true,priority=PRIORITY.OVERRIDE})
						end
					else
						table.insert(targets, {override=true,overrideAction=Action.Direction.RIGHT,priority=PRIORITY.OVERRIDE})
					end
				else
					table.insert(targets, {override=true,overrideAction=Action.Special.THROW,priority=PRIORITY.OVERRIDE})
				end
			else
				if not Map.firstWithComponent(5, -10, "weaponThrowable") then
					lutePhase = 4
				else
					lutePhase = 3.5
				end
			end
		end
		if lutePhase == 4 or lutePhase == 14 then
			-- TODO fetch dagger (from double rider) (wait for all monsters to die) (then wait out firepigs)
			local nextToLuteBody = Map.hasComponent(playerX, playerY - 1, "luteBody")
			if nextToLuteBody and adjacent(playerX-luteX, playerY-luteY) then
				lutePhase = lutePhase + 1
			else
				local unsafe = not Safety.isValidDirection(Direction.UP, player)
				if unsafe or ((not nextToLuteBody) and (luteY == playerY - 1) and (luteX == 0)) then
					table.insert(targets, {x=0, y=playerY+1, tile=true, override=true, priority=PRIORITY.OVERRIDE})
				else
					table.insert(targets, {x=0, y=playerY-1, tile=true, override=true, priority=PRIORITY.OVERRIDE})
				end
			end
		end
		if lutePhase == 5 or lutePhase == 7 or lutePhase == 9 or lutePhase == 15 or lutePhase == 17 then
			table.insert(targets, {entityID=lute.id, override=true, priority=PRIORITY.OVERRIDE})
			lutePhase = lutePhase + 1
		elseif lutePhase == 6 or lutePhase == 16 then
			local luteBody = Map.firstWithComponent(luteX, luteY - 1, "luteBody")
			if luteBody.beatDelay.counter == 0 then
				table.insert(targets, {x=0, y=playerY+1, tile=true, override=true, priority=PRIORITY.OVERRIDE})
			else
				table.insert(targets, {x=0, y=playerY-1, tile=true, override=true, priority=PRIORITY.OVERRIDE})
				lutePhase = lutePhase + 1
			end
		elseif lutePhase == 8 then
			table.insert(targets, {x=0, y=playerY-1, tile=true, override=true, priority=PRIORITY.OVERRIDE})
			if playerY == -14 then
				lutePhase = 9
			end
		elseif lutePhase == 10 then
			if #Entities.getEntitiesByType("Dragon2") > 0 then
				lutePhase = 11
			else
				if playerY ~= -8 then
					table.insert(targets, {x=0,y=-8,tile=true,override=true,priority=PRIORITY.OVERRIDE})
				else
					table.insert(targets, {x=0,y=-9,tile=true,override=true,priority=PRIORITY.OVERRIDE})
				end
			end
		elseif lutePhase == 18 then
			if playerX == luteX then
				lutePhase = 19
			else
				table.insert(targets, {x=luteX,y=playerY,tile=true,override=true,priority=PRIORITY.OVERRIDE})
			end
		end
		if lutePhase == 11 then
			local greenDragons = Entities.getEntitiesByType("Dragon")
			if #greenDragons == 0 then
				lutePhase = 12
			else
				for _, dragon in ipairs(greenDragons) do
					if playerY < -9 then
						table.insert(targets, {x=0, y=-7, tile=true, override=true, priority=PRIORITY.OVERRIDE})
					else
						table.insert(targets, {entityID=dragon.id, override=true, priority=PRIORITY.OVERRIDE})
					end
				end
			end
		end
		if lutePhase == 12 then
			local redDragons = Entities.getEntitiesByType("Dragon2")
			if #redDragons == 0 then
				lutePhase = 13
			else
				for _, dragon in ipairs(redDragons) do
					if playerY < -9 then
						table.insert(targets, {x=0, y=-7, tile=true, override=true, priority=PRIORITY.OVERRIDE})
					else
						table.insert(targets, {entityID=dragon.id, override=true, priority=PRIORITY.OVERRIDE})
					end
				end
			end
		end
		if lutePhase == 13 then
			if playerX == 0 and playerY == -7 then
				lutePhase = 13.5
			else
				table.insert(targets, {x=0,y=-7,tile=true,override=true,priority=PRIORITY.OVERRIDE})
			end
		end
		if lutePhase == 3.5 or lutePhase == 13.5 then
			local droppedDagger = Map.firstWithComponent(5, -10, "weaponThrowable")
			if not droppedDagger or droppedDagger.item.holder ~= 0 then
				droppedDagger = nil
			end
			local wallPig = Map.firstWithComponent(6, -14, "actionDelay")
			local bodyX = middleLuteX(luteX, luteY)
			local x = 0
			local y = -7
			local nonLuteEnts = false
			for entity in Entities.entitiesWithComponents({ "spawnable" }) do
				local type = entity.name
				if not Utils.stringStartsWith(type, "Lute") then
					nonLuteEnts = true
					break
				end
			end
			if not nonLuteEnts then
				if droppedDagger then
					x = 5
					y = -10
				else
					x = (-bodyX) * 4
					if x ~= 0 then
						y = -10
					end
					if playerY == y then
						y = y - 1
					end
				end
			end
			table.insert(targets, {x=x,y=y,tile=true,override=true,priority=PRIORITY.OVERRIDE})
			if wallPig.actionDelay.currentAction ~= 0 and wallPig.actionDelay.delay == 0 and bodyX == 0 then
				lutePhase = lutePhase + 0.5
			end
		end
		if lutePhase == 19 then
			table.insert(targets, {override=true,overrideAction=Action.Special.THROW,priority=PRIORITY.OVERRIDE})
			lutePhase = 20
		elseif lutePhase == 20 then
			table.insert(targets, {override=true,overrideAction=Action.Direction.UP,priority=PRIORITY.OVERRIDE})
			lutePhase = 21
		end
	end
end

return {
	luteOverride=luteOverride
}