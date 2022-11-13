local miscUtil = require "dkienenLib.MiscUtil"
local components = require "necro.game.data.Components"

local function registerComponent(modName, componentName, args)
	local prefix = miscUtil.makePrefix(modName)
	if not args then
		args = {}
	end
	local compiledArgs = {}
	for name, value in pairs(args) do
		local type = value.type
		local default = value.default
		table.insert(compiledArgs, components.field[type](name, default))
	end
	components.register{
		[prefix..componentName] = compiledArgs
	}
end

return {
	registerComponent = registerComponent
}
