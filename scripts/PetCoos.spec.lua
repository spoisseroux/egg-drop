return function(client)
 local Scheduler=require(client.PetCooScheduler);local Pose=require(client.PetCooPose)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function fixture()
  local audio={group={Volume=1},deviceActive=true,plays={},stops=0,busy=false}
  function audio:play(cue,pitch,gain,token)if self.fail then return false end;table.insert(self.plays,{cue=cue,pitch=pitch,gain=gain,token=token});return true end
  function audio:stopOwner()self.stops+=1 end
  function audio:petSpeechBusy()return self.busy end
  local scheduler=Scheduler.new(audio,{wait=function()return 35 end})
  local context={enabled=true,listener=Vector3.zero,identity={}}
  local function pet(id,x)return {petId=id,worldContext=true,model={Parent=true},origin=Vector3.new(x or 0,0,0),expression="neutral",greeting=2,lastGeneration=1}end
  return scheduler,audio,context,pet
 end
 test("one listener waits a full quiet interval and prefers its owner over visitors",function()
  local s,a,c,p=fixture();local owner=p("pip");local visitors={{visual=p("puddle",2)}}
  s:step(0,c,owner,visitors);s:step(34.9,c,owner,visitors);assert(#a.plays==0)
  s:step(35,c,owner,visitors);s:step(35.1,c,owner,visitors)
  assert(#a.plays==1 and a.plays[1].cue=="pet"and a.plays[1].pitch==.85 and a.plays[1].gain==.18 and owner.cooStart==35)
  s:destroy()
 end)
 test("mute blur board menus and focus drop opportunities without a return burst",function()
  for _,kind in ipairs({"context","mute","blur","speech"})do
   local s,a,c,p=fixture();local v=p("pip");s:step(0,c,v,{})
   if kind=="context"then c.enabled=false elseif kind=="mute"then a.group.Volume=0 elseif kind=="blur"then a.deviceActive=false else a.busy=true end
   s:step(35,c,v,{});assert(#a.plays==0)
   c.enabled=true;a.group.Volume=1;a.deviceActive=true;a.busy=false;s:step(100,c,v,{})
   assert(#a.plays==0 and s.nextAt==135);s:destroy()
  end
 end)
 test("ordinary walking and short pauses cannot starve room cadence; a moving due beat is skipped",function()
  local s,a,c,p=fixture();local v=p("pip")
  for frame=0,140 do
   local now=frame*.5
   -- Repeated 5.5s walks/1.5s pauses never form35 continuous quiet seconds.
   -- A later6s rest is an opportunity at70, not a queued catch-up at68.
   local quiet=now>=68 or now%7>=5.5
   v.gaitWeight=if quiet then 0 else 1;v.gardenAction=if quiet then "wanderPause"else "follow"
   s:step(now,c,v,{})
   if now<70 then assert(#a.plays==0)end
   if now==35 then
    assert(s.nextAt==70,"missing candidate queued or reset the listener cooldown")
    v.gaitWeight=0;v.gardenAction="wanderPause";s:step(35.1,c,v,{})
    assert(#a.plays==0 and s.nextAt==70,"a newly quiet pet replayed the missed beat")
   end
  end
  assert(#a.plays==1 and v.cooStart==70 and s.nextAt==105);s:destroy()
 end)
 test("nearest eligible visible visitor attenuates and out-of-range preview never speaks",function()
  local s,a,c,p=fixture();local owner=p("pip");owner.petting=true
  local near,far=p("orbit",5),p("puddle",12)
  s:step(0,c,owner,{{visual=far},{visual=near}});s:step(35,c,owner,{{visual=far},{visual=near}})
  assert(#a.plays==1 and a.plays[1].cue=="orbit"and a.plays[1].gain<.18 and near.cooStart==35)
  s:destroy();local preview=p("pip");preview.worldContext=false
  assert(not Scheduler.eligible(preview,nil,Vector3.zero)and not Scheduler.eligible(p("pip",29),nil,Vector3.zero))
 end)
 test("generation character mode and model retirement cancel only the captured speaker",function()
  local s,a,c,p=fixture();local v=p("pip");s:step(0,c,v,{});s:step(35,c,v,{})
  v.lastGeneration=2;s:step(35.1,c,v,{});assert(not s.active and not v.cooStart and a.stops==1)
  c.identity={};s:step(35.2,c,v,{});assert(s.nextAt==70.2)
  s:destroy()
 end)
 test("a visitor entering Board cancels its active voice without affecting another owner's pet",function()
  local s,a,c,p=fixture();local v=p("puddle",2);local mode="Room";local board={GetAttribute=function()return mode end}
  local visitors={{visual=v,board=board}};s:step(0,c,nil,visitors);s:step(35,c,nil,visitors);assert(s.active)
  mode="Board";s:step(35.1,c,nil,visitors);assert(not s.active and v.cooStart==nil and a.stops==1);s:destroy()
 end)
 test("failed or unavailable approved voice skips a beat with no pose and no queued replay",function()
  local s,a,c,p=fixture();local v=p("wick");a.fail=true;s:step(0,c,v,{});s:step(35,c,v,{})
  assert(#a.plays==0 and not v.cooStart and s.nextAt==70);a.fail=false;s:step(36,c,v,{});assert(#a.plays==0);s:destroy()
 end)
 test("retained species reuse original family recipe and reduced overlay never moves head hands or root",function()
  assert(Pose.family("bloom_pip")==Pose.family("pip")and Pose.family("foxfire_wick")==Pose.family("wick")and Pose.family("eclipse_orbit")==Pose.family("orbit"))
  local _,_,_,p=fixture();local v=p("pip");v.cooFamily=Pose.family("pip");v.cooStart=0;v.cosmeticTime=.065
  local r,n,h,m,e=Pose.sample(v);assert(math.abs(r)<=math.rad(4)and math.abs(n)<=math.rad(3)and h<=.05 and m>0 and e<1)
  v.reducedEffects=true;r,n,h,m,e=Pose.sample(v);assert(r==0 and n==0 and h==0 and m>0 and e>.9)
  v.petting=true;r,n,h,m,e=Pose.sample(v);assert(r==0 and n==0 and h==0 and m==0 and e==1)
 end)
 test("teardown stops one incidental owner and cannot speak after destruction",function()
  local s,a,c,p=fixture();local v=p("wick");s:step(0,c,v,{});s:step(35,c,v,{});s:destroy();s:step(100,c,v,{})
  assert(a.stops==1 and #a.plays==1 and v.cooStart==nil)
 end)
 return{passed=#cases,cases=cases}
end
