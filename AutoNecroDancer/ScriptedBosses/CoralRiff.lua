local Action = require "necro.game.system.Action"
local Direction = Action.Direction
local Entities = require "system.game.Entities"
local Map = require "necro.game.object.Map"
local Utilities = require "system.utils.Utilities"

local Utils = require("AutoNecroDancer.Utils")
local Safety = require("AutoNecroDancer.Safety")
local Pathfinding = require("AutoNecroDancer.Pathfinding")
local Targeting = require("AutoNecroDancer.Targeting")
local PRIORITY = require("AutoNecroDancer.Targeting").PRIORITY

local Snapshot = require "necro.game.system.Snapshot"

-- TODO make scripted boss base class
crPhase = Snapshot.levelVariable(0)
crBeatCounter = Snapshot.levelVariable(0)
previousShadow = Snapshot.levelVariable(false)

local function coralRiffOverride(player, targets)
	for coralRiff in Entities.entitiesWithComponents({ "boss" }) do
		crBeatCounter = crBeatCounter + 1
		if Utils.stringStartsWith(coralRiff.name, "Coralriff") then
			local playerX, playerY = player.position.x, player.position.y
			local extras = {}
			for monster in Entities.entitiesWithComponents({ "health" }) do
				if monster.controllable.playerID == 0 and not monster.playableCharacter and not monster.boss then
					table.insert(extras, monster)
				end
			end
			--[[
				defend corner: dry all water in 3x3 area around corner excluding 2x2 area around corner
				if mons can hit safe then hit mons
				else prio corner, then prio dir with higher dx/dy from CR

				spots to be in before next wave (cr1/2/3):
				-4, -9
				 if vertical hit hit right left right right
				 if horizontal hit hit down/up right right up/down
				 if diag: (towards down) hit (reverse step 1) right left right

				box cr1
					right up left up (down up) * 3 down left
					-- defend lower right
				box cr2
					right up left up left dry right right left right left left right up dry down up
					down down up down up up down up up down right
					-- defend lower right
				box cr3
					right up down down up down right right left right left left up up right up left
					(down up) * 3 down down up down up up right up left left right up up dry up
					-- defend upper right
				star cr1
					right right left right left right up right up dry up dry down down up down up up
					-- defend upper right
				star cr2
					right right left right left right left up right left right up down up down up up
					(down up) * 3 down down up down up up right right left left right right left left
					 right right up up up dry up
					-- defend upper right
				star cr3
					right right down up up down left up right down up up up dry up down up up down up
					down up down up up right dry left up right up dry up dry left dry up dry up dry
					-- defend upper left

				spots to be in before next wave (cr4/5):
				-4, -9; -3, -10; -2, -9; -1, -10; 0, -9
				 if vertical hit both then travel to spot then away form and back (any dir)
				 if horizontal hit both then travel to spot then away form and back (any dir)
				 if diag move right then hit rightmost one then into water then to spot (if not there)

				if box first cr4
					down down throw down up down right right up down up down left (up down)*4
					up up down up up up right right right up right left right left left down left
					right(water) right left right left left right up up up(water) up up(water)
					down up up down up up
					-- defend upper right
				if box first cr5
				 	down down throw down up down right right up up(water) up down left (up down)*4
				 	up up down up up up right right right up right left right left left down left
				 	(right left)*3 left up up up(water) up up(water) down up up down up up
				 	-- defend upper right
				if star first cr4
					down down right down right right right up right left right left up right left right
					up left right left up left left left up left right left right left right left right
					right right left left right left right right
					up right right right(water) right down(water) down up(water) up left
					-- defend lower right
			 	if (star first) cr5
				 	down down right down right right right up right left right left up right left right
				 	up left right left up right left right left up left left left up left right right
				 	left right left right left right right up left down up up
				 	-2, -14
				 	up downs until hit
				 	-- defend lower left
			--]]
		end
	end
end

return {
	coralRiffOverride = coralRiffOverride
}