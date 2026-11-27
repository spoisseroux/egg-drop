-- "You're all set!" (onboarding v3 brief section 3, switch Onboard "allset2"; Spencer's beta 37 note 7: "the youre all
-- set should be more fun and exciting too"). Shows only when Pet, Nest and Stars are truly done, in the garden, with no
-- menu open (BearNeeds waits for that). 5 s; any tap, B or Esc closes it once it has been up 0.4 s.
--   0.0  the Bear jumps and spins (the server's leadCheer, every screen); 24 Aero bubbles and 16 confetti dots rise
--        from the bottom edge; `charge` at 1.0; a tick buzz
--   0.15 the card pops (0.85 -> 1.05 -> 1.0 over 0.3 s), the pet's headshot poking over its top edge
--   0.3, 0.5, 0.7  three stamps (Pet, Nest, Stars) land with a gold tick: 1.4 -> 1.0 in 0.12 s, `charge` 1.12 / 1.26 /
--        1.5, a tick buzz each
--   0.9  the title punches (1.45 -> 1): `rarity_common`, a `pop` buzz, one light sweep across the card
--   1.2  "{pet} loves it here." and the gold "What's next?" button (opens Things to do)
-- Reduced Motion: no confetti, spin or sweep; the sound and the buzz stay. No "+5 welcome gift": not confirmed.
-- The top half is pure (spec-checked offline); show() builds the card.
--   AllSetCard.show(playerGui, {copy(key, vars), pet (name), petId, appearance, play(cue, speed, gain), haptic(name),
--     reduced(), cheer() (the server's jump-spin), next() (opens Things to do), done()}) -> card ({close()})
local Card={};Card.__index=Card

-- ── Pure ─────────────────────────────────────────────────────────────────────────────────────────────────────────────
Card.T=table.freeze({card=.15,stamps={.3,.5,.7},title=.9,sub=1.2,life=5,closeAfter=.4,
	pop=.3,popFrom=.85,popPeak=1.05,stamp=.12,stampFrom=1.4,punch=1.45,punchTime=.12,sweep=.5,cheer=0})
Card.Size=table.freeze({w=320,h=210,maxW=360,maxH=230,corner=22,headshot=72,glass=.15})
Card.Ink=Color3.fromHex("#0E0F12")
Card.Gold=Color3.fromHex("#FFC14D")
Card.Button=Color3.fromHex("#FFC14D")
Card.Confetti=table.freeze({Color3.fromHex("#22B8F2"),Color3.fromHex("#FFB52A"),Color3.fromHex("#2FCB5A"),Color3.fromHex("#FF6FA8")})
Card.Bubbles=24;Card.Dots=16;Card.Rise=1.8
Card.Stamps=table.freeze({{key="onbAllSet.pet",icon="hand"},{key="onbAllSet.nest",icon="moon"},{key="onbAllSet.stars",icon="deck"}})
-- The sounds and buzzes, in time (existing cues only): {at, cue, speed} and {at, haptic}.
Card.Cues=table.freeze({{at=0,cue="charge",speed=1},{at=.3,cue="charge",speed=1.12},{at=.5,cue="charge",speed=1.26},
	{at=.7,cue="charge",speed=1.5},{at=.9,cue="rarity_common",speed=1}})
Card.Buzz=table.freeze({{at=0,haptic="settle"},{at=.3,haptic="land"},{at=.5,haptic="land"},{at=.7,haptic="land"},{at=.9,haptic="pop"}})
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
-- Pure: may a tap or B/Esc close it at t? And is it over by itself?
function Card.closable(t)return t>=Card.T.closeAfter end
function Card.over(t)return t>=Card.T.life end
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
	for i,entry in ipairs(Card.Stamps)do
		local x=(i-2)*92
		local holder=node("Frame",card,{Name="Stamp"..i,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,x,0,84),Size=UDim2.fromOffset(64,64),
			BackgroundTransparency=1,Visible=false,ZIndex=6})
		local disc=node("Frame",holder,{Name="Disc",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(54,54),
			BackgroundColor3=Color3.fromHex("#F3F6FB"),BorderSizePixel=0,ZIndex=6})
		node("UICorner",disc,{CornerRadius=UDim.new(.5,0)})
		node("UIStroke",disc,{Color=Card.Ink,Thickness=2})
		local id=ok and Bubble.IconIds[entry.icon]
		if id then node("ImageLabel",disc,{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(.66,.66),
			Image="rbxassetid://"..id,ZIndex=7})end
		local tick=node("TextLabel",holder,{Name="Tick",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(1,-6,0,8),Size=UDim2.fromOffset(24,24),
			BackgroundColor3=Card.Gold,Text="✓",TextColor3=Color3.new(1,1,1),Font=Enum.Font.BuilderSansExtraBold,TextSize=16,BorderSizePixel=0,ZIndex=8})
		node("UICorner",tick,{CornerRadius=UDim.new(.5,0)})
		node("TextLabel",holder,{Name="Label",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,1,2),Size=UDim2.fromOffset(84,20),BackgroundTransparency=1,
			Font=Enum.Font.BuilderSansBold,TextSize=15,TextColor3=Card.Ink,Text=copy(entry.key),ZIndex=6})
		table.insert(self.stamps,{holder=holder,scale=node("UIScale",holder,{Scale=Card.T.stampFrom})})
	end
	-- the title, the sub-line and the button
	self.title=node("TextLabel",card,{Name="Title",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,0,52),Size=UDim2.new(1,-24,0,34),BackgroundTransparency=1,
		Font=Enum.Font.BuilderSansExtraBold,TextSize=28,TextColor3=Card.Ink,Text=copy("onbAllSet.title"),Visible=false,ZIndex=6})
	self.titleScale=node("UIScale",self.title,{Scale=1})
	self.sub=node("TextLabel",card,{Name="Sub",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,140),Size=UDim2.new(1,-24,0,20),BackgroundTransparency=1,
		Font=Enum.Font.BuilderSansBold,TextSize=16,TextColor3=Card.Ink,TextTransparency=.15,Text=copy("onbAllSet.sub",{pet=deps.pet or "Bear"}),Visible=false,ZIndex=6})
	self.button=node("TextButton",card,{Name="WhatsNext",AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-12),Size=UDim2.fromOffset(168,38),
		BackgroundColor3=Card.Button,Text=copy("onbAllSet.next"),TextColor3=Card.Ink,Font=Enum.Font.BuilderSansExtraBold,TextSize=18,AutoButtonColor=true,
		BorderSizePixel=0,Visible=false,Selectable=true,ZIndex=7})
	node("UICorner",self.button,{CornerRadius=UDim.new(0,19)})
	self.button.Activated:Connect(function()
		if not self.open then return end
		self:close()
		if deps.next then pcall(deps.next)end
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
	local last=-1
	self.link=RunService.RenderStepped:Connect(function(dt)
		local good,problem=pcall(self.step,self,dt,last,reduced)
		last=self.t
		if not good then warn("[AllSet] "..tostring(problem));self:close()end
	end)
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
	if self.shots and self.shotCard then
		self.shots:pump({self.shotCard()},function()self.paw.Visible=false end)
	end
	if Card.over(t)then self:close()end
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
