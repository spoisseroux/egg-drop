-- Frutiger Aero "Medium" in the garden (WORLD-PLAN-2026-11-22 section 9; values in Shared.WorldAero). Client only and
-- looks only: nothing replicates, and no CFrame, size, collision, remote or save is touched. Off (Aero.on) nothing is
-- created, written or connected but the switch signal, and the garden is the one the server built.
--
-- One writer per property:
--   Lighting, its effects, the sky and the backdrop clouds   HollowClock, which paints self.look instead of WorldDusk
--                                                            while it is Clock.look (its own 5 s pass, no new one)
--   world meshes, water layers, beams and spray colours      this file, once per item
--   with the garden hour on: the same light, glow_warm       HollowClock, through self.look.paint(values) (GardenHour.look)
--   colour and the AeroClouds                                at its pace; off, the light, glow and clouds go back to
--                                                            WorldAero's at once
-- Never touched here: WorldMotion's CFrames, texture offsets, emitter switches and pulsing Transparency; the care
-- machine's status colours (GardenCareClient); the wind's bushes.
-- Every original is kept on the first write and put back exactly when the layer goes off, the room goes, or the item
-- leaves it. After the pass only arrivals are painted; the one timer (additions: frame budget, Reduced Motion) is 5 s.
local GuiService=game:GetService("GuiService")
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Shared=ReplicatedStorage:WaitForChild("Shared")
local Values=require(Shared:WaitForChild("WorldAero"))
local Hour=require(Shared:WaitForChild("GardenHour"))
local Additions=require(script.Parent.AeroAdditions)
local Kit=require(script.Parent.AeroKit)

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
-- Puts an item back. What cannot be put back stays on record (the next restore tries again); returns the problem.
function World.restore(records,item)
	local record=records[item]
	if not record then return nil end
	local problem
	for key,value in pairs(table.clone(record.was))do
		local ok,why=pcall(put,item,key,value)
		if ok then record.was[key],record.now[key],record.want[key]=nil,nil,nil else problem=why end
	end
	local parked=record.parked
	record.parked={}
	for _,child in ipairs(parked)do
		local ok,why=pcall(function()child.Parent=item end)
		if not ok then table.insert(record.parked,child);problem=why end
	end
	if next(record.was)==nil and #record.parked==0 then records[item]=nil end
	return problem
end

-- options (fixtures): world, lighting, data, clock {look, now, apply}, switch {on, changed, trees, treesChanged},
-- level, reduced, reducedChanged, camera, defer, delay, additions, warn. The game passes only clock.
function World.new(options)
	options=options or {}
	local self=setmetatable({world=options.world or workspace,lighting=options.lighting or game:GetService("Lighting"),
		clock=options.clock,enabled=false,turn=0,writes=0,light={},surfaces={},sky={},glows={},refused=setmetatable({},{__mode="k"}),
		connections={},roomLinks={},folderLinks={},folders={},late={}},World)
	-- The sky's clouds the additions made (AeroAdditions.clouds); only the garden hour moves their colour.
	self.clouds=options.clouds or function()
		local terrain=workspace:FindFirstChildOfClass("Terrain")
		local clouds=terrain and terrain:FindFirstChild("AeroClouds")
		return if clouds and clouds:IsA("Clouds")then clouds else nil
	end
	self.data=options.data or require(Shared:WaitForChild("WorldV7Data"))
	self.switch=options.switch or require(Shared:WaitForChild("Aero"))
	self.level=options.level or require(script.Parent.AliveBudget).level
	-- Where the camera is, for the waterfall layers' distance gate (checked on the additions' timer).
	self.camera=options.camera or function()
		local camera=workspace.CurrentCamera
		return camera and camera.CFrame.Position
	end
	self.defer,self.delay=options.defer or task.defer,options.delay or task.delay
	self.additions=options.additions or Additions
	-- The world kit (AeroKit): split crowns, falls sheets and rocks. Its templates exist only where the ceiling passes.
	self.kit=options.kit or Kit
	self.hidden={} -- what the kit hides (merged crowns and falls, Tumble sheet beams): only the kit's drop restores it
	self.kitData=options.kitData or function()
		local module=Shared:FindFirstChild("WorldAeroKit")
		return module and require(module)
	end
	self.templates=options.templates or function()return ReplicatedStorage:FindFirstChild(Kit.Templates)end
	self.spawn=options.spawn or task.spawn
	-- true when every template's mesh (and texture) loaded; yields.
	self.preload=options.preload or function(folder)
		local good=true
		game:GetService("ContentProvider"):PreloadAsync(folder:GetChildren(),function(_,status)
			if status~=Enum.AssetFetchStatus.Success then good=false end
		end)
		return good
	end
	self.warn=options.warn or warn
	self.reducedChanged=options.reducedChanged or function()return GuiService:GetPropertyChangedSignal("ReducedMotionEnabled")end
	self.reduced=options.reduced or function()
		local boards,player=ReplicatedStorage:FindFirstChild("EggDropBoards"),Players.LocalPlayer
		local board=boards and player and boards:FindFirstChild(tostring(player.UserId))
		return GuiService.ReducedMotionEnabled or board~=nil and board:GetAttribute("ReducedEffects")==true
	end
	-- What HollowClock paints while the layer is on (Clock.look). paint(values): the garden hour's look, nil for WorldAero.
	self.look={Hour=Values.Hour,Daylight=Values.Daylight,CloudColor=Values.CloudColor,
		paint=function(values)self:paintLight(values)end,reduced=function()return self.reduced()==true end}
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
	return ok
end
function World:restoreItem(records,item)
	local problem=World.restore(records,item)
	if problem~=nil then self:complain(problem)end
end

-- Light: called by HollowClock only. Effects that are not there (yet) are skipped; its next pass finds them.
-- `values`: the garden hour's look (GardenHour.look: Lighting, Atmosphere, Grade, Bloom, SunRays, Sky, FaceSet,
-- GlowWarm, Clouds); nil is WorldAero's, and exactly the pass before the hour. A hold's tables are frozen and equal,
-- so a 5 s pass over one writes nothing.
function World:paintLight(values)
	if not self.enabled then return end
	local look=values or Values
	local lighting=self.lighting
	-- An effect that was replaced or destroyed is let go (with its own looks, where it still takes them).
	for _,item in ipairs(self:items(self.light))do
		if item~=lighting and item.Parent~=lighting then World.restore(self.light,item);self.light[item]=nil end
	end
	local function all(item,values)
		if not item then return end
		for key,value in pairs(values)do self:set(self.light,item,key,value)end
	end
	local function named(name,class)
		local item=lighting:FindFirstChild(name)
		return item and item:IsA(class)and item or nil
	end
	all(lighting,look.Lighting)
	all(lighting:FindFirstChildOfClass("Atmosphere"),look.Atmosphere)
	all(named("SproutHollowGrade","ColorCorrectionEffect"),look.Grade)
	all(named("HollowBloom","BloomEffect"),look.Bloom)
	all(named("HollowSunRays","SunRaysEffect"),look.SunRays)
	local sky=named("WorldSky","Sky")
	local faces=if values then Hour.skyFaces(values.FaceSet,self.data)else Values.skyFaces(self.data)
	all(sky,look.Sky)
	if sky and faces then
		for _,face in ipairs({"Bk","Dn","Ft","Lf","Rt","Up"})do self:set(self.light,sky,"Skybox"..face,faces[face])end
		self:set(self.light,sky,"@FaceSet",look.FaceSet)
	end
	self:paintGlow(values and values.GlowWarm)
	self:paintClouds(values and values.Clouds)
end
-- glow_warm meshes: the hour's colour while it is on; once back to WorldAero's when it goes off; else nothing.
function World:paintGlow(color)
	if color==nil and self.glow==nil then return end
	self.glow=color
	local value=color or Values.Surfaces.glow_warm.Color
	for part in pairs(self.glows)do
		if self.surfaces[part]then self:set(self.surfaces,part,"Color",value)else self.glows[part]=nil end
	end
end
-- The AeroClouds (Cover, Density, Color): the hour's while it is on; their own back when it goes off or they go.
function World:paintClouds(clouds)
	if not clouds and next(self.sky)==nil then return end
	local item=self.clouds()
	for each in pairs(table.clone(self.sky))do
		if each.Parent==nil then self.sky[each]=nil elseif each~=item or not clouds then self:restoreItem(self.sky,each)end
	end
	if not clouds or not item then return end
	for key,value in pairs(clouds)do self:set(self.sky,item,key,value)end
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
		elseif key=="Color"and kind=="glow_warm"then
			-- The garden hour's glow (paintGlow) if it is on.
			self.glows[part]=true
			self:set(self.surfaces,part,key,self.glow or value)
		else
			self:set(self.surfaces,part,key,value)
		end
	end
end
function World:paintCrown(part)
	local crown=Values.Crowns[self.switch.trees()]
	if not crown or self.refused[part]then return end
	local skins={}
	for _,child in ipairs(part:GetChildren())do if child:IsA("SurfaceAppearance")then table.insert(skins,child)end end
	if not crown.Flat then
		for _,child in ipairs(skins)do self:set(self.surfaces,child,"Color",crown.Tint)end
		return
	end
	-- All or nothing: a crown that will not go flat keeps its own leaves until the next switch.
	-- A crown with its own map (lime) shows it on a white part; a MeshPart is needed for a TextureID, else flat colour.
	local mapped=crown.Texture~=nil and part:IsA("MeshPart")
	local ok=not part:IsA("MeshPart")or self:set(self.surfaces,part,"TextureID",if mapped then crown.Texture else "")
	ok=ok and self:set(self.surfaces,part,"Material",crown.Material)
	ok=ok and self:set(self.surfaces,part,"Color",if mapped then crown.TextureColor or crown.Color else crown.Color)
	for _,child in ipairs(skins)do
		if not ok then break end
		-- Only its Parent moves, and only here: the same instance goes back.
		local record=entry(self.surfaces,part)
		local moved,why=pcall(function()child.Parent=nil end)
		if moved then table.insert(record.parked,child);self.writes+=1 else ok=false;self:complain(why)end
	end
	if not ok then
		self.refused[part]=true
		self:restoreItem(self.surfaces,part)
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
		-- A merged part or sheet beam that arrived late (streaming, a beam added after its anchor) is hidden too.
		if self.built then
			local ok,problem=pcall(self.hideMerged,self)
			if not ok then self:complain(problem)end
		end
	end)
end
function World:inside(item)
	for _,folder in pairs(self.folders)do if folder:IsAncestorOf(item)and self.room:IsAncestorOf(item)then return true end end
	return false
end
-- What left the room gets its own looks back; if it returns it is painted afresh.
function World:sweep()
	local gone={}
	for item in pairs(self.surfaces)do if not self:inside(item)then table.insert(gone,item)end end
	for _,item in ipairs(gone)do self:restoreItem(self.surfaces,item)end
end
function World:watch(folder)
	if folder.Name~="World"and folder.Name~="WaterFlow"and folder.Name~=Kit.Folder or self.folders[folder.Name]==folder then return end
	-- A new folder takes over from the one before it: that one's items get their own looks back.
	local old=self.folders[folder.Name]
	if old then self:unwatch(old);self:queue(nil)end
	self:unwatch(folder)
	self.folders[folder.Name]=folder
	self.folderLinks[folder]={
		folder.DescendantAdded:Connect(function(item)self:queue(item)end),
		folder.DescendantRemoving:Connect(function()self:queue(nil)end),
	}
	for _,item in ipairs(folder:GetDescendants())do
		local ok,problem=pcall(self.paint,self,item)
		if not ok then self:complain(problem)end
	end
	-- A new World or WaterFlow under a standing kit: hide what the kit replaces in it too.
	if self.built and folder.Name~=Kit.Folder then
		local ok,problem=pcall(self.hideMerged,self)
		if not ok then self:complain(problem)end
	end
end
function World:unwatch(folder)
	for _,link in ipairs(self.folderLinks[folder]or{})do link:Disconnect()end
	self.folderLinks[folder]=nil
end
function World:bind(room)
	if self.room==room then return end
	for folder in pairs(table.clone(self.folderLinks))do self:unwatch(folder)end
	for _,link in ipairs(self.roomLinks)do link:Disconnect()end
	table.clear(self.roomLinks);table.clear(self.late)
	self:restoreAll(self.surfaces)
	self:dropKit()
	table.clear(self.glows)
	table.clear(self.refused)
	self.room,self.folders=room,{}
	self:dropAdditions()
	if not room then return end
	table.insert(self.roomLinks,room.ChildAdded:Connect(function(child)self:watch(child)end))
	table.insert(self.roomLinks,room.ChildRemoved:Connect(function(child)
		self:unwatch(child)
		if self.folders[child.Name]~=child then return end
		self.folders[child.Name]=nil;self:queue(nil)
		local left=room:FindFirstChild(child.Name)
		if left then self:watch(left)end
	end))
	for _,child in ipairs(room:GetChildren())do self:watch(child)end
	self:buildKit()
	self:buildAdditions()
end
function World:items(records)
	local items={}
	for item in pairs(records)do table.insert(items,item)end
	return items
end
function World:restoreAll(records)
	for _,item in ipairs(self:items(records))do self:restoreItem(records,item)end
end

-- Additions (AeroAdditions): gone for good this session at budget level 2, and still under Reduced Motion. The
-- waterfall layers among them also follow the level, the camera and the clock's daylight (update).
function World:tuneAdditions(added)
	pcall(added.still,self.reduced())
	if not added.update then return end
	local ok,problem=pcall(function()
		added.update({level=self.level(),camera=self.camera(),daylight=self.clock and self.clock.lastDaylight or Values.Daylight})
	end)
	if not ok then self:complain(problem)end
end
function World:buildAdditions()
	if self.added or self.level()>=World.DropLevel then return end
	local ok,added=pcall(self.additions.build,{parent=self.world,data=self.data,kit=self.built and self.built.data})
	if not ok then self:complain(added);return end
	self.added=added
	self:tuneAdditions(added)
	local turn=self.turn
	local function check()
		if turn~=self.turn or self.added~=added then return end
		if self.level()>=World.DropLevel then self:dropAdditions();return end
		self:tuneAdditions(added)
		self.delay(World.Interval,check)
	end
	self.delay(World.Interval,check)
end
function World:dropAdditions()
	local added=self.added
	self.added=nil
	if added then pcall(added.destroy)end
end

-- The world kit: built after the room's folders are watched (so its parts are painted as they arrive), then the merged
-- meshes and beams it replaces are hidden in the same step, so no frame shows a garden without trees. Dropped with the
-- room, Aero off or budget level 2: hidden things back first, then the kit goes, in one step. A kit that cannot build
-- (no templates: not this place; no data) leaves the merged garden as it is.
function World:hideMerged()
	local built,room=self.built,self.room
	if not(built and room)then return end
	-- The folders this layer watches: a new World that arrived before the old one left is the one that counts.
	local meshes=self.folders.World
	for _,name in ipairs(built.data.hides or {})do
		local part=meshes and meshes:FindFirstChild(name)
		if part and part:IsA("BasePart")then self:set(self.hidden,part,"Transparency",1)end
	end
	local flow=self.folders.WaterFlow
	for _,beam in ipairs(flow and flow:GetDescendants()or {})do
		if beam:IsA("Beam")and Values.Waterfall.Tiers[beam.Name]then self:set(self.hidden,beam,"Enabled",false)end
	end
end
-- The kit's meshes are fetched first (PreloadAsync on the templates): nothing is hidden until every one has loaded, so a
-- join never shows a bare garden, and a mesh that fails (moderated, offline) leaves the merged garden as it is. The
-- additions are rebuilt once the kit stands, so the falls layers fit its sheets.
function World:buildKit()
	if self.built or not self.room or self.level()>=World.DropLevel then return end
	-- One fetch per turn and room; a new room or a new switch turn starts its own.
	local loading=self.kitLoading
	if loading and loading.turn==self.turn and loading.room==self.room then return end
	local templates=self.templates()
	local ok,data=pcall(self.kitData)
	if not(templates and ok and data)then return end
	local turn,room=self.turn,self.room
	local token={turn=turn,room=room}
	self.kitLoading=token
	self.spawn(function()
		local fetched,loaded=pcall(self.preload,templates)
		if self.kitLoading==token then self.kitLoading=nil end
		if turn~=self.turn or room~=self.room or self.built or not self.enabled then return end
		if not(fetched and loaded==true)then self:complain(if fetched then "kit meshes did not load" else loaded);return end
		if self.level()>=World.DropLevel then return end
		self:standKit(data,templates,turn)
	end)
end
function World:standKit(data,templates,turn)
	local ok,built=pcall(self.kit.build,{data=data,templates=templates,parent=self.room})
	if not ok then self:complain(built);return end
	self.built=built
	self:watch(built.folder)
	local hid,problem=pcall(self.hideMerged,self)
	if not hid then self:complain(problem);self:dropKit();return end
	if self.added then self:dropAdditions();self:buildAdditions()end
	local function check()
		if turn~=self.turn or self.built~=built then return end
		if self.level()>=World.DropLevel then self:dropKit();return end
		self.delay(World.Interval,check)
	end
	self.delay(World.Interval,check)
end
function World:dropKit()
	self:restoreAll(self.hidden)
	local built=self.built
	self.built=nil
	if not built then return end
	if self.folders[Kit.Folder]==built.folder then
		self:unwatch(built.folder)
		self.folders[Kit.Folder]=nil
		for _,item in ipairs(built.folder:GetDescendants())do self:restoreItem(self.surfaces,item)end
	end
	built.destroy()
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
	self.glow=nil
	self:paintClouds(nil)
	-- The clock's own look again at once (lamps, backdrop clouds, and the cycle's hour if it is running).
	self.clock.apply(self.clock.now())
end
function World:repaintCrowns()
	if not self.enabled or not self.room then return end
	table.clear(self.refused)
	local parts={}
	for _,name in ipairs({"World",Kit.Folder})do
		local folder=self.folders[name]
		if folder then for _,part in ipairs(folder:GetChildren())do table.insert(parts,part)end end
	end
	for _,part in ipairs(parts)do
		if not part:IsA("BasePart")or Values.kind(part.Name)~=Values.CrownKind then continue end
		for _,child in ipairs(part:GetChildren())do self:restoreItem(self.surfaces,child)end
		self:restoreItem(self.surfaces,part)
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
