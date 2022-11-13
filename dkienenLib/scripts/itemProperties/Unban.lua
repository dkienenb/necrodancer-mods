function apply(itemComponents, args)
	itemComponents.itemBanHealthlocked = false
	itemComponents.itemBanWeaponlocked = false
	itemComponents.itemBanShoplifter = false
	itemComponents.itemBanNoDamage = false
	itemComponents.itemBanDiagonal = false
	itemComponents.itemBanMoveAmplifier = false
	itemComponents.itemBanPoverty = false
	itemComponents.itemBanKillPoverty = false
	itemComponents.itemBanPacifist = false
	itemComponents.itemBanInnateSpell = false
	itemComponents.itemBanAria = false
	itemComponents.itemBanDorian = false
	itemComponents.itemBanEli = false
	itemComponents.itemBanDiamond = false
	itemComponents.itemBanMary = false		
	itemComponents.itemBanTempo = false
end

return {
	apply=apply
}
