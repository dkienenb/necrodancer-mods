local breakable = require "dkienenLib.itemProperties.Breakable"

function apply(components, args, name)
	local level = args.level or "First"
	components["itemIncomingDamageImmunity" .. level] = {}
	components.itemIncomingDamageImmunityConsume = {}
	components.itemIncomingDamageImmunityHitstop = {}
	components.itemResetDamageCountdown = {}
	components.itemDestructible = {}
	breakable.apply(components, {sound="skeletonShieldHit", soundLast="skeletonShieldBreak"}, name)
end

return {
	apply=apply
}
