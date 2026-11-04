local Settings = {
	Sound = { Full = 1, Quiet = 0.4, Off = 0 },
	NextSound = { Full = "Quiet", Quiet = "Off", Off = "Full" },
	DefaultSound = "Full",
}

function Settings.validSound(value)
	return type(value) == "string" and Settings.Sound[value] ~= nil
end

return Settings
