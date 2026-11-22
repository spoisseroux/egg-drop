-- QA ONLY, deliberately outside Rojo. Alive frame cost on a real client (ALIVE-BUILD-PLAN-2026-11-22 step 0).
-- Alternating off / on windows (off, on, on, off, ...): the client's own copy of the Alive attributes is
-- switched, so no other player and no server state changes; it is put back at the end or on destroy().
-- Stand still in the garden (or hold one menu open) for the whole run, then read owner.result.
-- local owner=require(module)({client=PlayerScripts.Client})   returns at once
-- options: pairs (3), seconds (8) and warm (2) per window, features (default all).
-- owner:status(), owner.result {off, on, windows}, owner:destroy(). Nothing is discarded but warm-up.
return function(api)
 api=api or {}
 local Run=game:GetService("RunService");local Stats=game:GetService("Stats")
 assert(Run:IsClient()and game:GetService("Players").LocalPlayer,"a real client is required")
 local Alive=require(game:GetService("ReplicatedStorage").Shared.Alive)
 local client=assert(api.client,"api.client: PlayerScripts.Client")
 local Spring=require(client.KitSpring)
 local okWind,WindClient=pcall(function()return require(client.WindClient)end)
 local features=api.features or Alive.Features
 local count,seconds,warm=api.pairs or 3,api.seconds or 8,api.warm or 2
 local owner={phase="running",done=false,windows={}}
 local saved={};for _,f in ipairs(features)do saved[f]=workspace:GetAttribute(Alive.attribute(f))end
 local function set(on)for _,f in ipairs(features)do workspace:SetAttribute(Alive.attribute(f),on)end end
 local function summary(values)
  local sorted=table.clone(values);table.sort(sorted)
  if #sorted==0 then return{count=0}end
  local sum=0;for _,v in ipairs(sorted)do sum+=v end
  local function p(n)return sorted[math.max(1,math.ceil(#sorted*n))]end
  return{count=#sorted,mean=sum/#sorted,p50=p(.5),p75=p(.75),p95=p(.95),max=sorted[#sorted]}
 end
 -- Not every counter exists on every client: a missing one is simply absent.
 local function counters()
  local out={}
  for _,name in ipairs({"SceneDrawcallCount","SceneTriangleCount","ShadowsDrawcallCount","ShadowsTriangleCount","UI2DDrawcallCount","UI2DTriangleCount","RenderCPUFrameTime","RenderGPUFrameTime","HeartbeatTime"})do
   local ok,value=pcall(function()return Stats[name]end);if ok and type(value)=="number"then out[name]=value end
  end
  local ok,memory=pcall(function()return Stats:GetTotalMemoryUsageMb()end);if ok then out.memoryMb=memory end
  return out
 end
 local function windMs()
  if not okWind or type(WindClient)~="table"then return nil end
  local value=rawget(WindClient,"stepMs");return if type(value)=="number"then value else nil
 end
 local function restore()
  Spring.profile=false
  for _,f in ipairs(features)do workspace:SetAttribute(Alive.attribute(f),saved[f])end
 end
 function owner:destroy()if self.done then return end;self.done=true;self.phase="cancelled";restore()end
 function owner:status()return self.phase.." "..#self.windows.."/"..count*2 end
 local function window(on)
  set(on)
  local began=os.clock();while os.clock()-began<warm do Run.RenderStepped:Wait();if owner.done then return end end
  local frames,spring,wind,live={},{},{},0
  began=os.clock()
  while os.clock()-began<seconds do
   local dt=Run.RenderStepped:Wait();if owner.done then return end
   table.insert(frames,dt*1000)
   live=math.max(live,Spring.count())
   table.insert(spring,if Spring.count()>0 then Spring.stepMs else 0)
   local ms=windMs();if ms then table.insert(wind,ms)end
  end
  table.insert(owner.windows,{on=on,frames=frames,spring=spring,wind=wind,mostSprings=live,counters=counters()})
 end
 task.spawn(function()
  Spring.profile=true
  local ok,problem=pcall(function()
   for pair=1,count do
    for half=1,2 do if not owner.done then window((half==1)==(pair%2==0))end end
   end
  end)
  if owner.done then return end
  owner.done=true;restore()
  if not ok then owner.phase="failed";owner.result={error=tostring(problem)};return end
  local function cohort(on)
   local frames,spring,wind={},{},{}
   for _,w in ipairs(owner.windows)do if w.on==on then
    for _,v in ipairs(w.frames)do table.insert(frames,v)end
    for _,v in ipairs(w.spring)do table.insert(spring,v)end
    for _,v in ipairs(w.wind)do table.insert(wind,v)end
   end end
   return{frame=summary(frames),springMs=summary(spring),windMs=summary(wind)}
  end
  owner.result={off=cohort(false),on=cohort(true),windows=owner.windows,windMeasured=windMs()~=nil}
  owner.phase="done"
 end)
 return owner
end
