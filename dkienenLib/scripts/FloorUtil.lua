local map = require "necro.game.object.Map"
local marker = require "necro.game.tile.Marker"
local segment = require "necro.game.tile.Segment"
local tile = require "necro.game.tile.Tile"

local function findOpenFloor()
  local candidates = {}
  local levelX, levelY, levelWidth, levelHeight = tile.getLevelBounds()
  local spawnX, spawnY = marker.lookUpMedian(marker.Type.SPAWN)
  if not spawnX then spawnX = 0 end
  if not spawnY then spawnY = 0 end
  local shopX, shopY = marker.lookUpMedian(marker.Type.SHOP)
  for y = levelY, levelY + levelHeight - 1 do
    for x = levelX, levelX + levelWidth - 1 do
      if tile.getInfo(x, y).name == "Floor" then
        if (not (math.abs(spawnX - x) <= 2)) and (not (math.abs(spawnY - y) <= 2)) then
          if (not shopX or not shopY or (not (math.abs(shopX - x) <= 3)) and (not (math.abs(shopY - y) <= 3))) then
            if not (segment.getSegmentIDAt(x, y) == segment.SECRET_ROOM) then
              if not map.get(x, y) then
                table.insert(candidates, {x=x, y=y})
              end
            end
          end
        end
      end
    end
  end
  return candidates
end

return {
  findOpenFloor=findOpenFloor
}