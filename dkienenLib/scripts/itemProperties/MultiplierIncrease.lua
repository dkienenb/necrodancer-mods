function apply(itemComponents, args)
	local amount = args.amount or 1
	itemComponents.itemIncreaseCoinMultiplier = { multiplier = amount }
end

return {
	apply=apply
}
