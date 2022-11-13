function apply(itemComponents, args)
	itemComponents.itemIncreaseCurrencyDrops = {
		currencyType = currency.Type.GOLD,
		amount = 1,
		applyMultiplier = true,
		minimum = 1
	}
end

return {
	apply=apply
}
