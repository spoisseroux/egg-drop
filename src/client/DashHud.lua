-- Garden Dash race screen (V3-DASH-BUILD-PLAN-2026-11-22, slice S7): the two pads with the closing ring, the dash bar,
-- place, the progress strip, the countdown, the stones key and the Leave key. Made the first time a race is held
-- and hidden after. A frame writes a property only when the whole pixel (or word) it shows has changed.
-- Beta 12 U4 (DASH-DECK-UI-LOOK): each pad is a key (opaque face, ink ring, 5 pt ink lip) with a drawn icon
-- (DashIcons; the frame-built bolt and spring until the upload), its word under the icon and, for keys or a gamepad,
-- a key cap at its top right. The face drops into its lip on a press and stays down while Dash is held; out of puff
-- it goes grey and says "Phew!"; a Perfect flashes the Jump pad. Countdown digits high (26%), the place in a pill
-- beside the progress strip, the strip with hoop ticks and a flag at its end. Reduced Motion: no drop, no flash.
local UserInputService=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local UICopy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
local Hud={};Hud.__index=Hud
Hud.Pad=96
Hud.PadLarge=108
Hud.Margin=16
Hud.RingTicks=100 -- the ring starts to close this long before the take-off spot
Hud.WordSeconds=.8
Hud.DisplayOrder=9
Hud.Seats=8
Hud.Ink=Color3.fromHex("#15143A")
Hud.Jump=Color3.fromHex("#43DB5F")
Hud.Dash=Color3.fromHex("#FFE14D")
Hud.Puff=Color3.fromHex("#B9B6C9")
Hud.Stones=Color3.fromHex("#8FD3FF")
Hud.Cream=Color3.fromHex("#FFF4DC")
Hud.Lip=5
Hud.Drop=4
Hud.Icon=50
Hud.IconTop=9
Hud.WordAt=.76
Hud.Cap=20
Hud.CapIn=8 -- the key cap overlaps the pad this much
Hud.CapEdge=8 -- FABLE-REVIEW-R1 5: a cap's edge at least this far inside the safe area
Hud.CapText=11 -- and its word at least this size
Hud.PlaceW=54
Hud.PlaceH=24
Hud.StripH=20
Hud.DigitsAt=.26
local function box(x,y,w,h)return{x=math.floor(x),y=math.floor(y),w=math.floor(w),h=math.floor(h)}end
-- Pure: every piece for a safe area of W x H px.
function Hud.layout(W,H)
	local m=Hud.Margin
	local pad=if H<=430 or W<=700 then Hud.Pad else Hud.PadLarge
	local jump=box(W-m-pad,H-m-pad,pad,pad)
	local dash=box(m,H-m-pad,pad,pad)
	-- The strip in the middle of the top, the place pill just left of it, the Leave key in the right corner.
	local side=m+Hud.PlaceW+8+8
	local strip=box(0,14,math.clamp(W-side*2,80,380),Hud.StripH)
	strip.x=math.floor((W-strip.w)/2)
	local digitsH=if H<=430 then 84 else 110
	return{W=W,H=H,pad=pad,jump=jump,dash=dash,
		zoneDash=box(0,0,W/2,H),zoneJump=box(W/2,0,W-math.floor(W/2),H),
		stones=box(jump.x+(pad-72)/2,jump.y-12-56,72,56),
		bar=box(dash.x,dash.y-12-14,pad,14),
		strip=strip,place=box(strip.x-8-Hud.PlaceW,strip.y+(Hud.StripH-Hud.PlaceH)/2,Hud.PlaceW,Hud.PlaceH),leave=box(W-m-44,4,44,44),
		digits=box((W-200)/2,math.max(strip.y+strip.h+6,H*Hud.DigitsAt-digitsH/2),200,digitsH),
		word=box((W-240)/2,math.max(52+digitsH,H/2+digitsH/2-12),240,34),
		hint=box((W-280)/2,math.max(52+digitsH,H/2+digitsH/2-12)+36,280,34)}
end
-- Pure: a key cap `width` px wide on the `name` pad ("jump" or "dash"), overlapping the pad's top right by CapIn; when
-- that would come nearer than CapEdge to the safe area's right edge, the pad's top left instead (Jump, on the right,
-- always), so a wide word ("Space", "Shift") grows toward the middle of the screen (Studio check beta 12: "Space" ran
-- off the right edge; FABLE-REVIEW-R1 5).
function Hud.capBox(l,name,width)
	local p=l[name]
	local x=p.x+p.w-Hud.CapIn
	if x+width>l.W-Hud.CapEdge then x=p.x+Hud.CapIn-width end
	return box(math.clamp(x,Hud.CapEdge,math.max(Hud.CapEdge,l.W-Hud.CapEdge-width)),p.y+Hud.CapIn-Hud.Cap,width,Hud.Cap)
end
-- Pure: the ring's size as a multiple of the pad, `ticks` before the take-off spot; nil = not shown.
function Hud.ring(ticks,first)
	if ticks==nil or ticks>Hud.RingTicks or ticks< -12 then return nil end
	return 1+math.max(0,ticks)/Hud.RingTicks*(if first then 1.7 else 1.2)
end
function Hud.ordinal(place)return UICopy.get("dash.ordinal.p"..math.clamp(math.floor(place),1,8))end

local function put(object,b)
	object.Position=UDim2.fromOffset(b.x,b.y);object.Size=UDim2.fromOffset(b.w,b.h)
end
local function make(class,parent,props)
	local object=Instance.new(class)
	for key,value in pairs(props)do object[key]=value end
	object.Parent=parent
	return object
end
local function round(parent,radius)return make("UICorner",parent,{CornerRadius=radius or UDim.new(.5,0)})end
local function bar(parent,x,y,w,h,rotation)
	local item=make("Frame",parent,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(x,y),Size=UDim2.fromScale(w,h),Rotation=rotation or 0,
		BackgroundColor3=Hud.Ink,BorderSizePixel=0,ZIndex=parent.ZIndex+1,Active=false})
	round(item)
	return item
end

-- options: leave()
function Hud.new(playerGui,options)
	local Kit=require(script.Parent.DeckKit)
	local self=setmetatable({dots={},shown={},options=options},Hud)
	local gui=make("ScreenGui",nil,{Name="EggDropDash",ResetOnSpawn=false,ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets,DisplayOrder=Hud.DisplayOrder,
		ZIndexBehavior=Enum.ZIndexBehavior.Sibling,ClipToDeviceSafeArea=false,Enabled=false})
	local root=make("Frame",gui,{Name="Root",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=1,Active=false})
	-- The half-screen zones lie under everything else.
	local function zone(name)
		return make("Frame",root,{Name=name,BackgroundTransparency=1,ZIndex=1,Active=true,Visible=false,Selectable=false})
	end
	self.zones={dash=zone("DashZone"),jump=zone("JumpZone")}
	local Icons=require(script.Parent.DashIcons)
	self.faces={}
	-- A pad: a clear box the layout places, an ink lip, the face on it (icon, word), the key cap (keys() makes it).
	local function pad(name,color,key,icon,caps)
		local frame=make("Frame",root,{Name=name,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=4,Active=false})
		local lip=make("Frame",frame,{Name="Lip",BackgroundColor3=Hud.Ink,BorderSizePixel=0,Position=UDim2.fromOffset(0,Hud.Lip),Size=UDim2.fromScale(1,1),ZIndex=4,Active=false})
		round(lip)
		local face=make("Frame",frame,{Name="Face",BackgroundColor3=color,BackgroundTransparency=0,BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=5,Active=false})
		round(face)
		local ring=make("UIStroke",face,{Color=Hud.Ink,Thickness=3})
		local holder=make("Frame",face,{Name="Icon",BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,Hud.IconTop),
			Size=UDim2.fromOffset(Hud.Icon,Hud.Icon),ZIndex=6,Active=false})
		local image=Icons.image(icon)
		local picture=nil
		if image then picture=make("ImageLabel",holder,{Name="Picture",BackgroundTransparency=1,Image=image,Size=UDim2.fromScale(1,1),ZIndex=7})end
		local word=Kit.text(face,"Title",UICopy.get(caps),"text",{Name="Word",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,Hud.WordAt),
			Size=UDim2.new(1,-8,0,18),TextXAlignment=Enum.TextXAlignment.Center,TextSize=14})
		word.TextColor3=Hud.Ink;word.ZIndex=7
		frame:SetAttribute("AccessibleLabel",UICopy.get(key))
		self.faces[name]={frame=frame,face=face,ring=ring,holder=holder,picture=picture,word=word,color=color,key=key,caps=caps}
		return frame,holder
	end
	local jumpIcon,dashIcon
	self.jump,jumpIcon=pad("Jump",Hud.Jump,"dash.jump","jump","dash.pad.jump")
	self.dash,dashIcon=pad("Dash",Hud.Dash,"dash.dash","dash","dash.pad.dash")
	if not self.faces.Jump.picture then for i=0,2 do bar(jumpIcon,.5,.3+i*.2,.62,.11,if i%2==0 then -12 else 12)end end -- a spring
	if not self.faces.Dash.picture then bar(dashIcon,.58,.26,.16,.5,28);bar(dashIcon,.5,.5,.5,.14,-14);bar(dashIcon,.42,.74,.16,.5,28)end -- a bolt
	local ring=make("Frame",root,{Name="Ring",AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,ZIndex=5,Visible=false,Active=false})
	round(ring)
	self.ring,self.ringStroke=ring,make("UIStroke",ring,{Color=Color3.new(1,1,1),Thickness=5})
	self.stones=make("TextButton",root,{Name="Stones",Text="",AutoButtonColor=false,BackgroundColor3=Hud.Stones,BorderSizePixel=0,ZIndex=8,Visible=false,Selectable=false})
	round(self.stones,UDim.new(0,16));make("UIStroke",self.stones,{Color=Hud.Ink,Thickness=3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
	bar(self.stones,.5,.58,.14,.5);bar(self.stones,.4,.4,.14,.4,45);bar(self.stones,.6,.4,.14,.4,-45) -- an arrow
	self.stones:SetAttribute("AccessibleLabel",UICopy.get("dash.stones"))
	local tank=make("Frame",root,{Name="Bar",BackgroundColor3=Hud.Ink,BackgroundTransparency=.25,BorderSizePixel=0,ZIndex=4,Active=false})
	round(tank);make("UIStroke",tank,{Color=Hud.Ink,Thickness=2})
	self.bar=tank
	self.fill=make("Frame",tank,{Name="Fill",BackgroundColor3=Hud.Dash,BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=5,Active=false})
	round(self.fill)
	local strip=make("Frame",root,{Name="Strip",BackgroundColor3=Hud.Ink,BackgroundTransparency=.35,BorderSizePixel=0,ZIndex=3,Active=false})
	round(strip)
	self.strip=strip
	-- The finish: a cream cap with the flag at the strip's right end. Hoop ticks come with each race's layout (show).
	local cap=make("Frame",strip,{Name="Finish",AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,2,.5,0),Size=UDim2.fromOffset(Hud.StripH+4,Hud.StripH+4),
		BackgroundColor3=Hud.Cream,BorderSizePixel=0,ZIndex=5,Active=false})
	round(cap);make("UIStroke",cap,{Color=Hud.Ink,Thickness=2})
	local flag=Icons.image("racingFlag")
	if flag then make("ImageLabel",cap,{Name="Flag",BackgroundTransparency=1,Image=flag,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(16,16),ZIndex=6})
	else make("TextLabel",cap,{Name="Flag",BackgroundTransparency=1,Text="⚑",TextColor3=Hud.Ink,TextSize=14,Font=Enum.Font.GothamBold,AutoLocalize=false,Size=UDim2.fromScale(1,1),ZIndex=6})end
	self.ticks={}
	for index=1,6 do
		self.ticks[index]=make("Frame",strip,{Name="Hoop"..index,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(0,.5),Size=UDim2.fromOffset(2,12),
			BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=.65,BorderSizePixel=0,ZIndex=4,Visible=false,Active=false})
	end
	for seat=1,Hud.Seats do
		local dot=make("Frame",strip,{Name="Dot"..seat,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(0,.5),Size=UDim2.fromOffset(12,12),BackgroundColor3=Hud.Cream,
			BorderSizePixel=0,ZIndex=4,Visible=false,Active=false})
		round(dot);make("UIStroke",dot,{Color=Hud.Ink,Thickness=2})
		self.dots[seat]=dot
	end
	local function label(name,role,size)
		local text=Kit.text(root,role,"","text",{Name=name,TextXAlignment=Enum.TextXAlignment.Center,TextSize=size,TextStrokeTransparency=.2,TextStrokeColor3=Hud.Ink})
		text.TextColor3=Color3.new(1,1,1);text.ZIndex=6
		return text
	end
	self.place=label("Place","Title",15)
	self.place.BackgroundColor3=Hud.Ink;self.place.BackgroundTransparency=.35;self.place.TextStrokeTransparency=1;self.place.Visible=false
	round(self.place)
	self.digits=label("Digits","Title",72)
	self.digits.TextStrokeTransparency=1
	make("UIStroke",self.digits,{Color=Hud.Ink,Thickness=4})
	self.word=label("Word","Title",26)
	self.hint=label("Hint","Title",24)
	self.leave=Kit.closeKey(root,"Leave",44,UICopy.get("dash.leave"))
	self.leave.ZIndex=9;self.leave.Selectable=false
	self.leave.Activated:Connect(function()options.leave()end)
	self.connections={
		root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:fit()end),
		UserInputService.LastInputTypeChanged:Connect(function()self:keys()end),
	}
	gui.Parent=playerGui
	self.gui,self.root=gui,root
	return self
end
function Hud:fit()
	local size=self.root.AbsoluteSize
	if size.X<=0 or size.Y<=0 then return end
	local l=Hud.layout(size.X,size.Y)
	self.l=l
	put(self.zones.dash,l.zoneDash);put(self.zones.jump,l.zoneJump)
	put(self.jump,l.jump);put(self.dash,l.dash);put(self.stones,l.stones);put(self.bar,l.bar);put(self.strip,l.strip)
	put(self.place,l.place);put(self.digits,l.digits);put(self.word,l.word);put(self.hint,l.hint);put(self.leave,l.leave)
	self.ring.Position=UDim2.fromOffset(l.jump.x+l.pad/2,l.jump.y+l.pad/2)
	self.shown.ring=nil
	self:placeCaps()
end
-- The key caps, in pad space, from Hud.capBox (after a resize and after a new cap).
function Hud:placeCaps()
	local l=self.l
	if not l then return end
	for name,face in pairs(self.faces)do
		local cap=face.cap
		if cap then
			local key=string.lower(name)
			local b=Hud.capBox(l,key,cap.Size.X.Offset)
			cap.AnchorPoint=Vector2.zero;cap.Position=UDim2.fromOffset(b.x-l[key].x,b.y-l[key].y)
		end
	end
end
-- Pure: the key cap's word for each pad on this input ("" on touch: no cap).
function Hud.capWords(touch,gamepad)
	if touch then return "",""end
	if gamepad then return "A","RT"end
	return "Space","Shift"
end
-- Key caps on the pads (Kit.glyph, 20 tall with an 11 pt word, placed by Hud.capBox), and the touch zones only for a touch screen.
function Hud:keys()
	local last=UserInputService:GetLastInputType()
	local touch=last==Enum.UserInputType.Touch or(UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.GamepadEnabled)
	local jump,dash=Hud.capWords(touch,string.sub(last.Name,1,7)=="Gamepad")
	for name,word in pairs({Jump=jump,Dash=dash})do
		local face=self.faces[name]
		if face.capWord~=word then
			face.capWord=word
			if face.cap then face.cap:Destroy();face.cap=nil end
			if word~=""then
				local Kit=require(script.Parent.DeckKit)
				local cap=Kit.glyph(face.frame,word,false,Hud.Cap)
				cap.Name="KeyCap";cap.ZIndex=8
				local word=cap:FindFirstChildWhichIsA("TextLabel")
				if word and word.TextSize<Hud.CapText then word.TextSize=Hud.CapText end
				for _,child in ipairs(cap:GetDescendants())do if child:IsA("GuiObject")then child.ZIndex=9 end end
				face.cap=cap
			end
		end
	end
	self:placeCaps()
	local zones=self.racing==true and UserInputService.TouchEnabled
	self.zones.dash.Visible,self.zones.jump.Visible=zones,zones
end
-- The face of a pad down in its lip (pressed, or Dash held) or up. Reduced Motion: 10% darker in place of the drop.
function Hud:sink(name,down)
	local face=self.faces[name]
	if not face or face.down==down then return end
	face.down=down
	local reduced=self.options.reduced and self.options.reduced()==true
	local color=if face.out then Hud.Puff else face.color
	if reduced then
		face.face.Position=UDim2.fromOffset(0,0)
		face.face.BackgroundColor3=if down then color:Lerp(Color3.new(0,0,0),.1)else color
		return
	end
	face.face.BackgroundColor3=color
	local goal={Position=UDim2.fromOffset(0,if down then Hud.Drop else 0)}
	pcall(function()TweenService:Create(face.face,TweenInfo.new(if down then .06 else .1,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),goal):Play()end)
end
-- A press of a pad (from DashInput through DashClient): down at once, back up after the release time.
function Hud:press(kind)
	local name=if kind=="jump"then "Jump"elseif kind=="dashDown"then "Dash"else nil
	if not name then return end
	self:sink(name,true)
	if name=="Jump"then
		local token={};self.jumpPress=token
		task.delay(.12,function()if self.jumpPress==token then self:sink("Jump",false)end end)
	end
end
-- A Perfect jump: the Jump pad flashes white 30% for 0.12 s. Reduced Motion: none.
function Hud:flash()
	if self.options.reduced and self.options.reduced()==true then return end
	local face=self.faces.Jump
	local glow=face.glow
	if not glow then
		glow=make("Frame",face.face,{Name="Flash",BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=8,Active=false})
		round(glow)
		face.glow=glow
	end
	glow.BackgroundTransparency=.7
	pcall(function()TweenService:Create(glow,TweenInfo.new(.12),{BackgroundTransparency=1}):Play()end)
end
-- first: the player's first race (a larger ring). plan: the race's public plan (the hoop ticks on the strip).
function Hud:show(first,plan)
	self.first=first==true
	self.racing=true
	table.clear(self.shown)
	self.ringStroke.Thickness=if self.first then 8 else 5
	local Course=require(game:GetService("ReplicatedStorage").Shared.DashCourse)
	local hoops=if type(plan)=="table"then Course.hurdles(plan.layout)else {}
	for index,tick in ipairs(self.ticks)do
		local cs=hoops[index]
		tick.Visible=cs~=nil
		if cs then tick.Position=UDim2.fromScale(cs/Course.Length,.5)end
	end
	for _,face in pairs(self.faces)do face.down=nil;self:sink(face.frame.Name,false)end
	for _,dot in ipairs(self.dots)do dot.Visible=false end
	self.ring.Visible,self.stones.Visible=false,false
	self.place.Text,self.digits.Text,self.word.Text,self.hint.Text="","","",""
	self.place.Visible=false
	self.jump.Visible,self.dash.Visible,self.bar.Visible,self.strip.Visible,self.leave.Visible=true,true,true,true,true
	self.gui.Enabled=true
	self:fit();self:keys()
end
-- This pet is home: the pads go, the strip stays. The Leave key stays until the result (`final`).
function Hud:rest(final)
	self.racing=false
	self.jump.Visible,self.dash.Visible,self.bar.Visible,self.leave.Visible=false,false,false,final~=true
	self.ring.Visible,self.stones.Visible=false,false
	self:setHint(nil)
	self:keys()
end
function Hud:hide()
	self.racing=false
	self.zones.dash.Visible,self.zones.jump.Visible=false,false
	self.gui.Enabled=false
end

-- Setters: cheap to call every frame --------------------------------------------------------------------------
function Hud:setDigits(text)
	if self.shown.digits==text then return end
	self.shown.digits=text
	self.digits.Text=text or""
end
function Hud:setRing(ticks)
	local scale=Hud.ring(ticks,self.first)
	local px=if scale and self.l then math.floor(self.l.pad*scale)else 0
	if self.shown.ring==px then return end
	self.shown.ring=px
	self.ring.Visible=px>0
	if px>0 then self.ring.Size=UDim2.fromOffset(px,px)end
end
-- held: Dash is down (the face stays down, its ring white). puff: out of puff (face and bar grey, icon at half, "Phew!").
function Hud:setBar(share,puff,held)
	local px=math.floor(math.clamp(share,0,1)*100)
	if self.shown.bar~=px then self.shown.bar=px;self.fill.Size=UDim2.fromScale(px/100,1)end
	if self.shown.puff~=puff then
		self.shown.puff=puff;self.fill.BackgroundColor3=if puff then Hud.Puff else Hud.Dash
		local face=self.faces and self.faces.Dash
		if face then
			face.out=puff==true
			face.face.BackgroundColor3=if puff then Hud.Puff else face.color
			face.holder.Visible=true
			if face.picture then face.picture.ImageTransparency=if puff then .5 else 0 end
			for _,child in ipairs(face.holder:GetChildren())do if child:IsA("Frame")then child.BackgroundTransparency=if puff then .5 else 0 end end
			face.word.Text=UICopy.get(if puff then "dash.pad.puff"else face.caps)
			face.down=nil;self:sink("Dash",self.shown.held==true)
		end
	end
	held=held==true and not puff
	if self.shown.held~=held then
		self.shown.held=held
		local face=self.faces and self.faces.Dash
		if face then face.ring.Color=if held then Color3.new(1,1,1)else Hud.Ink;self:sink("Dash",held)end
	end
end
function Hud:setPlace(place)
	if self.shown.place==place then return end
	self.shown.place=place
	self.place.Text=if place then Hud.ordinal(place)else""
	self.place.Visible=place~=nil
end
function Hud:setDot(seat,share,mine)
	local dot=self.dots[seat]
	if not dot then return end
	local px=math.floor(math.clamp(share,0,1)*250)
	if self.shown[seat]==px then return end
	if self.shown[seat]==nil then
		dot.Visible=true
		dot.BackgroundColor3=if mine then Hud.Dash else Hud.Cream
		dot.ZIndex=if mine then 6 else 4
		dot.Size=if mine then UDim2.fromOffset(18,18)else UDim2.fromOffset(12,12)
	end
	self.shown[seat]=px
	dot.Position=UDim2.fromScale(px/250,.5)
end
function Hud:setStones(visible)
	if self.stones.Visible~=visible then self.stones.Visible=visible end
end
-- The first race's help line (DashHints); nil = none.
function Hud:setHint(text)
	if self.shown.hint==text then return end
	self.shown.hint=text
	self.hint.Text=text or""
end
function Hud:say(text)
	self.word.Text=text
	self.wordLeft=Hud.WordSeconds
end
function Hud:step(dt)
	local left=self.wordLeft
	if not left then return end
	left-=dt
	self.wordLeft=if left>0 then left else nil
	if left<=0 then self.word.Text=""end
end
function Hud:destroy()
	for _,connection in ipairs(self.connections)do connection:Disconnect()end
	self.gui:Destroy()
end
return Hud
