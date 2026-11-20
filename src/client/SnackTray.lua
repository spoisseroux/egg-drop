-- v2 Stat Snacks: the snack pouch as a tray of tiles (V2-PET-AND-SNACKS 2.2, V2-FEEDING-RUNES 2).
-- Used by the stats panel's Snacks view and by pet focus. Snacks of one stat and size share a
-- tile with a count ("six by three counters"). Pick one by tap, click, keys 1 to 6 or the d-pad;
-- Feed (button, Enter, F or gamepad A) feeds it. Or drag a tile onto the drop target (the pet):
-- pick up after 8 px (6 with a mouse) or a 0.15 s hold; the snack rides 28 px above a thumb; let go
-- inside to feed; outside it floats back with nothing sent. Esc or a right click cancels a carry.
-- The tray never decides anything: it calls onFeed(group) and the host asks the server.
local UserInputService=game:GetService("UserInputService")
local Shared=game:GetService("ReplicatedStorage").Shared
local K=require(Shared.StatEggCatalog)
local Stats=require(Shared.StatCatalog)
local UICopy=require(Shared.UICopy)
local Kit=require(script.Parent.DeckKit)
local SnackModel=require(script.Parent.SnackModel)
local Tray={}
Tray.__index=Tray
Tray.TouchLift=8
Tray.MouseLift=6
Tray.HoldLift=.15
Tray.ThumbGap=28

local sizeRank={}
for i,id in ipairs(K.SizeOrder)do sizeRank[id]=i end
local statRank={}
for i,id in ipairs(Stats.Order)do statRank[id]=i end
-- Pure: pouch entries grouped by stat and size, in panel order then size order. Each group:
-- {key, stat, size, count, ids (oldest first), known}.
function Tray.groups(pouch)
	local byKey,list={},{}
	for _,snack in ipairs(type(pouch)=="table"and pouch or {})do
		if type(snack)=="table"and type(snack.id)=="number"then
			local key=tostring(snack.stat)..":"..tostring(snack.size)
			local g=byKey[key]
			if not g then
				g={key=key,stat=snack.stat,size=snack.size,count=0,ids={},known=Stats.ById[snack.stat]~=nil and K.size(snack.size)~=nil}
				byKey[key]=g;table.insert(list,g)
			end
			g.count+=1;table.insert(g.ids,snack.id)
		end
	end
	table.sort(list,function(a,b)
		local sa,sb=statRank[a.stat]or 99,statRank[b.stat]or 99
		if sa~=sb then return sa<sb end
		local za,zb=sizeRank[a.size]or 99,sizeRank[b.size]or 99
		if za~=zb then return za<zb end
		return a.key<b.key
	end)
	for _,g in ipairs(list)do table.sort(g.ids)end
	return list
end
function Tray.groupName(g)
	return UICopy.get("stats.snacks.name",{stat=UICopy.get("stats.name."..tostring(g.stat)),size=UICopy.get("stats.snacks.size."..tostring(g.size))})
end
-- Pure: the card line for a group: what it will do and the boost the stat already has.
-- boosts: the pet's petStats boosts ({[stat]={mult,left}}).
function Tray.cardLine(g,boosts)
	local size=K.size(g.size)
	if not size then return Tray.groupName(g)end
	local line=UICopy.get("stats.snacks.card",{mult=size.mult,count=size.xp})
	local b=type(boosts)=="table"and boosts[g.stat]
	if b then line..=" · "..UICopy.get("stats.snacks.cardBoost",{stat=UICopy.get("stats.name."..g.stat),mult=b.mult,left=b.left})end
	return line
end
-- Pure: inside a drop target grown 30%, never smaller than 96 px across.
function Tray.inside(point,position,size)
	if not position or not size then return false end
	local w,h=math.max(96,size.X*1.3),math.max(96,size.Y*1.3)
	local c=position+size/2
	return math.abs(point.X-c.X)<=w/2 and math.abs(point.Y-c.Y)<=h/2
end

-- A layered snack icon (2D): 1 to 3 biscuit bars with the stat's icing and its rune.
local function icon(parent,g,s)
	local holder=Kit.frame(parent,"Icon",nil,UDim2.fromOffset(0,0),UDim2.fromOffset(s,s))
	local size=K.size(g.size)
	local layers=size and size.layers or 1
	local color=(Stats.ById[g.stat]or{color=Color3.fromHex("#BBBBBB")}).color
	local barH=math.max(4,math.floor(s*.14))
	for i=1,layers do
		local bar=Kit.frame(holder,"Layer"..i,nil,UDim2.fromOffset(math.floor(s*.12),s-barH*i-(i-1)*2-2),UDim2.fromOffset(math.floor(s*.76),barH),4)
		bar.BackgroundTransparency=0;bar.BackgroundColor3=SnackModel.Biscuit
	end
	local top=s-barH*layers-(layers-1)*2-2-barH
	local icing=Kit.frame(holder,"Icing",nil,UDim2.fromOffset(math.floor(s*.16),top),UDim2.fromOffset(math.floor(s*.68),barH),4)
	icing.BackgroundTransparency=0;icing.BackgroundColor3=color
	local rune=Kit.node("ImageLabel",holder,{Name="Rune",BackgroundTransparency=1,Image=SnackModel.Atlas,ImageRectOffset=SnackModel.Rune[g.stat]or Vector2.zero,
		ImageRectSize=Vector2.new(64,64),Size=UDim2.fromOffset(math.floor(s*.56),math.floor(s*.56)),Position=UDim2.fromOffset(math.floor(s*.22),math.max(0,top-math.floor(s*.5))),ZIndex=holder.ZIndex+2})
	local _=rune
	return holder
end

-- parent: a Frame the tray fills. options: compact, petName(), onFeed(group), onSelect(group),
-- dropTarget() -> (absolutePosition, absoluteSize) or nil, onCarry(kind, group) with kind
-- "lift" | "enter" | "leave" | "miss" | "cancel".
function Tray.new(parent,options)
	options=options or {}
	local self=setmetatable({parent=parent,options=options,groups={},index=1,busy=false,connections={},tiles={},misses=0},Tray)
	local root=Kit.frame(parent,"SnackTray",nil,UDim2.new(),UDim2.fromScale(1,1))
	self.root=root
	local compact=options.compact==true
	self.title=Kit.text(root,"Label",UICopy.get("stats.snacks.title"),"dim",{Name="Title",Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,-80,0,16),TextSize=if compact then 11 else 13})
	self.count=Kit.text(root,"Counter","","soft",{Name="Count",Position=UDim2.new(1,-80,0,0),Size=UDim2.fromOffset(80,16),TextSize=if compact then 11 else 13,TextXAlignment=Enum.TextXAlignment.Right})
	local row=Kit.node("ScrollingFrame",root,{Name="Row",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(0,20),Size=UDim2.new(1,0,0,if compact then 56 else 64),
		ScrollingDirection=Enum.ScrollingDirection.X,ScrollBarThickness=3,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.X,ZIndex=root.ZIndex+1,Selectable=false})
	Kit.node("UIListLayout",row,{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
	self.row=row
	local rowH=if compact then 56 else 64
	self.empty=Kit.text(root,"Small",UICopy.get("stats.snacks.empty"),"soft",{Name="Empty",Position=UDim2.fromOffset(0,20),Size=UDim2.new(1,0,0,rowH),TextWrapped=true,Visible=false})
	self.card=Kit.text(root,"Small","","soft",{Name="Card",Position=UDim2.fromOffset(0,24+rowH),Size=UDim2.new(1,-128,0,36),TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,TextSize=if compact then 12 else 14})
	local feed=Kit.button(root,"FeedButton",{text=UICopy.get("stats.snacks.feed"),variant="primary",glyph="A",showGlyph=false,size=Vector2.new(120,44),selectable=false})
	feed.Position=UDim2.new(1,-120,0,24+rowH);feed.ZIndex=root.ZIndex+3
	for _,d in ipairs(feed:GetDescendants())do if d:IsA("GuiObject")then d.ZIndex+=2 end end
	self.feedButton=feed
	table.insert(self.connections,feed.Activated:Connect(function()self:feed()end))
	-- Carry: global pointer tracking while a tile is pressed.
	table.insert(self.connections,UserInputService.InputChanged:Connect(function(input)self:pointerMoved(input)end))
	table.insert(self.connections,UserInputService.InputEnded:Connect(function(input)self:pointerEnded(input)end))
	table.insert(self.connections,UserInputService.InputBegan:Connect(function(input)
		if self.carry and(input.KeyCode==Enum.KeyCode.Escape or input.UserInputType==Enum.UserInputType.MouseButton2
			or(input.UserInputType==Enum.UserInputType.Touch and input~=self.press.input))then self:dropCarry(false,"cancel")end
	end))
	table.insert(self.connections,UserInputService.WindowFocusReleased:Connect(function()if self.carry then self:dropCarry(false,"cancel")end;self.press=nil end))
	return self
end

function Tray:selected()return self.groups[self.index]end
function Tray:setBusy(busy,text)
	self.busy=busy==true
	Kit.setEnabled(self.feedButton,not self.busy and self:selected()~=nil and self:selected().known and not self.locked)
	if text then self.card.Text=text end
end
-- model: {pouch, boosts, total, locked (a reason line or nil), select (a snack id to pick)}
function Tray:set(model)
	model=model or {}
	-- Never rebuild the tiles under a finger: apply the new pouch once the press ends.
	if self.press or self.carry then self.pendingModel=model;return end
	self.pendingModel=nil
	local previous=self:selected()
	self.groups=Tray.groups(model.pouch)
	self.boosts=model.boosts
	self.locked=model.locked
	self.count.Text=UICopy.get("stats.snacks.count",{count=#(model.pouch or {}),total=model.total or K.PouchSize})
	local wanted=1
	for i,g in ipairs(self.groups)do
		if model.select and table.find(g.ids,model.select)then wanted=i;break end
		if previous and g.key==previous.key then wanted=i end
	end
	self.index=math.clamp(wanted,1,math.max(1,#self.groups))
	self:render()
end
function Tray:render()
	for _,t in ipairs(self.tiles)do t.connection:Disconnect();t.button:Destroy()end
	table.clear(self.tiles)
	local compact=self.options.compact==true
	local tileW,tileH=if compact then 58 else 64,if compact then 54 else 60
	for i,g in ipairs(self.groups)do
		local button,state=Kit.tile(self.row,"Snack_"..g.key,{selectable=false,radius=10,compact=true,size=UDim2.fromOffset(tileW,tileH)})
		button.LayoutOrder=i
		local ic=icon(button,g,tileH-14);ic.Position=UDim2.fromOffset(4,4)
		Kit.text(button,"Counter","×"..g.count,"text",{Name="Count",Position=UDim2.new(1,-30,1,-20),Size=UDim2.fromOffset(26,16),TextSize=12,TextXAlignment=Enum.TextXAlignment.Right})
		button:SetAttribute("AccessibleLabel",UICopy.get("stats.snacks.tile",{stat=UICopy.get("stats.name."..tostring(g.stat)),size=UICopy.get("stats.snacks.size."..tostring(g.size)),count=g.count}))
		button:SetAttribute("SnackKey",g.key)
		local connection=button.InputBegan:Connect(function(input)self:pointerBegan(input,i)end)
		table.insert(self.tiles,{button=button,state=state,group=g,connection=connection})
	end
	self.empty.Visible=#self.groups==0
	self:paintSelection()
end
function Tray:paintSelection()
	for i,t in ipairs(self.tiles)do t.state.setSelected(i==self.index,false)end
	local g=self:selected()
	if self.locked then self.card.Text=self.locked
	elseif g then self.card.Text=Tray.groupName(g)..": "..Tray.cardLine(g,self.boosts)
	else self.card.Text=""end
	Kit.setEnabled(self.feedButton,not self.busy and g~=nil and g.known and not self.locked)
	self.root:SetAttribute("SelectedSnack",g and g.key or "")
end
function Tray:select(index)
	if #self.groups==0 then return false end
	self.index=math.clamp(index,1,#self.groups)
	self:paintSelection()
	local t=self.tiles[self.index];if t then Kit.boing(t.button)end
	if self.options.onSelect then self.options.onSelect(self:selected())end
	return true
end
function Tray:move(delta)return self:select(self.index+delta)end
function Tray:feed()
	local g=self:selected()
	if self.busy or self.locked or not g or not g.known then return false end
	self.misses=0
	if self.options.onFeed then return self.options.onFeed(g)==true end
	return false
end
-- Keys while the host routes input here: 1-6 pick, Left/Right move, Enter/F/A feed.
function Tray:input(key)
	local K2=Enum.KeyCode
	local digits={[K2.One]=1,[K2.Two]=2,[K2.Three]=3,[K2.Four]=4,[K2.Five]=5,[K2.Six]=6}
	if digits[key]then return self:select(digits[key])end
	if key==K2.Left or key==K2.DPadLeft or key==K2.A then return self:move(-1)end
	if key==K2.Right or key==K2.DPadRight or key==K2.D then return self:move(1)end
	if key==K2.Return or key==K2.KeypadEnter or key==K2.F or key==K2.ButtonA then return self:feed()end
	return false
end

-- Drag to feed.
local function pointerInput(input)
	return input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch
end
function Tray:pointerBegan(input,index)
	if not pointerInput(input)or self.press or self.busy then return end
	self.press={input=input,index=index,start=Vector2.new(input.Position.X,input.Position.Y),at=os.clock(),touch=input.UserInputType==Enum.UserInputType.Touch}
	task.delay(Tray.HoldLift,function()
		local p=self.press
		if p and p.input==input and not self.carry and p.touch then self:lift()end
	end)
end
function Tray:lift()
	local p=self.press;if not p or self.carry or self.locked then return end
	local g=self.groups[p.index];if not g or not g.known then return end
	if self.index~=p.index then self.index=p.index;self:paintSelection()end
	local layer=self.options.carryLayer or self.root
	local ghost=Kit.frame(layer,"SnackCarry",nil,UDim2.new(),UDim2.fromOffset(60,60));ghost.AnchorPoint=Vector2.new(.5,.5);ghost.ZIndex=layer.ZIndex+20
	local ic=icon(ghost,g,60);ic.ZIndex=ghost.ZIndex+1
	for _,d in ipairs(ghost:GetDescendants())do if d:IsA("GuiObject")then d.ZIndex+=20 end end
	Kit.node("UIScale",ghost,{Scale=1.25})
	self.carry={group=g,ghost=ghost,inside=false}
	self.tiles[p.index].button.Visible=false
	self:place(p.start)
	if self.options.onCarry then self.options.onCarry("lift",g)end
end
function Tray:place(point)
	local c=self.carry;if not c then return end
	local layer=c.ghost.Parent
	local offset=if self.press and self.press.touch then Tray.ThumbGap else 0
	local at=point-layer.AbsolutePosition-Vector2.new(0,offset)
	c.ghost.Position=UDim2.fromOffset(at.X,at.Y)
	local target=self.options.dropTarget
	local position,size
	if target then position,size=target()end
	local inside=Tray.inside(point-Vector2.new(0,offset),position,size)
	if inside~=c.inside then
		c.inside=inside
		local scale=c.ghost:FindFirstChildOfClass("UIScale");if scale then scale.Scale=if inside then 1.1 else 1.25 end
		if self.options.onCarry then self.options.onCarry(if inside then "enter"else "leave",c.group)end
		if inside and self.options.petName then self.card.Text=UICopy.get("stats.snacks.drop",{pet=self.options.petName()})end
	end
end
function Tray:pointerMoved(input)
	local p=self.press;if not p then return end
	if not(input==p.input or(not p.touch and input.UserInputType==Enum.UserInputType.MouseMovement))then return end
	local point=Vector2.new(input.Position.X,input.Position.Y)
	if not self.carry then
		if(point-p.start).Magnitude>=(if p.touch then Tray.TouchLift else Tray.MouseLift)then self:lift()end
	end
	if self.carry then self:place(point)end
end
function Tray:pointerEnded(input)
	local p=self.press;if not p then return end
	if not(input==p.input or(not p.touch and input.UserInputType==Enum.UserInputType.MouseButton1))then return end
	if self.carry then
		self:dropCarry(self.carry.inside,"drop")
	else
		-- A tap picks the snack (it floats to the cheek in pet focus).
		self.press=nil
		self:select(p.index)
	end
	self.press=nil
	if self.pendingModel and not self.carry then self:set(self.pendingModel)end
end
function Tray:dropCarry(inside,why)
	local c=self.carry;if not c then return end
	self.carry=nil
	local p=self.press;self.press=nil
	local tile=p and self.tiles[p.index]
	if inside then
		c.ghost:Destroy()
		if tile then tile.button.Visible=true end
		self:feed()
		if self.pendingModel then self:set(self.pendingModel)end
		return
	end
	-- A miss: the snack floats back to its slot; nothing is sent.
	if tile then
		local home=tile.button.AbsolutePosition+tile.button.AbsoluteSize/2-c.ghost.Parent.AbsolutePosition
		Kit.tween(c.ghost,.2,{Position=UDim2.fromOffset(home.X,home.Y)})
		task.delay(.2,function()c.ghost:Destroy();if tile.button.Parent then tile.button.Visible=true end end)
	else c.ghost:Destroy()end
	if why=="drop"then
		self.misses+=1
		if self.misses>=3 then self.card.Text=UICopy.get("stats.snacks.tapHint")end
	end
	if self.options.onCarry then self.options.onCarry(if why=="cancel"then "cancel"else "miss",c.group)end
	self:paintSelection()
	if self.misses>=3 then self.card.Text=UICopy.get("stats.snacks.tapHint")end
	if self.pendingModel then task.delay(.21,function()if not self.press and not self.carry and self.pendingModel then self:set(self.pendingModel)end end)end
end
-- Ends a carry in progress with nothing sent (the tray closed, focus ended).
function Tray:cancelCarry()
	if self.carry then self:dropCarry(false,"cancel")end
	self.press=nil
end
function Tray:destroy()
	if self.carry then self.carry.ghost:Destroy();self.carry=nil end
	for _,c in ipairs(self.connections)do c:Disconnect()end
	self.root:Destroy()
end
return Tray
