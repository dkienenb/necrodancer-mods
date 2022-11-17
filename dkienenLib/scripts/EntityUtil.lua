local miscUtil = require "dkienenLib.MiscUtil"
local componentUtil = require "dkienenLib.ComponentUtil"
local customEntities = require "necro.game.data.CustomEntities"
local damage = require "necro.game.system.Damage"

local function registerEntity(modName, template, components, name, data)
	local prefix = miscUtil.makePrefix(modName)
	local registerFunction = "register"
	if not components then components = {} end
	components.gameObject = {}
	components.position = {}
	local wrapComponents = false
	if template then
		registerFunction = "extend"
		wrapComponents = true
	end
	if name then
		componentUtil.registerComponent(modName, name)
		name = prefix .. name
		components[name] = {}
	end
	if wrapComponents then
		customEntities[registerFunction]({template=template, name=name, components=components, data=data})
	else
		components.name = name
		customEntities[registerFunction](components)
	end
end

local function registerMarkerEntity(modName, markerName)
	registerEntity(modName, nil, {}, markerName .. "Marker")
end

local function destroy(entity, deathMessage)
	damage.inflict({victim=entity, killerName=deathMessage, damage=999, damageType=damage.Type.SELF_DESTRUCT})
end

return {
	registerEntity=registerEntity,
	registerMarkerEntity=registerMarkerEntity,
	destroy=destroy
}
