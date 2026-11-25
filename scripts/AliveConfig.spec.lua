-- Studio Server. The Alive off switch (ALIVE-BUILD-PLAN-2026-11-22 step 0) on a fake ConfigService, clock and
-- scheduler: attributes first, missing / slow / broken config keeps shipped defaults, errored snapshots keep
-- the last good values, one refresh per 5 s, and the owner's /alive overrides.
-- Usage: require(ServerScriptService.Server.ZZSpecs.AliveConfig)(ServerScriptService.Server)
return function(server)
 local Config=require(server.AliveConfig);local Alive=require(game:GetService("ReplicatedStorage").Shared.Alive)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 -- A hand-run scheduler: spawn starts a coroutine, wait parks it, advance(s) wakes what is due.
 local function rig(service,ceiling)
  local r={at=0,attrs={},writes=0,parked={},waits={},warnings={}}
  r.config=Config.new({service=service,set=function(name,value)r.attrs[name]=value;r.writes+=1 end,
   now=function()return r.at end,ceiling=ceiling or function()return true end,warn=function(text)table.insert(r.warnings,text)end,
   spawn=function(fn)local co=coroutine.create(fn);local ok,problem=coroutine.resume(co);assert(ok,problem)end,
   wait=function(s)table.insert(r.waits,s);table.insert(r.parked,{co=coroutine.running(),due=r.at+s});return coroutine.yield()end})
  function r.advance(s)
   local target=r.at+s
   while true do
    local best
    for i,p in ipairs(r.parked)do if p.due<=target and(not best or p.due<r.parked[best].due)then best=i end end
    if not best then break end
    local p=table.remove(r.parked,best);r.at=math.max(r.at,p.due)
    local ok,problem=coroutine.resume(p.co);assert(ok,problem)
   end
   r.at=target
  end
  function r.get(f)return r.attrs[Alive.attribute(f)]end
  -- "true" is every feature at its shipped default (beta 17: windbed's is off); false is every one off.
  function r.all(value)
   for _,f in ipairs(Alive.Features)do
    local want=if value==true then Alive.resolve(f,nil,nil,true)else value
    if r.get(f)~=want then return false end
   end
   return true
  end
  return r
 end
 local function snapshot(values)
  local s={values=values,refreshes=0,listeners={}}
  function s:GetValue(key)if s.throw then error("boom")end;return s.values[key]end
  function s:Refresh()s.refreshes+=1;if s.onRefresh then s.onRefresh()end end
  s.UpdateAvailable={Connect=function(_,fn)table.insert(s.listeners,fn)end}
  function s.update()for _,fn in ipairs(s.listeners)do fn()end end
  return s
 end
 local function serviceOf(snap)return function()return{GetConfigAsync=function()return if type(snap)=="function"then snap()else snap end}end end
 local function errored()local s=snapshot({alive_wind=false});s.Error="LoadFailed";return s end
 local function throwing()local s=snapshot({alive_wind=false});s.throw=true;return s end

 test("attributes are written before anything yields, as booleans; a service that never answers changes nothing",function()
  local r=rig(function()return{GetConfigAsync=function()return coroutine.yield()end}end)
  r.config.start();assert(r.all(true)and r.writes==#Alive.Features);r.advance(1000);assert(r.all(true))
 end)
 test("a missing service, a throw and an errored snapshot retry at 5, 15, 60 then every 300 s",function()
  for i,service in ipairs({function()error("no such service")end,serviceOf(function()error("down")end),serviceOf(errored),serviceOf(throwing),
   serviceOf(function()return nil end)})do
   local r=rig(service);r.config.start();r.advance(5+15+60+300+300)
   assert(table.concat(r.waits," ")=="5 15 60 300 300 300",i..": "..table.concat(r.waits," "))
   assert(r.all(true),"shipped defaults")
   assert(#r.warnings==1,i..": one warning per kind of failure, not "..#r.warnings)
  end
 end)
 test("a late load applies and stops retrying; malformed keys count as missing",function()
  local calls=0
  local r=rig(serviceOf(function()
   calls+=1;if calls<3 then error("down")end
   return snapshot({alive_springs=false,alive_menus="false",alive_close=0})
  end))
  r.config.start();r.advance(1000)
  assert(calls==3 and #r.waits==2)
  assert(r.get("springs")==false and r.get("menus")==true and r.get("close")==true and r.get("wind")==true)
 end)
 test("UpdateAvailable refreshes and re-resolves, at most once per 5 s, with a trailing one",function()
  local s=snapshot({});local r=rig(serviceOf(s));r.config.start();assert(r.all(true))
  r.at=10;s.values={alive_wind=false};s.update();assert(s.refreshes==1 and r.get("wind")==false)
  s.values={};for _=1,20 do s.update()end
  assert(s.refreshes==1 and r.get("wind")==false);r.advance(5);assert(s.refreshes==2 and r.get("wind")==true)
  r.advance(100);assert(s.refreshes==2)
 end)
 test("a refresh that throws, or comes back errored or throwing, keeps the last good values",function()
  local s=snapshot({alive_close=false});local r=rig(serviceOf(s));r.config.start();assert(r.get("close")==false)
  s.values={}
  s.onRefresh=function()error("refresh failed")end;r.at=10;s.update();assert(s.refreshes==1 and r.get("close")==false)
  s.onRefresh=nil;s.Error="LoadFailed";r.at=20;s.update();assert(r.get("close")==false)
  s.Error=nil;s.throw=true;r.at=30;s.update();assert(r.get("close")==false)
  s.throw=nil;r.at=40;s.update();assert(r.get("close")==true,"a good one applies")
 end)
 test("a failed refresh retries at 5, 15, 60 then every 300 s until one is good; a newer update takes its turn",function()
  for _,kind in ipairs({"throws","errored"})do
   local s=snapshot({});local r=rig(serviceOf(s));r.config.start();r.at=10
   if kind=="throws"then s.onRefresh=function()error("down")end else s.Error="LoadFailed"end
   s.values={alive_wind=false};s.update();assert(s.refreshes==1 and r.all(true),kind)
   r.advance(4.9);assert(s.refreshes==1);r.advance(.2);assert(s.refreshes==2);r.advance(15);assert(s.refreshes==3);r.advance(60);assert(s.refreshes==4)
   r.advance(300);assert(s.refreshes==5 and r.all(true));assert(#r.warnings==1,kind.." warned "..#r.warnings)
   s.onRefresh=nil;s.Error=nil;r.advance(300);assert(s.refreshes==6 and r.get("wind")==false,"the good one applies")
   r.advance(2000);assert(s.refreshes==6,"and ends the retries")
   s.Error="LoadFailed";s.update();assert(s.refreshes==7);r.advance(4);s.Error=nil;s.values={};s.update()
   r.advance(1.1);assert(s.refreshes==8 and r.get("wind")==true);r.advance(2000);assert(s.refreshes==8,"the older retry stands down")
  end
 end)
 test("a snapshot already outdated when it connects is refreshed at once; Outdated that throws is not a failure",function()
  local s=snapshot({});s.Outdated=true;s.onRefresh=function()s.Outdated=false;s.values={alive_close=false}end
  local r=rig(serviceOf(s));r.config.start();assert(s.refreshes==1 and r.get("close")==false and #r.warnings==0)
  local odd=setmetatable(snapshot({}),{__index=function(_,key)if key=="Outdated"then error("no such property")end;return nil end})
  r=rig(serviceOf(odd));r.config.start();assert(odd.refreshes==0 and r.all(true)and #r.waits==0)
 end)
 test("no UpdateAvailable signal is not a failure",function()
  local s=snapshot({alive_wind=false});s.UpdateAvailable=nil
  local r=rig(serviceOf(s));r.config.start();r.advance(1000);assert(r.get("wind")==false and #r.waits==0 and #r.warnings==1)
 end)
 test("the ceiling is false: every attribute is false, and ConfigService is never asked",function()
  local asked=false
  local r=rig(function()asked=true;error("asked")end,function()return false end)
  r.config.start();r.config.command("/alive all on");r.advance(1000);assert(r.all(false)and not asked)
 end)
 test("/alive: one or all, on, off and clear; overrides beat config and survive a refresh; nonsense is ignored",function()
  local s=snapshot({alive_springs=false});local r=rig(serviceOf(s));r.config.start()
  assert(r.config.command(" /ALIVE springs On ")and r.get("springs")==true)
  r.at=10;s.update();assert(r.get("springs")==true,"still overridden")
  assert(r.config.command("/alive springs clear")and r.get("springs")==false)
  assert(r.config.command("/alive all off")and r.all(false))
  assert(r.config.command("/alive all clear")and r.get("wind")==true and r.get("springs")==false)
  for _,odd in ipairs({"/alive","/alive wind","/alive nope off","/alive wind maybe","/alive wind off now","alive wind off","/stars 5"})do
   assert(not r.config.command(odd),odd)
  end
  assert(not r.config.command(nil)and not r.config.command(5)and not r.config.command({}))
  assert(r.get("wind")==true)
 end)
 test("a set that throws never reaches the caller; start twice is once",function()
  local config=Config.new({service=serviceOf(snapshot({})),set=function()error("locked")end,now=function()return 0 end,
   ceiling=function()return true end,spawn=function(fn)fn()end,wait=function()end})
  config.start();config.start();assert(config.command("/alive all off"))
 end)
 test("the real server wrote a boolean for every feature",function()
  for _,f in ipairs(Alive.Features)do assert(type(workspace:GetAttribute(Alive.attribute(f)))=="boolean",f)end
 end)
 return{passed=#cases,cases=cases}
end
