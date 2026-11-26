-- Onboarding v2 steps 2, 3 and 4 (Onboard "stork"; ONBOARDING-V2.md; Spencer: "the animation of the bear being dropped
-- by a stork, in front of us after, and then we open like a petting screen for the egg and tap it 3 times to hatch it,
-- and then we get the bear smash screen").
--   2  the deck tucks away; a stork glides in, lowers a knotted blanket to the ground 6 studs in front of the player and
--      lets go: the blanket opens and the Companion Egg settles on it. "A delivery!" Skip (bottom right, B, Esc).
--   3  the camera comes close; "Tap the egg!": three taps crack it (CrackRitual, CrackFx at the egg's screen spot), the
--      top flies off with the pop and the Bear stands in the blanket. No countdown: the hand helps at 3 s, the tap
--      happens by itself at 7 s, mashing never skips the pop.
--   4  the Bear's card (RevealStage, its own entrance: the egg already cracked in the world) with one button, Meet
--      Bear. Movement comes back the moment it is pressed.
-- Trust: the Bear is granted and saved by the Welcome round (the server) before this starts. This plays the starter
-- receipt (nurseryState.lastHatch, starter, pip) in place of the Hatch eggs reveal and acks it on Meet, through the
-- same `ack` the reveal sends. Nothing else is written. A replay (Settings) plays steps 2 and 3 with a stand-in egg and
-- no receipt. Any error puts the receipt back on the old path (deps.fallback) so the player always meets the Bear.
-- deps (init.client): gui (PlayerGui), audio, copy(key, vars), inputKind(), reduced(), ready() (the garden is up and
-- free), toRoom(), character(), pet() (the garden pet visual), appearance(petId), receipt() (lastHatch), ack(id),
-- companion(), event(name), fallback(result), done(replay).
local ContextActionService=game:GetService("ContextActionService")
local GuiService=game:GetService("GuiService")
local Input=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local Pets=require(game:GetService("ReplicatedStorage").Shared.PetCatalog)
local V2=require(script.Parent.OnboardV2)
local Model=require(script.Parent.StorkModel)
local Story={};Story.__index=Story
Story.DisplayOrder=15;Story.Action="EggDropFirstHatchStory";Story.Priority=Enum.ContextActionPriority.High.Value+820
Story.LockReason="firstHatchStory";Story.RoomWait=10
local K=Enum.KeyCode
Story.Keys=table.freeze({K.Space,K.E,K.ButtonA,K.ButtonB,K.Escape,K.Backspace,K.Return,K.KeypadEnter,K.W,K.A,K.S,K.D,K.Q,
	K.Up,K.Down,K.Left,K.Right,K.ButtonX,K.ButtonY,K.ButtonL2,K.G})
-- The new synthesised sounds (scripts/synth_asmr.py): empty slots until uploaded (BoardAudio.StorkIds). Playing an
-- empty slot is quiet.
Story.Sounds=table.freeze({flap={"stork_flap_a","stork_flap_b","stork_flap_c"},clack="stork_clack",rustle="blanket_rustle"})

local function node(class,parent,props)
	local n=Instance.new(class)
	for k,v in pairs(props or {})do n[k]=v end
	n.Parent=parent;return n
end
local function flat(v)return Vector3.new(v.X,0,v.Z)end
local function unit(v,fallback)local m=v.Magnitude;return if m>1e-4 then v/m else fallback end
local function smooth(u)u=math.clamp(u,0,1);return u*u*(3-2*u)end

-- The top bar's notification rail waits under the story (PetArrivalHatch's pattern).
local holds,wrapped=0,false
local function holdRail(on)
	if not wrapped then
		wrapped=true
		local ok,Rail=pcall(require,script.Parent.NotificationRail)
		if ok and type(Rail)=="table"and type(Rail.held)=="function"then
			local base=Rail.held
			Rail.held=function()return holds>0 or base()end
		end
	end
	holds=math.max(0,holds+(if on then 1 else -1))
end

function Story.new(deps)
	local self=setmetatable({d=deps,state="idle",links={}},Story)
	return self
end
function Story:copy(key,vars)
	local ok,text=pcall(self.d.copy,key,vars)
	return if ok and type(text)=="string"then text else ""
end
function Story:reduced()return self.d.reduced and self.d.reduced()==true or GuiService.ReducedMotionEnabled end
function Story:play(name,speed,gain)if self.d.audio then pcall(function()self.d.audio:play(name,speed or 1,gain or .5)end)end end
function Story:layer(layer,gainScale)
	local ok,Asmr=pcall(require,script.Parent.HatchAsmr)
	if not ok then return end
	local l=Asmr.Layers[layer];if not l then return end
	self:play(l.cue.."_"..Asmr.pick(layer,math.random()),.97+.06*math.random(),l.gain*(gainScale or 1.3))
end
function Story:buzz(name)
	pcall(function()require(script.Parent.HatchAsmr).fire({haptic=name})end)
end
function Story:event(name)if not self.replaying and self.d.event then pcall(self.d.event,name)end end

-- ── What the game asks ───────────────────────────────────────────────────────────────────────────────────────────────
-- Is this the receipt the story plays (the starter Bear, the switch on, not given up this session)?
function Story:wants(result)
	return not self.disabled and type(result)=="table"and result.starter==true and result.petId=="pip"and V2.on("stork")
		and V2.mayClaim(self.gate or {})
end
-- The Welcome deck's hatch modal waits for the story (it never shows when the story plays). A grant whose receipt never
-- comes lets the modal back after Hold seconds.
-- Review B36: once the modal has been let back, a late receipt never starts the stork (V2.deckHold / V2.mayClaim).
Story.Hold=V2.Hold
function Story:holdsDeck(pet)
	self.gate=self.gate or {}
	if self.disabled or not V2.on("stork")then return false end
	return V2.deckHold(self.gate,pet==Pets[1],self.state~="idle"and not self.replaying,os.clock())
end
-- The receipt is the story's (Hatch eggs must not open it meanwhile).
-- (and after Meet, until the server has taken the ack)
function Story:ownsReceipt()return(self.state~="idle"and not self.replaying and self.result~=nil)or self.acking~=nil end
function Story:isRunning()return self.state~="idle"end
-- A starter receipt arrived (refreshNursery): true when the story takes it.
function Story:claim(result)
	if not self:wants(result)then return false end
	if self.result and self.result.id==result.id and self.state~="idle"then return true end
	if self.state~="idle"then self:cleanup()end
	self.result=result;self.replaying=false
	self:start()
	return true
end
-- Settings > Watch the first hatch again: steps 2 and 3 with a stand-in egg, no receipt, no rewards.
function Story:replay()
	if self.state~="idle"or self.disabled then return false end
	if not(self.d.ready and self.d.ready())then return false end
	self.result=nil;self.replaying=true
	self:start()
	return true
end

-- ── The run ──────────────────────────────────────────────────────────────────────────────────────────────────────────
function Story:start()
	self.state="tuck";self.clock=0;self.since=0
	self.startedAt=os.clock()
	if not self.link then
		self.link=RunService.RenderStepped:Connect(function(dt)
			local ok,problem=pcall(self.step,self,dt)
			if not ok then self:fail(problem)end
		end)
	end
end
function Story:fail(problem)
	warn("[Onboard] first hatch story: "..tostring(problem))
	local result=if self.replaying then nil else self.result
	self.disabled=true
	self:cleanup()
	if result and self.d.fallback then pcall(self.d.fallback,result)end
end
function Story:step(dt)
	dt=math.clamp(dt or 0,0,.1)
	self.clock+=dt;self.since+=dt
	if self.state=="tuck"then return self:stepTuck()end
	-- the garden Bear may be drawn again (a rig swap): keep it hidden while ours is on stage
	if self.folder then self:hidePet(true)end
	if self.state=="stork"then return self:stepStork(dt)end
	if self.state=="crack"then return self:stepCrack(dt)end
	if self.state=="card"then return self:stepCard(dt)end
end
function Story:enter(state)self.state=state;self.since=0 end

-- Step 1's tail: 0.4 s after combo 3 the deck tucks away (the deck's own close: it sinks under the shade), then the
-- garden. A rejoin with the receipt pending lands here too.
function Story:stepTuck()
	local d=self.d
	if d.mode and d.mode()~="Room"then
		if self.since>=V2.Deck.tuckAfter and not self.asked then self.asked=true;pcall(d.toRoom)end
		if self.since>Story.RoomWait then error("the garden never came")end
		return
	end
	if not(d.ready and d.ready())then
		if self.since>Story.RoomWait then error("the garden is not free")end
		return
	end
	self:begin()
end
function Story:begin()
	local d=self.d
	local character=d.character and d.character()
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local camera=workspace.CurrentCamera
	if not(root and camera)then error("no character or camera")end
	self.folder=node("Folder",workspace,{Name="EggDropFirstHatch"})
	-- The landing: 6 studs in front of the character, on the ground (a raycast), else the spawn pad.
	local look=unit(flat(root.CFrame.LookVector),Vector3.new(0,0,-1))
	local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances={character,self.folder}
	local guess=root.Position+look*V2.Stork.land
	local hit=workspace:Raycast(guess+Vector3.new(0,8,0),Vector3.new(0,-30,0),params)
	local land
	if hit then land=hit.Position
	else
		local pad=workspace:FindFirstChildWhichIsA("SpawnLocation",true)
		land=if pad then pad.Position+Vector3.new(0,pad.Size.Y/2,0)else root.Position-Vector3.new(0,3,0)+look*V2.Stork.land
	end
	self.land=land
	self.toPlayer=unit(flat(root.Position-land),-look)
	self.right=unit((-self.toPlayer):Cross(Vector3.new(0,1,0)),Vector3.new(1,0,0)) -- the player's right (look x up)
	self.facing=CFrame.lookAt(Vector3.zero,self.toPlayer)
	-- The character turns to face it and stays still; the camera is ours.
	pcall(function()root.CFrame=CFrame.lookAt(root.Position,Vector3.new(land.X,root.Position.Y,land.Z))end)
	require(script.Parent.MovementLock).shared():acquire(Story.LockReason)
	self.locked=true
	holdRail(true);self.railHeld=true
	self.saved={type=camera.CameraType,fov=camera.FieldOfView,subject=camera.CameraSubject}
	camera.CameraType=Enum.CameraType.Scriptable
	self.camera=camera
	self.cameraAt=camera.CFrame
	self.unregisterCursor=require(script.Parent.ModalCursor).register(self,function()return self.state~="idle"end)
	ContextActionService:BindActionAtPriority(Story.Action,function(_,state,input)return self:key(state,input)end,false,Story.Priority,table.unpack(Story.Keys))
	self.bound=true
	table.insert(self.links,Input.InputBegan:Connect(function(input,processed)self:press(input,processed)end))
	self:buildGui()
	-- The models.
	self.stork=Model.new(self.folder)
	self.blanket=Model.Blanket.new(self.folder)
	self.egg=Model.Egg.new(self.folder)
	self:hidePet(true)
	self.reducedStart=self:reduced()
	self:enter("stork")
	self:event("StorkShown")
	self.pill.Visible=true
	self.skip.Visible=false
end
function Story:buildGui()
	local gui=node("ScreenGui",self.d.gui,{Name="EggDropFirstHatch",ResetOnSpawn=false,DisplayOrder=Story.DisplayOrder,
		ZIndexBehavior=Enum.ZIndexBehavior.Sibling,ScreenInsets=Enum.ScreenInsets.None,IgnoreGuiInset=true})
	self.gui=gui
	-- The full-bleed layer: vignette, flash, cover (a fade), the crack layer.
	local vignette=node("Frame",gui,{Name="Vignette",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=1,Active=false})
	self.vignettes={}
	for i,rotation in ipairs({0,90})do
		local v=node("Frame",vignette,{Name="Edge"..i,Size=UDim2.fromScale(1,1),BackgroundColor3=V2.Crack.vignette,BorderSizePixel=0,ZIndex=1})
		local g=node("UIGradient",v,{Rotation=rotation})
		self.vignettes[i]={frame=v,gradient=g}
	end
	self.vignette=vignette;self:setVignette(0)
	self.crackLayer=node("Frame",gui,{Name="CrackLayer",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=5,Active=false})
	self.flash=node("Frame",gui,{Name="Flash",BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=20,Active=false})
	self.cover=node("Frame",gui,{Name="Cover",BackgroundColor3=V2.Crack.vignette,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=30,Active=false})
	-- The safe layer: the pill top-centre and Skip bottom-right, clear of the Roblox buttons.
	local safe=node("ScreenGui",self.d.gui,{Name="EggDropFirstHatchSafe",ResetOnSpawn=false,DisplayOrder=Story.DisplayOrder+1,
		ZIndexBehavior=Enum.ZIndexBehavior.Sibling,ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets})
	self.safeGui=safe
	local pill=node("TextLabel",safe,{Name="DeliveryPill",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,10),Size=UDim2.fromOffset(0,40),
		AutomaticSize=Enum.AutomaticSize.X,BackgroundColor3=V2.Guide.fill,TextColor3=V2.Guide.ink,Font=Enum.Font.BuilderSansBold,TextSize=20,
		Text=self:copy("onb2.stork.delivery"),Visible=false,ZIndex=2})
	node("UICorner",pill,{CornerRadius=UDim.new(.5,0)})
	node("UIPadding",pill,{PaddingLeft=UDim.new(0,22),PaddingRight=UDim.new(0,22)})
	node("UIStroke",pill,{Color=V2.Guide.ink,Thickness=2,Transparency=.4,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
	self.pill=pill
	local skip=node("TextButton",safe,{Name="StorkSkip",AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-16,1,-16),Size=UDim2.fromOffset(0,V2.Stork.skipH),
		AutomaticSize=Enum.AutomaticSize.X,BackgroundColor3=Color3.fromHex("#2F404C"),BackgroundTransparency=.1,TextColor3=Color3.fromHex("#FFF0D2"),
		Font=Enum.Font.BuilderSansBold,TextSize=17,Text=self:copy("onb2.stork.skip"),AutoButtonColor=true,Visible=false,ZIndex=3})
	node("UICorner",skip,{CornerRadius=UDim.new(.5,0)})
	node("UIPadding",skip,{PaddingLeft=UDim.new(0,22),PaddingRight=UDim.new(0,22)})
	skip.Activated:Connect(function()self:skipStork()end)
	self.skip=skip
	-- The crack ritual's pill and drawing (CrackFx): gold, ink text, under the egg; flakes and hand per Fable.
	local prompt=node("TextLabel",self.crackLayer,{Name="CrackTapPrompt",Text="",Font=Enum.Font.BuilderSansBold,TextSize=22,Visible=false,ZIndex=40})
	local Fx=require(script.Parent.CrackFx)
	self.fx=Fx.new(prompt,self.d.copy):configure({fill=V2.Crack.pill,copy=V2.CrackCopy,handAfter=V2.Crack.handAfter,everyStop=true})
	self.fx.flakeCounts={}
	for i,tap in ipairs(V2.Taps)do self.fx.flakeCounts[i]=tap.flakes end
end
function Story:setVignette(a)
	for _,v in ipairs(self.vignettes or {})do
		local edge=1-V2.Crack.vignetteAlpha*a
		v.gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,edge),NumberSequenceKeypoint.new(.22,1),
			NumberSequenceKeypoint.new(.78,1),NumberSequenceKeypoint.new(1,edge)})
	end
end
-- The garden pet is the Bear; while the story plays its own Bear it is hidden (local only).
function Story:hidePet(on)
	local visual=self.d.pet and self.d.pet()
	local model=visual and visual.model
	if on then
		self.hidden=self.hidden or {}
		if model and model.Parent then
			for _,p in ipairs(model:GetDescendants())do
				if p:IsA("BasePart")and not self.hidden[p]then self.hidden[p]=true;p.LocalTransparencyModifier=1 end
			end
		end
	elseif self.hidden then
		for p in pairs(self.hidden)do if p.Parent then p.LocalTransparencyModifier=0 end end
		self.hidden=nil
	end
end

-- ── Step 2: the stork ────────────────────────────────────────────────────────────────────────────────────────────────
function Story:storkRoots()
	local S=V2.Stork
	local land=self.land
	local hoverKnot=land+Vector3.new(0,S.hoverUp+.2,0)
	local face=CFrame.lookAt(Vector3.zero,self.toPlayer)
	local hoverRoot=CFrame.new(hoverKnot-face:VectorToWorldSpace(Model.BeakTip))*face
	local start=land+self.right*S.out+Vector3.new(0,S.up,0)-self.toPlayer*8
	return start,hoverRoot,hoverKnot
end
function Story:stepStork(dt)
	if self.reducedStart then return self:stepStorkReduced()end
	local S=V2.Stork
	local t=self.since
	local start,hoverRoot,hoverKnot=self:storkRoots()
	local phase=V2.storkPhase(t)
	local root
	local opts={flap=V2.flap(t),legs=0,fold=0}
	if phase=="glide"then
		local u=smooth(t/S.glide)
		local pos=V2.curve(start,hoverRoot.Position,Vector3.new(0,5,0)-self.toPlayer*6,u)
		local ahead=V2.curve(start,hoverRoot.Position,Vector3.new(0,5,0)-self.toPlayer*6,math.min(1,u+.04))
		local travel=unit(flat(ahead-pos),self.toPlayer)
		local dir=unit(travel:Lerp(self.toPlayer,smooth((t-S.glide*.6)/(S.glide*.4))),self.toPlayer)
		root=CFrame.lookAt(pos,pos+dir)
		opts.legs=smooth((t-S.glide*.7)/(S.glide*.3))*.6
	elseif phase=="leave"or phase=="gone"then
		local L=V2.Leave
		local after=t-S.release
		root=hoverRoot
		opts.legs=.6
		for _,at in ipairs(L.clacks)do
			if after>=at and after<at+.12 then opts.clack=math.sin((after-at)/.12*math.pi)end
		end
		if after>=L.nod and after<L.nod+.35 then opts.nod=22*math.sin((after-L.nod)/.35*math.pi)end
		if after>=L.fly then
			local u=(after-L.fly)/(S.total-S.release-L.fly)
			local away=-self.right*10+Vector3.new(0,22,0)-self.toPlayer*16
			local pos=hoverRoot.Position+away*(u*u)
			root=CFrame.lookAt(pos,pos+unit(flat(away),-self.toPlayer))
			opts.legs=.6*(1-u)
		end
		for i,at in ipairs(L.clacks)do
			if not self["clack"..i]and after>=at then self["clack"..i]=true;self:play(Story.Sounds.clack,1+.06*i,.5)end
		end
	else
		root=hoverRoot
		opts.legs=.6
	end
	-- The wing beats' soft whoosh, once a downstroke (empty slots until uploaded).
	local beat=math.floor(((t<=S.glide)and(S.flapFast*t+.5*((S.flapSlow-S.flapFast)/S.glide)*t*t)or(S.flapFast*S.glide+.5*(S.flapSlow-S.flapFast)*S.glide+S.flapSlow*(t-S.glide))))
	if beat~=self.lastBeat then self.lastBeat=beat;local list=Story.Sounds.flap;self:play(list[beat%#list+1],1,.35)end
	if phase~="gone"then self.stork:pose(root,opts)end
	-- The bundle: hanging under the beak until the release, then open on the ground.
	local knot=root*Model.BeakTip
	local facing=CFrame.lookAt(Vector3.zero,self.toPlayer)
	local ground=CFrame.new(self.land)*facing
	if t<S.hover then
		local drop=V2.lower(t)*math.max(0,(hoverKnot.Y-self.land.Y)-1.55)
		local center=self.blanket:hang(knot,drop,facing)
		self.egg:pose(CFrame.new(center-Vector3.new(0,.62,0))*facing,0,1,nil,0)
	else
		if not self.setDown then
			self.setDown=true
			self:play(Story.Sounds.rustle,1,.45)
			self:layer("settle");self:buzz("settle")
			self:event("EggSetDown")
		end
		local u=math.clamp((t-S.hover)/(S.release-S.hover),0,1)
		self.blanket:open(self.land,u,facing)
		self.egg:pose(ground*CFrame.new(0,.1,0),V2.rock(t-S.hover),1,nil,0)
	end
	self.skip.Visible=t>=S.skipAt
	self:aimCamera(dt,"stork",root.Position)
	if t>=S.total then self.stork:destroy();self.stork=nil;self:toCrack()end
end
-- Reduced Motion: a fade to the egg on its blanket with the stork standing beside it, one nod, the stork fades.
function Story:stepStorkReduced()
	local S=V2.Stork
	local t=self.since
	local f=S.reducedFade
	self.cover.BackgroundTransparency=if t<f then 1-t/f elseif t<2*f then(t-f)/f else 1
	local facing=CFrame.lookAt(Vector3.zero,self.toPlayer)
	if t>=f and not self.setDown then
		self.setDown=true
		self:layer("settle");self:buzz("settle");self:event("EggSetDown")
	end
	local ground=CFrame.new(self.land)*facing
	if self.setDown then
		self.blanket:open(self.land,1,facing)
		self.egg:pose(ground*CFrame.new(0,.1,0),0,1,nil,0)
		local spot=self.land+self.right*2.4
		local root=CFrame.lookAt(spot,spot+self.toPlayer)
		local nod=if t>=.9 and t<1.25 then 22*math.sin((t-.9)/.35*math.pi)else 0
		if self.stork then
			self.stork:pose(root,{flap=0,legs=1,fold=1,nod=nod})
			if t>=1.5 then self.stork:setAlpha(math.clamp((t-1.5)/f,0,1))end
		end
	else
		self.egg:pose(CFrame.new(0,-1000,0),0,1,nil,1);self.blanket:open(self.land,0,facing);self.blanket:setAlpha(1)
		if self.stork then self.stork:setAlpha(1)end
	end
	self.skip.Visible=t>=S.skipAt
	self:aimCamera(0,"stork",self.land+Vector3.new(0,2,0))
	if t>=1.5+f+.1 then
		if self.stork then self.stork:destroy();self.stork=nil end
		self:toCrack()
	end
end
-- Skip (the button, B or Esc): straight to the egg on its open blanket.
function Story:skipStork()
	if self.state~="stork"or self.since<V2.Stork.skipAt then return false end
	self:event("OnboardSkipped_Stork")
	if self.stork then self.stork:destroy();self.stork=nil end
	local facing=CFrame.lookAt(Vector3.zero,self.toPlayer)
	self.blanket:open(self.land,1,facing)
	self.egg:pose(CFrame.new(self.land)*facing*CFrame.new(0,.1,0),0,1,nil,0)
	if not self.setDown then self.setDown=true;self:layer("settle");self:buzz("settle");self:event("EggSetDown")end
	self.cover.BackgroundTransparency=1
	self:toCrack()
	return true
end
-- The camera: behind the player, framing the stork and the landing (FOV 55); close on the egg for the crack (FOV 40).
function Story:aimCamera(dt,mode,focus)
	local camera=self.camera;if not camera then return end
	local land=self.land
	local want,fov
	if mode=="stork"then
		local eye=land+self.toPlayer*(V2.Stork.land+7)+Vector3.new(0,3.6,0)-self.right*1.5
		local look=land:Lerp(focus or land,.35)+Vector3.new(0,1.2,0)
		want,fov=CFrame.lookAt(eye,look),V2.Stork.fov
	else
		local C=V2.Crack
		local centre=land+Vector3.new(0,.8,0)
		local eye=centre+self.toPlayer*C.dist+Vector3.new(0,C.up,0)
		want,fov=CFrame.lookAt(eye,centre),C.fov
	end
	if dt<=0 then camera.CFrame=want;camera.FieldOfView=fov;self.cameraAt=want;return end
	local k=1-math.exp(-5*dt)
	self.cameraAt=self.cameraAt:Lerp(want,k)
	camera.CFrame=self.cameraAt
	camera.FieldOfView=camera.FieldOfView+(fov-camera.FieldOfView)*k
end

-- ── Step 3: crack it ─────────────────────────────────────────────────────────────────────────────────────────────────
function Story:toCrack()
	self.pill.Visible=false;self.skip.Visible=false
	self:enter("crack")
	local Ritual=require(script.Parent.CrackRitual)
	self.ritual=Ritual.new(V2.Crack.stops,os.clock,V2.Crack.auto)
	self.age=0;self.fired=0;self.tapAt={};self.rockAt=nil;self.rockDeg=0
	self.cameraFrom=self.cameraAt;self.cameraFov=self.camera and self.camera.FieldOfView or 70
	self.fx:reset()
	self.fx:setText(self.d.inputKind and self.d.inputKind()or "Keyboard")
end
function Story:eggSpot()
	local camera=self.camera
	local centre=self.land+Vector3.new(0,.75,0)
	local p,on=camera:WorldToScreenPoint(centre)
	local top=camera:WorldToScreenPoint(self.land+Vector3.new(0,self.egg:height()+.1,0))
	local bottom=camera:WorldToScreenPoint(self.land)
	local h=math.max(40,math.abs(bottom.Y-top.Y))
	local phone=camera.ViewportSize.Y<500
	return{egg=Vector2.new(p.X,p.Y),eggH=h,pill=Vector2.new(p.X,bottom.Y+(if phone then 34 else 48)),phone=phone},on
end
function Story:stepCrack(dt)
	local C=V2.Crack
	local reduced=self:reduced()
	-- The camera comes close in 0.6 s (a cut under Reduced Motion); the vignette with it.
	local u=if reduced or self.reducedStart then 1 else smooth(self.since/C.tween)
	if self.camera then
		local centre=self.land+Vector3.new(0,.8,0)
		local want=CFrame.lookAt(centre+self.toPlayer*C.dist+Vector3.new(0,C.up,0),centre)
		self.cameraAt=self.cameraFrom:Lerp(want,u)
		self.camera.CFrame=self.cameraAt
		self.camera.FieldOfView=self.cameraFov+(C.fov-self.cameraFov)*u
	end
	self:setVignette(u)
	local ritual=self.ritual
	-- The ritual's clock: runs to each stop and holds there for a tap (or its own 7 s).
	if ritual and not ritual:done()or(self.age<(C.stops[#C.stops]or 0)+.01)then
		local step=if ritual then ritual:cap(self.age,dt)else dt
		if not(ritual and ritual:hold(self.age))then self.age+=step end
	else self.age+=dt end
	for i=self.fired+1,#C.stops do
		if self.age>=C.stops[i]then self.fired=i;self:beat(i,reduced)else break end
	end
	-- The egg: rock after a tap, the swell before the pop, the pop.
	local spot=self:eggSpot()
	self.fx:place(self.crackLayer,spot,spot.phone)
	self.fx:step(dt,ritual~=nil and ritual:waiting()and not self.popAt,ritual and ritual:waited()or 0,0,reduced)
	local facing=CFrame.lookAt(Vector3.zero,self.toPlayer)
	local base=CFrame.new(self.land)*facing*CFrame.new(0,.1,0)
	local rock=0
	if self.rockAt and not reduced then
		local t=self.clock-self.rockAt
		if t<.45 then rock=self.rockDeg*math.exp(-t*5)*math.sin(t*math.pi*2*3)end
	end
	local swell,top,fade=1,nil,0
	if self.creakAt then
		local t=self.clock-self.creakAt
		if t<C.creak then swell=1+(C.swell-1)*smooth(t/C.creak)
		else
			if not self.popAt then self:pop(reduced)end
			local p=self.clock-self.popAt
			local P=C.pop
			if reduced then top={up=0,tip=0,fade=math.clamp(p/.3,0,1)}
			else top={up=P.up*smooth(p/P.fade),tip=40*smooth(p/P.fade),fade=math.clamp(p/P.fade,0,1)}end
			fade=math.clamp(p/.25,0,1) -- the lower shell goes as the Bear stands
			self.flash.BackgroundTransparency=if reduced then 1 else math.clamp(p/P.flash,0,1)
			self:stepBear(p,reduced)
			if p>=P.fade+P.hold then
				if self.replaying then self:finish()else self:toCard()end
				return
			end
		end
	end
	self.egg:pose(base,rock,swell,top,fade)
end
-- A beat released (by a tap or by itself): the rock, the crack drawn, the sound and the buzz.
function Story:beat(i,reduced)
	local tap=V2.Taps[i];if not tap then return end
	local spot=self:eggSpot()
	local at=self.tapAt[i]or spot.egg
	if reduced then for k in ipairs(self.fx.flakeCounts)do self.fx.flakeCounts[k]=V2.ReducedFlakes end end
	self.fx:beat(i,at,false)
	self.rockAt,self.rockDeg=self.clock,tap.rock
	for _,layer in ipairs(tap.layers)do self:layer(layer)end
	self:buzz(tap.haptic)
	if tap.pop then self.creakAt=self.clock end
end
function Story:pop(reduced)
	self.popAt=self.clock
	self:layer("pop",1.2);self:buzz("pop")
	for k=1,3 do task.delay(.08*k,function()if self.state=="crack"then self:layer("flake")end end)end
	task.delay(.35,function()if self.state=="crack"or self.state=="card"then self:layer("exhale")end end)
	self.fx:reset()
	if not reduced then self.flash.BackgroundTransparency=0 end
	-- The Bear stands in the blanket (the player's own Bear, as the garden draws it).
	local ok=pcall(function()
		local pet=Pets.byId.pip
		local appearance=self.d.appearance and self.d.appearance("pip")or nil
		self.bear=require(script.Parent.PetFactory).new(self.folder,self.land,pet,.72,appearance)
		local d=self.toPlayer
		self.bear.yaw=math.atan2(d.X,d.Z)
		self.bear.reducedEffects=reduced
		self.bear:update(0)
	end)
	if not ok then self.bear=nil end
	if self.d.audio and Pets.byId.pip.cue then self:play(Pets.byId.pip.cue,1,.55)end
end
function Story:stepBear(p,reduced)
	local bear=self.bear;if not bear then return end
	local hop=if reduced or p>=.4 then 0 else .7*math.sin(p/.4*math.pi)
	bear.origin=self.land+Vector3.new(0,.12+hop,0)
	if p>=.35 and not self.greeted then self.greeted=true;pcall(function()bear:greet()end)end
	pcall(function()bear:update(1/60)end)
end
-- A press (any tap in the middle 60%, a click; A, Space, E): the ritual's next crack. Never a skip.
function Story:tap(at)
	if self.state~="crack"or not self.ritual or self.popAt or self.creakAt then return false end
	local index=self.ritual.index
	local before=self.ritual.taps
	local taken=self.ritual:tap()
	if taken and self.ritual.taps>before then self.tapAt[index]=at end
	return taken
end
function Story:press(input,processed)
	if processed or self.state~="crack"then return end
	local kind=input.UserInputType
	if kind~=Enum.UserInputType.MouseButton1 and kind~=Enum.UserInputType.Touch then return end
	local camera=self.camera;if not camera then return end
	local at=Vector2.new(input.Position.X,input.Position.Y)
	local size=camera.ViewportSize-Vector2.new(0,GuiService:GetGuiInset().Y)
	if V2.inZone(at,size)then self:tap(at)end
end
function Story:key(state,input)
	if state~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
	if GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
	local key=input.KeyCode
	if self.state=="stork"then
		if key==K.ButtonB or key==K.Escape or key==K.Backspace then self:skipStork()end
	elseif self.state=="crack"then
		if key==K.ButtonA or key==K.Space or key==K.E or key==K.Return or key==K.KeypadEnter then self:tap(nil)end
	elseif self.state=="card"then
		return self:cardKey(key)
	end
	return Enum.ContextActionResult.Sink
end

-- ── Step 4: the Bear's card ──────────────────────────────────────────────────────────────────────────────────────────
function Story:toCard()
	self:enter("card")
	self.flash.BackgroundTransparency=1
	local pet=Pets.byId.pip
	local name=pet.name or "Bear"
	local host=node("ScreenGui",self.d.gui,{Name="EggDropFirstHatchCard",ResetOnSpawn=false,DisplayOrder=Story.DisplayOrder+2,
		ZIndexBehavior=Enum.ZIndexBehavior.Sibling,ScreenInsets=Enum.ScreenInsets.None,IgnoreGuiInset=true})
	self.cardGui=host
	local frame=node("Frame",host,{Name="StageHost",BackgroundTransparency=1,Size=UDim2.fromScale(1,1)})
	local Stage=require(script.Parent.RevealStage)
	self.stage=Stage.show(frame,{pet=pet,name=name,appearance=self.d.appearance and self.d.appearance("pip")or nil,tag="new",
		description=pet.description,audio=self.d.audio,voice=true,
		reduced=function()return self:reduced()end,owns=function()return self.state=="card"end,
		buttons={{id="meet",text=self:copy("onb2.card.meet",{pet=name}),glyph="A",primary=true}},
		onButton=function(id)if id=="meet"then self:meet()end end})
end
function Story:stepCard()
	if self.bear and self.since<1 then pcall(function()self.bear:update(1/60)end)end
	-- Review B36: a card that never showed (or is gone) or was left up too long meets, so input is never held.
	if not self.stage or self.stage.destroyed or self.since>=V2.CardTimeout then self:meet()end
end
function Story:cardKey(key)
	local stage=self.stage
	if not stage then self:meet();return Enum.ContextActionResult.Sink end
	-- The stage reads A / Enter / Space itself; B, Esc and Backspace settle it, then meet (there is no Back).
	if key==K.ButtonB or key==K.Escape or key==K.Backspace then
		if stage:isSettled()then self:meet()else stage:back()end
		return Enum.ContextActionResult.Sink
	end
	if key==K.ButtonA or key==K.Return or key==K.KeypadEnter or key==K.Space then return Enum.ContextActionResult.Pass end
	return Enum.ContextActionResult.Sink
end
-- Meet: movement back at once, the card leaves, the receipt is acked (the same ack the Hatch eggs reveal sends).
function Story:meet()
	if self.state~="card"then return end
	local result=self.result
	self:cleanup()
	if result and self.d.ack then pcall(self.d.ack,result.id)end
	if self.d.companion then pcall(self.d.companion)end
	self.acking=result
	self.ackTries=1;self.ackAt=os.clock()
	if result then
		-- A throttled or busy ack is sent again (at most three times) while the receipt is still the same.
		task.spawn(function()
			while self.acking==result and self.ackTries<3 do
				task.wait(1.5)
				local now=self.d.receipt and self.d.receipt()
				if not now or now.id~=result.id then break end
				self.ackTries+=1;pcall(self.d.ack,result.id)
			end
			if self.acking==result then self.acking=nil end
		end)
	end
	if self.d.done then pcall(self.d.done,false)end
end
-- The replay's end: no card, the garden back.
function Story:finish()
	self:cleanup()
	if self.d.done then pcall(self.d.done,true)end
end
function Story:cleanup()
	self.state="idle";self.since=0
	if self.link then self.link:Disconnect();self.link=nil end
	for _,link in ipairs(self.links)do link:Disconnect()end
	table.clear(self.links)
	if self.bound then self.bound=false;ContextActionService:UnbindAction(Story.Action)end
	if self.unregisterCursor then self.unregisterCursor();self.unregisterCursor=nil end
	if self.locked then self.locked=false;pcall(function()require(script.Parent.MovementLock).shared():release(Story.LockReason)end)end
	if self.railHeld then self.railHeld=false;holdRail(false)end
	if self.stage then
		local stage=self.stage;self.stage=nil
		local gui=self.cardGui;self.cardGui=nil
		if not stage:dismiss(function()if gui then gui:Destroy()end end)then stage:destroy();if gui then gui:Destroy()end end
	elseif self.cardGui then self.cardGui:Destroy();self.cardGui=nil end
	if self.bear then pcall(function()self.bear:destroy()end);self.bear=nil end
	if self.stork then self.stork:destroy();self.stork=nil end
	if self.folder then self.folder:Destroy();self.folder=nil end
	self.blanket,self.egg=nil,nil
	if self.fx then pcall(function()self.fx:destroy()end);self.fx=nil end
	if self.gui then self.gui:Destroy();self.gui=nil end
	if self.safeGui then self.safeGui:Destroy();self.safeGui=nil end
	self:hidePet(false)
	local camera,saved=self.camera,self.saved
	self.camera,self.saved=nil,nil
	if camera and saved then
		camera.CameraType=saved.type==Enum.CameraType.Scriptable and Enum.CameraType.Custom or saved.type
		camera.FieldOfView=saved.fov
		local character=self.d.character and self.d.character()
		local humanoid=character and character:FindFirstChildOfClass("Humanoid")
		camera.CameraSubject=humanoid or saved.subject
	end
	self.ritual,self.popAt,self.creakAt,self.setDown,self.greeted,self.asked=nil,nil,nil,nil,nil,nil
	self.clack1,self.clack2,self.lastBeat,self.heldSince=nil,nil,nil,nil
	self.replaying=false
end
function Story:destroy()
	self.disabled=true
	self:cleanup()
end
return Story
