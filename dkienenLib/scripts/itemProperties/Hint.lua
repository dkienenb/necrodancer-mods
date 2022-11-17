function apply(itemComponents, args)
    local hint = args.hint
    itemComponents.itemHintLabel = { text = hint }
end

return {
    apply=apply
}
