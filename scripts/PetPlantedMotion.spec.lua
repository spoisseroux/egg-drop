-- Fixed root trajectories exercise continuous planting and sampled expressive poses.
return function(client)
 local Factory=require(client.PetFactory);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog);local H=require(game.ReplicatedStorage.Shared.HueCatalog)
 local folder=Instance.new("Folder");folder.Name="_PlantedMotion";folder.Parent=workspace;local cases={};local visuals={}
 local function visual(id)local v=Factory.new(folder,Vector3.new(0,4,0),Pets.byId[id],.72,{mainDoses=H.emptyCounts(),secondaryDoses=H.emptyCounts(),charmVisible=false});table.insert(visuals,v);v.greeting=2;return v end
 local ok,err=pcall(function()
  for _,id in ipairs({"pip","puddle","wick","orbit","bloom_pip","foxfire_wick","eclipse_orbit"})do
   local v=visual(id);local previous={};local planted=0
   for frame=1,180 do
    local dt=1/60;local distance=frame*1.044*dt;v.origin=Vector3.new(0,4,distance);v.yaw=0;v.gaitPhase=(distance/(1.45*.72)*math.pi*2)%(math.pi*2);v.gaitWeight=1;v:update(dt)
    for _,slot in ipairs(v.poseSlots)do if slot.side then
     local p=slot.entry.part.Position;local old=previous[slot]
     if slot.stance and old and old.stance then assert((p-old.position).Magnitude<=.08001,"stance slip "..id);planted+=1 end
     previous[slot]={position=p,stance=slot.stance}
    end end
   end
   assert(planted>60 and v.poseSamples>=44 and v.poseSamples<=48,"cadence/stance missing "..id)
   table.insert(cases,id.." planted distance gait with fresh 60Hz root and 15Hz expressive poses")
  end
  for _,turn in ipairs({math.pi*.5,-math.pi*.5,math.pi})do
   local v=visual("pip");v.gaitWeight=0;v.gardenPivot=true;v.gardenPivotTurn=turn;local footPositions={}
   for frame=0,60 do
    local phase=frame/60;v.gardenPivotPhase=phase;v.yaw=turn*phase*phase*(3-2*phase);v:update(1/120)
    for _,slot in ipairs(v.poseSlots)do if slot.side then
     local p=slot.entry.part.Position;assert((Vector3.new(p.X,0,p.Z)-Vector3.new(v.origin.X,0,v.origin.Z)).Magnitude<1,"unreachable pivot foot")
     footPositions[slot.side]=p
    end end
   end
   assert(footPositions[-1]and footPositions[1]and(footPositions[-1]-footPositions[1]).Magnitude>.1,"pivot crossed sides")
   v.gardenPivot=false;v.gaitWeight=1;v.gaitPhase=.1;v.origin+=Vector3.new(.01,0,0);v:update(1/60)
   table.insert(cases,"stationary "..math.floor(math.deg(turn)).." pivot steps one foot and releases into first stride")
  end
  for _,id in ipairs({"pip","puddle"})do
   local v=visual(id);v.reducedEffects=true;v.movementBob=0;local previous={};local planted=0
   local function boundedFeet()
    for _,slot in ipairs(v.poseSlots)do if slot.side then
     local part=slot.entry.part;local base=v.origin.Y+math.max(slot.rest.Y,part.Size.Y*.5)
     assert(part.Position.Y<=base+.035*.72+.011,"reduced swing/pivot lift exceeded bound "..id)
     local old=previous[slot]
     if not v.gardenPivot and slot.stance and old and old.stance then assert((part.Position-old.position).Magnitude<=.08001,"reduced stance slip "..id);planted+=1 end
     previous[slot]={position=part.Position,stance=slot.stance}
    end end
   end
   for frame=1,120 do local d=frame*1.044/60;v.origin=Vector3.new(0,4,d);v.gaitPhase=(d/(1.45*.72)*math.pi*2)%(math.pi*2);v.gaitWeight=1;v:update(1/60);boundedFeet()end
   assert(planted>30 and v.movementBob==0)
   v.gardenPivot=true;v.gardenPivotTurn=math.pi;v.gaitWeight=0
   for frame=0,60 do local p=frame/60;v.gardenPivotPhase=p;v.yaw=math.pi*p*p*(3-2*p);v:update(1/120);boundedFeet()end
   table.insert(cases,id.." reduced walking and half-turn keep stance/lift bounded without body bounce")
  end
  do
   local v=visual("pip");v.gardenPivot=true;v.gardenPivotPhase=.4;v.gardenPivotTurn=math.pi
   local follow=require(client.PetFollow);local root={Position=Vector3.new(0,6,0),CFrame=CFrame.new(0,6,0)}
   follow.step(v,root,1/60,nil,true)
   assert(v.gardenPivot==false and v.gardenPivotPhase==0 and v.gardenPivotTurn==0,"fallback retained old authoritative pivot")
   table.insert(cases,"pivot to fallback/new owner root clears authoritative-only pivot state")
  end
 end)
 for _,v in ipairs(visuals)do v:destroy()end;folder:Destroy();assert(ok,err);return cases
end
