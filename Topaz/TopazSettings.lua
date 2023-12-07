local Enum = require "system.utils.Enum"
local Settings = require "necro.config.Settings"

local TopazSettings = {}

useOldExploreMethod = Settings.user.bool {
	name = "Use Old Exploration Method",
	id = "UseOldExploreMethod",
	default = false,
	desc = "Only explore via digging",
	tag = "topazPriority",
}

function TopazSettings.useOldExploreMethod()
	return useOldExploreMethod
end

-- TODO provide option to enable past a certain level, or after obtaining any of a list of items
exitASAP = Settings.user.bool {
	name = "Exit ASAP",
	id = "ExitASAP",
	default = false,
	desc = "Take exits as soon as possible",
	tag = "topazPriority",
}

function TopazSettings.exitASAP()
	return exitASAP
end

TopazSettings.LOOT_MONSTER_RELATIONS_TYPE = Enum.sequence({
	LOOT_HIGH = Enum.data {
		name = "Loot Higher",
		desc = "Prioritize loot over monsters.",
	},
	LOOT_MEDIUM = Enum.data {
		name = "Loot/Monsters equal",
		desc = "Prioritize loot and monsters equally.",
	},
	LOOT_LOW = Enum.data {
		name = "Monsters Higher",
		desc = "Prioritize monsters over loot.",
	},
})

lootMonsterRelations = Settings.user.enum({
	enum = TopazSettings.LOOT_MONSTER_RELATIONS_TYPE,
	name = "Loot/Monster Targeting",
	default = TopazSettings.LOOT_MONSTER_RELATIONS_TYPE.LOOT_MEDIUM,
	desc = "Which of monsters/loot to prioritize.",
	tag = "topazPriority",
})

function TopazSettings.lootMonsterRelations()
	return lootMonsterRelations
end

return TopazSettings