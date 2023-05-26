local libLevelGen = require "LibLevelGen.LibLevelGen"
local segment = require "LibLevelGen.Segment"
local room = require "LibLevelGen.Room"
local levelgenUtil = require "LibLevelGen.Util"
local tr = levelgenUtil.TileRequirements
local snapshot = require "necro.game.system.Snapshot"
local roomActions = require "dkienenLib.LevelGenerationUtil_RoomActions"

local generationSystems = {}
local END_DEPTH = 143

local defaultRoomGenParameterCombinations = {
  -- Directions in which the room is allowed to generate.
  direction = {room.Direction.UP, room.Direction.DOWN, room.Direction.LEFT, room.Direction.RIGHT},
  -- Where corridor center is allowed to be relative to the origin room.
  -- 0.5 is the middle, 0 is left/top and 1 is right or bottom.
  corridorEntrance = {0.25, 0.5, 0.75},
  -- Same as above, but relative to the generated room.
  corridorExit = {0.25, 0.5, 0.75},
  -- How thick the corridor is allowed to be. Do note that it takes the border
  -- into account, so thickness of 3 is actually just 1-floor tile wide.
  corridorThickness = {3},
  -- How long is the corridor allowed to be.
  -- Length of 0 is allowed, and will result in rooms being adjacent.
  corridorLength = {0, 1, 2, 3, 4},
  -- Allowed width values for the generated room.
  roomWidth = {6, 7, 8, 9},
  -- Allowed height values for the generated room.
  roomHeight = {6, 7, 8, 9},
}

local endRoomGenParamCombinations = {
  direction = {room.Direction.LEFT, room.Direction.RIGHT, room.Direction.UP, room.Direction.DOWN},
  corridorEntrance = {0.5},
  corridorExit = {0.5},
  corridorThickness = {3},
  corridorLength = {2},
  roomWidth = {5},
  roomHeight = {5},
}

local function branch(currentRoom, roomGenCombinations)
  local segment = currentRoom.segment
  local newCorridor, newRoom = segment:createRandLinkedRoom(currentRoom, true, roomGenCombinations)
  newCorridor:setTile(0, 0, "DirtWall")
  newCorridor:setTile(0, 1, "DirtWall")
  newCorridor:setTile(1, 0, "DirtWall")
  newCorridor:setTile(1, 1, "DirtWall")
  return newRoom
end

local function processActions(room, actions)
  for _, action in ipairs(actions) do
    local newRooms = roomActions[action.type](action.args, room, branch)
    if action.actionsForEachRoom then
      for _, newRoom in ipairs(newRooms) do
        processActions(newRoom, action.actionsForEachRoom)
      end
    end
    if action.actionsForLastRoom then
      processActions(newRooms[#newRooms], action.actionsForLastRoom)
    end
  end
end

local function makeGeneratorFunction(actions)
  return function(instance)
    local mainSegment = instance:createSegment()
    local startingRoom = mainSegment:createStartingRoom()
    processActions(startingRoom, actions)
    mainSegment:placeWallTorches(4)
  end
end

local function addGenerator(depthPredicate, generatorFunction)
  table.insert(generationSystems, {predicate=depthPredicate, action=generatorFunction})
end

local function generatorEngineFunction(genParams)
  local instance = libLevelGen.new(genParams)
  local depth = instance:getDepth()
  local floor = instance:getFloor()
  local found = false
  for _, entry in ipairs(generationSystems) do
    local predicate = entry.predicate
    if predicate(depth, floor) then
      entry.action(instance)
      instance:finalize()
      found = true
      break
    end
  end
  if not found then
    print("Unable to find any generators for depth " .. depth .. ", floor " .. floor .. "!")
  end
end

local endRoomGenCombinations = segment.createRandLinkedRoomParameterCombinations(endRoomGenParamCombinations)
addGenerator(function(depth) return depth == depth end, makeGeneratorFunction({
  {
    type="TREE",
    args={
      roomCount=3,
      roomGenCombinations=endRoomGenCombinations
    },
    actionsForEachRoom={
      {
        type="EXIT",
        args={
          miniboss="Bat3"
        }
      },
      {
        type="ENTITY",
        args={
          entity="Bat3",
          count={
            min=0,
            max=8
          }
        }
      }
    }
  }
}))
local commonGenerator = libLevelGen.registerGenerator("dkienenLib_common", generatorEngineFunction)
return {
  COMMON=commonGenerator,
  END_DEPTH=END_DEPTH
}