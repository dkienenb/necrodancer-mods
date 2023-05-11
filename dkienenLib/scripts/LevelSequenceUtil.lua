local snapshot = require "necro.game.system.Snapshot"
local musicUtil = require "dkienenLib.MusicUtil"
local eventUtil = require "dkienenLib.EventUtil"
local currentLevel = require "necro.game.level.CurrentLevel"
local utils = require "system.utils.Utilities"
local hud = require "necro.render.hud.HUD"
local hudLayout = require "necro.render.hud.HUDLayout"
local ui  = require "necro.render.UI"

levels = snapshot.variable(nil)
append = snapshot.variable({})
sequenceOffset = snapshot.runVariable(0)
warpLevelOverride = snapshot.runVariable(nil)

eventUtil.addEvent("levelSequenceUpdate", "levelSequenceUtilOffset", "initAllZones", -1, function (ev)
  sequenceOffset = ev.offset
end)

eventUtil.addEvent("levelSequenceUpdate", "levelSequenceUtilInject", "shuffle", 1, function (ev)
  local levels = ev.sequence
  local levelCount = #levels
  if levelCount > 2 then
    for offset, level in ipairs(levels) do
      level.name = level.depth .. "-" .. level.floor
      level.index = offset + sequenceOffset
      if offset ~= levelCount and not level.nextLevel then
        level.nextLevel = level.index + 1
      end
    end
  end
end)

local function findLevelByIndex(index)
  local found
  for _, level in ipairs(levels) do
    if index == level.index then
      found = level
    end
  end
  return found
end

local function findLevel(name)
  local found
  for _, level in ipairs(levels) do
    if name == level.name then
      found = level
    end
  end
  return found
end

local function overrideWarp(levelName)
  print("lName: " .. levelName)
  local found = findLevel(levelName)
  print("found: ")
  print(found)
  warpLevelOverride = found.index
  print("after set: " .. warpLevelOverride)
end

eventUtil.addEvent("levelSequenceUpdate", "levelSequenceUtilInsert", "shuffle", 2, function (ev)
  levels = ev.sequence
  if #levels > 2 then
    for _, newLevel in ipairs(append) do
      local index = levels[#levels].index + 1
      local found = findLevel(newLevel.nextLevel)
      local nextLevel = found.index
      local displayName = newLevel.displayName
      local depth = newLevel.depth
      local zone = newLevel.zone
      local floor = newLevel.floor
      local type = newLevel.generator
      table.insert(levels, {depth=depth, floor=floor, zone=zone, type=type, name=displayName, nextLevel=nextLevel, index=index})
    end
  end
  levels = utils.deepCopy(ev.sequence)
  --print(levels)
end)

eventUtil.addEvent("levelComplete", "levelWarp", "nextLevel", -2, function (ev)
  local index = currentLevel.getNumber()
  for _, level in ipairs(levels) do
    if level and index == level.index then
      ev.targetLevel = level.nextLevel
    end
    print(warpLevelOverride)
    if warpLevelOverride then
      ev.targetLevel = warpLevelOverride
      warpLevelOverride = nil
    end
  end
end)

eventUtil.addLevelEvent(nil, "resetWarp", "runState", 0, nil, function()
  warpLevelOverride = nil
end)

local function addFloor(depthNumber, floorNumber, displayName, music, generator, nextLevel)
  musicUtil.setMusic(depthNumber, floorNumber, music)
  utils.removeIf(append, function(value)
    return value.displayName == displayName
  end)
  table.insert(append, { depth= depthNumber, floor=floorNumber, generator=generator, nextLevel=nextLevel, displayName=displayName})
end

local function addZone(depthNumber, displayName, music, generator, nextLevel, length)
  for floor = length, 1, -1 do
    local floorNextLevel = floor == length and nextLevel or displayName .. "-" .. floor + 1
    addFloor(depthNumber, floor, displayName .. "-" .. floor, music[floor], generator, floorNextLevel)
  end
  for level, trackName in ipairs(music) do
    musicUtil.setMusic(depthNumber, level, trackName, true)
  end
end

event.renderGlobalHUD.override("renderLevelCounter", 1, function()
  local text = findLevelByIndex(currentLevel.getNumber()).name
  hud.drawText {
    text = text,
    font = ui.Font.SMALL,
    element = hudLayout.Element.LEVEL,
    alignX = 1,
    alignY = 1
  }
end)

return {
  addZone=addZone,
  overrideWarp=overrideWarp
}