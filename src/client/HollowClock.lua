local Lighting = game:GetService("Lighting")

local Clock = {}
-- A shared world timezone, fixed year-round. This is a real 24-hour day.
Clock.TimeZoneOffsetHours = -5

function Clock.sample(unixSeconds)
	local hour = (unixSeconds / 3600 + Clock.TimeZoneOffsetHours) % 24
	local sunlight = math.clamp((math.sin((hour - 6) * math.pi / 12) + 0.08) / 0.6, 0, 1)
	return hour, sunlight * sunlight * (3 - 2 * sunlight)
end

function Clock.apply(unixSeconds)
	local hour, daylight = Clock.sample(unixSeconds)
	Lighting.ClockTime = hour
	Lighting.Brightness = 1.0 + 1.13 * daylight
	Lighting.ExposureCompensation = 0.13 * (1 - daylight)
	Lighting.Ambient = Color3.fromHex("#7D948C"):Lerp(Color3.fromHex("#99927A"), daylight)
	Lighting.OutdoorAmbient = Color3.fromHex("#869E95"):Lerp(Color3.fromHex("#9CA598"), daylight)
	Lighting.ColorShift_Top = Color3.fromHex("#BBCFE1"):Lerp(Color3.fromHex("#FFF4E5"), daylight)
	local air = Lighting:FindFirstChildOfClass("Atmosphere")
	if air then
		air.Color = Color3.fromHex("#99B6B4"):Lerp(Color3.fromHex("#D3E6F0"), daylight)
		air.Decay = Color3.fromHex("#748E8C"):Lerp(Color3.fromHex("#DCC69D"), daylight)
		air.Density = 0.18 + daylight * 0.02
	end
	local grade = Lighting:FindFirstChild("SproutHollowGrade")
	if grade then
		grade.TintColor = Color3.fromHex("#DDECE6"):Lerp(Color3.fromHex("#FFF5E5"), daylight)
	end
	local room = workspace:FindFirstChild("EggDropLounge")
	if room then
		for _, item in ipairs(room:GetDescendants()) do
			if item:IsA("PointLight") then item.Brightness = 0.65 + (1 - daylight) * 0.9 end
		end
	end
	return hour, daylight
end

function Clock.start()
	if Clock.started then return end
	Clock.started = true
	local bloom = Instance.new("BloomEffect")
	bloom.Name, bloom.Intensity, bloom.Size, bloom.Threshold = "HollowBloom", 0.12, 12, 1.4
	bloom.Parent = Lighting
	task.spawn(function()
		workspace:WaitForChild("EggDropLounge")
		while true do
			-- Server time avoids different phone clocks producing different skies.
			Clock.apply(workspace:GetServerTimeNow())
			task.wait(5)
		end
	end)
end

return Clock
