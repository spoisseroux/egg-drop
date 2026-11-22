-- Garden Dash local props (V3-DASH-BUILD-PLAN-2026-11-22, slice S7): the six hoops and the lucky clovers of the layout
-- being raced, the leaf tags over the pals and the balloon over the start. Placeholder parts until the art lands (Fable). Everything is local,
-- anchored, and never collides, touches or answers a raycast. Made once, the first time a race is shown, and reused;
-- a frame writes a part only while the hoops rise or sink. At most Props.MaxParts parts in all.
local Course=require(game:GetService("ReplicatedStorage").Shared.DashCourse)
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
local function frameAt(cs,lane)
	local x,y,z,yaw=Course.at(cs,false,lane)
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
				if lane then clover.at=frameAt(at,lane)*CFrame.new(0,.4,0)end
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
-- A leaf-green name tag over a pal. Returns the slot; move it with tagAt.
function Props:tag(slot,text)
	local tag=self.tags[slot]
	if not tag then
		if slot>Props.MaxTags then return end
		local anchor=self:make("PalTag",Vector3.new(.1,.1,.1),Props.Leaf)
		if not anchor then return end
		anchor.Transparency=1
		local board=Instance.new("BillboardGui")
		board.Name="Leaf";board.Size=UDim2.fromOffset(Props.TagSize.X,Props.TagSize.Y);board.LightInfluence=0;board.MaxDistance=90;board.Adornee=anchor;board.Enabled=false
		local label=Instance.new("TextLabel")
		label.Name="Name";label.Size=UDim2.fromScale(1,1);label.BackgroundColor3=Props.Leaf;label.BackgroundTransparency=.1
		label.TextColor3=Color3.fromHex("#15143A");label.Font=Enum.Font.FredokaOne;label.TextSize=15
		label.TextTruncate=Enum.TextTruncate.AtEnd;label.AutoLocalize=false
		local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(.5,0);corner.Parent=label
		label.Parent=board;board.Parent=anchor
		tag={part=anchor,board=board,label=label}
		self.tags[slot]=tag
	end
	tag.label.Text=text;tag.used=true
end
function Props:tagAt(slot,position)
	local tag=self.tags[slot]
	if tag and tag.used then tag.part.Position=position end
end
function Props:untag(slot)
	local tag=self.tags[slot]
	if tag then tag.used=false;tag.board.Enabled=false end
end
local function nearer(a,b)return a.away<b.away end
-- Which tags show this frame: near `anchor` (the player's own pet; nil = none), nearest first, none over another.
-- project(position) -> screen x, y in px, or nil when it is off screen.
function Props:placeTags(anchor,project)
	local order=self.order
	table.clear(order)
	for _,tag in pairs(self.tags)do
		tag.show=false
		if tag.used and anchor then
			tag.away=(tag.part.Position-anchor).Magnitude
			if tag.away<=Props.TagReach then
				tag.x,tag.y=project(tag.part.Position)
				if tag.x then table.insert(order,tag)end
			end
		end
	end
	table.sort(order,nearer)
	for i,tag in ipairs(order)do
		tag.show=true
		for j=1,i-1 do
			local other=order[j]
			if other.show and math.abs(tag.x-other.x)<Props.TagSize.X+Props.TagGap and math.abs(tag.y-other.y)<Props.TagSize.Y+Props.TagGap then
				tag.show=false
				break
			end
		end
	end
	for _,tag in pairs(self.tags)do
		if tag.board.Enabled~=tag.show then tag.board.Enabled=tag.show end
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
