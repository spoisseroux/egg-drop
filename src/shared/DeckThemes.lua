local Palette = require(script.Parent.DeckPalette)

return {
	Default = "stone",
	Order = { "stone", "ice", "brick", "moss" },
	ById = {
		stone = { name = "Stone", shell = Palette.Shell, trim = Palette.Rim, buttons = Palette.Primary },
		ice = { name = "Ice", shell = Color3.fromHex("#334652"), trim = Color3.fromHex("#81A5B4"),
			buttons = Color3.fromHex("#B8D9E0") },
		brick = { name = "Brick", shell = Color3.fromHex("#603A32"), trim = Color3.fromHex("#C57C64"),
			buttons = Color3.fromHex("#E9AA8C") },
		moss = { name = "Moss", shell = Color3.fromHex("#3E4937"), trim = Color3.fromHex("#899B6E"),
			buttons = Color3.fromHex("#C9D5A3") },
	},
}
