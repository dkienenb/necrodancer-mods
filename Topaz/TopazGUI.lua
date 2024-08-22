local HUD = require "necro.render.hud.HUD"
local UI = require "necro.render.UI"
local LowPercent = require "necro.game.item.LowPercent"

local Targeting = require("Topaz.Targeting")

event.renderPlayerHUD.add("TopazOverlay", {order = "grooveChain"}, function (ev)
	if not LowPercent.isEnforced() then
		HUD.drawText {
			offsetX = 2,
			offsetY = 208,
			text = "Shrine",
			fillColor = Targeting.seenShrine() and {0, 255, 0} or {255, 0, 0},
			maxWidth = 0,
		}
		HUD.drawText {
			offsetX = 2,
			offsetY = 219,
			text = "Chest",
			fillColor = Targeting.seenChest() and {0, 255, 0} or {255, 0, 0},
			maxWidth = 0,
		}
		HUD.drawText {
			offsetX = 2,
			offsetY = 230,
			text = "Shopping",
			fillColor = Targeting.hasShopped() and {0, 255, 0} or {255, 0, 0},
			maxWidth = 0,
		}
	else
		HUD.drawText {
			offsetX = 2,
			offsetY = 227,
			text = "Low% Active",
			fillColor = {0, 0, 255},
			maxWidth = 0,
		}
	end
end)