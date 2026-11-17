-- Deck network harness (deck-network-plan.md S0). Studio only, from a Client execute_luau:
-- copy to src/client/ZZSpecs/DeckNetHarness.lua, restart Play, then
--   local H=require(PlayerScripts.Client.ZZSpecs.DeckNetHarness)
--   H.setup()                         -- fresh save -> first pet -> field round
--   H.echo(lag)                       -- does IncomingReplicationLag delay RemoteEvent / UnreliableRemoteEvent?
--   H.net(label, attempts, interval, lag, {loss=, delay=})  -- drop latency, Part hitches, stream stats
--   H.run(label, drops, interval, probe)                    -- frame-time round (deck-perf.md)
local H={}
local Players=game:GetService("Players")
local RS=game:GetService("RunService")
local function parts()
 local p=Players.LocalPlayer
 local board=game.ReplicatedStorage:WaitForChild("EggDropBoards"):WaitForChild(tostring(p.UserId))
 return p,board,game.ReplicatedStorage:FindFirstChild("BoardRequest",true)
end
function H.setup()
 local p,board,req=parts()
 for i=1,8 do
  if (board:GetAttribute("OwnedPets") or 0)>0 then break end
  local t=os.clock() while board:GetAttribute("FieldReady")~=true and os.clock()-t<3 do task.wait() end
  req:FireServer("drop",(i%5)/4*2-1) task.wait(.7)
 end
 task.wait(1.5)
 local rem=game.ReplicatedStorage:FindFirstChild("HatchRequest",true)
 local snap=game.ReplicatedStorage:FindFirstChild("NurserySnapshot",true)
 local got
 local c=snap.OnClientEvent:Connect(function(s)got=s end)
 task.wait(.4)
 rem:FireServer("snapshot")
 local t=os.clock() while not got and os.clock()-t<3 do task.wait() end
 c:Disconnect()
 if got and got.lastHatch then rem:FireServer("ack",got.lastHatch.id,got.revision) end
 task.wait(2)
 req:FireServer("mode","Board")
 task.wait(4)
 return "owned="..tostring(board:GetAttribute("OwnedPets")).." phase="..tostring(board:GetAttribute("FieldPhase")).." mode="..tostring(board:GetAttribute("Mode"))
end
function H.phone(on)
 local pg=Players.LocalPlayer.PlayerGui
 local bd=pg.EggDrop.Backdrop
 if on then
  H.saved=H.saved or {bd.Size,bd.Position}
  bd.Position=UDim2.fromOffset(0,0);bd.Size=UDim2.fromOffset(812,354)
 elseif H.saved then bd.Size,bd.Position=H.saved[1],H.saved[2] end
 task.wait(1)
 local deck=pg:FindFirstChild("EggDropDeck") and pg.EggDropDeck:FindFirstChild("PocketDeck",true)
 return "backdrop="..tostring(bd.AbsoluteSize).." deck="..tostring(deck and deck.AbsoluteSize)
end
function H.run(label,drops,interval,probe)
 local p,board,req=parts()
 local pg=p.PlayerGui
 -- fresh round each run: restart a live run, retry a finished one (both need RunSequence)
 for _=1,3 do
  if not board:GetAttribute("RoundOver") and (board:GetAttribute("Drops") or 0)==0 then break end
  local seq=board:GetAttribute("RunSequence")
  req:FireServer(if board:GetAttribute("RoundOver") then "reset" else "restart",seq)
  local t=os.clock() while os.clock()-t<4 and board:GetAttribute("RunSequence")==seq and (board:GetAttribute("Drops") or 0)>0 do task.wait(.1) end
  task.wait(1.5)
 end
 local startDrops=board:GetAttribute("Drops")
 local frames={}
 local last=os.clock()
 local idx=0
 local conn=RS.RenderStepped:Connect(function()local n=os.clock();idx+=1;frames[idx]=(n-last)*1000;last=n end)
 if probe then pg:SetAttribute("DeckPerf",true) end
 local t0=os.clock()
 for i=1,drops do
  local t=os.clock() while board:GetAttribute("FieldReady")~=true and os.clock()-t<3 do task.wait() end
  if board:GetAttribute("RoundOver") then break end
  req:FireServer("drop",math.sin(i*1.7)*0.85)
  task.wait(interval)
 end
 task.wait(2)
 conn:Disconnect()
 if probe then pg:SetAttribute("DeckPerf",false) end
 local sorted={}
 for i=6,idx do table.insert(sorted,frames[i]) end
 H.pool=H.pool or {}
 local key=label:match("^[^%d]+")
 H.pool[key]=H.pool[key] or {}
 for _,v in ipairs(sorted)do table.insert(H.pool[key],v) end
 table.sort(sorted)
 local n=#sorted
 local spikes=0
 for _,v in ipairs(sorted)do if v>20 then spikes+=1 end end
 local sum=0 for _,v in ipairs(sorted)do sum+=v end
 local res=string.format("%s frames=%d spikes=%d worst=%.1f p99=%.2f p50=%.2f mean=%.2f drops=%s merges=%s dur=%.1f",label,n,spikes,sorted[n],sorted[math.ceil(n*.99)],sorted[math.ceil(n*.5)],sum/n,tostring(startDrops).."->"..tostring(board:GetAttribute("Drops")),tostring(board:GetAttribute("Merges")),os.clock()-t0)
 if probe then task.wait(.2) res..="\n"..tostring(pg:GetAttribute("DeckPerfResult")) end
 return res
end

-- Network path: drop latency (input -> new ball part / Drops attribute) and the
-- replicated position cadence of moving balls. lag: nil, number (constant s) or
-- {lo,hi} (re-drawn every 50-150 ms, which reorders arrival timing like jitter).
function H.net(label,attempts,interval,lag,hooks)
 local p,board,req=parts()
 for _=1,3 do
  if not board:GetAttribute("RoundOver") and (board:GetAttribute("Drops") or 0)==0 then break end
  local seq=board:GetAttribute("RunSequence")
  req:FireServer(if board:GetAttribute("RoundOver") then "reset" else "restart",seq)
  local t=os.clock() while os.clock()-t<4 and board:GetAttribute("RunSequence")==seq and (board:GetAttribute("Drops") or 0)>0 do task.wait(.1) end
  task.wait(1.5)
 end
 local net=settings().Network
 local running=true
 hooks=hooks or {}
 p.PlayerGui:SetAttribute("DeckNetLoss",hooks.loss)
 p.PlayerGui:SetAttribute("DeckNetDelay",hooks.delay)
 p.PlayerGui:SetAttribute("DeckNetResetStats",true)
 if type(lag)=="number" then net.IncomingReplicationLag=lag
 elseif type(lag)=="table" then
  task.spawn(function()local r=Random.new(7) while running do net.IncomingReplicationLag=r:NextNumber(lag[1],lag[2]);task.wait(r:NextNumber(.05,.15)) end end)
 else net.IncomingReplicationLag=0 end
 task.wait(1)
 local last={},{}
 local prevPos,prevMoved={},{}
 local frames,stalls,moving,maxStall,stallRun=0,0,0,0,{}
 local lastFrame=os.clock()
 local conn=RS.Heartbeat:Connect(function() -- render is throttled when Studio is unfocused
  local now=os.clock();frames+=1
  for _,part in ipairs(board:GetChildren())do
   if part:IsA("BasePart")then
    local pos=part.Position;local old=prevPos[part]
    local changed=old~=nil and (pos-old).Magnitude>1e-4
    -- a ball that moved last frame and moves again later is "in motion"; a frame
    -- with no new position in between is a stall (the renderer has nothing new)
    if prevMoved[part] then
     moving+=1
     if not changed then stalls+=1;stallRun[part]=(stallRun[part] or 0)+(now-lastFrame)
     else if (stallRun[part] or 0)>maxStall then maxStall=stallRun[part] end;stallRun[part]=0 end
    end
    if changed then prevMoved[part]=true elseif (stallRun[part] or 0)>.3 then prevMoved[part]=false end
    prevPos[part]=pos
   end
  end
  lastFrame=now
 end)
 local lat,latDrops={},{}
 for i=1,attempts do
  local t=os.clock() while board:GetAttribute("FieldReady")~=true and os.clock()-t<3 do task.wait() end
  if board:GetAttribute("RoundOver") then break end
  local before=board:GetAttribute("Drops")
  local sent=os.clock();local gotPart,gotDrops
  local a=board.ChildAdded:Connect(function()if not gotPart then gotPart=os.clock()end end)
  local b=board:GetAttributeChangedSignal("Drops"):Connect(function()if not gotDrops then gotDrops=os.clock()end end)
  req:FireServer("drop",math.sin(i*1.7)*0.85)
  local w=os.clock() while os.clock()-w<interval do task.wait() end
  a:Disconnect();b:Disconnect()
  if gotDrops and board:GetAttribute("Drops")~=before then table.insert(latDrops,(gotDrops-sent)*1000) end
  if gotPart then table.insert(lat,(gotPart-sent)*1000) end
 end
 task.wait(2)
 conn:Disconnect();running=false;net.IncomingReplicationLag=0
 p.PlayerGui:SetAttribute("DeckNetLoss",nil);p.PlayerGui:SetAttribute("DeckNetDelay",nil)
 local stream=tostring(p.PlayerGui:GetAttribute("DeckNetStats"))
 local function med(t)if #t==0 then return 0 end;table.sort(t);return t[math.ceil(#t/2)],t[#t]end
 local lm,lx=med(lat);local dm,dx=med(latDrops)
 return string.format("%s lag=%s frames=%d dropToBall median=%.0fms max=%.0fms dropToCount median=%.0fms max=%.0fms movingBallFrames=%d stalls=%d (%.1f%%) longestStall=%.0fms drops=%s",
  label,type(lag)=="table"and(lag[1].."-"..lag[2])or tostring(lag or 0),frames,lm,lx,dm,dx,moving,stalls,moving>0 and stalls*100/moving or 0,maxStall*1000,tostring(board:GetAttribute("Drops"))).."\n  stream "..stream
end


-- What the deck actually draws: every ball Part's Position read at the end of the render
-- step (after BoardNetClient's First-priority driver, before the deck's RenderStepped
-- loop draws it). A hitch is a moving ball that shows no new position for 50 ms or more;
-- a freeze snap is a hitch that ends in a visible jump (over 0.08 stud, about half an LCD
-- pixel: the catch-up of a late update; a ball pushed from rest starts small instead);
-- a jump is a frame step over 3x the ball's previous step (a catch-up snap). Steps under
-- 0.01 stud (sub-pixel settling) do not count as motion.
-- hooks: {loss=0-1 (stream only), delay=s (stream only), burn=ms per frame (slow device)}.
function H.draw(label,attempts,interval,lag,hooks)
 local p,board,req=parts()
 hooks=hooks or {}
 for _=1,3 do
  if not board:GetAttribute("RoundOver") and (board:GetAttribute("Drops") or 0)==0 then break end
  local seq=board:GetAttribute("RunSequence")
  req:FireServer(if board:GetAttribute("RoundOver") then "reset" else "restart",seq)
  local t=os.clock() while os.clock()-t<4 and board:GetAttribute("RunSequence")==seq and (board:GetAttribute("Drops") or 0)>0 do task.wait(.1) end
  task.wait(1.5)
 end
 local net=settings().Network
 local running=true
 if type(lag)=="number" then net.IncomingReplicationLag=lag
 elseif type(lag)=="table" then
  task.spawn(function()local r=Random.new(7) while running do net.IncomingReplicationLag=r:NextNumber(lag[1],lag[2]);task.wait(r:NextNumber(.05,.15)) end end)
 else net.IncomingReplicationLag=0 end
 p.PlayerGui:SetAttribute("DeckNetLoss",hooks.loss);p.PlayerGui:SetAttribute("DeckNetDelay",hooks.delay)
 p.PlayerGui:SetAttribute("DeckNetResetStats",true)
 task.wait(1)
 local seen={}
 local hitches,jumps,frames,longest,slow,snaps=0,0,0,0,0,0
 local last=os.clock()
 RS:BindToRenderStep("DeckNetHarnessDraw",Enum.RenderPriority.Last.Value,function()
  local now=os.clock();local dt=now-last;last=now;frames+=1
  if dt>.04 then slow+=1 end
  if hooks.burn then local t=os.clock() while os.clock()-t<hooks.burn/1000 do end end
  for _,part in ipairs(board:GetChildren())do
   if part:IsA("BasePart")then
    local pos=part.Position;local e=seen[part]
    if not e then seen[part]={pos=pos,moving=false,still=0,step=0}
    else
     local step=(pos-e.pos).Magnitude
     -- 0.01 stud is about 1/18 of an LCD pixel: settling micro-motion is not motion.
     if step>.01 then
      if e.moving and e.still>=.05 then hitches+=1;if step>.08 then snaps+=1 end end
      if e.still>longest and e.moving then longest=e.still end
      if e.moving and e.step>1e-3 and e.still<1e-6 and step>3*e.step and step>.05 then jumps+=1 end
      e.moving,e.still,e.step=true,0,step
     elseif e.moving then
      e.still+=dt;if e.still>.4 then e.moving=false;e.step=0 end
     end
     e.pos=pos
    end
   end
  end
 end)
 local lat={}
 for i=1,attempts do
  local t=os.clock() while board:GetAttribute("FieldReady")~=true and os.clock()-t<3 do task.wait() end
  if board:GetAttribute("RoundOver") then break end
  local sent=os.clock();local got
  local a=board.ChildAdded:Connect(function()if not got then got=os.clock()end end)
  req:FireServer("drop",math.sin(i*1.7)*0.85)
  local w=os.clock() while os.clock()-w<interval do task.wait() end
  a:Disconnect()
  if got then table.insert(lat,(got-sent)*1000)end
 end
 task.wait(2)
 RS:UnbindFromRenderStep("DeckNetHarnessDraw")
 running=false;net.IncomingReplicationLag=0
 p.PlayerGui:SetAttribute("DeckNetLoss",nil);p.PlayerGui:SetAttribute("DeckNetDelay",nil)
 table.sort(lat)
 return string.format("%s lag=%s frames=%d slowFrames=%d freezeSnaps=%d hitches>=50ms=%d jumps=%d longestFreeze=%.0fms dropToPart=%.0fms drops=%s merges=%s\n  stream %s",
  label,type(lag)=="table"and(lag[1].."-"..lag[2])or tostring(lag or 0),frames,slow,snaps,hitches,jumps,longest*1000,lat[math.max(1,#lat//2)]or -1,
  tostring(board:GetAttribute("Drops")),tostring(board:GetAttribute("Merges")),tostring(p.PlayerGui:GetAttribute("DeckNetStats")))
end

-- Taps through the game's own dropEgg (Studio hook in init.client.lua), mashing every frame
-- after each sent drop until the next one goes. Reports tap -> first ball view, tap -> next
-- tap allowed, refusals and the ghost handoff gap.
function H.taps(label,drops,lag)
 local p,board,req=parts()
 local pg=p.PlayerGui
 for _=1,3 do
  if not board:GetAttribute("RoundOver") and (board:GetAttribute("Drops") or 0)==0 then break end
  local seq=board:GetAttribute("RunSequence")
  req:FireServer(if board:GetAttribute("RoundOver") then "reset" else "restart",seq)
  local t=os.clock() while os.clock()-t<4 and board:GetAttribute("RunSequence")==seq and (board:GetAttribute("Drops") or 0)>0 do task.wait(.1) end
  task.wait(1.5)
 end
 local net=settings().Network
 local running=true
 if type(lag)=="table" then
  task.spawn(function()local r=Random.new(7) while running do net.IncomingReplicationLag=r:NextNumber(lag[1],lag[2]);task.wait(r:NextNumber(.05,.15)) end end)
 else net.IncomingReplicationLag=lag or 0 end
 task.wait(1)
 pg:SetAttribute("DeckNetQuery",os.clock());task.wait(.1)
 local before=game:GetService("HttpService"):JSONDecode(pg:GetAttribute("DeckNetReport")or"{}")
 local toBall,toNext={},{}
 local function tap(i)
  pg:SetAttribute("DeckNetTestAim",.5+.4*math.sin(i*1.7))
  pg:SetAttribute("DeckNetTestTap",(pg:GetAttribute("DeckNetTestTap")or 0)+1)
 end
 local sentBefore=pg:GetAttribute("DeckNetTapSent")or 0
 local lastSentAt
 local i=0
 local deadline=os.clock()+40
 while (pg:GetAttribute("DeckNetTapSent")or 0)-sentBefore<drops and os.clock()<deadline and not board:GetAttribute("RoundOver")do
  i+=1
  local sent=pg:GetAttribute("DeckNetTapSent")or 0
  tap(i)
  RS.Heartbeat:Wait()
  if (pg:GetAttribute("DeckNetTapSent")or 0)>sent then
   local at=pg:GetAttribute("DeckNetTapAt")
   if lastSentAt then table.insert(toNext,(at-lastSentAt)*1000)end
   lastSentAt=at
   -- wait for its first ball view (ghost: this frame)
   local t=os.clock()
   while os.clock()-t<1.5 do
    local shown=pg:GetAttribute("DeckNetBallShownAt")
    if shown and shown>=at then table.insert(toBall,(shown-at)*1000);break end
    RS.Heartbeat:Wait()
   end
  end
 end
 task.wait(2)
 running=false;net.IncomingReplicationLag=0
 pg:SetAttribute("DeckNetQuery",os.clock());task.wait(.1)
 local after=game:GetService("HttpService"):JSONDecode(pg:GetAttribute("DeckNetReport")or"{}")
 local function med(t)if #t==0 then return -1,-1 end local c=table.clone(t);table.sort(c);return c[math.ceil(#c/2)],c[#c]end
 local bm,bx=med(toBall);local nm,nx=med(toNext)
 local sent=(after.intent and after.intent.sent or 0)-(before.intent and before.intent.sent or 0)
 local refused=(after.intent and after.intent.refused or 0)-(before.intent and before.intent.refused or 0)
 local g=after.ghost or {}
 return string.format("%s lag=%s sent=%d refused=%d tapToBall median=%.0f max=%.0f ms tapToNextTap median=%.0f max=%.0f ms ghost handoffs=%s gapMean=%.2f gapMax=%.2f blendMaxStep=%.3f timeouts=%s drops=%s",
  label,type(lag)=="table"and(lag[1].."-"..lag[2])or tostring(lag or 0),sent,refused,bm,bx,nm,nx,tostring(g.handoffs),(g.gapSum or 0)/math.max(1,g.handoffs or 0),g.gapMax or 0,g.blendMaxStep or 0,tostring(g.timeouts),tostring(board:GetAttribute("Drops")))
end

-- Round trip through the Studio-only echo remotes (server BoardNet.setup), with the given
-- IncomingReplicationLag. Compare against lag 0: if the RTT does not grow, Studio's lag
-- setting does not cover remotes and the harness must inject its own delay.
function H.echo(lag,samples)
 local remotes=game.ReplicatedStorage:WaitForChild("Remotes")
 local net=settings().Network
 net.IncomingReplicationLag=lag or 0
 task.wait(.5)
 local out={}
 for _,name in ipairs({"DeckNetEcho","DeckNetEchoUnreliable"})do
  local remote=remotes:FindFirstChild(name)
  if not remote then table.insert(out,name.." missing");continue end
  local rtts={}
  local pending={}
  local c=remote.OnClientEvent:Connect(function(stamp)if pending[stamp]then table.insert(rtts,(os.clock()-pending[stamp])*1000);pending[stamp]=nil end end)
  for i=1,(samples or 10)do local stamp=i+math.random();pending[stamp]=os.clock();remote:FireServer(stamp);task.wait(.1)end
  task.wait(math.max(1,(lag or 0)*3))
  c:Disconnect()
  table.sort(rtts)
  table.insert(out,string.format("%s lag=%.0fms rtt median=%.0fms n=%d",name,(lag or 0)*1000,rtts[math.max(1,#rtts//2)]or -1,#rtts))
 end
 net.IncomingReplicationLag=0
 return table.concat(out,"\n")
end
-- The game's BoardNetClient stats (published to PlayerGui in Studio).
function H.stream(reset)
 local gui=Players.LocalPlayer.PlayerGui
 if reset then gui:SetAttribute("DeckNetResetStats",true);return "reset requested" end
 return tostring(gui:GetAttribute("DeckNetStats"))
end
function H.pooled(key)
 local s=table.clone(H.pool[key] or {});table.sort(s)
 local n=#s;if n==0 then return key..": none" end
 local spikes=0 for _,v in ipairs(s)do if v>20 then spikes+=1 end end
 return string.format("%s pooled frames=%d spikes>20ms=%d worst=%.1f p99=%.2f p50=%.2f",key,n,spikes,s[n],s[math.ceil(n*.99)],s[math.ceil(n*.5)])
end
return H
