local Action = require "necro.game.system.Action"
local Entities = require "system.game.Entities"

local Utils = require("AutoNecroDancer.Utils")
local PRIORITY = require("AutoNecroDancer.Targeting").PRIORITY

local function deathMetalOverride(player, targets)
	for deathMetal in Entities.entitiesWithComponents({"deathMetalHitTriggers"}) do
		if deathMetal.name ~= "DeathmetalPhase4" then
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
end

return {
	deathMetalOverride = deathMetalOverride
}