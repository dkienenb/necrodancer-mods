local Enum = require "system.utils.Enum"
local Settings = require "necro.config.Settings"

local TopazSettings = {}

useOldExploreMethod = Settings.user.bool {
	name = "Use Old Exploration Method",
	id = "UseOldExploreMethod",
	default = false,
	desc = "Only explore via digging.",
	tag = "topazPriority",
}

function TopazSettings.useOldExploreMethod()
	return useOldExploreMethod
end

avoidBombTraps = Settings.user.bool {
	name = "Avoid Bomb Traps",
	id = "AvoidBombTraps",
	default = false,
	desc = "Sometimes they cause issues.",
}

function TopazSettings.avoidBombTraps()
	return avoidBombTraps
end

avoidDiceTraps = Settings.user.bool {
	name = "Avoid Dice Traps",
	id = "AvoidDiceTraps",
	default = false,
	desc = "Sometimes they cause annoying softlocks.",
}

function TopazSettings.avoidDiceTraps()
	return avoidDiceTraps
end

goldReserves = Settings.user.number({
	id = "MaxGold",
	name = "Gold Reserves",
	desc = "The amount of gold to stop at.",
	minimum = 0,
	default = 5000,
	step = 25,
})

function TopazSettings.goldReserves()
	return goldReserves
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

-- TODO provide option to stop farming past a certain level, or after obtaining any of a list of items
TopazSettings.FARM_AMOUNT = Enum.sequence({
	THE_NUCLEAR_OPTION = Enum.data {
		name = "The nuclear option!",
		desc = "Explore everything completely, including taking out every possible wall.",
	},
	VERY_FULL_CLEAR = Enum.data {
		name = "Excessive full clear",
		desc = "Explore everything completely, including exploring behind walls.",
	},
	FULL_CLEAR = Enum.data {
		name = "Full clear",
		desc = "Explore everything completely.",
	},
	ALL_LOOT = Enum.data {
		name = "All loot",
		desc = "Don't leave until you get the guaranteed items, plus any gold you may have encountered.",
	},
	ALL_ITEMS_SEARCH = Enum.data {
		name = "All items (search)",
		desc = "Don't leave until you get the guaranteed items, plus searching for any shrines that have not yet generated on your level.",
	},
	ALL_ITEMS = Enum.data {
		name = "All items",
		desc = "Don't leave until you get the guaranteed items.",
	},
	SOME_ITEMS = Enum.data {
		name = "Some items",
		desc = "Only pick up loot encountered, don't go looking for it.",
	},
	IGNORE_LOOT = Enum.data {
		name = "Ignore loot",
		desc = "Only the weak require assistance!",
	},
})

function TopazSettings.defaultFarmAmount()
	return TopazSettings.FARM_AMOUNT.FULL_CLEAR
end

farmAmount = Settings.user.enum({
	enum = TopazSettings.FARM_AMOUNT,
	name = "Farm amount",
	default = TopazSettings.defaultFarmAmount(),
	desc = "How much farming you will do. (Enable the low% shrine to run Topaz low%)",
	tag = "topazPriority",
})

function TopazSettings.farmAmount()
	return farmAmount
end

return TopazSettings