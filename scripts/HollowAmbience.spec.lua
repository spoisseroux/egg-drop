-- Native anchored Part fixture + injected time/frustum, never real lounge facts.
return function(client)
 local Ambience=require(client.HollowAmbience);local cases,cleanup={},{}
 local function test(n,f)f();table.insert(cases,n)end
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function fixture()
  local f={time=.63,daylight=0,visible=true};f.world=Instance.new("Folder");f.world.Name="_HollowAmbienceFixture";f.world.Parent=workspace
  f.room=Instance.new("Folder");f.room.Name="EggDropLounge";f.room.Parent=f.world
  f.camera={Parent=f.world,CFrame=CFrame.new(0,5,12)}
  f.options={world=f.world,now=function()return f.time end,daylight=function()return f.daylight end,view=function()return f.visible end}
  f.c=Ambience.new(f.options);table.insert(cleanup,function()f.c:destroy();f.world:Destroy()end)
  function f:tick(enabled,reduced)self.c:step(.1,self.camera,enabled~=false,reduced==true)end
  return f
 end
 local function part(f,kind,index,late)
  local p=Instance.new("Part");p.Name="HollowAmbient_"..kind..tostring(index or 1);p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
  p.Size=Vector3.new(.3,.04,.2);p.CFrame=CFrame.new((index or 1)*.2,5,0)*CFrame.Angles(.15,math.pi/2,.1);p.Transparency=.4
  local rest=p.CFrame
  local function metadata()
   p:SetAttribute("HollowAmbientPhase",.17);p:SetAttribute("HollowAmbientPeriod",4);p:SetAttribute("HollowAmbientAmplitude",Vector3.new(.3,.1,.2))
   p:SetAttribute("HollowRestCFrame",rest);p:SetAttribute("HollowRestTransparency",.4);p:SetAttribute("HollowAmbientKind",kind)
  end
  if late then p.Parent=f.room else metadata();p.Parent=f.room end
  return p,rest,metadata
 end
 local function closePose(a,b)return(a.Position-b.Position).Magnitude<1e-4 and a.LookVector:Dot(b.LookVector)>.99999 end
 local ok,err=pcall(function()
 test("declared candidates register once and cap18 without creating renderer instances",function()
  local f=fixture();for i=1,19 do part(f,if i%3==0 then "firefly"elseif i%3==1 then "water"else "leaf",i)end;settle()
  assert(f.c:getStats().candidates==18 and f.c:getStats().parts==18 and f.c:getStats().scans==1)
  local count=#f.room:GetDescendants();for _=1,30 do f.time+=.1;f:tick()end;assert(#f.room:GetDescendants()==count)
 end)
 test("parent-before-attributes and late cosmetic safety properties become eligible",function()
  local f=fixture();local p,rest,metadata=part(f,"leaf",1,true);p.CanQuery=true;settle();assert(f.c:getStats().parts==0)
  metadata();settle();assert(f.c:getStats().parts==0)
  p.CanQuery=false;settle();assert(f.c:getStats().parts==1 and f.c:getStats().scans==1);f:tick();assert(not closePose(p.CFrame,rest))
 end)
 test("one sampler advances at12Hz and repeated absolute time never accumulates",function()
  local f=fixture();local p=part(f,"leaf");settle()
  for _=1,9 do f.c:step(.008,f.camera,true,false)end;assert(f.c:getStats().ticks==0)
  f.c:step(.012,f.camera,true,false);assert(f.c:getStats().ticks==1)
  local pose=p.CFrame;local writes=f.c:getStats().cframeWrites
  for _=1,40 do f:tick()end;assert(closePose(p.CFrame,pose)and f.c:getStats().cframeWrites==writes)
 end)
 test("world-axis amplitudes stay in world space on rotated authored leaves",function()
  local f=fixture();local p,rest=part(f,"leaf");settle();f:tick()
  local angle=((f.time%4)/4+.17)*math.pi*2;local expected=Vector3.new(.3*math.sin(angle),.1*math.sin(angle*2),.2*math.cos(angle))
  assert((p.CFrame.Position-rest.Position-expected).Magnitude<1e-4)
  f.time+=4;f:tick();assert((p.CFrame.Position-rest.Position-expected).Magnitude<1e-4)
  assert(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery)
 end)
 test("covered Deck/menu owner restores once then issues zero steady writes",function()
  local f=fixture();local p,rest=part(f,"leaf");local mote=part(f,"firefly",2);settle();f:tick();assert(mote.Transparency<1)
  f:tick(false);assert(closePose(p.CFrame,rest)and mote.Transparency==1)
  local a=f.c:getStats();for _=1,20 do f.time+=.1;f:tick(false)end;local b=f.c:getStats()
  assert(a.cframeWrites==b.cframeWrites and a.alphaWrites==b.alphaWrites)
 end)
 test("reduced composition keeps water/leaves still and suppresses fireflies",function()
  local f=fixture();local water,wr=part(f,"water");local leaf,lr=part(f,"leaf",2);local mote=part(f,"firefly",3);settle();f:tick();f:tick(true,true)
  assert(closePose(water.CFrame,wr)and closePose(leaf.CFrame,lr)and mote.Transparency==1)
  local a=f.c:getStats();for _=1,20 do f.time+=.1;f:tick(true,true)end;local b=f.c:getStats()
  assert(a.cframeWrites==b.cframeWrites and a.alphaWrites==b.alphaWrites)
 end)
 test("daylight distance and frustum yield to static rest without rays",function()
  local f=fixture();local p,rest=part(f,"leaf");local mote=part(f,"firefly",2);settle();f:tick();f.daylight=1;f:tick();assert(mote.Transparency==1)
  f.visible=false;f:tick();assert(closePose(p.CFrame,rest));f.visible=true;f.camera.CFrame=CFrame.new(1000,5,12);f:tick();assert(closePose(p.CFrame,rest))
  local a=f.c:getStats();for _=1,20 do f:tick()end;local b=f.c:getStats();assert(a.cframeWrites==b.cframeWrites and a.alphaWrites==b.alphaWrites)
 end)
 test("20mode cycles preserve connections scan count and18-actor instance budget",function()
  local f=fixture();for i=1,18 do part(f,if i%3==0 then "firefly"else "leaf",i)end;settle()
  local before=f.c:getStats();local count=#f.room:GetDescendants()
  for _=1,20 do f.time+=.3;f:tick();f:tick(false)end
  local after=f.c:getStats();assert(after.connections==before.connections and after.scans==before.scans and after.parts==18 and #f.room:GetDescendants()==count)
 end)
 test("stream removal and world replacement release old metadata safely",function()
  local f=fixture();local p,rest=part(f,"leaf");settle();f:tick();local detached=p.CFrame;local beforeDetach=f.c:getStats();p.Parent=nil;settle();assert(f.c:getStats().parts==0 and closePose(p.CFrame,detached),string.format("detach parts=%d candidates=%d parent=%s current=%s captured=%s rest=%s deltaCaptured=%.8f deltaRest=%.8f",f.c:getStats().parts,f.c:getStats().candidates,tostring(p.Parent),tostring(p.CFrame),tostring(detached),tostring(rest),(p.CFrame.Position-detached.Position).Magnitude,(p.CFrame.Position-rest.Position).Magnitude));assert(f.c:getStats().cframeWrites==beforeDetach.cframeWrites and f.c:getStats().alphaWrites==beforeDetach.alphaWrites,"stream removal issued presentation writes");p:Destroy()
  local old=f.room;local nextRoom=Instance.new("Folder");nextRoom.Name="EggDropLounge";nextRoom.Parent=f.world;f.room=nextRoom;local fresh=part(f,"water");settle()
  assert(f.c.room==nextRoom and f.c:getStats().parts==1);old:Destroy();settle();assert(f.c.room==nextRoom);f:tick()
 end)
 test("destroy and20GUI-owner restarts disconnect without per-part jobs or instances",function()
  local f=fixture();local p,rest=part(f,"leaf");settle();local count=#f.room:GetDescendants()
  f:tick();f.c:destroy();assert(closePose(p.CFrame,rest)and f.c:getStats().connections==0)
  local before=f.c:getStats();p:SetAttribute("HollowAmbientPhase",.6);settle();f.c:step(5,f.camera,true,false)
  assert(f.c:getStats().cframeWrites==before.cframeWrites)
  for _=1,20 do local c=Ambience.new(f.options);assert(c:getStats().parts==1);c:destroy();assert(c:getStats().connections==0)end
  assert(#f.room:GetDescendants()==count)
 end)
 end)
 for _,close in ipairs(cleanup)do close()end;assert(ok,err);return{passed=#cases,cases=cases}
end
