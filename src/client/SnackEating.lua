-- v2 Stat Snacks: the eating sequence on a pet (V2-FEEDING-RUNES-ONBOARDING 3.1 and 3.2). Works on
-- any pet visual with `pieces` and `update` (the garden pet, another player's pet, the stats
-- panel's preview), the PetFruitEating way: each frame the owner's update poses the pet, then
-- step() re-poses it at zero dt and moves the head, eyes and body on top.
--
-- offer(): the client-only part before the server answers (the snack at the cheek, a sniff).
-- eat(): only after a server receipt (or another player's public beat): bites with crumbs, a
-- gulp, a happy wiggle (a spin on a Feast) and a burst of the stat's icons.
-- refuse(): the server said no: a head tilt, "hm?", the snack goes away.
-- Reduced Motion: one bite, the gulp, no wiggle or burst (the line and sound still show it).
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage").Shared
local K=require(Shared.StatEggCatalog)
local Stats=require(Shared.StatCatalog)
local SnackModel=require(script.Parent.SnackModel)
local Eating={}
Eating.__index=Eating
-- Bite times from the receipt (3.2), the reaction and the whole length.
Eating.Timeline=table.freeze({
	nibble=table.freeze({bites={.6,.9},stones=5,happy={"snack_happy_squeak"},spin=false,length=2.4}),
	snack=table.freeze({bites={.6,.9,1.2},stones=8,happy={"snack_happy_coo"},spin=false,length=3.0}),
	feast=table.freeze({bites={.6,1.1,1.4,1.7},stones=12,happy={"snack_happy_coo","snack_happy_squeak"},spin=true,length=4.0}),
})
Eating.Reduced=table.freeze({bites={.2},length=.9})
-- The Pocket Buddies burst sheet (assets/ui/stat-icons/levelup-burst-8x128.json): 8 frames of 128 px, 16 fps.
Eating.Burst="rbxassetid://98905350966594"
Eating.BurstFrames=8
Eating.BurstFps=16
Eating.Atlas=SnackModel.Atlas
Eating.Icon=SnackModel.Icon
Eating.Noms={"snack_nom_a","snack_nom_b","snack_nom_c"}

local function smooth(x)x=math.clamp(x,0,1);return 1-(1-x)^3 end
local function anchor(visual,name)
	for _,entry in ipairs(visual.pieces or {})do if entry.name==name then return entry.part end end
end
local function restore(visual)
	for _,entry in ipairs(visual.pieces)do entry.lastFrame=nil;entry.lastSize=nil;entry.lastTransparency=nil end
	visual.poseDirty=true;visual:update(0)
end
local function headish(entry)
	local name,channel=entry.name or "",entry.channel
	return channel=="Head"or channel=="Face"or channel=="Charm"or name:find("Eye")or name:find("Glint")or name:find("Mouth")or name:find("Teeth")or name:find("Cheek")or name:find("Ear")
end

-- Pure: which nom plays for bite `index`, never the same twice in a row; the Feast's first
-- bite is the big crunch.
function Eating.nomFor(sizeId,index,previous)
	if sizeId=="feast"and index==1 then return "snack_crunch_feast"end
	local pick=Eating.Noms[((index-1)%#Eating.Noms)+1]
	if pick==previous then pick=Eating.Noms[(index%#Eating.Noms)+1]end
	return pick
end
-- Pure: the beats of one sequence: {t, kind, cue?, index?} sorted by time.
function Eating.beats(sizeId,reduced)
	local plan=if reduced then Eating.Reduced else(Eating.Timeline[sizeId]or Eating.Timeline.nibble)
	local beats,previous={},nil
	for index,t in ipairs(plan.bites)do
		local cue=Eating.nomFor(sizeId,index,previous);previous=cue
		table.insert(beats,{t=t,kind="bite",cue=cue,index=index})
	end
	local last=plan.bites[#plan.bites]
	table.insert(beats,{t=last+.3,kind="gulp",cue="snack_gulp"})
	if not reduced then
		local happyAt=last+.45
		for i,cue in ipairs(plan.happy)do table.insert(beats,{t=happyAt+(i-1)*.55,kind="happy",cue=cue})end
		table.insert(beats,{t=happyAt+(if plan.spin then 1.1 else .5),kind="burst",cue="snack_boost_sparkle"})
	end
	table.sort(beats,function(a,b)return a.t<b.t end)
	return beats,plan
end

-- audio: BoardAudio (play(cue, speed, volume)). options.gain: volume multiplier (other players' pets).
function Eating.new(audio,options)
	options=options or {}
	return setmetatable({audio=audio,gain=options.gain or 1,crumbs={}},Eating)
end
function Eating:play(cue)
	if not self.audio or not cue then return end
	local gain=(require(script.Parent.BoardAudio).SnackGain or {})[cue]or .6
	pcall(function()self.audio:play(cue,1,gain*self.gain)end)
end
function Eating:clearSnack()
	if self.snack then self.snack:Destroy();self.snack=nil end
end
function Eating:clearBurst()
	if self.burst then self.burst:Destroy();self.burst=nil end
end
function Eating:cancel()
	local visual=self.visual
	if visual and not visual.destroyed and visual.model and visual.model.Parent then pcall(restore,visual)end
	self:clearSnack();self:clearBurst()
	for _,crumb in ipairs(self.crumbs)do crumb.part:Destroy()end
	table.clear(self.crumbs)
	self.visual,self.phase,self.info=nil,nil,nil
	if self.onDone then local done=self.onDone;self.onDone=nil;done(false)end
end
function Eating:busy()return self.phase~=nil end

local function prepare(self,visual,info)
	if not visual or visual.destroyed or not visual.model or not visual.model.Parent then return false end
	local head=anchor(visual,"Head")
	if not head then return false end
	self.visual,self.info,self.rigRevision=visual,info,visual.rigRevision
	self.headSize=head.Size.X
	self.age=0
	return true
end
local function makeSnack(self)
	self:clearSnack()
	local info=self.info
	local size=K.size(info.size)or K.Sizes.nibble
	-- Scaled to the head so it reads beside the pet (Nibble 30%, Feast 42% of the head).
	local width=self.headSize*(.22+.06*size.layers)
	local model=SnackModel.build(size.id,info.stat,width)
	model.Parent=self.visual.model.Parent
	self.snack,self.snackLayers,self.snackScale=model,size.layers,1
end
-- Where the snack sits: beside the cheek (t=0) to the mouth (t=1).
local function snackFrame(self,toMouth,bob)
	local visual=self.visual
	local head=anchor(visual,"Head");local mouth=anchor(visual,"MouthSmile")or anchor(visual,"MouthO")or head
	local hc=head.CFrame
	local cheek=hc.Position+hc.RightVector*self.headSize*.62+hc.LookVector*self.headSize*.35-hc.UpVector*self.headSize*.05
	local lips=mouth.Position+hc.LookVector*self.headSize*.18
	local at=cheek:Lerp(lips,smooth(toMouth))+Vector3.new(0,bob or 0,0)
	return CFrame.lookAt(at,at+hc.LookVector)*CFrame.Angles(math.rad(-55),0,0)
end

-- The offer, before the server answers. It can stop at any moment (cancel / refuse / eat).
function Eating:offer(visual,info,options)
	self:cancel()
	if not prepare(self,visual,info)then return false end
	self.phase="offer";self.reduced=options and options.reduced==true
	makeSnack(self)
	self:play("snack_sniff")
	self:step(0)
	return true
end
function Eating:refuse()
	if self.phase~="offer"or not self.visual then self:cancel();return end
	self.phase="refuse";self.age=0
	self:play("snack_refuse_hm")
end
-- info: {stat, size, favourite}. options: {reduced, overlay (a GuiObject: draw the burst there,
-- for a ViewportFrame pet), onDone(completed)}.
function Eating:eat(visual,info,options)
	options=options or {}
	local continuing=self.phase=="offer"and self.visual==visual and self.info and self.info.stat==info.stat and self.info.size==info.size
	if not continuing then
		self:cancel()
		if not prepare(self,visual,info)then return false end
		makeSnack(self)
	end
	self.phase="eat";self.age=0;self.reduced=options.reduced==true;self.overlay=options.overlay;self.onDone=options.onDone
	self.beats,self.plan=Eating.beats(info.size,self.reduced)
	self.nextBeat=1;self.biteAt=nil;self.happyAt=nil;self.burstAt=nil
	self:step(0)
	return true
end

local function spawnCrumbs(self,color)
	local snack=self.snack;if not snack or not snack.PrimaryPart then return end
	local origin=snack:GetPivot().Position
	for i=1,5 do
		local crumb=Instance.new("Part");crumb.Name="SnackCrumb";crumb.Shape=Enum.PartType.Ball
		crumb.Size=Vector3.one*self.headSize*(.04+.02*(i%2));crumb.Color=if i%2==0 then color else SnackModel.Biscuit
		crumb.Material=Enum.Material.SmoothPlastic;crumb.Anchored=true;crumb.CanCollide=false;crumb.CanTouch=false;crumb.CanQuery=false;crumb.CastShadow=false
		crumb.CFrame=CFrame.new(origin);crumb.Parent=self.visual.model.Parent
		local a=math.random()*math.pi*2
		table.insert(self.crumbs,{part=crumb,v=Vector3.new(math.cos(a),1.2+math.random(),math.sin(a))*self.headSize*1.4,age=0})
	end
end
local function biteSnack(self,index,count)
	local snack=self.snack;if not snack then return end
	local left=1-index/count
	if left<=0 then self:clearSnack();return end
	local keep=math.max(1,math.ceil(self.snackLayers*left))
	for _,part in ipairs(snack:GetDescendants())do
		if part:IsA("BasePart")then
			local layer=part:GetAttribute("SnackLayer")
			if layer and layer>keep then part.Transparency=1 end
		elseif part:IsA("Decal")and part.Parent and part.Parent:IsA("BasePart")then
			-- The topper's icon: a decal still draws on a hidden part, so it follows its plate.
			part.Transparency=part.Parent.Transparency
		end
	end
	local scale=.62+.38*left
	pcall(function()snack:ScaleTo(scale)end)
end

-- The 2D or world burst: the 8-frame sheet plus a ring of the stat's icons.
local function startBurst(self)
	self:clearBurst()
	local info,visual=self.info,self.visual
	local head=anchor(visual,"Head");if not head then return end
	local holder
	if self.overlay then
		holder=Instance.new("Frame");holder.Name="SnackBurst";holder.BackgroundTransparency=1;holder.AnchorPoint=Vector2.new(.5,.5)
		holder.Position=UDim2.fromScale(.5,.42);holder.Size=UDim2.fromScale(.9,.9);holder.ZIndex=self.overlay.ZIndex+6
		local ratio=Instance.new("UIAspectRatioConstraint");ratio.Parent=holder
		holder.Parent=self.overlay
		self.burst=holder
	else
		local board=Instance.new("BillboardGui");board.Name="SnackBurst";board.Adornee=head;board.AlwaysOnTop=true;board.LightInfluence=0
		board.Size=UDim2.new(self.headSize*4.2,0,self.headSize*4.2,0);board.ResetOnSpawn=false
		board.Parent=Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")or head
		holder=Instance.new("Frame");holder.BackgroundTransparency=1;holder.Size=UDim2.fromScale(1,1);holder.Parent=board
		self.burst=board
	end
	local z=holder.ZIndex
	local sheet=Instance.new("ImageLabel");sheet.Name="Sheet";sheet.BackgroundTransparency=1;sheet.Image=Eating.Burst
	sheet.ImageRectSize=Vector2.new(128,128);sheet.ImageRectOffset=Vector2.zero
	sheet.AnchorPoint=Vector2.new(.5,.5);sheet.Position=UDim2.fromScale(.5,.5);sheet.Size=UDim2.fromScale(.7,.7);sheet.ZIndex=z+1;sheet.Parent=holder
	local flash=Instance.new("Frame");flash.Name="Flash";flash.AnchorPoint=Vector2.new(.5,.5);flash.Position=UDim2.fromScale(.5,.5)
	flash.Size=UDim2.fromScale(.5,.5);flash.BackgroundColor3=(Stats.ById[info.stat]or Stats.ById.heart).color;flash.BackgroundTransparency=.4;flash.ZIndex=z
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(1,0);corner.Parent=flash;flash.Parent=holder
	self.burstStones={}
	local count=(Eating.Timeline[info.size]or Eating.Timeline.nibble).stones
	for i=1,count do
		local stone=Instance.new("ImageLabel");stone.Name="Stone";stone.BackgroundTransparency=1;stone.Image=Eating.Atlas
		stone.ImageRectOffset=Eating.Icon[info.stat]or Vector2.zero;stone.ImageRectSize=Vector2.new(64,64)
		stone.AnchorPoint=Vector2.new(.5,.5);stone.Size=UDim2.fromScale(.16,.16);stone.ZIndex=z+2;stone.Parent=holder
		local ring=if count>8 and i>count/2 then 2 else 1
		table.insert(self.burstStones,{image=stone,angle=(i-1)/math.max(1,if ring==2 then count/2 else math.min(count,8))*math.pi*2+(ring-1)*.4,ring=ring})
	end
	self.burstSheet,self.burstFlash=sheet,flash
	self.burstAt=self.age
end
local function stepBurst(self)
	if not self.burst or not self.burstAt then return end
	local t=self.age-self.burstAt
	local frame=math.min(Eating.BurstFrames-1,math.floor(t*Eating.BurstFps))
	self.burstSheet.ImageRectOffset=Vector2.new(frame*128,0)
	self.burstSheet.ImageTransparency=math.clamp((t-.4)/.2,0,1)
	self.burstFlash.BackgroundTransparency=.4+.6*math.clamp(t/.35,0,1)
	self.burstFlash.Size=UDim2.fromScale(.5+t*.8,.5+t*.8)
	for _,s in ipairs(self.burstStones)do
		local r=(.12+.3*smooth(t/.45))*(if s.ring==2 then .7 else 1)
		local a=s.angle+math.rad(90)*smooth(t/.6)
		s.image.Position=UDim2.fromScale(.5+math.cos(a)*r,.5+math.sin(a)*r)
		s.image.Rotation=math.deg(a)
		s.image.ImageTransparency=math.clamp((t-.45)/.25,0,1)
	end
	if t>.75 then self:clearBurst()end
end

local function finish(self,completed)
	local done=self.onDone;self.onDone=nil
	local visual=self.visual
	if visual and not visual.destroyed and visual.model and visual.model.Parent then pcall(restore,visual)end
	self:clearSnack();self:clearBurst()
	self.visual,self.phase,self.info=nil,nil,nil
	if done then done(completed)end
end

function Eating:step(dt)
	-- Crumbs fall on their own, even after the pet is done.
	for i=#self.crumbs,1,-1 do
		local c=self.crumbs[i];c.age+=dt
		c.v+=Vector3.new(0,-9*self.headSize,0)*dt
		if c.part.Parent then c.part.CFrame=c.part.CFrame+c.v*dt;c.part.Transparency=math.clamp((c.age-.35)/.3,0,1)end
		if c.age>.7 then c.part:Destroy();table.remove(self.crumbs,i)end
	end
	if not self.phase then return false end
	local visual=self.visual
	if not visual or visual.destroyed or not visual.model or not visual.model.Parent or visual.rigRevision~=self.rigRevision or not anchor(visual,"Head")then
		-- The model rebuilt (a hat changed): stop cleanly. The boost is already saved.
		finish(self,false);return false
	end
	self.age+=math.max(0,dt)
	local t=self.age
	local nod,tilt,roll,yaw,closeEyes,toMouth,bob=0,0,0,0,false,0,0
	if self.phase=="offer"then
		-- Lean toward the snack, nose twitches; it waits at the cheek with a tiny bounce.
		tilt=math.rad(8)*smooth(t/.3)+math.rad(2)*math.sin(t*22)*math.clamp(1-t/.6,0,1)
		toMouth=.25*smooth(t/.4);bob=self.headSize*.02*math.sin(t*9)
	elseif self.phase=="refuse"then
		tilt=math.rad(14)*math.sin(math.min(1,t/.5)*math.pi)
		toMouth=0
		if self.snack then
			local fade=math.clamp(t/.25,0,1)
			for _,part in ipairs(self.snack:GetDescendants())do
				if part:IsA("BasePart")then part.Transparency=math.max(part.Transparency,fade)
				elseif part:IsA("Decal")then part.Transparency=math.max(part.Transparency,fade)end
			end
		end
		if t>.6 then finish(self,false);return false end
	else
		-- Beats: sounds, bites, the burst.
		while self.beats[self.nextBeat]and t>=self.beats[self.nextBeat].t do
			local beat=self.beats[self.nextBeat];self.nextBeat+=1
			self:play(beat.cue)
			if beat.kind=="bite"then
				self.biteAt=beat.t
				spawnCrumbs(self,(Stats.ById[self.info.stat]or Stats.ById.heart).color)
				biteSnack(self,beat.index,#self.plan.bites)
			elseif beat.kind=="gulp"then self:clearSnack()
			elseif beat.kind=="happy"then self.happyAt=self.happyAt or beat.t
			elseif beat.kind=="burst"then startBurst(self)end
		end
		local first=self.plan.bites[1]
		toMouth=if self.reduced then 1 else smooth(t/first)
		if self.biteAt then
			local b=t-self.biteAt
			if b<.22 then nod=math.rad(9)*math.sin(b/.22*math.pi);closeEyes=true end
		end
		local gulp=self.plan.bites[#self.plan.bites]+.3
		if t>=gulp and t<gulp+.18 then nod=-math.rad(6)*math.sin((t-gulp)/.18*math.pi)end
		if self.happyAt and not self.reduced then
			local h=t-self.happyAt
			if h<.5 then roll=math.rad(9)*math.sin(h/.5*math.pi*3);closeEyes=true end
			if self.plan.spin and h>=.5 and h<1.1 then yaw=math.pi*2*smooth((h-.5)/.6)end
		end
		stepBurst(self)
		if t>=self.plan.length then finish(self,true);return false end
	end
	-- Pose: the owner already posed this frame; re-pose at zero dt, then layer ours on top.
	restore(visual)
	local body=visual.model.PrimaryPart or anchor(visual,"Body")
	local head=anchor(visual,"Head")
	if body and(roll~=0 or yaw~=0)then
		local pivot=body.Position
		local turn=CFrame.new(pivot)*CFrame.fromAxisAngle(body.CFrame.UpVector,yaw)*CFrame.fromAxisAngle(body.CFrame.LookVector,roll)*CFrame.new(-pivot)
		for _,entry in ipairs(visual.pieces)do entry.part.CFrame=turn*entry.part.CFrame end
	end
	if head and(nod~=0 or tilt~=0)then
		local pivot=head.Position
		local turn=CFrame.new(pivot)*CFrame.fromAxisAngle(head.CFrame.RightVector,nod)*CFrame.fromAxisAngle(head.CFrame.LookVector,tilt)*CFrame.new(-pivot)
		for _,entry in ipairs(visual.pieces)do if headish(entry)then entry.part.CFrame=turn*entry.part.CFrame end end
	end
	if closeEyes then
		for _,entry in ipairs(visual.pieces)do
			local name=entry.name or ""
			if name:find("Eye")and not name:find("Brow")then local s=entry.part.Size;entry.part.Size=Vector3.new(s.X,math.max(.001,s.Y*.15),s.Z)end
			if name:find("Glint")then entry.part.Transparency=1 end
		end
	end
	if self.snack and self.snack.Parent then
		self.snack:PivotTo(snackFrame(self,toMouth,bob))
	end
	return true
end
function Eating:destroy()self:cancel()end
return Eating
