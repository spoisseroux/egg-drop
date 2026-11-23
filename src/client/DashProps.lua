-- Garden Dash local props (V3-DASH-BUILD-PLAN-2026-11-22, slice S7): the six hoops and the lucky clovers of the layout
-- being raced, the leaf tags over the pals and the balloon over the start. Placeholder parts until the art lands (Fable). Everything is local,
-- anchored, and never collides, touches or answers a raycast. Made once, the first time a race is shown, and reused;
-- a frame writes a part only while the hoops rise or sink. At most Props.MaxParts parts in all.
local Course=require(game:GetService("ReplicatedStorage").Shared.DashCourse)
local Grid=require(game:GetService("ReplicatedStorage").Shared.DashGrid)
local Props={};Props.__index=Props
Props.MaxParts=60
Props.FolderName="GardenDashLocal"
Props.RiseSeconds=.6
Props.Sunk=1.4
Props.HoopWidth=4.4
Props.Hoop=Color3.fromHex("#FF8FC0")
Props.HoopTop=Color3.fromHex("#FFF4DC")
Props.Clover=Color3.fromHex("#43DB5F")
Props.Leaf=Color3.fromHex("#BBF7D0")
Props.MaxClovers=4
Props.MaxTags=8
Props.TagReach=12 -- a pal's tag shows only this near the player's own pet, and never over another tag
Props.TagSize=Vector2.new(84,22)
Props.TagGap=4
Props.Balloon=Color3.fromHex("#FF6B6B")
Props.Flag=Color3.fromHex("#FFD23F")
Props.BalloonSize=5
Props.BalloonHeight=16 -- its middle, over the start line
Props.BalloonBob=.6
Props.BalloonPeriod=4
local UP=Vector3.yAxis

local function part(parent,name,size,color,shape)
	local item=Instance.new("Part")
	item.Name=name;item.Size=size;item.Color=color
	if shape then item.Shape=shape end
	item.Anchored=true;item.CanCollide=false;item.CanQuery=false;item.CanTouch=false;item.CastShadow=false
	item.Material=Enum.Material.SmoothPlastic
	item.Parent=parent
	return item
end
local function frameAt(cs,lane,count)
	local x,y,z,yaw=Grid.at(cs,false,lane,count)
	return CFrame.new(x,y,z)*CFrame.Angles(0,yaw,0)
end
-- The clover's spot for a lane past a hurdle, in cs (pure).
function Props.cloverAt(plan)
	if type(plan)~="table"or type(plan.cloverHurdle)~="number"or plan.cloverHurdle<1 then return nil end
	local hurdle=Course.hurdles(plan.layout)[plan.cloverHurdle]
	return hurdle and hurdle+Course.CloverPast
end
function Props.new(parent)
	return setmetatable({parent=parent,hoops={},clovers={},tags={},order={},share=0,want=0,count=0},Props)
end
function Props:make(name,size,color,shape)
	if self.count>=Props.MaxParts then return nil end
	if not self.folder then
		local folder=Instance.new("Folder")
		folder.Name=Props.FolderName
		folder.Parent=self.parent
		self.folder=folder
	end
	self.count+=1
	return part(self.folder,name,size,color,shape)
end
-- Shows a layout (plan = Sim.publicPlan). The hoops rise over RiseSeconds, or at once when `still`.
function Props:show(plan,still)
	self.still=still==true
	if self.plan~=plan then
		self.plan=plan
		for index,cs in ipairs(Course.hurdles(plan.layout))do
			local hoop=self.hoops[index]
			if not hoop then
				hoop={left=self:make("HoopLeft",Vector3.new(.22,.8,.22),Props.Hoop),right=self:make("HoopRight",Vector3.new(.22,.8,.22),Props.Hoop),
					top=self:make("HoopTop",Vector3.new(Props.HoopWidth,.2,.2),Props.HoopTop)}
				self.hoops[index]=hoop
			end
			hoop.at=frameAt(cs)
		end
		local at=Props.cloverAt(plan)
		for slot=1,Props.MaxClovers do
			local lane=at and plan.clovers[slot]
			local clover=self.clovers[slot]
			if lane and not clover then
				clover={part=self:make("Clover",Vector3.new(.5,.5,.5),Props.Clover,Enum.PartType.Ball)}
				self.clovers[slot]=clover
			end
			if clover then
				clover.lane=lane
				if lane then clover.at=frameAt(at,lane,plan.count)*CFrame.new(0,.4,0)end
				clover.taken=lane==nil
			end
		end
		self.share=0
		self:place()
	end
	self.want=1
end
function Props:hide()self.want=0 end
-- The clover in this lane was picked up.
function Props:pick(lane)
	for _,clover in ipairs(self.clovers)do
		if clover.lane==lane and not clover.taken then
			clover.taken=true
			if clover.part then clover.part.Transparency=1 end
			return true
		end
	end
	return false
end
function Props:place()
	local shown=self.share>0
	local transparency=if shown then 0 else 1
	local drop=UP*(-Props.Sunk*(1-self.share))
	for _,hoop in ipairs(self.hoops)do
		if hoop.left then hoop.left.CFrame=hoop.at*CFrame.new(-Props.HoopWidth/2,.4,0)+drop;hoop.left.Transparency=transparency end
		if hoop.right then hoop.right.CFrame=hoop.at*CFrame.new(Props.HoopWidth/2,.4,0)+drop;hoop.right.Transparency=transparency end
		if hoop.top then hoop.top.CFrame=hoop.at*CFrame.new(0,.8,0)+drop;hoop.top.Transparency=transparency end
	end
	for _,clover in ipairs(self.clovers)do
		if clover.part then
			if clover.at then clover.part.CFrame=clover.at+drop end
			clover.part.Transparency=if clover.taken then 1 else transparency
		end
	end
end
function Props:step(dt)
	if self.share==self.want then return end
	local move=if self.still then 1 else dt/Props.RiseSeconds
	self.share=if self.want>self.share then math.min(self.want,self.share+move)else math.max(self.want,self.share-move)
	self:place()
	if self.share==0 and self.want==0 then self.plan=nil end
end
-- Tags over the racing pets (beta 12 QA U5 and G4). One BillboardGui per seat on that seat's anchor part (no other
-- parts: the eight anchors are in the part budget), which draws whichever of these the frame wants:
--   name     a racer sees every racer's name from the lock to GO + NamesAfterGo, on top, none hidden: odd lanes just over
--            the head, even lanes a tier higher, and any two that still overlap push the farther one up (Props.tiers);
--            yours is lemon. They pop in left to right and fade out together.
--   chevron  then a racer's own pet keeps a small lemon chevron over its head until it is home.
--   leaf     then today's rule: a pal's leaf-green name near the player's own pet, never over another.
--   racing   an onlooker (no seat in this heat) sees a "Racing" pill over every racing pet from GO until it is home.
-- Names are proper names (AutoLocalize off); "Racing" is UICopy. Feed it with tag() (the text), tagAt() (where, every
-- frame) and placeTags() once a frame: a tag nothing moved this frame hides.
Props.NameH=22
Props.NamePad=9
Props.NameMax=104
Props.TierPx=30
Props.Stem=6
Props.RacingH=20
Props.RacingReach=60
Props.NamesAfterGo=1.5
Props.NamesFade=.3
Props.RacingFade=.2
Props.PopSeconds=.15
Props.PopGap=.04
Props.Chevron=14
Props.MaxTiers=8
Props.Ink=Color3.fromHex("#15143A")
Props.Cream=Color3.fromHex("#FFF4DC")
Props.Lemon=Color3.fromHex("#FFE14D")

-- Text width in px (FredokaOne), remembered; specs swap it.
local measured={}
function Props.measure(text,size)
	local key=text.."|"..size
	if measured[key]then return measured[key]end
	local ok,bounds=pcall(function()
		return game:GetService("TextService"):GetTextSize(text,size,Enum.Font.FredokaOne,Vector2.new(1000,100))
	end)
	local width=if ok and typeof(bounds)=="Vector2"then math.ceil(bounds.X)else math.ceil(#text*size*.55)
	measured[key]=width
	return width
end
-- Pure: a tier for each name tag. list = {{lane, x, y (the head on screen, px), w, away}}; odd lanes start at tier 0,
-- even lanes at tier 1; while two overlap, the farther one goes up a tier. Never hides one.
function Props.tiers(list)
	local tier={}
	for index,item in ipairs(list)do tier[index]=if(item.lane or index)%2==0 then 1 else 0 end
	local function overlap(i,j)
		local a,b=list[i],list[j]
		return math.abs(a.x-b.x)<(a.w+b.w)/2+Props.TagGap
			and math.abs((a.y-tier[i]*Props.TierPx)-(b.y-tier[j]*Props.TierPx))<Props.NameH+Props.TagGap
	end
	for _=1,#list*Props.MaxTiers do
		local moved=false
		for i=1,#list do
			for j=i+1,#list do
				if overlap(i,j)then
					local far=if(list[i].away or 0)>=(list[j].away or 0)then i else j
					if tier[far]<Props.MaxTiers then tier[far]+=1;moved=true end
				end
			end
		end
		if not moved then break end
	end
	return tier
end

local function node(class,parent,props)
	local item=Instance.new(class)
	for key,value in pairs(props)do item[key]=value end
	item.Parent=parent
	return item
end
function Props:ensureTag(slot)
	local tag=self.tags[slot]
	if tag or slot>Props.MaxTags then return tag end
	local anchor=self:make("PalTag",Vector3.new(.1,.1,.1),Props.Leaf)
	if not anchor then return nil end
	anchor.Transparency=1
	local board=node("BillboardGui",anchor,{Name="Leaf",Size=UDim2.fromOffset(Props.TagSize.X,Props.TagSize.Y),LightInfluence=0,MaxDistance=90,Adornee=anchor,
		Enabled=false,SizeOffset=Vector2.new(0,.5),ResetOnSpawn=false})
	local holder=node("Frame",board,{Name="Holder",BackgroundTransparency=1,Size=UDim2.fromScale(1,1)})
	local scale=node("UIScale",holder,{Scale=1})
	local pill=node("Frame",holder,{Name="Pill",BackgroundColor3=Props.Leaf,BackgroundTransparency=.1,BorderSizePixel=0,Size=UDim2.fromOffset(Props.TagSize.X,Props.TagSize.Y)})
	node("UICorner",pill,{CornerRadius=UDim.new(.5,0)})
	local stroke=node("UIStroke",pill,{Color=Props.Ink,Thickness=2,Enabled=false})
	local label=node("TextLabel",pill,{Name="Name",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),TextColor3=Props.Ink,Font=Enum.Font.FredokaOne,TextSize=15,
		TextTruncate=Enum.TextTruncate.AtEnd,AutoLocalize=false,Text=""})
	local Icons=require(script.Parent.DashIcons)
	local image=Icons.image("racingFlag")
	local flag=if image then node("ImageLabel",pill,{Name="Flag",BackgroundTransparency=1,Image=image,Size=UDim2.fromOffset(14,14),Visible=false})
		else node("TextLabel",pill,{Name="Flag",BackgroundTransparency=1,Text="⚑",Font=Enum.Font.GothamBold,TextSize=13,TextColor3=Props.Ink,AutoLocalize=false,
			Size=UDim2.fromOffset(14,14),Visible=false})
	local stem=node("Frame",holder,{Name="Stem",BackgroundColor3=Props.Ink,BorderSizePixel=0,Size=UDim2.fromOffset(2,0),Visible=false})
	local chevron=node("Frame",holder,{Name="Chevron",BackgroundTransparency=1,Size=UDim2.fromOffset(Props.Chevron,Props.Chevron),Visible=false})
	for side=-1,1,2 do
		local bar=node("Frame",chevron,{Name="Bar",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5-side*.2,.42),Size=UDim2.fromOffset(4,11),Rotation=side*40,
			BackgroundColor3=Props.Lemon,BorderSizePixel=0})
		node("UICorner",bar,{CornerRadius=UDim.new(.5,0)})
		node("UIStroke",bar,{Color=Props.Ink,Thickness=1.5})
	end
	tag={part=anchor,board=board,holder=holder,scale=scale,pill=pill,stroke=stroke,label=label,flag=flag,stem=stem,chevron=chevron,alpha=0,text=""}
	self.tags[slot]=tag
	return tag
end
-- The name over a seat's pet (a pal's, or a racer's pet name). Returns the tag, or nil past the budget.
function Props:tag(slot,text)
	local tag=self:ensureTag(slot)
	if not tag then return nil end
	tag.text=text or"";tag.used=true
	return tag
end
-- Where the seat's pet's head is this frame, and what it is doing: info = {lane, pal, mine, finished}.
function Props:tagAt(slot,position,info)
	local tag=self:ensureTag(slot)
	if not tag then return end
	tag.part.Position=position
	tag.used=true;tag.touched=true
	tag.info=info or tag.info
end
function Props:untag(slot)
	local tag=self.tags[slot]
	if tag then tag.used=false;tag.touched=false;tag.mode=nil;tag.alpha=0;tag.board.Enabled=false end
end
-- One tag's look for a mode; written only when it changes.
local function dress(tag,mode,tier,width,racingText)
	local key=mode..":"..tier..":"..width..":"..(if mode=="racing"then racingText else tag.text)
	if tag.dressed==key then return end
	tag.dressed=key
	local board,pill,label=tag.board,tag.pill,tag.label
	local h=if mode=="racing"then Props.RacingH else Props.NameH
	local stem=if mode=="name"then tier*Props.TierPx+Props.Stem else 0
	pill.Visible=mode~="chevron"
	tag.chevron.Visible=mode=="chevron"
	tag.flag.Visible=mode=="racing"
	tag.stem.Visible=stem>0
	tag.stroke.Enabled=mode~="leaf"
	board.AlwaysOnTop=mode=="name"
	board.MaxDistance=if mode=="racing"then Props.RacingReach else 90
	if mode=="chevron"then
		board.Size=UDim2.fromOffset(Props.Chevron+4,Props.Chevron+8)
		tag.chevron.Position=UDim2.fromOffset(2,0)
		return
	end
	board.Size=UDim2.fromOffset(width,h+stem)
	pill.Size=UDim2.fromOffset(width,h)
	pill.BackgroundColor3=if mode=="leaf"then Props.Leaf elseif mode=="name"and tag.info and tag.info.mine then Props.Lemon else Props.Cream
	pill.BackgroundTransparency=.1
	tag.stem.Position=UDim2.fromOffset(math.floor(width/2)-1,h);tag.stem.Size=UDim2.fromOffset(2,stem)
	if mode=="racing"then
		label.Text=racingText;label.AutoLocalize=true;label.TextSize=12
		tag.flag.Position=UDim2.fromOffset(7,3)
		label.Position=UDim2.fromOffset(7+14+4,0);label.Size=UDim2.new(1,-(7+14+4+9),1,0)
		label.TextXAlignment=Enum.TextXAlignment.Left
	else
		label.Text=tag.text;label.AutoLocalize=false;label.TextSize=if mode=="name"then 13 else 15
		label.Position=UDim2.fromOffset(if mode=="name"then Props.NamePad else 0,0)
		label.Size=if mode=="name"then UDim2.new(1,-Props.NamePad*2,1,0)else UDim2.fromScale(1,1)
		label.TextXAlignment=Enum.TextXAlignment.Center
	end
end
local function nearer(a,b)return a.away<b.away end
-- Once a frame. anchor: the player's own pet (nil = none). project(position) -> screen x, y in px, or nil off screen.
-- ctx (nil = after the names, for a racer): {viewer = "racer" | "onlooker", now, dt, reduced, namesUntil, running}.
function Props:placeTags(anchor,project,ctx)
	ctx=ctx or {}
	local now,dt,reduced=ctx.now or 0,ctx.dt or 0,ctx.reduced==true
	local onlooker=ctx.viewer=="onlooker"
	local names=not onlooker and ctx.namesUntil~=nil and now<ctx.namesUntil
	if not names then self.popAt=nil end
	local order,named=self.order,{}
	table.clear(order)
	for slot,tag in pairs(self.tags)do
		local info=tag.info or {}
		local want=nil
		if tag.used and tag.touched then
			if onlooker then
				if ctx.running and not info.finished then want="racing"end
			elseif names then want="name"
			elseif info.mine then if not info.finished then want="chevron"end
			elseif info.pal and anchor then
				tag.away=(tag.part.Position-anchor).Magnitude
				if tag.away<=Props.TagReach then
					tag.x,tag.y=project(tag.part.Position)
					if tag.x then table.insert(order,tag)end
				end
			end
		end
		tag.want=want
		tag.slot=slot
		if want=="name"then
			local x,y=project(tag.part.Position)
			if x then
				tag.x,tag.y=x,y
				tag.away=if anchor then(tag.part.Position-anchor).Magnitude else 0
				table.insert(named,tag)
			else tag.want=nil end
		end
	end
	-- Leaf tags: nearest first, none over another.
	table.sort(order,nearer)
	for i,tag in ipairs(order)do
		local free=true
		for j=1,i-1 do
			local other=order[j]
			if other.want=="leaf"and math.abs(tag.x-other.x)<Props.TagSize.X+Props.TagGap and math.abs(tag.y-other.y)<Props.TagSize.Y+Props.TagGap then free=false;break end
		end
		if free then tag.want="leaf"end
	end
	-- Names: measured, tiered, popping in left to right.
	local list={}
	for index,tag in ipairs(named)do
		tag.width=math.clamp(Props.NamePad*2+Props.measure(tag.text,13),40,Props.NameMax)
		list[index]={lane=tag.info and tag.info.lane or tag.slot,x=tag.x,y=tag.y,w=tag.width,away=tag.away}
	end
	local tiers=Props.tiers(list)
	-- Each name pops the first frame it is seen, left to right, PopGap after the one before.
	if names then
		self.popAt=self.popAt or {}
		local fresh={}
		for _,tag in ipairs(named)do if not self.popAt[tag]then table.insert(fresh,tag)end end
		table.sort(fresh,function(a,b)return a.x<b.x end)
		for _,tag in ipairs(fresh)do
			local at=math.max(now,self.popNext or now)
			self.popAt[tag]=at
			self.popNext=at+Props.PopGap
		end
	else self.popNext=nil end
	local racingText=nil
	for _,tag in pairs(self.tags)do
		local want=tag.want
		if want then
			tag.mode=want
			if want=="racing"and not racingText then racingText=require(game:GetService("ReplicatedStorage").Shared.UICopy).get("dash.racing")end
			local tier=0
			for index,item in ipairs(named)do if item==tag then tier=tiers[index]end end
			tag.tier=tier
			local width=if want=="name"then tag.width elseif want=="racing"then 7+14+4+Props.measure(racingText,12)+9 else Props.TagSize.X
			dress(tag,want,tier,width,racingText or"")
		end
		-- Fades: names out over NamesFade, Racing in and out over RacingFade, the leaf and chevron at once.
		local target=if want then 1 else 0
		local seconds=if tag.mode=="racing"then Props.RacingFade elseif tag.mode=="name"and not want then Props.NamesFade else 0
		if reduced or seconds==0 then tag.alpha=target
		elseif tag.alpha<target then tag.alpha=math.min(target,tag.alpha+dt/seconds)
		else tag.alpha=math.max(target,tag.alpha-dt/seconds)end
		if want=="name"and tag.alpha<1 then tag.alpha=1 end -- names pop in, they do not fade in
		local on=tag.alpha>0
		if tag.board.Enabled~=on then tag.board.Enabled=on end
		if on then
			local fade=1-tag.alpha
			if tag.shownFade~=fade then
				tag.shownFade=fade
				tag.pill.BackgroundTransparency=.1+.9*fade;tag.label.TextTransparency=fade;tag.stroke.Transparency=fade
				tag.stem.BackgroundTransparency=fade
				if tag.flag:IsA("ImageLabel")then tag.flag.ImageTransparency=fade else tag.flag.TextTransparency=fade end
			end
			local pop=1
			if tag.mode=="name"and self.popAt and self.popAt[tag]and not reduced then
				pop=.8+.2*math.clamp((now-self.popAt[tag])/Props.PopSeconds,0,1)
			end
			if tag.scale.Scale~=pop then tag.scale.Scale=pop end
			if tag.mode=="chevron"then
				local bob=if reduced then 0 else math.floor(3*math.sin(now*math.pi*2)+.5)
				if tag.bob~=bob then tag.bob=bob;tag.chevron.Position=UDim2.fromOffset(2,3+bob)end
			end
		else tag.mode=nil end
		tag.touched=false
	end
end
-- The balloon over the start arch, tall enough to see from the arrival dais (96, 66). Placeholder: a ball and a flag.
function Props:balloon(now,still)
	local made=self.sky
	if not made then
		local ball=self:make("Balloon",Vector3.one*Props.BalloonSize,Props.Balloon,Enum.PartType.Ball)
		local flag=self:make("BalloonFlag",Vector3.new(.2,1.6,3),Props.Flag)
		if not ball or not flag then return end
		local x,y,z=Course.at(0)
		made={ball=ball,flag=flag,at=CFrame.new(x,y+Props.BalloonHeight,z)}
		self.sky=made
	end
	local up=if still then 0 else Props.BalloonBob*math.sin(now/Props.BalloonPeriod*math.pi*2)
	if made.up==up then return end
	made.up=up
	made.ball.CFrame=made.at*CFrame.new(0,up,0)
	made.flag.CFrame=made.at*CFrame.new(0,up-Props.BalloonSize/2-1,0)
end
function Props:destroy()
	if self.folder then self.folder:Destroy();self.folder=nil end
	table.clear(self.hoops);table.clear(self.clovers);table.clear(self.tags);table.clear(self.order)
	self.sky=nil
	self.plan,self.share,self.want,self.count=nil,0,0,0
end
return Props
