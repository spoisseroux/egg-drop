-- Isolated cache/lifecycle fixture. No production Lighting or clock is changed.
-- Lamp fixtures sample the real 24-hour cycle (Clock.cycle) so day and night stay testable while
-- FeatureFlags.DayNight=false locks the live garden at dusk (batch 2026-11-13, W1).
-- The garden hour cases (slice B) run on a fake hour, look, world and backdrop, so they also run offline: a bundle
-- with HollowClock passes `offline` (the second argument), and the Studio cases below them are skipped.
return function(client,offline)
 local Clock=require(client.HollowClock);local cases={};local cleanup={}
 local function test(n,f)f();table.insert(cases,n)end
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function fixture()
  local f={time=17*3600,sky=0};f.world=Instance.new("Folder");f.world.Name="_ClockFixture";f.world.Parent=workspace
  f.room=Instance.new("Folder");f.room.Name="EggDropLounge";f.room.Parent=f.world
  f.c=Clock.new({world=f.world,now=function()return f.time end,sample=Clock.cycle,environment=function()f.sky+=1 end})
  table.insert(cleanup,function()f.c:destroy();f.world:Destroy()end)
  return f
 end
 local function light(room,marked)
  local holder=Instance.new("Part");holder.Anchored=true;holder.CanCollide=false;holder.CanTouch=false;holder.CanQuery=false;holder.Parent=room
  local l=Instance.new("PointLight");l.Brightness=.123;l.Color=Color3.fromRGB(255,211,130);l.Range=9;l.Shadows=false
  if marked then l:SetAttribute("HollowLamp",true)end;l.Parent=holder;return l,holder
 end
 -- The Aero look (AeroWorld) is put back at the end.
 local look=Clock.look;Clock.look=nil;table.insert(cleanup,function()Clock.look=look end)
 local ok,err=pcall(function()
 -- The garden hour (slice B): a fake hour (the real pure look, a set switch and time), a fake Aero look, a fake world
 -- and the backdrop stubbed, so the live room, Lighting and workspace attributes are never touched.
 local Shared=game:GetService("ReplicatedStorage").Shared
 local Real,Dusk,Day=require(Shared.GardenHour),require(Shared.WorldDusk),require(Shared.WorldAero)
 local Base=3600*1000
 local function rgb(c)return math.round(c.R*255).."/"..math.round(c.G*255).."/"..math.round(c.B*255)end
 local function sig()
  local s={list={}}
  function s:Connect(fn)local link={Connected=true};s.list[link]=fn;function link:Disconnect()self.Connected=false;s.list[link]=nil end;return link end
  function s.fire()for _,fn in pairs(table.clone(s.list))do fn()end end
  return s
 end
 local state={on=true,ceiling=true,t=Base+1000,level=0,reduced=false,calls=0,changed=sig(),offset=sig()}
 local fake={on=function()state.calls+=1;return state.on end,ceiling=function()return state.ceiling end,time=function()return state.t end,
  look=Real.look,phase=Real.phase,Blending=Real.Blending,ApplyRate=Real.ApplyRate,
  changed=function()return state.changed end,offsetChanged=function()return state.offset end}
 local painted,backdrops={},{}
 local look={Hour=Day.Hour,Daylight=Day.Daylight,CloudColor=Day.CloudColor,
  paint=function(...)table.insert(painted,{n=select("#",...),values=(...)})end,reduced=function()return state.reduced end}
 -- The cases after these keep the fake hour, switched off, so a garden hour on in Studio cannot change them.
 local realHour,realBackdrop=Clock.Hour,Clock.backdrop
 Clock.Hour=fake;Clock.backdrop=function(...)table.insert(backdrops,{n=select("#",...),daylight=(...),values=select(2,...)})end
 table.insert(cleanup,function()
  Clock.Hour,Clock.backdrop=realHour,realBackdrop;Clock.lastHour,Clock.lastDaylight=Clock.schedule(0)
 end)
 local function world()return{ChildAdded=sig(),ChildRemoved=sig(),FindFirstChild=function()return nil end}end
 local function controller(options)
  options=options or {}
  local f={applies=0}
  f.c=Clock.new({world=world(),now=function()return 0 end,environment=function()f.applies+=1 end,
   level=function()return state.level end,hour=options.hour or fake})
  table.insert(cleanup,function()f.c:destroy()end)
  return f
 end
 -- Holds and the middle of each blend, and both ends of a night blend.
 local Moments={45,200,400,1000,2450,2600,2900,2940,3300,3599}
 local function reset(on)state.on,state.t,state.reduced,state.level=on,Base+1000,false,0;table.clear(painted);table.clear(backdrops)end

 test("hour on: sample, environment and both daylights read the hour's look, painted through the Aero look",function()
  reset(true);Clock.look=look
  for _,s in ipairs(Moments)do
   state.t=Base+s
   local want=Real.look(state.t)
   local hour,daylight=Clock.sample(0)
   assert(hour==want.Hour and daylight==want.Daylight,"sample "..s)
   local h,d=Clock.environment(0)
   assert(h==want.Hour and d==want.Daylight and Clock.lastHour==want.Hour and Clock.lastDaylight==want.Daylight,"environment "..s)
   local paint,back=painted[#painted],backdrops[#backdrops]
   assert(paint.n==1 and paint.values.Phase==want.Phase and paint.values.Hour==want.Hour and paint.values.Daylight==want.Daylight,"paint "..s)
   assert(back.n==2 and back.daylight==want.Daylight and rgb(back.values.CloudColor)==rgb(want.CloudColor)and back.values.PeakColor==want.PeakColor,"backdrop "..s)
   assert(Clock.daylight()==Clock.lastDaylight and Clock.daylight()==Real.phase(state.t).daylight,"one daylight "..s)
  end
 end)
 test("hour off, or the Aero look off: today's path, call for call",function()
  reset(false);Clock.look=look
  local hour,daylight=Clock.sample(0);assert(hour==Day.Hour and daylight==Day.Daylight)
  Clock.environment(0)
  assert(#painted==1 and painted[1].n==0 and #backdrops==1 and backdrops[1].n==1 and backdrops[1].daylight==Day.Daylight)
  assert(Clock.lastDaylight==Day.Daylight and Clock.daylight()==select(2,Clock.schedule(Clock.now())),"the birds keep their own day")
  -- Aero off: the hour cannot be on, whatever its switch says, and it is never asked.
  reset(true);Clock.look=nil;state.calls=0
  hour,daylight=Clock.sample(0);assert(hour==Dusk.Hour and daylight==Dusk.Daylight)
  assert(Clock.hourLook()==nil and Clock.daylight()==(Clock.lastDaylight or Dusk.Daylight)and state.calls==0)
 end)
 test("holds paint the phase's own frozen table (nothing new to write); blends a fresh one; Reduced Motion steps ClockTime",function()
  reset(true);Clock.look=look
  for _,s in ipairs({200,1000,2600,3300})do
   state.t=Base+s;Clock.environment(0);Clock.environment(0)
   local a,b=painted[#painted-1].values,painted[#painted].values
   assert(rawequal(a,b)and table.isfrozen(a)and rawequal(a,Real.Holds[a.Phase]),"hold "..s)
  end
  state.t=Base+2450;Clock.environment(0);Clock.environment(0)
  assert(not rawequal(painted[#painted-1].values,painted[#painted].values)and painted[#painted].values.Blend~=nil)
  for _,s in ipairs({2420,2470,2900,2990,30,80})do
   state.t=Base+s;state.reduced=true;Clock.environment(0)
   local got=painted[#painted].values
   local a,b=Real.Holds[got.From],Real.Holds[got.Phase]
   assert(got.Hour==a.Hour or got.Hour==b.Hour,"stepped "..s.." "..got.Hour)
  end
 end)
 test("blends apply at GardenHour.ApplyRate by budget level; holds keep the 5 s pass; into or out of a blend at once",function()
  reset(true);Clock.look=look
  local f=controller()
  local start=f.applies
  for _=1,40 do f.c:step(.1)end;assert(f.applies==start,"a hold has no per-frame pass")
  f.c:step(1.1);assert(f.applies==start+1,"the 5 s pass")
  for level,rate in pairs({[0]=20,[1]=10,[2]=2})do
   state.level=level;state.t=Base+2450
   local before=f.applies
   f.c:step(.001);assert(f.applies==before+1 and f.c.blending,"into the blend at once")
   before=f.applies
   for _=1,64 do f.c:step(1/64)end
   local got=f.applies-before
   assert(got<=rate and got>=rate*.75,"level "..level..": "..got.." a second")
   state.t=Base+2600;before=f.applies
   f.c:step(.001);assert(f.applies==before+1 and not f.c.blending,"out of the blend at once")
   for _=1,40 do f.c:step(.1)end;assert(f.applies==before+1,"back to 5 s")
  end
  state.level=7;state.t=Base+2950;f.c:step(.001);local before=f.applies
  for _=1,64 do f.c:step(1/64)end;assert(f.applies-before<=Real.ApplyRate[2],"an unknown level is the lowest rate")
  -- Off: the blend windows mean nothing.
  state.on=false;f.c:step(.001);before=f.applies
  for _=1,40 do f.c:step(.1)end;assert(f.applies==before)
 end)
 test("a switch flip or an offset change paints at once; nothing without the Aero look; destroy lets go",function()
  reset(true);Clock.look=look
  local f=controller();local before=f.applies
  state.changed.fire();assert(f.applies==before+1)
  state.t=Base+2950;state.offset.fire();assert(f.applies==before+2 and f.c.blending)
  Clock.look=nil;state.changed.fire();state.offset.fire();assert(f.applies==before+2)
  f.c:destroy();Clock.look=look;state.changed.fire();assert(f.applies==before+2 and f.c:getStats().connections==0)
 end)
 test("where the build ceiling is off the clock never asks the hour: no signals, no per-frame check",function()
  reset(true);Clock.look=nil;state.ceiling=false;state.calls=0
  local links=0;for _ in pairs(state.changed.list)do links+=1 end
  local f=controller();for _ in pairs(state.changed.list)do links-=1 end
  assert(f.c:getStats().connections==2 and links==0,"no hour signals")
  for _=1,105 do f.c:step(.1)end;assert(state.calls==0 and f.applies==3,f.applies)
  state.ceiling=true
 end)
 Clock.look=nil;state.on=false;Clock.backdrop=realBackdrop
 if offline then return end
 test("fixed UTCminus5 real24hour day preserves midnight noon and wrap",function()
  local midnight,dark=Clock.cycle(5*3600);local noon,day=Clock.cycle(17*3600);local nextMidnight=Clock.cycle(29*3600)
  assert(midnight==0 and noon==12 and nextMidnight==0 and dark==0 and day==1 and Clock.TimeZoneOffsetHours==-5)
 end)
 test("day/night off locks every sample to dusk",function()
  local Shared=game:GetService("ReplicatedStorage").Shared
  local Flags,Dusk=require(Shared.FeatureFlags),require(Shared.WorldDusk)
  assert(Flags.DayNight==false and Clock.DayNight==false,"DayNight flag")
  for _,t in ipairs({0,5*3600,11*3600,17*3600,23*3600})do
   local hour,daylight=Clock.sample(t);assert(hour==Dusk.Hour and daylight==Dusk.Daylight,"sample "..t)
  end
  assert(Dusk.Daylight>=.5 and Dusk.Daylight>Clock.SkyThreshold,"dusk keeps day faces, no night focus key, no fireflies")
  local f=fixture();local c=Clock.new({world=f.world,now=function()return 5*3600 end,environment=function()end})
  local l=light(f.room,true);settle();c:apply(5*3600)
  assert(math.abs(l.Brightness-(1.55+(.65-1.55)*Dusk.Daylight))<1e-4,"lamps glow at the dusk mix");c:destroy()
 end)
 test("a look is sampled and painted instead, and nothing else; nil is the garden without it",function()
  local painted,backdrop=0,nil
  local real=Clock.backdrop;Clock.backdrop=function(daylight)backdrop=daylight end
  local fine,wrong=pcall(function()
   Clock.look={Hour=10.5,Daylight=.9,CloudColor=Color3.new(1,1,1),paint=function()painted+=1 end}
   local hour,daylight=Clock.sample(0);assert(hour==10.5 and daylight==.9)
   Clock.environment(0);assert(painted==1 and backdrop==.9 and Clock.lastHour==10.5 and Clock.lastDaylight==.9)
   assert(Clock.daylight()==select(2,Clock.schedule(Clock.now())),"the birds keep their own day")
  end)
  Clock.look=nil;Clock.backdrop=real;Clock.lastHour,Clock.lastDaylight=Clock.schedule(0);assert(fine,wrong)
  assert(Clock.sample(0)==require(game:GetService("ReplicatedStorage").Shared.WorldDusk).Hour)
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
