-- Four reusable, passive tray bursts. No event creates Instances or tweens.
local Effects={};Effects.__index=Effects
local Pico8=require(game:GetService("ReplicatedStorage").Shared.Pico8)
Effects.PopDuration=.7
local function node(parent,name)
	local frame=Instance.new("Frame");frame.Name=name;frame.BorderSizePixel=0;frame.BackgroundTransparency=1
	frame.Active,frame.Selectable=false,false;frame.AnchorPoint=Vector2.new(.5,.5);frame.ZIndex=5;frame.Visible=false;frame.Parent=parent
	local round=Instance.new("UICorner");round.CornerRadius=UDim.new(.5,0);round.Parent=frame
	return frame
end
local function put(self,object,key,value)
	if object[key]~=value then object[key]=value;self.stats.writes+=1 end
end
function Effects.new(parent)
	local root=Instance.new("Frame");root.Name="FieldFeedback";root.BackgroundTransparency=1;root.Size=UDim2.fromScale(1,1)
	root.Active,root.Selectable,root.ClipsDescendants=false,false,true;root.ZIndex=5;root.Parent=parent
	local self=setmetatable({root=root,slots={},visible=false,reduced=false,serial=nil,stats={accepted=0,rejected=0,evicted=0,writes=0,active=0}},Effects)
	for i=1,4 do
		local ring=node(root,"Halo"..i);local stroke=Instance.new("UIStroke");stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Thickness=1.5;stroke.Parent=ring
		local slot={ring=ring,stroke=stroke,fragments={},active=false,priority=0}
		for j=1,6 do slot.fragments[j]=node(root,"Fragment"..i.."_"..j)end
		self.slots[i]=slot
	end
 local caption=Instance.new("TextLabel");caption.Name="ChainFeedback";caption.BackgroundTransparency=1;caption.BorderSizePixel=0
 caption.Active,caption.Selectable=false,false;caption.Visible=false;caption.ZIndex=5;caption.Font=Enum.Font.GothamBold;caption.TextSize=14
 caption.TextWrapped=true;caption.TextColor3=Color3.fromHex("#F4F8E9");caption.TextStrokeColor3=Color3.fromHex("#142D20");caption.TextStrokeTransparency=.25;caption.Parent=root
 self.caption=caption
 -- Four pooled "+N" score pops, oldest reused first. Colours come from the caller.
 self.pops={}
 for i=1,4 do
  local pop=Instance.new("TextLabel");pop.Name="ScorePop"..i;pop.BackgroundTransparency=1;pop.BorderSizePixel=0;pop.AnchorPoint=Vector2.new(.5,.5)
  pop.Active,pop.Selectable=false,false;pop.Visible=false;pop.ZIndex=6;pop.Font=Enum.Font.GothamBlack;pop.TextSize=16;pop.Size=UDim2.fromOffset(84,26)
  pop.TextStrokeColor3=Pico8[0];pop.TextStrokeTransparency=.1;pop.Parent=root
  self.pops[i]={label=pop,active=false,start=0}
 end
	self.stats.instances=#root:GetDescendants()+1
	return self
end
function Effects:observeDrop(serial,count)
 local accepted=type(serial)=="number"and serial==self.dropSerial and type(count)=="number"and count==(self.drops or 0)+1
 self.dropSerial,self.drops=serial,count
 return accepted
end
function Effects:clear()
	for _,slot in ipairs(self.slots)do
		slot.active=false;put(self,slot.ring,"Visible",false)
		for _,fragment in ipairs(slot.fragments)do put(self,fragment,"Visible",false)end
	end
 if self.caption then put(self,self.caption,"Visible",false)end
 if self.pops then for _,pop in ipairs(self.pops)do pop.active=false;put(self,pop.label,"Visible",false)end end
 self.captionUntil=nil
	self.stats.active=0
end
function Effects:setOwner(visible,serial,reduced)
	if self.destroyed then return end
 visible=visible==true and type(serial)=="number"
 local lost=self.visible and(not visible or self.serial~=serial)
	if self.serial~=serial or self.visible~=visible or self.reduced~=reduced then self:clear()end
	self.visible,self.serial,self.reduced=visible,serial,reduced
 return lost
end
function Effects:emit(kind,point,radius,color,tier,chain,serial,now,normal,cleared,score)
	if self.destroyed or not self.visible or serial~=self.serial then self.stats.rejected+=1;return false end
 if kind=="merge"and type(score)=="number"and score>0 then self:pop(point,radius,color,score,now)end
	local priority=if kind=="merge"then 100+(tier or 1)*10+math.min(chain or 1,9)+(if cleared then 1000 else 0)elseif kind=="impact"then 20 else 10
	local chosen
	for _,slot in ipairs(self.slots)do if not slot.active then chosen=slot;break end end
	if not chosen then
		for _,slot in ipairs(self.slots)do if not chosen or slot.priority<chosen.priority or(slot.priority==chosen.priority and slot.start<chosen.start)then chosen=slot end end
		if chosen.priority>priority then self.stats.rejected+=1;return false end
		self.stats.evicted+=1
	end
	chosen.active,chosen.priority,chosen.start=true,priority,now
	chosen.point,chosen.radius,chosen.kind=point,math.max(3,radius),kind
	chosen.duration=if self.reduced then .18 elseif kind=="merge"then .28 elseif kind=="impact"then .22 else .18
	chosen.normal=normal or Vector2.new(0,-1)
 put(self,chosen.ring,"Rotation",if kind=="impact"then math.deg(math.atan2(chosen.normal.X,chosen.normal.Y))else 0)
	put(self,chosen.ring,"Position",UDim2.fromOffset(point.X,point.Y));put(self,chosen.ring,"Visible",true)
	put(self,chosen.stroke,"Color",if kind=="merge"and(cleared or(chain or 1)>1)then color:Lerp(Color3.fromHex("#F4F8E9"),.22)else color)
 if kind=="merge"and(cleared or(chain or 1)>1)and(not self.captionUntil or now>=self.captionUntil or priority>=(self.captionPriority or 0))then
  self.captionPriority=priority
  local label=self.caption;local width=math.max(1,self.root.AbsoluteSize.X-8);local maxH=math.max(1,self.root.AbsoluteSize.Y-8)
  local text=if cleared then "MAX CLEAR +100 pts"else "×"..tostring(chain)
  put(self,label,"TextColor3",if cleared then Pico8[7] else Pico8.ChainRamp[math.clamp((chain or 2)-1,1,3)])
  local service=game:GetService("TextService")
  local bounds=service:GetTextSize(text,14,Enum.Font.GothamBold,Vector2.new(width,10000))
  if cleared and bounds.Y+4>maxH then text="MAX\n+100\npts";bounds=service:GetTextSize(text,14,Enum.Font.GothamBold,Vector2.new(width,10000))end
  local h=math.min(maxH,math.ceil(bounds.Y)+4)
  put(self,label,"Text",text);put(self,label,"Size",UDim2.fromOffset(width,h))
  put(self,label,"Position",UDim2.fromOffset(4,math.clamp(point.Y-radius-h-4,4,math.max(4,self.root.AbsoluteSize.Y-h-4))))
  put(self,label,"TextTransparency",0);put(self,label,"Visible",true)
  self.captionStart,self.captionUntil=now,now+.30
 end
	for _,fragment in ipairs(chosen.fragments)do put(self,fragment,"BackgroundColor3",color);put(self,fragment,"Visible",not self.reduced and kind=="merge")end
	self.stats.accepted+=1;self:update(now);return true
end
function Effects:update(now)
	if self.destroyed or not self.visible then return end
 if self.captionUntil then
  if now>=self.captionUntil then put(self,self.caption,"Visible",false);self.captionUntil=nil
  else put(self,self.caption,"TextTransparency",math.clamp((now-self.captionStart)/.30,0,1)*.8)end
 end
 self:updatePops(now)
	local active=0
	for _,slot in ipairs(self.slots)do if slot.active then
		local t=math.clamp((now-slot.start)/slot.duration,0,1)
		if t>=1 then
			slot.active=false;put(self,slot.ring,"Visible",false)
			for _,fragment in ipairs(slot.fragments)do put(self,fragment,"Visible",false)end
		else
			active+=1;local r=slot.radius*(if self.reduced then 1.04 else 1+.42*t)
			put(self,slot.ring,"Size",UDim2.fromOffset(r*2,r*(if slot.kind=="impact"then .65 elseif slot.kind=="drop"then .8+1.2*t else 2)))
			put(self,slot.stroke,"Transparency",.45+.55*t)
			if not self.reduced and slot.kind=="merge"then for j,fragment in ipairs(slot.fragments)do
				local angle=j*math.pi/3+.35;local distance=slot.radius*(.8+t*.9)
				put(self,fragment,"Position",UDim2.fromOffset(slot.point.X+math.cos(angle)*distance,slot.point.Y+math.sin(angle)*distance))
				local size=math.max(2,slot.radius*.12)*(1-t*.45);put(self,fragment,"Size",UDim2.fromOffset(size,size))
				put(self,fragment,"BackgroundTransparency",.25+.75*t)
			end end
		end
	end end
	self.stats.active=active
end
-- "+N" rises about 18 px and fades out within PopDuration. Reduced Effects keeps it
-- still at the merge point and only fades. Writes go through put(); no allocation.
function Effects:pop(point,radius,color,score,now)
 local chosen
 for _,pop in ipairs(self.pops)do if not pop.active then chosen=pop;break end end
 if not chosen then for _,pop in ipairs(self.pops)do if not chosen or pop.start<chosen.start then chosen=pop end end;self.stats.popEvicted=(self.stats.popEvicted or 0)+1 end
 chosen.active,chosen.start,chosen.x,chosen.y=true,now,point.X,math.max(9,point.Y-radius*.4)
 local label=chosen.label
 put(self,label,"Text","+"..tostring(score));put(self,label,"TextColor3",color);put(self,label,"TextSize",math.clamp(math.floor(radius*.5),15,24))
 put(self,label,"Position",UDim2.fromOffset(chosen.x,chosen.y));put(self,label,"TextTransparency",0);put(self,label,"TextStrokeTransparency",.1)
 put(self,label,"Visible",true)
 self.stats.pops=(self.stats.pops or 0)+1
end
function Effects:updatePops(now)
 for _,pop in ipairs(self.pops)do if pop.active then
  local t=(now-pop.start)/Effects.PopDuration
  if t>=1 then pop.active=false;put(self,pop.label,"Visible",false)
  else
   local fade=math.clamp((t-.45)/.55,0,1)
   put(self,pop.label,"TextTransparency",fade);put(self,pop.label,"TextStrokeTransparency",.1+.9*fade)
   if not self.reduced then put(self,pop.label,"Position",UDim2.fromOffset(pop.x,pop.y-18*math.sin(math.min(t,1)*math.pi*.5)))end
  end
 end end
end
function Effects:getStats()return table.clone(self.stats)end
function Effects:destroy()if self.destroyed then return end;self:clear();self.destroyed=true;self.root:Destroy()end
return Effects
