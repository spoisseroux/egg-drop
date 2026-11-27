-- The paint wipe on the garden pet after the free Paint Egg's "Paint {pet}!" (GIFT-ART-BRIEF section 3, 1.8 s; the
-- schedule, curves and cues are GiftArt.wipe). Presentation only: the colour itself is the existing hueUse; this
-- draws its arrival. The pot (1.2 studs) arrives 2.2 studs over the pet and tips 110 degrees while the pet looks up,
-- eyes wide; a ribbon of paint lands on its head (it squashes 12%); the sweep runs crown to feet (Quad in-out, .4 to
-- 1.0 s), a bright edge of the pot's colour halfway to white with 6 drips just ahead of it and the final colour
-- behind; a 3 stud ring of the colour spreads on the ground and fades; the shake (+-14 degrees, four damped swings)
-- throws 10 beads; it looks at each paw, then jump-spins with 10 sparkles. Then 2 s under the pet: "{pet} is
-- {colour}!" ("Deeper {colour}!" for a pot it already wore: the wipe at 60% length). The camera comes 4% closer (the
-- field of view) over .3 s and back. Face, eyes and the secondary palette never tint (GardenPetVisual's overlay).
-- Reduced Motion, or AliveBudget at 2 or more: a .4 s cross-fade, the ring, one sound and the settle buzz.
-- The server's answer can land after the pour: the sweep waits for the new colour (Hold s at most), so it always
-- reveals the colour the pet is really getting.
-- deps: pet() -> the garden visual (GardenPetVisual), play(name, speed, volume), rise(name, from, to, seconds) and
--   fade(name, seconds) (optional: the shimmer's pitch climb and tail), haptic(name), reduced() -> bool, budget() ->
--   level, camera() -> Camera, text(key, vars), parent (the folder's parent, default workspace)
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GiftArt=require(Shared:WaitForChild("GiftArt"))
local Wipe={};Wipe.__index=Wipe
Wipe.Hold=1.5 -- s the sweep waits for the server's new colour
Wipe.Folder="EggDropPaintWipe"

local function inert(part)
	part.Anchored,part.CanCollide,part.CanQuery,part.CanTouch,part.CastShadow=true,false,false,false,false
	part.Material=Enum.Material.SmoothPlastic
	part.TopSurface,part.BottomSurface=Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
	return part
end
local function part(parent,name,size,color,shape,props)
	local p=Instance.new("Part")
	p.Name=name;p.Size=size;p.Color=color;p.Transparency=1
	if shape=="ball"then p.Shape=Enum.PartType.Ball elseif shape=="cylinder"then p.Shape=Enum.PartType.Cylinder end
	for k,v in pairs(props or {})do p[k]=v end
	inert(p)
	p.Parent=parent
	return p
end

function Wipe.new(deps)return setmetatable({d=deps},Wipe)end
function Wipe:play(name,speed,volume)if self.d.play then pcall(self.d.play,name,speed,volume)end end
function Wipe:buzz(name)if self.d.haptic then pcall(self.d.haptic,name)end end
function Wipe:running()return self.run~=nil end
-- At the tap (before the paint is asked for): the body pieces' colours now, so the sweep has where it starts from.
function Wipe:prepare()
	local visual=self.d.pet and self.d.pet()
	if not visual or type(visual.pieces)~="table"then self.prepared=nil;return false end
	local from={}
	for _,entry in ipairs(visual.pieces)do
		if entry.colorRole=="body"then from[entry]=entry.color or entry.part.Color end
	end
	self.prepared={visual=visual,from=from,at=os.clock()}
	return true
end
-- The pot reached the pet: run. info = {pot (Color3), colour (its name), pet (name), duplicate}.
function Wipe:start(info)
	self:stop()
	local prepared=self.prepared
	self.prepared=nil
	local visual=self.d.pet and self.d.pet()
	if not visual or not prepared or prepared.visual~=visual or os.clock()-prepared.at>20 then return false end
	local reduced=(self.d.reduced and self.d.reduced()==true)or(self.d.budget and(tonumber(self.d.budget())or 0)>=2)
	local run={visual=visual,from=prepared.from,pot=info.pot or GiftArt.color("pink"),info=info,reduced=reduced,t=0,last=-1,held=0,
		duplicate=info.duplicate==true}
	run.edge=GiftArt.edgeColor(run.pot)
	self.run=run
	self:build(run)
	-- the 4% closer camera (the field of view, so the player's own camera is never taken)
	local camera=self.d.camera and self.d.camera()
	if camera and not reduced and camera.CameraType==Enum.CameraType.Custom then run.camera,run.fov=camera,camera.FieldOfView end
	visual.giftPose={tint=function(entry,cf,size)return self:tint(run,entry,cf,size)end}
	self.link=RunService.Heartbeat:Connect(function(dt)
		local ok,problem=pcall(self.step,self,dt)
		if not ok then warn("[PaintWipe] "..tostring(problem));self:stop()end
	end)
	return true
end
function Wipe:build(run)
	local folder=Instance.new("Folder");folder.Name=Wipe.Folder
	run.folder=folder
	local W=GiftArt.Wipe
	if not run.reduced then
		run.potBody=part(folder,"Pot",Vector3.new(W.pot.size*.9,W.pot.size,W.pot.size),Color3.fromHex("#E7FFFF"),"cylinder")
		run.potPaint=part(folder,"PotPaint",Vector3.new(W.pot.size*.5,W.pot.size*.82,W.pot.size*.82),run.pot,"cylinder")
		run.potRim=part(folder,"PotRim",Vector3.new(.12,W.pot.size*1.06,W.pot.size*1.06),Color3.fromHex("#E9FFFF"),"cylinder")
		run.stream=part(folder,"Stream",Vector3.new(W.ribbon,1,.12),run.pot)
		run.drips={};run.beads={};run.sparkles={}
		for i=1,W.sweep.drips do run.drips[i]=part(folder,"Drip"..i,Vector3.new(.16,.22,.16),run.pot,"ball")end
		for i=1,W.beads.count do run.beads[i]=part(folder,"Bead"..i,Vector3.new(.14,.14,.14),run.pot,"ball")end
		for i=1,W.sparkles do
			run.sparkles[i]=part(folder,"Sparkle"..i,Vector3.new(.12,.12,.12),if i%2==0 then Color3.new(1,1,1)else run.edge,"ball",{Material=Enum.Material.Neon})
		end
	end
	run.ring=part(folder,"Ring",Vector3.new(.05,1,1),run.pot,"cylinder")
	folder.Parent=self.d.parent or workspace
end
-- The pet's height share of a piece: 0 the crown, 1 the feet.
local function shares(run,cf,size)
	local top,bottom=run.top,run.bottom
	if not top or top-bottom<.05 then return .5,.5 end
	local h=top-bottom
	local y=cf.Position.Y
	return math.clamp((top-(y+size.Y/2))/h,0,1),math.clamp((top-(y-size.Y/2))/h,0,1)
end
function Wipe:tint(run,entry,cf,size)
	local old=run.from[entry]
	local new=entry.color
	if not old or not new then return nil end
	if run.reduced then return GiftArt.mix(old,new,run.sweep or 0)end
	local a,b=shares(run,cf,size)
	local state=GiftArt.sweepState(a,b,run.sweep or 0)
	if state=="new"then return new end
	if state=="edge"then return run.edge end
	return old
end
-- Has the server's new colour arrived on the pet?
function Wipe:updated(run)
	for entry,old in pairs(run.from)do
		local c=entry.color
		if c and(math.abs(c.R-old.R)+math.abs(c.G-old.G)+math.abs(c.B-old.B))>.004 then return true end
	end
	return false
end
function Wipe:step(dt)
	local run=self.run
	if not run then return end
	local visual=run.visual
	if visual.destroyed or not visual.model or not visual.model.Parent then self:stop();return end
	local W=GiftArt.Wipe
	-- the sweep waits for the new colour (at its start; Hold s at most)
	local startAt=if run.reduced then 0 else W.sweep.from*(if run.duplicate then W.duplicate else 1)
	if not run.ready then run.ready=self:updated(run)end
	if not run.ready and run.t>=startAt and run.held<Wipe.Hold then run.held+=dt
	else run.t+=dt end
	local t=run.t
	local s=GiftArt.wipe(t,run.duplicate,run.reduced)
	run.sweep=s.sweep
	-- the cues
	local list=if run.reduced then GiftArt.WipeReducedCues else GiftArt.WipeCues
	local clock=if run.reduced then t else GiftArt.wipeClock(t,run.duplicate)
	for _,cue in ipairs(GiftArt.due(list,run.last,clock))do
		self:play(cue.sound,cue.speed,cue.volume)
		if cue.toSpeed and self.d.rise then pcall(self.d.rise,cue.sound,cue.speed,cue.toSpeed,(cue.rising or .6)*(if run.duplicate then W.duplicate else 1))end
		if cue.buzz then self:buzz(cue.buzz)end
	end
	if not run.shimmerOff and clock>=W.sweep.to and not run.reduced then
		run.shimmerOff=true
		if self.d.fade then pcall(self.d.fade,"shimmer_loop",.2)end
	end
	run.last=clock
	-- the pet's frame (last frame's hull)
	local frame,size=visual.bodyBoundsFrame,visual.bodyBoundsSize
	local origin=visual.origin
	if typeof(frame)=="CFrame"and typeof(size)=="Vector3"then
		run.top,run.bottom=frame.Position.Y+size.Y/2,frame.Position.Y-size.Y/2
		run.centre=frame.Position
		run.radius=math.max(size.X,size.Z)/2
	elseif typeof(origin)=="Vector3"then
		run.top,run.bottom,run.centre,run.radius=origin.Y+1.6,origin.Y,origin+Vector3.new(0,.8,0),.7
	end
	local ground=if typeof(origin)=="Vector3"then origin.Y else(run.bottom or 0)
	-- the pet's own moment
	local pose=visual.giftPose
	if pose then
		pose.headPitch,pose.headYaw,pose.eye,pose.roll,pose.hop,pose.spin=s.headPitch,s.headYaw,s.eye,s.roll,s.hop,s.spin
		pose.squash=s.squash*W.squash/.14 -- GardenPetVisual's boop squashes the body 14% at 1
	end
	visual.poseDirty=true
	if run.camera and run.fov then run.camera.FieldOfView=run.fov*(1-W.closer*s.closer)end
	local top,centre,radius=run.top or ground+1.5,run.centre or Vector3.new(0,ground+.8,0),run.radius or .7
	-- the pot and its pour
	if run.potBody then
		local over=top+s.pot.over
		local camera=self.d.camera and self.d.camera()
		local side=if camera then camera.CFrame.RightVector else Vector3.new(1,0,0)
		side=Vector3.new(side.X,0,side.Z)
		side=if side.Magnitude>1e-3 then side.Unit else Vector3.new(1,0,0)
		local at=Vector3.new(centre.X,over,centre.Z)+side*.35
		-- a cylinder's axis is X: stand it up, then tip it toward the pet about the axis facing the camera
		local tipAxis=side:Cross(Vector3.yAxis)
		local upright=CFrame.fromMatrix(at,Vector3.yAxis,side:Cross(Vector3.yAxis).Unit)
		local tipped=CFrame.new(at)*CFrame.fromAxisAngle(tipAxis.Magnitude>1e-3 and tipAxis.Unit or Vector3.zAxis,math.rad(s.pot.tip))*(upright-upright.Position)
		local alpha=if s.pot.shown then s.pot.alpha else 0
		run.potBody.CFrame=tipped;run.potBody.Transparency=1-alpha*.75
		run.potPaint.CFrame=tipped*CFrame.new(-.05,0,0);run.potPaint.Transparency=1-alpha
		run.potRim.CFrame=tipped*CFrame.new(W.pot.size*.45,0,0);run.potRim.Transparency=1-alpha
		-- the ribbon of paint from the lip to the crown
		local lip=(tipped*CFrame.new(W.pot.size*.45,0,0)).Position
		local head=Vector3.new(centre.X,top,centre.Z)
		local reach=head-lip
		if s.stream>0 and reach.Magnitude>.05 then
			local length=reach.Magnitude*s.stream
			run.stream.Size=Vector3.new(W.ribbon,length,.12)
			-- the long side along the pour, the flat face to the camera's side
			local across=reach.Unit:Cross(side)
			run.stream.CFrame=CFrame.fromMatrix(lip+reach.Unit*length/2,if across.Magnitude>1e-3 then across.Unit else Vector3.xAxis,reach.Unit*-1)
			run.stream.Transparency=0
		else run.stream.Transparency=1 end
		-- the drips, just ahead of the front
		local height=math.max(.5,top-(run.bottom or ground))
		for i,drip in ipairs(run.drips)do
			local angle,share=GiftArt.drip(i,#run.drips,s.sweep,height)
			if angle then
				drip.Position=Vector3.new(centre.X+math.cos(angle)*radius*.92,top-share*height,centre.Z+math.sin(angle)*radius*.92)
				drip.Transparency=0
			else drip.Transparency=1 end
		end
		for i,bead in ipairs(run.beads)do
			if s.beads then
				local offset,a=GiftArt.bead(i,#run.beads,s.beads,1.6)
				bead.Position=centre+offset;bead.Transparency=1-a
			else bead.Transparency=1 end
		end
		local sparkAge=(GiftArt.wipeClock(t,run.duplicate)-W.paws.from)/(W.seconds-W.paws.from)
		for i,spark in ipairs(run.sparkles)do
			if sparkAge>0 and sparkAge<1 then
				local offset,a=GiftArt.bead(i,#run.sparkles,sparkAge,1.8)
				spark.Position=Vector3.new(centre.X,top,centre.Z)+offset+Vector3.new(0,.4*sparkAge,0);spark.Transparency=1-a
			else spark.Transparency=1 end
		end
	end
	if s.ring then
		run.ring.Size=Vector3.new(.05,math.max(.05,s.ring.size),math.max(.05,s.ring.size))
		run.ring.CFrame=CFrame.new(centre.X,ground+.04,centre.Z)*CFrame.Angles(0,0,math.pi/2)
		run.ring.Transparency=1-.85*s.ring.alpha
	else run.ring.Transparency=1 end
	if s.done then
		self:label(run)
		self:stop()
	end
end
-- "{pet} is {colour}!" (or "Deeper {colour}!") for 2 s under the pet.
function Wipe:label(run)
	local visual=run.visual
	local anchor=visual.model and visual.model.PrimaryPart
	local text=self.d.text
	if not anchor or not text then return end
	local info=run.info
	local words=if info.duplicate then text("onbGift.card.deeper",{name=info.colour})else text("onbGift.wipe",{pet=info.pet,colour=info.colour})
	local gui=self.d.gui and self.d.gui()
	local board=Instance.new("BillboardGui")
	board.Name="EggDropPaintLabel";board.Adornee=anchor;board.AlwaysOnTop=true;board.LightInfluence=0;board.MaxDistance=80
	board.Size=UDim2.fromOffset(240,40);board.StudsOffsetWorldSpace=Vector3.new(0,-1.1,0);board.ResetOnSpawn=false
	local pill=Instance.new("TextLabel")
	pill.Name="Pill";pill.AnchorPoint=Vector2.new(.5,.5);pill.Position=UDim2.fromScale(.5,.5);pill.AutomaticSize=Enum.AutomaticSize.X
	pill.Size=UDim2.fromOffset(0,34);pill.BackgroundColor3=Color3.new(1,1,1);pill.BackgroundTransparency=GiftArt.GlassTransparency
	pill.Font=Enum.Font.BuilderSansExtraBold;pill.TextSize=18;pill.TextColor3=GiftArt.color("ink");pill.Text=words;pill.Parent=board
	local pad=Instance.new("UIPadding");pad.PaddingLeft=UDim.new(0,14);pad.PaddingRight=UDim.new(0,14);pad.Parent=pill
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(.5,0);corner.Parent=pill
	local stroke=Instance.new("UIStroke");stroke.Color=run.pot;stroke.Thickness=2;stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Parent=pill
	board.Parent=gui or anchor
	task.delay(GiftArt.Wipe.label,function()if board.Parent then board:Destroy()end end)
end
function Wipe:stop()
	if self.link then self.link:Disconnect();self.link=nil end
	local run=self.run
	self.run=nil
	if not run then return end
	if run.visual and run.visual.giftPose then run.visual.giftPose=nil;run.visual.poseDirty=true end
	if run.camera and run.fov then pcall(function()run.camera.FieldOfView=run.fov end)end
	if run.folder then run.folder:Destroy()end
end
return Wipe
