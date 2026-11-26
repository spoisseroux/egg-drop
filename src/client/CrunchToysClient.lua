-- Crunchy toys round the garden (GARDEN-PLAY-BRIEF 2026-11-26 section 2; CrunchToys holds the numbers): two leaf heaps,
-- a row of pop pods, a pebble tray and rattle gourds, built from plain parts on this client and stomped locally. No
-- remotes: each client watches the characters and pets it already has (replicated, or drawn by RoomView) and reacts
-- on its own. Mine are full volume with a buzz (Haptics, its cap); my pet's at half; other players' at 40% and only
-- within 30 studs of me. A pet that pops a pod startles, then sniffs about.
--
-- Gate: the Alive `crunch` switch (beta and Studio); off, nothing is built (and a switch turned off at runtime takes it
-- all down). The loop runs at 30 Hz only while a toy is within the cull distance (90 studs on a phone, 150 elsewhere)
-- and the garden is up (Mode Room); otherwise it sleeps and looks again every .5 s. Reduced Motion: the toys stay
-- still (no squash, burst, hop or swing); they still crunch.
--
-- Instance state for probes: workspace.CrunchToysLocal (attributes CrunchAwake, CrunchParts, CrunchLast).
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Toys=require(Shared:WaitForChild("CrunchToys"))
local World=require(Shared:WaitForChild("HollowWorldLayout"))

local Client={};Client.__index=Client
Client.Folder="CrunchToysLocal"
Client.Voices=8

local function material(name,fallback)
	local ok,value=pcall(function()return(Enum.Material::any)[name]end)
	if ok and value~=nil then return value end
	return(Enum.Material::any)[fallback]
end
local function hex(value)return Color3.fromHex(value)end

-- deps (specs): alive, parent, heartbeat (false: the spec steps), now, ground(x, z) -> y, agents() -> {key, kind,
-- position, visual}, listener() -> Vector3, camera() -> Vector3, mode() -> string, reduced() -> bool, phone() -> bool,
-- level() -> number, play(layer, position, gain), buzz(name), react(visual), uri(cue), group (SoundGroup), delay(s, fn),
-- roomView (the default agents' pets), worldVersion.
function Client.mount(deps)
	deps=deps or {}
	local alive=deps.alive or require(Shared:WaitForChild("Alive"))
	if not alive.ceiling(Toys.Feature)then return nil end
	if(deps.worldVersion or World.WorldVersion)~="v7"then return nil end
	local self=setmetatable({d=deps,alive=alive,built=false,awake=false,connections={},clock=0,seed=deps.seed or 1126},Client)
	self.now=deps.now or os.clock
	self.delay=deps.delay or task.delay
	self.mode=deps.mode or function()return "Room"end
	self.reduced=deps.reduced or function()return game:GetService("GuiService").ReducedMotionEnabled==true end
	self.level=deps.level or function()
		local ok,level=pcall(function()return require(script.Parent.AliveBudget).level()end)
		return if ok and type(level)=="number"then level else 0
	end
	self.phone=deps.phone or function()
		local input=game:GetService("UserInputService")
		return input.TouchEnabled==true and input.KeyboardEnabled~=true
	end
	self.camera=deps.camera or function()
		local camera=workspace.CurrentCamera
		return camera and camera.CFrame.Position
	end
	self.listener=deps.listener or function()
		local character=Players.LocalPlayer and Players.LocalPlayer.Character
		local root=character and character:FindFirstChild("HumanoidRootPart")
		return if root then root.Position else self.camera()
	end
	self.agents=deps.agents or function()return Client.defaultAgents(deps.roomView)end
	self.buzz=deps.buzz or function(name)
		pcall(function()require(script.Parent.Haptics).play(name)end)
	end
	self.react=deps.react or Client.startle
	self.random=Random.new(self.seed)
	table.insert(self.connections,alive.changed(Toys.Feature):Connect(function()self:sync()end))
	self:sync()
	return self
end

-- Every character root and every pet this client draws. kind: own / other / ownPet / otherPet.
function Client.defaultAgents(roomView)
	local out={}
	local me=Players.LocalPlayer
	for _,player in ipairs(Players:GetPlayers())do
		local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then table.insert(out,{key=player.UserId,kind=if player==me then "own"else "other",position=root.Position})end
	end
	if roomView then
		local own=roomView.pet
		if own and not own.destroyed and typeof(own.origin)=="Vector3"then
			table.insert(out,{key=own,kind="ownPet",position=own.origin,visual=own})
		end
		for player,entry in pairs(roomView.companions and roomView.companions.active or {})do
			local visual=entry.visual
			if visual and visual~=own and not visual.destroyed and typeof(visual.origin)=="Vector3"then
				table.insert(out,{key=visual,kind=if player==me then "ownPet"else "otherPet",position=visual.origin,visual=visual})
			end
		end
	end
	return out
end
-- A pet that popped a pod: startled for a beat (PetReactions' face), then a curious look about (the idle "look" beat).
function Client.startle(visual)
	if type(visual)~="table"or visual.destroyed then return end
	local Reactions=require(script.Parent.PetReactions)
	local now=os.clock()
	if Reactions.trigger(visual,"loss",now)and visual.playReaction then
		visual.playReaction.untilTime=now+Reactions.StartledFor
	end
	task.delay(Reactions.StartledFor,function()
		if visual.destroyed then return end
		local Beats=require(script.Parent.PetIdleBeats)
		local s=visual.idleBeat
		if not s then s={idle=0,clock=0,last=-math.huge};visual.idleBeat=s end
		if s.kind then return end
		s.kind,s.age,s.previous,s.landed="look",0,"look",false
		s.duration=Beats.Durations.look;s.side=s.side or 1;s.count=(s.count or 0)+1
		visual.poseDirty=true
	end)
end

function Client:sync()
	if self.destroyed then return end
	local on=self.alive.on(Toys.Feature)==true
	if on==self.built then return end
	if on then
		local ok,problem=pcall(self.build,self)
		if not ok then
			warn("[CrunchToys] build failed: "..tostring(problem))
			self:teardown()
			return
		end
		self:wake()
	else
		self:teardown()
	end
end

-- Building ----------------------------------------------------------------------------------------------------------
local function part(name,size,cframe,colour,mat,parent,shadow)
	local p=Instance.new("Part")
	p.Name=name;p.Size=size;p.CFrame=cframe;p.Color=hex(colour);p.Material=mat
	p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=shadow==true
	p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
	p.Parent=parent
	return p
end
local function sphere(p)
	local mesh=Instance.new("SpecialMesh")
	mesh.MeshType=Enum.MeshType.Sphere
	mesh.Parent=p
	return mesh
end
local function cylinder(name,length,width,cframe,colour,mat,parent,shadow)
	local p=part(name,Vector3.new(length,width,width),cframe,colour,mat,parent,shadow)
	p.Shape=Enum.PartType.Cylinder
	return p
end

-- Ground under (x, z): the island's grid, refined by a straight-down ray that skips see-through and non-query parts.
function Client:groundAt(x,z)
	if self.d.ground then return self.d.ground(x,z)end
	local grid=World.groundY(x,z)
	local ok,y=pcall(function()
		local params=RaycastParams.new()
		params.FilterType=Enum.RaycastFilterType.Exclude
		local skip={self.folder}
		for _,player in ipairs(Players:GetPlayers())do if player.Character then table.insert(skip,player.Character)end end
		for _=1,4 do
			params.FilterDescendantsInstances=skip
			local hit=workspace:Raycast(Vector3.new(x,grid+12,z),Vector3.new(0,-30,0),params)
			if not hit then return nil end
			if hit.Instance.Transparency<1 then return hit.Position.Y end
			table.insert(skip,hit.Instance)
		end
		return nil
	end)
	if ok and type(y)=="number"and math.abs(y-grid)<2.5 then return y end
	return grid
end

function Client:build()
	if self.built then return end
	self.built=true
	local folder=Instance.new("Folder");folder.Name=Client.Folder
	folder.Parent=self.d.parent or workspace
	self.folder=folder
	self.parts=0
	local function count(p)self.parts+=1;return p end
	local leafy,fabric,wood,pebble=material("LeafyGrass","Grass"),material("Fabric","Fabric"),material("Wood","Wood"),material("Pebble","Pebble")
	local rubber,skin=material("Rubber","Fabric"),material("Cardboard","Fabric")
	local grass,slate,smooth=material("Grass","SmoothPlastic"),material("Slate","Slate"),material("SmoothPlastic","SmoothPlastic")
	local H,P,T,G=Toys.Heap,Toys.Pod,Toys.Tray,Toys.Gourd
	self.heaps,self.pods,self.cards,self.gourds={}, {}, {}, {}

	-- The leaf heaps: three squashed mounds (sunk half into the ground, so a squash lowers the top) and leaves on top.
	for n,at in ipairs(Toys.Places.heaps)do
		local y=self:groundAt(at.x,at.z)
		local base=CFrame.new(at.x,y,at.z)*CFrame.Angles(0,at.yaw,0)
		local heap={id=at.id,base=base,centre=Vector3.new(at.x,y,at.z),mounds={},leaves={},state={},level=1,seed=n*101}
		for i,m in ipairs(H.mounds)do
			local p=count(part(at.id.."_mound"..i,Vector3.new(m[3],m[4]*2,m[5]),base*CFrame.new(m[1],0,m[2]),H.colours[m[6]],leafy,folder,i==1))
			table.insert(heap.mounds,sphere(p))
		end
		for i=1,H.leaves do
			local r=Toys.hash(heap.seed,i,1)*1.9
			local a=Toys.hash(heap.seed,i,2)*math.pi*2
			local lx,lz=math.cos(a)*r,math.sin(a)*r
			local ly=H.height*math.sqrt(math.max(0,1-(r/(H.width/2))^2))+.02
			local tilt=CFrame.Angles((Toys.hash(heap.seed,i,3)-.5)*.6,a,(Toys.hash(heap.seed,i,4)-.5)*.6)
			local p=count(part(at.id.."_leaf"..i,H.leafSize,base*CFrame.new(lx,ly,lz)*tilt,H.colours[(i%3)+1],fabric,folder,false))
			table.insert(heap.leaves,{part=p,x=lx,y=ly,z=lz,tilt=tilt})
		end
		table.insert(self.heaps,heap)
	end
	-- One pool of burst cards, parked out of sight under the first heap.
	local park=self.heaps[1].base*CFrame.new(0,-3,0)
	for i=1,H.burst do
		local p=count(part("leaf_card"..i,H.leafSize,park,H.colours[(i%3)+1],fabric,folder,false))
		p.Transparency=1
		table.insert(self.cards,{part=p,heap=nil,start=0,index=i})
	end

	-- The pop pods (Fable B35): a body in one of three greens, a puckered nub on top, and three sepals at the base that
	-- stay put when it flattens. Each its own yaw and height (Toys.podLook).
	for i,spot in ipairs(Toys.podSpots())do
		local y=self:groundAt(spot.X,spot.Y)
		local yaw,high=Toys.podLook(i)
		local tall=P.tall*high
		local base=CFrame.new(spot.X,y,spot.Y)*CFrame.Angles(0,yaw,0)
		local colour=P.colours[(i-1)%#P.colours+1]
		local body=count(part("pop_pod"..i,Vector3.new(P.across,tall,P.across),base*CFrame.new(0,tall*.4,0),colour,rubber,folder,true))
		local dome=count(part("pop_pod"..i.."_nub",Vector3.new(P.domeAcross,P.domeTall,P.domeAcross),base*CFrame.new(0,tall*.88,0),P.dome,rubber,folder,false))
		-- A sepal: its inner end tucked under the body, its tip tilted up and .25 past the body's edge.
		local length,tilt=P.sepal.X,math.rad(P.sepalTilt)
		local reach=P.across/2+P.sepalPast-length/2*math.cos(tilt)
		for k=1,P.sepals do
			local a=(k-1)*math.pi*2/P.sepals
			count(part("pop_pod"..i.."_sepal"..k,P.sepal,
				base*CFrame.Angles(0,a,0)*CFrame.new(reach,length/2*math.sin(tilt)+P.sepal.Y/2,0)*CFrame.Angles(0,0,tilt),
				P.sepalColour,grass,folder,false))
		end
		table.insert(self.pods,{body=body,dome=dome,bodyMesh=sphere(body),domeMesh=sphere(dome),base=base,tall=tall,
			centre=Vector3.new(spot.X,y,spot.Y),poppedAt=nil,scale=1})
	end

	-- The pebble tray: four timber boards round a bed of pea gravel, and six loose pebbles that hop under a step.
	do
		local at=Toys.Places.tray
		local y=self:groundAt(at.x,at.z)
		local base=CFrame.new(at.x,y,at.z)*CFrame.Angles(0,at.yaw,0)
		local sx,sz,bw,bh=T.size.X,T.size.Y,T.board.X,T.board.Y
		count(part("pebble_tray_board1",Vector3.new(sx,bh,bw),base*CFrame.new(0,bh/2,sz/2-bw/2),T.frame,wood,folder,true))
		count(part("pebble_tray_board2",Vector3.new(sx,bh,bw),base*CFrame.new(0,bh/2,-sz/2+bw/2),T.frame,wood,folder,true))
		count(part("pebble_tray_board3",Vector3.new(bw,bh,sz-bw*2),base*CFrame.new(sx/2-bw/2,bh/2,0),T.frame,wood,folder,true))
		count(part("pebble_tray_board4",Vector3.new(bw,bh,sz-bw*2),base*CFrame.new(-sx/2+bw/2,bh/2,0),T.frame,wood,folder,true))
		count(part("pebble_tray_gravel",Vector3.new(sx-bw*2,.2,sz-bw*2),base*CFrame.new(0,.1,0),T.gravel,pebble,folder,false))
		self.tray={base=base,centre=Vector3.new(at.x,y,at.z),pebbles={}}
		for i=1,T.pebbles do
			local lx=(Toys.hash(11,i,1)-.5)*(sx-1.2)
			local lz=(Toys.hash(11,i,2)-.5)*(sz-1.2)
			local w=.22+Toys.hash(11,i,3)*.14
			local rest=base*CFrame.new(lx,.2+w*.3,lz)
			local p=count(part("pebble_tray_pebble"..i,Vector3.new(w,w*.7,w*1.1),rest,T.pebbleColours[(i%3)+1],pebble,folder,false))
			sphere(p)
			table.insert(self.tray.pebbles,{part=p,rest=rest,x=lx,z=lz,hopAt=nil})
		end
	end

	-- The rattle gourds (Fable B35): a twig arch (two leaning posts on foot stones, one bar with accent cord wraps on its
	-- ends) and three unalike gourds on short cords that swing on it.
	do
		local at=Toys.Places.gourds
		local y=self:groundAt(at.x,at.z)
		local base=CFrame.new(at.x,y,at.z)*CFrame.Angles(0,at.yaw,0)
		local half=G.span/2-.15
		for side=-1,1,2 do
			count(cylinder("rattle_gourds_post"..(if side<0 then 1 else 2),G.bar+.1,G.post,
				base*CFrame.new(side*half,G.bar/2,0)*CFrame.Angles(0,0,math.pi/2+side*.06),G.bark,wood,folder,true))
		end
		count(cylinder("rattle_gourds_bar",G.span,G.post*.8,base*CFrame.new(0,G.bar,0),G.bark,wood,folder,true))
		for k,side in ipairs({-1,1})do
			count(part("rattle_gourds_stone"..k,G.stone,base*CFrame.new(side*half,G.stone.Y/2-.04,0)*CFrame.Angles(0,math.rad(G.stoneYaws[k]),0),
				G.stoneColour,slate,folder,true))
			count(cylinder("rattle_gourds_wrap"..k,G.wrap.X,G.wrap.Y,base*CFrame.new(side*(half-.05),G.bar,0),G.wrapColour,smooth,folder,false))
		end
		self.arch={base=base,centre=Vector3.new(at.x,y,at.z)}
		for i=1,G.count do
			local lx=(i-(G.count+1)/2)*G.gap
			local pivot=base*CFrame.new(lx,G.bar-G.post*.3,0)
			local shape=G.bodies[i]
			local size=Vector3.new(shape[1],shape[2],shape[1])
			local cord=count(cylinder("rattle_gourd"..i.."_cord",G.cordLength,.05,pivot,G.cord,smooth,folder,false))
			local neck=count(part("rattle_gourd"..i.."_neck",G.neck,pivot,shape[3],skin,folder,true))
			local body=count(part("rattle_gourd"..i,size,pivot,shape[3],skin,folder,true))
			sphere(neck);sphere(body)
			local g={pivot=pivot,cord=cord,neck=neck,body=body,at=nil,push=0,
				offsets={CFrame.new(0,-G.cordLength/2,0)*CFrame.Angles(0,0,math.pi/2),
					CFrame.new(0,-G.cordLength-G.neck.Y*.4,0),
					CFrame.new(0,-G.cordLength-G.neck.Y*.75-size.Y*.35,0)},
				spot=(pivot*CFrame.new(0,-G.cordLength-G.neck.Y-size.Y*.2,0)).Position}
			table.insert(self.gourds,g)
			self:poseGourd(g,0)
		end
	end

	-- The sounds hang from one invisible part (attachments are positional), routed through the garden's cue group so
	-- the Sound setting and focus mute them.
	local anchor=count(part("crunch_audio",Vector3.new(.2,.2,.2),CFrame.new(),"#000000",material("SmoothPlastic","SmoothPlastic"),folder,false))
	anchor.Transparency=1
	self.voices={}
	local group=self.d.group or(self.d.ambient and self.d.ambient.group)
	if group==nil then pcall(function()group=game:GetService("SoundService"):FindFirstChild("EggDropAmbientCues")end)end
	for i=1,Client.Voices do
		local holder=Instance.new("Attachment");holder.Name="voice"..i;holder.Parent=anchor
		local voice=Instance.new("Sound");voice.Name="crunch"..i
		voice.RollOffMode=Enum.RollOffMode.InverseTapered;voice.RollOffMinDistance=8;voice.RollOffMaxDistance=70
		voice.Volume=0;voice.SoundGroup=group;voice.Parent=holder
		table.insert(self.voices,{holder=holder,voice=voice,at=-math.huge})
	end
	self.uris={}
	self.agentsSeen={}
	self.petReactAt=setmetatable({},{__mode="k"})
	self.clusters={
		{centre=self.heaps[1].centre},{centre=self.heaps[2].centre},
		{centre=self.pods[1].centre:Lerp(self.pods[#self.pods].centre,.5)},
		{centre=self.tray.centre},{centre=self.arch.centre}}
	folder:SetAttribute("CrunchParts",self.parts)
	assert(self.parts<=Toys.Budget,"over the part budget: "..self.parts)
end

function Client:teardown()
	self:sleep()
	if self.folder then self.folder:Destroy()end
	self.folder=nil;self.built=false
	self.heaps,self.pods,self.cards,self.gourds,self.tray,self.arch,self.voices=nil,nil,nil,nil,nil,nil,nil
end

-- Sound ---------------------------------------------------------------------------------------------------------
function Client:uri(cue)
	if self.d.uri then return self.d.uri(cue)end
	if self.uris[cue]~=nil then return self.uris[cue]or nil end
	local id=Toys.NewTakes[cue]
	local out=if type(id)=="number"and id>0 then "rbxassetid://"..id else nil
	if not out then
		pcall(function()
			local Audio=require(script.Parent.BoardAudio)
			local asmr=Audio.AsmrIds and Audio.AsmrIds[cue]
			out=if type(asmr)=="number"and asmr>0 then "rbxassetid://"..asmr else Audio.uri(cue)
		end)
	end
	self.uris[cue]=out or false
	return out
end
function Client:voice(layer,position,gain)
	if self.d.play then return self.d.play(layer,position,gain)end
	local uri=self:uri(layer.cue)
	if not uri or not self.voices then return false end
	local pick
	for _,v in ipairs(self.voices)do if not v.voice.IsPlaying then pick=v;break end end
	if not pick then
		pick=self.voices[1]
		for _,v in ipairs(self.voices)do if v.at<pick.at then pick=v end end
	end
	pick.at=self.now()
	pick.holder.Position=position
	local voice=pick.voice
	voice.SoundId=uri;voice.PlaybackSpeed=layer.speed;voice.Volume=layer.volume*gain;voice.TimePosition=0
	voice:Play()
	return true
end
-- Play a toy's sound at `position` for whoever made it.
function Client:sound(name,position,kind,distance)
	local gain=Toys.gain(kind,distance)
	if gain<=0 then return 0 end
	local random=self.random
	local layers=Toys.layers(name,function(lo,hi)return random:NextNumber(lo,hi)end)
	for _,layer in ipairs(layers)do
		if layer.delay>0 then
			self.delay(layer.delay,function()if self.built then self:voice(layer,position,gain)end end)
		else self:voice(layer,position,gain)end
	end
	if kind=="own"and Toys.Buzz[name]then self.buzz(Toys.Buzz[name])end
	if self.folder then self.folder:SetAttribute("CrunchLast",name)end
	return #layers
end

-- Posing --------------------------------------------------------------------------------------------------------
function Client:poseGourd(g,angle)
	local frame=g.pivot*CFrame.Angles(angle,0,0)
	g.cord.CFrame=frame*g.offsets[1]
	g.neck.CFrame=frame*g.offsets[2]
	g.body.CFrame=frame*g.offsets[3]
	g.angle=angle
end

-- The loop --------------------------------------------------------------------------------------------------------
function Client:cull()
	return if self.phone()then Toys.Cull.phone else Toys.Cull.desktop
end
-- Anything to do? A toy within the cull distance of the camera, the garden up, and no animation left over.
function Client:wanted()
	if not self.built or self.mode()~="Room"then return false end
	local camera=self.camera()
	if typeof(camera)~="Vector3"then return false end
	local reach=self:cull()
	for _,cluster in ipairs(self.clusters)do
		if(cluster.centre-camera).Magnitude<=reach then return true end
	end
	return false
end
function Client:wake()
	if self.destroyed or not self.built then return end
	if not self:wanted()then self:sleep(true);return end
	if self.awake then return end
	self.awake=true
	if self.folder then self.folder:SetAttribute("CrunchAwake",true)end
	if self.d.heartbeat~=false then
		self.link=(self.d.heartbeat or RunService.Heartbeat):Connect(function(dt)
			local ok,problem=pcall(self.step,self,dt)
			if not ok then
				warn("[CrunchToys] stopped: "..tostring(problem))
				pcall(self.destroy,self)
			end
		end)
	end
end
-- Stop the loop; `poll` looks again in Toys.Sleep s.
function Client:sleep(poll)
	if self.link then self.link:Disconnect();self.link=nil end
	if self.awake then
		self.awake=false
		if self.folder then self.folder:SetAttribute("CrunchAwake",false)end
		table.clear(self.agentsSeen or {})
	end
	if poll and not self.polling and not self.destroyed and self.d.heartbeat~=false then
		self.polling=true
		self.delay(Toys.Sleep,function()
			self.polling=false
			if not self.destroyed and self.built then self:wake()end
		end)
	end
end

function Client:busy(now)
	for _,heap in ipairs(self.heaps)do if heap.state.hitAt and now-heap.state.hitAt<Toys.Heap.squash+Toys.Heap.reheap+.1 then return true end end
	for _,card in ipairs(self.cards)do if card.heap then return true end end
	for _,pod in ipairs(self.pods)do if pod.poppedAt then return true end end
	for _,g in ipairs(self.gourds)do if g.at then return true end end
	for _,p in ipairs(self.tray.pebbles)do if p.hopAt then return true end end
	return false
end

-- One agent against every near toy. `seen` is its last sample {x, z, y, inside = {key = true}}.
function Client:touch(agent,seen,now,listener,active)
	local p=agent.position
	local kind=agent.kind
	local distance=if typeof(listener)=="Vector3"then(p-listener).Magnitude else nil
	local inside=seen.inside
	local prime=seen.prime==true
	seen.prime=nil
	local function enter(key,centre,reach)
		local over=p.Y-centre.Y
		local hit=over<Toys.Reach and over>-2 and Toys.crossed(seen.x,seen.z,p.X,p.Z,centre.X,centre.Z,reach)
		local was=inside[key]==true
		inside[key]=over<Toys.Reach and over>-2 and Vector2.new(p.X-centre.X,p.Z-centre.Z).Magnitude<=reach
		return hit and not was and not prime
	end
	if active[1]or active[2]then
		for i,heap in ipairs(self.heaps)do
			if active[i]and enter("heap"..i,heap.centre,Toys.Heap.reach)then self:hitHeap(heap,now,agent,distance)end
		end
	end
	if active[3]then
		for i,pod in ipairs(self.pods)do
			if enter("pod"..i,pod.centre,Toys.Pod.reach)and not pod.poppedAt then
				pod.poppedAt=now
				self:sound("pop",pod.centre,kind,distance)
				if agent.visual and(kind=="ownPet"or kind=="otherPet")then
					local last=self.petReactAt[agent.visual]
					if not last or now-last>=Toys.PetReactGap then
						self.petReactAt[agent.visual]=now
						pcall(self.react,agent.visual)
					end
				end
			end
		end
	end
	if active[4]then
		local tray=self.tray
		local l=tray.base:PointToObjectSpace(Vector3.new(p.X,tray.centre.Y,p.Z))
		local over=p.Y-tray.centre.Y
		local on=over<Toys.Reach and over>-2 and Toys.inTray(l.X,l.Z)
		if on then
			local step=Vector2.new(p.X-seen.x,p.Z-seen.z).Magnitude
			local was=inside.tray==true
			seen.stride=(seen.stride or 0)+step
			if not prime and(not was or seen.stride>=Toys.Tray.stride)then
				seen.stride=0
				self:sound("gravel",Vector3.new(p.X,tray.centre.Y+.2,p.Z),kind,distance)
				-- The pebble nearest the foot hops.
				local best,bestD
				for _,pebble in ipairs(tray.pebbles)do
					local d=(pebble.x-l.X)^2+(pebble.z-l.Z)^2
					if not pebble.hopAt and(not bestD or d<bestD)then best,bestD=pebble,d end
				end
				if best then best.hopAt=now end
			end
		end
		inside.tray=on
	end
	if active[5]then
		for i,g in ipairs(self.gourds)do
			if enter("gourd"..i,g.spot,Toys.Gourd.reach)then
				-- Swing away from where the bump came from (across the bar).
				local away=self.arch.base:VectorToObjectSpace(Vector3.new(g.spot.X-seen.x,0,g.spot.Z-seen.z))
				-- (A positive angle about the bar swings the gourd toward -Z.)
				local push=if away.Z>=0 then -1 else 1
				self:bumpGourd(i,push,now)
				self:sound("rattle",g.spot,kind,distance)
			end
		end
	end
	seen.x,seen.z,seen.y=p.X,p.Z,p.Y
end
function Client:hitHeap(heap,now,agent,distance)
	local burst,gain=Toys.heapHit(heap.state,now)
	local g=Toys.gain(agent.kind,distance)
	if g>0 then
		local random=self.random
		for _,layer in ipairs(Toys.layers("heap",function(lo,hi)return random:NextNumber(lo,hi)end))do
			local scaled={cue=layer.cue,speed=layer.speed,volume=layer.volume*gain,delay=layer.delay}
			if layer.delay>0 then self.delay(layer.delay,function()if self.built then self:voice(scaled,heap.centre,g)end end)
			else self:voice(scaled,heap.centre,g)end
		end
		if agent.kind=="own"then self.buzz(Toys.Buzz.heap)end
		if self.folder then self.folder:SetAttribute("CrunchLast","heap")end
	end
	if self.reduced()or self.level()>=2 then return end
	-- Burst cards: the free ones first, then the oldest.
	local free={}
	for _,card in ipairs(self.cards)do if not card.heap then table.insert(free,card)end end
	table.sort(self.cards,function(a,b)return(a.start or 0)<(b.start or 0)end)
	for _,card in ipairs(self.cards)do
		if #free>=burst then break end
		if card.heap and not table.find(free,card)then table.insert(free,card)end
	end
	heap.bursts=(heap.bursts or 0)+1
	for k=1,math.min(burst,#free)do
		local card=free[k]
		card.heap,card.start,card.seed=heap,now,heap.seed+heap.bursts*17
	end
end
function Client:bumpGourd(i,push,now)
	local G=Toys.Gourd
	local g=self.gourds[i]
	g.at,g.push=now,push
	-- The neighbours sway a little with it.
	for _,j in ipairs({i-1,i+1})do
		local other=self.gourds[j]
		if other and(not other.at or now-other.at>G.settle*.5)then other.at,other.push=now+.08,push*G.neighbour end
	end
end

function Client:step(dt)
	if self.destroyed or not self.built then return end
	self.clock+=dt or 0
	if self.clock<Toys.Rate then return end
	self.clock=0
	local now=self.now()
	local camera=self.camera()
	local reach=self:cull()
	local active,any={},false
	if self.mode()=="Room"and typeof(camera)=="Vector3"then
		for i,cluster in ipairs(self.clusters)do
			active[i]=(cluster.centre-camera).Magnitude<=reach
			any=any or active[i]
		end
	end
	if any then
		local listener=self.listener()
		local seenNow={}
		for _,agent in ipairs(self.agents())do
			if agent.key~=nil and typeof(agent.position)=="Vector3"then
				local seen=self.agentsSeen[agent.key]
				if not seen then
					-- A first sight only notes where it is (no crunch for a pet that appears on a heap).
					seen={x=agent.position.X,z=agent.position.Z,y=agent.position.Y,inside={},prime=true}
				end
				self:touch(agent,seen,now,listener,active)
				seenNow[agent.key]=seen
			end
		end
		self.agentsSeen=seenNow
	end
	self:animate(now,self.reduced())
	if not any and not self:busy(now)then self:sleep(true)end
end

function Client:animate(now,reduced)
	local parts,frames={},{}
	local H,P=Toys.Heap,Toys.Pod
	for _,heap in ipairs(self.heaps)do
		local level=if reduced then 1 else Toys.heapLevel(heap.state,now)
		local settled=heap.state.hitAt~=nil and now-heap.state.hitAt>=H.squash+H.reheap
		if settled then heap.state.hitAt=nil;level=1 end
		if math.abs(level-heap.level)>.004 or(settled and level~=heap.level)then
			heap.level=level
			for _,mesh in ipairs(heap.mounds)do mesh.Scale=Vector3.new(1+(1-level)*.12,level,1+(1-level)*.12)end
			for _,leaf in ipairs(heap.leaves)do
				table.insert(parts,leaf.part);table.insert(frames,heap.base*CFrame.new(leaf.x,leaf.y*level,leaf.z)*leaf.tilt)
			end
		end
	end
	local life=Toys.cardLife()
	for _,card in ipairs(self.cards)do
		if card.heap then
			local t=now-card.start
			if t>=life or reduced then
				card.heap=nil;card.part.Transparency=1
				table.insert(parts,card.part);table.insert(frames,self.heaps[1].base*CFrame.new(0,-3,0))
			else
				local offset,rx,ry,rz,seen=Toys.card(card.seed,card.index,math.max(0,t))
				card.part.Transparency=1-seen
				table.insert(parts,card.part)
				table.insert(frames,CFrame.new(card.heap.centre+offset)*CFrame.Angles(rx,ry,rz))
			end
		end
	end
	for _,pod in ipairs(self.pods)do
		if pod.poppedAt or pod.scale~=1 then
			local sy,sxz,phase=Toys.podScale(pod.poppedAt,now)
			if reduced then sy,sxz=1,1 end
			if pod.poppedAt and phase=="inflating"and not pod.creaked then
				pod.creaked=true
				self:sound("creak",pod.centre,"world",0)
			end
			if phase=="ready"then pod.poppedAt=nil;pod.creaked=false end
			if math.abs(sy-pod.scale)>.002 or phase=="ready"then
				pod.scale=sy
				pod.bodyMesh.Scale=Vector3.new(sxz,sy,sxz)
				pod.domeMesh.Scale=Vector3.new(sxz,sy,sxz)
				table.insert(parts,pod.body);table.insert(frames,pod.base*CFrame.new(0,pod.tall*.4*sy,0))
				table.insert(parts,pod.dome);table.insert(frames,pod.base*CFrame.new(0,pod.tall*.88*sy,0))
			end
		end
	end
	for _,pebble in ipairs(self.tray.pebbles)do
		if pebble.hopAt then
			local t=now-pebble.hopAt
			local up=if reduced then 0 else Toys.pebbleHop(t)
			if t>=Toys.Tray.hopTime then pebble.hopAt=nil;up=0 end
			table.insert(parts,pebble.part);table.insert(frames,pebble.rest*CFrame.new(0,up,0))
		end
	end
	for _,g in ipairs(self.gourds)do
		if g.at then
			local angle=if reduced then 0 else Toys.gourdAngle(g.at,g.push,now)
			if now-g.at>=Toys.Gourd.settle then g.at=nil;angle=0 end
			self:poseGourd(g,angle)
		end
	end
	if #parts>0 then
		if self.d.move then self.d.move(parts,frames)
		else workspace:BulkMoveTo(parts,frames,Enum.BulkMoveMode.FireCFrameChanged)end
	end
end

function Client:destroy()
	if self.destroyed then return end
	self.destroyed=true
	for _,c in ipairs(self.connections)do c:Disconnect()end
	self:teardown()
end
return Client
