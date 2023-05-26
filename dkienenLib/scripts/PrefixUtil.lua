local snapshot = require "necro.game.system.Snapshot"
mod = snapshot.variable("dkienenLib")

local function getMod()
  return mod
end

local function prefix()
  return getMod() .. "_"
end

local function setMod(value)
  mod = value
end

return {
  getMod=getMod,
  prefix=prefix,
  setMod=setMod
}