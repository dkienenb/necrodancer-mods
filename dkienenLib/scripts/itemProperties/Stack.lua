function apply(itemComponents, args, itemName, modName)
	itemComponents.itemStack = {quantity = args.stackSize or 1, mergeKey=modName .. "_" .. itemName}
	itemComponents.itemStackQuantityLabelHUD = {
		minimumQuantity = 2,
		offsetX = 0
	}
	itemComponents.itemBlockDuplicatePickup = false
	itemComponents.itemStackMergeOnPickup = {}
end

return {
	apply=apply
}
