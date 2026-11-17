-- Deck network S5: the ghost ball's local flight (GhostFlight).
-- Studio: require(PlayerScripts.Client.ZZSpecs.GhostFlight)(PlayerScripts.Client, gui)
--   (also checks it matches BoardConfig.advanceFlight / launchVelocity exactly).
-- Offline: luau scripts/run_pure_spec.luau.
return function(client,_,modules)
 modules=modules or {}
 local Flight=modules.GhostFlight or require(client.GhostFlight)
 local Config=modules.Config or(game and require(game:GetService("ReplicatedStorage").Shared.BoardConfig))
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local c={Width=11,Height=19,Bank=2.2,Gravity=32,MaxSpeed=38,FixedStep=1/120,Pace=1.3,SpawnY=17.8,
  LaunchAngleDegrees=35,LaunchSpeed=10,bounce=.64,Tiers={{radius=.72},{radius=1.04}}}
 if Config and Config.Width then
  for _,key in ipairs({"Width","Height","Bank","Gravity","MaxSpeed","FixedStep","Pace","SpawnY","LaunchAngleDegrees","LaunchSpeed"})do
   assert(Config[key]==c[key],"spec constants drifted from BoardConfig: "..key)
  end
 end
 local function run(aim,obstacles,seconds,radius)
  local vx,vy=Flight.launchVelocity(c,aim)
  local f=Flight.new(c,vx,vy,radius or .72)
  local kind
  for _=1,math.floor((seconds or 3)*60)do kind=f:step(1/60,obstacles)or kind;if f.resting then break end end
  return f,kind
 end

 test("same integration as BoardConfig.advanceFlight and launchVelocity",function()
  if not(Config and Config.advanceFlight and Vector2)then return end -- Studio only
  for _,aim in ipairs({0,.2,.5,.9,1})do
   local vx,vy=Flight.launchVelocity(c,aim);local v=Config.launchVelocity(aim)
   assert(math.abs(vx-v.X)<1e-6 and math.abs(vy-v.Y)<1e-6,"launch velocity "..aim)
   local p=Config.launchPosition();local x,y=p.X,p.Y
   for _=1,60 do
    p,v=Config.advanceFlight(p,v,Config.FixedStep)
    x,y,vx,vy=Flight.advance(c,x,y,vx,vy,Config.FixedStep)
   end
   assert(math.abs(x-p.X)<1e-4 and math.abs(y-p.Y)<1e-4,"flight drifted at aim "..aim)
  end
 end)

 -- First contact is returned on the step it happens; run() keeps the first one seen.
 local function settle(aim,obstacles,radius,tier,seconds)
  local vx,vy=Flight.launchVelocity(c,aim)
  local f=Flight.new(c,vx,vy,radius or .72,tier)
  local first
  local trace={}
  for _=1,math.floor((seconds or 4)*60)do
   local kind=f:step(1/60,obstacles)
   first=first or kind
   table.insert(trace,{f.x,f.y})
   if f.resting then break end
  end
  return f,first,trace
 end

 test("a straight drop lands on the floor, bounces like the server ball and settles there",function()
  local f,first,trace=settle(.5,{})
  assert(first=="floor","first contact: "..tostring(first))
  assert(f.resting and math.abs(f.y-.72)<.05 and math.abs(f.x)<.05,"settled at the centre: "..f.x..","..f.y)
  -- it bounced: after the first touch the ghost went up again (Springy, fast landing)
  local touched,rose=false,false
  for i=2,#trace do
   if trace[i][2]<=.73 then touched=true end
   if touched and trace[i][2]>trace[i-1][2]+.01 then rose=true;break end
  end
  assert(rose,"a fast landing bounces (one continuous motion, no stop-and-wait)")
 end)

 test("it takes the server's real time to fall (fixed step at Pace)",function()
  local vx,vy=Flight.launchVelocity(c,.5)
  local f=Flight.new(c,vx,vy,.72)
  local frames=0
  while not f.contact and frames<600 do f:step(1/60,{});frames+=1 end
  -- 17.08 studs at 10 studs/s plus gravity 32, sim seconds / 1.3: about 0.5-0.75 s real
  assert(frames>=25 and frames<=50,"frames to first contact "..frames)
 end)

 test("a steep aim reaches a bank or the floor on the near side, then settles in the tray",function()
  local f,first=settle(0,{})
  assert(first=="bank"or first=="floor","first contact "..tostring(first))
  assert(f.resting and f.x>=-5.5 and f.x<=5.5)
 end)

 test("a drawn ball of another tier is bounced off (pair impulse), never entered",function()
  local o={0,5,1.04,false,nil,2}
  local f,first,trace=settle(.5,{o},.72,1)
  assert(first=="ball","first contact: "..tostring(first))
  for _,p in ipairs(trace)do assert(math.sqrt(p[1]^2+(p[2]-5)^2)>=.72+1.04-1e-6,"never overlaps the drawn ball")end
  assert(f.resting,"settles somewhere")
 end)

 test("a same-tier drawn ball stops the ghost (the server merges there)",function()
  local f,first=settle(.5,{{0,5,.72,false,nil,1}},.72,1)
  assert(first=="merge"and f.merging and f.resting,tostring(first))
 end)

 test("a drawn ball still moving reports movingBall as the first contact",function()
  local _,first=settle(.5,{{0,5,1.04,true,nil,2}},.72,1)
  assert(first=="movingBall",tostring(first))
 end)

 test("side walls bounce (no contact), the ghost never leaves the tray",function()
  local f=Flight.new(c,30,0,.72)
  for _=1,240 do f:step(1/60,{});assert(f.x>=-5.5+.72-1e-6 and f.x<=5.5-.72+1e-6,"inside: "..f.x);if f.resting then break end end
  assert(f.contact~=nil,"eventually touches the floor")
 end)

 test("a long frame is capped (no tunnelling through a ball)",function()
  local vx,vy=Flight.launchVelocity(c,.5)
  local f=Flight.new(c,vx,vy,.72,1)
  f:step(2,{{0,8,1.04,false,nil,2}}) -- a 2 s hitch is stepped as 0.1 s at most
  for _=1,60 do f:step(1/60,{{0,8,1.04,false,nil,2}})end
  assert(f.contact=="ball","met the ball, not the floor")
 end)

 test("a frame hitch costs at most MaxStepsPerFrame fixed steps",function()
  local vx,vy=Flight.launchVelocity(c,.5)
  local f=Flight.new(c,vx,vy,.72)
  f:step(.1,{})
  assert(f.steps<=Flight.MaxStepsPerFrame,"steps "..f.steps)
 end)

 test("resting is final, and motion is bounded in time",function()
  local f=settle(.5,{})
  local x,y=f.x,f.y
  assert(f:step(1/60,{})==nil and f.x==x and f.y==y)
  assert(f.realTime<=Flight.MaxSeconds+.1)
 end)

 return {passed=#cases,cases=cases}
end
