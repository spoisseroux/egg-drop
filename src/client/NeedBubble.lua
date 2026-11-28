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
--  * the bubble hangs on its own local anchor that follows the Bear (beta 40: BubbleFollow, below; it was a spring
--    with a 2-stud dead zone);
--  * a small key cap shows the keyboard or gamepad key (options.keyHint) that does the same as a tap.
-- Beta (37) note 2 ("tuck the egg in ui thing doesnt constantly follow the pet, it like waits and then catches up"):
-- that was the Dead zone and the spring above. The guide's worded bubble was pinned to the pet's own part then (beta 40
-- replaced that: the part is the animated Body, see below).
-- Beta (40) note 1 ("the onboarding label above the pet ... its all jittery"): the pet's part is its animated Body (the
-- waddle's roll and sway, the lean, the bob, the boop squash), so the pinned words shook with every step, and the icon
-- bubble's dead zone and spring still read stop-and-go. Every bubble (words or icon) now hangs on its own anchor, placed
-- every rendered frame (BubbleFollow.bind, after the camera) over the pet's un-animated origin (options.origin) plus its
-- measured top and Lift: X and Z exactly, the height lightly smoothed, no dead zone, a teleport snaps. The parked chip
-- has its own anchor the same way. The hop and the arrow's bounce ride on top as before.
-- The bubble is gamepad-selectable. Fades in and out, pops in with a small hop and hops on the idle hint; Reduced Motion:
-- fades only, and the anchor follows exactly (no smoothing).
-- options: {parent = PlayerGui, adornee() -> the pet's part or nil, origin(part) -> the pet's un-animated origin
--   (Vector3) when `part` is the pet's, else nil (the part itself is the place: the nest's anchor), onTap(),
--   reduced() -> bool, keyHint() -> text or nil, world = where the anchor parts live (default workspace),
--   chipAdornee() and onChip() for the parked chip}
local Follow=require(script.Parent.BubbleFollow)
local Bubble={};Bubble.__index=Bubble
Bubble.Follow=Follow -- the shared follow (GiftBubble may hang on it too)
Bubble.Glyph=table.freeze({hand="👋",ball="🎾",deck="🎮",moon="🌙",paws="🐾",egg="🥚"})
Bubble.IconIds=table.freeze({hand=125214220825448,ball=107242483076374,deck=83400081676425,moon=127648287993869,
 paws=80004221456977,egg=116751717038768}) -- flat icons (beta 17 U7), uploaded 2026-11-25; a glyph if one is missing
Bubble.Size=72        -- px, the drawn bubble
Bubble.HitSize=108    -- px, the tap target round it
Bubble.Lift=2.2       -- studs over the top of the pet
Bubble.Fade=.2
Bubble.HopTime=.45;Bubble.HopHeight=.6
Bubble.Snap=Follow.Snap -- studs: further than this is a teleport, the bubble snaps
Bubble.Press=table.freeze({low=.88,down=.06,rate=8,wobble=18}) -- beta 14 B3b: the squash a taken tap gives
Bubble.Ink=Color3.fromHex("#24304F")
Bubble.Fill=Color3.fromHex("#FFFDF6") -- U7: flat cream-white, no shading
Bubble.Lip=table.freeze({drop=3,opacity=.25}) -- U7: px below the face, ink opacity
-- Onboarding v2 step 5 (the guide, ONBOARDING-V2.md): a white pill with the words in ink, a gold arrow (6 px at 1 Hz,
-- still under Reduced Motion).
Bubble.WordFill=Color3.fromHex("#FFFFFF");Bubble.WordInk=Color3.fromHex("#1B2A4A");Bubble.Arrow=Color3.fromHex("#FFD86B")
Bubble.WordSize=20;Bubble.WordH=60;Bubble.ArrowPx=6;Bubble.ArrowHz=1
-- Onboarding v3 brief section 1 (Onboard "lead"): two lines, a headline (20 px ExtraBold) over a sub-line (14 px Bold,
-- the ink at 70%). The parked lead's chip: a 36 px moon over the pet, a tap restarts the lead (options.onChip).
Bubble.SubSize=14;Bubble.SubAlpha=.3;Bubble.TwoH=68
Bubble.ChipSize=36;Bubble.ChipHit=52
-- Pure: the pill's width for these words (measure(text, size) -> px, else an estimate); `sub` the second line.
function Bubble.wordWidth(text,measure,sub)
	local function width(t,size)
		if type(measure)=="function"then return measure(t,size)end
		return #t*size*.55
	end
	local w=width(text,Bubble.WordSize)
	if type(sub)=="string"and sub~=""then w=math.max(w,width(sub,Bubble.SubSize))end
	return math.ceil(62+w+16)
end

-- Pure: where the bubble hangs now. state = {at} (kept by the caller), target = over the pet now (BubbleFollow.toward:
-- X and Z exactly, the height lightly smoothed, a teleport snaps; beta 40: no dead zone, no spring).
Bubble.follow=Follow.toward
-- Pure (beta 14 B3b): does a screen tap at `tap` land on a bubble drawn round `centre` (both Vector2, px)? With `size`
-- (the drawn bubble's px, a Vector2; beta 44 note 18): only on the drawn bubble, centred 6 px over `centre`, its tail
-- (8 px) under it, never the clear square round it.
function Bubble.hits(tap,centre,size)
	if typeof(tap)~="Vector2"or typeof(centre)~="Vector2"then return false end
	if typeof(size)=="Vector2"then
		local d=tap-(centre+Vector2.new(0,-6))
		return math.abs(d.X)<=size.X*.5 and d.Y>=-size.Y*.5 and d.Y<=size.Y*.5+8
	end
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
	local self=setmetatable({options=options,alpha=1,target=1,hopAt=nil,time=0,spot=Follow.new(),chipSpot=Follow.new()},Bubble)
	local function anchorPart(name)
		local part=Instance.new("Part")
		part.Name=name;part.Size=Vector3.new(.2,.2,.2);part.Transparency=1
		part.Anchored,part.CanCollide,part.CanQuery,part.CanTouch,part.CastShadow,part.Massless=true,false,false,false,false,true
		return part
	end
	local anchor=anchorPart("EggDropNeedAnchor")
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
	-- The hit area: the drawn bubble only (beta 44 note 18: the clear square round it ate clicks on the pet's head), clear,
	-- over everything; it follows the drawn bubble's size (Bubble:layout).
	local button=Instance.new("TextButton")
	button.Name="Hit";button.Text="";button.AutoButtonColor=false;button.Selectable=true;button.Active=true;button.BackgroundTransparency=1
	button.AnchorPoint=art.AnchorPoint;button.Position=art.Position;button.Size=art.Size
	button.BorderSizePixel=0;button.ZIndex=10;button.Parent=gui
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
			local drawn=Vector2.new(self.art.Size.X.Offset,self.art.Size.Y.Offset)
			if onScreen and point.Z>0 and Bubble.hits(Vector2.new(position.X,position.Y),Vector2.new(point.X,point.Y),drawn)then tapped()end
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
	-- The v3 brief's sub-line, under the headline (hidden with one line).
	local subline=Instance.new("TextLabel")
	subline.Name="Sub";subline.BackgroundTransparency=1;subline.AnchorPoint=Vector2.new(0,0);subline.Position=UDim2.new(0,62,.5,4)
	subline.Size=UDim2.new(1,-74,0,18);subline.Font=Enum.Font.BuilderSansBold;subline.TextSize=Bubble.SubSize;subline.TextColor3=Bubble.WordInk
	subline.TextXAlignment=Enum.TextXAlignment.Left;subline.Text="";subline.Visible=false;subline.ZIndex=4;subline.Parent=art
	self.words,self.arrow,self.arrowEdge,self.subline=words,arrow,arrowEdge,subline
	-- The parked lead's chip (v3 brief section 1): a 36 px moon over the pet, its own billboard and tap.
	local chip=Instance.new("BillboardGui")
	chip.Name="EggDropLeadChip";chip.Size=UDim2.fromOffset(Bubble.ChipHit,Bubble.ChipHit);chip.AlwaysOnTop=true;chip.Active=true
	chip.LightInfluence=0;chip.ResetOnSpawn=false;chip.Enabled=false;chip.MaxDistance=140
	local chipArt=Instance.new("Frame")
	chipArt.Name="Art";chipArt.AnchorPoint=Vector2.new(.5,.5);chipArt.Position=UDim2.fromScale(.5,.5);chipArt.Size=UDim2.fromOffset(Bubble.ChipSize,Bubble.ChipSize)
	chipArt.BackgroundColor3=Bubble.WordFill;chipArt.BorderSizePixel=0;chipArt.Parent=chip
	local chipRound=Instance.new("UICorner");chipRound.CornerRadius=UDim.new(.5,0);chipRound.Parent=chipArt
	local chipEdge=Instance.new("UIStroke");chipEdge.Color=Bubble.WordInk;chipEdge.Thickness=2;chipEdge.Parent=chipArt
	local chipIcon=Instance.new("ImageLabel")
	chipIcon.Name="Icon";chipIcon.BackgroundTransparency=1;chipIcon.AnchorPoint=Vector2.new(.5,.5);chipIcon.Position=UDim2.fromScale(.5,.5)
	chipIcon.Size=UDim2.fromScale(.7,.7);chipIcon.Image="rbxassetid://"..Bubble.IconIds.moon;chipIcon.Parent=chipArt
	local chipScale=Instance.new("UIScale");chipScale.Scale=1;chipScale.Parent=chipArt
	local chipHit=Instance.new("TextButton")
	chipHit.Name="Hit";chipHit.Text="";chipHit.AutoButtonColor=false;chipHit.BackgroundTransparency=1;chipHit.Size=UDim2.fromScale(1,1)
	chipHit.Selectable=true;chipHit.ZIndex=10;chipHit.Parent=chip
	on(chipHit.Activated,function()if self.chipOn and options.onChip then options.onChip()end end)
	-- beta 40: the chip hangs on its own anchor over the pet's origin too (never its animated Body)
	local chipAnchor=anchorPart("EggDropLeadChipAnchor")
	chip.Adornee=chipAnchor
	chip.Parent=options.parent
	self.chipGui,self.chipScale,self.chipAnchor=chip,chipScale,chipAnchor
	local squash=Instance.new("UIScale");squash.Name="PressScale";squash.Scale=1;squash.Parent=art
	anchor.Parent=options.world or workspace
	chipAnchor.Parent=options.world or workspace
	-- every rendered frame, after the camera (and the pets' RenderStepped pose); offline, step() places them itself
	self.unbind=Follow.bind("EggDropNeedBubble",function(dt)self:place(dt)end)
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
-- The guide's words beside the icon (a white pill), or nil for the round icon bubble as before. sub: the v3 brief's
-- second line (nil: one line, as before).
function Bubble:setWords(text,sub)
	local on=type(text)=="string"and text~=""
	local two=on and type(sub)=="string"and sub~=""
	if on==(self.wordText~=nil)and(not on or self.wordText==text)and(if two then sub else nil)==self.subText then return end
	self.wordText=if on then text else nil
	self.subText=if two then sub else nil
	local w=Bubble.Size
	if on then
		local measure=function(t,size)
			size=size or Bubble.WordSize
			local font=if size==Bubble.WordSize and two then Enum.Font.BuilderSansExtraBold else Enum.Font.BuilderSansBold
			local ok,got=pcall(function()return game:GetService("TextService"):GetTextSize(t,size,font,Vector2.new(1000,100))end)
			return if ok and typeof(got)=="Vector2"then got.X else #t*size*.55
		end
		w=Bubble.wordWidth(text,measure,if two then sub else nil)
		self.words.Text=text
	end
	if self.subline then
		self.subline.Visible=two
		self.subline.Text=if two then sub else ""
		-- two lines: the headline ExtraBold in the top half, the sub-line under it
		self.words.Font=if two then Enum.Font.BuilderSansExtraBold else Enum.Font.BuilderSansBold
		self.words.AnchorPoint=if two then Vector2.new(0,1)else Vector2.new(0,.5)
		self.words.Position=if two then UDim2.new(0,62,.5,4)else UDim2.new(0,62,.5,0)
		self.words.Size=if two then UDim2.new(1,-74,0,26)else UDim2.new(1,-74,1,-8)
	end
	local h=if two then Bubble.TwoH elseif on then Bubble.WordH else Bubble.Size
	self.art.Size=UDim2.fromOffset(w,h);self.lip.Size=self.art.Size;self.button.Size=self.art.Size
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
-- Show `icon` (a Glyph key), or hide (visible false). words: the guide's prompt (nil: the icon alone); sub: its
-- second line (the v3 brief, nil: one line).
function Bubble:set(icon,visible,words,sub)
	if visible then self:setWords(words,sub)end
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
-- The parked lead's moon chip over the pet (the v3 brief): on or off. It pulses gently; Reduced Motion: still.
function Bubble:chip(on)self.chipOn=on==true end
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
	if self.subline then self.subline.TextTransparency=a+(1-a)*Bubble.SubAlpha end
	for _,dot in ipairs(self.eggBadge:GetChildren())do if dot:IsA("Frame")then dot.BackgroundTransparency=a end end
end
-- Where a bubble over `part` hangs: the pet's un-animated origin (options.origin) and the part's top over it, measured
-- once a part (else the part itself: the nest's anchor). `memo` keeps the measure. -> base Vector3 or nil, height.
function Bubble:over(part,memo)
	if part==nil then memo.part,memo.top,memo.origin=nil,nil,nil;return nil,0 end
	local origin=nil
	if self.options.origin then
		local ok,at=pcall(self.options.origin,part)
		if ok and typeof(at)=="Vector3"then origin=at end
	end
	-- re-measured when the part changes, or it switches between origin and part (a pet stowed, the nest's anchor)
	if memo.part~=part or memo.origin~=(origin~=nil)then
		memo.part,memo.origin=part,origin~=nil
		memo.top=Follow.top(part,origin,1.5)
	end
	return origin or part.Position,(memo.top or 1.5)+Bubble.Lift
end
-- Every rendered frame (BubbleFollow.bind): the anchors over the pet. A finger on the bubble holds it still.
function Bubble:place(dt)
	if not self.anchor then return end
	local reduced=self:reduced()
	self.measure=self.measure or {}
	local base,height=self:over(self.options.adornee and self.options.adornee()or nil,self.measure)
	if base and not self.holding then
		local at=Follow.step(self.spot,base,height,dt,reduced)
		if at then self.anchor.CFrame=CFrame.new(at)end
	end
	if self.chipAnchor and self.chipOn then
		self.chipMeasure=self.chipMeasure or {}
		local chipPart=if self.options.chipAdornee then self.options.chipAdornee()else(self.options.adornee and self.options.adornee()or nil)
		local chipBase,chipHeight=self:over(chipPart,self.chipMeasure)
		if chipBase then
			local at=Follow.step(self.chipSpot,chipBase,chipHeight,dt,reduced)
			if at then self.chipAnchor.CFrame=CFrame.new(at)end
		end
	end
end
function Bubble:step(dt)
	dt=dt or 0
	self.time+=dt
	local adornee=self.options.adornee and self.options.adornee()or nil
	local reduced=self:reduced()
	-- A finger on the bubble holds it still, for a second at most (a lost InputEnded never pins it).
	if self.holding and(not self.shown or os.clock()-self.holding.at>1)then self.holding=nil end
	if self.gui.Adornee~=self.anchor then self.gui.Adornee=self.anchor end
	-- offline (no render step): placed here
	if not self.unbind then self:place(dt)end
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
	-- the anchor carries the height (Bubble:place); the hop rides on top
	self.gui.StudsOffsetWorldSpace=Vector3.new(0,lift,0)
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
	if self.chipGui then
		local chipAt=self.options.chipAdornee and self.options.chipAdornee()or adornee
		local showChip=self.chipOn==true and chipAt~=nil
		self.chipGui.Enabled=showChip
		if showChip then
			if self.chipGui.Adornee~=self.chipAnchor then self.chipGui.Adornee=self.chipAnchor end
			-- beside the bubble when both hang over the pet, else where the bubble would be (the anchor carries the height)
			local beside=self.gui.Enabled and self.measure~=nil and self.measure.part==chipAt
			local px=if beside then self.gui.Size.X.Offset*.5+Bubble.ChipHit*.5 else 0
			self.chipGui.SizeOffset=Vector2.new(-px/Bubble.ChipHit,0)
			self.chipGui.StudsOffsetWorldSpace=Vector3.zero
			self.chipScale.Scale=if reduced then 1 else 1+.075*(1-math.cos(self.time*math.pi*2/1.2))
		else self.chipSpot.at=nil end
	end
	-- Out of sight: the next showing starts over the pet exactly, not where it was.
	if not self.gui.Enabled then self.spot.at=nil end
end
function Bubble:destroy()
	if self.worldTap then self.worldTap:Disconnect();self.worldTap=nil end
	if self.unbind then self.unbind();self.unbind=nil end
	if not self.anchor then return end
	self.gui:Destroy();self.anchor:Destroy()
	if self.chipGui then self.chipGui:Destroy()end
	if self.chipAnchor then self.chipAnchor:Destroy()end
	self.anchor,self.chipAnchor=nil,nil
end
return Bubble
