local Action = require "necro.game.system.Action"
local Entities = require "system.game.Entities"

local Utils = require("AutoNecroDancer.Utils")
local PRIORITY = require("AutoNecroDancer.Targeting").PRIORITY

--[[
	dm in center of board facing down with 7hp, player one above
	down(hit) down down(hit)
	up up up down unside side side up side(hit)
	follow normal plan for most
	on worst case throw at y=-11, then throw again as soon as possible
	on dm2 spawncap with headless skeletons
	on dm3 use bats to spawncap instead
	on dm5 use beholders to block corners

	gold: dm1 make ghost train; kill in corner
	dm2: spawncappinng, gold can go anywhere
	dm3: spawncappinng, gold can go anywhere
	dm4: kill warlocks from spot safe to put gold in
	dm5 beholders easy to lure, lure red ones to lower corners kill blue in upper corners

	dm3
	enter spot with dm (so he goes down)
	kill beetles by align x then y
	if enter right or center kill left beetle
	if enter left kill right beetle
	go to nearest lower corner
--]]
local function deathMetalOverride(player, targets)
	for deathMetal in Entities.entitiesWithComponents({"deathMetalHitTriggers"}) do
		local monsterCount = 0
		for _, target in ipairs(targets) do
			if target.entityID then
				monsterCount = monsterCount + 1
				local entity = Entities.getEntityByID(target.entityID)
				local type = entity.name
				if type == "DeathmetalPhase2" then
					target.priority = PRIORITY.OVERRIDE + 1
					target.override = true
				elseif Utils.stringStartsWith(type, "Deathmetal") then
					target.priority = PRIORITY.OVERRIDE - 1
					target.override = true
				elseif type ~= "Skeleton2Headless" then
					target.priority = PRIORITY.OVERRIDE
					target.override = true
				end
			end
		end
	end
end

return {
	deathMetalOverride = deathMetalOverride
}