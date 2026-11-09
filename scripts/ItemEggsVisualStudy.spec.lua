-- QA-only native ownership regression. Supply the temporary study ModuleScript as driver.
return function(client,driver)
 local Study=require(driver);local Run=game:GetService("RunService");local Lighting=game:GetService("Lighting");local Http=game:GetService("HttpService")
 local keys={"ClockTime","Brightness","ExposureCompensation","Ambient","OutdoorAmbient","ColorShift_Top"};local before={}
 for _,key in ipairs(keys)do before[key]=Lighting[key]end
 local air=Lighting:FindFirstChildOfClass("Atmosphere");local airBefore={};if air then for _,key in ipairs({"Color","Decay","Density"})do airBefore[key]=air[key]end end
 local grade=Lighting:FindFirstChild("SproutHollowGrade");local gradeBefore=grade and grade.TintColor
 local lamps={};for _,node in ipairs(workspace:GetDescendants())do if node:IsA("PointLight")and node:GetAttribute("HollowLamp")==true then lamps[node]=node.Brightness end end
 local function frame(callback)
  local event=Instance.new("BindableEvent");local id="StudyLightingProbe_"..Http:GenerateGUID(false);local result
  Run:BindToRenderStep(id,Enum.RenderPriority.Last.Value+21,function()
   Run:UnbindFromRenderStep(id);result={pcall(callback)};event:Fire()
  end)
  event.Event:Wait();event:Destroy();assert(result[1],result[2]);return result[2]
 end
 local owner,competitor;local cases={};local ok,err=pcall(function()
  owner=Study(client,{hour=12,pets={"pip"},motion="idle",frozen=true,markers=false,hideUI=false,origin=Vector3.new(2000,4.025,0)})
  competitor=Run.Heartbeat:Connect(function()
   Lighting.ClockTime=4.5486;Lighting.ExposureCompensation=.91;Lighting.Ambient=Color3.new(.1,.2,.3)
   if air then air.Density=.33 end;if grade then grade.TintColor=Color3.new(.2,.3,.4)end
   for light in pairs(lamps)do if light.Parent then light.Brightness=2.3 end end
  end)
  Run.Heartbeat:Wait()
  local sampled=frame(function()return owner:stats()end)
  assert(sampled.requestedHour==12 and sampled.actualClockTime==12 and sampled.actualDaylight==1 and sampled.lightingControlled)
  assert(sampled.environment.ClockTime==12 and sampled.environment.ExposureCompensation==0 and sampled.lastFrameClockTime==12 and sampled.lightingCorrections>0)
  assert(sampled.environment.Ambient and sampled.environment.OutdoorAmbient and sampled.environment.lamps and sampled.collectedAt>=sampled.lastLightingSampleAt)
  table.insert(cases,"last-priority study owner corrects an independent clock and records actual sampled environment")
  competitor:Disconnect();competitor=nil
  frame(function()
   Lighting.ClockTime=0;Lighting.ExposureCompensation=.72
   local drift=owner:stats();assert(drift.requestedHour==12 and drift.actualClockTime==0 and drift.actualDaylight==0 and not drift.lightingControlled)
   assert(drift.environment.ExposureCompensation==.72 or math.abs(drift.environment.ExposureCompensation-.72)<1e-5)
   assert(Lighting.ClockTime==0,"stats hid contamination with a collection-time repaint")
  end)
  local held=frame(function()return owner:stats()end);assert(held.actualClockTime==12 and held.lightingControlled)
  assert(owner:set({hour=0}));local night=frame(function()return owner:stats()end);assert(night.actualClockTime==0 and night.actualDaylight==0 and night.lightingControlled)
  table.insert(cases,"collection exposes drift honestly and subsequent frames/reconfigured night regain the actual hold")
  owner:destroy();owner:destroy()
  for _,key in ipairs(keys)do assert(Lighting[key]==before[key],"cleanup environment "..key)end
  if air and air.Parent then for key,value in pairs(airBefore)do assert(air[key]==value,"cleanup atmosphere "..key)end end
  if grade and grade.Parent then assert(grade.TintColor==gradeBefore)end
  for light,value in pairs(lamps)do if light.Parent then assert(light.Brightness==value,"cleanup lamp")end end
  assert(owner.folder.Parent==nil and owner.gui.Parent==nil)
  table.insert(cases,"cleanup restores exact pre-study sky atmosphere grade lamps and retires the existing render owner")
 end)
 if competitor then competitor:Disconnect()end;if owner then owner:destroy()end
 assert(ok,err);return cases
end
