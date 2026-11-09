-- Bounded borderless run spans on a shared rounded logical grid. No Instances are
-- created after construction; overflow is sticky and leaves the cheap gel owner.
local Surface={};Surface.__index=Surface
Surface.DiagnosticLimit=4096
local function frame(parent,name,z)
	local f=Instance.new("Frame");f.Name,f.BorderSizePixel,f.BackgroundTransparency,f.ZIndex=name,0,0,z
	f.Active,f.Selectable,f.Visible=false,false,false;f.Parent=parent;return f
end
local function color(packed)
	return Color3.fromRGB(bit32.band(packed,255),bit32.band(bit32.rshift(packed,8),255),bit32.band(bit32.rshift(packed,16),255))
end
local function staticRectangles(pixels,width,height)
	local frequencies={};local base,largest=0,0
	for i=0,width*height-1 do local c=buffer.readu32(pixels,i*4);frequencies[c]=(frequencies[c]or 0)+1;if frequencies[c]>largest then base,largest=c,frequencies[c]end end
	local rectangles,active={},{}
	for y=0,height-1 do
		local nextActive={};local x=0
		while x<width do
			local start=x;local c=buffer.readu32(pixels,(y*width+x)*4);x+=1
			while x<width and buffer.readu32(pixels,(y*width+x)*4)==c do x+=1 end
			if c~=base then
				local key=start..":"..(x-start)..":"..c
				local r=active[key]
				if r then r.h+=1 else r={x=start,y=y,w=x-start,h=1,c=c};table.insert(rectangles,r)end
				nextActive[key]=r
			end
		end
		active=nextActive
	end
	return rectangles,base
end
function Surface.new(parent,background,width,height,limit)
	local started=os.clock();limit=math.clamp(math.floor(limit or Surface.DiagnosticLimit),1,Surface.DiagnosticLimit)
	local root
	local ok,result=pcall(function()
	root=frame(parent,"JellyLCDSpans",3);root.BackgroundTransparency=1;root.Size=UDim2.fromScale(1,1);root.ClipsDescendants=true
	local rectangles,base=staticRectangles(background,width,height)
	root.BackgroundTransparency=0;root.BackgroundColor3=color(base)
	local self=setmetatable({root=root,base=base,width=width,height=height,background=background,limit=limit,pool={},static={},rectangles=rectangles,xs=table.create(limit),ys=table.create(limit),ws=table.create(limit),colors=table.create(limit),rowStarts=table.create(height),rowCounts=table.create(height),rowHosts={},rowSlots={},liveRowCounts=table.create(height,0),free=table.create(limit),freeCount=limit,retired=table.create(limit),edgesX={},edgesY={},colorCache={},dirty=true,failed=false,stats={dynamicAllocated=limit,dynamicCreated=limit,staticAllocated=0,spansUsed=0,visibleSpans=0,lastDemand=0,peakDemand=0,propertyWrites=0}},Surface)
	for index,r in ipairs(self.rectangles)do
		local f=frame(root,"BoardSpan"..index,3);f.BackgroundColor3=color(r.c);f.Visible=true;self.static[index]=f
	end
	self.stats.staticAllocated=#self.static
	self.stash=frame(root,"UnusedPool",4);self.stash.BackgroundTransparency=1
	for y=1,height do
		-- Shared integer edges already bound each span. Nested row clipping can
		-- introduce compositor seams at device scaling; the outer tray stays clipped.
		local row=frame(root,"PixelRow"..y,4);row.BackgroundTransparency=1;row.ClipsDescendants=false;row.Visible=true
		self.rowHosts[y]=row;self.rowSlots[y]=table.create(width)
	end
	for index=1,limit do
		self.pool[index]={node=frame(self.stash,"GelSpan"..index,4),visible=false};self.free[index]=index
	end
	self.stats.rowHosts=height
	self.connection=root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self.dirty=true end)
	self.stats.constructionMs=(os.clock()-started)*1000
	return self
	end)
	if not ok then if root then root:Destroy()end;return nil,result end
	return result
end
-- Geometry is independent of palette identity; all five authored categories
-- stay distinct. No static or dynamic Instance is replaced on theme changes.
function Surface:setBackground(background,replacements)
 if self.failed or not replacements[self.base]then return false end
 for _,r in ipairs(self.rectangles)do if not replacements[r.c]then return false end end
 self.base=replacements[self.base];self.root.BackgroundColor3=color(self.base)
 for i,r in ipairs(self.rectangles)do r.c=replacements[r.c];self.static[i].BackgroundColor3=color(r.c)end
 self.background=background;return true
end
-- Reuse the actual quest underlay. Existing outside/rail rectangles mask it;
-- existing opaque gel spans stay above it. No pool, span or canvas is added.
function Surface:attachRegions(host,colors)
    self.root.ZIndex=3
    for i,r in ipairs(self.rectangles)do
        local foreground=r.c==colors.outside or r.c==colors.rail or r.c==colors.rim
        self.static[i].ZIndex=if foreground then 4 else 2
    end
    host.Parent=self.root;host.ZIndex=3
    for _,node in ipairs(host:GetChildren())do if node:IsA("GuiObject")then node.ZIndex=3 end end
end
function Surface:resize()
	local w,h=self.root.AbsoluteSize.X,self.root.AbsoluteSize.Y
	for x=0,self.width do self.edgesX[x]=math.floor(x*w/self.width+.5)end
	for y=0,self.height do self.edgesY[y]=math.floor(y*h/self.height+.5)end
	for index,r in ipairs(self.rectangles)do
		local f=self.static[index];local x,y=self.edgesX[r.x],self.edgesY[r.y]
		f.Position=UDim2.fromOffset(x,y);f.Size=UDim2.fromOffset(self.edgesX[r.x+r.w]-x,self.edgesY[r.y+r.h]-y)
		self.stats.propertyWrites+=2
	end
	for y=1,self.height do
		local row=self.rowHosts[y];row.Position=UDim2.fromOffset(0,self.edgesY[y-1]);row.Size=UDim2.new(1,0,0,self.edgesY[y]-self.edgesY[y-1]);self.stats.propertyWrites+=2
	end
	self.dirty=false
end
function Surface:paint(pixels)
	if self.failed then return false end
	local stats=self.stats;stats.propertyWrites=0
	local scanStarted=os.clock()
	local count=0
	for y=0,self.height-1 do
		local startCount=count;self.rowStarts[y+1]=count+1
		local x=0
		while x<self.width do
			local offset=(y*self.width+x)*4;local c=buffer.readu32(pixels,offset)
			if c==buffer.readu32(self.background,offset)then x+=1 else
				local start=x;x+=1
				while x<self.width do
					local nextOffset=(y*self.width+x)*4
					if buffer.readu32(pixels,nextOffset)~=c or c==buffer.readu32(self.background,nextOffset)then break end
					x+=1
				end
				count+=1
				if count<=self.limit then self.xs[count],self.ys[count],self.ws[count],self.colors[count]=start,y,x-start,c end
			end
		end
		self.rowCounts[y+1]=count-startCount
	end
	stats.scanMs=(os.clock()-scanStarted)*1000
	stats.lastDemand=count;stats.peakDemand=math.max(stats.peakDemand,count)
	if count>self.limit then
		self.failed=true;stats.failure="span-cap";stats.spansUsed=0;stats.visibleSpans=0;self.root.Visible=false
		return false
	end
	local commitStarted=os.clock()
	if self.dirty then self:resize()end
	-- Retire every shrinking row first so global capacity is sufficient even
	-- when demand moves from a later row into an earlier one in the same frame.
	local retiredCount=0
	for y=1,self.height do
		local slots=self.rowSlots[y]
		for k=self.rowCounts[y]+1,self.liveRowCounts[y]do
			local index=slots[k];slots[k]=nil;self.pool[index].row=nil
			self.freeCount+=1;self.free[self.freeCount]=index;retiredCount+=1;self.retired[retiredCount]=index
		end
	end
	local visible=0
	for y=1,self.height do
		local slots=self.rowSlots[y]
		for k=1,self.rowCounts[y]do
			local index=slots[k]
			if not index then index=self.free[self.freeCount];self.freeCount-=1;slots[k]=index end
			local slot=self.pool[index];local node=slot.node
			if slot.row~=y then node.Parent=self.rowHosts[y];slot.row=y;stats.propertyWrites+=1 end
			local run=self.rowStarts[y]+k-1
			local x=self.edgesX[self.xs[run]]
			local w=self.edgesX[self.xs[run]+self.ws[run]]-x
			if slot.x~=x then node.Position=UDim2.fromOffset(x,0);slot.x=x;stats.propertyWrites+=1 end
			if slot.w~=w then node.Size=UDim2.new(0,w,1,0);slot.w=w;stats.propertyWrites+=1 end
			local c=self.colors[run]
			if slot.c~=c then
				local tint=self.colorCache[c]
				if not tint then tint=color(c);if (self.colorCount or 0)<128 then self.colorCache[c]=tint;self.colorCount=(self.colorCount or 0)+1 end end
				node.BackgroundColor3=tint;slot.c=c;stats.propertyWrites+=1
			end
			local shown=w>0 and self.edgesY[y]>self.edgesY[y-1]
			if slot.visible~=shown then node.Visible=shown;slot.visible=shown;stats.propertyWrites+=1 end
			if shown then visible+=1 end
		end
		self.liveRowCounts[y]=self.rowCounts[y]
	end
	for k=1,retiredCount do
		local slot=self.pool[self.retired[k]]
		if not slot.row then
			slot.node.Parent=self.stash;stats.propertyWrites+=1
			if slot.visible then slot.node.Visible=false;slot.visible=false;stats.propertyWrites+=1 end
		end
	end
	stats.spansUsed,stats.visibleSpans=count,visible
	stats.commitMs=(os.clock()-commitStarted)*1000
	return true
end
function Surface:destroy()
	if self.destroyed then return end
	self.destroyed=true
	if self.connection then self.connection:Disconnect();self.connection=nil end
	self.failed=true;self.root:Destroy();table.clear(self.pool);table.clear(self.static)
end
return Surface
