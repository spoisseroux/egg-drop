-- Four reusable, passive tray bursts. No event creates Instances or tweens.
local Effects={};Effects.__index=Effects
local Pico8=require(game:GetService("ReplicatedStorage").Shared.Pico8)
-- Deck juice (Levels matter S3): the merge pop's look, and the drop trail and start flourish this layer
-- owns. Nothing below is made, listened to or stepped while the part is off or the choice is classic.
local Shared=game:GetService("ReplicatedStorage").Shared
local Juice=require(Shared.DeckJuiceCatalog)
local Levels=require(Shared.Levels)
local Budget=require(script.Parent.AliveBudget)
Effects.PopDuration=.7
-- G1 (QA 2026-11-16) merge juice. Everything below scales with the merged tier.
Effects.PunchTime=.1 -- "+N" and the chain counter land from PunchScale to 1 in this long
Effects.PunchScale=1.45
Effects.CaptionHold=.5 -- chain counter lifetime (was .30)
Effects.White=Color3.fromHex("#F4F8E9")
-- Deck juice P1: the second ring on tiers IV and V (60 ms late, 60% alpha: transparency .4 at its brightest).
Effects.EchoDelay,Effects.EchoAlpha=.06,.4
-- AeroJuice (or nil): read for the echo ring, the beads and the drop buzz. Nothing changes while it is nil or off.
function Effects:setAero(juice)self.aero=juice end
-- Text size `u` (0..1, eased) of the way through the punch: PunchScale x size down to size.
function Effects.punchSize(size,u)return math.floor(size*(Effects.PunchScale+(1-Effects.PunchScale)*u)+.5)end
-- Chain counter size: bigger with every chain step, capped for the phone tray.
function Effects.chainTextSize(chain)return 16+2*math.clamp(chain or 2,2,7)end
-- Merge ring lifetime and reach, and how far the fragments fly (in ball radii).
function Effects.mergeDuration(tier)return .22+.02*math.clamp(tier or 1,1,5)end
function Effects.ringReach(tier)return .42+.08*math.clamp(tier or 1,1,5)end
function Effects.fragmentReach(tier)return 1.1+.2*math.clamp(tier or 1,1,5)end
-- The chosen merge pops: the same slots and fragments, other shapes. `stretch` is how much longer the
-- fragments live than the ring; the ring, the "+N" and the chain counter never change.
Effects.Pops=table.freeze({confetti=table.freeze({stretch=1.9}),fizz=table.freeze({stretch=1.7})})
Effects.Ink=Color3.fromHex("#142D20")
Effects.Confetti=table.freeze({Color3.fromHex("#FFD84A"),Color3.fromHex("#FF6FA8"),Color3.fromHex("#58B8FF"),
 Color3.fromHex("#5FE39A"),Color3.fromHex("#FF9A3C"),Color3.fromHex("#F4F8E9")})
-- Pure: fragment `j` (1..6) of a pop at `t` (0..1, `out` eased): x, y, width and height in ball radii,
-- degrees, transparency. Numbers only.
function Effects.popPose(id,j,t,out,reach)
 if id=="confetti"then
  -- Bursts out, then flutters down as it turns.
  local angle=j*math.pi/3+.35;local d=.8+out*reach
  return math.cos(angle)*d,math.sin(angle)*d*.85-.35*out+1.25*t*t,
   .36,.22*(.35+.65*math.abs(math.cos(t*9+j))),j*47+(if j%2==0 then -220 else 260)*t,math.clamp((t-.6)/.4,0,1)
 end
 -- Fizz: bubbles of three sizes rush up, swell and pop.
 local pop=math.clamp((t-.8)/.2,0,1);local size=(.24+.08*(j%3))*(1+.35*pop)
 return(j-3.5)/2.5*.95+math.sin(t*7+j*1.7)*.16,-(.2+(.75+.26*((j*2)%3))*out*reach*.75),size,size,0,.08+.92*pop
end
-- Pure: what the board's DeckJuice attribute asks for: pop, trail and start ids this build knows, nil
-- each for classic. A missing, broken or unknown value is classic.
function Effects.readJuice(text)
 if type(text)~="string"or text==""then return nil,nil,nil end
 local ok,choice=pcall(function()return game:GetService("HttpService"):JSONDecode(text)end)
 if not ok or type(choice)~="table"then return nil,nil,nil end
 local function known(kind)return if Juice.row(kind,choice[kind])then choice[kind]else nil end
 return known("pop"),known("trail"),known("start")
end
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
 -- Juice: the first drop cuts the start flourish, so it is never in the way.
 if self.flourish and(count or 0)>0 then self.flourish:cancel()end
 -- Deck juice P3: an accepted drop on the board I am looking at buzzes once and restarts the idle clock.
 if accepted and self.visible and self.aero then self.aero:dropped(os.clock())end
 return accepted
end
function Effects:clear()
	for _,slot in ipairs(self.slots)do
		slot.active=false;put(self,slot.ring,"Visible",false)
		if slot.echoRing then put(self,slot.echoRing,"Visible",false)end
		for _,fragment in ipairs(slot.fragments)do put(self,fragment,"Visible",false)end
	end
 if self.trail then self.trail:clear()end
 if self.flourish then self.flourish:cancel()end
 if self.caption then put(self,self.caption,"Visible",false)end
 if self.pops then for _,pop in ipairs(self.pops)do pop.active=false;put(self,pop.label,"Visible",false)end end
 if self.aero then self.aero:hideAll()end
 self.captionUntil=nil
	self.stats.active=0
end
function Effects:setOwner(visible,serial,reduced)
	if self.destroyed then return end
 visible=visible==true and type(serial)=="number"
 local lost=self.visible and(not visible or self.serial~=serial)
	if self.serial~=serial or self.visible~=visible or self.reduced~=reduced then self:clear()end
	self.visible,self.serial,self.reduced=visible,serial,reduced
 if self.trail then self.trail:setOwner(visible,reduced)end
 if self.flourish then self.flourish:owner(visible,serial,reduced,self.dropSerial==serial and(self.drops or 0)==0)end
 return lost
end
function Effects:emit(kind,point,radius,color,tier,chain,serial,now,normal,cleared,score)
	if self.destroyed or not self.visible or serial~=self.serial then self.stats.rejected+=1;return false end
 if kind=="merge"and type(score)=="number"and score>0 then self:pop(point,radius,color,score,now)end
	-- A slow phone stays on the classic pop for the session.
	if self.popStyle and Budget.level()>=Budget.MaxLevel then self:setPop(nil)end
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
	chosen.duration=if self.reduced then .18 elseif kind=="merge"then Effects.mergeDuration(tier) elseif kind=="impact"then .22 else .18
	chosen.tier=tier or 1
	chosen.style=if kind=="merge"and not self.reduced then self.popStyle else nil
	chosen.ringTime=nil
	if chosen.style then chosen.ringTime=chosen.duration;chosen.duration*=Effects.Pops[chosen.style].stretch end
	-- Deck juice P1 (AeroJuice): tiers IV and V get a second ring, EchoDelay late at 60% alpha; the classic fragments
	-- give way to AeroJuice's glass beads (a chosen pop keeps its own).
	local aero=self.aero
	chosen.echo=kind=="merge"and not self.reduced and(tier or 1)>=4 and aero~=nil and aero:can("echo")
	chosen.beads=kind=="merge"and not chosen.style and aero~=nil and aero:can("beads")
	if chosen.echo then
		if not chosen.echoRing then
			chosen.echoRing=node(self.root,"Echo"..table.find(self.slots,chosen))
			chosen.echoStroke=Instance.new("UIStroke");chosen.echoStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;chosen.echoStroke.Parent=chosen.echoRing
		end
		chosen.ringTime=chosen.ringTime or chosen.duration
		chosen.duration=math.max(chosen.duration,chosen.ringTime+Effects.EchoDelay)
		put(self,chosen.echoStroke,"Thickness",1.5+.5*math.clamp(tier or 1,1,5))
		put(self,chosen.echoRing,"Position",UDim2.fromOffset(point.X,point.Y));put(self,chosen.echoRing,"Visible",false)
	elseif chosen.echoRing then put(self,chosen.echoRing,"Visible",false)end
	put(self,chosen.stroke,"Thickness",if kind=="merge"then 1.5+.5*math.clamp(tier or 1,1,5)else 1.5)
	chosen.normal=normal or Vector2.new(0,-1)
 put(self,chosen.ring,"Rotation",if kind=="impact"then math.deg(math.atan2(chosen.normal.X,chosen.normal.Y))else 0)
	put(self,chosen.ring,"Position",UDim2.fromOffset(point.X,point.Y));put(self,chosen.ring,"Visible",true)
	put(self,chosen.stroke,"Color",if kind=="merge"and(cleared or(chain or 1)>1)then color:Lerp(Color3.fromHex("#F4F8E9"),.22)else color)
	if chosen.echo then put(self,chosen.echoStroke,"Color",chosen.stroke.Color)end
 if kind=="merge"and(cleared or(chain or 1)>1)and(not self.captionUntil or now>=self.captionUntil or priority>=(self.captionPriority or 0))then
  self.captionPriority=priority
  local label=self.caption;local width=math.max(1,self.root.AbsoluteSize.X-8);local maxH=math.max(1,self.root.AbsoluteSize.Y-8)
  local text=if cleared then "MAX CLEAR +100 pts"else "×"..tostring(chain)
  put(self,label,"TextColor3",if cleared then Pico8[7] else Pico8.ChainRamp[math.clamp((chain or 2)-1,1,3)])
  local service=game:GetService("TextService")
  -- The chain counter grows with the chain and lands with a punch; the box is sized
  -- for the punch peak so the text never clips. MAX CLEAR keeps its measured 14 px.
  local size=if cleared then 14 else Effects.chainTextSize(chain)
  local peak=if cleared or self.reduced then size else Effects.punchSize(size,0)
  self.captionSize,self.captionPunch=size,peak>size
  put(self,label,"TextSize",peak)
  local bounds=service:GetTextSize(text,peak,Enum.Font.GothamBold,Vector2.new(width,10000))
  if cleared and bounds.Y+4>maxH then text="MAX\n+100\npts";bounds=service:GetTextSize(text,14,Enum.Font.GothamBold,Vector2.new(width,10000))end
  local h=math.min(maxH,math.ceil(bounds.Y)+4)
  put(self,label,"Text",text);put(self,label,"Size",UDim2.fromOffset(width,h))
  put(self,label,"Position",UDim2.fromOffset(4,math.clamp(point.Y-radius-h-4,4,math.max(4,self.root.AbsoluteSize.Y-h-4))))
  put(self,label,"TextTransparency",0);put(self,label,"Visible",true)
  self.captionStart,self.captionUntil=now,now+Effects.CaptionHold
 end
	-- Every other fragment is a near-white sparkle so the burst reads on any ball colour.
	if chosen.style then
		for j,fragment in ipairs(chosen.fragments)do
			put(self,fragment,"BackgroundColor3",if chosen.style=="confetti"then Effects.Confetti[j]else color:Lerp(Effects.White,if j%2==0 then .85 else .55))
			put(self,fragment,"Visible",true)
		end
	else
		for j,fragment in ipairs(chosen.fragments)do put(self,fragment,"BackgroundColor3",if j%2==0 then color:Lerp(Effects.White,.7)else color);put(self,fragment,"Visible",not self.reduced and kind=="merge"and not chosen.beads)end
	end
	self.stats.accepted+=1;self:update(now);return true
end
function Effects:update(now)
	if self.destroyed or not self.visible then return end
 if self.captionUntil then
  if now>=self.captionUntil then put(self,self.caption,"Visible",false);self.captionUntil=nil
  else
   local age=now-self.captionStart
   -- Opaque through the punch and a short hold, then fades.
   put(self,self.caption,"TextTransparency",math.clamp((age-.2)/(Effects.CaptionHold-.2),0,1)*.85)
   if self.captionPunch then
    local u=math.clamp(age/Effects.PunchTime,0,1);u=1-(1-u)*(1-u)
    put(self,self.caption,"TextSize",Effects.punchSize(self.captionSize,u))
   end
  end
 end
 self:updatePops(now)
 if self.trail then self.trail:step(now)end
 if self.flourish then self.flourish:update(now)end
	local active=0
	for _,slot in ipairs(self.slots)do if slot.active then
		local t=math.clamp((now-slot.start)/slot.duration,0,1)
		if t>=1 then
			slot.active=false;put(self,slot.ring,"Visible",false)
			if slot.echoRing then put(self,slot.echoRing,"Visible",false)end
			for _,fragment in ipairs(slot.fragments)do put(self,fragment,"Visible",false)end
		else
			local merge=slot.kind=="merge"
			-- A chosen pop's fragments (`whole`) outlive the ring, which keeps its own time (so does an echo).
			local style,whole=slot.style,t
			if slot.ringTime then t=math.min(1,(now-slot.start)/slot.ringTime)end
			if slot.echo then
				local e=(now-slot.start-Effects.EchoDelay)/slot.ringTime
				if e>=0 and e<1 then
					local eo=1-(1-e)*(1-e);local er=slot.radius*(1+Effects.ringReach(slot.tier)*eo)
					put(self,slot.echoRing,"Visible",true);put(self,slot.echoRing,"Size",UDim2.fromOffset(er*2,er*2))
					put(self,slot.echoStroke,"Transparency",Effects.EchoAlpha+(1-Effects.EchoAlpha)*e)
				else put(self,slot.echoRing,"Visible",false)end
			end
			-- A merge bursts out fast and eases to rest (ease-out); other rings stay linear.
			local out=if merge then 1-(1-t)*(1-t)else t
			active+=1;local r=slot.radius*(if self.reduced then 1.04 elseif merge then 1+Effects.ringReach(slot.tier)*out else 1+.42*t)
			put(self,slot.ring,"Size",UDim2.fromOffset(r*2,r*(if slot.kind=="impact"then .65 elseif slot.kind=="drop"then .8+1.2*t else 2)))
			-- A merge ring starts as a bright flash, then fades.
			put(self,slot.stroke,"Transparency",if merge and not self.reduced then .08+.92*t else .45+.55*t)
			if style then
				local reach,ease=Effects.fragmentReach(slot.tier),1-(1-whole)*(1-whole)
				for j,fragment in ipairs(slot.fragments)do
					local x,y,w,h,turn,fade=Effects.popPose(style,j,whole,ease,reach)
					put(self,fragment,"Position",UDim2.fromOffset(slot.point.X+x*slot.radius,slot.point.Y+y*slot.radius))
					put(self,fragment,"Size",UDim2.fromOffset(math.max(4,w*slot.radius),math.max(3,h*slot.radius)))
					put(self,fragment,"Rotation",turn);put(self,fragment,"BackgroundTransparency",fade);put(self,slot.edges[j],"Transparency",fade)
				end
			elseif not self.reduced and merge then for j,fragment in ipairs(slot.fragments)do
				local angle=j*math.pi/3+.35;local distance=slot.radius*(.8+out*Effects.fragmentReach(slot.tier))
				put(self,fragment,"Position",UDim2.fromOffset(slot.point.X+math.cos(angle)*distance,slot.point.Y+math.sin(angle)*distance))
				local size=math.max(2.5,slot.radius*.16)*(1-t*.5);put(self,fragment,"Size",UDim2.fromOffset(size,size))
				put(self,fragment,"BackgroundTransparency",.1+.9*t*t)
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
 put(self,label,"Text","+"..tostring(score));put(self,label,"TextColor3",color);chosen.size=math.clamp(math.floor(radius*.5),15,24)
 put(self,label,"TextSize",if self.reduced then chosen.size else Effects.punchSize(chosen.size,0))
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
   if not self.reduced then
    put(self,pop.label,"Position",UDim2.fromOffset(pop.x,pop.y-18*math.sin(math.min(t,1)*math.pi*.5)))
    local u=math.clamp((now-pop.start)/Effects.PunchTime,0,1);u=1-(1-u)*(1-u)
    put(self,pop.label,"TextSize",Effects.punchSize(pop.size,u))
   end
  end
 end end
end
-- Deck juice. nil (or an id this build does not draw) is classic: the pool is put back as it was made.
-- Its outlines are made once, with the first chosen pop.
function Effects:setPop(id)
 id=if type(id)=="string"and Effects.Pops[id]then id else nil
 if self.destroyed or self.popStyle==id then return end
 self:clear();self.popStyle=id
 local round=if id=="confetti"then UDim.new(0,2)else UDim.new(.5,0)
 for _,slot in ipairs(self.slots)do
  slot.style=nil
  if id and not slot.edges then
   slot.edges={}
   for j,fragment in ipairs(slot.fragments)do
    local edge=Instance.new("UIStroke");edge.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;edge.Thickness=1;edge.Color=Effects.Ink;edge.Parent=fragment
    slot.edges[j]=edge
   end
  end
  for j,fragment in ipairs(slot.fragments)do
   put(self,fragment,"Rotation",0);fragment:FindFirstChildOfClass("UICorner").CornerRadius=round
   if slot.edges then put(self,slot.edges[j],"Enabled",id~=nil)end
  end
 end
end
function Effects:setTrail(id)
 if self.destroyed then return end
 local options=self.juice
 local Trail=if id then require(script.Parent.DropTrail)else nil
 if not(Trail and Trail.Styles[id]and options and options.views and options.project)then
  if self.trail then self.trail:setStyle(nil);self.trail=nil end
  return
 end
 self.trailPool=self.trailPool or Trail.new(self.root,options)
 self.trail=self.trailPool
 self.trail:setStyle(id);self.trail:setOwner(self.visible,self.reduced)
end
function Effects:setStart(id)
 if self.destroyed then return end
 local Flourish=if id then require(script.Parent.DeckFlourish)else nil
 if not(Flourish and Flourish.Styles[id])then
  if self.flourish then self.flourish:setStyle(nil);self.flourish=nil end
  return
 end
 self.flourishPool=self.flourishPool or Flourish.new(self.root,self.juice)
 self.flourish=self.flourishPool
 self.flourish:setStyle(id)
end
function Effects:setJuice(pop,trail,start)self:setPop(pop);self:setTrail(trail);self:setStart(start)end
-- The host's one mount: {board (the folder with the attribute), views, project, launchY, ready}. Does
-- nothing where the part can never be on; while the switch is off everything is classic, and a flip
-- either way is followed. No per-frame work until something is chosen.
function Effects:attachJuice(options)
 if self.destroyed or self.juiceLinks or not Levels.ceiling("juice")then return false end
 self.juice=options
 local board=options.board
 local function read()
  if Levels.on("juice")then self:setJuice(Effects.readJuice(board:GetAttribute(Juice.Attribute)))else self:setJuice(nil,nil,nil)end
 end
 self.juiceLinks={board:GetAttributeChangedSignal(Juice.Attribute):Connect(read),Levels.changed():Connect(read)}
 read();return true
end
-- A ball's view was made (the host's addView). Only a chosen trail looks at it.
function Effects:ballAdded(source)local trail=self.trail;if trail then trail:added(source,os.clock())end end
function Effects:getStats()return table.clone(self.stats)end
function Effects:destroy()
 if self.destroyed then return end
 self:clear();self.destroyed=true
 if self.juiceLinks then for _,link in ipairs(self.juiceLinks)do link:Disconnect()end;table.clear(self.juiceLinks)end
 self.trail,self.flourish=nil,nil
 self.root:Destroy()
end
return Effects
