-- Deck network S5 (deck-network-plan.md, architect review section 3): the ghost ball.
-- A tap shows its ball in the same frame: a local view (a fake source Part the deck's
-- renderer draws like any ball) flying the shared free flight (GhostFlight) against the
-- balls as drawn. It stops on first contact and waits. When the server's ball for its
-- token is drawn there on the snapshot clock, the ghost blends to it (BlendSeconds) and
-- the real view takes over. A refused or lost drop fades and removes it. The ghost plays
-- no sounds: the landing plop is the server's impact (the ghost carries the server id
-- once bound, so that impact finds it). Presentation only; the server decides everything.
local RunService=game:GetService("RunService")
local Flight=require(script.Parent.GhostFlight)

local Ghosts={};Ghosts.__index=Ghosts
Ghosts.BlendSeconds=.12
Ghosts.FadeSeconds=.15
Ghosts.UnboundTimeout=1.5  -- no ack
Ghosts.ServerTimeout=2     -- acked, the server ball never drawn
Ghosts.HandoffTimeout=1.5  -- the server ball drawn, never reached the ghost
Ghosts.RenderAction="EggDropDeckGhosts"

-- host: {add(source), remove(source), rebind(source, eggId), obstacles(out), constants,
-- resetId(), onContact(token), canShow()}
function Ghosts.new(host)
 local self=setmetatable({host=host,list={},byToken={},byEgg={},obstacles={},
  stats={spawned=0,handoffs=0,refused=0,timeouts=0,cleared=0,late=0,gone=0,held=0,gapMax=0,gapSum=0,blendMaxStep=0}},Ghosts)
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
 local ghost={token=token,source=source,flight=Flight.new(c,vx,vy,radius),radius=radius,born=now,state="flying"}
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
 g.show=nil;self:finish(g,false)
 return true
end

function Ghosts:fade(g)
 if g.state=="fading"then return end
 g.state,g.fadeAt="fading",os.clock()
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
end

-- A reset, a mode change, a menu: every ghost goes at once (held server views show).
function Ghosts:clear()
 for index=#self.list,1,-1 do self.stats.cleared+=1;self:finish(self.list[index],false)end
end

local function lerp(a,b,t)return a+(b-a)*t end

function Ghosts:step(now)
 if #self.list==0 then self.lastStep=now;return end
 local dt=if self.lastStep then math.clamp(now-self.lastStep,0,.1)else 0
 self.lastStep=now
 if not self.host.canShow()then self:clear();return end
 local obstacles=self.obstacles
 self.host.obstacles(obstacles)
 -- Mark drawn balls that moved since the last frame (over 1 stud/s).
 local previous=self.previousObstacles or {};local seen={}
 for _,o in ipairs(obstacles)do
  local key=o[5];local last=key and previous[key]
  o[4]=last~=nil and dt>0 and math.sqrt((o[1]-last[1])^2+(o[2]-last[2])^2)/dt>1
  if key then seen[key]={o[1],o[2]}end
 end
 self.previousObstacles=seen
 for index=#self.list,1,-1 do
  local g=self.list[index]
  local flight=g.flight
  if g.state=="flying"then
   local kind=flight:step(dt,obstacles)
   if kind then
    g.state="resting";g.restAt=now
    -- Only a touch the server ball will also have made opens the next tap early; resting
    -- on a drawn ball that is still moving leaves it to the gate time (measured: an early
    -- open on a falling ball was refused after the server queue's 150 ms).
    if kind~="movingBall"then self.host.onContact(g.token,kind)end
   end
  end
  local x,y=flight.x,flight.y
  if g.state=="fading"then
   local t=(now-g.fadeAt)/Ghosts.FadeSeconds
   if t>=1 then self:finish(g,false);continue end
   g.source.Size=Vector3.one*g.radius*2*(1-t)
  elseif g.server and g.server.Parent then
   -- Hand over once the server ball, as drawn, has reached the ghost: at or below it,
   -- close to it, or the ghost was already blending.
   local sp=g.server.Position
   -- Hand over when the drawn server ball comes down to the ghost's touch-down (its own
   -- first contact on the snapshot clock), not when it settles: the server ball bounces
   -- on (Springy) and can end far from the first contact (measured: waiting for it to
   -- settle gave 4.4-stud blends; at first contact the gap is a few tenths).
   local close=(Vector2.new(sp.X,sp.Y)-Vector2.new(x,y)).Magnitude<=g.radius*.5
   if g.state~="blend"and(close or(g.state=="resting"and sp.Y<=y+.05)or now-g.serverAt>Ghosts.HandoffTimeout)then
    g.state,g.blendAt,g.fromX,g.fromY="blend",now,x,y
    -- How far the drawn ball is from the ghost when the blend starts (it closes over
    -- BlendSeconds, about 7 frames): the handoff's visible size.
    local gap=(Vector2.new(sp.X,sp.Y)-Vector2.new(x,y)).Magnitude
    self.stats.gapSum+=gap;if gap>self.stats.gapMax then self.stats.gapMax=gap end
   end
   if g.state=="blend"then
    local t=math.min(1,(now-g.blendAt)/Ghosts.BlendSeconds)
    x,y=lerp(g.fromX,sp.X,t),lerp(g.fromY,sp.Y,t)
    local last=g.source.Position
    local step=(Vector2.new(x,y)-Vector2.new(last.X,last.Y)).Magnitude
    if step>self.stats.blendMaxStep then self.stats.blendMaxStep=step end
    if t>=1 then g.source.Position=Vector3.new(x,y,0);self:finish(g,true);continue end
   end
  elseif g.eggId then
   if now-g.boundAt>Ghosts.ServerTimeout then self.stats.timeouts+=1;self:fade(g)end
  elseif now-g.born>Ghosts.UnboundTimeout then
   self.stats.timeouts+=1;self:fade(g)
  end
  local position=Vector3.new(x,y,0)
  if g.source.Position~=position then g.source.Position=position end
 end
end

return Ghosts
