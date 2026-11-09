-- Native client fixtures; no real remote, camera replacement, or profile mutations.
return function(client,parent)
 local Transition=require(client.FocusTransition);local Follow=require(client.PetFollow)
 local Activity=require(game.ReplicatedStorage.Shared.GardenActivity);local Face=require(client.PetFace)
 local cases,cleanup,fixtureDiagnostics={},{},{}
 local function defer(fn)table.insert(cleanup,fn)end
 local function test(name,run)
  table.clear(cleanup)
  local ok,problem=xpcall(run,debug.traceback)
  local dump={"spec="..script:GetFullName(),"case="..name}
  local cleanupOk=true
  for i=#cleanup,1,-1 do
   local cleaned,detail=pcall(cleanup[i])
   cleanupOk=cleanupOk and cleaned
   table.insert(dump,if cleaned then tostring(detail or "cleaned")else "CLEANUP FAILED: "..tostring(detail))
  end
  table.insert(fixtureDiagnostics,table.concat(dump,"\n"))
  assert(ok and cleanupOk,tostring(problem).."\nFixture cleanup:\n"..table.concat(dump,"\n"))
  table.insert(cases,name)
 end
 test("reduced motion cover owns an opaque rendered frame and superseded reveal cannot uncover",function()
  local cut=Transition.new(parent,function()return true end)
  defer(function()
   local path=cut.gui:GetFullName()
   local state=string.format("path=%s visible=%s alpha=%s active=%s epoch=%s",path,tostring(cut.shade.Visible),tostring(cut.shade.BackgroundTransparency),tostring(cut.shade.Active),tostring(cut.epoch))
   cut:destroy()
   assert(cut.gui.Parent==nil,"transition fixture survived cleanup at "..path)
   return state.." destroyed=true"
  end)
  local token=cut:begin();local boundaries=0;local opaqueAtBoundaries=true;local heartbeatsAfterOpaque=0
  local runService=game:GetService("RunService")
  local function opaque()return cut.shade.Visible and cut.shade.BackgroundTransparency==0 and cut.shade.Active end
  local observation=runService.RenderStepped:Connect(function()
   boundaries+=1
   opaqueAtBoundaries=opaqueAtBoundaries and opaque()
  end)
  defer(function()observation:Disconnect();return "RenderStepped observer disconnected"end)
  local afterRender=runService.Heartbeat:Connect(function()
   if boundaries>0 then heartbeatsAfterOpaque+=1;opaqueAtBoundaries=opaqueAtBoundaries and opaque()end
  end)
  defer(function()afterRender:Disconnect();return "Heartbeat observer disconnected"end)
  local covered=cut:cover(token);observation:Disconnect();afterRender:Disconnect()
  -- The second RenderStepped waiter can resume before the observer callback on
  -- that boundary. An observed opaque pre-render followed by Heartbeat already
  -- proves the preceding frame completed before cover returned on the next one.
  assert(covered and boundaries>=1 and heartbeatsAfterOpaque>=1 and opaqueAtBoundaries,
   string.format("opaque frame: covered=%s preRender=%d heartbeatAfterOpaque=%d opaque=%s",tostring(covered),boundaries,heartbeatsAfterOpaque,tostring(opaqueAtBoundaries)))
  assert(cut.shade.Visible and cut.shade.BackgroundTransparency==0 and cut.shade.Active)
  local newer=cut:begin();assert(not cut:reveal(token)and cut.shade.Visible and cut.shade.BackgroundTransparency==0)
  assert(cut:cover(newer));cut:reveal(newer);assert(not cut.shade.Visible and not cut.shade.Active)
 end)
 test("authoritative gait covers .10-.15 studs and suppresses rest Focus and reduced motion",function()
  for _,petId in ipairs({"pip","puddle"})do
   local visual={petId=petId,worldScale=1,origin=Vector3.zero,yaw=0}
   local actor={from={0,0,0},to={10,0,0},startTime=0,endTime=2.5,mode="Room",behavior="follow"}
   local state;local low,high=math.huge,0
   for i=1,240 do state=Follow.activity(visual,actor,i/120+.12,1/120,state,false);low=math.min(low,visual.movementBob);high=math.max(high,visual.movementBob)end
   assert(high-low>=.1 and high-low<=.151,"gait amplitude "..petId..": "..(high-low))
   for i=1,120 do state=Follow.activity(visual,actor,10+i/120,1/120,state,false)end
   assert(visual.gaitWeight==0 and visual.movementBob==0)
   actor.mode="Focus";Follow.activity(visual,actor,1,1/60,state,false);assert(visual.gaitWeight==0 and visual.movementBob==0)
   actor.mode="Room";Follow.activity(visual,actor,1,1/60,state,true);assert(visual.gaitWeight==0 and visual.movementBob==0)
  end
 end)
 test("shaded night head and restrained torso restore palette and protect dark face",function()
  for _,id in ipairs({"zivvi","ovelle"})do
   local model=Instance.new("Model")
   defer(function()model:Destroy();return "night material model destroyed"end)
   local visual={worldContext=true,definition={id=id},nightTreatment="shadedHead",model=model}
   for _,name in ipairs({"Head","Body","EyeL","HandL"})do
    local part=Instance.new("Part");part.Material=Enum.Material.SmoothPlastic;local base=Color3.fromRGB(255,50,122);part.Color=base;part.Parent=model
    defer(function()local path=part:GetFullName();part:Destroy();return "part="..path.." destroyed=true"end)
    local entry={name=name,part=part,color=base}
    Face.paintSurface(entry,visual,0)
    assert((part.Material==Enum.Material.Neon)==(name=="Body"))
    if name=="Head"then
     assert(entry.nightHeadLift and entry.nightHeadLift.Adornee==part and entry.nightHeadLift.Enabled)
     assert(math.abs(entry.nightHeadLift.FillTransparency-.70)<.000001 and entry.nightHeadLift.OutlineTransparency==1)
    end
    Face.paintSurface(entry,visual,.29)
    if name=="Body"then assert(part.Material==Enum.Material.Neon)elseif name=="Head"then assert(part.Material==Enum.Material.SmoothPlastic and entry.nightHeadLift.Enabled)end
    Face.paintSurface(entry,visual,1)
    if name=="Head"then assert(not entry.nightHeadLift.Enabled)end
    assert(part.Material==Enum.Material.SmoothPlastic and math.abs(part.Color.R-base.R)<.005 and math.abs(part.Color.G-base.G)<.005 and math.abs(part.Color.B-base.B)<.005)
    part:Destroy()
   end
  end
 end)
 return{passed=#cases,cases=cases,fixtureCleanup=fixtureDiagnostics}
end
