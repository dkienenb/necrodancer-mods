local autoLoad = require "dkienenLib.AutoLoadUtil"

autoLoad.loadMod("SpelunkyGungeonMod")

local object = require "necro.game.object.Object"
local marker = require "necro.game.tile.Marker"
local currentLevel = require "necro.game.level.CurrentLevel"
local player = require "necro.game.character.Player"
local rng = require "necro.game.system.RNG"
local consumable = require "necro.game.item.Consumable"
local map = require "necro.game.object.Map"
local affectorItem = require "necro.game.item.AffectorItem"
local tile = require "necro.game.tile.Tile"
local segment = require "necro.game.tile.Segment"
local snapshot = require "necro.game.system.Snapshot"

local modName = require "dkienenLib.PrefixUtil".getMod()
local prefix = require "dkienenLib.PrefixUtil".prefix()

local oublietteGenerator = require(modName .. ".levelgen")

local RNG_OUBLIETTE = rng.Channel.extend(prefix .. "Oubliette")
local RNG_CHESTPLACEHOLDERS = rng.Channel.extend(prefix .. "ChestPlaceholders")

local hud = require "necro.render.hud.HUD"
local hudLayout = require "necro.render.hud.HUDLayout"
local ui  = require "necro.render.UI"
local minimapTheme = require "necro.game.data.tile.MinimapTheme"

local ecs = require "system.game.Entities"
local Color = require "system.utils.Color"

local itemUtil = require "dkienenLib.ItemUtil"
local componentUtil = require "dkienenLib.ComponentUtil"
local entityUtil = require "dkienenLib.EntityUtil"
local characterUtil = require "dkienenLib.CharacterUtil"
local eventUtil = require "dkienenLib.EventUtil"
local levelSeqUtil = require "dkienenLib.LevelSequenceUtil"

oublietteTrapdoorProperties = snapshot.runVariable({})
oublietteVisit = snapshot.runVariable(false)
oublietteStart = snapshot.variable()

local grateCount = 6
local abbeyMonsters = {"Armadillo3", "Bat3", "Bat4", "Beetle", "Beetle2", "Blademaster2", "Clone", "Devil2", "ElectricMage3", "Ghoul", "Goblin2", "Harpy", "Lich3", "Mole", "Monkey2", "Monkey3", "Mushroom2", "Orc2", "Orc3", "Skull3", "Skull4", "Sync_CoopThief", "Warlock", "Warlock2", "WaterBall2", "Wraith2"}

local abbeyMiniboss = {"Mommy", "Metrognome2"}

local allNonShovelNonWeaponItems = {}

function createGrate(material)
	local name = material .. "Grate"
	local components = {
		positionalSprite={
			offsetY = 12
		},
		rowOrder = {
			z = -99
		},
		visibility={},
		sprite = {texture = "mods/" .. modName .. "/images/level/" .. name .. ".png"},
		minimapStaticPixel = {
			color = Color.rgb(0, 0, 255),
			depth = minimapTheme.Depth.TRAP
		},
		visibilityRevealWhenLit = {},
		visibilityVisibleOnProximity = {},
		silhouette = {},
		visibleByForesight = {}
	}
	entityUtil.registerEntity(modName, nil, components, name)
	grateCount = grateCount + 1
	event.trapTrigger.override("descend", grateCount, function (func, ev)
		if not map.firstWithComponent(ev.trap.position.x, ev.trap.position.y, prefix .. name) then
			return func(ev)
		end
	end)
end

function createLock(material)
	local components = {
		gameObject={},
		positionalSprite={
			offsetY = 12
		},
		rowOrder = {
			z = -9999
		},
		minimapStaticPixel = {
			color = Color.rgb(0, 0, 255) ,
			depth = minimapTheme.Depth.TRAP
		},
		position={},
		sprite={texture = "mods/" .. modName .. "/images/level/" .. material .. "Lock.png"},
		visibility={},
		trap={},
		visibilityRevealWhenLit = {},
		visibilityVisibleOnProximity = {},
		silhouette = {},
		visibleByForesight = {}
	}
	components[prefix .. "Lock"] = {keyComponent=prefix .. material .. "Key"}
	entityUtil.registerEntity(modName, nil, components, material .. "Lock")
	event.trapTrigger.add("Unlock" .. material, {order="delete"}, function (ev)
		local trap = ev.trap
		local victim = ev.victim
		if trap[prefix .. material .. "Lock"] then
			local lock = trap[prefix .. "Lock"]
			local key = lock.keyComponent
			if victim.inventory and affectorItem.entityHasItem(victim, key) then
				object.kill(trap)
				object.kill(ecs.getEntityByID(lock.grate))
				consumable.consume(affectorItem.getItem(victim, key))
			end
		end
	end)
end

function createGrateAndKeyAndLock(material, hint, itemArgs)
	createGrate(material)
	itemArgs.Stack = {}
	itemArgs.Unban = {}
	itemArgs.Slot = {slot="misc"}
	itemArgs.Hint = {hint=hint}
	itemUtil.registerItem(modName, material .. " Key", nil, itemArgs)
	createLock(material)
end

event.objectTakeDamage.add("cookiesssss", {order="spell"}, function(ev)
	if ev.damage > 0 then
		--object.spawn("FoodMagicCookies", ev.entity.position.x, ev.entity.position.y, {})
		--print(ev)
	end
end)

event.entitySchemaLoadNamedEntity.add("debug", {key="ChestRed"}, function (ev)
	--	dbg(ev.entity)
end)

--event.levelSequenceUpdate.add("Oubliette", {order="shuffle", sequence = 4}, function (ev)
--	oublietteStart = 4
--	local generatorID = oublietteGenerator.generatorID
--	table.insert(ev.sequence, oublietteStart, {type=generatorID, floor=1, depth=1.5, zone=1.5})
--	table.insert(ev.sequence, oublietteStart + 1, {type=generatorID, floor=2, depth=1.5, zone=1.5})
--	table.insert(ev.sequence, oublietteStart + 2, {type=generatorID, floor=3, depth=1.5, zone=1.5})
--	table.insert(ev.sequence, oublietteStart + 3, {type=generatorID, floor=4, depth=1.5, zone=1.5})
--end)

--event.levelComplete.add("OublietteWarp", {order="nextLevel"}, function (ev)
--	if ev.targetLevel == oublietteStart and not oublietteVisit then
--		ev.targetLevel = (ev.targetLevel + 4);
--	end
--end)

event.levelLoad.add("OublietteTrapdoor", {order = "training"}, function(ev)
	if not currentLevel.isSafe() and currentLevel.getDepth() == 1 and currentLevel.getFloor() == 3 then
		local candidates = {}
		local levelX, levelY, levelWidth, levelHeight = tile.getLevelBounds()
		local spawnX, spawnY = marker.lookUpMedian(marker.Type.SPAWN)
		if not spawnX then spawnX = 0 end
		if not spawnY then spawnY = 0 end
		local shopX, shopY = marker.lookUpMedian(marker.Type.SHOP)
		for y = levelY, levelY + levelHeight - 1 do
			for x = levelX, levelX + levelWidth - 1 do
				if tile.getInfo(x, y).name == "Floor" then
					if (not (math.abs(spawnX - x) <= 1)) and (not (math.abs(spawnY - y) <= 1)) then
						if (not (math.abs(shopX - x) <= 3)) and (not (math.abs(shopY - y) <= 3)) then
							if not (segment.getSegmentIDAt(x, y) == segment.SECRET_ROOM) then
								if not map.get(x, y) then
									table.insert(candidates, {x=x, y=y})
								end
							end
						end
					end
				end
			end
		end
		rng.shuffle(candidates, RNG_OUBLIETTE)
		local index = 1
		local chosen = candidates[index]
		index = index + 1
		-- spawn four locks with four other chosens
		object.spawn("Sync_CrackTrapdoorOpen", chosen.x, chosen.y)
		object.spawn(prefix .. "OublietteTrapdoorMarker", chosen.x, chosen.y)
		oublietteTrapdoorProperties = {x=chosen.x, y=chosen.y}
		local grateComponentName = prefix .. "Grate"
		for _, material in ipairs({"Blood", "Gold", "Obsidian", "Glass"}) do
			local grate = object.spawn(prefix .. material .. "Grate", chosen.x, chosen.y)
			local lockLocation = candidates[index]
			index = index + 1
			local lock = object.spawn(prefix .. material .. "Lock", lockLocation.x, lockLocation.y)
			lock[prefix .. "Lock"].grate = grate
		end
	end
end)

event.trapTrigger.override("descend", 1, function (func, ev)
	local trap = ev.trap
	local x = oublietteTrapdoorProperties.x
	local y = oublietteTrapdoorProperties.y
	local victim = ev.victim
	if trap.position.x == x and trap.position.y == y and map.firstWithComponent(x, y, prefix .. "OublietteTrapdoorMarker") and player.isPlayerEntity(victim) then
		oublietteVisit = true
		levelSeqUtil.overrideWarp("Oubliette-1")
	end
	return func(ev)
end)

event.levelLoad.add("ChestPlaceholders", {order = "initialItems"}, function(ev)
	for entity in ecs.entitiesWithComponents {prefix .. "ChestPlaceholderMarker"} do
		object.spawn("Chest" .. rng.choice({"Red", "Black", "Purple"}, RNG_CHESTPLACEHOLDERS), entity.position.x, entity.position.y)
		object.kill(entity)
	end
end)

levelSeqUtil.addZone(1.5, "Oubliette", {"Crossing the Chasm.mp3", "Nonstop.mp3", "Oubliette Sting.mp3", "The Complex.mp3"}, oublietteGenerator.generatorID, "1-4", 4)

characterUtil.registerCharacter(modName, "Guy Spelunky", {"WeaponWhip", "Bomb3", "Bomb"}, "Contains the correct amount\nof digging tools!", {shovel=true})

componentUtil.registerComponent(modName, "Lock", {grate={type="entityID"}, keyComponent={type="string"}})

entityUtil.registerMarkerEntity(modName, "OublietteTrapdoor")
entityUtil.registerMarkerEntity(modName, "ChestPlaceholder")

createGrateAndKeyAndLock("Blood", "More health, regenerate health", {FloorDrop={depth=1, floor=1}, Breakable={depth={depth=3, floor=2}}, BloodRegen={}, HealthIncrease={}})
createGrateAndKeyAndLock("Glass", "Breaks on hit, +3 damage", {Purchasable={price={coins=48, blood=4}, secretShopWeights={0, 0, 999999, 999999, 0}}, Failsafe={shop={depth=1, floor=2}}, Breakable={damage=true}, DamageIncrease={amount=3}})
createGrateAndKeyAndLock("Gold", "Breaks on purchase, more money", {Purchasable={price={coins=110}, shopWeights={0, 999999, 0}, lockedShopWeights={0, 999999, 0}},  Failsafe={shop={depth=1, floor=3}}, Breakable={purchase=true}}, {GoldIncrease={}})
createGrateAndKeyAndLock("Obsidian", "Missed beat breaks, +1 multiplier", {Failsafe={drop={depth=1, floor=3, components="enemyPoolMiniboss"}}, Breakable={missedBeat=true}, MultiplierIncrease={}})

itemUtil.registerItem(modName, "Udjat Eye", "head_monocle", {Slot={}, Hint={hint="Reveals secrets"}, Unban=true})
itemUtil.registerItem(modName, "Worm Food", nil, {Slot={}, Hint={hint="Nom nom!"}, Unban=true})
itemUtil.registerItem(modName, "Old Crest", nil, {Slot={}, Hint={hint="Prevents damage once"}, Unban=true, DamageBlock={}})

itemUtil.registerItem(modName, "Escape Rope", nil, {Slot={slot="action"}, Hint={hint="Teleports you to the shop"}, Spell={spell="SpellcastCrownOfTeleportation", cooldown=20}})
