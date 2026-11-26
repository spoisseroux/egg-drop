-- Onboarding v2 step 3: the first Bear's egg cracks on the shell, in 3D (Spencer, beta 36: "not a 2d texture ...
-- shrinkwrapped to the 3d egg mesh"; Fable AERO-JUICE-BRIEF 4 and her review of the beta 37 captures, FABLE-REVIEW-B37
-- sections 4 to 6). The look only: the shapes are EggCrackPaths' data (where), the timing is the story's (when).
--   * each segment a thin brown sliver (#4A3524, never black) on the shell, turned to its normal, 0.004 studs out,
--     following the egg as it rocks and flexes; its width is the path's (0.035 at the tap to 0.008 at the tips);
--   * a lighter twin strip 0.012 studs below it (#FFFDF0, transparency 0.45, 0.6x the core's width): the depth;
--   * tap 2's runs carry the cream leak (#FFF3C4 at 25%);
--   * at each fork a dark chip (a 0.05 stud triangle, #3A2A1C) and one cream shard lifted 0.01 and tilted 8 degrees;
--   * a stage grows outward from the tap over 90 ms (Reduced Motion: whole at once);
--   * crumbs fall from the tap point and bounce once; at the pop 12 to 16 wedge shards (0.12 to 0.35 studs, 0.03
--     thick, outer #FBF8DC, inner #FFFFFF, a #2F6BFF spot on at most 1 in 4) arc out away from the camera, land and
--     shrink away over 300 ms from 1.2 s after landing.
-- No screen-space lines, no billboards. Client-only parts, anchored, out of the physics.
--   local crack=EggCrack3D.new(folder, egg (StorkModel.Egg), segments, {grow, leakAlpha, chips})
--   crack:show(stage, now, instant) ; crack:step(now, dt, hideLines) ; crack:crumbs(at, count, groundY, skitter, onLand)
--   crack:burst(count, groundY, away, onLand) ; crack:destroy()
local Paths=require(script.Parent.EggCrackPaths)
local Crack={};Crack.__index=Crack
Crack.Core=Color3.fromHex("#4A3524")
Crack.Edge=Color3.fromHex("#FFFDF0");Crack.EdgeAlpha=.45;Crack.EdgeOffset=.012;Crack.EdgeWidth=.6
Crack.Leak=Color3.fromHex("#FFF3C4")
Crack.Chip=Color3.fromHex("#3A2A1C");Crack.ChipSize=.05
Crack.Outer=Color3.fromHex("#FBF8DC");Crack.Inner=Color3.fromHex("#FFFFFF");Crack.Spot=Color3.fromHex("#2F6BFF")
Crack.Lift=.004      -- studs outside the shell
Crack.Depth=.006     -- the sliver's thickness along the normal (studs)
Crack.Grow=.09       -- s: a stage grows outward over this (V2.Crack.grow)
Crack.Gravity=60     -- studs/s^2 for crumbs and shards
Crack.Bounce=.35
Crack.Shard=table.freeze({min=.12,max=.35,thick=.03,shrinkAfter=1.2,shrink=.3,spotEvery=4})

local function part(parent,name,color,size,material,class)
	local p=Instance.new(class or "Part")
	p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
	p.Material=material or Enum.Material.SmoothPlastic;p.Reflectance=0;p.Color=color;p.Size=size
	p.Parent=parent
	return p
end

function Crack.new(parent,egg,segments,options)
	options=options or {}
	local model=Instance.new("Model");model.Name="EggCrack3D";model.Parent=parent
	local self=setmetatable({model=model,egg=egg,lines={},chips={},bits={},shown={},grow=options.grow or Crack.Grow,leakAlpha=options.leakAlpha or .25},Crack)
	for i,seg in ipairs(segments or {})do
		local mid,along,normal,length=Paths.segment(seg)
		local line={seg=seg,mid=mid,along=along,normal=normal,length=length,start=nil}
		line.part=part(model,"Crack"..i,Crack.Core,Vector3.new(.01,.01,.01))
		line.edge=part(model,"Edge"..i,Crack.Edge,Vector3.new(.01,.01,.01))
		line.part.Transparency,line.edge.Transparency=1,1
		if seg.leak then line.leak=part(model,"Leak"..i,Crack.Leak,Vector3.new(.01,.01,.01),Enum.Material.Neon);line.leak.Transparency=1 end
		self.lines[i]=line
	end
	for i,chip in ipairs(options.chips or {})do
		local theta,v=chip.at[1],chip.at[2]
		local entry={chip=chip,point=Paths.point(theta,v),normal=Paths.normal(theta,v),start=nil}
		entry.dark=part(model,"Chip"..i,Crack.Chip,Vector3.new(.004,Crack.ChipSize,Crack.ChipSize),nil,"WedgePart")
		entry.shard=part(model,"ChipShard"..i,Crack.Outer,Vector3.new(.035,.006,.025))
		entry.dark.Transparency,entry.shard.Transparency=1,1
		self.chips[i]=entry
	end
	return self
end
-- Start a stage at `now` (instant: whole at once, Reduced Motion). The segments start in order of their distance
-- from the tap, so the crack runs outward over Grow seconds.
function Crack:show(stage,now,instant)
	if self.shown[stage]then return end
	self.shown[stage]=true
	local from,to=math.huge,-math.huge
	for _,line in ipairs(self.lines)do if line.seg.stage==stage then from=math.min(from,line.seg.order);to=math.max(to,line.seg.order)end end
	local span=math.max(1e-6,to-from)
	for _,line in ipairs(self.lines)do
		if line.seg.stage==stage then
			line.start=now+(if instant then 0 else(line.seg.order-from)/span*self.grow*.8);line.instant=instant
		end
	end
	for _,entry in ipairs(self.chips)do
		if entry.chip.stage==stage then entry.start=now+(if instant then 0 else self.grow*.6)end
	end
end
local function grown(self,line,now)
	if not line.start or now<line.start then return 0 end
	if line.instant then return 1 end
	return math.clamp((now-line.start)/(self.grow*.2+1e-3),0,1)
end
function Crack:place(line,u)
	local egg=self.egg
	local w=line.seg.width
	local len=line.length*egg.scale*(egg.S and egg.S.X or 1)*u
	-- grows from its start (a, the end nearer the tap), so the middle of what has grown
	local startAt=line.mid-line.along*(line.length/2)
	local at=startAt+line.along*(line.length*u/2)
	local world,normal=egg:surface(at,line.normal,Crack.Lift)
	local tangent=egg.frame and egg.frame:VectorToWorldSpace(line.along)or line.along
	local side=tangent:Cross(normal)
	if side.Magnitude<1e-5 then return end
	side=side.Unit
	-- the twin edge sits below the core
	if side.Y>0 then side=-side end
	line.part.Size=Vector3.new(math.max(.01,len),Crack.Depth,w)
	line.part.CFrame=CFrame.fromMatrix(world,tangent,normal)
	line.part.Transparency=0
	line.edge.Size=Vector3.new(math.max(.01,len),Crack.Depth*.6,w*Crack.EdgeWidth)
	line.edge.CFrame=CFrame.fromMatrix(world+side*Crack.EdgeOffset-normal*.001,tangent,normal)
	line.edge.Transparency=Crack.EdgeAlpha
	if line.leak then
		line.leak.Size=Vector3.new(math.max(.01,len*.9),Crack.Depth*.5,w*.45)
		line.leak.CFrame=CFrame.fromMatrix(world+normal*Crack.Depth*.6,tangent,normal)
		line.leak.Transparency=1-self.leakAlpha
	end
end
function Crack:placeChip(entry)
	local egg=self.egg
	local world,normal=egg:surface(entry.point,entry.normal,Crack.Lift)
	local heading=entry.chip.heading or 0
	-- a tangent from the chip's heading on the shell (round the egg = +theta)
	local theta,v=entry.chip.at[1],entry.chip.at[2]
	local round=Paths.point(theta+.01,v)-Paths.point(theta,v)
	local up=Paths.point(theta,math.min(.97,v+.01))-Paths.point(theta,v)
	local t=(round.Unit*math.cos(heading)+up.Unit*math.sin(heading))
	local tangent=egg.frame and egg.frame:VectorToWorldSpace(t)or t
	tangent=(tangent-normal*tangent:Dot(normal)).Unit
	-- the dark triangle lies in the shell (a wedge's thin X along the normal)
	entry.dark.CFrame=CFrame.fromMatrix(world,normal,tangent)
	entry.dark.Transparency=0
	-- one cream shard lifted 0.01 and tilted 8 degrees off the shell
	local lifted=CFrame.fromMatrix(world+normal*.01,tangent,normal)*CFrame.Angles(math.rad(8),0,0)
	entry.shard.CFrame=lifted
	entry.shard.Transparency=0
end
-- Every frame after the egg's pose: the lines follow the shell; the bits fly, bounce, rest and go.
function Crack:step(now,dt,hidden)
	for _,line in ipairs(self.lines)do
		local u=grown(self,line,now)
		if u>0 and not hidden then self:place(line,u)
		else
			line.part.Transparency,line.edge.Transparency=1,1
			if line.leak then line.leak.Transparency=1 end
		end
	end
	for _,entry in ipairs(self.chips)do
		if entry.start and now>=entry.start and not hidden then self:placeChip(entry)
		else entry.dark.Transparency,entry.shard.Transparency=1,1 end
	end
	dt=math.clamp(dt or 0,0,.1)
	for i=#self.bits,1,-1 do
		local b=self.bits[i]
		b.age+=dt
		if b.age>=0 then
			if not b.rest then
				b.v-=Vector3.new(0,Crack.Gravity*dt,0)
				b.p+=b.v*dt
				if b.p.Y<=b.ground then
					b.p=Vector3.new(b.p.X,b.ground,b.p.Z)
					if b.bounces<1 then
						b.bounces+=1;b.v=Vector3.new(b.v.X*.5,-b.v.Y*Crack.Bounce,b.v.Z*.5)
						if b.onLand then pcall(b.onLand,b)end
					else b.v=Vector3.zero;b.rest=b.age;b.spinRate=0 end
				end
				b.spin+=b.spinRate*dt
			end
			local cf=CFrame.new(b.p)*CFrame.Angles(0,b.yaw,0)*CFrame.Angles(b.spin,0,b.spin*.6)
			-- shards shrink away over 0.3 s from 1.2 s after landing; crumbs fade
			local scale=1
			if b.rest and b.shard then scale=1-math.clamp((b.age-b.rest-Crack.Shard.shrinkAfter)/Crack.Shard.shrink,0,1)end
			for _,p in ipairs(b.parts)do
				p.Size=p:GetAttribute("Base")*math.max(.01,scale)
				p.CFrame=cf*(p:GetAttribute("Offset")or CFrame.new())
				p.Transparency=if b.shard then(if scale<=.02 then 1 else 0)else(if b.rest then math.clamp((b.age-b.rest-.6)/.5,0,1)else 0)
			end
			local gone=if b.shard then scale<=.02 else(b.rest~=nil and b.age-b.rest>1.2)
			if gone then for _,p in ipairs(b.parts)do p:Destroy()end;table.remove(self.bits,i)end
		end
	end
end
local function addBit(self,parts,at,v,ground,delay,onLand,shard)
	for _,p in ipairs(parts)do p.Transparency=1;p:SetAttribute("Base",p.Size)end
	table.insert(self.bits,{parts=parts,p=at,v=v,ground=ground,age=-(delay or 0),bounces=0,spin=math.random()*6,
		spinRate=(math.random()-.5)*20,yaw=math.random()*math.pi*2,onLand=onLand,shard=shard})
end
-- Shell crumbs from `at` (world): `count` of them, 0.04 to 0.08 studs, flicked out and down; skitter: low and fast.
function Crack:crumbs(at,count,ground,skitter,onLand)
	for i=1,count do
		local a=math.random()*math.pi*2
		local size=.04+math.random()*.04
		local out=Vector3.new(math.cos(a),0,math.sin(a))
		local v=if skitter then out*(5+math.random()*3)+Vector3.new(0,2+math.random(),0)else out*(1.5+math.random()*2)+Vector3.new(0,3+math.random()*2,0)
		local p=part(self.model,"Crumb",Crack.Outer,Vector3.new(size,size*.5,size))
		addBit(self,{p},at,v,ground,.03+(i-1)*.47/math.max(1,count),onLand,false)
	end
end
-- A wedge shard: a thin cream outer wedge over a white inner one (and, on some, a blue spot).
function Crack:shard(spot)
	local S=Crack.Shard
	local length=S.min+math.random()*(S.max-S.min)
	local wide=length*(.55+math.random()*.35)
	local half=S.thick/2
	local outer=part(self.model,"Shard",Crack.Outer,Vector3.new(wide,half,length),nil,"WedgePart")
	outer:SetAttribute("Offset",CFrame.new(0,half/2,0))
	local inner=part(self.model,"ShardInner",Crack.Inner,Vector3.new(wide,half,length),nil,"WedgePart")
	inner:SetAttribute("Offset",CFrame.new(0,-half/2,0))
	local parts={outer,inner}
	if spot then
		local dot=part(self.model,"ShardSpot",Crack.Spot,Vector3.new(.004,wide*.35,wide*.35),nil,"Part")
		dot.Shape=Enum.PartType.Cylinder
		dot:SetAttribute("Offset",CFrame.new(0,half+.002,length*.15)*CFrame.Angles(0,0,math.rad(90)))
		table.insert(parts,dot)
	end
	return parts
end
-- The pop: `count` wedge shards from round the seam, arcing out (never toward `toward`, the camera's side) and landing.
function Crack:burst(count,ground,toward,onLand)
	local egg=self.egg
	local S=Crack.Shard
	local spots=0
	for i=1,count do
		local theta,v,world,normal
		for _=1,8 do
			-- the egg faces the camera with theta pi: the shards leave from the far half and the sides
			theta=((i-.5)/count-.5)*3.3+(math.random()-.5)*.2
			v=Paths.Shape.seamV+(math.random()-.5)*.25
			world,normal=egg:surface(Paths.point(theta,v),Paths.normal(theta,v),0)
			-- none between the camera and the Bear: only out to the sides and away
			if not toward or Vector3.new(normal.X,0,normal.Z).Unit:Dot(toward)<.2 then break end
			theta=nil
		end
		if theta then
			local speed=3+math.random()*3
			local vel=Vector3.new(normal.X,0,normal.Z).Unit*speed+Vector3.new(0,4+math.random()*4,0)
			local spot=spots<math.floor(count/S.spotEvery)and math.random()<1/S.spotEvery
			if spot then spots+=1 end
			addBit(self,self:shard(spot),world,vel,ground+S.thick/2,math.random()*.03,onLand,true)
		end
	end
end
-- The pop splits the shell: its cracks and chips go (the shards carry on).
function Crack:hideLines()
	for _,line in ipairs(self.lines)do line.start=nil end
	for _,entry in ipairs(self.chips)do entry.start=nil end
end
function Crack:destroy()self.model:Destroy();table.clear(self.bits)end
return Crack
