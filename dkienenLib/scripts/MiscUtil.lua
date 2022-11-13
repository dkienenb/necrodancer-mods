function makeProperIdentifier(name)
	name = string.gsub(name, "%s+", "")
	name = string.gsub(name, "'+", "")
	return name
end

function makePrefix(modName)
	return modName .. "_"
end

return {
	makeProperIdentifier=makeProperIdentifier,
	makePrefix = makePrefix
}
