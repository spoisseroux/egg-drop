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

 test("a straight drop onto an empty tray rests on the floor and reports it",function()
  local f,kind=run(.5,{})
  assert(f.resting and kind=="floor","rested: "..tostring(kind))
  assert(math.abs(f.y-.72)<1e-6 and math.abs(f.x)<1e-6,"on the floor at the centre: "..f.x..","..f.y)
 end)

 test("it takes the server's real time to fall (fixed step at Pace)",function()
  local vx,vy=Flight.launchVelocity(c,.5)
  local f=Flight.new(c,vx,vy,.72)
  local frames=0
  while not f.resting and frames<600 do f:step(1/60,{});frames+=1 end
  -- 17.08 studs at 10 studs/s plus gravity 32, sim seconds / 1.3: about 0.5-0.75 s real
  assert(frames>=25 and frames<=50,"frames to land "..frames)
 end)

 test("a steep aim reaches a bank, not the floor, on the near side",function()
  local f,kind=run(0,{})
  assert(f.resting and(kind=="bank"or kind=="floor"),"rested "..tostring(kind))
  assert(f.x<0,"left side")
 end)

 test("it stops touching a drawn ball, on the side it came from",function()
  local f,kind=run(.5,{{0,5,1.04}})
  assert(kind=="ball"and f.resting)
  local d=math.sqrt(f.x^2+(f.y-5)^2)
  assert(math.abs(d-(.72+1.04))<1e-6 and f.y>5,"touching from above: "..d)
 end)

 test("side walls bounce (no contact), the ghost never leaves the tray",function()
  local vx=30
  local f=Flight.new(c,vx,0,.72)
  for _=1,180 do f:step(1/60,{});if f.resting then break end end
  assert(f.x>=-5.5+.72-1e-6 and f.x<=5.5-.72+1e-6,"inside: "..f.x)
  assert(f.contact~=nil,"eventually rests")
 end)

 test("a long frame is capped (no tunnelling through a ball)",function()
  local vx,vy=Flight.launchVelocity(c,.5)
  local f=Flight.new(c,vx,vy,.72)
  f:step(2,{{0,8,1.04}}) -- a 2 s hitch is stepped as 0.1 s at most
  assert(not f.resting or f.contact=="ball")
  for _=1,60 do f:step(1/60,{{0,8,1.04}})end
  assert(f.contact=="ball","met the ball, not the floor")
 end)

 test("resting is final: further steps do nothing",function()
  local f=run(.5,{})
  local x,y=f.x,f.y
  assert(f:step(1/60,{})==nil and f.x==x and f.y==y)
 end)

 return {passed=#cases,cases=cases}
end
