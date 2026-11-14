-- Deterministic owned duck mixer; real Sound routing remains native verification.
return function(client)
 local Audio=require(client.BoardAudio);local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function fixture()
  local a=setmetatable({ducks={},manualDisplayDucks=true,master=1,deviceActive=true},Audio)
  function a:refreshLoops()
   local gain=1;for _,value in pairs(self.ducks)do gain=math.min(gain,value)end
   self.output=self.master*(if self.deviceActive then 1 else 0)*gain
  end
  return a
 end
 test("one owner's600ms release cannot unduck a surviving quieter owner",function()
  local a=fixture();local owner={};a.ducks.boot=.22;a:setDisplayDuck(owner,true)
  assert(a.output==.22);a:setDisplayDuck(owner,false)
  for _=1,6 do a:stepDisplayDucks(.1);assert(a.output==.22)end
  assert(next(a.displayDucks)==nil and a.ducks.boot==.22)
 end)
 test("reactivation replaces recovery and mute/focus use current master",function()
  local a=fixture();local owner={};a:setDisplayDuck(owner,true);a:setDisplayDuck(owner,false);a:stepDisplayDucks(.2)
  local recovering=a.output;assert(recovering>10^(-6/20)and recovering<1)
  a:setDisplayDuck(owner,true);assert(math.abs(a.output-10^(-6/20))<1e-8)
  a:setDisplayDuck(owner,false);a.master=.4;a.deviceActive=false;a:stepDisplayDucks(.2);assert(a.output==0)
  a.deviceActive=true;a.ducks.round=.1;a:stepDisplayDucks(.2);assert(math.abs(a.output-.04)<1e-8)
  a:stepDisplayDucks(.2);assert(a.ducks.round==.1 and next(a.displayDucks)==nil)
 end)
 test("two reveal owners release independently and cleanup is bounded",function()
  local a=fixture();local one,two={},{};a:setDisplayDuck(one,true);a:setDisplayDuck(two,true);a:setDisplayDuck(one,false)
  for _=1,3 do a:stepDisplayDucks(.2)end
  assert(a.displayDucks[one]==nil and a.displayDucks[two].active and math.abs(a.output-10^(-6/20))<1e-8)
  a:clearDisplayDucks();a:refreshLoops();assert(next(a.ducks)==nil and a.output==1)
 end)
 return{passed=#cases,cases=cases}
end
