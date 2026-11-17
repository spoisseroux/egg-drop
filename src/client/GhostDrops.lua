-- Deck network S5 (deck-network-plan.md, architect review section 3): the ghost ball.
-- A tap shows its ball in the same frame: a local view (a fake source Part the deck's
-- renderer draws like any ball) flying the shared free flight (GhostFlight) against the
-- balls as drawn: it falls, bounces, rolls and settles like the server ball (v880 QA:
-- stopping dead on first contact and waiting made the real ball bounce a second time).
-- The real view takes over where the two meet: mid-motion when the drawn server ball
-- coincides with the ghost going the same way (a swap, no blend), else once both have
-- settled (a short blend, never upward unless the server ball truly rests higher). A refused or lost drop fades and removes it. The ghost plays
-- no sounds: the landing plop is the server's impact (the ghost carries the server id
-- once bound, so that impact finds it). Presentation only; the server decides everything.
local RunService=game:GetService("RunService")
local Flight=require(script.Parent.GhostFlight)
local NoGhosts=table.freeze({})

local Ghosts={};Ghosts.__index=Ghosts
Ghosts.BlendSeconds=.1
Ghosts.SwapDistance=.25  -- x radius: close enough to swap with no blend
Ghosts.SettleSpeed=.6    -- studs/s: the drawn server ball has settled
Ghosts.SettleSeconds=.12
Ghosts.RiseStep=.04      -- studs per frame: the most a blend may lift the ball
Ghosts.MaxLive=6          -- ghosts drawn at once (one lives up to ~2.5 s; taps come every 0.47 s)
Ghosts.SlideStep=.25     -- studs per frame: the most a blend moves the ball
Ghosts.TraceSeconds=.8   -- Studio: how long the shown ball is traced after the handoff
Ghosts.FadeSeconds=.15
-- v890 QA (poor connections): a ghost is bound to its drop by the server's ack or by the
-- server Part's DropToken, whichever arrives first, and lives as long as the drop is in
-- flight. These are only backstops for a lost answer (the remote is reliable; a refused or
-- expired queued drop is acked false and fades at once). They were 1.5 and 2 s, so on a
-- 1 s+ link the ghost faded and the real ball appeared later: "dropping then coming back".
Ghosts.UnboundTimeout=8    -- no ack and no Part
Ghosts.ServerTimeout=3     -- bound, the server ball never drawn (its Part follows the ack within
                           -- about one Part interval; a ball merged before any Part existed is
                           -- ended by mergedAway, code review 2026-11-17)
Ghosts.HandoffTimeout=2.5  -- the server ball drawn, never met the ghost
Ghosts.RenderAction="EggDropDeckGhosts"
-- v890 QA (poor connections, "a pause right before merging"): a ghost that touches a
-- same-tier drawn ball merges at once on the client: the two balls hide, the merge blob and
-- sound play, and a predicted result ball (itself a ghost, one tier up) flies from the
-- contact. The server's merge event (with both ball ids) confirms it and binds the result
-- ghost to the real result ball, which then hands over like any ghost. Anything else undoes
-- it: the event names only one of the pair, the partner leaves, the drop is refused, or the
-- newest snapshot tick passes the expected merge tick plus PredictSlackTicks. Predicted
-- results never predict again (one level deep); max-tier clears are not predicted.
-- OFF (Studio, v890): the ghost's local flight is 1 to 3 studs off the server ball (it
-- gives no impulses to what it lands on), so it often names the wrong partner: 1 of 4
-- predictions confirmed even at zero lag, and an undo (balls vanish, then come back) looks
-- worse than the pause. The real fix is the client-run board (client-sim-plan.md, Option B).
Ghosts.PredictMerges=false
-- OFF (Studio, v890): ghosts as obstacles for each other let two quick same-tier drops
-- "merge" mid-air on the client (stopped 13 to 17 studs from where the server merged).
Ghosts.GhostObstacles=false
Ghosts.PredictSlackTicks=60  -- server ticks (1/120 s of sim each) past the expected merge
Ghosts.PredictBackstop=6     -- seconds: undo without any tick information
Ghosts.ResultToken=70000     -- result ghosts' tokens (client drop tokens are 1-65535)

-- host: {add(source), remove(source), rebind(source, eggId), obstacles(out), constants,
-- resetId(), onContact(token), canShow()}
function Ghosts.new(host)
 local self=setmetatable({host=host,list={},byToken={},byEgg={},obstacles={},previousObstacles={},studio=RunService:IsStudio(),traces={},
  stats={spawned=0,handoffs=0,refused=0,timeouts=0,cleared=0,late=0,gone=0,held=0,gapMax=0,gapSum=0,blendMaxStep=0,swaps=0,settles=0,drops={},
   predicted=0,confirmed=0,undone=0},predictions={},consumed={},predictedPartner={},resultSerial=0},Ghosts)
 -- A name per instance: render-step names are shared across every Luau VM in the client,
 -- and a spec's ghosts unbinding the game's (same name) stopped the game's ghosts stepping.
 Ghosts.instances=(Ghosts.instances or 0)+1
 self.renderAction=Ghosts.RenderAction.."_"..Ghosts.instances.."_"..tostring(math.random(1,1e9))
 RunService:BindToRenderStep(self.renderAction,Enum.RenderPriority.First.Value+1,function()self:step(os.clock())end)
 return self
end

function Ghosts:destroy()
 self:clear()
 pcall(function()RunService:UnbindFromRenderStep(self.renderAction)end)
end

function Ghosts:isGhost(source)
 for _,g in ipairs(self.list)do if g.source==source then return true end end
 return false
end
function Ghosts:count()return #self.list end

-- A ghost of `tier` at (x, y) moving (vx, vy). nil past MaxLive or for an unknown tier.
function Ghosts:make(token,tier,x,y,vx,vy,now,look)
 -- A bound on the work: past MaxLive ghosts the drop simply shows the server ball.
 if #self.list>=Ghosts.MaxLive then self.stats.capped=(self.stats.capped or 0)+1;return nil end
 local c=self.host.constants
 local spec=type(tier)=="number"and c.Tiers[tier]
 if not spec then return nil end
 local radius=spec.radius
 local source=Instance.new("Part")
 source.Name="Ghost_"..token;source.Anchored=true;source.CanCollide=false;source.CanQuery=false;source.CanTouch=false
 source.Size=Vector3.one*radius*2;source.Color=spec.color;source.Position=Vector3.new(x,y,0)
 source:SetAttribute("Tier",tier);source:SetAttribute("EggId",-token);source:SetAttribute("BoardSerial",self.host.resetId())
 if look then source:SetAttribute("PowerUp",look.star==true);source:SetAttribute("ItemMark",look.mark)end
 local flight=Flight.new(c,vx,vy,radius,tier);flight.x,flight.y=x,y
 local ghost={token=token,source=source,flight=flight,radius=radius,born=now,state="flying"}
 if self.studio then
  ghost.trace={}
  -- Studio measurement only: PlayerGui DeckNetGhostLegacy replays the v880 ghost (stop on
  -- first touch, wait, blend at the drawn first contact) for before/after numbers.
  local gui=game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
  ghost.legacy=gui~=nil and gui:GetAttribute("DeckNetGhostLegacy")==true
  ghost.flight.legacy=ghost.legacy
 end
 table.insert(self.list,ghost);self.byToken[token]=ghost
 self.stats.spawned+=1
 self.host.add(source)
 return ghost
end
-- A tap: tier, colour and launch from the deck's own state at the tap.
function Ghosts:spawn(token,aim,tier,now,look)
 if not self.host.canShow()then return nil end
 local c=self.host.constants
 local vx,vy=Flight.launchVelocity(c,aim)
 return self:make(token,tier,0,c.SpawnY,vx,vy,now,look)
end

-- The server's ack. ok binds the ghost to its ball; not ok fades it.
function Ghosts:ack(token,ok,eggId,tick)
 local g=self.byToken[token];if not g then return end
 if ok and type(tick)=="number"then g.ackTick=tick end
 if not ok and g.prediction then self:undo(g.prediction,"refused")end
 -- Already bound by its Part's DropToken (the Part beat the ack): nothing to do.
 if g.eggId~=nil and g.eggId==eggId then return end
 if not ok or type(eggId)~="number"then self.stats.refused+=1;self:fade(g);return end
 -- A late ack: the server ball is already drawn (its Part and stream sample beat the
 -- ack). Binding now would point its id at the ghost and draw the ball twice.
 if self.host.hasView and self.host.hasView(eggId)then self.stats.late+=1;self:fade(g);return end
 g.eggId,g.boundAt=eggId,os.clock()
 self.byEgg[eggId]=g
 self.host.rebind(g.source,eggId)
end

-- The server ball's view is ready (BoardNetClient.afterSpawn). Returns true when a ghost
-- holds it: `show` then runs at the handoff instead of now.
function Ghosts:holdSpawn(eggId,source,show)
 -- A ball a confirmed prediction already merged away: its Part never shows.
 if self.consumed[eggId]then return true end
 local g=self.byEgg[eggId]
 if not g then g=self:bindByToken(eggId,source)end
 if not g or g.state=="fading"then return false end
 g.server,g.show,g.serverAt=source,show,os.clock()
 self.stats.held+=1
 return true
end
function Ghosts:holds(eggId)return self.byEgg[eggId]~=nil end
-- The Part beat the ack: its DropToken names the ghost, which binds now (as the ack would).
function Ghosts:bindByToken(eggId,source)
 local token=source and source:GetAttribute("DropToken")
 local g=type(token)=="number"and self.byToken[token]
 if not g or g.eggId~=nil or g.state=="fading"or type(eggId)~="number"then return nil end
 -- Already drawn (e.g. the content gate added it): binding would draw the ball twice.
 if self.host.hasView and self.host.hasView(eggId)then self.stats.late+=1;self:fade(g);return nil end
 g.eggId,g.boundAt=eggId,os.clock()
 self.byEgg[eggId]=g;self.stats.tokenBound=(self.stats.tokenBound or 0)+1
 self.host.rebind(g.source,eggId)
 return g
end
-- Drops shown but not yet known to the server's replicated state (no ack, no Part): the
-- next tap's tier is that many places down the queue (NextTier, PreviewTier1, PreviewTier2).
function Ghosts:pending()
 local n=0
 for _,g in ipairs(self.list)do if g.eggId==nil and g.state~="fading"then n+=1 end end
 return n
end
-- Is this server Part waiting for a ghost's handoff (its view must not be added yet)?
function Ghosts:holding(source)
 for _,g in ipairs(self.list)do if g.server==source and g.show then return true end end
 return false
end

-- The server ball left before the handoff (a quick merge): the ghost goes with it.
function Ghosts:serverGone(eggId)
 local g=self.byEgg[eggId];if not g then return false end
 self.stats.gone+=1
 g.endedBy="gone"
 -- How far the ghost was from where the server ball merged (the merge blob plays there).
 if g.server then local sp,p=g.server.Position,g.source.Position;g.handoffJump=math.sqrt((sp.X-p.X)^2+(sp.Y-p.Y)^2)end
 g.show=nil;self:finish(g,false)
 return true
end

function Ghosts:fade(g)
 if g.state=="fading"then return end
 g.state,g.fadeAt="fading",os.clock()
 g.endedBy=g.endedBy or "fade"
end

-- Remove a ghost; `handoff` shows the server view in its place.
function Ghosts:finish(g,handoff)
 local index=table.find(self.list,g);if index then table.remove(self.list,index)end
 self.byToken[g.token]=nil
 if g.eggId and self.byEgg[g.eggId]==g then self.byEgg[g.eggId]=nil end
 self.host.remove(g.source)
 g.source:Destroy()
 if handoff then self.stats.handoffs+=1 end
 if g.show then local show=g.show;g.show=nil;show()end
 -- Studio: keep tracing the shown ball (now the server's) for the handoff report.
 if self.studio and g.trace then
  if handoff and g.server then table.insert(self.traces,{g=g,part=g.server,untilAt=os.clock()+Ghosts.TraceSeconds})
  else self:report(g)end
 end
end

-- Studio: what one drop looked like. Largest per-frame step, the handoff jump (and
-- whether it went up), and direction reversals (a second bounce shows as an extra one).
function Ghosts:report(g)
 local t=g.trace;if not t or #t<2 then return end
 local maxStep,reversals,upJumps,restRise=0,0,0,0
 local lastDy,still=0,0
 for i=2,#t do
  local dx,dy=t[i][1]-t[i-1][1],t[i][2]-t[i-1][2]
  local step=math.sqrt(dx*dx+dy*dy)
  if step>maxStep then maxStep=step;g.maxAt=(if t[i].handoff then "handoff" elseif i>(g.handoffIndex or math.huge)then "server" else "ghost")end
  if lastDy<-.01 and dy>.01 then reversals+=1 end
  if math.abs(dy)>.01 then lastDy=dy end
  -- An upward jump: the shown ball rises more than a frame of fall could explain while it
  -- was resting or falling (handoff discontinuity), not a bounce leaving a contact.
  if t[i].handoff and dy>.05 then upJumps+=1 end
  -- Rest, then rise: the shown ball sat still (3+ frames) and then went up (v880 QA:
  -- "jumping after hitting the bottom").
  if step<.01 then still+=1 else
   if still>=3 and dy>.05 then restRise+=1 end
   still=0
  end
 end
 local drops=self.stats.drops
 if #drops<64 then table.insert(drops,{maxStep=maxStep,reversals=reversals,upJumps=upJumps,restRise=restRise,jump=g.handoffJump or 0,swap=g.swapped==true,how=g.endedBy or "?",merging=g.flight.merging==true,maxAt=g.maxAt})end
end

-- A reset, a mode change, a menu: every ghost goes at once (held server views show).
function Ghosts:clear()
 for P in pairs(self.predictions)do P.done=true;if self.host.undoMerge then self.host.undoMerge(P)end end
 table.clear(self.predictions);table.clear(self.consumed);table.clear(self.predictedPartner)
 for index=#self.list,1,-1 do self.stats.cleared+=1;self:finish(self.list[index],false)end
end

-- A ghost's same-tier touch (obstacle o: {x, y, r, moving, source, tier, id}): predict the merge.
function Ghosts:predict(g,o)
 if not Ghosts.PredictMerges then return end
 local host=self.host
 local skips=self.stats.predictSkips or {};self.stats.predictSkips=skips
 local function skip(why)skips[why]=(skips[why]or 0)+1 end
 if not host.predictMerge or g.predictedResult or g.legacy or(g.state~="flying"and g.state~="resting")then return skip("ghost")end
 local partner,partnerId,tier=o[5],o[7],g.flight.tier
 local partnerGhost=o[8]
 local c=host.constants
 if not partner or type(partnerId)~="number"or(partnerId<0 and not partnerGhost)then return skip("partner")end
 if partnerGhost and(partnerGhost.predictedResult or partnerGhost.state~="resting")then return skip("ghostPartner")end
 if o[4]then return skip("moving")end
 if o[6]~=tier or type(tier)~="number"or tier>=#c.Tiers then return skip("tier")end
 if self.predictedPartner[partner]or(self:isGhost(partner)and not partnerGhost)then return skip("taken")end
 local x,y=(g.flight.x+o[1])/2,(g.flight.y+o[2])/2
 self.resultSerial+=1
 -- The server's result: the pair's mean velocity x 0.38 plus 2 up; both are still here.
 local r=self:make(Ghosts.ResultToken+self.resultSerial,tier+1,x,y,0,2,os.clock(),nil)
 if not r then return skip("capped")end
 r.predictedResult=true
 local P={ghost=g,result=r,partner=partner,partnerId=partnerId,partnerGhost=partnerGhost,tier=tier+1,x=x,y=y,at=os.clock(),expectSteps=g.flight.steps,
  fromX=g.flight.x,fromY=g.flight.y,otherX=o[1],otherY=o[2]}
 g.state,g.prediction,r.prediction="predicted",P,P
 self.predictions[P]=true;self.predictedPartner[partner]=P
 host.remove(g.source)
 if partnerGhost then partnerGhost.state,partnerGhost.prediction="predicted",P;host.remove(partnerGhost.source)end
 self.stats.predicted+=1
 host.predictMerge(P)
end
-- The server's merge event arrived (both ball ids). True when it confirms a prediction
-- (the caller then skips the merge juice already played).
function Ghosts:confirm(firstId,secondId,resultId)
 local hit=false
 for P in pairs(self.predictions)do
  local gid=P.ghost.eggId
  local pid=if P.partnerGhost then P.partnerGhost.eggId else P.partnerId
  local partnerIn=pid~=nil and(firstId==pid or secondId==pid)
  local ghostIn=gid~=nil and(firstId==gid or secondId==gid)
  if partnerIn and ghostIn then
   P.done,P.confirmed=true,true;self.predictions[P]=nil;self.predictedPartner[P.partner]=nil
   self.consumed[gid]=true;self.consumed[pid]=true
   local g,r=P.ghost,P.result
   g.show=nil;if table.find(self.list,g)then g.endedBy="predicted";self:finish(g,false)end
   local h=P.partnerGhost
   if h then h.show=nil;if table.find(self.list,h)then h.endedBy="predicted";self:finish(h,false)end end
   if r and table.find(self.list,r)and type(resultId)=="number"and not r.eggId then
    r.eggId,r.boundAt=resultId,os.clock();self.byEgg[resultId]=r;self.host.rebind(r.source,resultId)
   end
   self.stats.confirmed+=1;self:logPrediction(P,"confirmed")
   if self.host.confirmMerge then self.host.confirmMerge(P)end
   hit=true
  elseif partnerIn or ghostIn then
   self:undo(P,string.format("other(%s+%s)",tostring(firstId),tostring(secondId)))
  end
 end
 return hit
end
-- The server merged these balls (the merge event, on its tick). A ghost bound to one of them
-- that never got its Part (merged inside one Part interval) ends now instead of resting until
-- ServerTimeout. Ghosts holding a Part end through serverGone as before.
function Ghosts:mergedAway(firstId,secondId)
 for _,id in ipairs({firstId,secondId})do
  local g=type(id)=="number"and self.byEgg[id]
  if g and not g.server and g.state~="predicted"then self.stats.gone+=1;g.endedBy="mergedAway";g.show=nil;self:finish(g,false)end
 end
end
-- A drawn ball left (ChildRemoved): a prediction it was part of is wrong.
function Ghosts:partnerGone(source)
 local P=self.predictedPartner[source]
 if P and not P.done then self:undo(P,"gone")end
end
-- Studio diagnostics: the last outcomes (why, ids, how long the prediction stood).
function Ghosts:logPrediction(P,what)
 if not self.studio then return end
 local log=self.stats.predictLog or {};self.stats.predictLog=log
 if #log>=16 then table.remove(log,1)end
 table.insert(log,string.format("%s %.2fs ghost=%s partner=%s%s tier=%d",what,os.clock()-P.at,tostring(P.ghost.eggId),
  tostring(if P.partnerGhost then P.partnerGhost.eggId else P.partnerId),if P.partnerGhost then "(ghost)"else "",P.tier-1))
end
function Ghosts:undo(P,why)
 if P.done then return end
 self:logPrediction(P,"undo:"..tostring(why))
 P.done=true;self.predictions[P]=nil;self.predictedPartner[P.partner]=nil
 self.stats.undone+=1;self.stats.lastUndo=why
 local g,r=P.ghost,P.result
 if r and table.find(self.list,r)then r.show=nil;r.endedBy="undone";self:finish(r,false)end
 if table.find(self.list,g)and g.state=="predicted"then
  g.state,g.prediction="resting",nil;g.flight.merging=false
  self.host.add(g.source)
 end
 local h=P.partnerGhost
 if h and table.find(self.list,h)and h.state=="predicted"then
  h.state,h.prediction="resting",nil
  self.host.add(h.source)
 end
 if self.host.undoMerge then self.host.undoMerge(P)end
end

local function lerp(a,b,t)return a+(b-a)*t end

function Ghosts:step(now)
 if #self.traces>0 then
  for index=#self.traces,1,-1 do
   local tr=self.traces[index]
   if tr.part.Parent and now<tr.untilAt then local p=tr.part.Position;table.insert(tr.g.trace,{p.X,p.Y})
   else table.remove(self.traces,index);self:report(tr.g)end
  end
 end
 if #self.list==0 then self.lastStep=now;return end
 local dt=if self.lastStep then math.clamp(now-self.lastStep,0,.1)else 0
 self.lastStep=now
 if not self.host.canShow()then self:clear();return end
 local obstacles=self.obstacles
 self.host.obstacles(obstacles)
 -- v890 QA: the other ghosts are obstacles too (a quick second drop lands on, or merges
 -- with, the first one, as it does on the server). o[8] is the ghost itself; o[7] its
 -- server id, or minus its token until bound.
 local n=#obstacles
 for i=1,n do obstacles[i][8]=nil end -- reused entries: a drawn ball is never a ghost
 for _,h in ipairs(if Ghosts.GhostObstacles then self.list else NoGhosts)do
  if h.state~="fading"and h.state~="predicted"then
   n+=1;local o=obstacles[n];if not o then o={};obstacles[n]=o end
   o[1],o[2],o[3],o[4],o[5],o[6],o[7],o[8]=h.flight.x,h.flight.y,h.radius,false,h.source,h.flight.tier,h.eggId or -h.token,h
  end
 end
 -- Mark drawn balls that moved since the last frame (over 1 stud/s).
 -- One reused entry per drawn ball (no tables per frame on phones).
 local previous=self.previousObstacles
 self.frame=(self.frame or 0)+1
 local frame=self.frame
 for _,o in ipairs(obstacles)do
  local key=o[5]
  if key then
   local last=previous[key]
   o[4]=last~=nil and dt>0 and math.sqrt((o[1]-last[1])^2+(o[2]-last[2])^2)/dt>1
   if not last then last={};previous[key]=last end
   last[1],last[2],last[3]=o[1],o[2],frame
  else o[4]=false end
 end
 for key,last in pairs(previous)do if last[3]~=frame then previous[key]=nil end end
 for index=#self.list,1,-1 do
  local g=self.list[index]
  local flight=g.flight
  if g.state=="predicted"then
   local P=g.prediction
   if P and not P.done and P.ghost==g then
    local newest=self.host.newestTick and self.host.newestTick()
    local expected=g.ackTick and g.ackTick+(P.expectSteps or 0)+Ghosts.PredictSlackTicks
    if(expected and newest and newest>expected)or now-P.at>Ghosts.PredictBackstop then self:undo(P,"timeout")end
   end
   continue
  end
  if g.state=="flying"then
   local kind=flight:step(dt,obstacles)
   -- The step that stopped it on a same-tier ball (whether or not that was its first contact).
   if flight.merging and flight.partner and not g.predictTried then
    g.predictTried=true;self:predict(g,flight.partner)
    if g.state=="predicted"then continue end
   end
   -- Only a touch the server ball will also have made opens the next tap early (a drawn
   -- ball still moving is no proof; measured: an early open there was refused).
   if kind and kind~="movingBall"then self.host.onContact(g.token,kind)end
   if flight.resting then g.state="resting";g.restAt=now end
  end
  local x,y=flight.x,flight.y
  if g.state=="fading"then
   local t=(now-g.fadeAt)/Ghosts.FadeSeconds
   if t>=1 then self:finish(g,false);continue end
   g.source.Size=Vector3.one*g.radius*2*(1-t)
  elseif g.server and g.server.Parent then
   local sp=g.server.Position
   local svx,svy=0,0
   if g.lastServer and dt>0 then svx,svy=(sp.X-g.lastServer.X)/dt,(sp.Y-g.lastServer.Y)/dt end
   g.lastServer=sp
   local sspeed=math.sqrt(svx*svx+svy*svy)
   if sspeed<Ghosts.SettleSpeed then g.serverStill=(g.serverStill or 0)+dt else g.serverStill=0 end
   local gap=math.sqrt((sp.X-x)^2+(sp.Y-y)^2)
   if g.state~="blend"then
    -- 1) Where they meet going the same way (or both nearly still): swap, no blend.
    local gvx,gvy=if g.state=="resting"then 0 else flight.vx,if g.state=="resting"then 0 else flight.vy
    local together=(gvx*svx+gvy*svy)>0 or(sspeed<1.5 and math.sqrt(gvx*gvx+gvy*gvy)<1.5)
    -- Never upward: the server ball must be level with or below the ghost (v880 QA).
    if g.legacy then
     local close=gap<=g.radius*.5
     if close or(g.state=="resting"and sp.Y<=y+.05)or now-g.serverAt>1.5 then
      g.state,g.blendAt,g.fromX,g.fromY="blend",now,x,y;g.handoffJump=gap;g.endedBy="legacyBlend"
     end
    elseif gap<=g.radius*Ghosts.SwapDistance and together and sp.Y<=y+.05 and not flight.merging then
     g.handoffJump=gap;self.stats.swaps+=1
     self.stats.gapSum+=gap;if gap>self.stats.gapMax then self.stats.gapMax=gap end
     g.swapped=true;g.endedBy="swap"
     if g.trace then table.insert(g.trace,{sp.X,sp.Y,handoff=true});g.handoffIndex=#g.trace end
     g.source.Position=sp;self:finish(g,true);continue
    end
    -- 2) Both settled apart (the pile moved under one of them): a short blend.
    if g.state~="blend"and not g.legacy and((g.state=="resting"and not flight.merging and(g.serverStill or 0)>=Ghosts.SettleSeconds)or now-g.serverAt>Ghosts.HandoffTimeout)then
     g.state,g.blendAt,g.fromX,g.fromY="blend",now,x,y
     g.handoffJump=gap;self.stats.settles+=1
     g.endedBy=if now-g.serverAt>Ghosts.HandoffTimeout then "timeout" else "settle"
     self.stats.gapSum+=gap;if gap>self.stats.gapMax then self.stats.gapMax=gap end
    end
   end
   if g.state=="blend"then
    -- Never a jump up: a blend that rises (the server ball rests higher) takes long
    -- enough that no frame moves more than RiseStep upward.
    if not g.blendSeconds then
     local rise=math.max(0,sp.Y-g.fromY)
     local gap=math.sqrt((sp.X-g.fromX)^2+(sp.Y-g.fromY)^2)
     -- And a far blend (the server ball came to rest elsewhere) slides, at most SlideStep
     -- a frame, instead of snapping (measured: 5-stud blends in 0.1 s).
     g.blendSeconds=math.max(Ghosts.BlendSeconds,rise/Ghosts.RiseStep/60,gap/Ghosts.SlideStep/60)
    end
    local t=math.min(1,(now-g.blendAt)/g.blendSeconds)
    x,y=lerp(g.fromX,sp.X,t),lerp(g.fromY,sp.Y,t)
    local last=g.source.Position
    local step=(Vector2.new(x,y)-Vector2.new(last.X,last.Y)).Magnitude
    if step>self.stats.blendMaxStep then self.stats.blendMaxStep=step end
    if t>=1 then
     if g.trace then table.insert(g.trace,{x,y,handoff=true});g.handoffIndex=#g.trace end
     g.source.Position=Vector3.new(x,y,0);self:finish(g,true);continue
    end
   end
  elseif g.eggId then
   if now-g.boundAt>Ghosts.ServerTimeout then self.stats.timeouts+=1;self:fade(g)end
  elseif now-g.born>Ghosts.UnboundTimeout then
   self.stats.timeouts+=1;self:fade(g)
  end
  local position=Vector3.new(x,y,0)
  if g.source.Position~=position then g.source.Position=position end
  if g.trace then table.insert(g.trace,{x,y})end
 end
end

return Ghosts
