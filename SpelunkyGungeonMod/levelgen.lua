local boss = require "necro.game.level.Boss"
local customEntities = require "necro.game.data.CustomEntities"

local libLevelGen = require "LibLevelGen.LibLevelGen"
local levelgenUtil = require "LibLevelGen.Util"
local tr = levelgenUtil.TileRequirements
local segment = require "LibLevelGen.Segment"
local room = require "LibLevelGen.Room"
local levelSequence = require "LibLevelGen.LevelSequence"
local monsters = {"Armadillo2", "Armadillo3", "Bat2", "Bat4", "Beetle", "Beetle2", "Blademaster", "Clone", "Fireelemental", "Goblin", "Goblin2", "Golem3", "Hellhound", "Iceelemental", "Lich", "Mole", "Monkey2", "Mummy", "Mushroom2", "Skeleton3", "Skeleton3", "Skeleton3", "Skeleton3", "Skeleton4", "Slime4", "Slime5", "Slime6", "Slime7", "Slime8", "Warlock", "Warlock2"}
local minibosses = {"Mommy", "Dragon2", "Dragon3", "Ogre", "HeadGlassJaw"}

local name = "SpelunkyGungeonMod"
local prefix = name .. "_"
local entityUtil = require "dkienenLib.EntityUtil"

-- open tiles per monster
local spawnRate = 12
local crests = {"WormFood", "UdjatEye", "OldCrest"}

local bossID = boss.Type.extend("Blobulord")
entityUtil.registerEntity(name, customEntities.template.enemy("slime", 8), {
	boss = {type=bossID},
	Sync_enemyPoolBoss={},
	health = {
		maxHealth = 10,
		health = 10
	}
}, "Blobulord")

local roomGenParams = {
	-- Directions in which the room is allowed to generate.
	direction = {room.Direction.UP, room.Direction.LEFT, room.Direction.DOWN, room.Direction.RIGHT},
	-- Where corridor center is allowed to be relative to the origin room.
	-- 0.5 is the middle, 0 is left/top and 1 is right or bottom.
	corridorEntrance = {0.25, 0.35, 0.5, 0.65, 0.75},
	-- Same as above, but relative to the generated room.
	corridorExit = {0.25, 0.35, 0.5, 0.65, 0.75},
	-- How thick the corridor is allowed to be. Do note that it takes the border
	-- into account, so thickness of 3 is actually just 1-floor tile wide.
	corridorThickness = {3},
	-- How long is the corridor allowed to be.
	-- Length of 0 is allowed, and will result in rooms being adjacent.
	corridorLength = {2, 3, 4, 5, 6},
	-- Allowed width values for the generated room.
	roomWidth = {8, 9, 10, 11, 20},
	-- Allowed height values for the generated room.
	roomHeight = {8, 9, 10, 11, 20},
}

local shopGenCombinations = segment.createRandLinkedRoomParameterCombinations({
	-- Directions in which the room is allowed to generate.
	direction = {room.Direction.UP, room.Direction.LEFT, room.Direction.DOWN, room.Direction.RIGHT},
	-- Where corridor center is allowed to be relative to the origin room.
	-- 0.5 is the middle, 0 is left/top and 1 is right or bottom.
	corridorEntrance = {0.25, 0.35, 0.5, 0.65, 0.75},
	-- Same as above, but relative to the generated room.
	corridorExit = {0.2, 0.5, 0.8},
	-- How thick the corridor is allowed to be. Do note that it takes the border
	-- into account, so thickness of 3 is actually just 1-floor tile wide.
	corridorThickness = {3},
	-- How long is the corridor allowed to be.
	-- Length of 0 is allowed, and will result in rooms being adjacent.
	corridorLength = {1},
	-- Allowed width values for the generated room.
	roomWidth = {7},
	-- Allowed height values for the generated room.
	roomHeight = {9}
})

local bossRoomCombinations = segment.createRandLinkedRoomParameterCombinations({
	-- Directions in which the room is allowed to generate.
	direction = {room.Direction.UP},
	-- Where corridor center is allowed to be relative to the origin room.
	-- 0.5 is the middle, 0 is left/top and 1 is right or bottom.
	corridorEntrance = {0.5},
	-- Same as above, but relative to the generated room.
	corridorExit = {0.5},
	-- How thick the corridor is allowed to be. Do note that it takes the border
	-- into account, so thickness of 3 is actually just 1-floor tile wide.
	corridorThickness = {5},
	-- How long is the corridor allowed to be.
	-- Length of 0 is allowed, and will result in rooms being adjacent.
	corridorLength = {3},
	-- Allowed width values for the generated room.
	roomWidth = {21},
	-- Allowed height values for the generated room.
	roomHeight = {21}
})

local chestGenCombinations = segment.createRandLinkedRoomParameterCombinations({
	-- Directions in which the room is allowed to generate.
	direction = {room.Direction.UP, room.Direction.LEFT, room.Direction.DOWN, room.Direction.RIGHT},
	-- Where corridor center is allowed to be relative to the origin room.
	-- 0.5 is the middle, 0 is left/top and 1 is right or bottom.
	corridorEntrance = {0.25, 0.35, 0.5, 0.65, 0.75},
	-- Same as above, but relative to the generated room.
	corridorExit = {0.5},
	-- How thick the corridor is allowed to be. Do note that it takes the border
	-- into account, so thickness of 3 is actually just 1-floor tile wide.
	corridorThickness = {3},
	-- How long is the corridor allowed to be.
	-- Length of 0 is allowed, and will result in rooms being adjacent.
	corridorLength = {4},
	-- Allowed width values for the generated room.
	roomWidth = {7},
	-- Allowed height values for the generated room.
	roomHeight = {7}
})

local roomGenCombinations = segment.createRandLinkedRoomParameterCombinations(roomGenParams)
local directionalRoomGenCombinations = {}
local compiledMinibosses = {}

for _, miniboss in ipairs(minibosses) do
	table.insert(compiledMinibosses, {miniboss})
end


local function createRoomGenCombinations(direction)
	roomGenParams.direction = {room.Direction[direction]}
	local roomGenCombinationsDirectional = segment.createRandLinkedRoomParameterCombinations(roomGenParams)
	directionalRoomGenCombinations[direction] = roomGenCombinationsDirectional
end

createRoomGenCombinations("UP")
createRoomGenCombinations("LEFT")
createRoomGenCombinations("DOWN")
createRoomGenCombinations("RIGHT")

local function makeExit(room)
	room:makeExit(compiledMinibosses)
end

local function makeShop(room)
	room:makeShop()
end

local function makeChestRoom(target)
	target:placeEntityAt(3, 3, prefix .. "ChestPlaceholderMarker")
	target:clearFlags(room.Flag.ALLOW_ENEMY)
	target:clearFlags(room.Flag.ALLOW_TRAP)
end

local function makeCrestRoom(target)
	target:placeEntityAt(3, 3, prefix .. (crests[target.instance:getFloor()] or "Bomb3"))
	target:clearFlags(room.Flag.ALLOW_ENEMY)
	target:clearFlags(room.Flag.ALLOW_TRAP)
end

local function branch(room, roomGenCombinationsParameter, includeDirtDoor)
	if not roomGenCombinationsParameter then roomGenCombinationsParameter = roomGenCombinations end
	local newCorridor, newRoom, data = room.segment:createRandLinkedRoom(room, false, roomGenCombinationsParameter)
	local bounds = newRoom:getBounds()
	local width = bounds[3]
	local height = bounds[4]
	newRoom:placeWallTorches(((width * 2) + (height * 2)) / 4)
	if includeDirtDoor then
		newCorridor:setTile(1, 1, "DirtWall")
	end
	return newRoom, newCorridor, data
end

local function branchShop(room)
	local newRoom = branch(room, shopGenCombinations)
	makeShop(newRoom)
	return newRoom
end

local function branchExit(room)
	local newRoom = branch(room)
	makeExit(newRoom)
	return newRoom
end

local function branchChest(room)
	local newRoom = branch(room, chestGenCombinations)
	makeChestRoom(newRoom)
	return newRoom
end

local function branchCrest(room)
	local newRoom = branch(room, chestGenCombinations)
	makeCrestRoom(newRoom)
	return newRoom
end

local function branchMultiple(room, count)
	local currentRoom = room
	for index = 1, count do
		local newRoom = branch(currentRoom)
		currentRoom = newRoom
	end
	return currentRoom
end

local function branchMultipleRandom(room, min, max)
	return branchMultiple(room, room.instance:randIntRange(min, max))
end

local function recursiveTreeCreate(currentRoom, roomsLeft)
	if roomsLeft > 0 then
		local newCorridor1, newRoom1 = branch(currentRoom)
		local newCorridor2, newRoom2 = branch(currentRoom)
		-- Check if the generation didn't fail:
		if newRoom1 then
			recursiveTreeCreate(newRoom1, roomsLeft - 1)
		end
		if newRoom2 then
			recursiveTreeCreate(newRoom2, roomsLeft - 1)
		end
	end
end

local function createOublietteBranching(startingRoom)
	local instance = startingRoom.instance
	local crestChoices = {}
	local fork1 = branchMultipleRandom(startingRoom, 1, 2)
	local path1 = branch(fork1)
	local chest1 = branchChest(path1)
	local shop = branchShop(fork1)
	table.insert(crestChoices, chest1)
	table.insert(crestChoices, shop)
	local fork2 = branchMultipleRandom(fork1, 1, 2)
	local path2 = branchMultiple(fork2, 2)
	local chest2 = branchChest(path2)
	-- TODO loop chest back to fork2
	local bossEntrance = branchMultipleRandom(fork2, 1, 2)
	local exit = branchExit(bossEntrance)
	table.insert(crestChoices, chest2)
	table.insert(crestChoices, exit)
	local crestEntrance = instance:randChoice(crestChoices)
	branchCrest(crestEntrance)
end

local function createRooms(mainSegment)
	local instance = mainSegment.instance
	if (instance:getFloor() % 4) ~= 0 then
		mainSegment:setRoomBorder("CatacombWall")
		mainSegment:setCorridorBorder("CatacombWall")
		local startingRoom = mainSegment:createStartingRoom()
		if instance:randChance(1) then
			createOublietteBranching(startingRoom)
		end
	else
		mainSegment:setRoomBorder("BossWall")
		mainSegment:setCorridorBorder("BossWall")
		mainSegment:setTileset("Boss")
		instance.boss=bossID
		local startingRoom = mainSegment:createStartingRoom()
		local bossRoom = branch(startingRoom, bossRoomCombinations, false)
		bossRoom:clearFlags(room.Flag.ALLOW_ENEMY)
		bossRoom:clearFlags(room.Flag.ALLOW_TRAP)
		bossRoom:placeEntityAt(10, 10, prefix .. "Blobulord")
	end
end

local function placeEnemies(currentRoom)
	local instance = currentRoom.instance
	local floor = instance:getFloor()
	local bounds = currentRoom:getBounds()
	local width = bounds[3]
	local height = bounds[4]
	local floorSize = (width - 1) * (height - 1)
	local additionalMonsters = floor
	if currentRoom:checkFlags(room.Flag.EXIT) then
		additionalMonsters = additionalMonsters + 4
	end
	for i = 1, floorSize + (additionalMonsters * spawnRate), spawnRate do
		local enemyType = instance:randChoice(monsters)
		currentRoom:placeEntityRand(tr.Enemy.Generic, enemyType)
	end
end

local function placeTraps(currentRoom)
	local instance = currentRoom.instance
	local floor = instance:getFloor()
	local traps = floor + 1
	for i = 1, traps do
		local trapType = instance:randChoice({"BombTrap", "Sync_DiceTrap", "ScatterTrap", "TempoUpTrap", "ConfusionTrap"})
		currentRoom:placeEntityRand(tr.Enemy.Generic, trapType)
	end
end

local function addMessyFloor(currentRoom)
	local instance = currentRoom.instance
	local floor = instance:getFloor()
	local bounds = currentRoom:getBounds()
	local width = bounds[3]
	local height = bounds[4]
	local floorSize = (width - 1) * (height - 1)
	local additionalMonsters = floor
	if currentRoom:checkFlags(room.Flag.EXIT) then
		additionalMonsters = additionalMonsters + 4
	end
	for i = 1, floorSize + (additionalMonsters * spawnRate), spawnRate do
		local enemyType = instance:randChoice(monsters)
		currentRoom:placeEntityRand(tr.Enemy.Generic, enemyType)
	end
end

local function worldGenerator(genParams)
	-- Create a new instance, which will hold all the things
	-- related to the generated level.
	-- We give it the genParams argument - its type is LibLevelGen.LevelGenerationEventParameters
	-- (http://priw8.github.io/liblevelgen-doc/modules/LibLevelGen.lua/#liblevelgenlevelgenerationeventparameters)
	-- This argument is used to adjust certain properties of the level.
	local instance = libLevelGen.new(genParams)

	-- To place the initial starting room, we need a segment.
	-- As mentioned earlier, segments are isolated collections of rooms.
	local mainSegment = instance:createSegment()

	-- Finally, we can create the starting room. There's a nice helper
	-- method for that, which makes sure that our room ends up 
	-- where the player spawns!

	createRooms(mainSegment)
	if (instance:getFloor() % 4) ~= 0 then
		mainSegment:iterateRooms(room.Flag.ALLOW_ENEMY, placeEnemies)
		mainSegment:iterateRooms(room.Flag.ALLOW_TRAP, placeTraps)
	end
	mainSegment:placeWallTorches(6)
	-- Once we're done with generating the level,
	-- we need to call the finalize method.
	instance:finalize()
end

local generatorID = libLevelGen.registerGenerator("Test_Oubliette", worldGenerator)

return {
	generatorID=generatorID
}