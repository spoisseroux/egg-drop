-- Studio Client. Alive step-down (ALIVE-BUILD-PLAN-2026-11-22 step 0): p75 over 40 ms twice is level 1, once
-- more is level 2, never back up; warm-up, refocus, stalls and ignored windows do not count. Pure.
-- Usage: require(PlayerScripts.Client.ZZSpecs.AliveBudget)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Budget=require(client.AliveBudget)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function window(ms,n)return table.create(n or 100,ms)end
 local function levels(list)
  local state,out={level=0,slow=0},{}
  for _,ms in ipairs(list)do state=Budget.step(window(ms),state);table.insert(out,state.level)end
  return table.concat(out," ")
 end
 test("twice slow is level 1, once more level 2, and it never comes back up",function()
  assert(levels({50})=="0"and levels({50,50})=="0 1"and levels({50,50,50})=="0 1 2")
  assert(levels({50,16,50,16,16,50,16,16,16})=="0 0 1 1 1 2 2 2 2")
  assert(levels({50,50,50,50,50})=="0 1 2 2 2")
  assert(levels({16,33,40,40,40})=="0 0 0 0 0","40 ms itself is not over")
 end)
 test("p75: a quarter of hitches does not count, more does; short windows and stalls are ignored",function()
  local function mixed(slow)local t=window(16,100-slow);for _=1,slow do table.insert(t,60)end;return t end
  assert(Budget.step(mixed(25),nil).slow==0 and Budget.step(mixed(26),nil).slow==1)
  assert(Budget.step(window(60,Budget.MinSamples-1),nil).slow==0)
  local stalled=window(60);table.insert(stalled,1500);assert(Budget.step(stalled,nil).slow==0)
  assert(Budget.step({},nil).level==0)
 end)
 test("step is pure: the samples and the state it was given are not changed",function()
  local samples,state={30,10,20,50,50,50,50,50,50,50},{level=0,slow=1}
  Budget.step(samples,state)
  assert(samples[1]==30 and samples[2]==10 and state.slow==1 and state.level==0)
 end)
 test("frame(): warm-up and ignored frames drop the whole window",function()
  local s={state={level=0,slow=0},samples={},span=0,quietUntil=20}
  local now=0
  local function run(seconds,dt,ignore)
   for _=1,math.floor(seconds/dt+.5)do now+=dt;Budget.frame(s,now,dt,ignore)end
  end
  run(19.5,.06);assert(s.state.slow==0 and #s.samples==0,"first 20 s")
  run(6,.06);assert(s.state.slow==1,"one slow window: "..s.state.slow)
  run(3,.06);run(1,.06,true);run(3,.06);assert(s.state.slow==1,"a round in the middle drops it")
  run(1,.06,true);run(30,.016);assert(s.state.slow==1)
  run(1,.016,true);run(10.5,.06);assert(s.state.level==2,"level "..s.state.level)
 end)
 test("level() is 0 in Studio and safe to call every frame",function()
  for _=1,100 do
   local level=Budget.level()
   assert(if game:GetService("RunService"):IsStudio()then level==0 else level>=0 and level<=2)
  end
 end)
 return{passed=#cases,cases=cases}
end
