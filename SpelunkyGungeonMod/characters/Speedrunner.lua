local entityUtil = require "dkienenLib.EntityUtil"

local function dreamLuck(speedrunner)
    entityUtil.surroundEntity(speedrunner, 2, "Trapdoor")
end

return {
    character={
        description="Simulate the power\nof a good gaming chair!",
        powers={
            {
                notBoss=true,
                order="processPendingObjects",
                sequence=4,
                action=dreamLuck
            }
        }
    }
}