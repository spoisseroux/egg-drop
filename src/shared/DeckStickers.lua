local Stickers = {
	Default = "none",
	Order = { "none", "star", "glitch", "seed" },
	ById = {
		none = { name = "Blank" },
		star = { name = "Star", mark = "★", color = Color3.fromHex("#F5CD74"), ink = Color3.fromHex("#493313") },
		glitch = { name = "Glitch", mark = "+", color = Color3.fromHex("#A4D4C1"), ink = Color3.fromHex("#203A35") },
		seed = { name = "Seed", mark = "◆", color = Color3.fromHex("#EAA48C"), ink = Color3.fromHex("#462824") },
	},
}

function Stickers.paint(label, id)
	local sticker = Stickers.ById[id] or Stickers.ById.none
	label.Visible = sticker.mark ~= nil
	if sticker.mark then
		label.Text = sticker.mark
		label.BackgroundColor3 = sticker.color
		label.TextColor3 = sticker.ink
	end
end

return Stickers
