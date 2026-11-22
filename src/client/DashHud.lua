-- Garden Dash race screen (V3-DASH-BUILD-PLAN-2026-11-22, slice S7): the two pads with the closing ring, the dash bar,
-- place, the progress strip, the countdown, the stones key and the Leave key. Made the first time a race is held
-- and hidden after. Placeholder pictures (spring, bolt) from frames until the art lands. A frame writes a property
-- only when the whole pixel (or word) it shows has changed.
local UserInputService=game:GetService("UserInputService")
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
local function box(x,y,w,h)return{x=math.floor(x),y=math.floor(y),w=math.floor(w),h=math.floor(h)}end
-- Pure: every piece for a safe area of W x H px.
function Hud.layout(W,H)
	local m=Hud.Margin
	local pad=if H<=430 or W<=700 then Hud.Pad else Hud.PadLarge
	local jump=box(W-m-pad,H-m-pad,pad,pad)
	local dash=box(m,H-m-pad,pad,pad)
	local side=m+104+8
	local strip=box(0,14,math.clamp(W-side*2,80,380),18)
	strip.x=math.floor((W-strip.w)/2)
	local digitsH=if H<=430 then 84 else 110
	return{pad=pad,jump=jump,dash=dash,
		zoneDash=box(0,0,W/2,H),zoneJump=box(W/2,0,W-math.floor(W/2),H),
		stones=box(jump.x+(pad-72)/2,jump.y-12-56,72,56),
		bar=box(dash.x,dash.y-12-16,pad,16),
		strip=strip,place=box(m,4,104,40),leave=box(W-m-44,4,44,44),
		digits=box((W-200)/2,math.max(52,(H-digitsH)/2-16),200,digitsH),
		word=box((W-240)/2,math.max(52+digitsH,H/2+digitsH/2-12),240,34),
		hint=box((W-280)/2,math.max(52+digitsH,H/2+digitsH/2-12)+36,280,34)}
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
	local function pad(name,color,key)
		local frame=make("Frame",root,{Name=name,BackgroundColor3=color,BackgroundTransparency=.08,BorderSizePixel=0,ZIndex=4,Active=false})
		round(frame)
		make("UIStroke",frame,{Color=Hud.Ink,Thickness=3})
		local hint=Kit.text(frame,"Strong","","text",{Name="Key",Position=UDim2.new(0,-20,1,-22),Size=UDim2.new(1,40,0,18),TextXAlignment=Enum.TextXAlignment.Center,TextSize=13,
			TextStrokeTransparency=.35,TextStrokeColor3=Hud.Ink})
		hint.TextColor3=Color3.new(1,1,1);hint.ZIndex=7;Kit.fixedText(hint)
		frame:SetAttribute("AccessibleLabel",UICopy.get(key))
		return frame,hint
	end
	self.jump,self.jumpKey=pad("Jump",Hud.Jump,"dash.jump")
	self.dash,self.dashKey=pad("Dash",Hud.Dash,"dash.dash")
	for i=0,2 do bar(self.jump,.5,.34+i*.13,.36,.07,if i%2==0 then -12 else 12)end -- a spring
	bar(self.dash,.55,.36,.12,.34,28);bar(self.dash,.5,.5,.34,.1,-14);bar(self.dash,.45,.64,.12,.34,28) -- a bolt
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
	self.place=label("Place","Title",28);self.place.TextXAlignment=Enum.TextXAlignment.Left
	self.digits=label("Digits","Title",72)
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
end
-- Key names under the pads, and the touch zones only for a touch screen.
function Hud:keys()
	local last=UserInputService:GetLastInputType()
	local touch=last==Enum.UserInputType.Touch or(UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.GamepadEnabled)
	local pad=string.sub(last.Name,1,7)=="Gamepad"
	self.jumpKey.Text=if touch then ""elseif pad then "A"else "Space"
	self.dashKey.Text=if touch then ""elseif pad then "RT"else "Shift"
	local zones=self.racing==true and UserInputService.TouchEnabled
	self.zones.dash.Visible,self.zones.jump.Visible=zones,zones
end
-- first: the player's first race (a larger ring).
function Hud:show(first)
	self.first=first==true
	self.racing=true
	table.clear(self.shown)
	self.ringStroke.Thickness=if self.first then 8 else 5
	for _,dot in ipairs(self.dots)do dot.Visible=false end
	self.ring.Visible,self.stones.Visible=false,false
	self.place.Text,self.digits.Text,self.word.Text,self.hint.Text="","","",""
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
function Hud:setBar(share,puff)
	local px=math.floor(math.clamp(share,0,1)*100)
	if self.shown.bar~=px then self.shown.bar=px;self.fill.Size=UDim2.fromScale(px/100,1)end
	if self.shown.puff~=puff then self.shown.puff=puff;self.fill.BackgroundColor3=if puff then Hud.Puff else Hud.Dash end
end
function Hud:setPlace(place)
	if self.shown.place==place then return end
	self.shown.place=place
	self.place.Text=if place then Hud.ordinal(place)else""
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
		dot.Size=if mine then UDim2.fromOffset(16,16)else UDim2.fromOffset(12,12)
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
