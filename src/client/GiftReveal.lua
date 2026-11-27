-- The gift chain's card (GiftChain; ONBOARDING-FUN-PASS section 2, Onboard "gifts"): what the free Paint or Toy Egg gave,
-- opened only by the egg machine's deliver once the egg is in the cup (the standing rule: every egg cranks and emerges
-- before any reveal). Its odds are the egg's own ("Each colour: 1 in 4"). One tap does the thing and closes into the
-- garden, never a menu: "Paint {pet}!" (the pot on the pet's body, the existing hueUse) or "Play!" (the toy equipped,
-- the existing toyEquip); "Later" keeps it. Either way the server is told it was seen (giftSeen), so it never replays.
-- The look is Fable's GIFT-ART-BRIEF section 2 (numbers and curves in GiftArt): the paid card's system, HatchItemStage's
-- well in Sky (#C9F1FF core, #2FA8F0 edge, still rays, 6 bubbles), glass plates and ink text, 340 x 300, wrapped:
--   a 26 px pink sash across the top-left corner at 45 degrees (a 1 px #FFD3E6 top edge) and a 44 px bow on the corner
--   (12 px over the edge); a glass gift tag (190 x 34, -4 degrees, a 2 px pink string) "A gift from {pet}!" in place of
--   the egg-type line; the giver's 64 px headshot (a 3 px white ring) over the top-right edge; the item (the paint pot,
--   96 px, its colour on the bubble rims and confetti; a toy's icon in gift pink); no tier sticker, price or Stars; the
--   name (ExtraBold 22) and the real odds line (14 px at 65%); the primary key (170 x 52) in the pot's colour, ink on
--   rose and citrus, white on tide and iris, glinting every 6 s, and "Later" a glass pill (110 x 52).
--   Entrance (.9 s): the pop .85, 1.05, 1.0 in .3 (screen_rise); .15 the sash draws and the bow ties (blanket_rustle
--   1.2); .35 the pot lands from 30 px and squashes 10% (egg_tok_1); .5 rarity_common, the pop buzz, 12 confetti dots
--   and one light sweep; .6 the tag swings -14 to -4; the keys at .9. Exit: the primary folds the card into the pot
--   (.2 s), which arcs to the pet (.35 s); Later: screen_tuck. Reduced Motion: a .15 s fade in and out; sound and buzz
--   stay.
-- show(parent, record, options): record = {kind, item, id}; options = {text(key, vars), pet (name), petId, appearance,
--   color (Color3 for a pot), itemName, poolSize, deeper (a pot already owned), act(record) (Paint / Play, at the tap),
--   landed(record) (the pot reached the pet), seen(record), closed(), play(name, speed, volume), haptic(name),
--   reduced() -> bool, petScreen() -> Vector2? (the pet on screen, for the arc)}
local RunService=game:GetService("RunService")
local GuiService=game:GetService("GuiService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GiftArt=require(Shared:WaitForChild("GiftArt"))
local HatchAero=require(Shared:WaitForChild("HatchAero"))
local Draw=require(script.Parent:WaitForChild("GiftEggArt"))
local Reveal={}
Reveal.Ink=GiftArt.color("ink")
local open=nil
local openClose=nil -- the open card's own close (code review: a replaced card's Heartbeat never outlives it)
local node=Draw.node
local function on(signal,fn)if typeof(signal)=="RBXScriptSignal"then return signal:Connect(fn)end;return nil end
local function round(parent,r)return node("UICorner",parent,{CornerRadius=r or UDim.new(.5,0)})end
-- Pure: the card's words for a record. -> {title (the tag), name, odds, primary, secondary}
function Reveal.words(record,options)
	local text=options.text
	local kind=record.kind
	local w={title=text("onbGift.card.from",{pet=options.pet})}
	if kind=="paint"then
		local name=options.itemName or record.item
		w.name=if options.deeper then text("onbGift.card.deeper",{name=name})else text("onbGift.card.pot",{name=name})
		w.odds=text("onbGift.card.potOdds")
		w.primary=text("onbGift.card.paint",{pet=options.pet})
	else
		w.name=options.itemName or record.item
		w.odds=text("onbGift.card.toyOdds",{count=options.poolSize or 1})
		w.primary=text("onbGift.card.play")
	end
	w.secondary=text("onbGift.card.later")
	return w
end
function Reveal.isOpen()return open~=nil end

local function itemArt(holder,record)
	if record.kind=="paint"then
		local ok=pcall(function()require(script.Parent:WaitForChild("HueJarArt")).create(holder,record.item,UDim2.new(),UDim2.fromScale(1,1),holder.ZIndex+1)end)
		return ok
	end
	return(pcall(function()require(script.Parent:WaitForChild("RewardItemArt")).create(holder,{toyId=record.item},UDim2.new(),UDim2.fromScale(1,1),holder.ZIndex+1)end))
end

function Reveal.show(parent,record,options)
	-- a card still open: closed through its own close (its Heartbeat goes with it), never just destroyed
	if openClose then openClose()end
	if open then open:Destroy();open=nil end
	local C=GiftArt.Card
	local words=Reveal.words(record,options)
	local reduced=options.reduced~=nil and options.reduced()==true
	local function play(name,speed,volume)if options.play then pcall(options.play,name,speed or 1,volume or .5)end end
	local function buzz(name)if options.haptic then pcall(options.haptic,name)end end
	local accentHex=GiftArt.accent(record.kind,record.item)
	local accent=Color3.fromHex(accentHex)
	local sky=HatchAero.palette("Common")
	local gui=node("ScreenGui",parent,{Name="EggDropGiftCard",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=40,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
	open=gui
	local holder=node("Frame",gui,{Name="Holder",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(C.w,C.h),BackgroundTransparency=1})
	node("UISizeConstraint",holder,{MaxSize=Vector2.new(C.w,C.h)})
	local scale=node("UIScale",holder,{Scale=if reduced then 1 else C.popFrom})
	-- the Sky well
	local card=node("Frame",holder,{Name="Card",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=2,ClipsDescendants=false})
	round(card,UDim.new(0,C.corner))
	node("UIGradient",card,{Rotation=90,Color=ColorSequence.new({ColorSequenceKeypoint.new(0,sky.core),ColorSequenceKeypoint.new(.55,HatchAero.mix(sky.core,sky.edge,.35)),
		ColorSequenceKeypoint.new(1,sky.edge)})})
	node("UIStroke",card,{Color=Reveal.Ink,Thickness=2})
	local clip=node("Frame",card,{Name="Clip",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ClipsDescendants=true,ZIndex=3})
	round(clip,UDim.new(0,C.corner))
	-- still rays from the top centre
	for i=1,C.rays do
		local a=-36+72*(i-1)/(C.rays-1)
		local ray=node("Frame",clip,{Name="Ray"..i,AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,-20),Size=UDim2.fromOffset(34,C.h*1.25),Rotation=a,
			BackgroundColor3=sky.ray,BackgroundTransparency=1-HatchAero.Rays.alpha,BorderSizePixel=0,ZIndex=3})
		node("UIGradient",ray,{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.2),NumberSequenceKeypoint.new(.7,.7),NumberSequenceKeypoint.new(1,1)})})
	end
	-- the bubbles, their rims in the accent
	local bubbles={}
	for i=1,C.bubbles do
		local b=node("Frame",clip,{Name="Bubble"..i,AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1-HatchAero.Bubble.fill,
			BorderSizePixel=0,ZIndex=3})
		round(b);node("UIStroke",b,{Color=accent,Thickness=1,Transparency=1-HatchAero.Bubble.rimAlpha})
		local spec=node("Frame",b,{Name="Spec",Position=UDim2.fromScale(.22,.18),Size=UDim2.fromScale(.18,.18),BackgroundColor3=Color3.new(1,1,1),
			BackgroundTransparency=1-HatchAero.Bubble.specAlpha,BorderSizePixel=0,ZIndex=3})
		round(spec)
		bubbles[i]=b
	end
	-- the wrapped corner: the sash across it at 45 degrees and the bow on it
	local sash=node("Frame",clip,{Name="Sash",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(30,30),Size=UDim2.fromOffset(0,C.sash),Rotation=-45,
		BackgroundColor3=GiftArt.color("pink"),BorderSizePixel=0,ZIndex=4})
	node("Frame",sash,{Name="Edge",Size=UDim2.new(1,0,0,C.sashEdge),BackgroundColor3=GiftArt.color("light"),BorderSizePixel=0,ZIndex=4})
	local bowAt=C.bow/2-C.bowOver
	local bow=Draw.bow(card,C.bow,UDim2.fromOffset(bowAt,bowAt),9)
	local bowScale=node("UIScale",bow,{Scale=if reduced then 1 else 0})
	-- the gift tag and its string
	local T=C.tag
	local tag=node("Frame",card,{Name="Tag",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,8,0,10+T.h/2),Size=UDim2.fromOffset(T.w,T.h),
		Rotation=if reduced then T.rest else T.from,BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=GiftArt.GlassTransparency,BorderSizePixel=0,ZIndex=7})
	round(tag,UDim.new(0,10));node("UIStroke",tag,{Color=Reveal.Ink,Thickness=1.5,Transparency=.3})
	node("TextLabel",tag,{Name="Words",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Text=words.title,Font=Enum.Font.FredokaOne,TextSize=T.font,
		TextColor3=Reveal.Ink,ZIndex=8,TextScaled=false})
	node("Frame",tag,{Name="Hole",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(0,10,.5,0),Size=UDim2.fromOffset(6,6),BackgroundColor3=GiftArt.color("pink"),
		BorderSizePixel=0,ZIndex=8})
	do
		local from=Vector2.new(bowAt+6,bowAt+6)
		local to=Vector2.new(C.w/2+8-T.w/2+10,10+T.h/2)
		local d=to-from
		node("Frame",card,{Name="String",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset((from.X+to.X)/2,(from.Y+to.Y)/2),
			Size=UDim2.fromOffset(d.Magnitude,T.string),Rotation=math.deg(math.atan2(d.Y,d.X)),BackgroundColor3=GiftArt.color("pink"),BorderSizePixel=0,ZIndex=6})
	end
	-- the giver's headshot over the top-right edge
	local shot=node("Frame",card,{Name="Headshot",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(1,-18,0,2),Size=UDim2.fromOffset(C.shot,C.shot),
		BackgroundColor3=Color3.fromHex("#FFF4DC"),BorderSizePixel=0,ZIndex=8})
	round(shot);node("UIStroke",shot,{Color=Color3.new(1,1,1),Thickness=C.ring})
	local shots,shotCard
	pcall(function()
		local Headshot=require(script.Parent:WaitForChild("PetHeadshot"))
		shot.BackgroundColor3=Headshot.backdrop(options.petId,options.appearance)
		shots=Headshot.newCache()
		shotCard=function()return Headshot.card(shot,options.petId,options.appearance,false,true)end
	end)
	-- the item
	local itemBox=node("Frame",card,{Name="Item",AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,0,52+C.item),Size=UDim2.fromOffset(C.item,C.item),
		BackgroundTransparency=1,ZIndex=6})
	itemArt(itemBox,record)
	-- the glass plate, the words and the keys
	local plate=node("Frame",card,{Name="Plate",AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-10),Size=UDim2.new(1,-20,0,140),
		BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=GiftArt.GlassTransparency,BorderSizePixel=0,ZIndex=5})
	round(plate,UDim.new(0,18))
	node("TextLabel",plate,{Name="Name",BackgroundTransparency=1,Position=UDim2.new(0,8,0,8),Size=UDim2.new(1,-16,0,28),Text=words.name,
		Font=Enum.Font.BuilderSansExtraBold,TextSize=C.name,TextColor3=Reveal.Ink,ZIndex=6})
	node("TextLabel",plate,{Name="Odds",BackgroundTransparency=1,Position=UDim2.new(0,8,0,36),Size=UDim2.new(1,-16,0,18),Text=words.odds,
		Font=Enum.Font.BuilderSansBold,TextSize=C.odds,TextColor3=Reveal.Ink,TextTransparency=1-C.oddsAlpha,ZIndex=6})
	local fillHex,labelHex=GiftArt.button(record.kind,record.item)
	local function button(name,label,x,primary)
		local size=if primary then C.primary else C.later
		local b=node("TextButton",plate,{Name=name,Text="",AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(x,0,1,-12),Size=UDim2.fromOffset(size.w,size.h),
			BackgroundTransparency=1,AutoButtonColor=false,BorderSizePixel=0,Selectable=true,ZIndex=6,Visible=false})
		local fill=node("Frame",b,{Name="Fill",Size=UDim2.fromScale(1,1),BackgroundColor3=if primary then Color3.fromHex(fillHex)else Color3.new(1,1,1),
			BackgroundTransparency=if primary then 0 else GiftArt.GlassTransparency,BorderSizePixel=0,ZIndex=6,Active=false})
		round(fill,UDim.new(0,size.h/2));node("UIStroke",fill,{Color=Reveal.Ink,Thickness=2})
		node("TextLabel",b,{Name="Label",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Text=label,Font=Enum.Font.BuilderSansExtraBold,TextSize=20,
			TextColor3=if primary then Color3.fromHex(labelHex)else Reveal.Ink,ZIndex=8})
		node("UIScale",b,{Name="Press",Scale=1})
		return b,fill
	end
	local primary,primaryFill=button("Primary",words.primary,.64,true)
	local later=button("Later",words.secondary,.2,false)
	pcall(function()require(script.Parent:WaitForChild("AeroUI")).watchPrimary(primary,primaryFill)end)
	-- the confetti and the one light sweep
	local confetti={}
	for i=1,C.confetti do
		local dot=node("Frame",card,{Name="Confetti"..i,AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(7,7),BackgroundColor3=GiftArt.confetti(i,accentHex),
			BorderSizePixel=0,Visible=false,ZIndex=9})
		round(dot)
		confetti[i]=dot
	end
	local light=node("Frame",clip,{Name="Sweep",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(-.3,.5),Size=UDim2.new(0,46,1.6,0),Rotation=18,
		BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=.55,BorderSizePixel=0,Visible=false,ZIndex=4})
	if reduced then Draw.fade(holder,0)end

	-- the clock: entrance, bubbles, confetti, then the exits
	local t,last,burstAt,sweepAt=0,-1,nil,nil
	local exit=nil -- {kind = "fold" | "later", at, from, to}
	local done=false
	local link
	-- `silent`: replaced by a newer card or destroyed from outside (no callbacks, as before); either way its clock stops.
	local function close(acted,silent)
		if done then return end
		done=true
		if link then link:Disconnect();link=nil end
		if shots then pcall(function()shots:clear()end)end
		if open==gui then open,openClose=nil,nil end
		gui:Destroy()
		if silent then return end
		if acted and options.landed then pcall(options.landed,record)end
		if options.seen then pcall(options.seen,record)end
		if options.closed then pcall(options.closed)end
	end
	local function leave(acted)
		if exit or done then return end
		primary.Active,later.Active=false,false
		if acted and options.act then pcall(options.act,record)end
		pcall(function()if GuiService.SelectedObject==primary or GuiService.SelectedObject==later then GuiService.SelectedObject=nil end end)
		if reduced then exit={kind="fade",at=t,acted=acted};return end
		if not acted then play("screen_tuck",1,.4);exit={kind="later",at=t};return end
		-- the pot leaves the card first, so the card can fold into it
		local p=itemBox.AbsolutePosition+itemBox.AbsoluteSize/2
		local to=options.petScreen and options.petScreen()
		itemBox.Parent=gui;itemBox.AnchorPoint=Vector2.new(.5,.5);itemBox.Position=UDim2.fromOffset(p.X,p.Y)
		local z=node("UIScale",itemBox,{Name="Arc",Scale=scale.Scale})
		exit={kind="fold",at=t,from=p,to=if typeof(to)=="Vector2"then to else nil,arcScale=z}
	end
	on(primary.Activated,function()leave(true)end)
	on(later.Activated,function()leave(false)end)
	openClose=function()close(false,true)end
	link=RunService.Heartbeat:Connect(function(dt)
		if done then return end
		if gui.Parent==nil then close(false,true);return end
		local ok,problem=pcall(function()
			t+=dt
			if shots and shotCard then shots:pump({shotCard()},function()end)end
			for _,cue in ipairs(GiftArt.due(GiftArt.CardCues,last,t))do
				play(cue.sound,cue.speed,cue.volume)
				if cue.buzz then buzz(cue.buzz)end
				if cue.confetti then burstAt=t end
				if cue.sweep and not reduced then sweepAt=t end
			end
			last=t
			-- the bubbles rise (still under Reduced Motion)
			for i,b in ipairs(bubbles)do
				local x,y,size,alpha=HatchAero.bubble(i,#bubbles,t,nil,C.w,C.h,1,reduced)
				if x then b.Visible=true;b.Position=UDim2.fromOffset(x,y);b.Size=UDim2.fromOffset(size,size);b.BackgroundTransparency=1-HatchAero.Bubble.fill*alpha
				else b.Visible=false end
			end
			if exit then
				local age=t-exit.at
				if exit.kind=="fade"then
					Draw.fade(holder,1-math.clamp(age/C.reduced,0,1))
					if age>=C.reduced then close(exit.acted)end
				elseif exit.kind=="later"then
					local u=math.clamp(age/.2,0,1)
					scale.Scale=1-.15*u;holder.Position=UDim2.new(.5,0,.5,40*u*u)
					Draw.fade(holder,1-u)
					if u>=1 then close(false)end
				else
					-- fold into the pot, then the pot arcs to the pet
					local f=math.clamp(age/C.fold,0,1)
					scale.Scale=math.max(.01,1-f)
					Draw.fade(holder,1-f)
					if exit.to and age>C.fold then
						local u=math.clamp((age-C.fold)/C.arc,0,1)
						local at,s=GiftArt.arc(u,exit.from,exit.to)
						itemBox.Position=UDim2.fromOffset(at.X,at.Y);exit.arcScale.Scale=s
						if u>=1 then close(true)end
					elseif not exit.to and age>=C.fold then close(true)end
				end
				return
			end
			local s=GiftArt.card(t,reduced)
			scale.Scale=s.scale
			if reduced then if s.alpha<1 or not holder:GetAttribute("Shown")then Draw.fade(holder,s.alpha);if s.alpha>=1 then holder:SetAttribute("Shown",true)end end end
			sash.Size=UDim2.fromOffset(C.h*.55*s.sash,C.sash)
			bowScale.Scale=s.bow
			tag.Rotation=s.tag
			itemBox.Visible=s.potAlpha>0
			itemBox.Position=UDim2.new(.5,0,0,52+C.item+s.potY)
			itemBox.Size=UDim2.fromOffset(C.item*(1+(1-s.potSquash)*.5),C.item*s.potSquash)
			if s.buttons and not primary.Visible then
				primary.Visible,later.Visible=true,true
				pcall(function()GuiService.SelectedObject=primary end)
			end
			-- the confetti from the pot
			for i,dot in ipairs(confetti)do
				local at,alpha=nil,0
				if burstAt then at,alpha=GiftArt.confettiAt(i,#confetti,t-burstAt,reduced)end
				if at then
					dot.Visible=true
					dot.Position=UDim2.fromOffset(C.w/2+at.X,52+C.item/2+at.Y)
					dot.BackgroundTransparency=1-alpha
				else dot.Visible=false end
			end
			if sweepAt then
				local u=(t-sweepAt)/.35
				light.Visible=u<1
				light.Position=UDim2.fromScale(-.3+1.6*math.clamp(u,0,1),.5)
				if u>=1 then sweepAt=nil end
			end
		end)
		if not ok then warn("[GiftCard] "..tostring(problem));close(false)end
	end)
	return gui
end
return Reveal
