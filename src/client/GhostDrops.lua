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
Ghosts.UnboundTimeout=1.5  -- no ack
Ghosts.ServerTimeout=2     -- acked, the server ball never drawn
Ghosts.HandoffTimeout=2.5  -- the server ball drawn, never met the ghost
Ghosts.RenderAction="EggDropDeckGhosts"

-- host: {add(source), remove(source), rebind(source, eggId), obstacles(out), constants,
-- resetId(), onContact(token), canShow()}
function Ghosts.new(host)
 local self=setmetatable({host=host,list={},byToken={},byEgg={},obstacles={},previousObstacles={},studio=RunService:IsStudio(),traces={},
  stats={spawned=0,handoffs=0,refused=0,timeouts=0,cleared=0,late=0,gone=0,held=0,gapMax=0,gapSum=0,blendMaxStep=0,swaps=0,settles=0,drops={}}},Ghosts)
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

-- A tap: tier, colour and launch from the deck's own state at the tap.
function Ghosts:spawn(token,aim,tier,now,look)
 if not self.host.canShow()then return nil end
 -- A bound on the work: past MaxLive ghosts the drop simply shows the server ball.
 if #self.list>=Ghosts.MaxLive then self.stats.capped=(self.stats.capped or 0)+1;return nil end
 local c=self.host.constants
 local spec=type(tier)=="number"and c.Tiers[tier]
 if not spec then return nil end
 local radius=spec.radius
 local vx,vy=Flight.launchVelocity(c,aim)
 local source=Instance.new("Part")
 source.Name="Ghost_"..token;source.Anchored=true;source.CanCollide=false;source.CanQuery=false;source.CanTouch=false
 source.Size=Vector3.one*radius*2;source.Color=spec.color;source.Position=Vector3.new(0,c.SpawnY,0)
 source:SetAttribute("Tier",tier);source:SetAttribute("EggId",-token);source:SetAttribute("BoardSerial",self.host.resetId())
 if look then source:SetAttribute("PowerUp",look.star==true);source:SetAttribute("ItemMark",look.mark)end
 local ghost={token=token,source=source,flight=Flight.new(c,vx,vy,radius,tier),radius=radius,born=now,state="flying"}
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

-- The server's ack. ok binds the ghost to its ball; not ok fades it.
function Ghosts:ack(token,ok,eggId)
 local g=self.byToken[token];if not g then return end
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
 local g=self.byEgg[eggId]
 if not g or g.state=="fading"then return false end
 g.server,g.show,g.serverAt=source,show,os.clock()
 self.stats.held+=1
 return true
end
function Ghosts:holds(eggId)return self.byEgg[eggId]~=nil end
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
 for index=#self.list,1,-1 do self.stats.cleared+=1;self:finish(self.list[index],false)end
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
  if g.state=="flying"then
   local kind=flight:step(dt,obstacles)
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
