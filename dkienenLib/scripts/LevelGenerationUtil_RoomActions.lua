local levelgenUtil = require "LibLevelGen.Util"
local tr = levelgenUtil.TileRequirements

return {
  CORRIDOR=function(args, currentRoom, branchFunction)
    local newRooms = {}
    for _ = 1, args.roomCount or 1 do
      currentRoom = branchFunction(currentRoom, args.roomGenCombinations)
      table.insert(newRooms, currentRoom)
    end
    return newRooms
  end,
  TREE=function(args, currentRoom, branchFunction)
    local newRooms = {}
    for _ = 1, args.roomCount or 1 do
      table.insert(newRooms, branchFunction(currentRoom, args.roomGenCombinations))
    end
    return newRooms
  end,
  EXIT=function(args, currentRoom)
    currentRoom:makeExit({ { args.miniboss, 1 } })
  end,
  ENTITY=function(args, currentRoom)
    local countMin = args.count and args.count.min or 1
    local countMax = args.count and args.count.max or 2
    for _ = 1, currentRoom.instance:randIntRange(countMin, countMax) do
      currentRoom:placeEntityRand(args.tileRequirements or tr.Enemy.Generic, args.entity)
    end
  end
}