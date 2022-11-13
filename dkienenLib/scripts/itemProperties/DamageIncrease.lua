function apply(itemComponents, args)
	local amount = args.amount or 1
	itemComponents.itemAttackDamageIncrease = { increase = amount }
end

return {
	apply=apply
}
