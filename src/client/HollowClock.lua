local Lighting = game:GetService("Lighting")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World = require(Shared:WaitForChild("HollowWorldLayout"))
local Flags = require(Shared:WaitForChild("FeatureFlags"))
local Dusk = require(Shared:WaitForChild("WorldDusk"))

local Clock = {}
-- A shared world timezone, fixed year-round. This is a real 24-hour day.
Clock.TimeZoneOffsetHours = -5
-- FeatureFlags.DayNight=false (batch 2026-11-13) locks the garden at dusk: sample()
-- returns WorldDusk's hour and daylight and environment() paints the dusk look.
Clock.DayNight = Flags.DayNight == true

-- The real 24-hour cycle, kept for when DayNight comes back on.
function Clock.cycle(unixSeconds)
	local hour = (unixSeconds / 3600 + Clock.TimeZoneOffsetHours) % 24
	local sunlight = math.clamp((math.sin((hour - 6) * math.pi / 12) + 0.08) / 0.6, 0, 1)
	return hour, sunlight * sunlight * (3 - 2 * sunlight)
end

function Clock.sample(unixSeconds)
	if not Clock.DayNight then return Dusk.Hour, Dusk.Daylight end
	return Clock.cycle(unixSeconds)
end

function Clock.environment(unixSeconds)
	local hour, daylight = Clock.sample(unixSeconds)
 Clock.lastHour,Clock.lastDaylight=hour,daylight
	if not Clock.DayNight then
		Clock.dusk()
		return hour,daylight
	end
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
	if World.WorldVersion == "v7" then
		Clock.island(daylight)
	end
 return hour,daylight
end
-- Locked dusk: WorldDusk's lighting, grade, bloom and sky (the dusk faces once uploaded),
-- then the backdrop clouds in the dusk pink. The far peaks keep their texture.
function Clock.dusk()
	Dusk.apply(Lighting, require(Shared:WaitForChild("WorldV7Data")))
	Clock.backdrop(Dusk.Daylight)
end
-- v7 island: blue-violet night ambient and the painted day or night skybox.
-- A Sky cannot blend two face sets, so the faces switch at dusk and dawn
-- (daylight 0.35) while ambient and atmosphere carry the smooth fade.
Clock.SkyThreshold = 0.35
function Clock.island(daylight)
	Lighting.Ambient = Color3.fromHex("#6C7398"):Lerp(Color3.fromHex("#9C9C92"), daylight)
	Lighting.OutdoorAmbient = Color3.fromHex("#6E7DB0"):Lerp(Color3.fromHex("#A4AEB4"), daylight)
	Lighting.ColorShift_Top = Color3.fromHex("#9FB4E0"):Lerp(Color3.fromHex("#FFF4E5"), daylight)
	local air = Lighting:FindFirstChildOfClass("Atmosphere")
	if air then
		air.Color = Color3.fromHex("#3E4C80"):Lerp(Color3.fromHex("#CFE6F5"), daylight)
		air.Decay = Color3.fromHex("#2C3566"):Lerp(Color3.fromHex("#A9C6E0"), daylight)
		air.Density = 0.16
		air.Haze = 0.35
	end
	local sky = Lighting:FindFirstChild("WorldSky")
	if sky and sky:IsA("Sky") then
		local set = if daylight >= Clock.SkyThreshold then "day" else "night"
		if sky:GetAttribute("FaceSet") ~= set then
			local faces = require(Shared:WaitForChild("WorldV7Data")).sky[set]
			for _, face in ipairs({ "Bk", "Dn", "Ft", "Lf", "Rt", "Up" }) do
				sky["Skybox" .. face] = faces[face]
			end
			sky:SetAttribute("FaceSet", set)
		end
	end
	Clock.backdrop(daylight)
end
-- The backdrop ring (clouds and far peaks) is lit only by ambient, so at night
-- it read as a pale band around the horizon against the dark faces.
-- Clouds are untextured: tint them toward the night sky by daylight, holding
-- white through the bright half of dusk. Far peaks carry the palette texture,
-- which ignores Color, so after the night faces swap in they drop the texture
-- for a flat dusk-to-night slate silhouette and get it back at dawn.
Clock.CloudDay = Color3.fromHex("#FAFCFF")
Clock.CloudNight = Color3.fromHex("#2C355E")
Clock.PeakDusk = Color3.fromHex("#7C86A8")
Clock.PeakNight = Color3.fromHex("#283052")
Clock.clouds, Clock.peaks = {}, {}
function Clock.cloudColor(daylight)
	local t = math.clamp((daylight - 0.1) / 0.5, 0, 1)
	return Clock.CloudNight:Lerp(Clock.CloudDay, t * t * (3 - 2 * t))
end
function Clock.backdrop(daylight)
	local lounge = workspace:FindFirstChild("EggDropLounge")
	local meshes = lounge and lounge:FindFirstChild("World")
	if not meshes then return nil end
	if Clock.cloudFolder ~= meshes or #Clock.clouds == 0 then
		Clock.cloudFolder, Clock.clouds, Clock.peaks = meshes, {}, {}
		for _, part in ipairs(meshes:GetChildren()) do
			if part:IsA("BasePart") and part.Name:find("^W7_Backdrop__cloud") then table.insert(Clock.clouds, part) end
			if part:IsA("MeshPart") and part.Name:find("^W7_Backdrop__far_peak") then
				if part:GetAttribute("DayTextureID") == nil then part:SetAttribute("DayTextureID", part.TextureID) end
				table.insert(Clock.peaks, part)
			end
		end
	end
	local color = if Clock.DayNight then Clock.cloudColor(daylight) else Dusk.CloudColor
	for _, part in ipairs(Clock.clouds) do
		if part.Color ~= color then part.Color = color end
	end
	local night = Clock.DayNight and daylight < Clock.SkyThreshold
	local slate = Clock.PeakNight:Lerp(Clock.PeakDusk, math.clamp(daylight / Clock.SkyThreshold, 0, 1))
	for _, part in ipairs(Clock.peaks) do
		local texture = if night then "" else part:GetAttribute("DayTextureID") or ""
		if part.TextureID ~= texture then part.TextureID = texture end
		if night and part.Color ~= slate then part.Color = slate end
	end
	return color
end
-- Studio-only inspection hook: workspace attribute StudioClockHour (0-24) pins
-- the garden clock to that hour, so day, dusk and night can be checked in Play
-- (only while DayNight is on; the locked dusk ignores it).
function Clock.now()
 if game:GetService("RunService"):IsStudio()then
  local hour=workspace:GetAttribute("StudioClockHour")
  if type(hour)=="number"and hour==hour then return((hour%24)-Clock.TimeZoneOffsetHours)*3600 end
 end
 return workspace:GetServerTimeNow()
end
function Clock.daylight()return Clock.lastDaylight or select(2,Clock.sample(Clock.now()))end
Clock.Step=5
local Controller={};Controller.__index=Controller
local function finite(value)return type(value)=="number"and value==value and math.abs(value)<math.huge end
function Controller:paint(light,record)
 if not light.Parent or light:GetAttribute("HollowLamp")~=true then return end
 local day,night=light:GetAttribute("HollowDayBrightness"),light:GetAttribute("HollowNightBrightness")
 day=if finite(day)and day>=0 then day else .65
 night=if finite(night)and night>=0 then night else 1.55
 local brightness=night+(day-night)*self.daylight
 -- Native Brightness is float32; repeated equal sky samples must not issue
 -- setters merely because an authored numeric attribute is a Lua double.
 local delta=math.abs(light.Brightness-brightness)
 if record.desired~=brightness or delta>1e-5 then
  record.desired=brightness
  if delta>1e-5 then light.Brightness=brightness;self.writes+=1 end
 end
end
function Controller:track(item)
 if not item:IsA("PointLight")or self.lights[item]then return end
 local record={connections={}};self.lights[item]=record
 for _,name in ipairs({"HollowLamp","HollowDayBrightness","HollowNightBrightness"})do
  table.insert(record.connections,item:GetAttributeChangedSignal(name):Connect(function()
   if not self.destroyed and self.lights[item]==record then self:paint(item,record)end
  end))
 end
 self:paint(item,record)
end
function Controller:remove(item)
 local record=self.lights[item];if not record then return end
 self.lights[item]=nil;for _,c in ipairs(record.connections)do c:Disconnect()end
end
function Controller:bind(room)
 if self.room==room then return end
 for _,c in ipairs(self.roomConnections)do c:Disconnect()end;table.clear(self.roomConnections)
 for light in pairs(self.lights)do self:remove(light)end
 self.room=room;if not room then return end
 table.insert(self.roomConnections,room.DescendantAdded:Connect(function(item)if not self.destroyed and self.room==room then self:track(item)end end))
 table.insert(self.roomConnections,room.DescendantRemoving:Connect(function(item)if not self.destroyed and self.room==room then self:remove(item)end end))
 self.scans+=1;for _,item in ipairs(room:GetDescendants())do self:track(item)end
end
function Controller:apply(unixSeconds)
 local hour,daylight=self.sample(unixSeconds);self.daylight=daylight
 self.environment(unixSeconds)
 for light,record in pairs(self.lights)do self:paint(light,record)end
 self.samples+=1;return hour,daylight
end
function Controller:step(dt)
 if self.destroyed then return end
 self.elapsed+=dt;if self.elapsed<Clock.Step then return end
 self.elapsed%=Clock.Step;self:apply(self.now())
end
function Controller:stats()
 local count,managed=0,0;for light in pairs(self.lights)do count+=1;if light:GetAttribute("HollowLamp")==true then managed+=1 end end
 return {lights=count,managed=managed,connections=#self.connections+#self.roomConnections+count*3,scans=self.scans,samples=self.samples,writes=self.writes}
end
function Controller:getStats()return self:stats()end
function Controller:destroy()
 if self.destroyed then return end;self.destroyed=true
 self:bind(nil);for _,c in ipairs(self.connections)do c:Disconnect()end;table.clear(self.connections)
 if self.ownsBloom and self.bloom then self.bloom:Destroy()end
 if Clock.controller==self then Clock.controller=nil;Clock.started=false end
end
function Clock.new(options)
 options=options or {};local world=options.world or workspace
 local self=setmetatable({world=world,now=options.now or Clock.now,
  environment=options.environment or Clock.environment,sample=options.sample or Clock.sample,lights={},connections={},roomConnections={},elapsed=0,writes=0,samples=0,scans=0},Controller)
 self.daylight=select(2,self.sample(self.now()))
 table.insert(self.connections,world.ChildAdded:Connect(function(item)if not self.destroyed and item.Name=="EggDropLounge"then self:bind(item)end end))
 table.insert(self.connections,world.ChildRemoved:Connect(function(item)if not self.destroyed and self.room==item then self:bind(nil)end end))
 self:bind(world:FindFirstChild("EggDropLounge"));self:apply(self.now())
 if options.auto then table.insert(self.connections,game:GetService("RunService").Heartbeat:Connect(function(dt)self:step(dt)end))end
 return self
end
function Clock.apply(unixSeconds)
 if Clock.controller and not Clock.controller.destroyed then return Clock.controller:apply(unixSeconds)end
 return Clock.environment(unixSeconds)
end
function Clock.start()
 if Clock.controller and not Clock.controller.destroyed then return Clock.controller end
 local controller=Clock.new({auto=true});Clock.controller,Clock.started=controller,true
 local bloom=Lighting:FindFirstChild("HollowBloom")
 if not bloom then
  bloom=Instance.new("BloomEffect");bloom.Name,bloom.Intensity,bloom.Size,bloom.Threshold="HollowBloom",.12,12,1.4;bloom.Parent=Lighting;controller.ownsBloom=true
 end
 controller.bloom=bloom
 -- Ground flower patches (batch 2026-11-13, W1) start alongside the garden clock (once, v7 only).
 require(script.Parent.WorldDressingClient).start()
 return controller
end
return Clock
