local Lighting = game:GetService("Lighting")

local Clock = {}
-- A shared world timezone, fixed year-round. This is a real 24-hour day.
Clock.TimeZoneOffsetHours = -5

function Clock.sample(unixSeconds)
	local hour = (unixSeconds / 3600 + Clock.TimeZoneOffsetHours) % 24
	local sunlight = math.clamp((math.sin((hour - 6) * math.pi / 12) + 0.08) / 0.6, 0, 1)
	return hour, sunlight * sunlight * (3 - 2 * sunlight)
end

function Clock.environment(unixSeconds)
	local hour, daylight = Clock.sample(unixSeconds)
 Clock.lastHour,Clock.lastDaylight=hour,daylight
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
 return hour,daylight
end
function Clock.daylight()return Clock.lastDaylight or select(2,Clock.sample(workspace:GetServerTimeNow()))end
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
 local hour,daylight=Clock.sample(unixSeconds);self.daylight=daylight
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
 local self=setmetatable({world=world,now=options.now or function()return workspace:GetServerTimeNow()end,
  environment=options.environment or Clock.environment,lights={},connections={},roomConnections={},elapsed=0,writes=0,samples=0,scans=0,daylight=select(2,Clock.sample((options.now or function()return workspace:GetServerTimeNow()end)()))},Controller)
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
 controller.bloom=bloom;return controller
end
return Clock
