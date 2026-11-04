local Config = {
	Width = 14,
	Height = 19,
	SpawnY = 17.8,
	Gravity = 32,
	Bank = 2.2,
	MaxEggs = 32,
	DropInterval = 0.35,
	ResetInterval = 0.5,
	FixedStep = 1 / 120,
	DefaultPreset = "Springy",
	Presets = {
		Gentle = { bounce = 0.22, kick = 2.5 },
		Springy = { bounce = 0.64, kick = 6.5 },
	},
	Tiers = {
		{ radius = 0.72, color = Color3.fromRGB(147, 209, 238), mark = "I" },
		{ radius = 1.04, color = Color3.fromRGB(248, 170, 132), mark = "II" },
		{ radius = 1.43, color = Color3.fromRGB(168, 239, 181), mark = "III" },
	},
	Starter = {
		{ x = 0, tier = 1 },
		{ x = 1.95, tier = 2 },
		{ x = -3.3, tier = 2 },
		{ x = 4.05, tier = 1 },
	},
	Queue = { 1, 1, 2, 1, 2, 1 },
}

function Config.aimX(aim, tier)
	local span = Config.Width / 2 - Config.Tiers[tier].radius
	return (aim * 2 - 1) * span
end

return Config
