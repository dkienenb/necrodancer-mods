local Action = require "necro.game.system.Action"
local Direction = Action.Direction
local Entities = require "system.game.Entities"
local Map = require "necro.game.object.Map"

local Utils = require("Topaz.Utils")
local Targeting = require("Topaz.Targeting")

local Snapshot = require "necro.game.system.Snapshot"

-- TODO make scripted boss base class
fmPhase = Snapshot.levelVariable(0)
fmKillCycleIndex = Snapshot.levelVariable(1)

--[[
https://discord.com/channels/83287148966449152/83287148966449152/1117744544738463804 fm3
--]]
local killCycle = {Direction.DOWN, Direction.UP, Direction.DOWN, Direction.DOWN, Direction.UP, Direction.RIGHT, Direction.RIGHT, Direction.LEFT, Direction.LEFT, Direction.DOWN}

local function fortissimoleOverride(player, targets)
	local inventory = player.inventory
	if inventory and inventory.itemSlots.weapon and inventory.itemSlots.weapon and inventory.itemSlots.weapon[1] and Entities.getEntityByID(inventory.itemSlots.weapon[1]) and Entities.getEntityByID(inventory.itemSlots.weapon[1]).name == "Weapon" then
		for fortissimole in Entities.entitiesWithComponents({ "boss" }) do
			if Utils.stringStartsWith(fortissimole.name, "Fortissimole") then
				local playerX, playerY = player.position.x, player.position.y
				local extras = {}
				for monster in Entities.entitiesWithComponents({ "health" }) do
					if monster.controllable.playerID == 0 and not monster.playableCharacter and not (monster.captiveAudience and monster.captiveAudience.active) and not monster.boss and Utils.canEverHurt(monster, player) then
						table.insert(extras, monster)
					end
				end
				if fmPhase == 0 then
					if #extras == 0 then
						fmPhase = 1
					else
						for _, monster in ipairs(extras) do
							-- TODO ensure all gold spawns at y -11 or higher for monk/coda
							Targeting.addTarget(nil, nil, "override", nil, monster.id)
						end
					end
				end
				if fmPhase == 1 then
					if playerX == -4 and playerY == -14 then
						fmPhase = 2
					else
						Targeting.addTarget(-4, -14, "override")
					end
				end
				if fmPhase == 2 then
					local leftSkeleton = Map.firstWithComponent(-3, -14, "health")
					if not leftSkeleton then
						fmPhase = 3
					else
						-- TODO ensure no spawns that could hit player
						table.insert(targets, { overrideAction = Action.Direction.RIGHT, override = true, priority = PRIORITY.OVERRIDE })
					end
				end
				if fmPhase == 3 then
					if playerX == 4 and playerY == -14 then
						fmPhase = 4
					else
						Targeting.addTarget(4, -14, "override")
					end
				end
				if fmPhase == 4 then
					local rightSkeleton = Map.firstWithComponent(3, -14, "health")
					if not rightSkeleton then
						fmPhase = 5
					else
						-- TODO ensure no spawns that could hit player
						table.insert(targets, { overrideAction = Action.Direction.LEFT, override = true, priority = PRIORITY.OVERRIDE })
					end
				end
				if fmPhase == 5 and Map.firstWithComponent(-3, -14, "fortissimoleBurrowing") then
					if #extras == 0 then
						fmPhase = 6
					else
						for _, monster in ipairs(extras) do
							Targeting.addTarget(nil, nil, "override", nil, monster.id)
						end
					end
				end
				if fmPhase == 6 then
					if playerX == 6 and playerY == -16 then
						fmPhase = 7
					else
						Targeting.addTarget(6, -16, "override")
					end
				end
				if fmPhase == 7 then
					if playerX == -6 then
						fmPhase = 8
					else
						table.insert(targets, { overrideAction = Action.Direction.LEFT, override = true, priority = PRIORITY.OVERRIDE })
					end
				end
				if fmPhase == 8 then
					local action = killCycle[fmKillCycleIndex]
					dbg(action)
					table.insert(targets, { overrideAction = action, override = true, priority = PRIORITY.OVERRIDE })
					fmKillCycleIndex = fmKillCycleIndex + 1
					if fmKillCycleIndex == 11 then
						fmKillCycleIndex = 6
					end
				end
			end
		end
	end
end

return {
	fortissimoleOverride = fortissimoleOverride
}