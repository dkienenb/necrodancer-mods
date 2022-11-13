local consumable = require "necro.game.item.Consumable"
local componentUtil = require "dkienenLib.ComponentUtil"
local affectorItem = require "necro.game.item.AffectorItem"
local player = require "necro.game.character.Player"
local currentLevel = require "necro.game.level.CurrentLevel"
local ecs = require "system.game.Entities"

function apply(components, args, name)
	local defaultBreakText = name .. " shatters!"
	local defaultSound = "glassBreak"
	if args then
		if args.damage then
			components.itemConsumeOnIncomingDamage = {}
		end
		if args.missedBeat then
			components.itemConsumeOnMissedBeat = {}
			defaultSound = "spikedearsBreak"
			defaultBreakText = ""
		end
		if args.purchase then
			components.dkienenLib_breakOnPurchase = {}
			defaultBreakText = ""
		end
		if args.depth then
			components.dkienenLib_breakOnDepth = args.depth
		end
	end
	local breakText = args.text or defaultBreakText
	local breakSound = args.sound or defaultSound
	components.consumableFlyaway = { text = breakText, offsetY = 0 }
	components.soundConsumeItem = { sound = breakSound, soundLast = args.soundLast }
end

componentUtil.registerComponent("dkienenLib", "breakOnPurchase", {shopliftingAllowed={type="bool",default=false}})

event.priceTagPay.add("PurchaseBreak", {order = "consume"}, function (ev)
	while true do
		local item = affectorItem.getItem(ev.buyer, "dkienenLib_breakOnPurchase")
		if not item then
			break
		end
		if not item.dkienenLib_breakOnPurchase.shopliftingAllowed or ev.multiplier > 0 then
			consumable.consume(item)
		end
	end
end)

componentUtil.registerComponent("dkienenLib", "breakOnDepth", {depth={type="int16",default=nil},floor={type="int16",default=nil}})

event.levelLoad.add("DepthBreak", {order = "spawnPlayers", sequence = 4}, function(ev)
	for item in ecs.entitiesWithComponents{"dkienenLib_breakOnDepth", "item"} do
		local holder = ecs.getEntityByID(item.item.holder)
		if player.isPlayerEntity(holder) then
			local depth, floor
			depth = item.dkienenLib_breakOnDepth.depth
			floor = item.dkienenLib_breakOnDepth.floor
			if (depth == 0 or (currentLevel.getDepth() == depth)) and (floor == 0 or (currentLevel.getFloor() == floor)) and not (currentLevel.getSequentialNumber() == 1) then
				consumable.consume(item)
			end
		end
	end
end)

return {
	apply=apply
}
