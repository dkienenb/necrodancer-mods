function apply(itemComponents, args)
	local slot = args.slot or "misc"
	itemComponents.itemSlot = { name = slot }
end

return {
	apply=apply
}
