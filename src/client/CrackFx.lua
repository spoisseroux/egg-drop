-- The First Hatch (Onboard "crack"): what the player sees while cracking the Bear's egg, drawn in code (no assets).
-- Fable FABLE-REVIEW-FIRST-HATCH.md MUST 1 and 3: the "Tap the egg!" pill (gold, ink text, centred on the card and
-- overlapping its bottom edge, pulsing), a ghost hand that taps the egg after 0.6 s of waiting (first stop only), and
-- per beat: a cream ring and flakes at the tap point, then a dark crack that grows across the egg (a fork and a cream
-- glow line on the second). The cracks stay until the pop. HatchCinematic owns the clock; this only draws.
local Fx={};Fx.__index=Fx
Fx.Gold=Color3.fromHex("#FFC14D");Fx.Ink=Color3.fromHex("#0E0F12");Fx.Cream=Color3.fromHex("#FFF4DC")
Fx.CrackInk=Color3.fromHex("#5A3A22")
Fx.Pill=table.freeze({h=56,hPhone=40,text=22,textPhone=17,pad=26,pulse=.06,period=1.1})
Fx.Ring=table.freeze({from=24,to=64,time=.2,thick=3})
Fx.Flakes=table.freeze({counts={6,10,8},size={4,8},time=.5,speed={90,170},gravity=320})
Fx.Crack=table.freeze({grow=.09,width=3,glow=2})
Fx.HandAfter=.6;Fx.HandPeriod=.8
Fx.Z=400
-- The crack per beat (1 crack one, 2 crack two, 3 the creak): polylines in egg heights from the egg's centre
-- (x right, y down); the egg is about .75 egg heights wide. Beat 2's second line is the fork; glow marks a cream line.
Fx.Shapes={
	{{{-.34,-.02},{-.19,.06},{-.06,-.04},{.07,.05}}},
	{{{.07,.05},{.2,-.05},{.33,.03}},{{-.06,-.04},{-.01,-.16},{.07,-.24}},glow=true},
	{{{-.19,.06},{-.22,.2},{-.12,.29}},{{.2,-.05},{.25,-.19}}},
}

local function node(class,parent,name,props)
	local n=Instance.new(class);n.Name=name
	for k,v in pairs(props or {})do n[k]=v end
	n.Parent=parent;return n
end
local function round(parent)node("UICorner",parent,"Round",{CornerRadius=UDim.new(.5,0)})end

-- Pure: the wording for the last input kind ("Touch", "Gamepad", else mouse and keyboard).
function Fx.copyKey(kind)
	if kind=="Touch"then return "onboarding.crack.tap"end
	if kind=="Gamepad"then return "onboarding.crack.pad"end
	return "onboarding.crack.click"
end
-- Pure: a polyline's points in pixels, from the egg centre and height.
function Fx.points(line,center,eggH)
	local out={}
	for i,p in ipairs(line)do out[i]=center+Vector2.new(p[1]*eggH,p[2]*eggH)end
	return out
end

-- prompt: the TextLabel HatchCinematic made (it keeps its name and its Visible rule); copy: UICopy.get.
function Fx.new(prompt,copy)
	local self=setmetatable({prompt=prompt,copy=copy,items={},cracks={},drawn=0,age=0},Fx)
	prompt.AnchorPoint=Vector2.new(.5,.5);prompt.AutomaticSize=Enum.AutomaticSize.X;prompt.TextWrapped=false
	prompt.BackgroundTransparency=0;prompt.BackgroundColor3=Fx.Gold;prompt.TextColor3=Fx.Ink
	for _,child in ipairs(prompt:GetChildren())do if child:IsA("UICorner")or child:IsA("UIPadding")then child:Destroy()end end
	round(prompt)
	node("UIPadding",prompt,"Pad",{PaddingLeft=UDim.new(0,Fx.Pill.pad),PaddingRight=UDim.new(0,Fx.Pill.pad)})
	node("UIStroke",prompt,"Edge",{Color=Fx.Ink,Thickness=2,Transparency=.6,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
	self.pulse=node("UIScale",prompt,"Pulse",{Scale=1})
	-- the ghost hand (thumb, palm, two fingertips), passive
	local hand=node("Frame",nil,"CrackGhostHand",{Size=UDim2.fromOffset(36,42),AnchorPoint=Vector2.new(.2,.05),
		BackgroundTransparency=1,Active=false,Visible=false,ZIndex=prompt.ZIndex})
	for i,p in ipairs({{9,15,23,23,-10},{2,11,12,22,-28},{13,2,8,23,0},{22,5,8,21,8}})do
		local part=node("Frame",hand,"Hand"..i,{Position=UDim2.fromOffset(p[1],p[2]),Size=UDim2.fromOffset(p[3],p[4]),Rotation=p[5],
			BackgroundColor3=Fx.Cream,BackgroundTransparency=.05,BorderSizePixel=0,ZIndex=prompt.ZIndex})
		round(part)
		node("UIStroke",part,"Edge",{Color=Fx.Ink,Thickness=2,Transparency=.2}) -- it shows on the cream egg
	end
	self.hand=hand
	self.layer=node("Frame",nil,"CrackFxLayer",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Active=false,ZIndex=prompt.ZIndex-1})
	return self
end
function Fx:local_(layer,abs)return abs-layer.AbsolutePosition end
-- Follow the layer the prompt is in (the full-screen stage, or the cinematic's frame) and the spot.
function Fx:place(layer,spot,phone)
	if not layer then return end
	-- a new layer (the stage took over): drawn cracks would keep the old layer's offsets, so draw them again there
	if self.layer.Parent~=layer then self:clearCracks();self.drawn=0;self.layer.Parent=layer;self.hand.Parent=layer end
	if self.prompt.Parent~=layer then self.prompt.Parent=layer end
	-- over everything on that layer (the RevealStage sits at 71, the cinematic's skip button at 60)
	local z=Fx.Z;self.prompt.ZIndex=z;self.layer.ZIndex=z-1;self.hand.ZIndex=z+1
	for _,part in ipairs(self.hand:GetChildren())do if part:IsA("GuiObject")then part.ZIndex=z+1 end end
	local h=if phone then Fx.Pill.hPhone else Fx.Pill.h
	self.prompt.Size=UDim2.fromOffset(0,h);self.prompt.TextSize=if phone then Fx.Pill.textPhone else Fx.Pill.text
	if spot and spot.pill then
		local at=self:local_(layer,spot.pill);self.prompt.Position=UDim2.fromOffset(at.X,at.Y)
	else self.prompt.Position=UDim2.new(.5,0,1,-28-h/2)end
	self.spot=spot;self.phone=phone
end
function Fx:setText(kind)
	local ok,text=pcall(self.copy,Fx.copyKey(kind))
	if ok and type(text)=="string"then self.prompt.Text=text end
end
function Fx:center(layer)
	if self.spot and self.spot.egg then return self.spot.egg,self.spot.eggH or 120 end
	return layer.AbsolutePosition+layer.AbsoluteSize/2,math.min(layer.AbsoluteSize.X,layer.AbsoluteSize.Y)*.3
end
-- A beat released (index 1..3). at: the tap in absolute pixels, or nil (a key, the pad, or released by itself).
function Fx:beat(index,at,reduced)
	local layer=self.layer.Parent;if not layer or index<=self.drawn then return end
	self.drawn=index
	local center,eggH=self:center(layer)
	if at then self:ring(self:local_(layer,at));self:flakes(self:local_(layer,at),Fx.Flakes.counts[index]or 6,reduced)end
	local shape=Fx.Shapes[index];if not shape then return end
	for li,line in ipairs(shape)do
		local pts=Fx.points(line,self:local_(layer,center),eggH)
		for i=1,#pts-1 do
			self:segment(pts[i],pts[i+1],Fx.CrackInk,Fx.Crack.width,(li-1)*.04+(i-1)*Fx.Crack.grow/#pts)
			if shape.glow and li==1 then self:segment(pts[i]+Vector2.new(0,2),pts[i+1]+Vector2.new(0,2),Fx.Cream,Fx.Crack.glow,(i-1)*Fx.Crack.grow/#pts)end
		end
	end
end
-- A segment from a to b (layer pixels). GuiObjects turn about their centre, so the line is centred on the part grown
-- so far (it grows from a), and a short overlap hides the joints.
function Fx:segment(a,b,color,width,delay)
	local length=(b-a).Magnitude;if length<=0 then return end
	local line=node("Frame",self.layer,"Crack",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(a.X,a.Y),Size=UDim2.fromOffset(0,width),
		Rotation=math.deg(math.atan2(b.Y-a.Y,b.X-a.X)),BackgroundColor3=color,BorderSizePixel=0,ZIndex=self.layer.ZIndex,Visible=false})
	round(line)
	table.insert(self.cracks,{node=line,a=a,dir=(b-a)/length,length=length+width*.5,width=width,age=-(delay or 0)})
end
function Fx:ring(at)
	local ring=node("Frame",self.layer,"TapRing",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(at.X,at.Y),
		Size=UDim2.fromOffset(Fx.Ring.from,Fx.Ring.from),BackgroundTransparency=1,ZIndex=self.layer.ZIndex})
	round(ring)
	local stroke=node("UIStroke",ring,"Line",{Color=Fx.Cream,Thickness=Fx.Ring.thick})
	table.insert(self.items,{kind="ring",node=ring,stroke=stroke,age=0})
end
function Fx:flakes(at,count,reduced)
	if reduced then return end
	for i=1,count do
		local angle=(i/count)*math.pi*2+math.random()*.5
		local speed=Fx.Flakes.speed[1]+math.random()*(Fx.Flakes.speed[2]-Fx.Flakes.speed[1])
		local size=Fx.Flakes.size[1]+math.random()*(Fx.Flakes.size[2]-Fx.Flakes.size[1])
		local flake=node("Frame",self.layer,"Flake",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(at.X,at.Y),
			Size=UDim2.fromOffset(size,size),Rotation=math.random()*90,BackgroundColor3=Fx.Cream,BorderSizePixel=0,ZIndex=self.layer.ZIndex})
		table.insert(self.items,{kind="flake",node=flake,at=at,v=Vector2.new(math.cos(angle),math.sin(angle)-.6)*speed,age=0})
	end
end
-- Every frame. waiting: the clock is held for a tap; waited: how long; taps: accepted taps so far.
function Fx:step(dt,waiting,waited,taps,reduced)
	self.age+=dt
	self.prompt.Visible=waiting
	self.pulse.Scale=if waiting and not reduced then 1+Fx.Pill.pulse*(.5-.5*math.cos(self.age/Fx.Pill.period*math.pi*2))else 1
	local layer=self.layer.Parent
	local showHand=waiting and taps==0 and waited>=Fx.HandAfter and layer~=nil and not reduced
	self.hand.Visible=showHand
	if showHand then
		local center,eggH=self:center(layer)
		local at=self:local_(layer,center)+Vector2.new(eggH*.12,eggH*.05)
		local press=math.max(0,math.sin((waited-Fx.HandAfter)/Fx.HandPeriod*math.pi*2))
		self.hand.Position=UDim2.fromOffset(at.X+10*(1-press),at.Y+10*(1-press))
	end
	for _,c in ipairs(self.cracks)do
		c.age+=dt
		local u=math.clamp(c.age/Fx.Crack.grow,0,1)
		local grown=c.length*u;local mid=c.a+c.dir*(grown/2)
		c.node.Size=UDim2.fromOffset(grown,c.width);c.node.Position=UDim2.fromOffset(mid.X,mid.Y);c.node.Visible=u>0
	end
	for index=#self.items,1,-1 do
		local item=self.items[index];item.age+=dt
		if item.kind=="ring"then
			local u=item.age/Fx.Ring.time
			if u>=1 then item.node:Destroy();table.remove(self.items,index)
			else
				local size=Fx.Ring.from+(Fx.Ring.to-Fx.Ring.from)*u
				item.node.Size=UDim2.fromOffset(size,size);item.stroke.Transparency=u
			end
		else
			local u=item.age/Fx.Flakes.time
			if u>=1 then item.node:Destroy();table.remove(self.items,index)
			else
				local t=item.age
				local p=item.at+item.v*t+Vector2.new(0,.5*Fx.Flakes.gravity*t*t)
				item.node.Position=UDim2.fromOffset(p.X,p.Y);item.node.BackgroundTransparency=u
			end
		end
	end
end
function Fx:clearCracks()
	for _,c in ipairs(self.cracks)do c.node:Destroy()end
	table.clear(self.cracks)
end
-- A new ritual (or none): nothing drawn, the pill hidden.
function Fx:reset()
	self:clearCracks()
	for _,item in ipairs(self.items)do item.node:Destroy()end
	table.clear(self.items)
	self.drawn=0;self.prompt.Visible=false;self.hand.Visible=false;self.pulse.Scale=1
end
function Fx:destroy()
	self:reset()
	self.layer:Destroy();self.hand:Destroy();self.prompt:Destroy()
end
return Fx
