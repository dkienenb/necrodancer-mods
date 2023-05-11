local entityUtil = require "dkienenLib.EntityUtil"
local affectorItem = require "necro.game.item.AffectorItem"
local prefixUtil = require "dkienenLib.PrefixUtil"
local prefix = prefixUtil.prefix()

local function hunterKill(hunter)
    if not (affectorItem.entityHasItem(hunter, prefix .. "Soul")) then
        entityUtil.destroy(hunter, "Hunter's curse")
    end
end

return {
    character={
        inventory={"ShovelBasic","WeaponCrossbow","Bomb","HeadCircletTelepathy"},
        description="Locate and kill your\ntarget monster every floor,\nor die.",
        powers={
            {
                notFirstLevel=true,
                sequence=3,
                action=hunterKill
            }
        }
    }
}