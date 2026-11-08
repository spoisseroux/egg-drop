-- Isolated cache/lifecycle fixture. No production Lighting or clock is changed.
return function(client)
 local Clock=require(client.HollowClock);local cases={};local cleanup={}
 local function test(n,f)f();table.insert(cases,n)end
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function fixture()
  local f={time=17*3600,sky=0};f.world=Instance.new("Folder");f.world.Name="_ClockFixture";f.world.Parent=workspace
  f.room=Instance.new("Folder");f.room.Name="EggDropLounge";f.room.Parent=f.world
  f.c=Clock.new({world=f.world,now=function()return f.time end,environment=function()f.sky+=1 end})
  table.insert(cleanup,function()f.c:destroy();f.world:Destroy()end)
  return f
 end
 local function light(room,marked)
  local holder=Instance.new("Part");holder.Anchored=true;holder.CanCollide=false;holder.CanTouch=false;holder.CanQuery=false;holder.Parent=room
  local l=Instance.new("PointLight");l.Brightness=.123;l.Color=Color3.fromRGB(255,211,130);l.Range=9;l.Shadows=false
  if marked then l:SetAttribute("HollowLamp",true)end;l.Parent=holder;return l,holder
 end
 local ok,err=pcall(function()
 test("fixed UTCminus5 real24hour day preserves midnight noon and wrap",function()
  local midnight,dark=Clock.sample(5*3600);local noon,day=Clock.sample(17*3600);local nextMidnight=Clock.sample(29*3600)
  assert(midnight==0 and noon==12 and nextMidnight==0 and dark==0 and day==1 and Clock.TimeZoneOffsetHours==-5)
 end)
 test("incremental marked lamp cache paints exact day and night only",function()
  local f=fixture();local l=light(f.room,true);local other=light(f.room,false);local originalOther=other.Brightness;settle()
  assert(math.abs(l.Brightness-.65)<1e-5 and other.Brightness==originalOther)
  local color,range,shadows=l.Color,l.Range,l.Shadows
  f.c:apply(5*3600);assert(math.abs(l.Brightness-1.55)<1e-5 and other.Brightness==originalOther)
  assert(l.Color==color and l.Range==range and l.Shadows==shadows and f.c:getStats().managed==1)
 end)
 test("parent before attributes activates cached light without another scan",function()
  local f=fixture();local l=light(f.room,false);settle();local scans=f.c:getStats().scans
  l:SetAttribute("HollowDayBrightness",.4);l:SetAttribute("HollowNightBrightness",1.2);l:SetAttribute("HollowLamp",true);settle()
  assert(math.abs(l.Brightness-.4)<1e-5 and f.c:getStats().scans==scans)
  f.c:apply(5*3600);assert(math.abs(l.Brightness-1.2)<1e-5)
 end)
 test("cached repeated samples and20same-room binds never discover descendants again",function()
  local f=fixture();for _=1,4 do light(f.room,true)end;settle()
  local before=f.c:getStats();for _=1,20 do f.c:bind(f.room);f.c:apply(17*3600)end
  local after=f.c:getStats();assert(after.scans==before.scans and after.connections==before.connections and after.managed==4 and after.writes==before.writes)
 end)
 test("stream removal and replacement release old light subscriptions",function()
  local f=fixture();local l,holder=light(f.room,true);settle();holder.Parent=nil;settle()
  local value=l.Brightness;f.c:apply(5*3600);assert(l.Brightness==value and f.c:getStats().lights==0);holder:Destroy()
  local nextRoom=Instance.new("Folder");nextRoom.Name="EggDropLounge";nextRoom.Parent=f.world;local nextLight=light(nextRoom,true);settle()
  assert(f.c.room==nextRoom and f.c:getStats().managed==1 and math.abs(nextLight.Brightness-1.55)<1e-5)
  f.room:Destroy();settle();assert(f.c.room==nextRoom)
 end)
 test("five-second sampler has no per-frame lamp or sky writes",function()
  local f=fixture();local l=light(f.room,true);settle();local sky=f.sky;local before=f.c:getStats()
  for _=1,40 do f.c:step(.1)end
  assert(f.sky==sky and f.c:getStats().writes==before.writes)
  f.c:step(1.1);assert(f.sky==sky+1)
 end)
 test("destroy cancels signal/timer owner and owned Bloom without revival",function()
  local f=fixture();local l=light(f.room,true);settle()
  local bloom=Instance.new("BloomEffect");bloom.Parent=f.world;f.c.bloom,f.c.ownsBloom=bloom,true
  f.c:destroy();f.c:destroy();assert(f.c:getStats().connections==0 and not bloom.Parent)
  local before=l.Brightness;l:SetAttribute("HollowNightBrightness",4);local room=Instance.new("Folder");room.Name="EggDropLounge";room.Parent=f.world;settle();f.c:step(10)
  assert(l.Brightness==before and not f.c.room and f.c:getStats().lights==0)
 end)
 end)
 for _,close in ipairs(cleanup)do close()end;assert(ok,err);return{passed=#cases,cases=cases}
end
