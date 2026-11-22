-- Baseline spec runner, Studio Play, SERVER datamodel (execute_luau, datamodel_type=Server).
-- Starts a background run and returns immediately. Poll: _G.SPECRUN_SERVER.done / .current / .results
-- When done, _G.SPECRUN_SERVER.json holds {server=..,skipped=..,calls=..} as JSON.
local RS=game:GetService("ReplicatedStorage")
local HttpService=game:GetService("HttpService")
local server=game:GetService("ServerScriptService"):WaitForChild("Server")
local Z=server:WaitForChild("ZZSpecs")
local shared=RS:WaitForChild("Shared")
local TIMEOUT=60
local SKIP={
 FixtureFrozenDaily="fixture data, passed to ToyFeatureProgress",FixtureFrozenV370="fixture data, passed to ToyFeatureProgress",
 FieldObjectiveBenchmark="benchmark, no spec file",
 PersonalToyGardenTimeline="needs server and client modules together (server,client)",
 ZZNativePack1="data pack, not a spec",ZZNativePack2="data pack, not a spec",ZZNativePack3="data pack, not a spec",ZZNativePack4="data pack, not a spec",
}
local function pack(...)return table.pack(...)end
local function src(name)return server[name].Source end
local function fixture(n)local v=Z[n];return v:IsA("ModuleScript")and v.Source or v.Value end
local DEFAULT={desc="(ServerScriptService.Server)",calls={function()return pack(server)end}}
local function sh()return {desc="(server, ReplicatedStorage.Shared)",calls={function()return pack(server,shared)end}}end
local function host()return {desc="(server, server.Source)",calls={function()return pack(server,server.Source)end}}end
local function none()return {desc="()",calls={function()return pack()end}}end
local OVERRIDE={
 BoardSimDeterminism=none(),BoardRoundDeterminism=none(),LookEggCatalog=none(),WorldBackdropFidelity=none(),
 HuePalette={desc="(ReplicatedStorage.Shared)",calls={function()return pack(shared)end}},
 NeutralPetRoster={desc="(ReplicatedStorage.Shared)",calls={function()return pack(shared)end}},
 BondCatalog=sh(),BookStateBits=sh(),BugReports=sh(),WeeklyShelf=sh(),WearableVariants=sh(),WelcomeSeed=sh(),WelcomeState=sh(),
 HueHost=host(),MaterialHost=host(),PetContactHost=host(),
 ToyFeatureHost={desc="(server, server.Source, toy) then (server, server.Source, feature)",calls={
  function()return pack(server,server.Source,"toy")end,function()return pack(server,server.Source,"feature")end}},
 PreferenceFlush={desc="(server, PlayerProgress.Source)",calls={function()return pack(server,src("PlayerProgress"))end}},
 PetAppearance={desc="(server, PlayerProgress.Source)",calls={function()return pack(server,src("PlayerProgress"))end}},
 SessionRecovery={desc="(server, PlayerProgress.Source, SessionProfile.Source)",calls={function()return pack(server,src("PlayerProgress"),src("SessionProfile"))end}},
 ToyFeatureProgress={desc="(server, FixtureFrozenV370, FixtureFrozenDaily)",calls={function()return pack(server,fixture("FixtureFrozenV370"),fixture("FixtureFrozenDaily"))end}},
 BoardAngle={desc="(server, {BoardSimulation=Source})",calls={function()return pack(server,{BoardSimulation=src("BoardSimulation")})end}},
 FieldObjectives={desc="(server, {FieldRun,BoardSimulation,BoardRound sources})",calls={function()return pack(server,{FieldRun=src("FieldRun"),BoardSimulation=src("BoardSimulation"),BoardRound=src("BoardRound")})end}},
 WorldRoutes={desc="(server, LoungeArt.Source)",calls={function()return pack(server,src("LoungeArt"))end}},
 HatchProgress={desc="(require(server.HatchProgress), require(Shared.EggCatalog))",calls={function()return pack(require(server.HatchProgress),require(shared.EggCatalog))end}},
}
local R={results={},skipped={},calls={},current=nil,done=false}
_G.SPECRUN_SERVER=R
local function attempt(mod,make)
 local state={done=false}
 local th=task.spawn(function()
  local ok,res=pcall(function()
   local f=require(mod);local a=make();return f(table.unpack(a,1,a.n))end)
  state.ok,state.res,state.done=ok,res,true
 end)
 local t0=os.clock()
 while not state.done and os.clock()-t0<TIMEOUT do task.wait(0.05)end
 if not state.done then pcall(task.cancel,th);return "timeout",">"..TIMEOUT.."s"end
 return state.ok,tostring(state.res)
end
task.spawn(function()
 local names={}
 for _,m in Z:GetChildren()do if m:IsA("ModuleScript")then names[#names+1]=m.Name end end
 table.sort(names)
 for _,name in names do
  if SKIP[name]then R.skipped[name]=SKIP[name]
  else
   R.current=name
   local spec=OVERRIDE[name]or DEFAULT
   local allok,allinfo=true,{}
   for _,make in spec.calls do
    local ok,info=attempt(Z[name],make)
    allinfo[#allinfo+1]=info
    if ok~=true then allok=ok;break end
   end
   R.calls[name]=spec.desc
   local info=(table.concat(allinfo," | "):match("[^\n]*")or""):sub(1,240)
   R.results[name]={ok=(allok==true),timeout=(allok=="timeout")or nil,info=info}
  end
  task.wait()
 end
 R.current=nil;R.done=true
 R.json=HttpService:JSONEncode({server=R.results,skipped=R.skipped,calls=R.calls})
end)
return "started"
