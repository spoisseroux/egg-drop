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
-- companion(), event(name), fallback(result), done(replay), stand(at, seconds) (optional: the garden Bear rests at
-- `at` that long, facing the player: the server's GardenState:stand).
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
-- Every voice the story plays is its own (one owner), so the pop's near silence can stop them (code review: the duck
-- alone only reached the music group).
function Story:play(name,speed,gain)
	self.voices=self.voices or {}
	if self.d.audio then pcall(function()self.d.audio:play(name,speed or 1,gain or .5,self.voices)end)end
end
function Story:hush()
	local audio=self.d.audio
	if audio and audio.stopOwner and self.voices then pcall(function()audio:stopOwner(self.voices)end)end
	self.voices={}
end
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
	if self.state=="plan"then return self:stepPlan()end
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
		-- deck2 (onboarding v3 section 5): combo 3's pips, sweep and rise play first (V2.tuckAfter)
		if self.since>=V2.tuckAfter()and not self.asked then self.asked=true;pcall(d.toRoom)end
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
	self.ignore={character,self.folder}
	local pet=d.pet and d.pet()
	if pet and pet.model then table.insert(self.ignore,pet.model)end
	-- The player stays still and the camera is ours from here; the landing and the flight are planned over the next
	-- few frames (stepPlan), a bounded number of casts a frame (code review: never thousands in one frame).
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
	self.reducedStart=self:reduced()
	self:enter("plan")
	self.planned,self.planError,self.casts=false,nil,0
	local look=unit(flat(root.CFrame.LookVector),Vector3.new(0,0,-1))
	local feet=root.Position-Vector3.new(0,3,0)
	local token={}
	self.planToken=token
	task.spawn(function()
		local ok,problem=pcall(function()
			-- The landing: 6 studs in front on the ground with open sky and room for the hovering stork (V2.landing:
			-- else round the player); no ground at all: the spawn pad. On the arrival dais it sits 0.6 studs further in.
			local land=V2.landing(feet,look,function(x,z,y)return self:ground(x,z,y)end,function(a,b,r)return self:clear(a,b,r)end)
			if self.planToken~=token then return end
			if not land then
				local pad=workspace:FindFirstChildWhichIsA("SpawnLocation",true)
				land=if pad then pad.Position+Vector3.new(0,pad.Size.Y/2,0)else feet+look*V2.Stork.land
			end
			local okDais,dais=pcall(function()return require(game:GetService("ReplicatedStorage").Shared.HollowWorldLayout).Stations.ArrivalDais.Position end)
			land=V2.onDais(land,if okDais then dais else nil)
			self.land=land
			self.toPlayer=unit(flat(root.Position-land),-look)
			self.right=unit((-self.toPlayer):Cross(Vector3.new(0,1,0)),Vector3.new(1,0,0)) -- the player's right (look x up)
			self.facing=CFrame.lookAt(Vector3.zero,self.toPlayer)
			-- The flight, chosen against the world (beta 36: "the stork flies thru the arch").
			local _,hoverRoot=self:storkRoots()
			self.route=V2.storkRoute(land,self.toPlayer,hoverRoot.Position,function(a,b,r)return self:clear(a,b,r)end)
		end)
		if self.planToken~=token then return end
		if ok then self.planned=true else self.planError=problem end
	end)
end
-- The plan is in: the character turns to face the landing and the stork sets off.
function Story:stepPlan()
	if self.planError then error(self.planError)end
	if not self.planned then
		if self.since>3 then error("the flight could not be planned")end
		return
	end
	local character=self.d.character and self.d.character()
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local land=self.land
	if root then pcall(function()root.CFrame=CFrame.lookAt(root.Position,Vector3.new(land.X,root.Position.Y,land.Z))end)end
	self.stork=Model.new(self.folder)
	self.blanket=Model.Blanket.new(self.folder)
	self.egg=Model.Egg.new(self.folder)
	self:hidePet(true)
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
-- What a sweep may hit: solid, visible, queryable world (not us, the player, the garden pet, glass or trigger boxes).
-- Every cast counts toward a budget (V2.Route): at most castsPerSweep retries a sweep (past glass and trigger boxes),
-- and while the plan runs it waits a frame every framesCasts casts, so planning never stalls a frame.
function Story:cast()
	self.casts=(self.casts or 0)+1
	if self.state=="plan"and self.casts%V2.Route.framesCasts==0 then task.wait()end
end
function Story:clear(a,b,radius)
	local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
	local ignore=table.clone(self.ignore or {})
	params.FilterDescendantsInstances=ignore
	local d=b-a
	if d.Magnitude<1e-3 then return true end
	for _=1,V2.Route.castsPerSweep do
		self:cast()
		local hit=if radius and radius>0 then workspace:Spherecast(a,radius,d,params)else workspace:Raycast(a,d,params)
		if not hit then return true end
		local p=hit.Instance
		if p:IsA("BasePart")and(p.Transparency>=.95 or not p.CanCollide)then
			table.insert(ignore,p);params.FilterDescendantsInstances=ignore
		else return false end
	end
	return false
end
-- The ground under (x, z) near height y (solid, not water), or nil.
function Story:ground(x,z,y)
	local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
	local ignore=table.clone(self.ignore or {})
	params.FilterDescendantsInstances=ignore
	for _=1,V2.Route.castsPerSweep do
		self:cast()
		local hit=workspace:Raycast(Vector3.new(x,(y or 0)+8,z),Vector3.new(0,-30,0),params)
		if not hit then return nil end
		local p=hit.Instance
		if p:IsA("BasePart")and(p.Transparency>=.95 or not p.CanCollide)then table.insert(ignore,p);params.FilterDescendantsInstances=ignore
		elseif hit.Material==Enum.Material.Water then return nil
		else return hit.Position end
	end
	return nil
end
function Story:storkRoots()
	local S=V2.Stork
	local land=self.land
	local hoverKnot=land+Vector3.new(0,S.hoverUp+.2,0)
	local face=CFrame.lookAt(Vector3.zero,self.toPlayer)
	local hoverRoot=CFrame.new(hoverKnot-face:VectorToWorldSpace(Model.BeakTip))*face
	local start=if self.route then self.route.start else land+self.right*S.out+Vector3.new(0,S.up,0)-self.toPlayer*8
	return start,hoverRoot,hoverKnot
end
function Story:bow()return if self.route then self.route.bow else Vector3.new(0,5,0)-self.toPlayer*6 end
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
		local pos=V2.curve(start,hoverRoot.Position,self:bow(),u)
		local ahead=V2.curve(start,hoverRoot.Position,self:bow(),math.min(1,u+.04))
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
			-- off back along the way it came (the route found clear), speeding up
			local u=math.clamp((after-L.fly)/(S.total-S.release-L.fly),0,1)
			local back=u*u
			local pos=V2.curve(start,hoverRoot.Position,self:bow(),1-back)
			local ahead=V2.curve(start,hoverRoot.Position,self:bow(),math.max(0,1-back-.04))
			root=CFrame.lookAt(pos,pos+unit(flat(ahead-pos),-self.toPlayer))
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
		self.egg:pose(ground*CFrame.new(0,V2.Blanket.thick,0),V2.rock(t-S.hover),1,nil,0)
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
		self.egg:pose(ground*CFrame.new(0,V2.Blanket.thick,0),0,1,nil,0)
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
	self.egg:pose(CFrame.new(self.land)*facing*CFrame.new(0,V2.Blanket.thick,0),0,1,nil,0)
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
-- Fable's cathartic crack (AERO-JUICE-BRIEF 4) on 3D cracks (Spencer, beta 36). A tap releases the ritual's stop: a
-- 40 ms anticipation dip, then in one frame the sound layers, the buzz and the crack stage starting to grow on the shell
-- (EggCrackPaths + EggCrack3D), the rock (or tap 3's flex), the crumbs and the camera 3% closer. Tap 3: the creak and
-- flex, 80 ms of near silence, then the pop. CrackFx keeps only its pill and ghost hand (no ring, no screen lines; its
-- polylines are the fallback when the 3D cracks cannot be built).
function Story:toCrack()
	self.pill.Visible=false;self.skip.Visible=false
	self:enter("crack")
	local Ritual=require(script.Parent.CrackRitual)
	self.ritual=Ritual.new(V2.Crack.stops,os.clock,V2.Crack.auto)
	self.age=0;self.fired=0;self.tapAt={};self.tapT={};self.soundT={};self.closer=0
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
-- The new takes (scripts/synth_asmr.py, BoardAudio.StorkIds: empty slots until uploaded, quiet), never the same
-- variant twice running (HatchAsmr's rule).
Story.Takes=table.freeze({tap_knuckle={"a","b","c"},shell_scatter={"a","b"},crumb_bounce={"a","b","c"},asmr_crack3={"a","b"}})
function Story:take(name,gain)
	local list=Story.Takes[name];if not list then return end
	self.lastTake=self.lastTake or {}
	local options={}
	for _,v in ipairs(list)do if v~=self.lastTake[name]or #list==1 then table.insert(options,v)end end
	local v=options[math.random(1,#options)]
	self.lastTake[name]=v
	self:play(name.."_"..v,.97+.06*math.random(),gain or .4)
end
-- The camera on the egg: 0.6 s in, 3% closer after taps 1 and 2, the pop's kick back and FOV (none when reduced).
function Story:crackCamera(reduced)
	local C=V2.Crack
	local camera=self.camera;if not camera then return end
	local u=if reduced or self.reducedStart then 1 else smooth(self.since/C.tween)
	local dist=C.dist*(1-C.closer*self.closer)
	local kick,fov=0,C.fov
	if self.popAt and not reduced then kick,fov=V2.popCamera(self.clock-self.popAt)end
	local centre=self.land+Vector3.new(0,.8,0)
	local want=CFrame.lookAt(centre+self.toPlayer*(dist+kick)+Vector3.new(0,C.up,0),centre)
	if u<1 then
		self.cameraAt=self.cameraFrom:Lerp(want,u)
		camera.FieldOfView=self.cameraFov+(fov-self.cameraFov)*u
	else
		self.cameraAt=if reduced then want else self.cameraAt:Lerp(want,.25)
		camera.FieldOfView=fov
	end
	camera.CFrame=self.cameraAt
	self:setVignette(u)
end
function Story:stepCrack(dt)
	local C=V2.Crack
	local reduced=self:reduced()
	self:crackCamera(reduced)
	local ritual=self.ritual
	-- The ritual's clock: runs to each stop and holds there for a tap (or its own 7 s).
	if ritual and not ritual:done()or(self.age<(C.stops[#C.stops]or 0)+.01)then
		local step=if ritual then ritual:cap(self.age,dt)else dt
		if not(ritual and ritual:hold(self.age))then self.age+=step end
	else self.age+=dt end
	for i=self.fired+1,#C.stops do
		if self.age>=C.stops[i]then self.fired=i;self.tapT[i]=self.clock else break end
	end
	-- 40 ms after a tap: its sound, buzz, crack stage, crumbs, rock and camera step.
	for i=1,self.fired do
		if not self.soundT[i]and self.clock-self.tapT[i]>=C.anticipate then self.soundT[i]=self.clock;self:beat(i,reduced)end
	end
	local spot=self:eggSpot()
	self.fx:place(self.crackLayer,spot,spot.phone)
	self.fx:step(dt,ritual~=nil and ritual:waiting()and not self.creakAt,ritual and ritual:waited()or 0,0,reduced)
	local facing=CFrame.lookAt(Vector3.zero,self.toPlayer)
	local base=CFrame.new(self.land)*facing*CFrame.new(0,V2.Blanket.thick,0)
	-- The shell: the latest tap's dip (held on tap 3), its rock, tap 3's flex.
	local last=self.fired
	local rock,sy,sxz=0,1,1
	if last>0 and not reduced then
		sy,sxz=V2.dip(last,self.clock-self.tapT[last])
		if self.soundT[last]then rock=V2.tapRock(last,self.clock-self.soundT[last])end
	end
	local flex=1
	if self.creakAt and not reduced then flex=V2.flex(self.clock-self.creakAt)end
	local S=Vector3.new(sxz*flex,sy*flex,sxz*flex)
	local top,fade=nil,0
	if self.creakAt then
		local t=self.clock-self.creakAt
		local P=C.pop
		if t>=C.creak and not self.silentAt then
			-- 80 ms of near silence: everything ducks 6 dB
			self.silentAt=self.clock
			if self.d.audio and self.d.audio.duck then pcall(function()self.d.audio:duck("firstCrackPop",P.silence+.4,P.duck)end)end
			-- and the story's own voices (the creak's tail, crumbs, flakes, any stork take) stop for the beat
			self:hush()
		end
		if self.silentAt and not self.popAt and self.clock-self.silentAt>=P.silence then self:pop(reduced)end
		if self.popAt then
			local p=self.clock-self.popAt
			S=Vector3.new(1,1,1)
			if reduced then top={up=0,tip=0,fade=math.clamp(p/.3,0,1)}
			else top={up=P.up*smooth(p/P.fade),tip=40*smooth(p/P.fade),fade=math.clamp(p/P.fade,0,1)}end
			-- Fable B37 section 6: the bottom half-shell stays under the Bear for 600 ms, then goes
			fade=math.clamp((p-V2.Crack.pop.keepBottom)/.25,0,1)
			self.flash.BackgroundTransparency=if reduced then 1 else(if p<P.flash then 1-P.flashAlpha else 1)
			self:stepBear(p,reduced)
			if p>=P.fade+P.hold then
				if self.replaying then self:finish()else self:toCard()end
				return
			end
		end
	end
	self.egg:pose(base,rock,S,top,fade)
	if self.crack3D then self.crack3D:step(self.clock,dt,self.popAt~=nil)end
end
-- Tap i's moment (40 ms after it): the layered sound, the buzz, the stage on the shell, crumbs, the camera closer.
function Story:beat(i,reduced)
	local tap=V2.Taps[i];if not tap then return end
	local spot=self:eggSpot()
	local at=self.tapAt[i]or spot.egg
	-- the cracks: built at the first tap, from where it landed on the shell
	if i==1 and not self.crack3D and not self.crack2D then
		local ok,crack=pcall(function()
			local Paths=require(script.Parent.EggCrackPaths)
			local half=math.max(20,spot.eggH*.38)
			local dx,dy=(at.X-spot.egg.X)/half,(at.Y-spot.egg.Y)/half
			local segments,chips=Paths.build(Paths.tapPoint(dx,dy,math.pi),math.floor(os.clock()*1000)%100000)
			return require(script.Parent.EggCrack3D).new(self.folder,self.egg,segments,{grow=V2.Crack.grow,leakAlpha=V2.Crack.leakAlpha,chips=chips})
		end)
		if ok then self.crack3D=crack else warn("[Onboard] 3D cracks: "..tostring(crack));self.crack2D=true end
	end
	if self.crack3D then self.crack3D:show(tap.stage,self.clock,reduced)
	else
		-- the fallback: CrackFx's drawn lines (no ring)
		if reduced then for k in ipairs(self.fx.flakeCounts)do self.fx.flakeCounts[k]=V2.ReducedFlakes end end
		self.fx:beat(i,nil,false)
	end
	for _,layer in ipairs(tap.layers)do self:layer(layer)end
	for _,name in ipairs(tap.takes or {})do self:take(name,.45)end
	if tap.under then local u=tap.under;task.delay(.04,function()if self.state=="crack"then self:layer(u.layer,1.3*u.gain)end end)end
	self:buzz(tap.haptic)
	if tap.duck and self.d.audio and self.d.audio.duck then pcall(function()self.d.audio:duck("firstCrack"..i,tap.duck.time,tap.duck.gain)end)end
	if tap.closer and not reduced then self.closer+=1 end
	-- crumbs from the tap point on the shell, each a flake as it lands
	if self.crack3D then
		local Paths=require(script.Parent.EggCrackPaths)
		local first=self.crack3D.lines[1]
		local point=if first then first.seg.a else{math.pi,Paths.Shape.seamV}
		local world=self.egg:surface(Paths.point(point[1],point[2]),Paths.normal(point[1],point[2]),.02)
		local count=if reduced then V2.ReducedFlakes else tap.crumbs
		self.crack3D:crumbs(world,count,self.land.Y+V2.Blanket.thick+.02,tap.skitter,function()self:layer("flake",1.1);self:take("crumb_bounce",.25)end)
	end
	if tap.pop then self.creakAt=self.clock end
end
-- The pop: one frame of pop, sting and scatter; the top flies, 12 to 16 pieces arc out, a 35% flash for 120 ms, the
-- big buzz, the camera's kick; the Bear (facing the camera) and his cue 120 ms later; late flakes and the exhale.
function Story:pop(reduced)
	local P=V2.Crack.pop
	self.popAt=self.clock
	self.egg:open()
	self:layer("pop",1.2);self:play(P.sting,1,.5);self:take(P.scatter,.5)
	self:buzz("pop")
	self.fx:reset()
	if self.crack3D then
		self.crack3D:hideLines()
		local voiced=0
		local count=P.pieces[1]+math.random(0,P.pieces[2]-P.pieces[1])
		self.crack3D:burst(if reduced then V2.ReducedFlakes else count,self.land.Y+V2.Blanket.thick,self.toPlayer,function()
			if voiced<P.voiced then voiced+=1;self:layer("flake",1.2)end
		end)
	end
	local late=P.lateFlakes[1]+math.random(0,P.lateFlakes[2]-P.lateFlakes[1])
	for k=1,late do task.delay(.7+.12*k,function()if self.state=="crack"or self.state=="card"then self:layer("flake",.9)end end)end
	task.delay(.75+.12*late,function()if self.state=="crack"or self.state=="card"then self:layer("exhale")end end)
	-- The Bear stands in the blanket (the player's own Bear, as the garden draws it), facing the camera, feet and all.
	local ok=pcall(function()
		local pet=Pets.byId.pip
		local appearance=self.d.appearance and self.d.appearance("pip")or nil
		local bear=require(script.Parent.PetFactory).new(self.folder,self.land,pet,.72,appearance)
		-- beta (36): "its feet not facing the camera": face the camera (the pet's front is +Z turned by yaw) and keep
		-- the feet with the body (a focused pose plants nothing in the world)
		local camera=self.camera
		local d=unit(flat((if camera then camera.CFrame.Position else self.land+self.toPlayer)-self.land),self.toPlayer)
		bear.yaw=math.atan2(d.X,d.Z)
		bear.focusPose=true
		bear.reducedEffects=reduced
		bear:update(0)
		self.bear=bear
	end)
	if not ok then self.bear=nil end
	task.delay(P.cueDelay,function()
		if(self.state=="crack"or self.state=="card")and Pets.byId.pip.cue then self:play(Pets.byId.pip.cue,1,.55)end
	end)
end
function Story:stepBear(p,reduced)
	local bear=self.bear;if not bear then return end
	local hop=if reduced or p>=.4 then 0 else .7*math.sin(p/.4*math.pi)
	bear.origin=self.land+Vector3.new(0,V2.Blanket.thick+.02+hop,0)
	local camera=self.camera
	if camera then
		local d=unit(flat(camera.CFrame.Position-self.land),self.toPlayer)
		bear.yaw=math.atan2(d.X,d.Z)
	end
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
	-- Beta (37) note 1: the garden Bear takes over where ours stands (see handOff); ours is kept out of the cleanup.
	local handing=not self.replaying and self.bear~=nil and self.land~=nil and self.d.stand~=nil
	local bear,hidden,land=nil,nil,self.land
	if handing then
		bear,hidden=self.bear,self.hidden;self.bear,self.hidden=nil,nil
		-- out of the story's folder (the cleanup destroys it): ours stands in the world on its own until the swap
		if not pcall(function()bear.model.Parent=workspace end)then self.bear,self.hidden,handing=bear,hidden,false end
	end
	self:cleanup()
	if result and self.d.ack then pcall(self.d.ack,result.id)end
	if self.d.companion then pcall(self.d.companion)end
	if handing then self:handOff(bear,hidden,land)end
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
-- Beta (37) note 1 ("the bear isnt visible bc it teleports somewhere behind us behind a fence"): after Meet the garden
-- Bear (the server's) was wherever it followed to, behind the player. Now the server is asked to stand it where the egg
-- opened, facing the player, a beat (V2.Stand.beat) before it follows (GardenState:stand). Ours stays on its blanket
-- spot, still hiding the garden Bear, until the garden Bear is drawn there (or V2.Stand.wait passes: a refused or slow
-- ask shows the garden Bear where it is, as before). Same place, same pose: no pop. Movement is already back.
function Story:handOff(bear,hidden,land)
	local d=self.d
	pcall(d.stand,land,V2.Stand.beat+V2.Stand.reach)
	local function reveal()
		for p in pairs(hidden or {})do if p.Parent then p.LocalTransparencyModifier=0 end end
		hidden=nil
		if bear then pcall(function()bear:destroy()end);bear=nil end
	end
	if not pcall(function()bear:update(0)end)then reveal();return end
	local started=os.clock()
	local link
	link=RunService.RenderStepped:Connect(function()
		local good,swap=pcall(function()
			local visual=d.pet and d.pet()
			local model=visual and visual.model
			-- a rig swap meanwhile: its new parts hide too
			if model and model.Parent then
				hidden=hidden or {}
				for _,p in ipairs(model:GetDescendants())do
					if p:IsA("BasePart")and not hidden[p]then hidden[p]=true;p.LocalTransparencyModifier=1 end
				end
			end
			pcall(function()bear:update(1/60)end)
			local at=visual and visual.origin
			local near=typeof(at)=="Vector3"and V2.standArrived(at,land)
			return near or os.clock()-started>=V2.Stand.wait or self.disabled
		end)
		if not good or swap then link:Disconnect();reveal()end
	end)
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
	self.crack3D,self.crack2D,self.silentAt,self.closer,self.route=nil,nil,nil,0,nil
	self.clack1,self.clack2,self.lastBeat,self.heldSince=nil,nil,nil,nil
	self.replaying=false;self.planToken=nil;self.planned=false;self.planError=nil
end
function Story:destroy()
	self.disabled=true
	self:cleanup()
end
return Story
