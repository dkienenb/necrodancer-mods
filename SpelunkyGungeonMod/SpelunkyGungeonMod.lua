local object = require "necro.game.object.Object"
local customEntities = require "necro.game.data.CustomEntities"
local marker = require "necro.game.tile.Marker"
local currentLevel = require "necro.game.level.CurrentLevel"
local priceTag = require "necro.game.item.PriceTag"
local itemGeneration = require "necro.game.item.ItemGeneration"
local currency = require "necro.game.item.Currency"
local player = require "necro.game.character.Player"
local rng = require "necro.game.system.RNG"
local consumable = require "necro.game.item.Consumable"
local components = require "necro.game.data.Components"
local map = require "necro.game.object.Map"
local affectorItem = require "necro.game.item.AffectorItem"
local damage = require "necro.game.system.Damage"
local boss = require "necro.game.level.Boss"
local tile = require "necro.game.tile.Tile"
local commonTrap = require "necro.game.data.trap.CommonTrap"
local segment = require "necro.game.tile.Segment"
local snapshot = require "necro.game.system.Snapshot"
local inventory = require "necro.game.item.Inventory"
local levelSequence = require "necro.game.level.LevelSequence"
local oublietteGenerator = require "SpelunkyGungeonMod.levelgen"

local modName = "SpelunkyGungeonMod"
local prefix = modName .. "_"
local RNG_RANDOMDROPS = rng.Channel.extend(prefix .. "RandomDrops")
local RNG_PARADOX = rng.Channel.extend(prefix .. "Paradox")
local RNG_OUBLIETTE = rng.Channel.extend(prefix .. "Oubliette")
local RNG_CHESTPLACEHOLDERS = rng.Channel.extend(prefix .. "ChestPlaceholders")

local hud = require "necro.render.hud.HUD"
local hudLayout = require "necro.render.hud.HUDLayout"
local localization = require "system.i18n.Localization"
local ui  = require "necro.render.UI"

local ecs = require "system.game.Entities"
local Color = require "system.utils.Color"

local itemUtil = require "dkienenLib.ItemUtil"
local componentUtil = require "dkienenLib.ComponentUtil"
local entityUtil = require "dkienenLib.EntityUtil"
local characterUtil = require "dkienenLib.CharacterUtil"
local eventUtil = require "dkienenLib.EventUtil"

oublietteTrapdoorProperties = snapshot.runVariable({})
oublietteVisit = snapshot.runVariable(false)
oublietteStart = snapshot.variable()

local grateCount = 6
local gunslingerSubstitutions = {}
local abbeyMonsters = {"Armadillo3", "Bat3", "Bat4", "Beetle", "Beetle2", "Blademaster2", "Clone", "Devil2", "ElectricMage3", "Ghoul", "Goblin2", "Harpy", "Lich3", "Mole", "Monkey2", "Monkey3", "Mushroom2", "Orc2", "Orc3", "Skull3", "Skull4", "Sync_CoopThief", "Warlock", "Warlock2", "WaterBall2", "Wraith2"}

local abbeyMiniboss = {"Mommy", "Metrognome2"}

local allNonShovelNonWeaponItems = {}

local doubleParadoxMap = {}

local bossID = boss.Type.extend("Blobulord")
entityUtil.registerEntity(modName, customEntities.template.enemy("slime", 8), {
	boss = {type=bossID},
	Sync_enemyPoolBoss={},
	health = {
		maxHealth = 10,
		health = 10
	}
}, "Blobulord")


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
		sprite = {texture = "mods/SpelunkyGungeonMod/images/level/" .. name .. ".png"},
		minimapStaticPixel = {
			color = Color.rgb(0, 255, 255),
			depth = 5
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
			color = Color.rgb(0, 255, 255) ,
			depth = 5
		},
		position={},
		sprite={texture = "mods/SpelunkyGungeonMod/images/level/" .. material .. "Lock.png"},
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
				object.delete(affectorItem.getItem(victim, key))
			end
		end
	end)
end

function createGrateAndKeyAndLock(material, hint, itemArgs)
	createGrate(material)
	itemArgs.Stack = {}
	itemArgs.Unban = {}
	itemUtil.registerItem(modName, material .. " Key", nil, hint, "misc", itemArgs)
	createLock(material)
end

--event.objectTakeDamage.add("cookiesssss", {order="spell"}, function(ev)
--	if ev.damage > 0 then
--		object.spawn("FoodMagicCookies", ev.entity.position.x, ev.entity.position.y, {})
--end)
--	end

event.entitySchemaLoadNamedEntity.add("debug", {key="Trainingsarcophagus"}, function (ev)
--	dbg(ev.entity)
end)

event.levelSequenceUpdate.add("Oubliette", {order="shuffle", sequence = 4}, function (ev)
	oublietteStart = 4
	local generatorID = oublietteGenerator.generatorID
	table.insert(ev.sequence, oublietteStart, {type=generatorID, floor=1, depth=1.5, zone=1.5})
	table.insert(ev.sequence, oublietteStart + 1, {type=generatorID, floor=2, depth=1.5, zone=1.5})
	table.insert(ev.sequence, oublietteStart + 2, {type=generatorID, floor=3, depth=1.5, zone=1.5})
	table.insert(ev.sequence, oublietteStart + 3, {type=generatorID, floor=4, depth=1.5, zone=1.5, boss=bossID})
	print(ev)
end)

event.levelComplete.add("OublietteWarp", {order="nextLevel"}, function (ev)
	if ev.targetLevel == oublietteStart and not oublietteVisit then
		ev.targetLevel = (ev.targetLevel + 4);
	end
end)

event.entitySchemaLoadNamedEntity.add("generateGunslingerSubstitions", {order = "finalize"}, function (ev)
	local entity = ev.entity
	if entity and entity.health and not entity.crateLike then
		if entity.health.health == 1 then
			gunslingerSubstitutions[entity.name] = "Lich"
		end
		if entity.health.health == 2 then
			gunslingerSubstitutions[entity.name] = "Lich2"
		end
		if entity.health.health == 3 then
			gunslingerSubstitutions[entity.name] = "Lich3"
		end
	end
end)

event.entitySchemaLoadNamedEntity.add("registerItemsForParadox", {order = "finalize"}, function (ev)
	local entity = ev.entity
	if entity and entity.item then
		if entity.itemSlot then
			if entity.itemSlot.name ~= "shovel" and entity.itemSlot.name ~= "weapon" then
				table.insert(allNonShovelNonWeaponItems, entity.name)
			end
			if not doubleParadoxMap[entity.itemSlot.name] then
				doubleParadoxMap[entity.itemSlot.name] = {}
			end
			table.insert(doubleParadoxMap[entity.itemSlot.name], entity.name)
		end
	end
end)

eventUtil.addLevelEvent("lichSubstitutions", "enemySubstitutions", -1, {prefix .. "LichsEyeBullets"}, function (entity, event)
	local holder = ecs.getEntityByID(entity.item.holder)
	if player.isPlayerEntity(holder) then
		for _, entity in ipairs(event.entities) do
			if gunslingerSubstitutions[entity.type] then
				entity.type = gunslingerSubstitutions[entity.type]
			end
		end
	end
end)

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
	end
	return func(ev)
end)

event.levelLoad.add("SpeedrunnerTrapdoor", {order = "training", sequence = 1}, function(ev)
	if not currentLevel.isSafe() and not currentLevel.isBoss() and player.firstWithComponent(prefix .. "Speedrunner") then
		local spawnX, spawnY = marker.lookUpMedian(marker.Type.SPAWN)
		if not spawnX then spawnX = 0 end
		if not spawnY then spawnY = 0 end
		for xOffset = -2, 2 do
			for yOffset = -2, 2 do
				object.spawn("Trapdoor", spawnX + xOffset, spawnY + yOffset)
			end
		end
	end
end)

event.levelLoad.add("HunterKill", {order = "spawnPlayers", sequence = 3}, function(ev)
	for hunter in ecs.entitiesWithComponents {prefix .. "Hunter"} do
		if not currentLevel.isSafe() and not (affectorItem.entityHasItem(hunter, prefix .. "HunterSoul")) and not ((currentLevel.getFloor() == 1) and (currentLevel.getDepth() == 1)) then
			object.kill(hunter, nil, "Hunter's curse")
		end
	end
end)

event.levelLoad.add("HackerRemovals", {order = "training", sequence = 99999}, function(ev)
	local hacker = player.firstWithComponent(prefix .. "1337h4x0r")
	if not currentLevel.isSafe() and hacker then
		for entity in ecs.entitiesWithComponents {"gameObject", "health"} do
			if not (entity.controllable and entity.controllable.playerID ~= 0) then
				object.kill(entity, hacker, "]")
			end
		end
	end
end)

event.levelLoad.add("ParadoxItems", {order = "initialItems"}, function(ev)
	if not currentLevel.isSafe() and (currentLevel.getDepth() == 1) and (currentLevel.getFloor() == 1) then
		for _, paradox in ipairs(player.getPlayerEntities()) do
			if paradox[prefix .. "Paradox"] or paradox[prefix .. "DoubleParadox"] then
				local spawnX, spawnY = marker.lookUpMedian(marker.Type.SPAWN)
				local item = rng.choice(allNonShovelNonWeaponItems, RNG_PARADOX)
				local weapon = rng.choice(doubleParadoxMap.weapon, RNG_PARADOX)
				local shovel = rng.choice(doubleParadoxMap.shovel, RNG_PARADOX)
				inventory.grant(item, paradox, true)
				inventory.grant(weapon, paradox, true)
				inventory.grant(shovel, paradox, true)
			end
		end
	end
end)

event.levelLoad.add("DoubleParadoxItems", {order = "initialItems"}, function(ev)
	if not currentLevel.isSafe() and (currentLevel.getDepth() ~= 1) and (currentLevel.getFloor() == 1) then
		for _, paradox in ipairs(player.getPlayerEntities()) do
			if paradox[prefix .. "DoubleParadox"] then
				for _, item in ipairs(inventory.getItems(paradox)) do
					if item.itemSlot and doubleParadoxMap[item.itemSlot.name] then
						local choice = rng.choice(doubleParadoxMap[item.itemSlot.name], RNG_PARADOX)
						object.kill(item);
						inventory.grant(choice, paradox, true)
					end
				end
			end
		end
	end
end)

event.levelLoad.add("ChestPlaceholders", {order = "initialItems"}, function(ev)
	for entity in ecs.entitiesWithComponents {prefix .. "ChestPlaceholderMarker"} do
		object.spawn("Chest" .. rng.choice({"Red", "Black", "Purple"}, RNG_CHESTPLACEHOLDERS), entity.position.x, entity.position.y)
		object.kill(entity)
	end
end)

event.renderGlobalHUD.override("renderLevelCounter", 1, function(func, ev)
	local text

	local depth, floor, boss = currentLevel.getDepth(), currentLevel.getFloor(), currentLevel.isBoss()

	if depth == 1.5 then
		depth = "Oubliette"
	end

	text = localization.format("render.levelCounterHUD.depthLevel",
			"Depth: %s  Level: %s",
			depth,
			boss and localization.get("render.levelCounterHUD.boss") or floor)
	hud.drawText {
		text = text,
		font = ui.Font.SMALL,
		element = hudLayout.Element.LEVEL,
		alignX = 1,
		alignY = 1
	}
end)

event.musicTrack.add("OublietteMusic", {order = "assetMods"}, function (ev)
	local depth = currentLevel.getDepth()
	local floor = currentLevel.getFloor()
	if depth == 1.5 then
		local track
		if floor == 1 then
			track = "Crossing the Chasm.mp3"
		end
		if floor == 2 then
			track = "Nonstop.mp3"
		end
		if floor == 3 then
			track = "Oubliette Sting.mp3"
		end
		if floor == 4 then
			track = "Oubliette Sting.mp3"
		end
		ev.beatmap = "mods/" .. modName .. "/music/" .. track .. ".txt"
		ev.originalBeatmap = "mods/" .. modName .. "/music/" .. track .. ".txt"
		ev.layers[1].file = "mods/" .. modName .. "/music/" .. track
		ev.layers[1].originalFile = "mods/" .. modName .. "/music/" .. track
		ev.layers[2] = nil
		ev.vocals = nil
	end
end)

characterUtil.registerCharacter(modName, "1337h4x0r", nil, "", nil, "]")
characterUtil.registerCharacter(modName, "Double Paradox", {"Bomb"}, "Randomize your items every zone!")
characterUtil.registerCharacter(modName, "Hunter", {"ShovelBasic","WeaponCrossbow","Bomb","HeadCircletTelepathy"}, "Locate and kill your\ntarget monster every floor,\nor die.")
characterUtil.registerCharacter(modName, "Gunslinger", {"ShovelBasic", "WeaponDagger", "Bomb", "SpelunkyGungeonMod_LichsEyeBullets"}, "Defeat the lich(es)!")
characterUtil.registerCharacter(modName, "Guy Spelunky", {"WeaponWhip", "Bomb3", "Bomb"}, "Contains the correct amount\nof digging tools!", {shovel=true})
characterUtil.registerCharacter(modName, "Paradox", {"Bomb"}, "Start with random items!")
characterUtil.registerCharacter(modName, "Speedrunner", nil, "Simulate the power\nof a good gaming chair!")

componentUtil.registerComponent(modName, "Lock", {grate={type="entityID"}, keyComponent={type="string"}})

entityUtil.registerMarkerEntity(modName, "OublietteTrapdoor")
entityUtil.registerMarkerEntity(modName, "ChestPlaceholder")

createGrateAndKeyAndLock("Blood", "More health, regenerate health", {FloorDrop={depth=1, floor=1}, Breakable={depth={depth=3, floor=2}}, BloodRegen={}, HealthIncrease={}})
createGrateAndKeyAndLock("Glass", "Breaks on hit, +3 damage", {Purchasable={price={coins=48, blood=4}, secretShopWeights={999999}}, Failsafe={shop={depth=1, floor=2}}, Breakable={damage=true}, DamageIncrease={amount=3}})
createGrateAndKeyAndLock("Gold", "Breaks on purchase, more money", {Purchasable={price={coins=110}, shopWeights={0, 999999, 0}, lockedShopWeights={0, 999999, 0}},  Failsafe={shop={depth=1, floor=3}}, Breakable={purchase=true}}, {GoldIncrease={}})
createGrateAndKeyAndLock("Obsidian", "Missed beat breaks, +1 multiplier", {Failsafe={drop={depth=1, floor=3, components="enemyPoolMiniboss"}}, Breakable={missedBeat=true}, MultiplierIncrease={}})

itemUtil.registerItem(modName, "Udjat Eye", "head_monocle", "Reveals secrets", "misc", {Unban=true})
itemUtil.registerItem(modName, "Worm Food", nil, "Nom nom!", "misc", {Unban=true})
itemUtil.registerItem(modName, "Old Crest", nil, "Prevents damage once", "misc", {Unban=true, DamageBlock={}})

itemUtil.registerItem(modName, "Hunter Soul", nil, "Target down!", "misc", {FloorDrop={requiredPlayerComponent = prefix .. "Hunter"}, Stack={}, Breakable={sound="drinkPotion", depth={}, requiredComponent = prefix .. "Hunter"}})
itemUtil.registerItem(modName, "Lich's Eye Bullets", nil, "More liches", "misc", {})
