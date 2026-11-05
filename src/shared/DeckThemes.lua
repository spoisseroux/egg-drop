return {
	Default = "sherbet",
	Order = { "sherbet", "stone", "ice", "brick", "moss" },
	ById = {
		-- Saved IDs remain stable; Scout replaces the original default finish.
		sherbet = { name = "Scout", shell = Color3.fromHex("#4A8D32"), face = Color3.fromHex("#67AE3C"),
			trim = Color3.fromHex("#C2EC74"), buttons = Color3.fromHex("#FFA63C"), rocker = Color3.fromHex("#FFA63C") },
		stone = { name = "Pebble", shell = Color3.fromHex("#515C43"), face = Color3.fromHex("#687454"),
			trim = Color3.fromHex("#C2CEA0"), buttons = Color3.fromHex("#FFB84A"), rocker = Color3.fromHex("#FFB84A") },
		ice = { name = "Creek", shell = Color3.fromHex("#326B73"), face = Color3.fromHex("#4A8D92"),
			trim = Color3.fromHex("#B6DBCE"), buttons = Color3.fromHex("#FFC85A"), rocker = Color3.fromHex("#FFC85A") },
		brick = { name = "Ember", shell = Color3.fromHex("#A64C24"), face = Color3.fromHex("#C9682D"),
			trim = Color3.fromHex("#FFCC7A"), buttons = Color3.fromHex("#D6EB8E"), rocker = Color3.fromHex("#D6EB8E") },
		moss = { name = "Canopy", shell = Color3.fromHex("#285738"), face = Color3.fromHex("#397548"),
			trim = Color3.fromHex("#A4D66B"), buttons = Color3.fromHex("#FFC85A"), rocker = Color3.fromHex("#FFC85A") },
	},
}
