-- "You're all set!" (onboarding v3 brief section 3, switch Onboard "allset2"; Spencer's beta 37 note 7: "the youre all
-- set should be more fun and exciting too"). Shows only when Pet, Nest and Stars are truly done, in the garden, with no
-- menu open (BearNeeds waits for that). 5 s; any tap, B or Esc closes it once it has been up 0.4 s.
--   0.0  the Bear jumps and spins (the server's leadCheer, every screen); 24 Aero bubbles and 16 confetti dots rise
--        from the bottom edge; `charge` at 1.0; a tick buzz
--   0.15 the card pops (0.85 -> 1.05 -> 1.0 over 0.3 s), the pet's headshot poking over its top edge
--   0.3, 0.38, 0.46  three small stamps (44 px: Pet, Nest, Stars) land with a gold tick: 1.4 -> 1.0 in 0.12 s,
--        `charge` 1.12 / 1.26 / 1.5, a tick buzz each (the onboarding fun pass: was 64 px, 0.2 s apart, so the ticks
--        read as done, not as homework)
--   0.6  the title punches (1.45 -> 1): `rarity_common`, a `pop` buzz, one light sweep across the card
--   1.2  "{pet} loves it here." and the gold button: "Hatch one!" (the paw prints to the egg machine) when the Stars
--        cover the cheapest egg, else "What's next?" (opens Things to do). It turns into "Hatch one!" when the gift
--        lands the Stars, never back.
--   the welcome gift, the card's hero (Spencer OK'd it 2026-11-27; ONBOARDING-FUN-PASS section 4): "+5 ★ Welcome
--        gift!", only once the server says Saved (WelcomeGift: once per save, paid in the save). From T.gift (0.9, or
--        when the answer lands, if later) the card grows Gift.grow px over 0.2 s and the gold pill pops; five gold Stars
--        burst from the pet's headshot and fly to it one by one (Gift.gap s apart, Gift.fly s each), each landing counts
--        one with `charge` rising; the last lands with `stars_total`, a `land` buzz and the pill punches 1.3. The sub-line
--        becomes "A welcome gift from {pet}.". A late answer keeps the card up Gift.hold s more (at most T.lifeMax).
--        Refused, slow or never: the card is exactly the one above, never held.
-- Reduced Motion: no confetti, spin or sweep (and the gift's count lands at once); the sound and the buzz stay.
-- The top half is pure (spec-checked offline); show() builds the card.
--   AllSetCard.show(playerGui, {copy(key, vars), pet (name), petId, appearance, play(cue, speed, gain), haptic(name),
--     reduced(), cheer() (the server's jump-spin), next() (opens Things to do), done(),
--     gift(arrived) (optional: asks the server once; calls arrived(stars) only on Saved),
--     canHatch() (optional: the Stars cover the cheapest egg now), hatch() (optional: the way to the egg machine)})
--     -> card ({close(), gift(stars)})
local Card={};Card.__index=Card

-- ── Pure ─────────────────────────────────────────────────────────────────────────────────────────────────────────────
Card.T=table.freeze({card=.15,stamps={.3,.38,.46},title=.6,sub=1.2,life=5,lifeMax=7,gift=.9,closeAfter=.4,
	pop=.3,popFrom=.85,popPeak=1.05,stamp=.12,stampFrom=1.4,punch=1.45,punchTime=.12,sweep=.5,cheer=0})
Card.Size=table.freeze({w=320,h=210,maxW=360,maxH=260,corner=22,headshot=72,glass=.15,stamp=44,stampGap=76,pill=34,pillW=220,pillY=134})
Card.Ink=Color3.fromHex("#0E0F12")
Card.Gold=Color3.fromHex("#FFC14D")
Card.Button=Color3.fromHex("#FFC14D")
Card.Confetti=table.freeze({Color3.fromHex("#22B8F2"),Color3.fromHex("#FFB52A"),Color3.fromHex("#2FCB5A"),Color3.fromHex("#FF6FA8")})
Card.Bubbles=24;Card.Dots=16;Card.Rise=1.8
Card.Stamps=table.freeze({{key="onbAllSet.pet",icon="hand"},{key="onbAllSet.nest",icon="moon"},{key="onbAllSet.stars",icon="deck"}})
-- The sounds and buzzes, in time (existing cues only): {at, cue, speed} and {at, haptic}.
Card.Cues=table.freeze({{at=0,cue="charge",speed=1},{at=.3,cue="charge",speed=1.12},{at=.38,cue="charge",speed=1.26},
	{at=.46,cue="charge",speed=1.5},{at=.6,cue="rarity_common",speed=1}})
Card.Buzz=table.freeze({{at=0,haptic="settle"},{at=.3,haptic="land"},{at=.38,haptic="land"},{at=.46,haptic="land"},{at=.6,haptic="pop"}})
-- Pure: the button's words: "Hatch one!" when the Stars cover the cheapest egg, else "What's next?".
function Card.buttonKey(canHatch)return if canHatch==true then "onbAllSet.hatch"else "onbAllSet.next"end
local function smooth(u)u=math.clamp(u,0,1);return u*u*(3-2*u)end
-- Pure: the card's scale at t (nil before it shows).
function Card.cardScale(t)
	local T=Card.T
	local age=t-T.card
	if age<0 then return nil end
	if age>=T.pop then return 1 end
	local u=age/T.pop
	if u<.6 then return T.popFrom+(T.popPeak-T.popFrom)*smooth(u/.6)end
	return T.popPeak+(1-T.popPeak)*smooth((u-.6)/.4)
end
-- Pure: stamp i's scale at t (nil before it lands).
function Card.stampScale(i,t)
	local T=Card.T
	local at=T.stamps[i]
	if not at or t<at then return nil end
	local u=math.clamp((t-at)/T.stamp,0,1)
	return T.stampFrom+(1-T.stampFrom)*smooth(u)
end
-- Pure: the title's scale at t (nil before it shows).
function Card.titleScale(t)
	local T=Card.T
	if t<T.title then return nil end
	local u=math.clamp((t-T.title)/T.punchTime,0,1)
	return T.punch+(1-T.punch)*smooth(u)
end
-- Pure: the light sweep's place across the card (0..1) at t, nil when there is none (Reduced Motion, or over).
function Card.sweep(t,reduced)
	local T=Card.T
	if reduced or t<T.title or t>T.title+T.sweep then return nil end
	return(t-T.title)/T.sweep
end
-- Pure: may a tap or B/Esc close it at t? And is it over by itself (life: Card.life's, default T.life)?
function Card.closable(t)return t>=Card.T.closeAfter end
function Card.over(t,life)return t>=(life or Card.T.life)end

-- The welcome gift. `arrived`: the card's clock when the server's Saved landed (nil: no gift, the card as before).
-- The fun pass: each Star flies `fly` s from the headshot to the pill, `gap` s after the one before (at most `stars`
-- fly; the last landing shows the whole total); the pill punches to `punch` over `punchTime` s as the last lands.
Card.Gift=table.freeze({grow=34,growTime=.2,hold=2.2,pop=.18,popFrom=.6,fly=.35,gap=.08,stars=10,punch=1.3,punchTime=.25,
	star=26,spread=44,lift=26})
-- Pure: when the gift row starts (never before the stamps are done).
function Card.giftAt(arrived)
	if type(arrived)~="number"then return nil end
	return math.max(arrived,Card.T.gift)
end
-- Pure: the card's life with a gift that landed at `arrived` (a late one stays Gift.hold s, at most T.lifeMax).
function Card.life(arrived)
	local at=Card.giftAt(arrived)
	if not at or at>=Card.T.life then return Card.T.life end -- after the card's own end: too late, no gift shown
	return math.min(Card.T.lifeMax,math.max(Card.T.life,at+Card.Gift.hold))
end
-- Pure: how many Stars fly for a gift of `total` (Gift.stars at most).
function Card.giftFlying(total)return math.clamp(math.floor(tonumber(total)or 0),0,Card.Gift.stars)end
-- Pure: when Star i (1..) lands, the gift starting at `at`.
function Card.giftLand(i,at)return at+(i-1)*Card.Gift.gap+Card.Gift.fly end
-- Pure: the Stars shown on the pill at t (nil before it starts): one more as each flying Star lands, the whole total
-- with the last (Reduced Motion: the total at once).
function Card.giftCount(t,arrived,total,reduced)
	local at=Card.giftAt(arrived)
	if not at or t<at or at>=Card.T.life then return nil end
	total=math.max(0,math.floor(tonumber(total)or 0))
	if reduced then return total end
	local n=Card.giftFlying(total)
	local landed=0
	for i=1,n do if t>=Card.giftLand(i,at)then landed=i end end
	return if landed>=n then total else landed
end
-- Pure: Star i's flight at t: its progress (0 at the headshot .. 1 at the pill), or nil when it is not in the air
-- (not yet launched, landed, Reduced Motion, or past what flies).
function Card.giftStar(i,t,arrived,total,reduced)
	local at=Card.giftAt(arrived)
	if reduced or not at or at>=Card.T.life or i>Card.giftFlying(total)then return nil end
	if t>=Card.giftLand(i,at)then return nil end -- landed (the count's own test, so the two always agree)
	local u=(t-(at+(i-1)*Card.Gift.gap))/Card.Gift.fly
	if u<0 then return nil end
	return u
end
-- Pure: Star i of n's place at u from `from` to `to` (card pixels, y down): a curve bowed up and fanned out.
function Card.giftPath(i,n,u,from,to)
	local G=Card.Gift
	u=math.clamp(u,0,1)
	local side=if n>1 then((i-1)/(n-1)-.5)*2 else 0
	local mid=(from+to)/2+Vector2.new(side*G.spread,-G.lift)
	local e=u*u*(3-2*u)
	local v=1-e
	return from*(v*v)+mid*(2*v*e)+to*(e*e)
end
-- Pure: the pill's scale at t (nil before it starts): it pops in, then punches to Gift.punch as the last Star lands.
function Card.giftScale(t,arrived,reduced,total)
	local at=Card.giftAt(arrived)
	if not at or t<at or at>=Card.T.life then return nil end
	if reduced then return 1 end
	local G=Card.Gift
	local n=Card.giftFlying(total)
	if n>0 then
		local age=t-Card.giftLand(n,at)
		if age>=0 and age<G.punchTime then return 1+(G.punch-1)*math.sin(age/G.punchTime*math.pi)end
	end
	return G.popFrom+(1-G.popFrom)*smooth((t-at)/G.pop)
end
-- Pure: how far the card has grown for the gift row at t (0..Gift.grow px).
function Card.giftGrow(t,arrived)
	local at=Card.giftAt(arrived)
	if not at or t<at or at>=Card.T.life then return 0 end
	return Card.Gift.grow*smooth((t-at)/Card.Gift.growTime)
end
-- Pure: the cues for a count moving from `before` to `count`: `charge` rising a step for each Star landed,
-- stars_total on reaching the total.
function Card.giftCues(before,count,total)
	local out={}
	if type(count)~="number"then return out end
	before=before or -1
	for n=math.max(1,before+1),math.min(count,Card.Gift.stars)do table.insert(out,{cue="charge",speed=1+.08*n})end
	if count>=total and before<total then table.insert(out,{cue="stars_total",speed=1})end
	return out
end
-- Pure: the cues and buzzes due in (from, to].
function Card.due(list,from,to)
	local out={}
	for _,entry in ipairs(list)do if entry.at>from and entry.at<=to or(from<0 and entry.at==0 and to>=0)then table.insert(out,entry)end end
	return out
end
-- Pure: a rising bit (bubble or dot) i of n: its x (0..1 across), its delay and speed (screens a second), from a seed.
function Card.particle(i,n,kind)
	local seed=(i*7919+(if kind=="dot"then 104729 else 0))%1000/1000
	local x=((i-.5)/n+seed*.35)%1
	return x,seed*.35,.45+seed*.35
end

-- ── The card ─────────────────────────────────────────────────────────────────────────────────────────────────────────
local function node(class,parent,props)
	local n=Instance.new(class)
	for k,v in pairs(props or {})do n[k]=v end
	n.Parent=parent;return n
end
local build
-- The card, or nil when building it threw: then nothing is left on screen (no full-screen tap catcher swallowing taps).
function Card.show(parent,deps)
	deps=deps or {}
	local gui=node("ScreenGui",parent,{Name="EggDropAllSet2",ResetOnSpawn=false,DisplayOrder=14,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
		ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets,IgnoreGuiInset=false})
	local self=setmetatable({gui=gui,open=true,t=0,deps=deps},Card)
	local ok,problem=pcall(build,self,gui,deps)
	if not ok then
		warn("[AllSet] build: "..tostring(problem))
		self.open=false
		if self.link then pcall(function()self.link:Disconnect()end)end
		if self.action then pcall(function()game:GetService("ContextActionService"):UnbindAction(self.action)end)end
		pcall(function()gui:Destroy()end)
		return nil
	end
	return self
end
build=function(self,gui,deps)
	local RunService=game:GetService("RunService")
	local ContextActionService=game:GetService("ContextActionService")
	local copy=function(key,vars)local ok,t=pcall(deps.copy,key,vars);return if ok and type(t)=="string"then t else ""end
	local reduced=deps.reduced~=nil and deps.reduced()==true
	-- the rising bubbles and confetti
	local rise=node("Frame",gui,{Name="Rise",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=2,Active=false})
	self.bits={}
	if not reduced then
		for i=1,Card.Bubbles do
			local size=14+((i*37)%18)
			local b=node("Frame",rise,{Name="Bubble"..i,AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(size,size),BackgroundColor3=Color3.new(1,1,1),
				BackgroundTransparency=.82,BorderSizePixel=0,ZIndex=2})
			node("UICorner",b,{CornerRadius=UDim.new(.5,0)})
			node("UIStroke",b,{Color=Color3.new(1,1,1),Thickness=1.5,Transparency=.35})
			local x,delay,speed=Card.particle(i,Card.Bubbles,"bubble")
			table.insert(self.bits,{gui=b,x=x,delay=delay,speed=speed,sway=.02})
		end
		for i=1,Card.Dots do
			local d=node("Frame",rise,{Name="Dot"..i,AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(9,9),BackgroundColor3=Card.Confetti[(i-1)%#Card.Confetti+1],
				BorderSizePixel=0,ZIndex=3})
			node("UICorner",d,{CornerRadius=UDim.new(.5,0)})
			local x,delay,speed=Card.particle(i,Card.Dots,"dot")
			table.insert(self.bits,{gui=d,x=x,delay=delay,speed=speed*1.2,sway=.04})
		end
	end
	local S=Card.Size
	local card=node("Frame",gui,{Name="Card",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.52),Size=UDim2.fromOffset(S.w,S.h),
		BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=S.glass,BorderSizePixel=0,ZIndex=4,Visible=false,ClipsDescendants=false})
	node("UICorner",card,{CornerRadius=UDim.new(0,S.corner)})
	node("UIStroke",card,{Color=Color3.new(1,1,1),Thickness=2,Transparency=.2})
	node("UISizeConstraint",card,{MaxSize=Vector2.new(S.maxW,S.maxH)})
	self.card,self.cardScale=card,node("UIScale",card,{Scale=Card.T.popFrom})
	-- the light sweep, clipped to the card
	local clip=node("Frame",card,{Name="SweepClip",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ClipsDescendants=true,ZIndex=5})
	node("UICorner",clip,{CornerRadius=UDim.new(0,S.corner)})
	self.sweep=node("Frame",clip,{Name="Sweep",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(-.3,.5),Size=UDim2.new(0,46,1.6,0),Rotation=18,
		BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=.45,BorderSizePixel=0,Visible=false,ZIndex=5})
	-- the headshot over the top edge
	local shot=node("Frame",card,{Name="Headshot",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,0,0),Size=UDim2.fromOffset(S.headshot,S.headshot),
		BackgroundColor3=Color3.fromHex("#FFF4DC"),BorderSizePixel=0,ZIndex=6})
	node("UICorner",shot,{CornerRadius=UDim.new(.5,0)})
	node("UIStroke",shot,{Color=Color3.new(1,1,1),Thickness=3})
	local paw=node("TextLabel",shot,{Name="Paw",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Text="🐾",TextScaled=true,ZIndex=7})
	self.shot,self.paw=shot,paw
	pcall(function()
		local Headshot=require(script.Parent.PetHeadshot)
		self.shots=Headshot.newCache()
		self.shotCard=function()return Headshot.card(shot,deps.petId,deps.appearance,false,true)end
	end)
	-- the stamps
	self.stamps={}
	local ok,Bubble=pcall(require,script.Parent.NeedBubble)
	-- the fun pass: 44 px stamps (were 64), so the gift below them is the card's hero
	local stampPx=S.stamp
	for i,entry in ipairs(Card.Stamps)do
		local x=(i-2)*S.stampGap
		local holder=node("Frame",card,{Name="Stamp"..i,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,x,0,86),Size=UDim2.fromOffset(stampPx,stampPx),
			BackgroundTransparency=1,Visible=false,ZIndex=6})
		local disc=node("Frame",holder,{Name="Disc",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(stampPx-6,stampPx-6),
			BackgroundColor3=Color3.fromHex("#F3F6FB"),BorderSizePixel=0,ZIndex=6})
		node("UICorner",disc,{CornerRadius=UDim.new(.5,0)})
		node("UIStroke",disc,{Color=Card.Ink,Thickness=2})
		local id=ok and Bubble.IconIds[entry.icon]
		if id then node("ImageLabel",disc,{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(.66,.66),
			Image="rbxassetid://"..id,ZIndex=7})end
		local tick=node("TextLabel",holder,{Name="Tick",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(1,-4,0,6),Size=UDim2.fromOffset(18,18),
			BackgroundColor3=Card.Gold,Text="✓",TextColor3=Color3.new(1,1,1),Font=Enum.Font.BuilderSansExtraBold,TextSize=12,BorderSizePixel=0,ZIndex=8})
		node("UICorner",tick,{CornerRadius=UDim.new(.5,0)})
		node("TextLabel",holder,{Name="Label",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,1,1),Size=UDim2.fromOffset(72,16),BackgroundTransparency=1,
			Font=Enum.Font.BuilderSansBold,TextSize=13,TextColor3=Card.Ink,Text=copy(entry.key),ZIndex=6})
		table.insert(self.stamps,{holder=holder,scale=node("UIScale",holder,{Scale=Card.T.stampFrom})})
	end
	-- the title, the sub-line and the button
	self.title=node("TextLabel",card,{Name="Title",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,0,52),Size=UDim2.new(1,-24,0,34),BackgroundTransparency=1,
		Font=Enum.Font.BuilderSansExtraBold,TextSize=28,TextColor3=Card.Ink,Text=copy("onbAllSet.title"),Visible=false,ZIndex=6})
	self.titleScale=node("UIScale",self.title,{Scale=1})
	-- the welcome gift's gold pill under the stamps (hidden until the server's Saved)
	-- the fun pass: the gift is the hero, a bigger pill the Stars fly into from the headshot
	self.giftPill=node("Frame",card,{Name="WelcomeGift",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,S.pillY),Size=UDim2.fromOffset(S.pillW,S.pill),
		BackgroundColor3=Card.Gold,BorderSizePixel=0,Visible=false,ZIndex=6})
	node("UICorner",self.giftPill,{CornerRadius=UDim.new(.5,0)})
	node("UIStroke",self.giftPill,{Color=Card.Ink,Thickness=2})
	self.giftScale=node("UIScale",self.giftPill,{Scale=Card.Gift.popFrom})
	self.giftText=node("TextLabel",self.giftPill,{Name="Text",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Font=Enum.Font.BuilderSansExtraBold,
		TextSize=20,TextColor3=Card.Ink,Text="",ZIndex=7})
	self.flyers={}
	for i=1,Card.Gift.stars do
		local star=node("TextLabel",card,{Name="GiftStar"..i,AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(Card.Gift.star,Card.Gift.star),BackgroundTransparency=1,
			Text="★",TextScaled=true,Font=Enum.Font.BuilderSansExtraBold,TextColor3=Card.Gold,TextStrokeColor3=Card.Ink,TextStrokeTransparency=.2,
			Visible=false,ZIndex=9})
		self.flyers[i]=star
	end
	self.copy=copy
	self.petName=deps.pet or "Bear"
	self.sub=node("TextLabel",card,{Name="Sub",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,138),Size=UDim2.new(1,-24,0,20),BackgroundTransparency=1,
		Font=Enum.Font.BuilderSansBold,TextSize=16,TextColor3=Card.Ink,TextTransparency=.15,Text=copy("onbAllSet.sub",{pet=self.petName}),Visible=false,ZIndex=6})
	self.button=node("TextButton",card,{Name="WhatsNext",AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-12),Size=UDim2.fromOffset(168,38),
		BackgroundColor3=Card.Button,Text=copy("onbAllSet.next"),TextColor3=Card.Ink,Font=Enum.Font.BuilderSansExtraBold,TextSize=18,AutoButtonColor=true,
		BorderSizePixel=0,Visible=false,Selectable=true,ZIndex=7})
	node("UICorner",self.button,{CornerRadius=UDim.new(0,19)})
	self.button.Activated:Connect(function()
		if not self.open then return end
		local hatch=self.hatchReady==true
		self:close()
		-- "Hatch one!": the way to the egg machine (its crank and emerge play before any reveal); else Things to do
		if hatch and deps.hatch then pcall(deps.hatch)elseif deps.next then pcall(deps.next)end
	end)
	local function tryClose()if Card.closable(self.t)then self:close()end end
	-- the full-screen tap catcher last (under everything: ZIndex 1), once the rest is built
	local hit=node("TextButton",gui,{Name="TapToClose",Text="",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),AutoButtonColor=false,ZIndex=1})
	hit.Activated:Connect(tryClose)
	card.InputBegan:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then tryClose()end
	end)
	self.action="EggDropAllSet2Close"
	ContextActionService:BindActionAtPriority(self.action,function(_,state)
		if state~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
		tryClose()
		return Enum.ContextActionResult.Sink
	end,false,Enum.ContextActionPriority.High.Value,Enum.KeyCode.ButtonB,Enum.KeyCode.Escape)
	if deps.cheer then pcall(deps.cheer)end
	-- the welcome gift: asked once; only a Saved answer while the card is up shows it
	if deps.gift then pcall(deps.gift,function(stars)self:gift(stars)end)end
	local last=-1
	self.link=RunService.RenderStepped:Connect(function(dt)
		local good,problem=pcall(self.step,self,dt,last,reduced)
		last=self.t
		if not good then warn("[AllSet] "..tostring(problem));self:close()end
	end)
end
-- The server's Saved landed: show the gift from now (once; nothing after the card's own end or once it closed).
function Card:gift(stars)
	if not self.open or self.giftArrived or self.t>=Card.T.life then return false end
	self.giftArrived=self.t;self.giftStars=math.max(0,math.floor(tonumber(stars)or 0))
	return true
end
function Card:step(dt,last,reduced)
	self.t+=dt
	local t,d=self.t,self.deps
	for _,entry in ipairs(Card.due(Card.Cues,last,t))do if d.play then pcall(d.play,entry.cue,entry.speed,.5)end end
	for _,entry in ipairs(Card.due(Card.Buzz,last,t))do if d.haptic then pcall(d.haptic,entry.haptic)end end
	for _,bit in ipairs(self.bits)do
		local age=t-bit.delay
		local y=1.05-age*bit.speed
		bit.gui.Visible=age>=0 and y>-.1
		if bit.gui.Visible then bit.gui.Position=UDim2.fromScale(bit.x+math.sin(age*3+bit.x*6)*bit.sway,y)end
	end
	local scale=Card.cardScale(t)
	self.card.Visible=scale~=nil
	if scale then self.cardScale.Scale=if reduced then 1 else scale end
	for i,stamp in ipairs(self.stamps)do
		local s=Card.stampScale(i,t)
		stamp.holder.Visible=s~=nil
		if s then stamp.scale.Scale=if reduced then 1 else s end
	end
	local title=Card.titleScale(t)
	self.title.Visible=title~=nil
	if title then self.titleScale.Scale=if reduced then 1 else title end
	local sweep=Card.sweep(t,reduced)
	self.sweep.Visible=sweep~=nil
	if sweep then self.sweep.Position=UDim2.fromScale(-.3+1.6*sweep,.5)end
	local late=t>=Card.T.sub
	self.sub.Visible=late;self.button.Visible=late
	-- "Hatch one!" once the Stars cover the cheapest egg (never back to "What's next?")
	if late and not self.hatchReady and d.canHatch and d.hatch then
		local okHatch,can=pcall(d.canHatch)
		if okHatch and can==true then self.hatchReady=true end
	end
	local key=Card.buttonKey(self.hatchReady)
	if self.buttonKey~=key then self.buttonKey=key;self.button.Text=self.copy(key)end
	-- the welcome gift: the card grows, the pill pops, the Stars fly into it from the headshot and count up one by one
	local arrived=self.giftArrived
	local grow=Card.giftGrow(t,arrived)
	self.card.Size=UDim2.fromOffset(Card.Size.w,Card.Size.h+grow)
	self.sub.Position=UDim2.new(.5,0,0,138+grow)
	local count=Card.giftCount(t,arrived,self.giftStars,reduced)
	self.giftPill.Visible=count~=nil
	if count~=nil then
		if not self.giftWords then self.giftWords=true;self.sub.Text=self.copy("onbAllSet.giftSub",{pet=self.petName})end
		self.giftScale.Scale=Card.giftScale(t,arrived,reduced,self.giftStars)or 1
		self.giftText.Text=self.copy("onbAllSet.gift",{count=count})
		-- Reduced Motion: the count lands at once, so one stars_total and no run of charges
		local cues=if reduced then(if self.giftShown==nil then {{cue="stars_total",speed=1}}else {})else Card.giftCues(self.giftShown,count,self.giftStars)
		for _,entry in ipairs(cues)do if d.play then pcall(d.play,entry.cue,entry.speed,.45)end end
		if d.haptic and(if reduced then self.giftShown==nil else(count>=self.giftStars and(self.giftShown or -1)<self.giftStars))then pcall(d.haptic,"land")end
		self.giftShown=count
	end
	-- the flying Stars: from the headshot (the card's top centre) to the pill's centre
	local n=Card.giftFlying(self.giftStars)
	local from=Vector2.new(Card.Size.w/2,0)
	local to=Vector2.new(Card.Size.w/2,Card.Size.pillY+Card.Size.pill/2)
	for i,star in ipairs(self.flyers)do
		local u=if count~=nil then Card.giftStar(i,t,arrived,self.giftStars,reduced)else nil
		star.Visible=u~=nil
		if u then
			local p=Card.giftPath(i,n,u,from,to)
			star.Position=UDim2.fromOffset(math.floor(p.X+.5),math.floor(p.Y+.5))
			star.Rotation=u*200
		end
	end
	if self.shots and self.shotCard then
		self.shots:pump({self.shotCard()},function()self.paw.Visible=false end)
	end
	if Card.over(t,Card.life(arrived))then self:close()end
end
function Card:close()
	if not self.open then return end
	self.open=false
	if self.link then self.link:Disconnect();self.link=nil end
	pcall(function()game:GetService("ContextActionService"):UnbindAction(self.action)end)
	if self.shots then pcall(function()self.shots:clear()end)end
	self.gui:Destroy()
	if self.deps.done then pcall(self.deps.done)end
end
return Card
