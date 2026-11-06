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
	Art.fitText(label,13,9,0,false)
	local rolling=balls[8]:Clone();rolling.Name="RollingBall";rolling.Parent=host;rolling.ZIndex=host.ZIndex+3;rolling.Visible=false
	local self=setmetatable({host=host,channel=channel,balls=balls,label=label,rolling=rolling,reduce=reduceEffects or function()return false end,pulses=0},Dispenser)
	host:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:cancel();self:layout()end)
	return self
end
function Dispenser:cancel()
	if self.motion then self.motion:Cancel();self.motion=nil end
	self.rolling.Visible=false
end
function Dispenser:layout()
	local h=self.host.AbsoluteSize.Y
	local diameter=math.max(5,math.min(18,math.floor((self.host.AbsoluteSize.X-16)/8)))
	local cy=if h<42 then 0 else 3
	self.channel.Position,self.channel.Size=UDim2.fromOffset(0,cy),UDim2.new(1,-4,0,diameter+8)
	self.label.Position,self.label.Size=UDim2.fromOffset(0,cy+diameter+8),UDim2.new(1,-2,0,math.max(12,h-diameter-cy-8))
	for i,ball in ipairs(self.balls)do
		ball.Position=UDim2.fromOffset(6+(i-1)*(diameter+1),4)
		ball.Size=UDim2.fromOffset(diameter,diameter)
		ball.Visible=i<=math.min(8,self.remaining or 0)
	end
end
function Dispenser:update(reset,drops,budget,active)
	budget=budget or 24;drops=drops or 0
	local accepted=self.reset==reset and self.drops~=nil and drops>self.drops
	if self.reset~=reset or (self.drops and drops<self.drops)then self:cancel()end
	local previousVisible=math.min(8,self.remaining or 0)
	self.reset,self.drops,self.remaining=reset,drops,math.max(0,budget-drops)
	self.host.Visible=active==true
	self.label.Text=string.format("Drops left %d/%d",self.remaining,budget)
	self:layout()
	if not active then self:cancel();return end
	if accepted then
		self.pulses+=1;self.host:SetAttribute("AcceptedPulses",self.pulses)
		self:cancel()
		if self.reduce()then return end
		local ball=self.rolling;ball.Size=self.balls[1].Size;local slot=self.balls[math.max(1,previousVisible)]
		ball.Position=self.channel.Position+slot.Position
		ball.Rotation,ball.BackgroundTransparency,ball.Visible=0,0,true
		self.motion=TweenService:Create(ball,TweenInfo.new(.44,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{
			Position=ball.Position+UDim2.fromOffset(25,math.max(30,self.host.AbsoluteSize.Y)),Rotation=240,BackgroundTransparency=1})
		self.motion:Play()
	end
end
return Dispenser
