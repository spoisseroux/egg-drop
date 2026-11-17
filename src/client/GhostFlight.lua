-- Deck network S5 (deck-network-plan.md, architect review section 3): the ghost ball's
-- local motion. Pure Luau on plain numbers, so the spec runs offline.
-- The shared free flight (BoardConfig.advanceFlight: gravity, the speed cap, the 0.85/s
-- drag) at the server's fixed step and Pace, with the server's tray rules (keepInside:
-- walls, floor and banks, the bounce above 1.8 studs/s) and, against the balls as drawn,
-- the server's pair impulse with the drawn ball held still. v880 QA: the ghost used to
-- stop dead on its first touch and wait, so the real ball arrived late and bounced again
-- ("jumping after hitting the bottom"). It now bounces, rolls and settles like the server
-- ball, and only a same-tier touch (the server merges there) stops it.
-- First contact (floor, bank, a resting drawn ball) is reported once: the server's
-- contact gate opens on the same event. No impulses are given to anything drawn.
local Flight={};Flight.__index=Flight
local Diagonal=1/math.sqrt(2)
Flight.RestSpeed=.35   -- studs/s: below this while touching, the ghost is settling
Flight.RestSeconds=.2  -- settled this long: resting
Flight.MaxSeconds=3    -- real seconds of motion at most (a bound, not a rule)
Flight.MaxStepsPerFrame=8 -- 156 steps/s: enough for 20 fps (7.8), never a hitch's 15+
Flight.PushStep=.04    -- studs per fixed step: the most a drawn ball pushes the ghost out

-- constants: {Width,Height,Bank,Gravity,MaxSpeed,FixedStep,Pace,SpawnY,bounce}
function Flight.new(constants,vx,vy,radius,tier)
 local c=constants
 return setmetatable({c=c,x=0,y=c.SpawnY,vx=vx,vy=vy,radius=radius,tier=tier,resting=false,contact=nil,
  merging=false,simTime=0,realTime=0,accumulator=0,steps=0,still=0},Flight)
end

-- The launch velocity for an aim in [0, 1] (BoardConfig.launchVelocity on numbers).
function Flight.launchVelocity(constants,aim)
 local angle=(aim*2-1)*math.rad(constants.LaunchAngleDegrees)
 return math.sin(angle)*constants.LaunchSpeed,-math.cos(angle)*constants.LaunchSpeed
end

-- One fixed step of the shared free flight (BoardConfig.advanceFlight on numbers).
function Flight.advance(c,x,y,vx,vy,dt)
 vy-=c.Gravity*dt
 local speed=math.sqrt(vx*vx+vy*vy)
 if speed>c.MaxSpeed then vx,vy=vx/speed*c.MaxSpeed,vy/speed*c.MaxSpeed end
 local drag=1-dt*.85
 vx,vy=vx*drag,vy*drag
 return x+vx*dt,y+vy*dt,vx,vy
end

-- The server's keepInside: push out of a plane (normal nx,ny; signed centre distance d),
-- reflecting with the bounce when fast. Returns true on overlap.
local function plane(self,nx,ny,d)
 local overlap=self.radius-d
 if overlap<=0 then return false end
 self.x+=nx*overlap;self.y+=ny*overlap
 local speed=self.vx*nx+self.vy*ny
 if speed<0 then
  local k=speed*(1+(if speed<-1.8 then self.c.bounce else 0))
  self.vx-=nx*k;self.vy-=ny*k
 end
 return true
end

-- Advance by real seconds `dt` against `obstacles` ({x, y, r, moving, source, tier} per
-- drawn ball). Returns the first-contact kind on the step it happens ("floor", "bank",
-- "ball", "movingBall", "merge"), else nil.
function Flight:step(dt,obstacles)
 if self.resting then return nil end
 local c=self.c
 dt=math.min(dt,.1)
 self.realTime+=dt
 self.accumulator+=dt*c.Pace
 -- After a frame hitch, at most MaxStepsPerFrame fixed steps (the rest is dropped: the
 -- ghost slows a touch rather than spending a hitch's worth of work in one frame).
 self.accumulator=math.min(self.accumulator,c.FixedStep*Flight.MaxStepsPerFrame)
 local first
 while self.accumulator>=c.FixedStep do
  self.accumulator-=c.FixedStep
  self.simTime+=c.FixedStep;self.steps+=1
  self.x,self.y,self.vx,self.vy=Flight.advance(c,self.x,self.y,self.vx,self.vy,c.FixedStep)
  local half=c.Width/2
  -- Side walls and the ceiling are not contacts on the server either.
  plane(self,1,0,self.x+half);plane(self,-1,0,half-self.x);plane(self,0,-1,c.Height-self.y)
  local kind
  if plane(self,0,1,self.y)then kind="floor"end
  if plane(self,Diagonal,Diagonal,(self.x+half+self.y-c.Bank)*Diagonal)then kind="bank"end
  if plane(self,-Diagonal,Diagonal,(half-self.x+self.y-c.Bank)*Diagonal)then kind="bank"end
  if obstacles then
   for _,o in ipairs(obstacles)do
    local dx,dy=self.x-o[1],self.y-o[2]
    local distance=math.sqrt(dx*dx+dy*dy)
    local reach=self.radius+o[3]
    if distance<reach then
     if distance<1e-6 then dx,dy,distance=0,1,1 end
     local nx,ny=dx/distance,dy/distance
     -- Out of the overlap, but at most PushStep a step: a drawn ball that appears or
     -- moves into the ghost (a merge result, the snapshot clock) eases it aside instead
     -- of teleporting it (measured: 1.7-stud frame steps).
     local overlap=reach-distance
     local travel=math.sqrt(self.vx*self.vx+self.vy*self.vy)*c.FixedStep+.01
     local push=if overlap<=travel then overlap else math.max(travel,math.min(overlap,Flight.PushStep))
     self.x,self.y=self.x+nx*push,self.y+ny*push
     if self.tier and o[6]==self.tier then
      -- Same tier: the server merges here. Stop and let the merge (on the snapshot
      -- clock) take the ghost.
      self.merging,self.resting=true,true;self.vx,self.vy=0,0
      kind="merge"
     else
      -- The server's pair impulse (equal masses), the drawn ball held still.
      local speed=self.vx*nx+self.vy*ny
      if speed<0 then
       local k=speed*(1+(if speed<-1.8 then c.bounce else 0))/2
       self.vx-=nx*k;self.vy-=ny*k
      end
      -- A drawn ball still moving (behind the server on the snapshot clock) is no proof
      -- the server ball touched anything there.
      kind=if o[4]then "movingBall"else "ball"
     end
    end
   end
  end
  if kind and not self.contact then self.contact=kind;first=kind end
  -- Studio measurement only: the v880 behaviour (stop dead on the first touch).
  if kind and self.legacy then self.resting=true;self.vx,self.vy=0,0;self.accumulator=0;break end
  if self.merging then self.accumulator=0;break end
  -- Settling: slow while touching something.
  local speed=math.sqrt(self.vx*self.vx+self.vy*self.vy)
  if kind and speed<Flight.RestSpeed then self.still+=c.FixedStep/c.Pace else self.still=0 end
  if self.still>=Flight.RestSeconds or self.realTime>=Flight.MaxSeconds then
   self.resting=true;self.vx,self.vy=0,0;self.accumulator=0
   break
  end
 end
 return first
end

return Flight
