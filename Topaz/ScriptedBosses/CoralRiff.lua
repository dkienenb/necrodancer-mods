local Action = require "necro.game.system.Action"
local CurrentLevel = require "necro.game.level.CurrentLevel"
local Direction = Action.Direction
local Entities = require "system.game.Entities"
local Map = require "necro.game.object.Map"
local Snapshot = require "necro.game.system.Snapshot"
local Utilities = require "system.utils.Utilities"

local Utils = require("Topaz.Utils")
local Safety = require("Topaz.Safety")
local Pathfinding = require("Topaz.Pathfinding")
local Targeting = require("Topaz.Targeting")

crMoveCache = Snapshot.levelVariable({})
crTargetPos = Snapshot.levelVariable({})
crTargetCache = Snapshot.levelVariable({})
crCacheInit = Snapshot.levelVariable(false)
crTentaclePopups = Snapshot.levelVariable({})
crTentaclePopupCount = Snapshot.levelVariable(0)
crCorner = Snapshot.levelVariable(false)

local u = Direction.UP
local l = Direction.LEFT
local r = Direction.RIGHT
local d = Direction.DOWN
local throw = Action.Special.THROW
local dry = u

local box1 = {r, u, d, u, r, r, l, l, d, u, d, u, d, u, u}
local box2 = {r, u, r, u, d, u, d, l, r, l, u, d, u, d, u, u, d, u, d, u, d, u, d, u, d, u, u, d, u, u}
local box3 = {r, u, u, dry, d, d, r, r, l, d, u, l, u, u, u, d, u, d, u, d, u, d, d, u, d, u, u, d, u, u, u}
local box4 = {d, d, throw, d, u, d, r, r, u, d, u, d, l, u, d, u, d, u, d, u, d, u, u, d, u, u, u, r, r, r, u, r, l, r, l, l, d, l, dry, r, l, r, l, l, r, u, u, dry, u, dry, d, u, u, d, u, u}
local box5 = {d, d, throw, d, u, d, r, r, u, dry, u, d, l, u, d, u, d, u, d, u, d, u, u, d, u, u, u, r, r, r, u, r, l, r, l, l, d, l, r, l, r, l, r, l, l, u, u, dry, u, dry, d, u, u, d, u, u}
local boxes = {box1, box2, box3, box4, box5}

local star1 = {r, r, l, r, l, r, u, r, u, dry, u, dry, d, d, u, d, u, u, u}
local star2 = {r, r, l, r, l, r, l, u, r, l, r, u, d, u, d, u, u, d, u, d, u, d, u, d, d, u, d, u, u, r, r, l, l, r, r, l, l, r, r, u, u, u, dry, u}
local star3 = {r, r, l, r, l, r, l, u, r, l, r, u, u, dry, u, d, u, u, d, u, d, u, d, u, u, r, dry, u, dry, l, u}
local star4 = {d, d, r, d, r, r, r, u, r, l, r, l, u, r, l, r, u, l, r, l, u, l, l, l, u, l, r, l, r, l, r, l, r, r, r, l, r, r, u, u, u, dry, u, d, d, r, dry, r}
local star5 = {d, d, r, d, r, r, r, u, r, l, r, l, u, r, l, r, u, l, r, l, u, r, l, r, l, u, l, l, l, u, l, r, r, l, r, l, r, l, r, r, u, l, d, u, u, d, l, l}
local stars = {star1, star2, star3, star4, star5}

local corners = {
	{box="lowerRight", star="upperRight"},
	{box="lowerRight", star="upperRight"},
	{box="lowerRight", star="upperRight"},
	{box="upperRight", star="lowerRight"},
	{box="upperRight", star="lowerLeft"},
}

local cornerBounds = {
	lowerLeft = {
		{x=-5, y=-9},
		{x=-4, y=-9},
		{x=-3, y=-9},
		{x=-3, y=-8},
		{x=-3, y=-7}
	},
	lowerRight = {
		{x=5, y=-9},
		{x=4, y=-9},
		{x=3, y=-9},
		{x=3, y=-8},
		{x=3, y=-7}
	},
	upperRight = {
		{x=5, y=-12},
		{x=4, y=-12},
		{x=3, y=-12},
		{x=3, y=-13},
		{x=3, y=-14}
	}
}

local tentacleTypes = {
	Tentacle = "drums",
	Tentacle2 = "horns",
	Tentacle3 = "strings",
	Tentacle4 = "keys",
	Tentacle5 = "drums",
	Tentacle6 = "horns",
	Tentacle7 = "strings",
	Tentacle8 = "keys"
}

local function moveNext()
	if #crMoveCache == 0 then
		return
	end
	local next = table.remove(crMoveCache, 1)
	Targeting.addTarget(nil, nil, "override", nil, nil, next)
end

local function coralRiffOverride(player)
	for coralRiff in Entities.entitiesWithComponents({ "boss" }) do
		local accessible = false
		for monster in Entities.entitiesWithComponents({"health"}) do
			if Utils.stringStartsWith(monster.name, "Tentacle") or monster.boss then
				local x, y = monster.position.x, monster.position.y
				for dx = -1, 1 do
					for dy = -1, 1 do
						if not Safety.hasLiquid(x + dx, y + dy) and Utils.canDig(player, x + dx, y + dy) then
							accessible = true
							break
						end
					end
					if accessible then break end
				end
			end
			if accessible then break end
		end
		if not accessible then
			Targeting.addTarget(0, -9, "override", Targeting.PRIORITY.OVERRIDE - 10)
		end
		if not Pathfinding.hasDiagonal(player) and player.playableCharacter and player.name ~= "Sync_Chaunter" then
			if not crCacheInit then
				crTargetCache = {{x=0,y=-9}, {x=-4, y=-9}, {x=-3, y=-9}, {x=-4, y=-9}}
				crCacheInit = true
			end
			if Utils.stringStartsWith(coralRiff.name, "Coralriff") then
				local playerX, playerY = player.position.x, player.position.y
				local newPopup = false
				for monster in Entities.entitiesWithComponents({ "health" }) do
					if monster.controllable.playerID == 0 and not monster.playableCharacter and not monster.boss then
						local monsterX = monster.position.x
						local monsterY = monster.position.y
						local dx = math.abs(playerX - monsterX)
						local dy = math.abs(playerY - monsterY)
						if dx <= 1 and dy <= 1 then
							local monsterID = monster.id
							if not crTentaclePopups[monsterID] then
								crTentaclePopups[monsterID] = true
								crTentaclePopupCount = crTentaclePopupCount + 1
								newPopup = tentacleTypes[monster.name]
							end
						end
					end
				end
				if #crMoveCache == 0 then
					local targetX = crTargetPos.x
					local targetY = crTargetPos.y
					if (playerX == targetX and playerY == targetY) or not targetX or not targetY then
						if #crTargetCache ~= 0 then
							crTargetPos = table.remove(crTargetCache, 1)
						else
							crTargetPos = {}
						end
					end
					targetX = crTargetPos.x
					targetY = crTargetPos.y
					if crTargetPos and targetX and targetY and not newPopup then
						Targeting.addTarget(targetX, targetY, "override")
					else
						if newPopup then
							-- TODO treat all depths as 1 with more dmg
							if CurrentLevel.getDepth() <= 3 then
								if newPopup == "drums" then
									crMoveCache = {u, d, r, l, r, r}
								elseif newPopup == "keys" then
									if Safety.hasLiquid(playerX, playerY-1) then
										crMoveCache = {l, r, d, r, r, u}
									else
										crMoveCache = {l, r, u, r, r, d}
									end
								elseif newPopup == "strings" then
									if Safety.hasLiquid(playerX-1, playerY) then
										crMoveCache = {d, l, u, r, l, r}
									else
										crMoveCache = {l, d, r, r, l, r}
									end
								elseif newPopup == "horns" then
									crMoveCache = {d, r, u, r, l, r}
								end
							else
								local v = (playerY == -9) and u or d
								if newPopup == "drums" then
									crMoveCache = {u, d, r, l, r, v}
								elseif newPopup == "keys" then
									crMoveCache = {l, r, v, r, l, r}
								elseif newPopup == "strings" then
									crMoveCache = {r, u, u, dry, d, v}
								elseif newPopup == "horns" then
									crMoveCache = {r, d, d, dry, u, v}
								end
							end
						else
							if not crCorner then
								-- TODO treat all depths as 1 with more dmg
								local depth = CurrentLevel.getDepth()
								if Map.hasComponent(playerX + 1, playerY - 1, "health") then
									crMoveCache = Utilities.shallowCopy(boxes[depth])
									crCorner = corners[depth].box
								else
									crMoveCache = Utilities.shallowCopy(stars[depth])
									crCorner = corners[depth].star
								end
							else
								local dx = math.abs(playerX - coralRiff.position.x)
								local dy = math.abs(playerY - coralRiff.position.y)
								if (dx == 1 and dy == 0) or (dx == 0 and dy == 1) then
									Targeting.addTarget(nil, nil, "override", nil, coralRiff.id)
								else
									local offsets = cornerBounds[crCorner]
									-- TODO redirect corer if CR is in a bad spot (cr3, cr4)
									for index, offset in ipairs(offsets) do
										local x = offset.x
										local y = offset.y
										if Safety.hasLiquid(x, y) then
											Targeting.addTarget(x, y, "override")
										end
										if index == 3 and not (x == playerX and y == playerY) and Safety.isValidSpace(x, y, playerX, playerY, player) then
											Targeting.addTarget(x, y, "override", Targeting.PRIORITY.OVERRIDE - 1)
										end
										if dx >= dy and index < 3 and not (x == playerX and y == playerY) and Safety.isValidSpace(x, y, playerX, playerY, player) then
											Targeting.addTarget(x, y, "override", Targeting.PRIORITY.OVERRIDE - 2)
										end
										if dy > dx and index > 3 and not (x == playerX and y == playerY) and Safety.isValidSpace(x, y, playerX, playerY, player) then
											Targeting.addTarget(x, y, "override", Targeting.PRIORITY.OVERRIDE - 2)
										end
									end
								end
							end
						end
						moveNext()
					end
				else
					moveNext()
				end
			end
		end
	end
end

return {
	coralRiffOverride = coralRiffOverride
}