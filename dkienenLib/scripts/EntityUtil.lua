local miscUtil = require "dkienenLib.MiscUtil"
local eventUtil = require "dkienenLib.EventUtil"
local prefixUtil = require "dkienenLib.PrefixUtil"
local componentUtil = require "dkienenLib.ComponentUtil"

local commonSpell = require "necro.game.data.spell.CommonSpell"
local commonShrine = require "necro.game.data.object.CommonShrine"
local customEntities = require "necro.game.data.CustomEntities"
local damage = require "necro.game.system.Damage"
local object = require "necro.game.object.Object"
local marker = require "necro.game.tile.Marker"

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

--componentUtil.registerComponent(prefixUtil.getMod(), "Placeholder", {entity={type="entityID"}})
--local function registerPlaceholder(name)
--
--end

local function registerMarkerEntity(modName, markerName)
	registerEntity(modName, nil, {}, markerName .. "Marker")
end

local function destroy(entity, deathMessage, attacker)
	damage.inflict({victim=entity, killerName=deathMessage, attacker=attacker, damage=999, type=damage.Type.PHASING})
	if entity.killable and not entity.killable.dead then
		damage.inflict({victim=entity, killerName=deathMessage, attacker=attacker, damage=999, type=damage.Type.SELF_DESTRUCT})
	end
end

local function lookupMarker(markerType)
	return marker.lookUpMedian(marker.Type[markerType])
end

local function surroundPosition(x, y, radius, thing)
	if not x then x = 0 end
	if not y then y = 0 end
	for xOffset = -radius, radius do
		for yOffset = -radius, radius do
			object.spawn(thing, x + xOffset, y + yOffset)
		end
	end
end

local function surroundEntity(entity, radius, thing)
	local pos = entity.position
	if pos and pos.x and pos.y then
		surroundPosition(pos.x, pos.y, radius, thing)
	end
end

local function registerShrine(name, inactiveDrop, activeDrop, hint, action)
	commonShrine.registerShrine(name, {
		shrine = {
			inactiveDrop = {inactiveDrop},
			activeDrop = {activeDrop},
		},
		shrineHintLabel = { text = hint },
		sprite = {
			texture="mods/" .. prefixUtil.getMod() .. "/images/shrines/ShrineOf" .. name .. ".png"
		},
	})
	event.shrine.add(prefixUtil.getMod() .. name, name, action)
end

local function registerSpellCast(spellName, spellEffect)
	componentUtil.registerComponent(prefixUtil.getMod(), spellName)
	commonSpell.registerSpell("Spellcast" .. spellName, {
		spellcast = {},
		spellcastFlyaway = {
			text = spellName
		}
	})
	eventUtil.addEvent("spellcast", "Spellcast" .. spellName, nil, nil, spellEffect, prefixUtil.getMod() .. spellName)
end

return {
	registerEntity=registerEntity,
	registerMarkerEntity=registerMarkerEntity,
	destroy=destroy,
	surroundPosition=surroundPosition,
	lookupMarker=lookupMarker,
	surroundEntity=surroundEntity,
	registerShrine=registerShrine,
	registerSpellCast=registerSpellCast
}
