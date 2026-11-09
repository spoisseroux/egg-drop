-- QA ONLY. NOT mounted by default.project.json. Install temporarily in StarterPlayerScripts.
-- Configure ReplicatedStorage._SceneLightingEvidence: Enabled=true, Hour=0/12/18,
-- ShowLabel=true (optional). Collect attributes from the real Client datamodel.
-- Disable before removal/publication. No camera, avatar, input, remotes or profiles.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Lighting=game:GetService("Lighting")
local player=Players.LocalPlayer
local config=ReplicatedStorage:WaitForChild("_SceneLightingEvidence")
local client=player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local Clock=require(client:WaitForChild("HollowClock"))
local controller=Clock.start() -- Idempotent: this is the production LocalScript module cache.
if Clock._sceneLightingEvidenceOwner and Clock._sceneLightingEvidenceOwner.Parent then return end
Clock._sceneLightingEvidenceOwner=script
local bind="SceneLightingEvidence_"..player.UserId
local active,destroyed,hour,frames=false,false,nil,0
local originalNow,originalElapsed
local labelGui,label
local connections={}
local function heldNow()return((hour-Clock.TimeZoneOffsetHours)%24)*3600 end
local function stamp(controlled)
 if not config.Parent then return end
 config:SetAttribute("FixtureOnly",true)
 config:SetAttribute("ActualClockTime",Lighting.ClockTime)
 config:SetAttribute("Daylight",Clock.daylight())
 config:SetAttribute("ActualBrightness",Lighting.Brightness)
 config:SetAttribute("ActualExposure",Lighting.ExposureCompensation)
 config:SetAttribute("ActualAmbient",Lighting.Ambient)
 config:SetAttribute("ActualOutdoorAmbient",Lighting.OutdoorAmbient)
 config:SetAttribute("SampledAt",workspace:GetServerTimeNow())
 config:SetAttribute("Controlled",controlled==true)
 config:SetAttribute("ControlledFrames",frames)
 config:SetAttribute("ProductionClockShared",Clock.controller==controller)
end
local function clearLabel()
 if labelGui then labelGui:Destroy();labelGui,label=nil,nil end
end
local function refreshLabel()
 if not active or config:GetAttribute("ShowLabel")~=true then clearLabel();return end
 if not labelGui then
  labelGui=Instance.new("ScreenGui");labelGui.Name="SceneLightingEvidence_QA";labelGui.ResetOnSpawn=false;labelGui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;labelGui.DisplayOrder=1000
  label=Instance.new("TextLabel");label.Name="ControlledLight";label.AnchorPoint=Vector2.new(.5,0);label.Position=UDim2.new(.5,0,0,8);label.Size=UDim2.new(0,310,0,38)
  label.BackgroundColor3=Color3.fromHex("#173C35");label.BackgroundTransparency=.12;label.BorderSizePixel=0;label.TextColor3=Color3.fromHex("#F5FFF0");label.Font=Enum.Font.GothamMedium;label.TextSize=12;label.TextWrapped=true;label.AutomaticSize=Enum.AutomaticSize.Y;label.Active=false;label.Selectable=false;label.Parent=labelGui
  labelGui.Parent=player:WaitForChild("PlayerGui")
 end
 label.Text=string.format("CONTROLLED LIGHT %02d:00 - QA ONLY",hour)
end
local function restore()
 Run:UnbindFromRenderStep(bind)
 if active and not controller.destroyed and controller.now==heldNow then
  controller.now,controller.elapsed=originalNow,originalElapsed
  Clock.apply(originalNow())
 end
 active=false;frames=0;clearLabel();stamp(false)
end
local function refresh()
 if destroyed then return end
 local desired=config:GetAttribute("Hour")
 if config:GetAttribute("Enabled")~=true or(desired~=0 and desired~=12 and desired~=18)then restore();return end
 if not active then
  originalNow,originalElapsed=controller.now,controller.elapsed
  hour,frames,active=desired,0,true;controller.now=heldNow
  Clock.apply(heldNow())
  Run:BindToRenderStep(bind,Enum.RenderPriority.Last.Value+25,function()
   if destroyed or not active then return end
   if controller.destroyed or Clock.controller~=controller or controller.now~=heldNow then restore();return end
   Clock.apply(heldNow())
   local difference=math.abs((Lighting.ClockTime-hour+12)%24-12)
   local controlled=difference<.00001 and controller.now==heldNow and Clock.controller==controller
   frames=if controlled then frames+1 else 0
   stamp(controlled)
  end)
 elseif hour~=desired then hour,frames=desired,0;Clock.apply(heldNow())end
 refreshLabel()
end
local function destroy()
 if destroyed then return end;destroyed=true
 for _,connection in ipairs(connections)do connection:Disconnect()end
 restore()
 if Clock._sceneLightingEvidenceOwner==script then Clock._sceneLightingEvidenceOwner=nil end
end
for _,name in ipairs({"Enabled","Hour","ShowLabel"})do table.insert(connections,config:GetAttributeChangedSignal(name):Connect(refresh))end
table.insert(connections,config.Destroying:Connect(destroy))
table.insert(connections,script.Destroying:Connect(destroy))
refresh()
