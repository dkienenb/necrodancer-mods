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
local inventory = require "necro.game.item.Inventory"
local itemBan = require "necro.game.item.ItemBan"
local floorDrop = require "dkienenLib.itemProperties.FloorDrop"

local modName = require "dkienenLib.PrefixUtil".getMod()
local prefix = require "dkienenLib.PrefixUtil".prefix()

local oublietteGenerator = require(modName .. ".levelgen")

local RNG_MOLES = rng.Channel.extend(prefix .. "Moles")
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

local grateCount = 6
local abbeyMonsters = {"Armadillo3", "Bat3", "Bat4", "Beetle", "Beetle2", "Blademaster2", "Clone", "Devil2", "ElectricMage3", "Ghoul", "Goblin2", "Harpy", "Lich3", "Mole", "Monkey2", "Monkey3", "Mushroom2", "Orc2", "Orc3", "Skull3", "Skull4", "Sync_CoopThief", "Warlock", "Warlock2", "WaterBall2", "Wraith2"}

local abbeyMiniboss = {"Mommy", "Metrognome2"}

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
		--dbg(ev.entity)
end)

event.levelLoad.add("OublietteTrapdoor", {order = "training"}, function(ev)
	if not currentLevel.isSafe() and currentLevel.getDepth() == 1 and currentLevel.getFloor() == 3 then
		local candidates = findOpenFloor()
		rng.shuffle(candidates, RNG_OUBLIETTE)
		local index = 1
		local chosen = candidates[index]
		index = index + 1
		-- spawn four locks with four other chosens
		oublietteTrapdoorProperties = {x=chosen.x, y=chosen.y}
		local grateComponentName = prefix .. "Grate"
		for _, material in ipairs({"Blood", "Gold", "Obsidian", "Glass"}) do
			local grate = object.spawn(prefix .. material .. "Grate", chosen.x, chosen.y)
			local lockLocation = candidates[index]
			index = index + 1
			local lock = object.spawn(prefix .. material .. "Lock", lockLocation.x, lockLocation.y)
			lock[prefix .. "Lock"].grate = grate
		end
		object.spawn("Sync_CrackTrapdoorOpen", chosen.x, chosen.y)
		object.spawn(prefix .. "OublietteTrapdoorMarker", chosen.x, chosen.y)
	end
end)

event.trapTrigger.override("descend", 1, function (func, ev)
	local trap = ev.trap
	local x = oublietteTrapdoorProperties.x
	local y = oublietteTrapdoorProperties.y
	local victim = ev.victim
	if trap.position.x == x and trap.position.y == y and map.firstWithComponent(x, y, prefix .. "OublietteTrapdoorMarker") and player.isPlayerEntity(victim) then
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

eventUtil.addDepthLevelEvent(modName, "Moles", "extraEntities", 0, nil, eventUtil.makeDepthPredicate(1), function()
	if not currentLevel.isBoss() then
		local candidates = findOpenFloor()
		rng.shuffle(candidates, RNG_MOLES)
		for index, candidate in ipairs(candidates) do
			local x = candidate.x
			local y = candidate.y
			if index > currentLevel.getFloor() * 2 then
				break
			end
			object.spawn("Mole", x, y)
		end
	end
end)

levelSeqUtil.addZone(1.5, "Oubliette", {"Crossing the Chasm.mp3", "Nonstop.mp3", "Oubliette Sting.mp3", "The Complex.mp3"}, oublietteGenerator.generatorID, 4, "Caves-4")

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

stashedItem = snapshot.runVariable(nil)
entityUtil.registerShrine("Time", "Crate3", "WeaponDagger", "Send an item to your next run!", function(ev)
	local items = inventory.getItems(ev.interactor)
	local validItems = {}
	for _, item in ipairs(items) do
		if item.itemCommon then
			table.insert(validItems, item)
		end
	end
	local removed = rng.choice(validItems, RNG_MOLES)
	if not removed then
		ev.entity.shrine.active = false
	else
		stashedItem=removed.name
	end
	object.kill(removed)
end)

eventUtil.addDepthLevelEvent(modName, "TimeShrineItem", "training", 9, nil, eventUtil.makeDepthPredicate(1, 2), function()
	floorDrop.addOneDrop(stashedItem)
end)
