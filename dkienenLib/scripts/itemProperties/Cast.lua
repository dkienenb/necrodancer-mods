function apply(itemComponents, args)
    local spell = args.spell
    itemComponents.itemCastOnUse = {spell = spell}
end

return {
    apply=apply
}