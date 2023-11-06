local Action = require "necro.game.system.Action"
local Boss = require "necro.game.level.Boss"
local ClientActionBuffer = require "necro.client.ClientActionBuffer"
local Entities = require "system.game.Entities"
local LevelGenerator = require "necro.game.level.LevelGenerator"
local Map = require "necro.game.object.Map"
local Netplay = require "necro.network.Netplay"
local PlayerList = require "necro.client.PlayerList"
local Resources = require "necro.client.Resources"
local Snapshot = require "necro.game.system.Snapshot"
local Sound = require "necro.audio.Sound"
local Turn = require "necro.cycles.Turn"

local Direction = Action.Direction
local UP = Direction.UP
local LEFT = Direction.LEFT
local RIGHT = Direction.RIGHT
local DOWN = Direction.DOWN

event.entitySchemaLoadPlayer.add("debugBard", "overrides", function(ev)
	local entity = ev.entity
	entity.rhythmIgnored  = {}
end)

local function generateLevel(playerID)
	local level = LevelGenerator.generate({ depth = 1, type = LevelGenerator.Type.Boss, boss = Boss.Type.DEEP_BLUES, initialCharacters = { [playerID] = "Monk" } })
	return level
end

local function overrideLevel()
	local playerID = PlayerList.getLocalPlayerID()
	Resources.upload(Netplay.Resource.DUNGEON, nil, {
		options = { initialCharacters = { [playerID] = "Monk" } },
		levels = { generateLevel(playerID) },
	})
end

local function simulateInput(action)
	local playerID = PlayerList.getLocalPlayerID()
	ClientActionBuffer.addAction(playerID, Turn.getCurrentTurnID(), action, 0)
	Turn.process()
end

-- openingType: b(ongcloud) n(ormal) l(eft knight) r(ight knight)
local function hashOpening(depth, pawnsLeftOrdered, startingPawn, openingType, pieceUpgrades)
	local leftOrderedChar = pawnsLeftOrdered and "L" or "R"
	local startingPawnChar = startingPawn + 4
	local hash = depth .. leftOrderedChar .. startingPawnChar .. openingType
	for pieceX in pairs(pieceUpgrades) do
		hash = hash .. (pieceX + 4)
	end
	return hash
end

local function reset(depth, pawnsLeftOrdered, startingPawn, openingType, pieceUpgrades, entranceType)
	event.gameStateReset.fire {}
	event.gameStateLevel.fire { level = 1 }
	local pawnDelay = 0
	local pawnX = startingPawn
	local leftKnight = Map.firstWithComponent(-2, -14, "health")
	local rightKnight = Map.firstWithComponent(3, -14, "health")
	if openingType == "l" then
		leftKnight.beatDelay.counter = 0
		rightKnight.beatDelay.counter = 5
		pawnDelay = 1
	elseif openingType == "r" then
		leftKnight.beatDelay.counter = 5
		rightKnight.beatDelay.counter = 0
		pawnDelay = 1
	else
		leftKnight.beatDelay.counter = 3
		rightKnight.beatDelay.counter = 5
	end
	local king = Map.firstWithComponent(0, -14, "health")
	if openingType == "b" then
		king.Sync_deepBluesStrategicOpening.strategy = 1
		king.beatDelay.counter = 1
	else
		king.beatDelay.counter = 8
		king.Sync_deepBluesStrategicOpening.strategy = 0
	end
	for _ = 1,8 do
		local pawn = Map.firstWithComponent(pawnX, -13, "health")
		pawn.beatDelay.counter = pawnDelay
		pawnDelay = pawnDelay + 1
		if pawnsLeftOrdered then
			pawnX = pawnX - 1
			if pawnX == -4 then
				pawnX = 4
			end
		else
			pawnX = pawnX + 1
			if pawnX == 5 then
				pawnX = -3
			end
		end
	end
	for _ = 1, 7 do
		simulateInput(UP)
	end
	if entranceType == "left" then
		simulateInput(LEFT)
	end
	if entranceType == "right" then
		simulateInput(RIGHT)
	end
	simulateInput(UP)
end

local function isValidDirection(direction, player)
	for entity in Entities.entitiesWithComponents({"beatDelay"}) do
		--dbg(entity.beatDelay.counter)
	end
	return true
end

local function getNextDirection(player)
	local choices = { Action.Direction.UP, Action.Direction.LEFT, Action.Direction.RIGHT, Action.Direction.DOWN }
	for _, direction in ipairs(choices) do
		if isValidDirection(direction, player) then
			return direction
		end
	end
end

local function runTests(player)
	dbg("Running tests")
	overrideLevel()
	local oldSoundVolume = Sound.getSoundVolume()
	Sound.setSoundVolume(0)
	while true do
		reset(1, true, 0, "l", {}, "left")
		while true do
			local direction = getNextDirection(player)
			if direction then
				simulateInput(direction)
			end
			break
		end
		break
	end
	--for (each possible opening) do
	--	reset()
	---- do tests here
	--end

	Sound.resetGameSounds()
	Sound.setSoundVolume(oldSoundVolume)
end

event.shrine.add("testing", {}, function (ev)
	runTests(ev.entity)
end)

-- TODO info that matters
--[[
key (hashed)
opening
- left/right (1 bit)
- which pawn (3 bits)
- type: (2 bits)
-- normal 00
-- left knight 01
-- right knight 10
-- bongcloud 11
- player moves

value (hashed? raw table?)
valid moves left
previous key
previous move
--]]