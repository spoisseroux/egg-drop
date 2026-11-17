-- Deck network rework S1/S2 (artifacts/qa-2026-11-16c-v775/deck-network-plan.md, architect
-- review section 5): the client's snapshot buffer and render clock for its own board.
-- Pure Luau: every time is passed in (seconds, any monotonic clock), positions are plain
-- numbers, so the spec drives it with synthetic arrival schedules (and runs offline).
--
-- The server stamps each snapshot with an integer sim tick (TickRate per second while the
-- board steps). The clock maps ticks to local time with the smallest (arrival - tick/rate)
-- seen over the last Window seconds (the least-delayed packet), then renders Delay behind
-- it, Delay being the worst arrival jitter in the window plus one send interval (and a
-- small starvation margin), clamped to [DelayMin, DelayMax]. The render tick
-- eases toward that target at 0.95-1.05x, re-syncs hard past ResyncSeconds, never runs
-- backwards, extrapolates at most ExtrapolateSeconds past the newest sample and freezes on
-- a paused stream (same tick, Paused flag).
local Snapshots={};Snapshots.__index=Snapshots
Snapshots.TickRate=156 -- 120 fixed steps per sim second x Pace 1.3
Snapshots.Window=2
Snapshots.DelayMin,Snapshots.DelayMax=.05,.25
Snapshots.ExtrapolateSeconds=.05
Snapshots.ResyncSeconds=.25
Snapshots.RateMin,Snapshots.RateMax=.95,1.05
Snapshots.History=24 -- samples kept per ball
Snapshots.PausedFlag=1

function Snapshots.new(options)
 options=options or {}
 local self=setmetatable({},Snapshots)
 for _,key in ipairs({"TickRate","Window","DelayMin","DelayMax","ExtrapolateSeconds","ResyncSeconds","RateMin","RateMax","History"})do
  self[key]=if options[key]~=nil then options[key]else Snapshots[key]
 end
 self:reset(nil)
 self.stats={packets=0,stale=0,duplicates=0,resets=0,resyncs=0,starved=0,frames=0,maxStep=0,paused=0}
 return self
end

-- Forget every sample (a new ResetId, or a long silence).
function Snapshots:reset(resetId)
 self.resetId=resetId
 self.balls={} -- wire id -> {ticks={},xs={},ys={},n=0,removedAt=nil}
 self.order={} -- wire ids in arrival order of first sample
 self.newestTick=nil
 self.offsets={} -- {arrival, offset} within Window
 self.base=nil
 self.delay=self.DelayMin
 self.renderTick=nil
 self.pausedTick=nil
 self.lastArrival=nil
 self.lastNow=nil
 self.previousTick=nil
 self.spacing=nil
 self.interval=nil
 self.baseDelay=nil
 self.margin=0
end

local function percentile(values,p)
 local n=#values;if n==0 then return 0 end
 local sorted=table.clone(values);table.sort(sorted)
 return sorted[math.clamp(math.ceil(n*p),1,n)]
end

-- One decoded snapshot. Returns true when it was used.
function Snapshots:push(arrival,resetId,tick,flags,ids,xs,ys,count)
 self.stats.packets+=1
 if resetId~=self.resetId then
  -- A run already left never comes back (a late packet of it is stale). A new ResetId
  -- starts over when its tick is newer, or equal on a paused board (reset while the board
  -- did not step: the new run's first packet carries the same tick).
  local retired=self.retired or {};self.retired=retired
  local paused=bit32.band(flags,Snapshots.PausedFlag)~=0
  if retired[resetId]or(self.resetId~=nil and self.newestTick and(tick<self.newestTick or(tick==self.newestTick and not paused)))then
   self.stats.stale+=1;return false
  end
  if self.resetId~=nil then self.stats.resets+=1;retired[self.resetId]=true end
  self:reset(resetId)
 end
 if self.newestTick then
  if tick==self.newestTick then
   self.stats.duplicates+=1
   if bit32.band(flags,Snapshots.PausedFlag)~=0 then self.pausedTick=tick end
   self.lastArrival=arrival
   return false
  elseif tick<self.newestTick then self.stats.stale+=1;return false end
 end
 local paused=bit32.band(flags,Snapshots.PausedFlag)~=0
 -- Ticks stood still through a pause while time ran on, so every older offset is too
 -- small now: restart the clock window when the board steps again.
 if self.pausedTick and not paused then table.clear(self.offsets)end
 self.pausedTick=if paused then tick else nil
 self.newestTick=tick
 self.lastArrival=arrival
 -- Clock: least-delayed arrival over the window.
 local offset=arrival-tick/self.TickRate
 table.insert(self.offsets,{arrival,offset})
 while self.offsets[1]and arrival-self.offsets[1][1]>self.Window do table.remove(self.offsets,1)end
 local base=math.huge
 for _,entry in ipairs(self.offsets)do if entry[2]<base then base=entry[2]end end
 self.base=base
 local jitter={}
 for _,entry in ipairs(self.offsets)do table.insert(jitter,entry[2]-base)end
 -- The clock must stay one send interval behind the newest sample as well as above the
 -- jitter, or it renders past the data between packets (measured in Studio: at 0 lag a
 -- jitter-only delay starved 21% of frames). Interval = median tick spacing.
 if self.previousTick then
  local spacing=self.spacing or {}
  self.spacing=spacing
  table.insert(spacing,(tick-self.previousTick)/self.TickRate)
  if #spacing>30 then table.remove(spacing,1)end
  self.interval=math.min(percentile(spacing,.5),.25)
 end
 self.previousTick=tick
 -- The worst arrival lateness in the window (not p95): a late packet the clock has
 -- already passed is a visible stall, while a few more ms of delay are not.
 self.baseDelay=percentile(jitter,1)+(self.interval or 0)*1.25
 self.delay=math.clamp(self.baseDelay+(self.margin or 0),self.DelayMin,self.DelayMax)
 -- Samples. Every packet lists every live ball: an id missing from it left at this tick.
 local seen=self.seen or {};self.seen=seen;table.clear(seen)
 for i=1,count do
  local id=ids[i];seen[id]=true
  local ball=self.balls[id]
  if not ball or ball.removedAt then
   ball={ticks=table.create(self.History),xs=table.create(self.History),ys=table.create(self.History),n=0,firstTick=tick}
   self.balls[id]=ball;table.insert(self.order,id)
  end
  local n=ball.n
  if n>=self.History then
   table.remove(ball.ticks,1);table.remove(ball.xs,1);table.remove(ball.ys,1);n-=1
  end
  n+=1;ball.ticks[n],ball.xs[n],ball.ys[n]=tick,xs[i],ys[i];ball.n=n
 end
 for id,ball in pairs(self.balls)do
  if not seen[id]and not ball.removedAt then ball.removedAt=tick end
 end
 -- Drop balls whose removal the render clock has long passed.
 if self.renderTick then
  for index=#self.order,1,-1 do
   local id=self.order[index];local ball=self.balls[id]
   if ball and ball.removedAt and ball.removedAt<self.renderTick-self.TickRate then self.balls[id]=nil;table.remove(self.order,index)end
  end
 end
 return true
end

-- Advance the render clock to local time `now`. Returns the render tick (or nil before
-- the first packet).
function Snapshots:advance(now)
 if not self.newestTick then self.lastNow=now;return nil end
 local dt=if self.lastNow then math.max(0,now-self.lastNow)else 0
 self.lastNow=now
 self.stats.frames+=1
 -- Starvation feedback: frames that run past the newest sample add a little delay (the
 -- arrival pattern was burstier than the window's jitter showed); it decays again slowly.
 self.delay=math.clamp((self.baseDelay or self.DelayMin)+(self.margin or 0),self.DelayMin,self.DelayMax)
 local target=(now-self.base-self.delay)*self.TickRate
 local previous=self.renderTick
 local tick
 if not previous then tick=target
 else
  local error=(target-previous)/self.TickRate
  if math.abs(error)>self.ResyncSeconds then
   self.stats.resyncs+=1;tick=target
  else
   -- Close the gap over about a second, within the rate band.
   local rate=math.clamp(1+error,self.RateMin,self.RateMax)
   tick=previous+dt*self.TickRate*rate
  end
  if tick<previous then tick=previous end -- never backwards (a backwards re-sync holds)
 end
 -- Paused stream: stand still on the paused tick. Starved stream: extrapolate a little.
 if self.pausedTick and tick>=self.pausedTick then tick=self.pausedTick;self.stats.paused+=1
 else
  local limit=self.newestTick+self.ExtrapolateSeconds*self.TickRate
  if tick>self.newestTick+1 then
   self.stats.starved+=1
   -- Only while packets still flow: a silent stream (a stall, a lost link) is not jitter.
   if self.lastArrival and now-self.lastArrival<.1 then self.margin=math.min(.1,(self.margin or 0)+.004)end
  else self.margin=math.max(0,(self.margin or 0)-.0002*dt*60)end
  if tick>limit then tick=limit end
 end
 if previous and tick<previous then tick=previous end
 self.renderTick=tick
 return tick
end

-- Position of wire id `id` at the render tick: x, y, state. state is "live",
-- "early" (the clock has not reached its first sample yet: x,y is that sample),
-- "gone" (removed at or before the render tick) or nil (unknown id).
function Snapshots:sample(id,tick)
 local ball=self.balls[id];if not ball or ball.n==0 then return nil end
 tick=tick or self.renderTick;if not tick then return nil end
 local ticks,xs,ys,n=ball.ticks,ball.xs,ball.ys,ball.n
 if ball.removedAt and tick>=ball.removedAt then return xs[n],ys[n],"gone"end
 if tick<=ticks[1]then return xs[1],ys[1],if tick<ticks[1]then "early"else "live"end
 if tick>=ticks[n]then
  if n<2 then return xs[n],ys[n],"live"end
  -- Extrapolate along the last segment (advance caps how far). Also while paused: the
  -- clock may have run a little past the last tick before the pause was known, and it
  -- holds there, so the drawn ball holds too instead of stepping back.
  local span=ticks[n]-ticks[n-1]
  if span<=0 then return xs[n],ys[n],"live"end
  local t=(tick-ticks[n])/span
  return xs[n]+(xs[n]-xs[n-1])*t,ys[n]+(ys[n]-ys[n-1])*t,"live"
 end
 -- Binary search for the bracketing pair.
 local lo,hi=1,n
 while hi-lo>1 do
  local mid=(lo+hi)//2
  if ticks[mid]<=tick then lo=mid else hi=mid end
 end
 local t=(tick-ticks[lo])/(ticks[hi]-ticks[lo])
 return xs[lo]+(xs[hi]-xs[lo])*t,ys[lo]+(ys[hi]-ys[lo])*t,"live"
end

-- Seconds since the last packet (math.huge before any).
function Snapshots:silence(now)return if self.lastArrival then now-self.lastArrival else math.huge end

-- Buffer depth in seconds: how far the newest sample is ahead of the render tick.
function Snapshots:depth()
 if not self.newestTick or not self.renderTick then return 0 end
 return (self.newestTick-self.renderTick)/self.TickRate
end

return Snapshots
