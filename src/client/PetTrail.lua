-- G2 (G2-FIRST-SESSION-LOOK 2026-11-25 section 1a, switch FeatureFlags.PetTrail): the way to the pet.
-- A short line of paw prints on the grass from the player's feet to their pet, StationAttract's ground ring at the
-- pet (the pet turns its head to the player through PetLookAt.faceOwner) and, while the pet is off screen, one round
-- chip on the screen edge on the pet's side. It shows with G1's say-hi line (CoachCards.trailDue) and goes on the
-- first hello, after 30 s, or when a menu, a machine or the deck opens. Client only, pooled parts, no remotes.
-- The top half is pure (spec-checked offline); the view below builds the parts on first use.
-- Glow steps (ONBOARDING-V3-BRIEF section 2, switch Onboard "trail2", read once per trail at start): the prints, ring
-- and wave are GlowSteps (Shared.TrailGlow's numbers), the chip pulses with the wave, and it is a guide trail: no 30 s
-- end, hidden (not ended) while a menu or the deck is up. Off: everything below exactly as before.
local Trail={}
Trail.__index=Trail
Trail.Size=1.1          -- print size, studs
Trail.Step=2.2          -- between prints
Trail.Side=.35          -- left / right of the line, like real tracks
Trail.Ahead=3           -- the first print, ahead of the player
Trail.Short=2.5         -- the last print stops this short of the pet
Trail.Max=12            -- prints at most (the ones nearest the player)
Trail.MinDistance=6     -- closer than this: no prints, the ring only
Trail.See=.35           -- see-through (the spec's "35%"; lift to .2 if the night check loses them)
Trail.Color=Color3.fromHex("#FFF4DC") -- warm cream, matte
Trail.WalkEvery=1.6;Trail.WalkGap=.12;Trail.WalkTime=.3;Trail.WalkScale=1.15
Trail.FadeTime=.4
Trail.Lifetime=30
Trail.RedrawPlayer=3;Trail.RedrawPet=2
Trail.RingRadius=2.2;Trail.RippleEvery=2.4
Trail.RayUp=6;Trail.RayDown=12;Trail.MaxNormal=.8;Trail.MaxOffLine=1.5
Trail.Chip=36;Trail.ChipInset=10
-- The paw art faces the SurfaceGui's top edge; on a Top face that is the part's -Z (its LookVector), so a part
-- looking along the line points the toes at the pet. A Studio pass that finds them backwards flips this to math.pi.
Trail.TopFaceYaw=0

-- ── Pure ────────────────────────────────────────────────────────────────────

local function flat(v)return Vector3.new(v.X,0,v.Z)end
-- The prints from `from` (the player's feet) to `to` (the pet on the ground): {position, side (-1/1), index},
-- nearest the player first. Positions are on the straight line, Y interpolated (the view grounds each one).
function Trail.prints(from,to)
	local d=flat(to)-flat(from)
	local length=d.Magnitude
	local out={}
	if length<Trail.MinDistance then return out end
	local dir=d/length
	local across=Vector3.new(-dir.Z,0,dir.X)
	local stop=length-Trail.Short
	local at=Trail.Ahead
	while at<=stop+1e-6 and #out<Trail.Max do
		local index=#out+1
		local side=if index%2==1 then -1 else 1
		local t=at/length
		local base=from+(to-from)*t
		table.insert(out,{position=base+across*(Trail.Side*side),side=side,index=index,along=at,lineY=base.Y})
		at+=Trail.Step
	end
	return out
end
-- The direction a print faces (toward the pet), on the ground plane.
function Trail.heading(from,to)
	local d=flat(to)-flat(from)
	return if d.Magnitude>1e-6 then d.Unit else Vector3.new(0,0,-1)
end
-- The soft walk: print `index`'s scale `t` seconds into the trail. Every WalkEvery s each print in turn swells to
-- WalkScale and back, WalkGap apart, running toward the pet. Reduced Motion: still prints, no swell.
function Trail.swell(t,index,reduced)
	if reduced then return 1 end
	local u=((t%Trail.WalkEvery)-(index-1)*Trail.WalkGap)/Trail.WalkTime
	if u<0 or u>1 then return 1 end
	return 1+(Trail.WalkScale-1)*math.sin(u*math.pi)
end
-- Leaving: print `index` of `count` `age` s into the fade; 0 = as drawn, 1 = gone. Nearest the player goes first and
-- the whole line is gone after FadeTime.
function Trail.fade(age,index,count)
	if count<=1 then return math.clamp(age/Trail.FadeTime,0,1)end
	local each=Trail.FadeTime/2
	local start=(index-1)/(count-1)*(Trail.FadeTime-each)
	return math.clamp((age-start)/each,0,1)
end
-- Why the trail ends now (nil = it stays): ctx = {hello, menu, deck}; `age` = seconds shown.
function Trail.endReason(age,ctx)
	if ctx.hello then return "hello"end
	if age>=Trail.Lifetime then return "time"end
	if ctx.menu then return "menu"end
	if ctx.deck then return "deck"end
	return nil
end
-- Redraw once the player has moved RedrawPlayer studs or the pet RedrawPet since the last draw.
function Trail.moved(drawn,player,pet)
	if not drawn then return true end
	return(flat(player)-flat(drawn.player)).Magnitude>=Trail.RedrawPlayer or(flat(pet)-flat(drawn.pet)).Magnitude>=Trail.RedrawPet
end
-- A ray hit under a print is lawn: the world's ground (a WorldMesh or Terrain, not water), a near-flat face, close
-- to the line between the player and the pet (not a machine top or a wall), and outside every wet or blocked
-- footprint (`inside(point)`).
function Trail.ground(hit,lineY,inside)
	if not hit or not hit.ground or hit.water then return false end
	if hit.normal.Y<Trail.MaxNormal then return false end
	if math.abs(hit.position.Y-lineY)>Trail.MaxOffLine then return false end
	if inside and inside(hit.position)then return false end
	return true
end
-- A print's frame: at `at`, lying on the ground (`normal` up) and looking along `heading` (toes toward the pet).
function Trail.frame(at,heading,normal)
	local up=if normal and normal.Magnitude>1e-6 then normal.Unit else Vector3.new(0,1,0)
	local look=heading-up*heading:Dot(up)
	look=if look.Magnitude>1e-6 then look.Unit else Vector3.new(0,0,-1)
	local right=look:Cross(up)
	return CFrame.fromMatrix(at,right,up)
end
-- Is a point inside a box footprint (`localPoint` in the box's space, `size` its size)? X and Z only.
function Trail.inFootprint(localPoint,size)
	return math.abs(localPoint.X)<=size.X*.5 and math.abs(localPoint.Z)<=size.Z*.5
end
-- The screen-edge chip: nil while the pet is on screen, else {x, y, angle (deg, 0 = pointing right)}. `point` is the
-- pet's viewport point (X, Y px; Z depth, negative = behind the camera), `size` the viewport.
function Trail.edge(size,point,inset)
	inset=inset or(Trail.Chip/2+Trail.ChipInset)
	local behind=point.Z<0
	local on=not behind and point.X>=0 and point.X<=size.X and point.Y>=0 and point.Y<=size.Y
	if on then return nil end
	local cx,cy=size.X/2,size.Y/2
	local dx,dy=point.X-cx,point.Y-cy
	if behind then dx,dy=-dx,-dy end
	if math.abs(dx)<1e-6 and math.abs(dy)<1e-6 then dy=1 end
	local hx,hy=math.max(1,cx-inset),math.max(1,cy-inset)
	local k=math.min(hx/math.max(1e-6,math.abs(dx)),hy/math.max(1e-6,math.abs(dy)))
	return{x=cx+dx*k,y=cy+dy*k,angle=math.deg(math.atan2(dy,dx))}
end

-- The switch for one trail: options.glow (a boolean or a function), read when the trail starts.
function Trail.glowOn(options)
	local glow=options and options.glow
	if type(glow)=="function"then
		local ok,value=pcall(glow)
		return ok and value==true
	end
	return glow==true
end
-- Why the trail ends now, as endReason, for a trail drawn with `glow` (a guide trail: "hide" while a menu or the deck
-- is up, no time end; the first hello still ends it). Without glow: endReason exactly.
local GlowRules
function Trail.endsFor(age,ctx,glow)
	if not glow then return Trail.endReason(age,ctx)end
	GlowRules=GlowRules or require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("TrailGlow"))
	return GlowRules.guideEnd(Trail.endReason(0,ctx),true)
end

-- ── View ────────────────────────────────────────────────────────────────────

local function part(parent,name,size)
	local p=Instance.new("Part")
	p.Name=name
	p.Anchored,p.CanCollide,p.CanTouch,p.CanQuery,p.CastShadow=true,false,false,false,false
	p.Transparency,p.Size,p.Material=1,size,Enum.Material.SmoothPlastic
	p.Parent=parent
	return p
end
local function round(frame)
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(.5,0);corner.Parent=frame
end

-- options: {gui (a ScreenGui for the chip), ringColor (Color3), chipColor (Color3)}
function Trail.new(options)
	local self=setmetatable({options=options or {},active=false,prints={},drawn=nil},Trail)
	return self
end
function Trail:build()
	if self.folder then return end
	local Kit=require(script.Parent.DeckKit)
	local folder=Instance.new("Folder");folder.Name="PetTrailPresentation";folder.Parent=workspace
	self.folder=folder
	for i=1,Trail.Max do
		local p=part(folder,"PawPrint"..i,Vector3.new(Trail.Size,.05,Trail.Size))
		local surface=Instance.new("SurfaceGui")
		surface.Face,surface.LightInfluence,surface.AlwaysOnTop=Enum.NormalId.Top,1,false
		surface.SizingMode,surface.PixelsPerStud=Enum.SurfaceGuiSizingMode.PixelsPerStud,64
		surface.Enabled=false;surface.Parent=p
		local holder=Instance.new("Frame");holder.Name="Paw";holder.BackgroundTransparency=1;holder.BorderSizePixel=0
		holder.AnchorPoint=Vector2.new(.5,.5);holder.Position=UDim2.fromScale(.5,.5);holder.Size=UDim2.fromScale(1,1);holder.Parent=surface
		local scale=Instance.new("UIScale");scale.Parent=holder
		Kit.VectorIcons.paw(holder,64,6)
		local inks={}
		for _,d in ipairs(holder:GetDescendants())do
			if d:IsA("GuiObject")and d:GetAttribute("IconInk")then d.BackgroundColor3=Trail.Color;d.BackgroundTransparency=Trail.See;table.insert(inks,d)end
		end
		self.prints[i]={part=p,surface=surface,scale=scale,inks=inks}
	end
	-- StationAttract's ground ring (a rounded frame's stroke on a flat surface) at the pet, smaller.
	local span=Trail.RingRadius*2+1.2
	local ringPart=part(folder,"PetRing",Vector3.new(span,.05,span))
	local surface=Instance.new("SurfaceGui")
	surface.Face,surface.LightInfluence,surface.AlwaysOnTop=Enum.NormalId.Top,0,false
	surface.SizingMode,surface.PixelsPerStud=Enum.SurfaceGuiSizingMode.PixelsPerStud,40
	surface.Enabled=false;surface.Parent=ringPart
	local color=self.options.ringColor or Color3.fromHex("#FF8FC0")
	local function circle(name,thickness,transparency)
		local frame=Instance.new("Frame");frame.Name=name;frame.AnchorPoint=Vector2.new(.5,.5);frame.Position=UDim2.fromScale(.5,.5)
		frame.Size=UDim2.fromScale(Trail.RingRadius*2/span,Trail.RingRadius*2/span);frame.BackgroundTransparency=1;round(frame)
		local stroke=Instance.new("UIStroke");stroke.Color,stroke.Thickness,stroke.Transparency=color,thickness,transparency;stroke.Parent=frame
		frame.Parent=surface
		return frame,stroke
	end
	local ring,ringStroke=circle("Ring",6,.1)
	local ripple,rippleStroke=circle("Ripple",4,1)
	self.ring={part=ringPart,surface=surface,ring=ring,ringStroke=ringStroke,ripple=ripple,rippleStroke=rippleStroke,span=span}
	self:buildChip(Kit)
end
-- The screen-edge chip: a round raised disc with the paw in the companions tint and a small pointer.
function Trail:buildChip(Kit)
	local gui=self.options.gui
	if gui and not self.chip then
		local chip=Instance.new("Frame");chip.Name="PetTrailChip";chip.AnchorPoint=Vector2.new(.5,.5);chip.Size=UDim2.fromOffset(Trail.Chip,Trail.Chip)
		chip.BackgroundColor3=Kit.color("raised");chip.BorderSizePixel=0;chip.Visible=false;chip.Active=false;chip.ZIndex=30;round(chip)
		chip.Parent=gui
		local pointer=Instance.new("Frame");pointer.Name="Pointer";pointer.AnchorPoint=Vector2.new(.5,.5);pointer.Size=UDim2.fromOffset(10,10)
		pointer.BackgroundColor3=chip.BackgroundColor3;pointer.BorderSizePixel=0;pointer.Rotation=45;pointer.ZIndex=29;pointer.Active=false;pointer.Parent=chip
		local icon=Kit.icon(chip,"paw",22,function()return self.options.chipColor or Color3.fromHex("#FF8FC0")end)
		icon.AnchorPoint,icon.Position=Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
		self.chip,self.pointer=chip,pointer
	end
end
-- Glow steps: the GlowSteps pool and the chip (with a UIScale for its pulse); the old prints and ring are never built.
function Trail:buildGlow()
	if self.steps then return end
	local Kit=require(script.Parent.DeckKit)
	local Steps=require(script.Parent.GlowSteps)
	local folder=Instance.new("Folder");folder.Name="PetTrailPresentation";folder.Parent=workspace
	self.glowFolder=folder
	self.steps=Steps.new({parent=folder,play=self.options.play})
	self:buildChip(Kit)
	if self.chip and not self.chipScale then
		local grow=Instance.new("UIScale");grow.Parent=self.chip
		self.chipScale=grow
	end
end
function Trail:start(now)
	self.glow=Trail.glowOn(self.options)
	if self.glow then self:buildGlow()else self:build()end
	self.active,self.leaving,self.startedAt,self.drawn=true,nil,now,nil
	self.count=0
end
-- Begin the fade (nearest the player first). Safe to call more than once.
function Trail:stop(now)
	if not self.active or self.leaving then return end
	self.leaving=now
	if self.chip then self.chip.Visible=false end
	if self.ring then self.ring.surface.Enabled=false end
	if self.steps then self.steps:target(nil)end
end
function Trail:hideAll()
	for _,p in ipairs(self.prints)do p.surface.Enabled=false end
	if self.ring then self.ring.surface.Enabled=false end
	if self.chip then self.chip.Visible=false end
	if self.steps then self.steps:hide()end
end
-- Why this trail ends now (Trail.endsFor with its own switch): "hide" only for a glow trail.
function Trail:ends(age,ctx)return Trail.endsFor(age,ctx,self.glow==true)end
-- ctx: {player (feet Vector3), pet (ground Vector3), visible (the garden is free to show it), camera, viewport
-- (Vector2), reducedMotion, ground (function(x, z, lineY) -> hit table or nil)}. Returns false once fully gone.
function Trail:step(now,ctx)
	if not self.active then return false end
	if self.glow then return self:stepGlow(now,ctx)end
	if self.leaving then
		local age=now-self.leaving
		for i=1,self.count do
			local p=self.prints[i]
			local gone=Trail.fade(age,i,self.count)
			for _,ink in ipairs(p.inks)do ink.BackgroundTransparency=Trail.See+(1-Trail.See)*gone end
		end
		if age>=Trail.FadeTime then self.active=false;self:hideAll();return false end
		return true
	end
	if not ctx.visible or not ctx.player or not ctx.pet then self:hideAll();self.drawn=nil;return true end
	local t=now-self.startedAt
	if Trail.moved(self.drawn,ctx.player,ctx.pet)then
		self.drawn={player=ctx.player,pet=ctx.pet}
		local list=Trail.prints(ctx.player,ctx.pet)
		local heading=Trail.heading(ctx.player,ctx.pet)
		local count=0
		for _,print in ipairs(list)do
			local hit=ctx.ground and ctx.ground(print.position.X,print.position.Z,print.lineY)
			if hit then
				count+=1
				local slot=self.prints[count]
				local at=hit.position+Vector3.new(0,.03,0)
				slot.part.CFrame=Trail.frame(at,heading,hit.normal)*CFrame.Angles(0,Trail.TopFaceYaw,0)
				slot.index=print.index
				for _,ink in ipairs(slot.inks)do ink.BackgroundTransparency=Trail.See end
			end
		end
		for i=1,Trail.Max do self.prints[i].surface.Enabled=i<=count end
		self.count=count
		local ring=self.ring
		ring.part.CFrame=CFrame.new(ctx.pet+Vector3.new(0,.06,0))
	end
	for i=1,self.count do
		local slot=self.prints[i]
		slot.surface.Enabled=true
		slot.scale.Scale=Trail.swell(t,slot.index or i,ctx.reducedMotion)
	end
	local ring=self.ring
	ring.surface.Enabled=true
	local u=(t%Trail.RippleEvery)/Trail.RippleEvery
	local base=Trail.RingRadius*2/ring.span
	if ctx.reducedMotion then ring.rippleStroke.Transparency=1
	else ring.ripple.Size=UDim2.fromScale(base*(1+u*.12),base*(1+u*.12));ring.rippleStroke.Transparency=.2+.8*u end
	if self.chip and ctx.camera and ctx.viewport then
		local point=ctx.camera:WorldToViewportPoint(ctx.pet+Vector3.new(0,1,0))
		local edge=Trail.edge(ctx.viewport,point)
		self.chip.Visible=edge~=nil
		if edge then
			self.chip.Position=UDim2.fromOffset(edge.x,edge.y)
			local a=math.rad(edge.angle);local r=Trail.Chip/2
			self.pointer.Position=UDim2.fromOffset(r+math.cos(a)*r,r+math.sin(a)*r)
		end
	end
	return true
end
-- Glow steps: the same draw (where, when it redraws, the chip's place) through GlowSteps, the wave and the pulse.
function Trail:stepGlow(now,ctx)
	local steps=self.steps
	if self.leaving then
		local age=now-self.leaving
		for i=1,self.count do steps:fade(i,Trail.fade(age,i,self.count))end
		if age>=Trail.FadeTime then self.active=false;self:hideAll();return false end
		return true
	end
	if not ctx.visible or not ctx.player or not ctx.pet then self:hideAll();self.drawn=nil;return true end
	local t=now-self.startedAt
	if Trail.moved(self.drawn,ctx.player,ctx.pet)then
		self.drawn={player=ctx.player,pet=ctx.pet}
		local list=Trail.prints(ctx.player,ctx.pet)
		local heading=Trail.heading(ctx.player,ctx.pet)
		local count=0
		for _,print in ipairs(list)do
			local hit=ctx.ground and ctx.ground(print.position.X,print.position.Z,print.lineY)
			if hit then
				count+=1
				steps:place(count,Trail.frame(hit.position+Vector3.new(0,.03,0),heading,hit.normal)*CFrame.Angles(0,Trail.TopFaceYaw,0))
			end
		end
		steps:show(count)
		self.count=count
		steps:target(ctx.pet)
	end
	local count=steps:animate(t,ctx.reducedMotion==true,ctx.camera)
	if self.chip and ctx.camera and ctx.viewport then
		local point=ctx.camera:WorldToViewportPoint(ctx.pet+Vector3.new(0,1,0))
		local edge=Trail.edge(ctx.viewport,point)
		self.chip.Visible=edge~=nil
		if edge then
			self.chip.Position=UDim2.fromOffset(edge.x,edge.y)
			local a=math.rad(edge.angle);local r=Trail.Chip/2
			self.pointer.Position=UDim2.fromOffset(r+math.cos(a)*r,r+math.sin(a)*r)
			if self.chipScale then self.chipScale.Scale=steps.Glow.chip(t,count,ctx.reducedMotion==true)end
		end
	end
	return true
end
function Trail:destroy()
	self.active=false
	if self.folder then self.folder:Destroy();self.folder=nil end
	if self.steps then self.steps:destroy();self.steps=nil end
	if self.glowFolder then self.glowFolder:Destroy();self.glowFolder=nil end
	if self.chip then self.chip:Destroy();self.chip=nil end
	self.prints={};self.ring=nil
end
return Trail
