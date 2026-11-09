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
 test("authoritative gait covers .10-.15 studs and suppresses rest/Focus gait and reduced body bounce",function()
  for _,petId in ipairs({"pip","puddle"})do
   local visual={petId=petId,worldScale=1,origin=Vector3.zero,yaw=0}
   local actor={from={0,0,0},to={10,0,0},startTime=0,endTime=2.5,mode="Room",behavior="follow"}
   local state;local low,high=math.huge,0
   for i=1,240 do state=Follow.activity(visual,actor,i/120+.12,1/120,state,false);low=math.min(low,visual.movementBob);high=math.max(high,visual.movementBob)end
   assert(high-low>=.1 and high-low<=.151,"gait amplitude "..petId..": "..(high-low))
   for i=1,120 do state=Follow.activity(visual,actor,10+i/120,1/120,state,false)end
   assert(visual.gaitWeight==0 and visual.movementBob==0)
   actor.mode="Focus";Follow.activity(visual,actor,1,1/60,state,false);assert(visual.gaitWeight==0 and visual.movementBob==0)
   actor.mode="Room";Follow.activity(visual,actor,1,1/60,state,true);assert(visual.reducedEffects and visual.movementBob==0)
  end
 end)
 test("grouped night fills preserve shaded materials and protected dark face",function()
  local model=Instance.new("Model");defer(function()model:Destroy();return "night material model destroyed"end)
  local rose=Color3.fromRGB(255,50,122);local tide=Color3.fromRGB(0,141,255);local ink=Color3.fromRGB(45,39,49)
  local visual={worldContext=true,model=model,pieces={},colors={body=rose,secondary=tide},charmVisible=true}
  for _,name in ipairs({"Head","Body","EyeL","HandL","FootL"})do
   local role=if name=="EyeL"then "face"elseif name=="FootL"then "secondary"else "body"
   local part=Instance.new("Part");part.Name=name;part.Material=Enum.Material.SmoothPlastic;part.Color=if role=="face"then ink elseif role=="secondary"then tide else rose;part.Parent=model
   table.insert(visual.pieces,{name=name,part=part,colorRole=role,color=part.Color,faceBaseMaterial=part.Material})
  end
  for _,entry in ipairs(visual.pieces)do Face.paintSurface(entry,visual,0);assert(entry.part.Material==Enum.Material.SmoothPlastic)end
  assert(visual.nightGroups.body.fill.Enabled and visual.nightGroups.secondary.fill.Enabled)
  assert(math.abs(visual.nightGroups.body.fill.FillTransparency-.68)<.000001 and math.abs(visual.nightGroups.secondary.fill.FillTransparency-.64)<.000001)
  local eye=visual.pieces[3].part;assert(eye.Parent==model and eye.Color==ink)
  Face.paintSurface(visual.pieces[1],visual,1);assert(not visual.nightGroups.body.fill.Enabled and not visual.nightGroups.secondary.fill.Enabled)
 end)

 return{passed=#cases,cases=cases,fixtureCleanup=fixtureDiagnostics}
end
