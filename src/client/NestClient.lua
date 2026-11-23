-- The Sleepy Nest in the garden, the client (ONBOARDING-V3-PLAN-2026-11-23 slice D; the look is
-- artifacts/onboarding-2026-11-23/NEST-LOOK.md, remodelled and moved to the plaza for beta 12 QA O2:
-- artifacts/qa-2026-11-23-beta12/GARDEN-LIFE-NEST-LOOK.md section 4). mount() answers nil with the Onboarding v3 build
-- ceiling off; with Onboard.on("nest") off it only watches the switch: no instances, no remotes bound, no per-frame work.
-- On: the nest (21 parts: a twig mound, rim rolls, a straw bed, twig and straw fringes, a wooden sign with the pet's
-- name) and the napping egg at Nest.Spot as local inert parts in one folder (anchored, nothing can touch, stand on or
-- query them; only the mound casts a shadow), the egg's growth look from Nest.look (small, glow, rocking, ready), a label with
-- the clock, a ProximityPrompt to Tuck in or Hatch, a HUD chip with the countdown, and clientUI.nestPlace for the Bear.
-- The server is the truth (NestHost):
--   NestEvent {kind="state", public}    the egg, its clock and its gift (public = nil: no nest, everything goes)
--   NestEvent {kind="claimed", receipt} the egg hatched and was saved: only now is the reward shown
--   NestEvent {kind="refused", reason, of}
--   NestClaim {kind="sync"|"tuck"|"claim"} (the server lands the egg by itself; the client never sends "land")
-- Remotes are bound through remotes.ChildAdded, never waited for; {kind="sync"} once both are there, again on each
-- switch-on and on respawn. Presentation only: nothing here pays, times or decides anything.
-- deps: remotes, audio ({play(name, speed, volume)}), reduced(), root() -> Vector3?, free() (Room mode, nothing
--   in the way), busy() (a menu or card is up), compact() (phone), chipHost() -> GuiObject? (the garden dock),
--   show() (lay the Show me trail to the nest), toast(text, stars) (the rail), petName(), ground(at) -> y?,
--   meshes() -> {TopShell, BottomShell, Core}? (fresh MeshPart copies, or nil while they load), focus() (the pet focus
--   camera is on: the label hides), chipHidden() (in the Pet Park: the chip hides), measure(text, size) -> px,
--   plus world, player ({CharacterAdded}), now() (server unix time) and step=false (no Heartbeat; specs call :step).
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Onboard=require(Shared:WaitForChild("Onboard"))
local Nest=require(Shared:WaitForChild("Nest"))
local UICopy=require(Shared:WaitForChild("UICopy"))
local Toys=require(Shared:WaitForChild("ToyCatalog"))
local Wear=require(Shared:WaitForChild("WearableCatalog"))
local Pets=require(Shared:WaitForChild("PetCatalog"))
local LifeArt=require(Shared:WaitForChild("LifeArt"))
local Models=require(Shared:WaitForChild("EggModels")).Egg
local Client={};Client.__index=Client
Client.Folder="EggDropSleepyNest"
Client.Event="NestEvent"
Client.Claim="NestClaim"
Client.Spot=Nest.Spot                  -- the plaza's east rim (spot A); the walk map's ground, raycast when it can be
Client.Facing=Nest.Facing              -- the plaza's middle: root -Z points at it
Client.PromptAt=Vector3.new(0,1,-2.6)  -- root-local: the prompt, and where the Bear's prints end
Client.BearSpot=Vector3.new(2.2,0,-1.4) -- the Bear curls here (the fringe is wider); the sign is on the other side
Client.EggBase=.64     -- .06 into the straw bed
Client.Scale=table.freeze({small=1.25,glow=1.6,rocking=2,ready=2})
Client.Halo=table.freeze({glow={.25,.5},rocking={.45,.7},ready={.85,.85}})
Client.HaloStill=table.freeze({glow=.3,rocking=.5,ready=.8})
Client.ZzzEvery=table.freeze({small=4,glow=3,rocking=3})
Client.Pending=8        -- a claim with no answer this long settles back
Client.BusyWait=2       -- a refused claim: the prompt returns after this long
Client.TuckSeconds=2.6
Client.TuckedLabel=4
Client.TuckedFirstLabel=6 -- the first tuck-in ever holds its line longer (GARDEN-LIFE-NEST-LOOK 5)
Client.NextLabel=3
Client.HatchSeconds=2
Client.StageTween=.6
Client.DropSeconds=.35
Client.Prompt=6         -- studs: only within reach of the nest's front
Client.PromptOffset=Vector2.new(0,72) -- under the nest, never on the egg
Client.Near=8           -- studs: the "Inside:" line
Client.SecondWidth=236  -- px: the widest second-line pill; the explainer wraps inside it
Client.SecondSize=13
-- Beta (12) QA O1 (Fable, GARDEN-LIFE-NEST-LOOK.md section 5): the nest's words by role, so a wording change is a
-- UICopy edit only. `how` explains the egg until the first hatch; `tuckedFirst` is the first tuck-in ever.
Client.Copy=table.freeze({how="onb3.nest.how",howPlain="onb3.nest.howPlain",tucked="onb3.nest.tucked",
	tuckedFirst="onb3.nest.tuckedFirst",next="onb3.nest.next",title="onb3.nest.title",chipReady="onb3.nest.chipReady",
	ready="onb3.nest.ready"})
Client.GroundSlack=1    -- studs: a ground hit further than this from Spot.Y is not the lawn
Client.Assets=table.freeze({
	chip="rbxassetid://114080030018596",egg="rbxassetid://116613877519776",halo="rbxassetid://93444884817210",
	z="rbxassetid://127381504371398"})
-- The remodel's textures (LifeArt: the uploaded ids, or stand-ins until then).
Client.Art=table.freeze({twigs="nestTwigs",fringe="nestFringe",bed="strawBed",wisps="strawWisps",sign="nestSign"})
Client.Spark="rbxasset://textures/particles/sparkles_main.dds"
Client.Color=table.freeze({mound=Color3.fromHex("#3A2616"),rim1=Color3.fromHex("#6B4A2C"),rim2=Color3.fromHex("#5A3D24"),
	rim3=Color3.fromHex("#7D5A38"),straw=Color3.fromHex("#B8974F"),post=Color3.fromHex("#6B4A2B"),board=Color3.fromHex("#A47E50"),
	signInk=Color3.fromHex("#3B2A1A"),egg=Color3.fromHex("#C9B4FF"),halo=Color3.fromHex("#FFF3C4"),gold=Color3.fromHex("#FFE08A"),
	core=Color3.fromHex("#FFF3C4"),cream=Color3.fromHex("#FFF4DC"),ink=Color3.fromHex("#15143A"),stars=Color3.fromHex("#FFC14D"),
	well=Color3.fromHex("#20234A"),text=Color3.fromHex("#FFFFFF")})

local function finite(n)return type(n)=="number"and n==n and n~=math.huge and n~=-math.huge end
local function int(n,low)return finite(n)and n%1==0 and n>=(low or 0)end
local GiftKinds=table.freeze({hat=true,neck=true,toy=true,charm=true,stars=true})

-- ── Pure ─────────────────────────────────────────────────────────────────────────────────────────────────────────
-- A state packet's `public` as a checked view, or nil (no nest, or junk).
function Client.parse(public)
	if type(public)~="table"or not finite(public.at)or not int(public.n)then return nil end
	local gift=type(public.gift)=="table"and public.gift or {}
	local kind=if GiftKinds[gift.kind]then gift.kind else "stars"
	local item=if kind~="stars"and type(gift.item)=="string"and #gift.item>0 and #gift.item<=64 then gift.item else nil
	if kind~="stars"and not item then kind="stars"end
	local readyAt=if finite(public.readyAt)then public.readyAt else public.at+Nest.Seconds
	return{at=public.at,readyAt=readyAt,n=public.n,egg=if int(public.egg,1)then public.egg else public.n+1,
		week=public.week==true or public.n>=Nest.WeekLength,tucked=public.tucked==true,
		pet=if type(public.pet)=="string"then public.pet else "",
		gift={kind=kind,item=item,stars=if int(gift.stars)then gift.stars else 0}}
end
-- Seconds left (0 = ready) and the look at server time `now`.
function Client.left(view,now)return math.max(0,view.readyAt-now)end
function Client.look(view,now)
	if Client.left(view,now)<=0 then return "ready"end
	return Nest.look({at=view.readyAt-Nest.Seconds},now)or "small"
end
-- The label clock ("Ready in 7 h.") and the chip clock ("7 h"), from Nest.countdown.
function Client.clock(left)
	local kind,value=Nest.countdown(left)
	if kind=="hours"then return UICopy.get("onb3.nest.hours",{hours=value}),kind end
	if kind=="minutes"then return UICopy.get("onb3.nest.minutes",{minutes=value}),kind end
	return UICopy.get("onb3.nest.ready"),"ready"
end
function Client.chipText(left)
	local kind,value=Nest.countdown(left)
	if kind=="hours"then return UICopy.get("onb3.nest.chipHours",{hours=value}),kind end
	if kind=="minutes"then return UICopy.get("onb3.nest.chipMinutes",{minutes=value}),kind end
	return UICopy.get(Client.Copy.chipReady),"ready"
end
-- The gift's name for the label and the reward ("Bow Tie", "Ball", "Nest Charm"); nil for Stars.
function Client.itemName(kind,item,pet)
	if type(item)~="string"then return nil end
	if kind=="charm"then return UICopy.get("onb3.charm.name")end
	if kind=="toy"then local toy=Toys.ById[item];return toy and toy.name or nil end
	if kind=="hat"or kind=="neck"then
		local ok,found=pcall(function()return Wear.forPet(pet,math.huge).byId[item]end)
		return if ok and found then found.name else nil
	end
	return nil
end
-- The pet's display name for a view, or nil.
function Client.petName(view)
	return if type(view)=="table"then Pets.petName(view.pet)else nil
end
-- "{pet}'s egg naps for {hours} hours. Come back to hatch a gift." ({hours} is Nest.Hours, never a typed 8).
function Client.how(view)
	local name=Client.petName(view)
	if name then return UICopy.get(Client.Copy.how,{pet=name,hours=Nest.Hours})end
	return UICopy.get(Client.Copy.howPlain,{hours=Nest.Hours})
end
-- The label's second line and its kind: the explainer until the first hatch (n == 0, shown at any distance the label
-- shows), then what is inside (within Client.Near only).
function Client.secondLine(view)
	if view.n==0 then return Client.how(view),"how"end
	return Client.inside(view),"inside"
end
-- "Inside: {item} and {stars} Stars." or "Inside: {stars} Stars."
function Client.inside(view)
	local name=Client.itemName(view.gift.kind,view.gift.item,view.pet)
	if name then return UICopy.get("onb3.nest.inside",{item=name,stars=view.gift.stars})end
	return UICopy.get("onb3.nest.insideStars",{stars=view.gift.stars})
end
-- The egg's pose for a look at clock t: scale multiplier, rock (degrees), hop (studs), squash Y, halo opacity.
-- Reduced Motion: no rock, hop or breath; the halo steady.
function Client.motion(look,t,reduced)
	local halo=Client.Halo[look]
	if reduced then return 1,0,0,1,Client.HaloStill[look]or 0 end
	if look=="glow"then
		local wave=.5-.5*math.cos(t/3.2*2*math.pi)
		return 1+.03*wave,0,0,1,halo[1]+(halo[2]-halo[1])*wave
	elseif look=="rocking"then
		local cycle=2/.9+1.2
		local p=t%cycle
		local rock=if p<2/.9 then 7*math.sin(p*.9*2*math.pi)else 0
		local wave=.5-.5*math.cos(t/3.2*2*math.pi)
		return 1,rock,0,1,halo[1]+(halo[2]-halo[1])*wave
	elseif look=="ready"then
		local p=t%1.6
		local hop=if p<.4 then .35*math.sin(p/.4*math.pi)else 0
		local rock=if p<.8 then 10*math.sin(p/.8*2*math.pi)else 0
		local squash=if p>=.4 and p<.48 then .92 else 1
		return 1,rock,hop,squash,halo[1]
	end
	return 1,0,0,1,0
end
-- Back Out over 0..1 (the stage change).
function Client.backOut(x)local c1=1.70158;local c3=c1+1;return 1+c3*(x-1)^3+c1*(x-1)^2 end
-- The root frame on ground `y`: -Z at the dais.
function Client.frame(y)
	local at=Vector3.new(Client.Spot.X,y,Client.Spot.Z)
	return CFrame.lookAt(at,Vector3.new(Client.Facing.X,y,Client.Facing.Z))
end
-- The 21 nest parts, root-local (GARDEN-LIFE-NEST-LOOK 4; degrees, root -Z the front). shape: "cylinder" (axis along
-- X), "block" or "plate" (a see-through decal plate). texture = {key, faces, u, v, offsetU}; decal = {key, faces}.
local Face=Enum.NormalId
local CURVED={Face.Top,Face.Bottom,Face.Front,Face.Back} -- a Cylinder's round side (its caps are Left and Right)
local BOTH={Face.Front,Face.Back}
function Client.parts()
	local list={}
	local rad=math.rad
	local up=CFrame.Angles(0,0,math.pi/2) -- a Cylinder's axis is X: turn it up (its Right cap then faces up)
	table.insert(list,{name="NestMound",shape="cylinder",size=Vector3.new(.42,3.5,3.5),cf=CFrame.new(0,.21,0)*up,color="mound",
		texture={"twigs",CURVED,2.4,1.2,0},shadow=true})
	for k=0,7 do
		local a=rad(22.5+45*k)
		local even=k%2==0
		local r,y=if even then 1.42 else 1.50,if even then .56 else .62
		table.insert(list,{name="NestRim"..(k+1),shape="cylinder",size=Vector3.new(1.30,.66,.66),
			cf=CFrame.new(math.sin(a)*r,y,math.cos(a)*r)*CFrame.Angles(0,a,0)*CFrame.Angles(0,0,rad(if even then 7 else -7)),
			color="rim"..(k%3+1),texture={"twigs",CURVED,2.4,1.2,.37*k}})
	end
	table.insert(list,{name="NestStraw",shape="cylinder",size=Vector3.new(.30,2.36,2.36),cf=CFrame.new(0,.55,0)*up,color="straw",
		decal={"bed",{Face.Right}}})
	for k=0,5 do
		local a=rad(15+60*k)
		table.insert(list,{name="NestFringe"..(k+1),shape="plate",size=Vector3.new(1.9,1.05,.04),
			cf=CFrame.new(math.sin(a)*1.62,.78,math.cos(a)*1.62)*CFrame.Angles(0,a,0)*CFrame.Angles(0,rad(if k%2==0 then 8 else -8),0)
				*CFrame.Angles(rad(22),0,0),decal={"fringe",BOTH}})
	end
	for k=0,2 do
		local a=rad(40+120*k)
		table.insert(list,{name="NestTuft"..(k+1),shape="plate",size=Vector3.new(1.3,.62,.04),
			cf=CFrame.new(math.sin(a)*1.05,.98,math.cos(a)*1.05)*CFrame.Angles(0,a,0)*CFrame.Angles(rad(15),0,0),decal={"wisps",BOTH}})
	end
	table.insert(list,{name="NestSignPost",shape="block",size=Vector3.new(.14,1.5,.14),cf=CFrame.new(-1.95,.75,-.95),color="post",wood=true})
	table.insert(list,{name="NestSign",shape="block",size=Vector3.new(1.3,.8,.08),
		cf=CFrame.new(-1.95,1.45,-1.03)*CFrame.Angles(0,rad(-20),0)*CFrame.Angles(rad(6),0,0),color="board",wood=true,
		decal={"sign",{Face.Front}},sign=true})
	return list
end
-- The sign's words: "{pet}'s egg" for the pet stored at land, "Your egg" without a name.
function Client.signText(view)
	local name=Client.petName(view)
	if name then return UICopy.get("onb3.nest.sign",{pet=name})end
	return UICopy.get("onb3.nest.signPlain")
end

-- ── Instances ────────────────────────────────────────────────────────────────────────────────────────────────────
local function inert(p)
	p.Anchored=true
	p.CanCollide=false;p.CanQuery=false -- CanQuery only goes false once CanCollide is
	p.CanTouch=false;p.CastShadow=false
	p.Massless=true
	return p
end
local function make(class,parent,props)
	local object=Instance.new(class)
	for key,value in pairs(props or {})do object[key]=value end
	object.Parent=parent
	return object
end
local function corner(parent)make("UICorner",parent,{CornerRadius=UDim.new(1,0)})end
local function label(parent,name,size,color)
	return make("TextLabel",parent,{Name=name,BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Font=Enum.Font.FredokaOne,
		TextSize=size,TextColor3=color,TextWrapped=false})
end

function Client.mount(deps)
	if not Onboard.ceiling()then return nil end
	local self=setmetatable({d=deps,isOpen=false,connections={},clock=0,pinged={},beats={}},Client)
	self.world=deps.world or workspace
	self.now=deps.now or function()return workspace:GetServerTimeNow()end
	self.changed=Onboard.changed("nest"):Connect(function()self:sync()end)
	self:sync()
	return self
end
function Client:sync()
	local on=not self.dead and Onboard.on("nest")
	if on==self.isOpen then return end
	if on then
		local ok,problem=pcall(self.open,self)
		if not ok then warn("[Nest] not opened: "..tostring(problem));self.dead=true;pcall(self.close,self)end
	else self:close()end
end
function Client:open()
	self.isOpen=true
	self.synced=false
	local d=self.d
	-- Per-frame work only while on (off: the switch is watched, nothing else).
	if d.step~=false and not self.beat then
		self.beat=RunService.Heartbeat:Connect(function(dt)
			local ok,problem=pcall(self.step,self,dt)
			if not ok then warn("[Nest] "..tostring(problem));self.dead=true;pcall(self.close,self)end
		end)
	end
	local function on(signal,fn)table.insert(self.connections,signal:Connect(fn))end
	local function receive(packet)
		local ok,problem=pcall(self.receive,self,packet)
		if not ok then warn("[Nest] "..tostring(problem))end
	end
	local function bind(remote)
		if not self.isOpen then return end
		if remote.Name==Client.Event and not self.eventRemote then
			self.eventRemote=remote;on(remote.OnClientEvent,receive)
		elseif remote.Name==Client.Claim and not self.claimRemote then
			self.claimRemote=remote
		else return end
		self:ask()
	end
	for _,name in ipairs({Client.Event,Client.Claim})do
		local remote=d.remotes:FindFirstChild(name)
		if remote then bind(remote)end
	end
	on(d.remotes.ChildAdded,bind)
	local player=d.player
	if player==nil then player=game:GetService("Players").LocalPlayer end
	if player and player.CharacterAdded then on(player.CharacterAdded,function()self.synced=false;self:ask()end)end
end
function Client:ask()
	if self.synced or not self.isOpen or not self.eventRemote or not self.claimRemote then return end
	self.synced=true
	self.claimRemote:FireServer({kind="sync"})
end
function Client:send(kind)
	if not self.claimRemote then return false end
	self.claimRemote:FireServer({kind=kind})
	return true
end
function Client:clear()
	if self.folder then self.folder:Destroy();self.folder=nil end
	self.signWords=nil
	if self.chip then self.chip.button:Destroy();self.chip=nil end
	self.view,self.drawn,self.egg,self.hatching,self.waiting,self.queued,self.tuck=nil,nil,nil,nil,nil,nil,nil
	table.clear(self.beats)
end
function Client:close()
	self.isOpen=false
	if self.beat then self.beat:Disconnect();self.beat=nil end
	for _,connection in ipairs(self.connections)do connection:Disconnect()end
	table.clear(self.connections)
	self:clear()
	self.eventRemote,self.claimRemote,self.synced=nil,nil,false
end
function Client:destroy()
	if self.destroyed then return end
	self.destroyed=true;self.dead=true
	self.changed:Disconnect()
	self:close()
end
function Client:play(name,speed,volume)
	local audio=self.d.audio
	if audio then pcall(audio.play,audio,name,speed or 1,volume or .5)end
end
function Client:reduced()return self.d.reduced~=nil and self.d.reduced()==true end

-- Packets -------------------------------------------------------------------------------------------------------
function Client:receive(packet)
	if type(packet)~="table"or not self.isOpen then return end
	if packet.kind=="state"then
		local view=Client.parse(packet.public)
		if self.hatching then self.queued={view=view};return end -- the new egg lands when the hatch is over
		self:set(view)
	elseif packet.kind=="claimed"then
		self:claimed(type(packet.receipt)=="table"and packet.receipt or {})
	elseif packet.kind=="refused"then
		if packet.of=="claim"then
			self.waiting=nil
			self.promptAfter=self.clock+Client.BusyWait
		end
		-- A tuck refused as "Tucked" undoes nothing (it is tucked); any other refusal (Lost, Off, Busy...) gives Tuck in back.
		if packet.of=="tuck"and packet.reason~="Tucked"then self.tuck=nil end
	end
end
-- A new view: drawn on first sight (no tween), moved on, or everything goes (nil).
function Client:set(view,landing)
	if view==nil then self:clear();return end
	local before=self.view
	self.view=view
	if before and(before.at~=view.at or before.n~=view.n)then self.tuck,self.waiting=nil,nil end
	if not self.drawn then self:draw()end
	self:paintSign()
	if landing then
		self.drop={t=0}
		self:play("land",1,.5)
		self:say(UICopy.get(Client.Copy.next,{hours=Nest.Hours}),Client.NextLabel)
		self.shownScale=nil
	end
	self:paint(true)
end

-- Drawing -------------------------------------------------------------------------------------------------------
-- The sign's words, written only when they change (the pet stored at land).
function Client:paintSign()
	local words=self.signWords
	if not words or not self.view then return end
	local text=Client.signText(self.view)
	if words.Text~=text then words.Text=text end
end
function Client:groundY()
	local y=Client.Spot.Y
	local ground=self.d.ground
	if ground then
		local ok,hit=pcall(ground,Client.Spot)
		-- Only the lawn: a hit far from the walk map's ground is a pet, a player or a prop standing there.
		if ok and finite(hit)and math.abs(hit-Client.Spot.Y)<=Client.GroundSlack then y=hit end
	end
	return y
end
function Client:draw()
	local folder=make("Folder",self.world,{Name=Client.Folder})
	self.folder=folder
	self.root=Client.frame(self:groundY())
	for _,spec in ipairs(Client.parts())do
		local p=inert(make("Part",nil,{Name=spec.name}))
		p.Material=if spec.wood then Enum.Material.Wood else Enum.Material.SmoothPlastic
		p.Size=spec.size
		p.CFrame=self.root*spec.cf
		if spec.shadow then p.CastShadow=true end -- the mound alone: the nest sits on the marble
		if spec.shape=="plate"then p.Transparency=1 else p.Color=Client.Color[spec.color]end
		if spec.shape=="cylinder"then p.Shape=Enum.PartType.Cylinder end
		local texture=spec.texture
		if texture then
			local id=LifeArt.id(Client.Art[texture[1]])
			for _,face in ipairs(texture[2])do
				make("Texture",p,{Name="Twigs",Texture=id,Face=face,StudsPerTileU=texture[3],StudsPerTileV=texture[4],OffsetStudsU=texture[5]})
			end
		end
		local decal=spec.decal
		local id=decal and LifeArt.id(Client.Art[decal[1]])
		if id then
			for _,face in ipairs(decal[2])do make("Decal",p,{Name="Art",Texture=id,Face=face})end
		end
		if spec.sign then
			-- The pet's name on the board's right 62%; the burnt crescent is in the texture at the left.
			local gui=make("SurfaceGui",p,{Name="Words",Face=Face.Front,SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud,
				PixelsPerStud=50,LightInfluence=1,AlwaysOnTop=false,ClipsDescendants=true})
			local words=make("TextLabel",gui,{Name="Name",BackgroundTransparency=1,Position=UDim2.fromScale(.34,.14),
				Size=UDim2.fromScale(.63,.72),Font=Enum.Font.FredokaOne,TextColor3=Client.Color.signInk,TextScaled=true,
				TextWrapped=true,Text=""})
			make("UITextSizeConstraint",words,{MaxTextSize=22})
			self.signWords=words
		end
		p.Parent=folder
	end
	-- The egg: an invisible anchor at its base carries the halo, the label, the light and the emitters; the shells
	-- (or a lilac ball until the meshes load) are posed from it every frame.
	local anchor=inert(make("Part",nil,{Name="SleepyEgg",Transparency=1,Size=Vector3.new(.2,.2,.2)}))
	anchor.CFrame=self.root*CFrame.new(0,Client.EggBase,0)
	anchor.Parent=folder
	local egg={anchor=anchor,shells={}}
	-- A Ball part is always round: a block with a sphere mesh stretches to the egg's 1 x 1.3.
	egg.ball=inert(make("Part",nil,{Name="SleepyEggBody",Color=Client.Color.egg,Material=Enum.Material.SmoothPlastic,
		Size=Vector3.new(1,1.3,1)}))
	make("SpecialMesh",egg.ball,{Name="Shape",MeshType=Enum.MeshType.Sphere})
	egg.ball.Parent=folder
	egg.halo=make("BillboardGui",anchor,{Name="Halo",LightInfluence=0,AlwaysOnTop=false,MaxDistance=120,Enabled=false})
	egg.haloImage=make("ImageLabel",egg.halo,{Name="Glow",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image=Client.Assets.halo,
		ImageColor3=Client.Color.halo,ImageTransparency=1})
	egg.light=make("PointLight",anchor,{Name="Glow",Range=6,Brightness=.4,Color=Client.Color.halo,Enabled=false,Shadows=false})
	egg.zzz=make("ParticleEmitter",anchor,{Name="Zzz",Texture=Client.Assets.z,Rate=0,Lifetime=NumberRange.new(2.2),Speed=NumberRange.new(.6),
		Rotation=NumberRange.new(-12,12),LightInfluence=0,Acceleration=Vector3.new(.25,0,0),EmissionDirection=Enum.NormalId.Top,
		Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.35),NumberSequenceKeypoint.new(1,.6)}),
		Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.09,0),NumberSequenceKeypoint.new(.73,0),NumberSequenceKeypoint.new(1,1)})})
	egg.sparks=make("ParticleEmitter",anchor,{Name="Sparks",Texture=Client.Spark,Rate=0,Lifetime=NumberRange.new(.6,1),Speed=NumberRange.new(.6,1.4),
		SpreadAngle=Vector2.new(180,180),LightEmission=1,LightInfluence=0,Color=ColorSequence.new(Client.Color.gold),
		Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.25),NumberSequenceKeypoint.new(1,0)})})
	egg.stillZ=make("BillboardGui",anchor,{Name="StillZ",LightInfluence=0,AlwaysOnTop=false,MaxDistance=80,Enabled=false,Size=UDim2.fromOffset(20,20)})
	make("ImageLabel",egg.stillZ,{Name="Z",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image=Client.Assets.z})
	-- The label: a cream pill (gold when ready) with the clock; near, a second line with what is inside.
	local board=make("BillboardGui",anchor,{Name="Label",LightInfluence=0,AlwaysOnTop=true,MaxDistance=60,Size=UDim2.fromOffset(240,62),Enabled=true})
	local pill=make("Frame",board,{Name="Pill",AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,0),Size=UDim2.fromOffset(160,28),
		BackgroundColor3=Client.Color.cream,BorderSizePixel=0})
	corner(pill)
	egg.pillStroke=make("UIStroke",pill,{Color=Client.Color.ink,Thickness=2})
	egg.clock=label(pill,"Clock",14,Client.Color.ink)
	-- Near (Client.Near): what is inside, in its own cream pill 4 px under the clock (Fable R1; "Egg n of 7" stays
	-- on the gift tile, not here).
	local insidePill=make("Frame",board,{Name="InsidePill",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,32),Size=UDim2.fromOffset(200,24),
		BackgroundColor3=Client.Color.cream,BorderSizePixel=0,Visible=false})
	corner(insidePill)
	make("UIStroke",insidePill,{Color=Client.Color.ink,Thickness=2})
	egg.inside=label(insidePill,"Inside",13,Client.Color.ink)
	egg.board,egg.pill,egg.insidePill=board,pill,insidePill
	-- The prompt, at the front of the nest (where the Bear's prints end).
	local spot=inert(make("Part",nil,{Name="SleepyNestPrompt",Transparency=1,Size=Vector3.new(.2,.2,.2)}))
	spot.CFrame=self.root*CFrame.new(Client.PromptAt)
	spot.Parent=folder
	egg.prompt=make("ProximityPrompt",spot,{Name="NestPrompt",ObjectText=UICopy.get(Client.Copy.title),ActionText=UICopy.get("onb3.nest.tuck"),
		HoldDuration=0,MaxActivationDistance=Client.Prompt,RequiresLineOfSight=false,Enabled=false,UIOffset=Client.PromptOffset})
	local triggered=egg.prompt.Triggered
	if typeof(triggered)=="RBXScriptSignal"then
		table.insert(self.connections,triggered:Connect(function()
			local ok,problem=pcall(self.act,self)
			if not ok then warn("[Nest] "..tostring(problem))end
		end))
	end
	self.egg=egg
	self.drawn=true
	self:meshes()
end
-- The real shells (the existing egg mesh with the Sleepy ColorMap) take the ball's place once they load.
function Client:meshes()
	local egg=self.egg
	if not egg or egg.mesh or not self.d.meshes then return end
	local ok,parts=pcall(self.d.meshes)
	if not ok or type(parts)~="table"or not parts.TopShell or not parts.BottomShell then return end
	for _,key in ipairs({"BottomShell","TopShell","Core"})do
		local part=parts[key]
		if part then
			inert(part)
			part.Name="SleepyEgg"..key
			if key=="Core"then part.Material=Enum.Material.Neon;part.Color=Client.Color.core;part.Transparency=1;part.TextureID=""
			else part.Material=Enum.Material.SmoothPlastic;part.TextureID=Client.Assets.egg end
			part.Parent=self.folder
			egg.shells[key]=part
		end
	end
	egg.mesh=true
	if egg.ball then egg.ball:Destroy();egg.ball=nil end
end
-- The prompt, the label and the chip; `fresh` writes everything.
function Client:paint(fresh)
	local view,egg=self.view,self.egg
	if not view or not egg then return end
	local now=self.now()
	local left=Client.left(view,now)
	local look=Client.look(view,now)
	self.lookNow=look
	if fresh or self.paintedLook~=look then
		if self.paintedLook and self.paintedLook~=look and not fresh then self.stage={from=self.shownScale or Client.Scale[look],t=0}end
		self.paintedLook=look
	end
	local text=Client.clock(left)
	local hold=self.labelUntil and self.clock<self.labelUntil
	if hold then text=self.labelText end
	if egg.clock.Text~=text then egg.clock.Text=text end
	local ready=look=="ready"and not hold
	egg.pill.BackgroundColor3=if ready then Client.Color.stars else Client.Color.cream
	egg.pill.Size=UDim2.fromOffset(math.max(120,math.min(236,#text*8+28)),28)
	local textSize=if self.d.compact and self.d.compact()==true then 13 else 14
	egg.clock.TextSize=textSize
	-- The second line changes only with the egg: worked out once per view. The explainer wraps (two lines on a
	-- phone); the board grows to hold it.
	if egg.insideFor~=view then
		egg.insideFor=view
		local text,kind=Client.secondLine(view)
		egg.secondKind=kind
		egg.inside.Text=text
		local inner=Client.SecondWidth-24
		local textW=math.ceil(self:measure(text,Client.SecondSize))
		local lines=if textW<=inner then 1 else math.ceil(textW*1.15/inner)
		local h=if lines==1 then 24 else lines*16+8
		egg.inside.TextWrapped=lines>1
		egg.insidePill.Size=UDim2.fromOffset(if lines==1 then textW+24 else Client.SecondWidth,h)
		egg.board.Size=UDim2.fromOffset(240,38+h)
	end
	-- Tuck in while it grows (once per egg), Hatch when it is ready; nothing while a hatch is asked for or playing.
	local action=nil
	if look=="ready"then action="hatch"elseif not view.tucked and not self.tuck then action="tuck"end
	local free=(self.d.free==nil or self.d.free()==true)and(self.d.busy==nil or self.d.busy()~=true)
	local enabled=action~=nil and free and not self.waiting and not self.hatching and self.clock>=(self.promptAfter or -math.huge)
	self.action=action
	local actionText=UICopy.get(if action=="hatch"then "onb3.nest.hatch"else "onb3.nest.tuck")
	if egg.prompt.ActionText~=actionText then egg.prompt.ActionText=actionText end
	if egg.prompt.Enabled~=enabled then egg.prompt.Enabled=enabled end
	self:paintChip(left,look)
end

-- The HUD chip: the nest icon and the clock; gold when ready. A tap lays the Show me trail. It sits above the garden
-- dock, right-aligned with it and never wider: the dock's own row (left of it) is the save notice and feedback line
-- (PetFocusUI), so the two never meet. In the Pet Park the lane above the dock is the Throw button's: the chip hides.
Client.ChipGap=8
Client.ChipIconGap=6
function Client.chipWidth(iconSize,textW)return math.ceil(10+iconSize+Client.ChipIconGap+textW+12)end
-- Pure: the chip's rect for a dock rect {x, y, w, h} (screen px), `w` wide and `hit` tall.
function Client.chipRect(dock,w,hit)
	w=math.min(w,dock.w)
	return{x=dock.x+dock.w-w,y=dock.y-Client.ChipGap-hit,w=w,h=hit}
end
function Client:measure(text,size)
	if self.d.measure then
		local ok,w=pcall(self.d.measure,text,size)
		if ok and finite(w)then return w end
	end
	return #text*size*.6
end
function Client:paintChip(left,look)
	local host=self.d.chipHost and self.d.chipHost()
	if not host then
		if self.chip then self.chip.button:Destroy();self.chip=nil end
		return
	end
	local compact=self.d.compact and self.d.compact()==true
	local chip=self.chip
	if not chip or chip.host~=host or chip.compact~=compact then
		if chip then chip.button:Destroy()end
		chip=self:buildChip(host,compact)
		self.chip=chip
	end
	local text,kind=Client.chipText(left)
	local ready=kind=="ready"
	if chip.label.Text~=text then chip.label.Text=text end
	-- The moon icon alone did not name the thing: the chip's accessible label is the explainer (O1).
	local named=Client.how(self.view)
	if chip.button:GetAttribute("AccessibleLabel")~=named then chip.button:SetAttribute("AccessibleLabel",named)end
	if chip.ready~=ready then
		chip.ready=ready
		chip.pill.BackgroundColor3=if ready then Client.Color.stars else Client.Color.well
		chip.label.TextColor3=if ready then Client.Color.ink else Client.Color.text
		chip.stroke.Color=if ready then Client.Color.gold else Client.Color.ink
	end
	-- Measured only when the words change (once a minute at most).
	if chip.measured~=text then
		chip.measured=text
		local dockW=host.AbsoluteSize and host.AbsoluteSize.X
		local size=chip.textSize
		local w=Client.chipWidth(chip.iconSize,self:measure(text,size))
		if typeof(dockW)=="number"and dockW>0 and w>dockW then size=12;w=math.min(dockW,Client.chipWidth(chip.iconSize,self:measure(text,size)))end
		chip.label.TextSize=size
		chip.width=w
		chip.button.Size=UDim2.fromOffset(w,chip.hit)
		local iconW=chip.iconSize+Client.ChipIconGap
		chip.label.Position=UDim2.fromOffset(10+iconW,0);chip.label.Size=UDim2.new(1,-(10+iconW),1,0)
	end
	chip.button.Visible=not(self.d.chipHidden and self.d.chipHidden()==true)
	local bob=if ready and not self:reduced()then math.floor(2*math.sin(self.clock*1.2*2*math.pi)+.5)else 0
	chip.icon.Position=UDim2.new(0,10,.5,-bob)
end
function Client:buildChip(host,compact)
	local pillH=if compact then 26 else 30
	local hit=if compact then 44 else 36
	local iconSize=if compact then 18 else 22
	local textSize=if compact then 13 else 14
	local button=make("TextButton",host,{Name="NestChip",Text="",AutoButtonColor=false,BackgroundTransparency=1,
		AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,0,0,-Client.ChipGap),Size=UDim2.fromOffset(92,hit),Selectable=false,ZIndex=10})
	button:SetAttribute("AccessibleLabel",if self.view then Client.how(self.view)else UICopy.get(Client.Copy.title))
	local pill=make("Frame",button,{Name="Pill",AnchorPoint=Vector2.new(0,.5),Position=UDim2.fromScale(0,.5),Size=UDim2.new(1,0,0,pillH),
		BackgroundColor3=Client.Color.well,BorderSizePixel=0,ZIndex=10})
	corner(pill)
	local stroke=make("UIStroke",pill,{Color=Client.Color.ink,Thickness=2})
	local icon=make("ImageLabel",pill,{Name="NestIcon",BackgroundTransparency=1,Image=Client.Assets.chip,AnchorPoint=Vector2.new(0,.5),
		Position=UDim2.new(0,10,.5,0),Size=UDim2.fromOffset(iconSize,iconSize),ZIndex=11})
	local text=label(pill,"Clock",textSize,Client.Color.text)
	text.ZIndex=11;text.TextXAlignment=Enum.TextXAlignment.Left;text.AutoLocalize=true
	local chip={host=host,compact=compact,button=button,pill=pill,stroke=stroke,icon=icon,label=text,hit=hit,iconSize=iconSize,textSize=textSize}
	local activated=button.Activated
	if typeof(activated)=="RBXScriptSignal"then
		activated:Connect(function()if self.d.show then pcall(self.d.show)end end)
	end
	return chip
end

-- Actions ---------------------------------------------------------------------------------------------------------
-- The prompt (or a spec): Tuck in or Hatch.
function Client:act()
	if not self.isOpen or not self.view or self.waiting or self.hatching then return false end
	if self.action=="tuck"then
		if not self:send("tuck")then return false end
		self.tuck={t=0,first=self.view.n==0}
		self:play("pet_coo_1",.85,.35)
		if self.egg then pcall(function()self.egg.zzz:Emit(3)end)end
		self:peek()
		return true
	elseif self.action=="hatch"then
		if not self:send("claim")then return false end
		self.waiting={t=0}
		return true
	end
	return false
end
-- The gift peek over the egg on Tuck in: what is inside, and its Stars.
function Client:peek()
	local egg,view=self.egg,self.view
	if not egg or not view then return end
	local board=make("BillboardGui",egg.anchor,{Name="GiftPeek",LightInfluence=0,AlwaysOnTop=true,MaxDistance=60,Size=UDim2.fromOffset(120,96)})
	local tile=make("Frame",board,{Name="Tile",AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,0),Size=UDim2.fromOffset(96,72),
		BackgroundColor3=Client.Color.cream,BorderSizePixel=0})
	make("UICorner",tile,{CornerRadius=UDim.new(0,12)})
	make("UIStroke",tile,{Color=Client.Color.ink,Thickness=2})
	local name=Client.itemName(view.gift.kind,view.gift.item,view.pet)
	local item=label(tile,"Item",14,Client.Color.ink)
	item.Text=name or "★";item.TextWrapped=true
	item.Size=UDim2.new(1,0,1,-18)
	-- "Egg n of 7" lives here in the welcome week (not on the world label).
	local count=label(tile,"Count",12,Client.Color.ink)
	count.Position=UDim2.new(0,0,1,-20);count.Size=UDim2.new(1,0,0,16)
	count.Text=if view.egg<=Nest.WeekLength then UICopy.get("onb3.nest.count",{count=view.egg})else ""
	local chip=make("Frame",board,{Name="Stars",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,70),Size=UDim2.fromOffset(56,22),
		BackgroundColor3=Client.Color.stars,BorderSizePixel=0})
	corner(chip)
	local stars=label(chip,"Count",14,Client.Color.ink);stars.Text="+"..view.gift.stars;stars.AutoLocalize=false
	board.StudsOffset=Vector3.new(0,(self.shownScale or 1.25)*1.3+1.6,0)
	table.insert(self.beats,{kind="peek",board=board,t=0,parts={tile,chip},labels={item,count,stars}})
end
-- The label holds `text` for `seconds` (Sleep tight, A new egg is growing), then the clock again.
function Client:say(text,seconds)
	self.labelText=text
	self.labelUntil=self.clock+seconds
end
-- The hatch, only once the save has it: the reward shows only now.
function Client:claimed(receipt)
	if not self.view or not self.egg then return end
	self.waiting=nil
	self.hatching={t=0,receipt=receipt,rewarded=false,popped=false}
	self:play("hatch_rise",1,.6)
end
function Client:reward(receipt)
	local stars=if int(receipt.stars)then receipt.stars else 0
	local kind=receipt.kind
	local name=if kind~="stars"then Client.itemName(kind,receipt.item,receipt.pet)else nil
	if name and self.d.toast then pcall(self.d.toast,UICopy.get("onb3.nest.got",{item=name}),stars)end
	if stars>0 then self:float(stars)end
	self:play("snack_boost_sparkle",1,.7)
	self.rewarded=(self.rewarded or 0)+1
end
-- "+N" with the Star floats up from the nest (the find's "+N Smarts" billboard, gold).
function Client:float(stars)
	local egg=self.egg
	if not egg then return end
	local board=make("BillboardGui",egg.anchor,{Name="StarsGain",LightInfluence=0,AlwaysOnTop=true,MaxDistance=80,Size=UDim2.fromOffset(180,40),
		StudsOffset=Vector3.new(0,2.6,0)})
	local text=label(board,"Text",28,Client.Color.stars)
	text.TextScaled=true;text.TextStrokeColor3=Color3.fromHex("#5A3A12");text.TextStrokeTransparency=.35;text.Text="+"..stars.." ★";text.AutoLocalize=false
	table.insert(self.beats,{kind="float",board=board,label=text,t=0})
end

-- ── Per frame ──────────────────────────────────────────────────────────────────────────────────────────────────────
function Client:step(dt)
	if self.isOpen and not Onboard.on("nest")then self:close()end -- off: gone within the frame, whatever the signal does
	if not self.isOpen then return end
	self.clock+=dt
	if self.labelUntil and self.clock>=self.labelUntil then self.labelUntil,self.labelText=nil,nil end
	self:stepBeats(dt)
	if not self.view or not self.egg then return end
	if not self.egg.mesh then self:meshes()end
	if self.waiting then
		self.waiting.t+=dt
		if self.waiting.t>=Client.Pending then self.waiting=nil;self.synced=false;self:ask()end
	end
	self:paint(false)
	self:pose(dt)
	self:ping()
end
function Client:stepBeats(dt)
	local reduced=self:reduced()
	for index=#self.beats,1,-1 do
		local beat=self.beats[index]
		beat.t+=dt
		local done=false
		if beat.kind=="peek"then
			local fade=if beat.t<.2 then 1-beat.t/.2 elseif beat.t<2.2 then 0 else math.min(1,(beat.t-2.2)/.3)
			for _,part in ipairs(beat.parts)do part.BackgroundTransparency=fade end
			for _,text in ipairs(beat.labels)do text.TextTransparency=fade end
			done=beat.t>=2.5
		elseif beat.kind=="float"then
			if not reduced then beat.board.StudsOffset=Vector3.new(0,2.6+math.min(1,beat.t/1.4)*1.6,0)end
			local fade=math.clamp((beat.t-.77)/.63,0,1)
			beat.label.TextTransparency=fade;beat.label.TextStrokeTransparency=.35+.65*fade
			done=beat.t>=1.4
		end
		if done then beat.board:Destroy();table.remove(self.beats,index)end
	end
end
-- The egg's scale, rock, hop and glow for this frame, plus the tuck, hatch and drop moments.
function Client:pose(dt)
	local egg,view=self.egg,self.view
	local look=self.lookNow or "small"
	local reduced=self:reduced()
	local target=Client.Scale[look]
	local scale=target
	if self.stage and not reduced then
		self.stage.t+=dt
		local p=math.min(1,self.stage.t/Client.StageTween)
		scale=self.stage.from+(target-self.stage.from)*Client.backOut(p)
		if p>=1 then self.stage=nil end
	else self.stage=nil end
	self.shownScale=scale
	local breath,rock,hop,squash,halo=Client.motion(look,self.clock,reduced)
	local lean,sink,haloBoost=0,0,0
	local tucked=view.tucked or self.tuck~=nil
	if tucked and not reduced then lean=6 end
	-- Tuck in: a 0.12 sink and back, the halo to 0.9 and back over 0.6 s.
	if self.tuck then
		self.tuck.t+=dt
		local t=self.tuck.t
		if t<.25 and not reduced then sink=-.12*math.sin(t/.25*math.pi)end
		if t<.6 then haloBoost=math.max(0,.9-halo)*(1-t/.6)end
		if t>=Client.TuckSeconds and not self.tuck.said then
			self.tuck.said=true
			if self.tuck.first then
				-- The first tuck-in ever: the longer line, and a rail toast so it is read with the camera on the Bear.
				local text=UICopy.get(Client.Copy.tuckedFirst,{hours=Nest.Hours})
				self:say(text,Client.TuckedFirstLabel)
				if self.d.toast then pcall(self.d.toast,text,nil)end
			else self:say(UICopy.get(Client.Copy.tucked),Client.TuckedLabel)end
		end
	end
	-- Waiting for the save: a fast rock on a loop.
	if self.waiting and not reduced then rock=14*math.sin(self.clock*6*2*math.pi);hop=0 end
	local top,bottomFade,core=0,0,nil
	if self.hatching then
		local h=self.hatching
		h.t+=dt
		local t=h.t
		if t<.5 and not reduced then rock=14*math.sin(t*6*2*math.pi);hop=0 end
		haloBoost=math.max(haloBoost,math.min(1,t/.5)*.3)
		if t>=.5 and not h.popped then
			h.popped=true
			pcall(function()egg.sparks:Emit(if reduced then 6 else 18)end)
			self:play("hatch",1,.7)
		end
		if t>=.5 then
			local p=math.min(1,(t-.5)/.4)
			top=if reduced then 0 else 1.2*math.sin(p*math.pi*.5)
			core=math.min(1,(t-.5)/.35)
		end
		if t>=.6 and not h.rewarded then h.rewarded=true;self:reward(h.receipt)end
		if t>=1.6 then bottomFade=math.min(1,(t-1.6)/.4)end
		if t>=Client.HatchSeconds then
			self.hatching=nil
			local queued=self.queued;self.queued=nil
			for _,part in pairs(egg.shells)do if part.Name~="SleepyEggCore"then part.Transparency=0 end end
			if queued then self:set(queued.view,queued.view~=nil)end
			return
		end
	end
	-- The new egg drops 1.5 studs onto the straw with one bounce.
	local drop=0
	if self.drop then
		self.drop.t+=dt
		local p=math.min(1,self.drop.t/Client.DropSeconds)
		drop=if reduced then 0 else 1.5*(1-p)*(1-p)-(if p>.7 then .08*math.sin((p-.7)/.3*math.pi)else 0)
		if p>=1 then self.drop=nil end
	end
	local s=scale*breath
	local frame=self.root*CFrame.new(0,Client.EggBase+sink+drop,0)
	if lean~=0 then
		local d=Vector3.new(Client.BearSpot.X,0,Client.BearSpot.Z).Unit
		frame=frame*CFrame.fromAxisAngle(Vector3.new(d.Z,0,-d.X),math.rad(lean))
	end
	frame=frame*CFrame.Angles(0,0,math.rad(rock))*CFrame.new(0,hop,0)*CFrame.Angles(0,math.pi,0) -- the face looks at the dais
	self:place(frame,s,squash,top,bottomFade,core)
	-- Glow, light, sparks, Zzz.
	local alpha=math.min(1,(halo or 0)+haloBoost)
	egg.halo.Enabled=alpha>0
	egg.halo.Size=UDim2.fromScale(2.6*s,2.6*s)
	egg.halo.StudsOffset=Vector3.new(0,.65*s,0)
	egg.haloImage.ImageTransparency=1-alpha
	egg.haloImage.ImageColor3=if look=="ready"then Client.Color.gold else Client.Color.halo
	egg.light.Enabled=look~="small"
	egg.sparks.Rate=if look=="ready"and not reduced then 6 else 0
	egg.board.StudsOffset=Vector3.new(0,1.3*s+.9,0)
	egg.stillZ.Enabled=reduced and look~="ready"
	egg.stillZ.StudsOffset=Vector3.new(.3,1.3*s+.3,0)
	local every=Client.ZzzEvery[look]
	if every and not reduced then
		if tucked then every/=2 end
		self.zzzAt=self.zzzAt or self.clock
		if self.clock>=self.zzzAt then
			self.zzzAt=self.clock+every
			pcall(function()egg.zzz:Emit(1)end)
		end
	end
	-- Near: the second line (what is inside, and the egg's number in the welcome week).
	local root=self.d.root and self.d.root()
	local near=root~=nil and(root-self.root.Position).Magnitude<=Client.Near
	egg.insidePill.Visible=near or egg.secondKind=="how"
	-- The pet focus (greeting) camera: no label, it would read as the Bear's speech.
	local focus=self.d.focus~=nil and self.d.focus()==true
	if egg.board.Enabled==focus then egg.board.Enabled=not focus end
end
function Client:place(frame,s,squash,top,bottomFade,core)
	local egg=self.egg
	if egg.mesh then
		for key,part in pairs(egg.shells)do
			local spec=Models[key]
			if spec then
				part.Size=Vector3.new(spec.size.X*s,spec.size.Y*s*squash,spec.size.Z*s)
				local lift=if key=="TopShell"then top else 0
				part.CFrame=frame*CFrame.new(spec.center.X*s,spec.center.Y*s*squash+lift,spec.center.Z*s)
				if key=="TopShell"and top>0 then part.Transparency=math.clamp((top-.6)/.6,0,1)end
				if key=="BottomShell"and bottomFade>0 then part.Transparency=bottomFade end
				if key=="Core"then
					part.Transparency=if core then .2+.8*core else 1
					if core then part.Size=part.Size*(1+1.4*core)end
				end
			end
		end
	elseif egg.ball then
		egg.ball.Size=Vector3.new(s,1.3*s*squash,s)
		egg.ball.CFrame=frame*CFrame.new(0,.65*s*squash+top*.2,0)
		egg.ball.Transparency=if top>0 then math.clamp(top/1.2,0,1)else 0
	end
end
-- The one soft ping when a ready egg comes within Nest.ReadyPing, once per egg.
function Client:ping()
	if self.lookNow~="ready"then return end
	local root=self.d.root and self.d.root()
	local key=tostring(self.view.at)..":"..tostring(self.view.n)
	if root and not self.pinged[key]and(root-self.root.Position).Magnitude<=Nest.ReadyPing then
		self.pinged[key]=true
		self:play("machine_attract",1,.35)
	end
end

-- What the rest of the client asks ---------------------------------------------------------------------------------
-- Where the Bear's prints end (the front of the nest), or nil while there is no nest drawn.
function Client:place3D()
	if not self.isOpen or not self.drawn or not self.view then return nil end
	return(self.root*CFrame.new(Client.PromptAt)).Position
end
-- {left, look, ready, kind, item, stars} for the strip, or nil.
function Client:summary()
	if not self.isOpen or not self.view then return nil end
	local now=self.now()
	local left=Client.left(self.view,now)
	return{left=left,look=Client.look(self.view,now),ready=left<=0,view=self.view}
end
return Client
