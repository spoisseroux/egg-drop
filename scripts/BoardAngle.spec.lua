-- Execute with fresh BoardSimulation source, isolated from the live board.
return function(server,sources)
 local Config=require(game.ReplicatedStorage.Shared.BoardConfig)
 local module=Instance.new("ModuleScript");module.Name="_BoardAngleSimulation";module.Source=assert(sources.BoardSimulation);module.Parent=server
 local ok,Simulation=pcall(require,module);module:Destroy();assert(ok,Simulation)
 local cases={}
 local function test(name,run)run();table.insert(cases,name)end
 local function close(a,b)assert((a-b).Magnitude<.00002,tostring(a).." ~= "..tostring(b))end
 local function empty(tier)
  local board=Simulation.new("Springy",0,{starter={}});board.queue={tier or 1};return board
 end
 test("normalized center angle is straight down; endpoints are symmetric 35 degrees at speed10",function()
  assert(Config.LaunchAngleDegrees==35 and Config.LaunchSpeed==10)
  close(Config.launchVelocity(.5),Vector2.new(0,-10))
  local left,right=Config.launchVelocity(0),Config.launchVelocity(1)
  assert(left.X<0 and right.X>0 and left.Y<0 and right.Y<0)
  assert(math.abs(left.Magnitude-10)<.00001 and math.abs(right.Magnitude-10)<.00001)
  assert(math.abs(left.X+right.X)<.00001 and math.abs(left.Y-right.Y)<.00001)
 end)
 test("every tier and angle begins at exactly the fixed origin with server-derived launch velocity",function()
  for tier=1,#Config.Tiers do for _,aim in ipairs({0,.25,.5,.75,1})do
   local board=empty(tier);assert(Simulation.drop(board,aim));local egg=board.eggs[1]
   close(egg.position,Vector2.new(0,Config.SpawnY));close(egg.velocity,Config.launchVelocity(aim));assert(egg.tier==tier)
  end end
 end)
 test("invalid nonfinite or nonnormalized input rejects before consuming a drop",function()
  local board=empty()
  for _,aim in ipairs({-.001,1.001,math.huge,-math.huge,0/0,".5",{},false})do
   assert(not Simulation.drop(board,aim));assert(board.drops==0 and board.serial==0 and #board.eggs==0)
  end
  assert(not Simulation.drop(board,nil))
 end)
 test("short dotted preview equals the fresh uncollided production flight at every sample",function()
  for _,aim in ipairs({0,.21,.5,.79,1})do
   local board=empty();assert(Simulation.drop(board,aim));local steps=0
   for sample=1,Config.PreviewCount do
    local target=math.floor(sample*Config.PreviewStep/Config.FixedStep+.5)
    while steps<target do Simulation.step(board,Config.FixedStep,{});steps+=1 end
    close(board.eggs[1].position,Config.flightPoint(aim,sample*Config.PreviewStep))
   end
  end
 end)
 test("angle changes cannot dodge a blocked spawn or bypass contact gate and cap",function()
  local board=empty();assert(Simulation.drop(board,0));assert(not Simulation.drop(board,1));assert(board.drops==1)
  board.contactGate=true;board.dropAge=.4;assert(not Simulation.canDrop(board));board.dropAge=1.8;assert(Simulation.canDrop(board))
  board=empty();for _=1,Config.MaxEggs do table.insert(board.eggs,{position=Vector2.zero,radius=.1})end
  assert(not Simulation.drop(board,.5)and board.drops==0)
 end)
 test("same seed and normalized angle trace remain deterministic",function()
  local a=Simulation.new("Springy",0,{seed=40001,starter={},contactGate=true})
  local b=Simulation.new("Springy",0,{seed=40001,starter={},contactGate=true})
  for _,aim in ipairs({0,1,.5,.17,.83})do
   assert(Simulation.drop(a,aim)==Simulation.drop(b,aim))
   for _=1,240 do Simulation.step(a,Config.FixedStep,{});Simulation.step(b,Config.FixedStep,{})end
   assert(a.serial==b.serial and #a.eggs==#b.eggs)
   for index,egg in ipairs(a.eggs)do close(egg.position,b.eggs[index].position);close(egg.velocity,b.eggs[index].velocity)end
  end
 end)
 return cases
end
