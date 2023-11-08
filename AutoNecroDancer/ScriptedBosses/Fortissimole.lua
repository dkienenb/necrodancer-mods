local Action = require "necro.game.system.Action"
local Direction = Action.Direction
local Entities = require "system.game.Entities"
local Map = require "necro.game.object.Map"

local Utils = require("AutoNecroDancer.Utils")
local PRIORITY = require("AutoNecroDancer.Targeting").PRIORITY

local Snapshot = require "necro.game.system.Snapshot"

-- TODO make scripted boss base class
crPhase = Snapshot.levelVariable(0)
fmKillCycleIndex = Snapshot.levelVariable(1)

local killCycle = {Direction.DOWN, Direction.UP, Direction.DOWN, Direction.DOWN, Direction.UP, Direction.RIGHT, Direction.RIGHT, Direction.LEFT, Direction.LEFT, Direction.DOWN}

local function fortissimoleOverride(player, targets)
	for fortissimole in Entities.entitiesWithComponents({ "boss" }) do
		if Utils.stringStartsWith(fortissimole.name, "Fortissimole") then
			local playerX, playerY = player.position.x, player.position.y
			local extras = {}
			for monster in Entities.entitiesWithComponents({ "health" }) do
				if monster.controllable.playerID == 0 and not monster.playableCharacter and not (monster.captiveAudience and monster.captiveAudience.active) and not monster.boss then
					table.insert(extras, monster)
				end
			end
			if crPhase == 0 then
				if #extras == 0 then
					crPhase = 1
				else
					for _, monster in ipairs(extras) do
						-- TODO ensure all gold spawns at y -11 or higher for monk/coda
						table.insert(targets, { entityID = monster.id, override = true, priority = PRIORITY.OVERRIDE })
					end
				end
			end
			if crPhase == 1 then
				if playerX == -4 and playerY == -14 then
					crPhase = 2
				else
					table.insert(targets, { x = -4, y = -14, override = true, priority = PRIORITY.OVERRIDE })
				end
			end
			if crPhase == 2 then
				local leftSkeleton = Map.firstWithComponent(-3, -14, "health")
				if not leftSkeleton then
					crPhase = 3
				else
					-- TODO ensure no spawns that could hit player
					table.insert(targets, { overrideAction = Action.Direction.RIGHT, override = true, priority = PRIORITY.OVERRIDE })
				end
			end
			if crPhase == 3 then
				if playerX == 4 and playerY == -14 then
					crPhase = 4
				else
					table.insert(targets, { x = 4, y = -14, override = true, priority = PRIORITY.OVERRIDE })
				end
			end
			if crPhase == 4 then
				local rightSkeleton = Map.firstWithComponent(3, -14, "health")
				if not rightSkeleton then
					crPhase = 5
				else
					-- TODO ensure no spawns that could hit player
					table.insert(targets, { overrideAction = Action.Direction.LEFT, override = true, priority = PRIORITY.OVERRIDE })
				end
			end
			if crPhase == 5 and Map.firstWithComponent(-3, -14, "fortissimoleBurrowing") then
				if #extras == 0 then
					crPhase = 6
				else
					for _, monster in ipairs(extras) do
						table.insert(targets, { entityID = monster.id, override = true, priority = PRIORITY.OVERRIDE })
					end
				end
			end
			if crPhase == 6 then
				if playerX == 6 and playerY == -16 then
					crPhase = 7
				else
					table.insert(targets, { x = 6, y = -16, override = true, priority = PRIORITY.OVERRIDE })
				end
			end
			if crPhase == 7 then
				if playerX == -6 then
					crPhase = 8
				else
					table.insert(targets, { overrideAction = Action.Direction.LEFT, override = true, priority = PRIORITY.OVERRIDE })
				end
			end
			if crPhase == 8 then
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

return {
	fortissimoleOverride = fortissimoleOverride
}