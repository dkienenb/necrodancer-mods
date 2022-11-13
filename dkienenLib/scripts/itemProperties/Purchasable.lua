function apply(itemComponents, args)
	local price = args.price
	itemComponents.itemPrice = price
	if args.shopWeights then
		itemComponents.itemPoolShop = {weights = args.shopWeights}
	end
	if args.secretShopWeights then
		itemComponents.itemPoolSecret = {weights = args.secretShopWeights}
	end
	if args.lockedShopWeights then
		itemComponents.itemPoolLockedShop = {weights = args.lockedShopWeights}
	end
end

return {
	apply=apply
}
