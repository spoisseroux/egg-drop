-- Baseline spec runner, Studio Play, CLIENT datamodel (execute_luau, datamodel_type=Client).
-- Starts a background run and returns immediately. Poll: _G.SPECRUN_CLIENT.done / .current / .results
-- When done, _G.SPECRUN_CLIENT.json holds {client=..,skipped=..,calls=..} as JSON.
-- Optional: set _G.SPECRUN_ONLY_CLIENT={Name=true,...} first to re-run only those.
-- Each spec: pcall(require(ZZSpecs.<Name>)(args)), 60 s timeout, task.wait() between specs.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local HttpService=game:GetService("HttpService")
local P=Players.LocalPlayer
local PG=P:WaitForChild("PlayerGui")
local client=P.PlayerScripts:WaitForChild("Client")
local Z=client:WaitForChild("ZZSpecs")
local shared=RS:WaitForChild("Shared")
local TIMEOUT=60
local SKIP={
 BoardRoundDriver="harness, no spec file",BunnySnapshot="fixture, no spec file",
 ClientBoardMirror="lockstep harness (needs DeckNetHarness + server round, ~25 s per round)",
 ClientSimLockstep="lockstep harness (needs server round + attribute DeckClientSim)",
 ClientSimRollback="lockstep harness (needs server round)",ClientSuiteRun="harness, no spec file",
 DHelp="helper, no spec file",DeckNetHarness="harness, no spec file",DeckPerfHarness="harness, no spec file",
 DeckPerfProbe="harness, no spec file",DeckScreenOld="stale old copy, no spec file",
 PetAssetsReadyFixture="fixture, no spec file",RevealCaptureFixture="capture fixture, no spec file",
 JellyRendererBenchmark="benchmark harness (long-running)",
 PersonalToyGardenTimeline="needs server and client modules together (server,client)",
 CoachMask="server spec (takes server); run in the server runner",
}
local function board()local b=RS:FindFirstChild("EggDropBoards");return b and b:FindFirstChild(tostring(P.UserId))end
local function pack(...)return table.pack(...)end
local DEFAULT={desc="(PlayerScripts.Client, PlayerGui)",make=function()return pack(client,PG)end}
local function guiBoard()return {desc="(PlayerGui.EggDrop, EggDropBoards[userId])",make=function()
 local g=PG:FindFirstChild("EggDrop");assert(g,"PlayerGui.EggDrop missing");return pack(g,board())end}end
local OVERRIDE={
 BoardSimDeterminism={desc="()",make=function()return pack()end},
 BoardRoundDeterminism={desc="()",make=function()return pack()end},
 HuePalette={desc="(ReplicatedStorage.Shared)",make=function()return pack(shared)end},
 FirstSpendGuide={desc="(client, ReplicatedStorage.Shared)",make=function()return pack(client,shared)end},
 StatsUI={desc="(function(name) return require(client[name]) end)",make=function()return pack(function(n)return require(client[n])end)end},
 LocalizationFit={desc="(client, PlayerGui, {strict=false})",make=function()return pack(client,PG,{strict=false})end},
 CompactDeck=guiBoard(),HardwareDeck=guiBoard(),JellyOverflow=guiBoard(),JellyRenderOwner=guiBoard(),
 SaveNoticeOwnership=guiBoard(),FieldFeedbackOwner=guiBoard(),
}
local R={results={},skipped={},calls={},current=nil,done=false}
_G.SPECRUN_CLIENT=R
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
  if _G.SPECRUN_ONLY_CLIENT and not _G.SPECRUN_ONLY_CLIENT[name]then -- optional re-run filter
  elseif SKIP[name]then R.skipped[name]=SKIP[name]
  else
   R.current=name
   local spec=OVERRIDE[name]or DEFAULT
   local ok,info=attempt(Z[name],spec.make)
   local desc=spec.desc
   if ok==false and spec==DEFAULT then -- retry any failure once with a ScreenGui host (some specs need a ScreenGui ancestor)
    local host=Instance.new("ScreenGui");host.Name="_SpecHost";host.ResetOnSpawn=false;host.Parent=PG
    ok,info=attempt(Z[name],function()return pack(client,host)end)
    desc="(PlayerScripts.Client, enabled ScreenGui host)";pcall(function()host:Destroy()end)
   end
   R.calls[name]=desc
   R.results[name]={ok=(ok==true),timeout=(ok=="timeout")or nil,info=(info:match("[^\n]*")or""):sub(1,240)}
  end
  task.wait()
 end
 R.current=nil;R.done=true
 R.json=HttpService:JSONEncode({client=R.results,skipped=R.skipped,calls=R.calls})
end)
return "started"
