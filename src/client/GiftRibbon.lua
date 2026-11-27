-- The free egg's ribbon on the egg machine (GIFT-ART-BRIEF section 1, "a real ribbon, not a dot"; GiftChain parks a
-- gift there). Local parts in the machine's model, placed from the dial's own frame (the DialPivot attachment and the
-- Dial part's rest): a matte pink sash across the dial at 30 degrees, a bow at its upper right (two .5 stud loops, a
-- .18 knot, two .45 tails swaying +-6 degrees on a 3 s sine) and a tag under the bow, "Free egg!" with the 28 px
-- wrapped egg (a BillboardGui in PlayerGui so a tap reaches it; MaxDistance 60). Anchored, no collision, query, touch
-- or shadow. Idle: one glint down the sash every 5 s; machine_attract once a session, the first time the player
-- comes within 20 studs. The first crank tick of the gift's own crank unties it (Machine:giftCrank, then untie()):
-- the bow opens (.2 s), the sash slides off, falls 1.5 studs and fades (.4 s), blanket_rustle at 1.3 and the
-- machine_light buzz. Reduced Motion: no sway or glint; the untie is a .15 s fade. Numbers and curves: GiftArt.
-- options: {gui() -> PlayerGui or nil, text (the tag's words), onTap(), play(name, speed, volume), buzz(name),
--   reduced() -> bool, clock (default os.clock)}
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GiftArt=require(Shared:WaitForChild("GiftArt"))
local Corner=require(Shared:WaitForChild("EggCorner"))
local Ribbon={};Ribbon.__index=Ribbon
Ribbon.Name="EggDropGiftRibbon"
local attracted=false -- once a session

local function inert(part)
	part.Anchored,part.CanCollide,part.CanQuery,part.CanTouch,part.CastShadow=true,false,false,false,false
	part.Material=Enum.Material.SmoothPlastic
	part.TopSurface,part.BottomSurface=Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
	return part
end
local function make(name,size,color,shape)
	local p=Instance.new("Part")
	p.Name=name;p.Size=size;p.Color=color
	if shape=="ball"then p.Shape=Enum.PartType.Ball end
	if shape=="oval"then local m=Instance.new("SpecialMesh");m.MeshType=Enum.MeshType.Sphere;m.Parent=p end
	return inert(p)
end

function Ribbon.new(options)
	return setmetatable({o=options or {},clock=(options and options.clock)or os.clock,t=0,shown=true},Ribbon)
end
function Ribbon:reduced()return self.o.reduced~=nil and self.o.reduced()==true end
function Ribbon:play(name,speed,volume)if self.o.play then pcall(self.o.play,name,speed,volume)end end
-- The dial face's frame (x right, y up, z out of the face) and its diameter, from the machine's bound parts.
function Ribbon.face(parts)
	local pivot=parts and parts.dialPivot
	local dial=parts and parts.dial
	if typeof(pivot)~="CFrame"or not dial then return nil end
	local face=(Corner.machineData().dialFace or {0,0,1})
	local n=pivot:VectorToWorldSpace(Vector3.new(face[1],face[2],face[3])).Unit
	local rest=dial.rest
	local size=dial.part.Size
	local function extent(v)
		return(math.abs(rest.RightVector:Dot(v))*size.X+math.abs(rest.UpVector:Dot(v))*size.Y+math.abs(rest.LookVector:Dot(v))*size.Z)/2
	end
	local front=(rest.Position-pivot.Position):Dot(n)+extent(n)+GiftArt.Ribbon.sash.lift
	local diameter=2*math.max(extent(pivot.RightVector),extent(pivot.UpVector))
	return CFrame.new(pivot.Position+n*front)*pivot.Rotation,diameter
end
function Ribbon:build(parts)
	self:clearParts()
	local frame,diameter=Ribbon.face(parts)
	if not frame then return false end
	local R=GiftArt.Ribbon
	local L=GiftArt.ribbonLayout(diameter)
	local folder=Instance.new("Model");folder.Name=Ribbon.Name
	local pink,deep=GiftArt.color("pink"),GiftArt.color("deep")
	local p={folder=folder,frame=frame,layout=L,model=parts.model}
	p.sash=make("Sash",Vector3.new(L.sash.length,R.sash.w,R.sash.thick),pink)
	p.glint=make("Glint",Vector3.new(R.glint.size,R.sash.w+.01,.01),Color3.new(1,1,1))
	p.glint.Material=Enum.Material.Neon;p.glint.Transparency=1
	p.loops={make("LoopL",Vector3.new(R.bow.loop,R.bow.loopTall,R.bow.loopThick),pink,"oval"),make("LoopR",Vector3.new(R.bow.loop,R.bow.loopTall,R.bow.loopThick),pink,"oval")}
	p.tails={make("TailL",Vector3.new(R.bow.tailW,R.bow.tail,R.bow.tailThick),deep),make("TailR",Vector3.new(R.bow.tailW,R.bow.tail,R.bow.tailThick),deep)}
	p.knot=make("Knot",Vector3.new(R.bow.knot,R.bow.knot,R.bow.knot),deep,"ball")
	for _,part in ipairs({p.sash,p.glint,p.knot,p.loops[1],p.loops[2],p.tails[1],p.tails[2]})do part.Parent=folder end
	folder.Parent=parts.model
	-- the tag, under the bow
	local gui=self.o.gui and self.o.gui()
	if gui then
		local T=R.tag
		local board=Instance.new("BillboardGui")
		board.Name="EggDropGiftTag";board.Size=UDim2.fromOffset(T.w,T.h);board.LightInfluence=0;board.AlwaysOnTop=false
		board.MaxDistance=T.maxDistance;board.Active=true;board.ResetOnSpawn=false;board.Adornee=p.knot
		board.StudsOffsetWorldSpace=frame:VectorToWorldSpace(L.tag-L.bow)
		local tag=Instance.new("TextButton")
		tag.Name="Tag";tag.Text="";tag.AutoButtonColor=false;tag.Size=UDim2.fromScale(1,1);tag.BackgroundColor3=Color3.new(1,1,1)
		tag.BackgroundTransparency=GiftArt.GlassTransparency;tag.BorderSizePixel=0;tag.Selectable=true;tag.Parent=board
		local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(.5,0);corner.Parent=tag
		local stroke=Instance.new("UIStroke");stroke.Color=GiftArt.color("ink");stroke.Thickness=1.5;stroke.Transparency=.2
		stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Parent=tag
		local Draw=require(script.Parent:WaitForChild("GiftEggArt"))
		Draw.egg(tag,T.egg,UDim2.new(0,14,.5,0),2)
		local words=Instance.new("TextLabel")
		words.Name="Words";words.BackgroundTransparency=1;words.Position=UDim2.fromOffset(28,0);words.Size=UDim2.new(1,-32,1,0)
		words.Font=Enum.Font.BuilderSansExtraBold;words.TextSize=T.font;words.TextColor3=GiftArt.color("ink");words.Text=self.o.text or "Free egg!"
		words.ZIndex=3;words.Parent=tag
		tag.Activated:Connect(function()if self.shown and not self.untieAt and self.o.onTap then pcall(self.o.onTap)end end)
		board.Parent=gui
		p.board,p.tag=board,tag
	end
	self.parts=p
	return true
end
function Ribbon:clearParts()
	local p=self.parts
	if not p then return end
	self.parts=nil
	if p.folder then p.folder:Destroy()end
	if p.board then p.board:Destroy()end
end
-- The first crank tick of the gift's crank.
function Ribbon:untie()
	if self.untieAt then return end
	self.untieAt=self.t
	local C=GiftArt.RibbonCue
	self:play(C.sound,C.speed,C.volume)
	if self.o.buzz then pcall(self.o.buzz,C.buzz)end
end
-- The gift is no longer waiting (and was not untied): it fades and goes.
function Ribbon:off()if not self.offAt then self.offAt=self.t end end
function Ribbon:gone()return self.dead==true end
function Ribbon:step(dt,parts,root)
	if self.dead then return end
	self.t+=dt or 0
	if parts and(not self.parts or self.parts.model~=parts.model or not self.parts.folder.Parent)then
		if not self:build(parts)then return end
	end
	local p=self.parts
	if not p then return end
	local reduced=self:reduced()
	local s=GiftArt.ribbon(self.t,if self.untieAt then self.t-self.untieAt else nil,reduced)
	local alpha=s.alpha
	if self.offAt then alpha=math.min(alpha,1-math.clamp((self.t-self.offAt)/GiftArt.Ribbon.offFade,0,1))end
	if s.done or(self.offAt and alpha<=0)then self:destroy();return end
	-- once a session, the first time the player comes within 20 studs
	if not attracted and not self.untieAt and typeof(root)=="Vector3"and(root-p.frame.Position).Magnitude<=GiftArt.Ribbon.attract then
		attracted=true
		self:play("machine_attract",1,.3)
	end
	local R,L=GiftArt.Ribbon,p.layout
	local drop=Vector3.new(0,-s.fall,0)+p.frame:VectorToWorldSpace(Vector3.new(0,0,.35*s.fall/R.untie.fall))
	local frame=CFrame.new(drop)*p.frame
	local transparency=1-alpha
	local function set(part,cf,extra)
		part.CFrame=cf
		local want=math.clamp(transparency+(extra or 0),0,1)
		if part.Transparency~=want then part.Transparency=want end
	end
	set(p.sash,frame*CFrame.new(L.sash.at)*CFrame.Angles(0,0,math.rad(L.sash.angle)))
	-- the bow: open shrinks the loops and swings them out, the knot loosens
	local open=s.open
	for i,loop in ipairs(p.loops)do
		local row=L.loops[i]
		local sign=if i==1 then -1 else 1
		local k=1-open
		loop.Size=Vector3.new(R.bow.loop*math.max(.05,k),R.bow.loopTall*math.max(.05,k),R.bow.loopThick)
		set(loop,frame*CFrame.new(row.at+Vector3.new(sign*.15*open,-.1*open,0))*CFrame.Angles(0,0,math.rad(row.angle+sign*60*open)))
	end
	p.knot.Size=Vector3.one*R.bow.knot*(1-.4*open)
	set(p.knot,frame*CFrame.new(L.bow))
	for i,tail in ipairs(p.tails)do
		local row=L.tails[i]
		local sign=if i==1 then -1 else 1
		set(tail,frame*CFrame.new(L.bow)*CFrame.Angles(0,0,math.rad(row.angle+s.sway+sign*40*open))*CFrame.new(0,-R.bow.tail/2,-R.bow.loopThick/4))
	end
	-- the glint, down the sash from its upper right
	if s.glint then
		local a=math.rad(L.sash.angle)
		local along=(.5-s.glint)*L.sash.length
		p.glint.CFrame=frame*CFrame.new(L.sash.at+Vector3.new(math.cos(a)*along,math.sin(a)*along,R.sash.thick/2+.006))*CFrame.Angles(0,0,a)
		local want=1-.75*math.sin(s.glint*math.pi)
		if p.glint.Transparency~=want then p.glint.Transparency=want end
	elseif p.glint.Transparency~=1 then p.glint.Transparency=1 end
	if p.board then
		p.board.Enabled=self.shown and not self.untieAt and alpha>.05
		if p.tag then
			local want=GiftArt.GlassTransparency+(1-GiftArt.GlassTransparency)*transparency
			if p.tag.BackgroundTransparency~=want then p.tag.BackgroundTransparency=want end
		end
	end
end
function Ribbon:destroy()
	if self.dead then return end
	self.dead=true
	self:clearParts()
end
return Ribbon
