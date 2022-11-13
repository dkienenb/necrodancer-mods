function apply(itemComponents, args)
	local amount = args.amount or 2
	itemComponents.itemIncreaseMaxHealth = { maxHealth = amount }
end

return {
	apply=apply
}
