-- Deck network S5 (deck-network-plan.md, architect review section 3): the ghost ball's
-- local flight. Pure Luau on plain numbers, so the spec runs offline.
-- It is the shared free flight (BoardConfig.advanceFlight: gravity, the speed cap, the
-- 0.85/s drag) at the server's fixed step and Pace, plus circle tests against the tray and
-- the balls as drawn. It bounces off the side walls like the server ball does, and stops
-- on its first contact (floor, a bank or a drawn ball), which is where the server's
-- contact gate opens too. No impulses are given to anything; presentation only.
local Flight={};Flight.__index=Flight
local Diagonal=1/math.sqrt(2)

-- constants: {Width,Height,Bank,Gravity,MaxSpeed,FixedStep,Pace,SpawnY,bounce}
function Flight.new(constants,vx,vy,radius)
 local c=constants
 return setmetatable({c=c,x=0,y=c.SpawnY,vx=vx,vy=vy,radius=radius,resting=false,contact=nil,
  simTime=0,accumulator=0,steps=0},Flight)
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

-- Push out of a plane (normal nx,ny; signed distance d from it to the centre). Returns
-- true on overlap. Like the server's keepInside: reflect with the bounce when fast.
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

-- Advance by real seconds `dt` against `obstacles` ({x, y, r, moving} for each drawn ball).
-- Returns the contact kind on the step that touched ("floor", "bank", "ball", or
-- "movingBall" for a drawn ball that is itself moving), else nil.
function Flight:step(dt,obstacles)
 if self.resting then return nil end
 local c=self.c
 self.accumulator+=math.min(dt,.1)*c.Pace
 while self.accumulator>=c.FixedStep do
  self.accumulator-=c.FixedStep
  self.simTime+=c.FixedStep;self.steps+=1
  self.x,self.y,self.vx,self.vy=Flight.advance(c,self.x,self.y,self.vx,self.vy,c.FixedStep)
  local half=c.Width/2
  -- Side walls bounce (not a contact on the server either); the ceiling holds it in.
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
     -- Rest touching the drawn ball, on the side the ghost came from.
     if distance<1e-6 then dx,dy,distance=0,1,1 end
     self.x,self.y=o[1]+dx/distance*reach,o[2]+dy/distance*reach
     -- A drawn ball still moving (in flight on the snapshot clock, which runs behind the
     -- server) stops the ghost but is no proof the server ball has touched anything.
     kind=if o[4]then "movingBall"else "ball"
     break
    end
   end
  end
  if kind then
   self.resting,self.contact=true,kind
   self.vx,self.vy=0,0
   self.accumulator=0
   return kind
  end
 end
 return nil
end

return Flight
