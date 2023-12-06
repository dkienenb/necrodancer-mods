local HUD = require "necro.render.hud.HUD"
local UI = require "necro.render.UI"

local Targeting = require("Topaz.Targeting")

event.renderPlayerHUD.add("TopazOverlay", {order = "grooveChain"}, function (ev)
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
end)