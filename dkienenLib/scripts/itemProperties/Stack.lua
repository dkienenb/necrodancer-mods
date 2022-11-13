function apply(itemComponents, args)
	itemComponents.itemStack = {quantity = args.stackSize or 1}
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
