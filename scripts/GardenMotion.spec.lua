-- Deterministic production trajectory/coordinator math; no remotes/profile writes.
return function(server)
 local A=require(game.ReplicatedStorage.Shared.GardenActivity)
 local G=require(server.GardenState)
 local cases={};local metrics={};local function test(name,run)run();table.insert(cases,name)end
 local function actor(from,to,v,speed,via)
  local path,duration=A.plan(from,to,v,speed,0,.7,via)
  return {from=A.pack(from),to=A.pack(to),startTime=0,endTime=duration,path=path,mode="Room",behavior="follow"},duration
 end
 test("reverse nearly-opposed perpendicular and tight turns have finite bounded control hulls",function()
  for _,v in ipairs({Vector3.new(-9,0,0),Vector3.new(-8.99,0,0),Vector3.new(-8,0,0),Vector3.new(0,0,9),Vector3.new(18,0,0)})do
   for _,target in ipairs({Vector3.new(4,0,0),Vector3.new(-.05,0,0)})do
    local a,duration=actor(Vector3.zero,target,v,9)
    assert(duration<10,"excessive braking trip: "..duration)
    local start=A.sample(a,0);assert((start.position-Vector3.zero).Magnitude<1e-7 and(start.velocity-v).Magnitude<1e-6)
    for i=0,240 do
     local s=A.sample(a,duration*i/240)
     assert(s.position.Magnitude<=target.Magnitude+v.Magnitude*.125+.001,"escaped bounded control hull")
     assert(s.velocity.Magnitude<=math.max(9,v.Magnitude)+.001,"speed bound")
    end
    assert((A.sample(a,duration).position-target).Magnitude<1e-6 and A.sample(a,duration).velocity.Magnitude<1e-6)
   end
  end
 end)
 test("closed chord via is finite and the Lawn join has exact shared velocity",function()
  local a,duration=actor(Vector3.zero,Vector3.zero,Vector3.zero,3,Vector3.new(0,0,4))
  assert(duration<20 and #a.path>=2)
  for i=0,240 do local s=A.sample(a,duration*i/240);assert(s.position.X==s.position.X and s.velocity.Magnitude<=3.001)end
  local b=actor(Vector3.zero,Vector3.new(4,0,4),Vector3.zero,3,Vector3.new(0,0,4))
  local join=0
  for _,leg in ipairs(b.path)do join+=leg.duration;if not leg.pivot and(A.vector(leg.to)-Vector3.new(0,0,4)).Magnitude<.0001 then break end end
  local before,after=A.sample(b,join-1e-6),A.sample(b,join+1e-6)
  assert((before.position-after.position).Magnitude<.0001 and(before.velocity-after.velocity).Magnitude<.0001,"Lawn velocity corner")
 end)
 test("opposed outgoing Lawn tangent falls back to a stopped join without throwing",function()
  for i=0,36 do
   local theta=i*math.pi/18
   local from=Vector3.zero;local to=Vector3.new(math.sin(theta)*4,0,math.cos(theta)*4)
   local a,duration=actor(from,to,Vector3.new(-8.99,0,0),3,Vector3.new(0,0,4))
   assert(duration<30)
   for j=0,60 do local s=A.sample(a,duration*j/60);assert(s.position.Magnitude<12 and s.velocity.Magnitude<9.001)end
  end
 end)
 test("a missing follow snapshot finishes its published braking tail and holds forever",function()
  local path,duration=A.plan(Vector3.zero,Vector3.new(12,0,0),Vector3.new(9,0,0),18,0,0,nil,Vector3.new(16,0,0))
  local a={from={0,0,0},to={12,0,0},startTime=0,endTime=duration,path=path,mode="Room"}
  local final=A.sample(a,duration)
  assert(final.velocity.Magnitude<1e-7 and final.position.Magnitude<=14.001)
  for _,late in ipairs({60,1000})do local s=A.sample(a,duration+late);assert((s.position-final.position).Magnitude<1e-7 and s.velocity.Magnitude==0)end
 end)
 local function fixture()
  local c={now=0,input={[1]={petId="pip",owned=true,alive=true,characterId=1,petGeneration=0,mode="Room",position=Vector3.new(0,3,0),anchor=Vector3.zero,yaw=0}}}
  c.g=G.new({now=function()return c.now end});return c
 end
 test("one sender focus sync cannot advance another owner's cached observation time",function()
  local c=fixture();c.input[2]=table.clone(c.input[1]);c.input[2].position=Vector3.new(100,3,0);c.input[2].anchor=Vector3.new(100,0,0)
  c.g:sync(c.input);c.now=.4;c.g:syncOne(1,c.input[1])
  assert(c.g.actors[2].ownerSampleAt==0,"cached observer sample timestamp advanced")
  c.now=.5;c.input[2].position+=Vector3.new(8,0,0);c.input[2].anchor+=Vector3.new(8,0,0);c.g:sync(c.input)
  assert((c.g.actors[2].ownerVelocity-Vector3.new(16,0,0)).Magnitude<.0001,"other owner's16 walk discarded as teleport")
 end)
 test("sustained16 owner travel has bounded recovery and settles after stopping without teleports",function()
  local c=fixture();local speed,gap,turn=0,0,0
  for frame=1,7200 do
   c.now=frame/120
   if c.now<=30 then c.input[1].anchor=Vector3.new(16*c.now,0,0);c.input[1].position=c.input[1].anchor+Vector3.new(0,3,0)end
   local old=c.g.actors[1];local before=old and A.sample(old,c.now)
   c.g:step(1/120,c.input);local a=c.g.actors[1]
   if a then
    local s=A.sample(a,c.now);speed=math.max(speed,s.velocity.Magnitude);gap=math.max(gap,(s.position-c.input[1].anchor).Magnitude)
    if before then
     assert((s.position-before.position).Magnitude<.0001 and(s.velocity-before.velocity).Magnitude<.0001,string.format("2Hz replacement lost pose/velocity (float32 absolute epsilon.0001) t=%.3f p=%.9f v=%.9f",c.now,(s.position-before.position).Magnitude,(s.velocity-before.velocity).Magnitude))
     local angle=math.abs(math.atan2(math.sin(s.yaw-before.yaw),math.cos(s.yaw-before.yaw)));turn=math.max(turn,angle);assert(angle<1e-5,"2Hz heading snapped")
    end
   end
  end
  local final=A.sample(c.g.actors[1],c.now)
  assert(speed<=18.001 and gap<16 and(final.position-c.input[1].anchor).Magnitude<.1,string.format("walk16 maxSpeed=%.6f maxGap=%.6f finalGap=%.6f finalX=%.6f targetX=%.6f behavior=%s action=%s pathLegs=%d start=%.6f end=%.6f",speed,gap,(final.position-c.input[1].anchor).Magnitude,final.position.X,c.input[1].anchor.X,tostring(c.g.actors[1].behavior),tostring(c.g.actors[1].action),#(c.g.actors[1].path or{}),c.g.actors[1].startTime,c.g.actors[1].endTime))
  metrics.walk16={seconds=60,maxSpeed=speed,maxGap=gap,finalGap=(final.position-c.input[1].anchor).Magnitude,maxReplacementYaw=turn}
 end)
 test("2Hz reversals preserve position velocity heading and finite JSON-safe paths",function()
  local c=fixture()
  for frame=1,2400 do
   c.now=frame/120
   local x=math.sin(c.now*.7)*12
   c.input[1].anchor=Vector3.new(x,0,0);c.input[1].position=c.input[1].anchor+Vector3.new(0,3,0)
   local old=c.g.actors[1];local before=old and A.sample(old,c.now)
   c.g:step(1/120,c.input)
   local a=c.g.actors[1]
   if a and before then
    local s=A.sample(a,c.now)
    assert((s.position-before.position).Magnitude<.0001 and(s.velocity-before.velocity).Magnitude<.0001)
    assert(math.abs(math.atan2(math.sin(s.yaw-before.yaw),math.cos(s.yaw-before.yaw)))<1e-5)
    assert(a.endTime-a.startTime<30 and s.velocity.Magnitude<=18.001)
   end
  end
 end)
 test("stationary shove turns toward the shared toy instead of discarding its authored heading",function()
  local a,duration=actor(Vector3.zero,Vector3.zero,Vector3.zero,3)
  a.action="shove";a.yaw=-1.4
  local first,last=A.sample(a,0),A.sample(a,10)
  assert(math.abs(first.yaw-.7)<1e-5 and math.abs(last.yaw-a.yaw)<1e-5)
 end)
 test("90 and 180 degree pivots complete on the spot before accelerating",function()
  for _,degrees in ipairs({90,180})do
   local theta=math.rad(degrees);local target=Vector3.new(math.sin(theta)*4,0,math.cos(theta)*4)
   local path,duration=A.plan(Vector3.zero,target,Vector3.zero,4,0,0)
   local pivot=path[1];assert(pivot.pivot)
   assert(pivot.duration>=(if degrees==90 then .15 else .28)and pivot.duration<=(if degrees==90 then .24 else .40))
   local a={from={0,0,0},to=A.pack(target),startTime=0,endTime=duration,path=path}
   for frame=0,60 do local s=A.sample(a,pivot.duration*frame/60);assert(s.position.Magnitude<.000001 and s.velocity.Magnitude==0 and s.pivot and math.abs(s.pivotPhase-frame/60)<.00001 and math.abs(s.pivotTurn-theta)<.00001)end
   local final=A.sample(a,pivot.duration);assert(math.abs(math.atan2(math.sin(final.yaw-theta),math.cos(final.yaw-theta)))<.00001)
  end
 end)
 test("reversal publishes brake then in-place pivot; moving curve heading follows its actual tangent",function()
  local path,duration=A.plan(Vector3.zero,Vector3.new(0,0,-5),Vector3.new(0,0,4),4,0,0)
  assert(not path[1].pivot and path[2].pivot and path[1].duration<=.251)
  local a={from={0,0,0},to={0,0,-5},startTime=0,endTime=duration,path=path}
  local before=A.sample(a,0);assert((before.velocity-Vector3.new(0,0,4)).Magnitude<.00001)
  local elapsed=0
  for _,leg in ipairs(path)do
   if not leg.pivot then for frame=1,60 do local t=leg.duration*frame/60
    if t>.121 then local s=A.sample(a,elapsed+t);local velocity=s.velocity
     if Vector2.new(velocity.X,velocity.Z).Magnitude>.001 then local expected=math.atan2(velocity.X,velocity.Z)
      assert(math.abs(math.atan2(math.sin(s.yaw-expected),math.cos(s.yaw-expected)))<.0001)
     end
    end
   end end
   elapsed+=leg.duration
  end
 end)
 return {passed=#cases,cases=cases,metrics=metrics}
end
