-- Small warm sparks drawn in 2D over a ViewportFrame (v842 phone notes: the Sparkler's sparks).
-- A ViewportFrame does not render ParticleEmitters, so the hatch reveal (HatchDisplayScene,
-- a viewport) draws the Sparkler's sparks here instead: a fixed pool of tiny round frames,
-- each alive 0.12-0.3 s, thrown from the tip, slowed and pulled down, warm white to orange.
-- No instances are made after `new`; nothing moves while `step` is not called.
local Sparks={}
Sparks.__index=Sparks
Sparks.Max=14
Sparks.Rate=34 -- per second, as the 3D emitter (PetToyGeometry.SparkRate)
Sparks.Life={.12,.3}
local warm={Color3.fromHex("#FFF4C8"),Color3.fromHex("#FFB547"),Color3.fromHex("#FF7A2A")}
local function mix(t)
 if t<.5 then return warm[1]:Lerp(warm[2],t*2)end
 return warm[2]:Lerp(warm[3],(t-.5)*2)
end

function Sparks.new(parent,z)
 local self=setmetatable({parent=parent,pool={},carry=0,seed=7},Sparks)
 for index=1,Sparks.Max do
  local f=Instance.new("Frame");f.Name="Spark"..index;f.BorderSizePixel=0;f.AnchorPoint=Vector2.new(.5,.5)
  f.BackgroundColor3=warm[1];f.Visible=false;f.ZIndex=z or parent.ZIndex+1;f.Active=false
  local c=Instance.new("UICorner");c.CornerRadius=UDim.new(.5,0);c.Parent=f
  f.Parent=parent
  self.pool[index]={frame=f,age=0,life=0,pos=Vector2.zero,vel=Vector2.zero,alive=false}
 end
 return self
end
function Sparks:random()
 -- A small deterministic LCG: the same sparks every run (captures, specs).
 self.seed=(self.seed*1103515245+12345)%2147483648
 return self.seed/2147483648
end
-- origin: the tip in the parent's pixels. unit: pixels per spark-size unit (about the tip's
-- size on screen). on=false lets the live sparks die out and spawns none.
function Sparks:step(dt,origin,unit,on)
 dt=math.clamp(dt or 0,0,.1);unit=math.max(1,unit or 8)
 local alive=0
 for _,s in ipairs(self.pool)do
  if s.alive then
   s.age+=dt
   if s.age>=s.life then s.alive=false;s.frame.Visible=false
   else
    alive+=1
    s.vel=s.vel*(1-math.min(1,dt*2.5))+Vector2.new(0,unit*20)*dt
    s.pos+=s.vel*dt
    local t=s.age/s.life
    local size=math.max(1.5,unit*.6*(1-t*.5))
    s.frame.Position=UDim2.fromOffset(s.pos.X,s.pos.Y);s.frame.Size=UDim2.fromOffset(size,size)
    s.frame.BackgroundColor3=mix(t);s.frame.BackgroundTransparency=t*.7
   end
  end
 end
 if not on or not origin then self.carry=0;return alive end
 self.carry+=dt*Sparks.Rate
 while self.carry>=1 do
  self.carry-=1
  for _,s in ipairs(self.pool)do
   if not s.alive then
    local a=self:random()*math.pi*2;local speed=unit*(12+self:random()*10)
    s.alive=true;s.age=0;s.life=Sparks.Life[1]+self:random()*(Sparks.Life[2]-Sparks.Life[1])
    s.pos=origin;s.vel=Vector2.new(math.cos(a),math.sin(a))*speed
    s.frame.Position=UDim2.fromOffset(origin.X,origin.Y);s.frame.Visible=true
    alive+=1
    break
   end
  end
 end
 return alive
end
function Sparks:hide()for _,s in ipairs(self.pool)do s.alive=false;s.frame.Visible=false end;self.carry=0 end
function Sparks:destroy()for _,s in ipairs(self.pool)do s.frame:Destroy()end;table.clear(self.pool)end
return Sparks
