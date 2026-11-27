-- Onboarding v3 slice B: the need bubble over the Bear (ONBOARDING-V3-PLAN-2026-11-23 section 4 and the art table).
-- Beta (17) QA U7 (artifacts/qa-2026-11-25-beta17/CAPSULE-AND-HUD-LOOK.md section 4): a flat sticker, not a lit ball. A
-- billboard turns to the camera, so a drawn highlight turned with it and never agreed with the sun. Flat cream-white
-- fill, 2 px ink outline, a tail, and depth from a drawn lip (the same disc 3 px lower, ink at 25%, the Kit.tile lip):
-- no gradient, no gloss, no rotation (the press squash is scale only; the hop is a lift). One icon, no words: the flat
-- icons (artifacts/qa-2026-11-25-beta17/look/need-icons, two flat colours and an ink line) once their ids are in
-- IconIds; the emoji glyphs until then (they carry their own baked shine). BearNeeds decides what shows and when.
--
-- Studio QA (2026-11-23): the Bear shuttles between idle spots ~3 studs apart in its first minute, and the bubble jumped
-- ~60 px with it, so taps missed. Now:
--  * the hit area is HitSize px (over the 96 px asked for), a clear button round the 72 px bubble (the icon is unchanged);
--  * the bubble hangs on its own local anchor that follows the Bear on a spring (Bubble.follow): a move under Dead studs
--    is ignored, a bigger one is chased smoothly until it is within Settle, a jump over Snap studs (a teleport) snaps;
--  * a small key cap shows the keyboard or gamepad key (options.keyHint) that does the same as a tap.
-- Beta (37) note 2 ("tuck the egg in ui thing doesnt constantly follow the pet, it like waits and then catches up"):
-- that was the Dead zone and the spring above. The guide's worded bubble (Onboard "guide") is now pinned: the billboard
-- hangs on the pet's own part (the engine places it every rendered frame, so it never trails even a frame behind the
-- walk), its hop and the arrow's bounce on top. The icon-only bubble (guide off) keeps the spring, as before.
-- The bubble is gamepad-selectable. Fades in and out, pops in with a small hop and hops on the idle hint; Reduced Motion:
-- fades only, and the anchor follows at once (still ignoring small moves).
-- options: {parent = PlayerGui, adornee() -> the pet's part or nil, onTap(), reduced() -> bool, keyHint() -> text or nil,
--   world = where the anchor part lives (default workspace)}
local Bubble={};Bubble.__index=Bubble
Bubble.Glyph=table.freeze({hand="👋",ball="🎾",deck="🎮",moon="🌙",paws="🐾",egg="🥚"})
Bubble.IconIds=table.freeze({hand=125214220825448,ball=107242483076374,deck=83400081676425,moon=127648287993869,
 paws=80004221456977,egg=116751717038768}) -- flat icons (beta 17 U7), uploaded 2026-11-25; a glyph if one is missing
Bubble.Size=72        -- px, the drawn bubble
Bubble.HitSize=108    -- px, the tap target round it
Bubble.Lift=2.2       -- studs over the top of the pet
Bubble.Fade=.2
Bubble.HopTime=.45;Bubble.HopHeight=.6
Bubble.Dead=2         -- studs: the Bear moving less than this leaves the bubble where it is
Bubble.Settle=.15     -- studs: a chase ends this close
Bubble.Rate=3.5       -- the spring: about 1 - e^(-Rate dt) of the way each frame
Bubble.Snap=30        -- studs: further than this is a teleport, the bubble snaps
Bubble.Press=table.freeze({low=.88,down=.06,rate=8,wobble=18}) -- beta 14 B3b: the squash a taken tap gives
Bubble.Ink=Color3.fromHex("#24304F")
Bubble.Fill=Color3.fromHex("#FFFDF6") -- U7: flat cream-white, no shading
Bubble.Lip=table.freeze({drop=3,opacity=.25}) -- U7: px below the face, ink opacity
-- Onboarding v2 step 5 (the guide, ONBOARDING-V2.md): a white pill with the words in ink, a gold arrow (6 px at 1 Hz,
-- still under Reduced Motion).
Bubble.WordFill=Color3.fromHex("#FFFFFF");Bubble.WordInk=Color3.fromHex("#1B2A4A");Bubble.Arrow=Color3.fromHex("#FFD86B")
Bubble.WordSize=20;Bubble.WordH=60;Bubble.ArrowPx=6;Bubble.ArrowHz=1
-- Pure: the pill's width for these words (measure(text) -> px, else an estimate).
function Bubble.wordWidth(text,measure)
	local w=if type(measure)=="function"then measure(text)else #text*Bubble.WordSize*.55
	return math.ceil(62+w+16)
end

-- Pure: where the bubble hangs now. state = {at, chasing} (kept by the caller), target = over the Bear now.
function Bubble.follow(state,target,dt,reduced)
	if typeof(target)~="Vector3"then return state.at end
	local at=state.at
	if typeof(at)~="Vector3"then state.at,state.chasing=target,false;return target end
	local gap=(target-at).Magnitude
	if gap>=Bubble.Snap then state.at,state.chasing=target,false;return target end
	if not state.chasing then
		if gap<Bubble.Dead then return at end
		state.chasing=true
	end
	if reduced then state.at,state.chasing=target,false;return target end
	local step=1-math.exp(-Bubble.Rate*math.max(0,dt or 0))
	at=at:Lerp(target,step)
	if(target-at).Magnitude<=Bubble.Settle then at,state.chasing=target,false end
	state.at=at
	return at
end

-- Pure (beta 37 note 2): does the bubble hang on the pet itself (words shown) rather than on the sprung anchor?
function Bubble.pinned(words)return type(words)=="string"and words~=""end
-- Pure (beta 14 B3b): does a screen tap at `tap` land on a bubble drawn round `centre` (both Vector2, px)?
function Bubble.hits(tap,centre)
	if typeof(tap)~="Vector2"or typeof(centre)~="Vector2"then return false end
	return(tap-centre).Magnitude<=Bubble.HitSize*.5
end
-- Pure: the press squash `t` seconds after a taken tap (1 at rest), nil once it has settled.
function Bubble.pressScale(t)
	local P=Bubble.Press
	if type(t)~="number"or t<0 then return nil end
	if t<P.down then return 1-(1-P.low)*(t/P.down)end
	local k=t-P.down
	local s=1-(1-P.low)*math.exp(-k*P.rate)*math.cos(k*P.wobble)
	if k>.6 then return nil end
	return s
end

function Bubble.new(options)
	options=options or {}
	local self=setmetatable({options=options,alpha=1,target=1,hopAt=nil,time=0,spot={}},Bubble)
	local anchor=Instance.new("Part")
	anchor.Name="EggDropNeedAnchor";anchor.Size=Vector3.new(.2,.2,.2);anchor.Transparency=1
	anchor.Anchored,anchor.CanCollide,anchor.CanQuery,anchor.CanTouch,anchor.CastShadow,anchor.Massless=true,false,false,false,false,true
	local gui=Instance.new("BillboardGui")
	gui.Name="EggDropNeedBubble";gui.Adornee=anchor;gui.Size=UDim2.fromOffset(Bubble.HitSize,Bubble.HitSize)
	gui.AlwaysOnTop=true;gui.Active=true;gui.LightInfluence=0;gui.ResetOnSpawn=false;gui.Enabled=false;gui.MaxDistance=140
	gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
	-- The drawn bubble, centred in the hit area, its tail below it.
	local art=Instance.new("Frame")
	art.Name="Art";art.AnchorPoint=Vector2.new(.5,.5);art.Position=UDim2.new(.5,0,.5,-6);art.Size=UDim2.fromOffset(Bubble.Size,Bubble.Size)
	art.BackgroundColor3=Bubble.Fill;art.BorderSizePixel=0;art.ZIndex=2;art.Parent=gui
	-- U7: the lip, a sibling drawn under the face (a child would draw over it), 3 px lower; it squashes with the face.
	local lip=Instance.new("Frame")
	lip.Name="Lip";lip.AnchorPoint=art.AnchorPoint;lip.Position=art.Position+UDim2.fromOffset(0,Bubble.Lip.drop);lip.Size=art.Size
	lip.BackgroundColor3=Bubble.Ink;lip.BackgroundTransparency=1-Bubble.Lip.opacity;lip.BorderSizePixel=0;lip.ZIndex=1;lip.Parent=gui
	local lipCorner=Instance.new("UICorner");lipCorner.CornerRadius=UDim.new(.5,0);lipCorner.Parent=lip
	local lipSquash=Instance.new("UIScale");lipSquash.Name="PressScale";lipSquash.Scale=1;lipSquash.Parent=lip
	local tail=Instance.new("Frame")
	tail.Name="Tail";tail.AnchorPoint=Vector2.new(.5,.5);tail.Position=UDim2.new(.5,0,1,-3);tail.Size=UDim2.fromOffset(16,16)
	tail.Rotation=45;tail.BackgroundColor3=Bubble.Fill;tail.BorderSizePixel=0;tail.ZIndex=1;tail.Parent=art
	local tailEdge=Instance.new("UIStroke");tailEdge.Color=Bubble.Ink;tailEdge.Thickness=2;tailEdge.Parent=tail
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(.5,0);corner.Parent=art
	local edge=Instance.new("UIStroke");edge.Color=Bubble.Ink;edge.Thickness=2;edge.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;edge.Parent=art
	local icon=Instance.new("TextLabel")
	icon.Name="Icon";icon.AnchorPoint=Vector2.new(.5,.5);icon.Position=UDim2.fromScale(.5,.54);icon.Size=UDim2.fromScale(.6,.6)
	icon.BackgroundTransparency=1;icon.TextScaled=true;icon.Font=Enum.Font.FredokaOne;icon.TextColor3=Bubble.Ink;icon.ZIndex=4;icon.Parent=art
	local image=Instance.new("ImageLabel")
	image.Name="IconImage";image.AnchorPoint=Vector2.new(.5,.5);image.Position=UDim2.fromScale(.5,.54);image.Size=UDim2.fromScale(.64,.64)
	image.BackgroundTransparency=1;image.Visible=false;image.ZIndex=4;image.Parent=art
	-- The First Hatch (Fable MUST 5): the nest bubble shows tomorrow's egg beside the moon (drawn: a cream ovoid with
	-- two speckles, lower right), so it reads as a present, not bedtime.
	local eggBadge=Instance.new("Frame")
	eggBadge.Name="EggBadge";eggBadge.AnchorPoint=Vector2.new(.5,.5);eggBadge.Position=UDim2.fromScale(.74,.7);eggBadge.Size=UDim2.fromScale(.27,.34)
	eggBadge.BackgroundColor3=Color3.fromHex("#FFF4DC");eggBadge.BorderSizePixel=0;eggBadge.ZIndex=5;eggBadge.Visible=false;eggBadge.Parent=art
	local eggRound=Instance.new("UICorner");eggRound.CornerRadius=UDim.new(.5,0);eggRound.Parent=eggBadge
	local eggEdge=Instance.new("UIStroke");eggEdge.Color=Bubble.Ink;eggEdge.Thickness=2;eggEdge.Parent=eggBadge
	for i,p in ipairs({{.34,.38,.22},{.62,.62,.18}})do
		local dot=Instance.new("Frame");dot.Name="Speckle"..i;dot.AnchorPoint=Vector2.new(.5,.5);dot.Position=UDim2.fromScale(p[1],p[2])
		dot.Size=UDim2.fromScale(p[3],p[3]*.8);dot.BackgroundColor3=Color3.fromHex("#94DFB7");dot.BorderSizePixel=0;dot.ZIndex=6;dot.Parent=eggBadge
		local r=Instance.new("UICorner");r.CornerRadius=UDim.new(.5,0);r.Parent=dot
	end
	-- The key cap: 22 px at the bubble's top right, clear of the tail (Fable R1), the key that does what a tap does.
	local key=Instance.new("TextLabel")
	key.Name="Key";key.AnchorPoint=Vector2.new(1,0);key.Position=UDim2.new(1,6,0,-6);key.Size=UDim2.fromOffset(22,22)
	key.BackgroundColor3=Bubble.Ink;key.TextColor3=Color3.new(1,1,1);key.Font=Enum.Font.GothamBold;key.TextSize=14;key.ZIndex=5
	key.BorderSizePixel=0;key.Visible=false;key.Parent=art
	local keyCorner=Instance.new("UICorner");keyCorner.CornerRadius=UDim.new(0,6);keyCorner.Parent=key
	-- The hit area: the whole billboard, clear, over everything.
	local button=Instance.new("TextButton")
	button.Name="Hit";button.Text="";button.AutoButtonColor=false;button.Selectable=true;button.Active=true;button.BackgroundTransparency=1
	button.Size=UDim2.fromScale(1,1);button.BorderSizePixel=0;button.ZIndex=10;button.Parent=gui
	local function tapped()
		if self.shown and self.alpha<.6 and options.onTap then options.onTap()end
	end
	-- Signals only where they exist (the offline spec mocks have none; NestClient's pattern).
	local function on(signal,fn)if typeof(signal)=="RBXScriptSignal"then return signal:Connect(fn)end;return nil end
	on(button.Activated,tapped)
	-- Beta 14 B3b: on a phone a billboard can take a touch and still fire no Activated. A touch that begins and ends on
	-- the hit area counts too (BearNeeds keeps it to one action a tap), and the bubble holds still while a finger is on it.
	on(button.InputBegan,function(input)
		if input.UserInputType==Enum.UserInputType.Touch then self.holding={at=os.clock(),from=input.Position}end
	end)
	on(button.InputEnded,function(input)
		if input.UserInputType~=Enum.UserInputType.Touch then return end
		local hold=self.holding;self.holding=nil
		-- A short tap that stayed put, never the end of a camera swipe that began on the bubble.
		if hold and os.clock()-hold.at<=.6 and(input.Position-hold.from).Magnitude<=24 then tapped()end
	end)
	-- A tap no GUI took (TouchTapInWorld, PetClickTarget's pattern) within the hit area round the drawn bubble.
	local okInput,input=pcall(function()return game:GetService("UserInputService")end)
	if okInput and input then
		self.worldTap=on(input.TouchTapInWorld,function(position,processed)
			if processed or not self.shown or not self.gui.Enabled then return end
			local camera=workspace.CurrentCamera
			if not camera then return end
			local base=self.gui.Adornee or self.anchor
			local point,onScreen=camera:WorldToViewportPoint(base.Position+self.gui.StudsOffsetWorldSpace)
			if onScreen and point.Z>0 and Bubble.hits(Vector2.new(position.X,position.Y),Vector2.new(point.X,point.Y))then tapped()end
		end)
	end
	-- Onboarding v2 step 5 (the guide): the prompt in words beside the icon, and a gold arrow bouncing under the bubble.
	local words=Instance.new("TextLabel")
	words.Name="Words";words.BackgroundTransparency=1;words.AnchorPoint=Vector2.new(0,.5);words.Position=UDim2.new(0,62,.5,0)
	words.Size=UDim2.new(1,-74,1,-8);words.Font=Enum.Font.BuilderSansBold;words.TextSize=Bubble.WordSize;words.TextColor3=Bubble.WordInk
	words.TextXAlignment=Enum.TextXAlignment.Left;words.Text="";words.Visible=false;words.ZIndex=4;words.Parent=art
	local arrow=Instance.new("TextLabel")
	arrow.Name="Arrow";arrow.BackgroundTransparency=1;arrow.AnchorPoint=Vector2.new(.5,0);arrow.Position=UDim2.new(.5,0,1,8)
	arrow.Size=UDim2.fromOffset(20,14);arrow.Font=Enum.Font.BuilderSansBold;arrow.TextSize=18;arrow.Text="▼"
	arrow.TextColor3=Bubble.Arrow;arrow.Visible=false;arrow.ZIndex=3;arrow.Parent=art
	local arrowEdge=Instance.new("UIStroke");arrowEdge.Color=Bubble.WordInk;arrowEdge.Thickness=1.5;arrowEdge.Parent=arrow
	self.words,self.arrow,self.arrowEdge=words,arrow,arrowEdge
	local squash=Instance.new("UIScale");squash.Name="PressScale";squash.Scale=1;squash.Parent=art
	anchor.Parent=options.world or workspace
	gui.Parent=options.parent
	self.anchor,self.gui,self.button,self.art,self.tail,self.edge,self.tailEdge,self.lip,self.icon,self.image,self.key=
		anchor,gui,button,art,tail,edge,tailEdge,lip,icon,image,key
	self.squash,self.lipSquash=squash,lipSquash
	self.eggBadge,self.eggEdge=eggBadge,eggEdge
	return self
end
-- The egg badge belongs to the First Hatch's nest first (Onboard "nestfirst"); off, the moon as before.
function Bubble.nestFirst()
	local ok,on=pcall(function()return require(game:GetService("ReplicatedStorage").Shared.Onboard).on("nestfirst")end)
	return ok and on==true
end
function Bubble:reduced()return self.options.reduced~=nil and self.options.reduced()==true end
-- The guide's words beside the icon (a white pill), or nil for the round icon bubble as before.
function Bubble:setWords(text)
	local on=type(text)=="string"and text~=""
	if on==(self.wordText~=nil)and(not on or self.wordText==text)then return end
	self.wordText=if on then text else nil
	local w=Bubble.Size
	if on then
		local measure=function(t)
			local ok,size=pcall(function()return game:GetService("TextService"):GetTextSize(t,Bubble.WordSize,Enum.Font.BuilderSansBold,Vector2.new(1000,100))end)
			return if ok and typeof(size)=="Vector2"then size.X else #t*Bubble.WordSize*.55
		end
		w=Bubble.wordWidth(text,measure)
		self.words.Text=text
	end
	local h=if on then Bubble.WordH else Bubble.Size
	self.art.Size=UDim2.fromOffset(w,h);self.lip.Size=self.art.Size
	self.gui.Size=UDim2.fromOffset(math.max(Bubble.HitSize,w+16),Bubble.HitSize)
	self.words.Visible=on;self.arrow.Visible=on
	self.art.BackgroundColor3=if on then Bubble.WordFill else Bubble.Fill
	self.tail.BackgroundColor3=self.art.BackgroundColor3
	self.edge.Color=if on then Bubble.WordInk else Bubble.Ink
	self.tailEdge.Color=self.edge.Color
	-- the nest's egg badge rides the icon, not the words
	self.eggBadge.Position=if on then UDim2.new(0,46,.5,9)else UDim2.fromScale(.74,.7)
	self.eggBadge.Size=if on then UDim2.fromOffset(15,19)else UDim2.fromScale(.27,.34)
	for _,glyph in ipairs({self.icon,self.image})do
		if on then glyph.AnchorPoint=Vector2.new(.5,.5);glyph.Position=UDim2.new(0,32,.5,0);glyph.Size=UDim2.fromOffset(40,40)
		else glyph.AnchorPoint=Vector2.new(.5,.5);glyph.Position=UDim2.fromScale(.5,.54);glyph.Size=UDim2.fromScale(if glyph==self.image then .64 else .6,if glyph==self.image then .64 else .6)end
	end
end
-- Show `icon` (a Glyph key), or hide (visible false). words: the guide's prompt (nil: the icon alone).
function Bubble:set(icon,visible,words)
	if visible then self:setWords(words)end
	if visible and icon then
		local id=Bubble.IconIds[icon]
		self.image.Visible=id~=nil
		if id then self.image.Image="rbxassetid://"..id end
		self.icon.Text=if id then "" else Bubble.Glyph[icon]or "?"
		self.icon.Visible=id==nil
		self.eggBadge.Visible=icon=="moon"and Bubble.nestFirst()
		if not self.shown then self:hop()end
		self.shown,self.kind,self.target=true,icon,0
		self.gui:SetAttribute("Need",icon)
	else
		self.shown,self.target=false,1
		self.gui:SetAttribute("Need",nil)
	end
end
function Bubble:hop()
	if not self:reduced()then self.hopAt=self.time end
end
-- A taken tap (BearNeeds): a squash and a count on the billboard (Taps, beta diagnostics for a phone session).
function Bubble:press()
	self.taps=(self.taps or 0)+1
	self.gui:SetAttribute("Taps",self.taps)
	if not self:reduced()then self.pressAt=self.time end
end
function Bubble:paint()
	local a=self.alpha
	self.art.BackgroundTransparency=a;self.tail.BackgroundTransparency=a
	self.edge.Transparency=a;self.tailEdge.Transparency=a
	self.lip.BackgroundTransparency=1-Bubble.Lip.opacity*(1-a)
	self.icon.TextTransparency=a;self.image.ImageTransparency=a
	self.key.BackgroundTransparency=a;self.key.TextTransparency=a
	self.eggBadge.BackgroundTransparency=a;self.eggEdge.Transparency=a
	self.words.TextTransparency=a;self.arrow.TextTransparency=a;self.arrowEdge.Transparency=a
	for _,dot in ipairs(self.eggBadge:GetChildren())do if dot:IsA("Frame")then dot.BackgroundTransparency=a end end
end
function Bubble:step(dt)
	dt=dt or 0
	self.time+=dt
	local adornee=self.options.adornee and self.options.adornee()or nil
	if self.part~=adornee then
		self.part,self.top=adornee,nil
		if adornee then
			local model=adornee:FindFirstAncestorWhichIsA("Model")
			local ok,size=pcall(function()return if model then model:GetExtentsSize()else adornee.Size end)
			self.top=if ok and typeof(size)=="Vector3"then size.Y*.5 else 1.5
		end
	end
	local reduced=self:reduced()
	-- A finger on the bubble holds it still, for a second at most (a lost InputEnded never pins it).
	if self.holding and(not self.shown or os.clock()-self.holding.at>1)then self.holding=nil end
	local rise=0
	if adornee and Bubble.pinned(self.wordText)then
		-- pinned: on the pet's part, over its head (a finger on it never holds it back from the pet)
		if self.gui.Adornee~=adornee then self.gui.Adornee=adornee end
		self.spot.at,self.spot.chasing=nil,false
		rise=(self.top or 1.5)+Bubble.Lift
	else
		if self.gui.Adornee~=self.anchor then self.gui.Adornee=self.anchor end
		if adornee and not self.holding then
			local at=Bubble.follow(self.spot,adornee.Position+Vector3.new(0,(self.top or 1.5)+Bubble.Lift,0),dt,reduced)
			self.anchor.CFrame=CFrame.new(at)
		end
	end
	local fade=if reduced then 1 else dt/Bubble.Fade
	if self.alpha<self.target then self.alpha=math.min(self.target,self.alpha+fade)
	elseif self.alpha>self.target then self.alpha=math.max(self.target,self.alpha-fade)end
	local hint=self.options.keyHint and self.options.keyHint()or nil
	self.key.Visible=type(hint)=="string"and hint~=""
	if self.key.Visible then self.key.Text=hint end
	self:paint()
	local lift=0
	if self.hopAt then
		local t=(self.time-self.hopAt)/Bubble.HopTime
		if t>=1 or reduced then self.hopAt=nil else lift=math.sin(t*math.pi)*Bubble.HopHeight end
	end
	self.gui.StudsOffsetWorldSpace=Vector3.new(0,rise+lift,0)
	if self.arrow.Visible then
		local bounce=if reduced then 0 else Bubble.ArrowPx*(.5-.5*math.cos(self.time*Bubble.ArrowHz*math.pi*2))
		self.arrow.Position=UDim2.new(.5,0,1,8+bounce)
	end
	local squash=1
	if self.pressAt then
		local s=if reduced then nil else Bubble.pressScale(self.time-self.pressAt)
		if s then squash=s else self.pressAt=nil end
	end
	if self.squash.Scale~=squash then self.squash.Scale=squash;self.lipSquash.Scale=squash end
	self.gui.Enabled=adornee~=nil and self.alpha<1
	self.button.Active=self.shown==true
	-- Out of sight: the next showing starts over the Bear, not where it was.
	if not self.gui.Enabled then self.spot.at=nil end
end
function Bubble:destroy()
	if self.worldTap then self.worldTap:Disconnect();self.worldTap=nil end
	self.gui:Destroy();self.anchor:Destroy()
end
return Bubble
