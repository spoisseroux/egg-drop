-- Glow steps, the view (ONBOARDING-V3-BRIEF section 2, switch Onboard "trail2"; the rules are Shared.TrailGlow). One
-- pool of glowing paw prints for a trail (PetTrail and ThingsTrail each own one while the switch is on), the gold target
-- ring, and the "when a pet leads" prints with their pop, `pat` tick and gold sparkles. Client only, pooled local parts
-- that nothing can touch, stand on or query; built on first use. Per frame it writes only the prints whose swell or
-- ripple is running (a third of them at a time), the Reduced Motion breath a few times a second, and nothing for prints
-- far from the camera.
--   steps = GlowSteps.new({parent, play(name, speed, gain)})
--   steps:place(i, cframe) / steps:show(count)        the route prints, 1 = nearest the player
--   steps:target(position or nil)                     the gold ring
--   steps:animate(t, reduced, camera)                 the wave, the ring's ripple
--   steps:fade(i, gone)                               0 as drawn .. 1 gone (a trail's own fade in or out)
--   steps:leadStep(now, petFeet, playerFeet, reduced, ground) the pet's own prints (Glow.lead), instead of the route's
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Glow=require(Shared:WaitForChild("TrailGlow"))
local Steps={};Steps.__index=Steps
Steps.Glow=Glow

local function still(part)
	part.Anchored,part.CanCollide,part.CanTouch,part.CanQuery,part.CastShadow=true,false,false,false,false
	part.Massless=true
end
local function round(frame)
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(.5,0);corner.Parent=frame
end
local function circle(parent,name,scale,thickness,see)
	local frame=Instance.new("Frame");frame.Name=name;frame.AnchorPoint=Vector2.new(.5,.5);frame.Position=UDim2.fromScale(.5,.5)
	frame.Size=UDim2.fromScale(scale,scale);frame.BackgroundTransparency=1;frame.BorderSizePixel=0;round(frame)
	local stroke=Instance.new("UIStroke");stroke.Color,stroke.Thickness,stroke.Transparency=Glow.Gold,thickness,see;stroke.Parent=frame
	local grow=Instance.new("UIScale");grow.Parent=frame
	frame.Parent=parent
	return frame,stroke,grow
end

function Steps.new(options)
	return setmetatable({o=options or {},route={},leads={},count=0,leading=false},Steps)
end
function Steps:folder()
	if self.box then return self.box end
	local box=Instance.new("Folder");box.Name="GlowSteps"
	box.Parent=self.o.parent or workspace
	self.box=box
	return box
end
-- One print: a flat part spanning the ripple at its widest, a SurfaceGui on its top (LightInfluence 0), the gold ring
-- and its ripple, and the cream paw (DeckKit's vector paw) under a UIScale.
local PixelsPerStud=40
function Steps:print(name)
	local span=Glow.Size*Glow.Canvas
	local part=Instance.new("Part");part.Name=name;part.Size=Vector3.new(span,.05,span);part.Transparency=1
	part.Material=Enum.Material.SmoothPlastic;still(part)
	local surface=Instance.new("SurfaceGui")
	surface.Face,surface.LightInfluence,surface.AlwaysOnTop=Enum.NormalId.Top,Glow.LightInfluence,false
	surface.SizingMode,surface.PixelsPerStud=Enum.SurfaceGuiSizingMode.PixelsPerStud,PixelsPerStud
	surface.Enabled=false;surface.Parent=part
	local px=span*PixelsPerStud
	local haloScale=Glow.Halo/Glow.Canvas
	local halo,haloStroke=circle(surface,"Halo",haloScale,math.max(2,Glow.HaloThickness*Glow.Size*PixelsPerStud),Glow.HaloSee)
	local ripple,rippleStroke,rippleGrow=circle(surface,"Ripple",haloScale,math.max(2,Glow.HaloThickness*Glow.Size*PixelsPerStud*.8),1)
	-- The paw over its ring (the icon's inks take the holder's ZIndex).
	local holder=Instance.new("Frame");holder.Name="Paw";holder.BackgroundTransparency=1;holder.BorderSizePixel=0;holder.ZIndex=2
	holder.AnchorPoint=Vector2.new(.5,.5);holder.Position=UDim2.fromScale(.5,.5);holder.Size=UDim2.fromScale(1/Glow.Canvas,1/Glow.Canvas);holder.Parent=surface
	local scale=Instance.new("UIScale");scale.Parent=holder
	local ok,Kit=pcall(require,script.Parent.DeckKit)
	if ok and type(Kit)=="table"and Kit.VectorIcons and Kit.VectorIcons.paw then Kit.VectorIcons.paw(holder,px/Glow.Canvas,6)end
	local inks={}
	for _,d in ipairs(holder:GetDescendants())do
		if d:IsA("GuiObject")and d:GetAttribute("IconInk")then d.BackgroundColor3=Glow.Core;d.BackgroundTransparency=Glow.See;table.insert(inks,d)end
	end
	part.Parent=self:folder()
	return{part=part,surface=surface,scale=scale,inks=inks,halo=halo,haloStroke=haloStroke,ripple=ripple,rippleStroke=rippleStroke,
		rippleGrow=rippleGrow,see=Glow.See,size=1,fadeBy=0,resting=true,at=Vector3.zero}
end
local function paint(slot,scale,see,rippleScale,rippleSee)
	if slot.size~=scale then slot.size=scale;slot.scale.Scale=scale end
	slot.base,slot.rippleBase,slot.rippleScaleBase=see,rippleSee,rippleScale
	-- A fade (in or out) lifts every part of the print together.
	local fade=slot.fadeBy
	if fade>0 then see=see+(1-see)*fade;rippleSee=rippleSee+(1-rippleSee)*fade end
	if slot.see~=see then
		slot.see=see
		for _,ink in ipairs(slot.inks)do ink.BackgroundTransparency=see end
		slot.haloStroke.Transparency=Glow.HaloSee+(1-Glow.HaloSee)*math.clamp((see-Glow.See)/(1-Glow.See),0,1)
	end
	if slot.rippleSee~=rippleSee then slot.rippleSee=rippleSee;slot.rippleStroke.Transparency=rippleSee end
	if rippleSee<1 then slot.rippleGrow.Scale=rippleScale/Glow.Halo end
end
local function slotAt(list,i,make)
	local slot=list[i]
	if not slot then slot=make();list[i]=slot end
	return slot
end
-- The route prints -------------------------------------------------------------------------------------------------
function Steps:place(i,frame)
	local slot=slotAt(self.route,i,function()return self:print("GlowPrint"..i)end)
	slot.part.CFrame=frame
	slot.at=frame.Position
	slot.index=i
	if slot.fadeBy~=0 then slot.fadeBy=0;paint(slot,slot.size,slot.base or Glow.See,slot.rippleScaleBase or Glow.Halo,slot.rippleBase or 1)end
	return slot
end
function Steps:show(count)
	self.count=count
	for i,slot in ipairs(self.route)do slot.surface.Enabled=i<=count and not self.leading end
end
function Steps:fade(i,gone)
	local slot=self.route[i]
	if not slot or slot.fadeBy==gone then return end
	slot.fadeBy=gone
	paint(slot,slot.size,slot.base or Glow.See,slot.rippleScaleBase or Glow.Halo,slot.rippleBase or 1)
end
-- The target ring ------------------------------------------------------------------------------------------------
function Steps:target(position)
	if position==nil then
		if self.ring then self.ring.surface.Enabled=false end
		return
	end
	if not self.ring then
		local span=(Glow.TargetRadius*2)*Glow.TargetRippleTo+1.2
		local part=Instance.new("Part");part.Name="GlowTarget";part.Size=Vector3.new(span,.05,span);part.Transparency=1
		part.Material=Enum.Material.SmoothPlastic;still(part)
		local surface=Instance.new("SurfaceGui")
		surface.Face,surface.LightInfluence,surface.AlwaysOnTop=Enum.NormalId.Top,Glow.LightInfluence,false
		surface.SizingMode,surface.PixelsPerStud=Enum.SurfaceGuiSizingMode.PixelsPerStud,40
		surface.Enabled=false;surface.Parent=part
		local base=Glow.TargetRadius*2/span
		local _,ringStroke=circle(surface,"Ring",base,Glow.TargetThickness,Glow.TargetSee)
		local _,rippleStroke,rippleGrow=circle(surface,"Ripple",base,Glow.TargetThickness*.7,1)
		part.Parent=self:folder()
		self.ring={part=part,surface=surface,ringStroke=ringStroke,rippleStroke=rippleStroke,rippleGrow=rippleGrow,see=1}
	end
	if self.ring.at~=position then self.ring.at=position;self.ring.part.CFrame=CFrame.new(position+Vector3.new(0,.06,0))end
	self.ring.surface.Enabled=true
end
-- The wave (route prints and the ring) ------------------------------------------------------------------------------
function Steps:animate(t,reduced,camera)
	local eye=camera and camera.CFrame and camera.CFrame.Position
	local breath=nil
	if reduced then
		local b=Glow.breathe(t)
		breath=math.floor(b/Glow.BreatheStep+.5)*Glow.BreatheStep
	end
	local count=if self.leading then self.leadCount or 0 else self.count
	if not self.leading then
		for i=1,self.count do
			local slot=self.route[i]
			if eye and(slot.at-eye).Magnitude>Glow.AnimateWithin then
				if not slot.resting then slot.resting=true;paint(slot,1,Glow.See,Glow.Halo,1)end
			elseif breath then
				slot.resting=false
				paint(slot,1,breath,Glow.Halo,1)
			elseif Glow.moving(t,i,false)then
				slot.resting=false
				paint(slot,Glow.wave(t,i,false))
			elseif not slot.resting then
				slot.resting=true
				paint(slot,1,Glow.See,Glow.Halo,1)
			end
		end
	end
	local ring=self.ring
	if ring and ring.surface.Enabled then
		local scale,see=Glow.target(t,count,reduced)
		if ring.see~=see then ring.see=see;ring.rippleStroke.Transparency=see end
		if see<1 then ring.rippleGrow.Scale=scale end
	end
	return count
end
-- When a pet leads -------------------------------------------------------------------------------------------------
-- The sparkles: one emitter, moved to the print and emitted (no part per pop).
function Steps:sparkle(at)
	if not self.spark then
		local part=Instance.new("Part");part.Name="GlowSparkle";part.Size=Vector3.new(.2,.2,.2);part.Transparency=1;still(part)
		local attachment=Instance.new("Attachment");attachment.Parent=part
		local emitter=Instance.new("ParticleEmitter");emitter.Name="Sparkles"
		emitter.Texture="rbxasset://textures/particles/sparkles_main.dds" -- the built-in spark (StationAttract, FindsClient)
		emitter.Color=ColorSequence.new(Glow.SparkleColor);emitter.LightEmission=1;emitter.LightInfluence=0
		emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.35),NumberSequenceKeypoint.new(1,0)})
		emitter.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)})
		emitter.Lifetime=NumberRange.new(.35,.55);emitter.Speed=NumberRange.new(2,3.5);emitter.SpreadAngle=Vector2.new(35,35)
		emitter.Acceleration=Vector3.new(0,-4,0);emitter.Rate=0;emitter.Enabled=false;emitter.Parent=attachment
		part.Parent=self:folder()
		self.spark={part=part,emitter=emitter}
	end
	self.spark.part.CFrame=CFrame.new(at+Vector3.new(0,.2,0))
	self.spark.emitter:Emit(Glow.Sparkles)
end
-- Start (or end, with on false) the pet's own prints. The route prints hide while it leads and come back after.
function Steps:lead(on)
	on=on==true
	if on==self.leading then return end
	self.leading=on
	if not self.leadState then self.leadState=Glow.lead(Glow.LeadMax)end
	self.leadState:clear()
	for _,slot in ipairs(self.leads)do slot.surface.Enabled=false end
	self:show(self.count)
end
function Steps:hold(on)if self.leadState then self.leadState:hold(on)end end
-- petFeet / playerFeet: ground points (Vector3) or nil. ground(position) -> y or nil (where a print lies).
function Steps:leadStep(now,pet,player,reduced,ground)
	if not self.leading then return 0 end
	local state=self.leadState
	state:step(now,pet,player)
	local laid=state.laid
	if laid>0 then
		local data=state.slots[laid]
		local slot=slotAt(self.leads,laid,function()return self:print("LeadPrint"..laid)end)
		local y=data.y
		local at=Vector3.new(data.x,y,data.z)
		-- The pet's pivot stands over its feet: the ground under it, up to Glow.FeetDrop below (never a roof above).
		local g=ground and ground(at)
		if g and g<=y+1 and g>=y-Glow.FeetDrop then y=g end
		slot.at=Vector3.new(data.x,y+.04,data.z)
		slot.part.CFrame=CFrame.new(slot.at)*CFrame.Angles(0,data.yaw+Glow.TopFaceYaw,0)
		slot.fadeBy,slot.resting=0,false
		paint(slot,Glow.popIn(0,reduced),Glow.See,Glow.Halo,1)
		slot.surface.Enabled=true
		if state.pat and self.o.play then
			local cue=Glow.PatCue
			pcall(self.o.play,cue.name,cue.speed,cue.gain)
		end
	end
	for _,i in ipairs(state.popped)do
		local slot=self.leads[i]
		if slot and not reduced then self:sparkle(slot.at)end
	end
	-- Each live print: its pop in, then the wave (oldest first, so it runs from the player toward the pet); popping ones.
	local oldest=state:oldest()
	local live=0
	local breath=reduced and math.floor(Glow.breathe(now)/Glow.BreatheStep+.5)*Glow.BreatheStep or nil
	for i,data in ipairs(state.slots)do
		local slot=self.leads[i]
		if slot then
			if not data.on then
				if slot.surface.Enabled then slot.surface.Enabled=false end
			elseif data.gone~=nil then
				local scale,see=Glow.popAway(now-data.gone,reduced)
				slot.resting=false
				paint(slot,scale,see,Glow.Halo,1)
			else
				live+=1
				local age=now-data.born
				local index=data.seq-oldest+1
				if age<Glow.PopIn and not reduced then
					slot.resting=false
					paint(slot,Glow.popIn(age,false),Glow.See,Glow.Halo,1)
				elseif breath then
					paint(slot,1,breath,Glow.Halo,1)
				elseif Glow.moving(now,index,false)then
					slot.resting=false
					paint(slot,Glow.wave(now,index,false))
				elseif not slot.resting then
					slot.resting=true
					paint(slot,1,Glow.See,Glow.Halo,1)
				end
			end
		end
	end
	self.leadCount=live
	return live
end
function Steps:hide()
	for _,slot in ipairs(self.route)do slot.surface.Enabled=false end
	for _,slot in ipairs(self.leads)do slot.surface.Enabled=false end
	if self.ring then self.ring.surface.Enabled=false end
end
function Steps:destroy()
	if self.box then self.box:Destroy();self.box=nil end
	self.route,self.leads,self.ring,self.spark,self.leadState={},{},nil,nil,nil
	self.leading,self.count=false,0
end
return Steps
