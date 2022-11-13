local fileIO = require "system.game.FileIO"
local json = require "system.utils.serial.JSON"

local miscUtil = require "dkienenLib.MiscUtil"

function convertDotPathToSlashPath(dotPath)
	return string.gsub(dotPath, "%.", "/")
end

function convertSlashPathToDotPath(slashPath)
	return string.sub(string.gsub(slashPath, "/", "%."), 6, -5)
end

function getBasename(path)
	return string.gsub(path, "(.*/)(.*)", "%2")
end

function getModJSON(modName)
	local path = "mods/" .. modName .. "/mod.json"
	local file = fileIO.readFileToString(path)
	local decodedFile = json.decode(file)
	return decodedFile
end

function getScriptPath(modName)
	return getModJSON(modName)["api"]["scriptPath"]
end

function allScriptsFromPackage(modName, scriptPath)
	local pathPrefix = "mods/" .. modName .. "/" .. getScriptPath(modName) .. "/"
	local pathSuffix = convertDotPathToSlashPath(scriptPath)
	local path = pathPrefix .. pathSuffix
	local listings = fileIO.listFiles(path, fileIO.List.RECURSIVE + fileIO.List.FILES + fileIO.List.FULL_PATH + fileIO.List.SORTED)
	local mappings = {}
	for _, listing in ipairs(listings) do
		local basename = string.sub(getBasename(listing), 1, -5)
		mappings[basename] = require(modName .. "." .. scriptPath .. "." .. basename)
	end
	return mappings
end


return {
	allScriptsFromPackage=allScriptsFromPackage
}
