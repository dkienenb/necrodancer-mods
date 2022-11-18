local miscUtil = require "dkienenLib.MiscUtil"
local componentUtil = require "dkienenLib.ComponentUtil"
local customEntities = require "necro.game.data.CustomEntities"
local damage = require "necro.game.system.Damage"
local object = require "necro.game.object.Object"

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

local function destroy(entity, deathMessage, attacker)
	damage.inflict({victim=entity, killerName=deathMessage, attacker=attacker, damage=999, type=damage.Type.PHASING})
	--if not entity.killable.dead then
	--	object.kill(entity)
	-- end
end

return {
	registerEntity=registerEntity,
	registerMarkerEntity=registerMarkerEntity,
	destroy=destroy
}
