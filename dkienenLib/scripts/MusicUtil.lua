local currentLevel = require "necro.game.level.CurrentLevel"

local trackMappings = {}

function setMusic(modName, depth, floor, track)
    table.insert(trackMappings, {modName=modName, depth=depth, floor=floor, track=track})
end

event.musicTrack.add("CustomMusic", {order = "assetMods"}, function (ev)
    local currentDepth = currentLevel.getDepth()
    local currentFloor = currentLevel.getFloor()
    for _, entry in ipairs(trackMappings) do
        local depth = entry.depth
        local floor = entry.floor
        local modName = entry.modName
        local track = entry.track
        if depth == currentDepth and floor == currentFloor then
            ev.beatmap = "mods/" .. modName .. "/music/" .. track .. ".txt"
            ev.originalBeatmap = "mods/" .. modName .. "/music/" .. track .. ".txt"
            ev.layers[1].file = "mods/" .. modName .. "/music/" .. track
            ev.layers[1].originalFile = "mods/" .. modName .. "/music/" .. track
            ev.layers[2] = nil
            ev.vocals = nil
        end
    end
end)

return {
    setMusic=setMusic
}