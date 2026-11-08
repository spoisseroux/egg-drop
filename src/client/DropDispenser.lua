local TweenService=game:GetService("TweenService")
local Art=require(script.Parent.DeckArt)
local Dispenser={};Dispenser.__index=Dispenser
function Dispenser.new(parent,reduceEffects)
	local host=Art.frame(parent,"BallDispenser",Art.Ink,UDim2.fromScale(0,0),UDim2.fromScale(1,1),parent.ZIndex+2)
	host.BackgroundTransparency=1;host.ClipsDescendants=true
	local channel=Art.frame(host,"Channel",Art.Ink,UDim2.fromOffset(0,0),UDim2.new(1,-4,0,25))
	Art.corner(channel,12);Art.stroke(channel,Art.Line,.2,1)
	local balls={}
	for i=1,8 do
		local ball=Art.frame(channel,"Ball"..i,Art.Leaf,UDim2.fromOffset(0,4),UDim2.fromOffset(16,16),channel.ZIndex+1)
		Art.corner(ball,20);Art.shade(ball,1,.65)
		Art.corner(Art.frame(ball,"Glint",Art.Silver,UDim2.fromOffset(4,3),UDim2.fromOffset(5,2),ball.ZIndex+1),2)
		balls[i]=ball
	end
	local label=Art.text(host,"Remaining","Drops left 24/24",UDim2.fromOffset(1,26),UDim2.new(1,-2,0,18),Art.Silver,12)
	Art.type(label,"Counter")
	local rolling=balls[8]:Clone();rolling.Name="RollingBall";rolling.Parent=host;rolling.ZIndex=host.ZIndex+3;rolling.Visible=false
 local nozzle=Art.frame(host,"NozzleCompression",Art.Silver,UDim2.fromScale(.5,.5),UDim2.new(1,-4,1,-4),host.ZIndex)
 nozzle.AnchorPoint=Vector2.new(.5,.5);nozzle.BackgroundTransparency=1;nozzle.Active=false;nozzle.Selectable=false;nozzle.Visible=false;Art.corner(nozzle,8)
 local nozzleStroke=Art.stroke(nozzle,Art.Silver,1,1)
	local self=setmetatable({nozzle=nozzle,nozzleStroke=nozzleStroke,host=host,channel=channel,balls=balls,label=label,rolling=rolling,reduce=reduceEffects or function()return false end,pulses=0},Dispenser)
	host:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:cancel();self:layout()end)
	return self
end
function Dispenser:cancel()
	if self.motion then self.motion:Cancel();self.motion=nil end
	self.rolling.Visible=false
 if self.nozzleMotion then self.nozzleMotion:Cancel();self.nozzleMotion=nil end
 if self.nozzleFade then self.nozzleFade:Cancel();self.nozzleFade=nil end
 self.nozzle.Visible=false
end
-- Called only by root layout/preference changes, never a HUD-frame measurement.
function Dispenser:preferredHeight(width,available)
	local size=if self.roomy then 20 elseif available<50 then 12 else 14
	local text=string.format("Drops left %d/%d",self.budget or 24,self.budget or 24)
	local service=game:GetService("TextService")
	if service:GetTextSize(text,size,Art.Font.Counter,Vector2.new(10000,10000)).X+8>width then text=string.format("%d/%d",self.budget or 24,self.budget or 24)end
	local needed=math.ceil(service:GetTextSize(text,size,Art.Font.Counter,Vector2.new(math.max(1,width-8),10000)).Y)+4
	local diameter=math.max(1,math.min(18,math.floor((math.max(1,width-8)-19)/8)))
	local full=needed+diameter+8+6
	return if full<=available then full else math.min(available,needed+4)
end

function Dispenser:layout()
	local w,h=self.host.AbsoluteSize.X,self.host.AbsoluteSize.Y
	local key=table.concat({w,h,tostring(self.roomy),self.remaining or 0,self.budget or 24,game:GetService("GuiService").PreferredTextSize.Name},"|")
	if self.layoutKey==key then return end
	self.layoutKey=key
	Art.type(self.label,"Counter",h<50)
 self.label.TextSize=if self.roomy then 20 elseif h<50 then 12 else 14
	local inset=self.label:FindFirstChildOfClass("UIPadding");if inset then inset:Destroy()end
	self.label.Text=string.format("Drops left %d/%d",self.remaining or 0,self.budget or 24)
	if Art.textWidth(self.label)>w-8 then self.label.Text=string.format("%d/%d",self.remaining or 0,self.budget or 24)end
	local needed=Art.textHeight(self.label,w-8,12)
	local channelW=math.max(1,w-8)
	local diameter=math.max(1,math.min(18,math.floor((channelW-19)/8)))
	local channelH=diameter+8
	local showChannel=needed+channelH+6<=h
	self.channel.Visible=showChannel
	local packH=channelH+2+needed
	local cy=if showChannel then math.max(2,math.floor((h-packH)/2))else 0
	self.channel.Position,self.channel.Size=UDim2.fromOffset(4,cy),UDim2.fromOffset(channelW,channelH)
	local labelY=if showChannel then cy+channelH+2 else math.max(0,math.floor((h-needed)/2))
	self.label.Position,self.label.Size=UDim2.fromOffset(4,labelY),UDim2.fromOffset(math.max(1,w-8),if showChannel then needed else math.max(1,h-labelY))
	-- Center the complete eight-slot capacity, rather than the shrinking remainder.
	local trainW=diameter*8+7
	local start=(channelW-trainW)/2
	for i,ball in ipairs(self.balls)do
		ball.Position=UDim2.fromOffset(start+(i-1)*(diameter+1),4)
		ball.Size=UDim2.fromOffset(diameter,diameter)
		ball.Visible=i<=math.min(8,self.remaining or 0)
	end
end
function Dispenser:update(reset,drops,budget,active,animate)
	budget=budget or 24;drops=drops or 0
	local accepted=self.reset==reset and self.drops~=nil and drops==self.drops+1
	if self.reset~=reset or (self.drops and drops<self.drops)then self:cancel()end
	local previousVisible=math.min(8,self.remaining or 0)
	local previousSlot=self.balls[math.max(1,previousVisible)]
	local rollingOrigin=if accepted and self.channel.Visible then self.channel.Position+previousSlot.Position else nil
	self.reset,self.drops,self.remaining=reset,drops,math.max(0,budget-drops)
	self.budget=budget
	self.host.Visible=active==true
	self:layout()
	if not active or animate==false then self:cancel();return end
	if accepted then
		self.pulses+=1;self.host:SetAttribute("AcceptedPulses",self.pulses)
		self:cancel()
  self.nozzle.Visible=true;self.nozzleStroke.Transparency=.55
  self.nozzle.Size=if self.reduce()then UDim2.new(1,-4,1,-4)else UDim2.new(.96,-4,.90,-4)
  if not self.reduce()then self.nozzleMotion=TweenService:Create(self.nozzle,TweenInfo.new(.18,Enum.EasingStyle.Sine),{Size=UDim2.new(1,-4,1,-4)});self.nozzleMotion:Play()end
  self.nozzleFade=TweenService:Create(self.nozzleStroke,TweenInfo.new(.18),{Transparency=1});self.nozzleFade:Play()
		if self.reduce() or not self.channel.Visible then return end
		local ball=self.rolling;ball.Size=self.balls[1].Size;local slot=self.balls[math.max(1,previousVisible)]
		ball.Position=rollingOrigin or self.channel.Position+slot.Position
		ball.Rotation,ball.BackgroundTransparency,ball.Visible=0,0,true
		self.motion=TweenService:Create(ball,TweenInfo.new(.44,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{
			Position=ball.Position+UDim2.fromOffset(25,math.max(30,self.host.AbsoluteSize.Y)),Rotation=240,BackgroundTransparency=1})
		self.motion:Play()
	end
end
return Dispenser
