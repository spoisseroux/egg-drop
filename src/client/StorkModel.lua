-- Onboarding v2 step 2 (ONBOARDING-V2.md; Spencer: "the animation of the bear being dropped by a stork, in front of
-- us"): our own stork, its knotted blanket bundle and the Companion Egg in the world. Built from parts in code (no
-- assets), client-only, every part anchored and out of the physics (no collide, query or touch). Matte: SmoothPlastic
-- with no shine, the blanket Fabric.
--   stork: white ball body and head, dark wing tips, a long orange wedge beak in two halves (it clacks), thin orange
--   legs, two black eyes with a white glint, a small blue delivery cap with a gold band. About 4 studs tall, 7 across
--   the wings. The bundle: a pale blue blanket with white dots, knotted, hanging from the beak, the egg's top showing;
--   on the ground it opens flat (1.2 stud radius) under the egg.
-- Poses are pure CFrame maths on a root (the stork's feet point, facing its LookVector); the story drives them.
local V2=require(script.Parent.OnboardV2)
local S=V2.Stork
local Stork={};Stork.__index=Stork

local function part(parent,name,props,mesh)
	local p=Instance.new("Part")
	p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=true
	p.Material=Enum.Material.SmoothPlastic;p.Reflectance=0;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
	for k,v in pairs(props or {})do p[k]=v end
	if mesh then
		local m=Instance.new("SpecialMesh");m.MeshType=Enum.MeshType.Sphere;m.Scale=mesh;m.Parent=p
		p.Size=Vector3.new(1,1,1)
	end
	p.Parent=parent
	return p
end
local function wedge(parent,name,size,color)
	local w=Instance.new("WedgePart")
	w.Name=name;w.Anchored=true;w.CanCollide=false;w.CanQuery=false;w.CanTouch=false;w.CastShadow=true
	w.Material=Enum.Material.SmoothPlastic;w.Reflectance=0;w.Size=size;w.Color=color;w.Parent=parent
	return w
end
local function cylinder(parent,name,length,diameter,color)
	-- A cylinder's axis is its X: the pose turns it to stand up.
	return part(parent,name,{Shape=Enum.PartType.Cylinder,Size=Vector3.new(length,diameter,diameter),Color=color})
end

-- ── The stork ────────────────────────────────────────────────────────────────────────────────────────────────────────
-- Fixed pieces: {part, offset from the root}. The wings, the lower beak, the legs and the head (the nod) are posed apart.
function Stork.new(parent)
	local model=Instance.new("Model");model.Name="OnboardStork"
	local self=setmetatable({model=model,fixed={},alpha=0},Stork)
	local white,dark,orange=S.body,S.tips,S.beak
	local function fixed(p,offset)table.insert(self.fixed,{part=p,offset=offset});return p end
	fixed(part(model,"Body",{Color=white},Vector3.new(1.6,1.5,2.5)),CFrame.new(0,2.2,0))
	fixed(part(model,"Tail",{Color=dark},Vector3.new(1.0,.35,.9)),CFrame.new(0,2.35,1.3)*CFrame.Angles(math.rad(-12),0,0))
	fixed(part(model,"Neck1",{Color=white},Vector3.new(.62,.62,.62)),CFrame.new(0,2.85,-.95))
	fixed(part(model,"Neck2",{Color=white},Vector3.new(.55,.55,.55)),CFrame.new(0,3.2,-1.1))
	-- The head group turns about the neck top for the nod.
	self.head={}
	local function head(p,offset)table.insert(self.head,{part=p,offset=offset});return p end
	head(part(model,"Head",{Color=white},Vector3.new(.95,.9,1.0)),CFrame.new(0,.25,-.1))
	for side=-1,1,2 do
		head(part(model,"Eye",{Color=Color3.fromRGB(20,20,24)},Vector3.new(.17,.19,.12)),CFrame.new(side*.36,.36,-.42))
		head(part(model,"Glint",{Color=Color3.new(1,1,1)},Vector3.new(.06,.06,.04)),CFrame.new(side*.34,.41,-.48))
	end
	head(cylinder(model,"Cap",.28,.78,S.cap),CFrame.new(0,.74,-.05)*CFrame.Angles(0,0,math.rad(90)))
	head(cylinder(model,"CapBand",.09,.81,S.band),CFrame.new(0,.63,-.05)*CFrame.Angles(0,0,math.rad(90)))
	head(part(model,"CapBrim",{Color=S.cap,Size=Vector3.new(.5,.06,.32)}),CFrame.new(0,.6,-.48))
	-- The beak: an upper half and a lower half that opens for the clack. A wedge's thin end is its front (-Z).
	head(wedge(model,"BeakUpper",Vector3.new(.3,.18,1.45),orange),CFrame.new(0,.2,-1.12))
	self.lowerBeak=wedge(model,"BeakLower",Vector3.new(.26,.13,1.3),orange)
	-- The wings: hinged at the shoulders; each an inner white feather plane and a dark tip.
	self.wings={}
	for side=-1,1,2 do
		local inner=part(model,"Wing",{Color=white},Vector3.new(2.0,.18,1.3))
		local tip=part(model,"WingTip",{Color=dark},Vector3.new(1.4,.14,1.0))
		table.insert(self.wings,{side=side,inner=inner,tip=tip})
	end
	-- The legs and feet.
	self.legs={}
	for side=-1,1,2 do
		local leg=cylinder(model,"Leg",1.6,.12,orange)
		local foot=wedge(model,"Foot",Vector3.new(.3,.08,.42),orange)
		table.insert(self.legs,{side=side,leg=leg,foot=foot})
	end
	model.Parent=parent
	self:setAlpha(0)
	return self
end
-- Where the beak tip is from the root (the bundle's knot hangs here), for a level head.
Stork.BeakTip=V2.Route.beak -- (OnboardV2: the route and the landing plan the hover from it)
-- o: {flap (deg), nod (deg), clack (0 shut .. 1 open), legs (0 trailing .. 1 standing), fold (0 spread .. 1 folded)}
function Stork:pose(root,o)
	o=o or {}
	for _,entry in ipairs(self.fixed)do entry.part.CFrame=root*entry.offset end
	local neck=root*CFrame.new(0,3.3,-1.2)*CFrame.Angles(math.rad(-(o.nod or 0)),0,0)
	for _,entry in ipairs(self.head)do entry.part.CFrame=neck*entry.offset end
	self.lowerBeak.CFrame=neck*CFrame.new(0,.08,-.25)*CFrame.Angles(math.rad(-14*(o.clack or 0)),0,0)*CFrame.new(0,0,-.75)*CFrame.Angles(0,0,math.pi)
	local flap=math.rad(o.flap or 0)
	local fold=math.clamp(o.fold or 0,0,1)
	for _,w in ipairs(self.wings)do
		local shoulder=root*CFrame.new(w.side*.7,2.6,-.15)
		-- spread: out to the side, flapping about the body's long axis; folded: tucked along the body
		local spread=CFrame.Angles(0,0,w.side*flap)*CFrame.Angles(0,w.side*math.rad(-70*fold),0)
		w.inner.CFrame=shoulder*spread*CFrame.new(w.side*(1.0-.3*fold),0,0)
		w.tip.CFrame=shoulder*spread*CFrame.new(w.side*(2.4-.9*fold),-.02,.12)
		if fold>.5 then w.inner.CFrame*=CFrame.new(0,-.1,.2)end
	end
	local stand=math.clamp(o.legs or 0,0,1)
	for _,l in ipairs(self.legs)do
		local hip=root*CFrame.new(l.side*.35,1.6,.1)*CFrame.Angles(math.rad(-75*(1-stand)),0,0)
		l.leg.CFrame=hip*CFrame.new(0,-.8,0)*CFrame.Angles(0,0,math.rad(90))
		l.foot.CFrame=hip*CFrame.new(0,-1.58,-.12)
	end
end
-- 0 shown .. 1 gone (every part, the glint too).
function Stork:setAlpha(a)
	self.alpha=a
	for _,p in ipairs(self.model:GetDescendants())do if p:IsA("BasePart")then p.Transparency=a end end
end
function Stork:destroy()self.model:Destroy()end

-- ── The egg (the real Companion Egg shells when they are loaded, else a parts stand-in) ──────────────────────────────
local Egg={};Egg.__index=Egg
Stork.Egg=Egg
Egg.Scale=1.25 -- the 1.3-stud model egg, about 1.6 studs tall in the garden
function Egg.new(parent)
	local model=Instance.new("Model");model.Name="OnboardEgg"
	local self=setmetatable({model=model,parts={},scale=Egg.Scale,S=Vector3.new(1,1,1)},Egg)
	local ok=pcall(function()
		local Preview=require(script.Parent.EggPreview3D)
		local copies=Preview.cloneTemplates()
		if not copies then error("not loaded")end
		local Models=require(game:GetService("ReplicatedStorage").Shared.EggModels)
		local t=Models.Types.companion
		-- Beta (36): until it opens, the egg wears the map with no zig-zag (V2.closedMap; the old one until uploaded)
		self.openMap=t.colorMap
		local closed=V2.closedMap()or t.colorMap
		for key,p in pairs(copies)do
			p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=true
			-- Fable (AERO-JUICE 4): the Neon core never shows through before the pop
			if key=="Core"then p.Material=Enum.Material.Neon;p.Color=t.core;p.Transparency=1
			else p.Material=Enum.Material.SmoothPlastic;p.TextureID=closed;p.Reflectance=0 end
			p.Size=Models.Egg[key].size*self.scale
			p.Parent=model
			self.parts[key]={part=p,center=Models.Egg[key].center*self.scale,size=Models.Egg[key].size*self.scale}
		end
		self.pivot=Models.Egg.spinPivot*self.scale
		self.meshes=true
	end)
	if not ok then
		-- The stand-in: a cream ovoid with blue spots and a lime band (the reveal egg's look), its top a cap that flies.
		for _,child in ipairs(model:GetChildren())do child:Destroy()end
		table.clear(self.parts)
		local cream,spot,band=Color3.fromHex("#FFF0D2"),Color3.fromHex("#3E5BE0"),Color3.fromHex("#A6D53A")
		local f=self.scale
		local bottom=part(model,"BottomShell",{Color=cream},Vector3.new(1.0,1.0,1.0)*f)
		local top=part(model,"TopShell",{Color=cream},Vector3.new(.9,.75,.9)*f)
		local stripe=part(model,"Band",{Color=band},Vector3.new(1.02,.14,1.02)*f)
		self.parts.BottomShell={part=bottom,center=Vector3.new(0,.5,0)*f}
		self.parts.TopShell={part=top,center=Vector3.new(0,.98,0)*f}
		self.parts.Band={part=stripe,center=Vector3.new(0,.32,0)*f}
		for i,p in ipairs({{.35,.55,.3},{-.3,.75,.32},{.05,.45,-.42}})do
			local dot=part(model,"Spot",{Color=spot},Vector3.new(.16,.16,.08)*f)
			self.parts["Spot"..i]={part=dot,center=Vector3.new(p[1],p[2],p[3])*f,face=true}
		end
		self.pivot=Vector3.new(0,.55,0)*f
	end
	model.Parent=parent
	return self
end
-- The pop (beta 36: "the zigzag ... should only appear once it's opening"): the shells take the map with the zig-zag
-- as they split along the meshes' own seam. Once.
function Egg:open()
	if self.opened then return end
	self.opened=true
	if self.openMap then
		for key,entry in pairs(self.parts)do if key~="Core"then entry.part.TextureID=self.openMap end end
	end
end
-- base: the egg's ground point and facing. rock (deg, about its own forward axis), swell (1 = rest; a number, or a
-- Vector3 of x, y, z scales for the anticipation dip and the flex), top: {up (studs), tip (deg), fade (0..1)}, fade:
-- the whole egg (0..1). The pose's frame and scale are kept for the 3D cracks (Egg:surface).
function Egg:pose(base,rock,swell,top,fade)
	local S=if typeof(swell)=="Vector3"then swell else Vector3.new(1,1,1)*(swell or 1)
	local turn=CFrame.new(self.pivot)*CFrame.Angles(0,0,math.rad(rock or 0))*CFrame.new(-self.pivot)
	self.frame,self.S=base*turn,S
	local sizeKey=S.X*1000+S.Y
	local resize=self.sizeKey~=sizeKey
	self.sizeKey=sizeKey
	for key,entry in pairs(self.parts)do
		local c=entry.center*S
		local cf=base*turn*CFrame.new(c)
		if key=="TopShell"and top then
			cf=base*CFrame.new(0,top.up or 0,0)*turn*CFrame.new(c)*CFrame.Angles(math.rad(-(top.tip or 0)),0,0)
		end
		if entry.face then cf=CFrame.lookAt(cf.Position,cf.Position+(cf.Position-(base*turn).Position)*Vector3.new(1,0,1))end
		entry.part.CFrame=cf
		if resize and entry.size then entry.part.Size=entry.size*S end
		local a=fade or 0
		if key=="TopShell"and top then a=math.max(a,top.fade or 0)end
		if key~="Core"then entry.part.Transparency=a end
	end
end
-- A point on the shell (EggCrackPaths egg units) and its normal, in the world, for the last pose.
function Egg:surface(point,normal,lift)
	local frame=self.frame or CFrame.new()
	local S=self.S or Vector3.new(1,1,1)
	local at=point*self.scale*S+normal*(lift or 0)
	return frame*at,frame:VectorToWorldSpace(normal)
end
-- The top of the egg (world), the egg's height (studs).
function Egg:height()return 1.3*self.scale end
function Egg:destroy()self.model:Destroy()end

-- ── The blanket: a knotted bundle under the beak, or open flat on the ground ─────────────────────────────────────────
local Blanket={};Blanket.__index=Blanket
Stork.Blanket=Blanket
Blanket.Dots=table.freeze({{0,1},{.7,.55},{-.7,.55},{.45,-.2},{-.45,-.2},{0,-.6},{.85,0},{-.85,0}})
function Blanket.new(parent)
	local model=Instance.new("Model");model.Name="OnboardBlanket"
	local self=setmetatable({model=model,dots={}},Blanket)
	local fabric={Color=S.blanket,Material=Enum.Material.Fabric}
	self.bag=part(model,"Bundle",fabric,Vector3.new(1.75,1.35,1.75))
	self.knot=part(model,"Knot",fabric,Vector3.new(.45,.4,.45))
	self.ears={part(model,"KnotEar",fabric,Vector3.new(.42,.22,.26)),part(model,"KnotEar",fabric,Vector3.new(.42,.22,.26))}
	self.strap=cylinder(model,"Strap",1,.09,S.blanket:Lerp(Color3.new(1,1,1),.25))
	self.strap.Material=Enum.Material.Fabric
	self.flat=cylinder(model,"OpenBlanket",.1,S.open*2,S.blanket)
	self.flat.Material=Enum.Material.Fabric
	for i=1,#Blanket.Dots do
		local dot=cylinder(model,"Dot",.04,.24,S.dots)
		dot.Material=Enum.Material.Fabric
		self.dots[i]=dot
	end
	model.Parent=parent
	return self
end
-- Hanging: knot = the beak tip (world), drop = studs of strap under it. Returns the bundle's centre (the egg sits in it
-- with its top showing).
function Blanket:hang(knot,drop,facing)
	local down=Vector3.new(0,-1,0)
	local top=knot+down*(.2+drop)
	local yaw=facing or CFrame.new()
	local center=top+down*.65
	self.flat.Transparency=1;self.bag.Transparency=0;self.knot.Transparency=0;self.strap.Transparency=0
	for _,e in ipairs(self.ears)do e.Transparency=0 end
	self.bag.CFrame=CFrame.new(center)*yaw.Rotation
	self.knot.CFrame=CFrame.new(top+Vector3.new(0,.05,0))*yaw.Rotation
	self.ears[1].CFrame=CFrame.new(top+Vector3.new(0,.15,0))*yaw.Rotation*CFrame.Angles(0,0,math.rad(35))*CFrame.new(.22,0,0)
	self.ears[2].CFrame=CFrame.new(top+Vector3.new(0,.15,0))*yaw.Rotation*CFrame.Angles(0,0,math.rad(-35))*CFrame.new(-.22,0,0)
	local length=math.max(.05,(knot-top).Magnitude)
	self.strap.Size=Vector3.new(length,.09,.09)
	self.strap.CFrame=CFrame.new((knot+top)/2)*CFrame.Angles(0,0,math.rad(90))
	-- the dots on the bundle's front and sides
	for i,dot in ipairs(self.dots)do
		local d=Blanket.Dots[i]
		local a=d[1]*1.3
		local dir=(yaw.Rotation*CFrame.Angles(0,a,0)).LookVector*-1
		local at=center+dir*.86+Vector3.new(0,d[2]*.35,0)
		dot.CFrame=CFrame.lookAt(at,at+dir)*CFrame.Angles(0,math.rad(90),0)
		dot.Transparency=0
	end
	return center
end
-- Open flat on the ground at `ground` (world point); u: 0 (still the bundle shape) .. 1 (flat).
function Blanket:open(ground,u,facing)
	u=math.clamp(u or 1,0,1)
	local yaw=(facing or CFrame.new()).Rotation
	self.strap.Transparency=1;self.knot.Transparency=1;for _,e in ipairs(self.ears)do e.Transparency=1 end
	self.bag.Transparency=if u>=1 then 1 else u
	self.bag.CFrame=CFrame.new(ground+Vector3.new(0,.6*(1-u),0))*yaw
	self.flat.Transparency=1-u
	local r=S.open*(.4+.6*u)
	self.flat.Size=Vector3.new(.1,r*2,r*2)
	self.flat.CFrame=CFrame.new(ground+Vector3.new(0,.05,0))*yaw*CFrame.Angles(0,0,math.rad(90))
	for i,dot in ipairs(self.dots)do
		local d=Blanket.Dots[i]
		local at=ground+yaw*Vector3.new(d[1]*r*.7,.11,d[2]*r*.6)
		dot.CFrame=CFrame.new(at)*yaw*CFrame.Angles(0,0,math.rad(90))
		dot.Transparency=1-u
	end
end
function Blanket:setAlpha(a)
	for _,p in ipairs(self.model:GetDescendants())do if p:IsA("BasePart")then p.Transparency=math.max(p.Transparency,a)end end
end
function Blanket:destroy()self.model:Destroy()end
return Stork
