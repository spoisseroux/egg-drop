-- Onboarding v2 step 3: the first Bear's egg cracks on the shell, in 3D (Spencer, beta 36: "not a 2d texture ...
-- shrinkwrapped to the 3d egg mesh"; Fable AERO-JUICE-BRIEF 4). The look only: the shapes are EggCrackPaths' data
-- (where), the timing is the story's (when). Each segment is a thin dark sliver on the shell, laid along it and turned
-- to its normal, a hair outside it, following the egg as it rocks and flexes; a stage grows from its start over 90 ms
-- (Reduced Motion: it appears whole). Stage 2's main line carries a thin cream light leak at 25%. Shell crumbs (0.04 to
-- 0.08 studs) fall from the tap point and bounce once; at the pop 12 to 16 shell pieces arc out and land.
-- No screen-space lines, no billboards. Client-only parts, anchored, out of the physics.
--   local crack=EggCrack3D.new(folder, egg (StorkModel.Egg), segments)
--   crack:show(stage, now, instant) ; crack:step(now, dt) ; crack:crumbs(at, count, ground, now, onLand)
--   crack:burst(count, ground, now, onLand) ; crack:destroy()
local Paths=require(script.Parent.EggCrackPaths)
local Crack={};Crack.__index=Crack
Crack.Ink=Color3.fromHex("#3A2414")
Crack.Leak=Color3.fromHex("#FFFBE6")
Crack.Cream=Color3.fromHex("#FFF0D2")
Crack.Spot=Color3.fromHex("#3E5BE0")
Crack.Lift=.012      -- egg units outside the shell
Crack.Grow=.09       -- s: a stage grows over this (V2.Crack.grow)
Crack.Gravity=60     -- studs/s^2 for crumbs and pieces
Crack.Bounce=.35

local function part(parent,name,color,size,material)
	local p=Instance.new("Part")
	p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
	p.Material=material or Enum.Material.SmoothPlastic;p.Reflectance=0;p.Color=color;p.Size=size
	p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
	p.Parent=parent
	return p
end

function Crack.new(parent,egg,segments,options)
	options=options or {}
	local model=Instance.new("Model");model.Name="EggCrack3D";model.Parent=parent
	local self=setmetatable({model=model,egg=egg,lines={},bits={},shown={},grow=options.grow or Crack.Grow,leakAlpha=options.leakAlpha or .25},Crack)
	for i,seg in ipairs(segments or {})do
		local mid,along,normal,length=Paths.segment(seg)
		local line={seg=seg,mid=mid,along=along,normal=normal,length=length,start=nil,full=0}
		line.part=part(model,"Crack"..i,Crack.Ink,Vector3.new(.01,.01,.01))
		line.part.Transparency=1
		if seg.leak then
			line.leak=part(model,"Leak"..i,Crack.Leak,Vector3.new(.01,.01,.01),Enum.Material.Neon)
			line.leak.Transparency=1
		end
		self.lines[i]=line
	end
	return self
end
-- Start a stage at `now` (instant: whole at once, Reduced Motion).
function Crack:show(stage,now,instant)
	if self.shown[stage]then return end
	self.shown[stage]=true
	for _,line in ipairs(self.lines)do
		if line.seg.stage==stage then line.start=now+(if instant then 0 else line.seg.order*self.grow*.7);line.instant=instant end
	end
end
-- How far each line has grown (0..1) at now.
local function grown(self,line,now)
	if not line.start or now<line.start then return 0 end
	if line.instant then return 1 end
	return math.clamp((now-line.start)/(self.grow*.3+1e-3),0,1)
end
function Crack:place(line,u)
	local egg=self.egg
	local scale=egg.scale
	local w=line.seg.width*scale
	local len=line.length*scale*(egg.S and egg.S.X or 1)*u
	-- grows from its start (a), so the middle of what has grown
	local startAt=line.mid-line.along*(line.length/2)
	local at=startAt+line.along*(line.length*u/2)
	local world,normal=egg:surface(at,line.normal,Crack.Lift)
	local tangent=egg.frame and egg.frame:VectorToWorldSpace(line.along)or line.along
	local side=tangent:Cross(normal)
	if side.Magnitude<1e-5 then return end
	line.part.Size=Vector3.new(math.max(.01,len),w*.6,w)
	line.part.CFrame=CFrame.fromMatrix(world,tangent,normal,side)
	line.part.Transparency=0
	if line.leak then
		local above=world+normal*w*.5+side*w*.9
		line.leak.Size=Vector3.new(math.max(.01,len*.9),w*.35,w*.45)
		line.leak.CFrame=CFrame.fromMatrix(above,tangent,normal,side)
		line.leak.Transparency=1-self.leakAlpha
	end
end
-- Every frame after the egg's pose: the lines follow the shell; the bits fly, bounce and fade.
function Crack:step(now,dt,hidden)
	for _,line in ipairs(self.lines)do
		local u=grown(self,line,now)
		if u>0 and not hidden then self:place(line,u)
		else line.part.Transparency=1;if line.leak then line.leak.Transparency=1 end end
	end
	dt=math.clamp(dt or 0,0,.1)
	for i=#self.bits,1,-1 do
		local b=self.bits[i]
		b.age+=dt
		if b.age>=0 then
			b.v-=Vector3.new(0,Crack.Gravity*dt,0)
			b.p+=b.v*dt
			if b.p.Y<=b.ground then
				b.p=Vector3.new(b.p.X,b.ground,b.p.Z)
				if b.bounces<1 then
					b.bounces+=1;b.v=Vector3.new(b.v.X*.5,-b.v.Y*Crack.Bounce,b.v.Z*.5)
					if b.onLand then pcall(b.onLand,b)end
				else b.v=Vector3.zero;b.rest=b.rest or b.age end
			end
			b.spin+=b.turn*dt
			b.part.CFrame=CFrame.new(b.p)*CFrame.Angles(b.spin,b.spin*.7,0)
			b.part.Transparency=if b.rest then math.clamp((b.age-b.rest-.6)/.5,0,1)else 0
			if b.rest and b.age-b.rest>1.2 then b.part:Destroy();table.remove(self.bits,i)end
		end
	end
end
local function bit(self,size,color,at,v,ground,delay,onLand)
	local p=part(self.model,"Crumb",color,size)
	p.Transparency=1
	table.insert(self.bits,{part=p,p=at,v=v,ground=ground,age=-(delay or 0),bounces=0,spin=math.random()*6,turn=(math.random()-.5)*20,onLand=onLand})
end
-- Shell crumbs from `at` (world): `count` of them, 0.04 to 0.08 studs, flicked out and down; skitter: low and fast.
function Crack:crumbs(at,count,ground,skitter,onLand)
	for i=1,count do
		local a=math.random()*math.pi*2
		local size=.04+math.random()*.04
		local out=Vector3.new(math.cos(a),0,math.sin(a))
		local v=if skitter then out*(5+math.random()*3)+Vector3.new(0,2+math.random(),0)else out*(1.5+math.random()*2)+Vector3.new(0,3+math.random()*2,0)
		bit(self,Vector3.new(size,size*.5,size),Crack.Cream,at,v,ground,.03+(i-1)*.47/math.max(1,count),onLand)
	end
end
-- The pop: `count` shell pieces from round the seam, arcing out and landing.
function Crack:burst(count,ground,onLand)
	local egg=self.egg
	for i=1,count do
		local theta=math.pi*2*(i-.5)/count+math.random()*.3
		local v=Paths.Shape.seamV+(math.random()-.5)*.25
		local world,normal=egg:surface(Paths.point(theta,v),Paths.normal(theta,v),0)
		local speed=4+math.random()*3
		local size=.12+math.random()*.12
		local vel=Vector3.new(normal.X,0,normal.Z)*speed+Vector3.new(0,5+math.random()*4,0)
		bit(self,Vector3.new(size,.03,size*.8),if i%5==0 then Crack.Spot else Crack.Cream,world,vel,ground,math.random()*.03,onLand)
	end
end
-- Hide the shell's cracks (the pop splits it; the pieces carry on).
function Crack:hideLines()for _,line in ipairs(self.lines)do line.start=nil end end
function Crack:destroy()self.model:Destroy();table.clear(self.bits)end
return Crack
