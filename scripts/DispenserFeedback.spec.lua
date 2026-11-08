return function(client,parent)
 local D=require(client.DropDispenser);local root=Instance.new("Frame");root.Size=UDim2.fromOffset(220,100);root.Parent=parent
 local reduced=false;local d=D.new(root,function()return reduced end);local cases={}
 local function test(name,run)run();table.insert(cases,name)end
 game:GetService("RunService").Heartbeat:Wait();game:GetService("RunService").Heartbeat:Wait()
 local ok,err=pcall(function()
  test("first snapshot is static; one accepted drop compresses fixed neutral instrument",function()
   d:update(1,0,24,true);assert(not d.nozzle.Visible);local seat=d.host.Position;local size=d.host.Size
   d:update(1,1,24,true);assert(d.pulses==1 and d.remaining==23 and d.nozzle.Visible and d.nozzleMotion)
   assert(d.host.Position==seat and d.host.Size==size and not d.nozzle.Active and not d.nozzle.Selectable)
  end)
  test("duplicate HUD never rebinds compression or increments count",function()
   local motion=d.nozzleMotion;for _=1,12 do d:update(1,1,24,true)end
   assert(d.pulses==1 and d.nozzleMotion==motion)
  end)
  test("counter jumps and run replacement remain silent static snapshots",function()
   d:cancel();d:update(1,8,24,true);assert(d.pulses==1 and d.remaining==16 and not d.nozzle.Visible)
   d:update(2,0,24,true);assert(d.pulses==1 and d.remaining==24 and not d.nozzle.Visible)
  end)
  test("reduced fade retains count without moving train or outline",function()
   reduced=true;d:update(2,1,24,true);assert(d.pulses==2 and d.remaining==23 and d.nozzle.Visible)
   assert(not d.rolling.Visible and not d.nozzleMotion and d.nozzleFade and d.nozzle.Size==UDim2.new(1,-4,1,-4))
  end)
  test("covered field keeps exact static counter and returns without another drop",function()
   d:update(3,0,24,true,false);assert(d.host.Visible and d.remaining==24 and not d.nozzle.Visible and not d.rolling.Visible)
   d:update(3,1,24,true,false);assert(d.host.Visible and d.remaining==23 and d.pulses==2)
   d:update(3,1,24,true,true);assert(d.host.Visible and d.remaining==23 and d.pulses==2 and not d.nozzle.Visible)
  end)
  test("cover cancellation stops both effects without replay on uncover",function()
   d:cancel();assert(not d.nozzle.Visible and not d.rolling.Visible and not d.nozzleMotion and not d.nozzleFade)
   d:update(3,2,24,false);assert(d.pulses==2 and d.remaining==22);d:update(3,2,24,true)
   assert(d.pulses==2 and not d.nozzle.Visible)
  end)
 end)
 d:cancel();root:Destroy();assert(ok,err);return cases
end
