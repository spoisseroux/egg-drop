-- Frutiger Aero "Medium" in the garden (WORLD-PLAN-2026-11-22 section 9; values in Shared.WorldAero). Client only and
-- looks only: nothing replicates, and no CFrame, size, collision, remote or save is touched. Off (Aero.on) nothing is
-- created, written or connected but the switch signal, and the garden is the one the server built.
--
-- One writer per property:
--   Lighting, its effects, the sky and the backdrop clouds   HollowClock, which paints self.look instead of WorldDusk
--                                                            while it is Clock.look (its own 5 s pass, no new one)
--   world meshes, water layers, beams and spray colours      this file, once per item
-- Never touched here: WorldMotion's CFrames, texture offsets, emitter switches and pulsing Transparency; the care
-- machine's status colours (GardenCareClient); the wind's bushes.
-- Every original is kept on the first write and put back exactly when the layer goes off, the room goes, or the item
-- leaves it. After the pass only arrivals are painted; the one timer (additions: frame budget, Reduced Motion) is 5 s.
local GuiService=game:GetService("GuiService")
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Shared=ReplicatedStorage:WaitForChild("Shared")
local Values=require(Shared:WaitForChild("WorldAero"))
local Additions=require(script.Parent.AeroAdditions)

local World={}
World.__index=World
World.Interval=5 -- seconds between budget and Reduced Motion checks, while there are additions
World.DropLevel=2 -- AliveBudget

-- One property, kept and written. `records`: item -> {was, want, now, parked}. "@Name" is an attribute. `now` is what the
-- engine read back (its floats are narrower), so a pass over a painted garden writes nothing.
local NONE={}
local function read(item,key)
	if string.sub(key,1,1)~="@"then return item[key]end
	local value=item:GetAttribute(string.sub(key,2))
	return if value==nil then NONE else value
end
local function put(item,key,value)
	if string.sub(key,1,1)~="@"then item[key]=value;return end
	item:SetAttribute(string.sub(key,2),if value==NONE then nil else value)
end
local function entry(records,item)
	local record=records[item]
	if not record then record={was={},now={},want={},parked={}};records[item]=record end
	return record
end
function World.write(records,item,key,value)
	local record=records[item]
	local current=read(item,key)
	if record and record.was[key]~=nil and current==record.now[key]and record.want[key]==value then return false end
	record=entry(records,item)
	if record.was[key]==nil then record.was[key]=current end
	put(item,key,value)
	record.want[key]=value
	record.now[key]=read(item,key)
	return true
end
function World.restore(records,item)
	local record=records[item]
	if not record then return end
	records[item]=nil
	for key,value in pairs(record.was)do pcall(put,item,key,value)end
	for _,child in ipairs(record.parked)do pcall(function()child.Parent=item end)end
end

-- options (fixtures): world, lighting, data, clock {look, now, apply}, switch {on, changed, trees, treesChanged},
-- level, reduced, reducedChanged, defer, delay, additions, warn. The game passes only clock.
function World.new(options)
	options=options or {}
	local self=setmetatable({world=options.world or workspace,lighting=options.lighting or game:GetService("Lighting"),
		clock=options.clock,enabled=false,turn=0,writes=0,light={},surfaces={},connections={},roomLinks={},late={}},World)
	self.data=options.data or require(Shared:WaitForChild("WorldV7Data"))
	self.switch=options.switch or require(Shared:WaitForChild("Aero"))
	self.level=options.level or require(script.Parent.AliveBudget).level
	self.defer,self.delay=options.defer or task.defer,options.delay or task.delay
	self.additions=options.additions or Additions
	self.warn=options.warn or warn
	self.reducedChanged=options.reducedChanged or function()return GuiService:GetPropertyChangedSignal("ReducedMotionEnabled")end
	self.reduced=options.reduced or function()
		local boards,player=ReplicatedStorage:FindFirstChild("EggDropBoards"),Players.LocalPlayer
		local board=boards and player and boards:FindFirstChild(tostring(player.UserId))
		return GuiService.ReducedMotionEnabled or board~=nil and board:GetAttribute("ReducedEffects")==true
	end
	-- What HollowClock paints while the layer is on (Clock.look).
	self.look={Hour=Values.Hour,Daylight=Values.Daylight,CloudColor=Values.CloudColor,paint=function()self:paintLight()end}
	return self
end

-- The game's entry: follows the switch for the rest of the session. nil where the v7 island is not the world.
function World.start(options)
	if require(Shared:WaitForChild("HollowWorldLayout")).WorldVersion~="v7"then return nil end
	local self=World.new(options)
	self.link=self.switch.changed():Connect(function()self:sync()end)
	self:sync()
	return self
end
function World:sync()
	local on=not self.destroyed and self.switch.on()
	if on==self.enabled then return end
	local ok,problem=pcall(if on then self.enable else self.disable,self)
	if ok then return end
	self:complain(problem)
	if on then pcall(self.disable,self)end
end
function World:complain(problem)
	if self.warned then return end
	self.warned=true
	self.warn("[Aero] "..tostring(problem))
end
function World:set(records,item,key,value)
	local ok,wrote=pcall(World.write,records,item,key,value)
	if not ok then self:complain(wrote)elseif wrote then self.writes+=1 end
end

-- Light: called by HollowClock only. Effects that are not there (yet) are skipped; its next pass finds them.
function World:paintLight()
	if not self.enabled then return end
	local lighting=self.lighting
	local function all(item,values)
		if not item then return end
		for key,value in pairs(values)do self:set(self.light,item,key,value)end
	end
	local function named(name,class)
		local item=lighting:FindFirstChild(name)
		return item and item:IsA(class)and item or nil
	end
	all(lighting,Values.Lighting)
	all(lighting:FindFirstChildOfClass("Atmosphere"),Values.Atmosphere)
	all(named("SproutHollowGrade","ColorCorrectionEffect"),Values.Grade)
	all(named("HollowBloom","BloomEffect"),Values.Bloom)
	all(named("HollowSunRays","SunRaysEffect"),Values.SunRays)
	local sky=named("WorldSky","Sky")
	local faces=Values.skyFaces(self.data)
	all(sky,Values.Sky)
	if sky and faces then
		for _,face in ipairs({"Bk","Dn","Ft","Lf","Rt","Up"})do self:set(self.light,sky,"Skybox"..face,faces[face])end
		self:set(self.light,sky,"@FaceSet",Values.FaceSet)
	end
end

-- Surfaces: one item, from its own name and its parent's. Safe to repeat.
function World:paintPart(part)
	local kind=Values.kind(part.Name)
	-- The backdrop ring is the clock's.
	if not kind or string.sub(part.Name,1,12)=="W7_Backdrop_"then return end
	if kind==Values.CrownKind then self:paintCrown(part);return end
	local surface=Values.Surfaces[kind]
	if not surface then return end
	for key,value in pairs(surface)do
		if key=="Tint"then
			for _,child in ipairs(part:GetChildren())do
				if child:IsA("SurfaceAppearance")then self:set(self.surfaces,child,"Color",value)end
			end
		elseif key=="Color"and part:GetAttribute("CareStatusSurface")==true
			or key=="Transparency"and part:GetAttribute("WorldMotion")=="pulse"then
			continue
		else
			self:set(self.surfaces,part,key,value)
		end
	end
end
function World:paintCrown(part)
	local crown=Values.Crowns[self.switch.trees()]
	if not crown then return end
	for _,child in ipairs(part:GetChildren())do
		if not child:IsA("SurfaceAppearance")then continue end
		if crown.Flat then
			-- Only its Parent moves, and only here: the same instance goes back.
			local record=entry(self.surfaces,part)
			local ok=pcall(function()child.Parent=nil end)
			if ok then table.insert(record.parked,child);self.writes+=1 end
		else
			self:set(self.surfaces,child,"Color",crown.Tint)
		end
	end
	if crown.Flat then
		if part:IsA("MeshPart")then self:set(self.surfaces,part,"TextureID","")end
		self:set(self.surfaces,part,"Material",crown.Material)
		self:set(self.surfaces,part,"Color",crown.Color)
	end
end
function World:paint(item)
	local parent=item.Parent
	if item:IsA("BasePart")then
		self:paintPart(item)
	elseif item:IsA("SurfaceAppearance")then
		if parent and parent:IsA("BasePart")then self:paintPart(parent)end
	elseif item:IsA("Texture")then
		local skin=Values.Skins[item.Name]
		local values=skin and parent and skin[Values.kind(parent.Name)or ""]
		if values then for key,value in pairs(values)do self:set(self.surfaces,item,key,value)end end
	elseif item:IsA("Beam")then
		self:set(self.surfaces,item,"Color",Values.Falls)
	elseif item:IsA("ParticleEmitter")then
		local spray=Values.Spray[item.Name]
		if spray then self:set(self.surfaces,item,"Color",spray)end
	end
end

-- Arrivals and departures, once per burst and never inside the event itself (a parent cannot move there).
function World:queue(item)
	if item then table.insert(self.late,item)end
	if self.scheduled then return end
	self.scheduled=true
	local turn=self.turn
	self.defer(function()
		if turn~=self.turn then return end
		self.scheduled=false
		local items=self.late
		self.late={}
		if not self.enabled or not self.room then return end
		self:sweep()
		for _,each in ipairs(items)do
			if self:inside(each)then
				local ok,problem=pcall(self.paint,self,each)
				if not ok then self:complain(problem)end
			end
		end
	end)
end
function World:inside(item)
	for _,folder in pairs(self.folders or {})do if folder:IsAncestorOf(item)and self.room:IsAncestorOf(item)then return true end end
	return false
end
-- What left the room gets its own looks back; if it returns it is painted afresh.
function World:sweep()
	local gone={}
	for item in pairs(self.surfaces)do if not self:inside(item)then table.insert(gone,item)end end
	for _,item in ipairs(gone)do World.restore(self.surfaces,item)end
end
function World:watch(folder)
	if folder.Name~="World"and folder.Name~="WaterFlow"or self.folders[folder.Name]==folder then return end
	self.folders[folder.Name]=folder
	table.insert(self.roomLinks,folder.DescendantAdded:Connect(function(item)self:queue(item)end))
	table.insert(self.roomLinks,folder.DescendantRemoving:Connect(function()self:queue(nil)end))
	for _,item in ipairs(folder:GetDescendants())do
		local ok,problem=pcall(self.paint,self,item)
		if not ok then self:complain(problem)end
	end
end
function World:bind(room)
	if self.room==room then return end
	for _,link in ipairs(self.roomLinks)do link:Disconnect()end
	table.clear(self.roomLinks);table.clear(self.late)
	self:restoreAll(self.surfaces)
	self.room,self.folders=room,{}
	self:dropAdditions()
	if not room then return end
	table.insert(self.roomLinks,room.ChildAdded:Connect(function(child)self:watch(child)end))
	table.insert(self.roomLinks,room.ChildRemoved:Connect(function(child)
		if self.folders[child.Name]==child then self.folders[child.Name]=nil;self:queue(nil)end
	end))
	for _,child in ipairs(room:GetChildren())do self:watch(child)end
	self:buildAdditions()
end
function World:restoreAll(records)
	local items={}
	for item in pairs(records)do table.insert(items,item)end
	for _,item in ipairs(items)do World.restore(records,item)end
end

-- Additions (AeroAdditions): gone for good this session at budget level 2, and still under Reduced Motion.
function World:buildAdditions()
	if self.added or self.level()>=World.DropLevel then return end
	local ok,added=pcall(self.additions.build,{parent=self.world})
	if not ok then self:complain(added);return end
	self.added=added
	pcall(added.still,self.reduced())
	local turn=self.turn
	local function check()
		if turn~=self.turn or self.added~=added then return end
		if self.level()>=World.DropLevel then self:dropAdditions();return end
		pcall(added.still,self.reduced())
		self.delay(World.Interval,check)
	end
	self.delay(World.Interval,check)
end
function World:dropAdditions()
	local added=self.added
	self.added=nil
	if added then pcall(added.destroy)end
end

function World:enable()
	if self.enabled then return end
	self.enabled=true
	self.turn+=1;self.scheduled=false
	table.insert(self.connections,self.world.ChildAdded:Connect(function(item)if item.Name=="EggDropLounge"then self:bind(item)end end))
	table.insert(self.connections,self.world.ChildRemoved:Connect(function(item)if item==self.room then self:bind(nil)end end))
	table.insert(self.connections,self.switch.treesChanged():Connect(function()self:repaintCrowns()end))
	table.insert(self.connections,self.reducedChanged():Connect(function()if self.added then pcall(self.added.still,self.reduced())end end))
	self.clock.look=self.look
	self.clock.apply(self.clock.now())
	self:bind(self.world:FindFirstChild("EggDropLounge"))
end
function World:disable()
	if not self.enabled then return end
	self.enabled=false
	self.turn+=1;self.scheduled=false
	for _,link in ipairs(self.connections)do link:Disconnect()end
	table.clear(self.connections)
	self:bind(nil)
	if self.clock.look==self.look then self.clock.look=nil end
	self:restoreAll(self.light)
	-- The clock's own look again at once (lamps, backdrop clouds, and the cycle's hour if it is running).
	self.clock.apply(self.clock.now())
end
function World:repaintCrowns()
	if not self.enabled or not self.room then return end
	local meshes=self.folders.World
	if not meshes then return end
	for _,part in ipairs(meshes:GetChildren())do
		if not part:IsA("BasePart")or Values.kind(part.Name)~=Values.CrownKind then continue end
		for _,child in ipairs(part:GetChildren())do World.restore(self.surfaces,child)end
		World.restore(self.surfaces,part)
		local ok,problem=pcall(self.paintCrown,self,part)
		if not ok then self:complain(problem)end
	end
end
function World:destroy()
	if self.destroyed then return end
	self.destroyed=true
	if self.link then self.link:Disconnect();self.link=nil end
	self:sync()
end
return World
