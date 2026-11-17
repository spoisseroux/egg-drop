-- Deck network rework, client side (artifacts/qa-2026-11-16c-v775/deck-network-plan.md).
-- One owner per player, started by the DeckNet LocalScript when FeatureFlags.DeckNetStream is on.
--   S1 shadow: receives the owner's BoardSnapshot stream into BoardSnapshots and keeps
--      stats on what drawing from it would look like, next to what the Parts show today.
--   S2 render (DeckNetRender): before the deck's render loop each frame, moves this
--      board's Parts (locally) to their interpolated position at the render tick, so every
--      reader of `source.Position` draws the smoothed motion. With no packet for
--      FallbackSeconds the Parts are left to replication (8 Hz from the server).
--   The event clock (merges, impacts, items, score, round end on the render tick) is
--      `due`/`schedule` below; its wiring in init.client.lua is the S2b patch in the plan.
-- Presentation only: nothing here is sent to the server or decides an outcome.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Flags=require(ReplicatedStorage.Shared.FeatureFlags)
local Codec=require(ReplicatedStorage.Shared.BoardSnapshotCodec)
local Snapshots=require(script.Parent.BoardSnapshots)

local Net={}
Net.FallbackSeconds=1
Net.LateLimit=.25 -- an event this late (seconds of render time) still plays; later ones skip the juice
Net.RenderAction="EggDropDeckNet"

function Net.enabled()return Flags.DeckNetStream==true end
function Net.rendering()return Flags.DeckNetRender==true and Flags.DeckNetStream==true end

local state

local function studioHook(name)
 if not RunService:IsStudio()then return nil end
 local value=Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")and Players.LocalPlayer.PlayerGui:GetAttribute(name)
 return if type(value)=="number"then value else nil
end

-- Studio-only loss and delay hooks for the harness (there is no loss knob in Studio):
-- PlayerGui attributes DeckNetLoss (0-1) and DeckNetDelay (extra seconds, +/- half as jitter).
local function receive(payload)
 local s=state;if not s then return end
 local loss=studioHook("DeckNetLoss")
 if loss and s.random:NextNumber()<loss then s.lost+=1;return end
 local delay=studioHook("DeckNetDelay")
 if delay and delay>0 then
  local wait=delay*(1+s.random:NextNumber(-.5,.5))
  task.delay(wait,function()if state==s then Net.ingest(payload,os.clock())end end)
  return
 end
 Net.ingest(payload,os.clock())
end

function Net.ingest(payload,arrival)
 local s=state;if not s then return false end
 local resetId,tick,flags,count=Codec.decode(payload,s.ids,s.xs,s.ys)
 if not resetId then s.malformed+=1;return false end
 return s.buffer:push(arrival,resetId,tick,flags,s.ids,s.xs,s.ys,count)
end

-- Shadow stats: per frame, how far each moving ball would step drawn from snapshots
-- versus drawn from its Part, and how many frames a moving Part had nothing new (a hitch).
local function shadow(s,board,tick)
 local frameStep=0
 for _,part in ipairs(board:GetChildren())do
  local eggId=part:GetAttribute("EggId")
  if eggId then
   local id=Codec.wireId(eggId)
   local x,y,where=s.buffer:sample(id,tick)
   if where=="live"then
    local last=s.drawn[id]
    if last then
     local step=math.sqrt((x-last[1])^2+(y-last[2])^2)
     if step>frameStep then frameStep=step end
     last[1],last[2]=x,y
    else s.drawn[id]={x,y}end
   end
   local position=part.Position
   local seen=s.partSeen[part]
   if seen then
    local moved=(position-seen.position).Magnitude>1e-4
    if moved then
     if seen.moving and seen.still>=.05 then s.partHitches+=1 end
     seen.moving,seen.still=true,0
    elseif seen.moving then
     seen.still+=s.frameDt;if seen.still>.4 then seen.moving=false end
    end
    seen.position=position
   else s.partSeen[part]={position=position,moving=false,still=0}end
  end
 end
 if frameStep>s.maxStep then s.maxStep=frameStep end
end

local function step()
 local s=state;if not s then return end
 local now=os.clock()
 s.frameDt=if s.lastFrame then now-s.lastFrame else 0;s.lastFrame=now
 local board=s.board
 if s.buffer:silence(now)>Net.FallbackSeconds then s.fallbackFrames+=1;if #s.queue>0 then Net.flush()end;return end
 local tick=s.buffer:advance(now)
 if not tick then return end
 if s.shadow then shadow(s,board,tick)end
 if Net.rendering()then
  for _,part in ipairs(board:GetChildren())do
   local eggId=part:GetAttribute("EggId")
   if eggId then
    local x,y=s.buffer:sample(Codec.wireId(eggId),tick)
    if x then
     local position=Vector3.new(x,y,0)
     if part.Position~=position then part.Position=position end
    end
   end
  end
 end
 Net.runDue(tick)
 -- Studio: publish the stats for the harness (it runs in another Luau VM).
 if s.studio and now-(s.statsAt or 0)>=.5 then
  s.statsAt=now
  local gui=Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
  if gui then
   if gui:GetAttribute("DeckNetResetStats")==true then gui:SetAttribute("DeckNetResetStats",false);Net.resetStats()end
   gui:SetAttribute("DeckNetStats",game:GetService("HttpService"):JSONEncode(Net.stats()))
  end
 end
end

-- Start once for the local player's board folder.
function Net.start(board,options)
 if state or not Net.enabled()then return state end
 local remote=ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BoardSnapshot",10)
 if not remote then return nil end
 options=options or {}
 state={board=board,buffer=Snapshots.new(),ids={},xs={},ys={},random=Random.new(),lost=0,malformed=0,
  shadow=options.shadow~=false,drawn={},partSeen=setmetatable({},{__mode="k"}),partHitches=0,maxStep=0,fallbackFrames=0,
  queue={},frameDt=0,studio=RunService:IsStudio()}
 state.connection=remote.OnClientEvent:Connect(receive)
 -- First in the render step, before the deck's RenderStepped loop reads the Parts.
 RunService:BindToRenderStep(Net.RenderAction,Enum.RenderPriority.First.Value,step)
 state.reset=board:GetAttributeChangedSignal("ResetId"):Connect(function()
  if state then Net.flush();table.clear(state.drawn)end
 end)
 return state
end

function Net.stop()
 local s=state;if not s then return end
 state=nil
 s.connection:Disconnect();s.reset:Disconnect()
 pcall(function()RunService:UnbindFromRenderStep(Net.RenderAction)end)
end

function Net.renderTick()return state and state.buffer.renderTick or nil end
function Net.active()return state~=nil and Net.rendering()and state.buffer:silence(os.clock())<=Net.FallbackSeconds end

-- S2b event clock. `schedule(tick, fn, fields)` runs fn(lateSeconds) once the render tick
-- reaches `tick`, or at once when the clock is not active or the tick is already shown.
-- lateSeconds above LateLimit tells the caller to keep the state change but skip its juice.
-- `fields` (e.g. {score=40}) are summed by `pending` while the event waits, so the HUD can
-- show the score the drawn board has earned so far.
function Net.schedule(tick,fn,fields)
 local s=state
 local now=s and s.buffer.renderTick
 if not s or not Net.active()or type(tick)~="number"or not now or tick<=now then
  local late=if now and type(tick)=="number"then math.max(0,(now-tick)/s.buffer.TickRate)else 0
  fn(late);return false
 end
 local entry={tick=tick,fn=fn}
 if fields then for key,value in pairs(fields)do entry[key]=value end end
 table.insert(s.queue,entry)
 return true
end
function Net.runDue(tick)
 local s=state;if not s or #s.queue==0 then return end
 local index=1
 while index<=#s.queue do
  local entry=s.queue[index]
  if entry.tick<=tick then
   table.remove(s.queue,index)
   local ok,problem=pcall(entry.fn,(tick-entry.tick)/s.buffer.TickRate)
   if not ok then warn("DeckNet event: "..tostring(problem))end
  else index+=1 end
 end
end
function Net.pending(key)
 local s=state;if not s then return 0 end
 local total=0
 for _,entry in ipairs(s.queue)do if type(entry[key])=="number"then total+=entry[key]end end
 return total
end
-- Run everything still queued (fallback to replication, a reset, leaving the deck).
function Net.flush()
 local s=state;if not s then return end
 local queue=s.queue;s.queue={}
 for _,entry in ipairs(queue)do pcall(entry.fn,math.huge)end
end

function Net.stats()
 local s=state;if not s then return nil end
 local b=s.buffer
 return {packets=b.stats.packets,stale=b.stats.stale,duplicates=b.stats.duplicates,resets=b.stats.resets,resyncs=b.stats.resyncs,
  starvedFrames=b.stats.starved,pausedFrames=b.stats.paused,frames=b.stats.frames,delay=b.delay,depth=b:depth(),lost=s.lost,malformed=s.malformed,
  maxStep=s.maxStep,partHitches=s.partHitches,fallbackFrames=s.fallbackFrames,queued=#s.queue}
end
function Net.resetStats()
 local s=state;if not s then return end
 for key in pairs(s.buffer.stats)do s.buffer.stats[key]=0 end
 s.lost,s.malformed,s.maxStep,s.partHitches,s.fallbackFrames=0,0,0,0,0
end

return Net
