function apply(itemComponents, args)
	local amount = args.amount or 1
	itemComponents.itemRegenerationKillCounterHUD = {}
	itemComponents.itemIncrementRegenerationKillCounter = { increment = amount }
end

return {
	apply=apply
}
