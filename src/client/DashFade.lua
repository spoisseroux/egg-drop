-- Garden Dash see-through (WORLD-PLAN-2026-11-22 section 2, camera rules): a crown or pillar between the race camera and
-- the pet goes 75% clear on this screen only, and comes back. Owner-client presentation: LocalTransparencyModifier,
-- never the replicated Transparency. Every part it touched gets its own value back when the view is clear again and
-- on release() (every way out of a race).
--   * solid things answer rays: a look every Fade.Every seconds, against the named meshes alone, up to Fade.Casts deep;
--   * the crowns do not (nor the blossom), so where they cross the view is measured offline from the world meshes
--     (scripts/measure_dash_camera.py) and kept here as stretches of the course.
-- The island's crowns are one merged mesh, so they fade together. Under the Aero look the kit (AeroKit) hides that mesh
-- and shows the same leaves as split parts: every kit part whose name ends in the zone's material fades with it.
local Fade={};Fade.__index=Fade
Fade.Clear=.75
Fade.Seconds=.18
Fade.Every=.1
Fade.Hold=.3 -- a mesh stays clear this long after the last time it was in the way
Fade.Lounge="EggDropLounge"
Fade.Casts=3
-- Only what measure_dash_camera.py reports and what is one thing by itself: the caps of the bridge's rails. Never a mesh
-- that also holds ground or kerbs (the bridge deck, the rocks, W7_Architecture).
Fade.Solids=table.freeze({"W7_Bridge__palette"})
-- Course version 2: 4900..5050 on Main, plus a stud and a half either side to have it clear on arrival.
Fade.Zones=table.freeze({table.freeze({mesh="W7_Vegetation__foliage",stones=false,from=4750,to=5200})})

local function world()
	local lounge=workspace:FindFirstChild(Fade.Lounge)
	return lounge and lounge:FindFirstChild("World")
end
local function kit()
	local lounge=workspace:FindFirstChild(Fade.Lounge)
	return lounge and lounge:FindFirstChild("AeroKit")
end
-- options (specs): world() -> folder, kit() -> folder or nil, cast(origin, direction, solids) -> part or nil
function Fade.new(options)
	options=options or {}
	return setmetatable({world=options.world or world,kit=options.kit or kit,cast=options.cast,records={},wait=0},Fade)
end
-- "W7_Vegetation__foliage" -> "__foliage": the kit parts that hold the same leaves end in it (W7_Kit_Crown_Round__foliage).
local function suffix(mesh)return string.match(mesh,"(__[%w_]+)$")end
-- The meshes, looked up by name on every look: they may stream in, or be replaced, during a race.
function Fade:find()
	local folder=self.world()
	self.ready=folder~=nil
	if not folder then
		if self.solids then table.clear(self.solids);table.clear(self.crowns)end
		return
	end
	self.solids,self.crowns=self.solids or {},self.crowns or {}
	table.clear(self.solids)
	for _,name in ipairs(Fade.Solids)do
		local part=folder:FindFirstChild(name)
		if part then table.insert(self.solids,part)end
	end
	local split=self.kit()
	for index,zone in ipairs(Fade.Zones)do
		local list=self.crowns[index]or {}
		table.clear(list)
		local merged=folder:FindFirstChild(zone.mesh)
		if merged then table.insert(list,merged)end
		local tail=suffix(zone.mesh)
		if split and tail then
			for _,part in ipairs(split:GetChildren())do
				if part:IsA("BasePart")and string.sub(part.Name,1,7)=="W7_Kit_"and string.sub(part.Name,-#tail)==tail then table.insert(list,part)end
			end
		end
		self.crowns[index]=list
	end
end
-- Everything solid between the eye and the pet, nearest first: each cast leaves out what was already hit.
function Fade:look(eye,way)
	local left=self.solids
	for _=1,Fade.Casts do
		if #left==0 then return end
		local part
		if self.cast then part=self.cast(eye,way,left)
		else
			if not self.params then
				self.params=RaycastParams.new()
				self.params.FilterType=Enum.RaycastFilterType.Include
			end
			self.params.FilterDescendantsInstances=left
			local hit=workspace:Raycast(eye,way,self.params)
			part=hit and hit.Instance
		end
		if not part then return end
		self:blocked(part)
		left=table.clone(left)
		local at=table.find(left,part)
		if not at then return end
		table.remove(left,at)
	end
end
function Fade:blocked(part)
	local record=self.records[part]
	if not record then
		record={prior=part.LocalTransparencyModifier,share=0,hold=0}
		self.records[part]=record
	end
	record.hold=Fade.Hold
end
-- One frame: from the eye to the pet, which is at cs (onStones as Sim.spot).
function Fade:step(dt,eye,pet,cs,onStones)
	self.wait-=dt
	local look=self.wait<=0
	if look then
		self.wait=Fade.Every
		self:find()
	end
	if self.ready then
		for index,zone in ipairs(Fade.Zones)do
			local list=self.crowns[index]
			if list and zone.stones==onStones and cs>=zone.from and cs<=zone.to then
				for _,crown in ipairs(list)do self:blocked(crown)end
			end
		end
		if look then self:look(eye,pet-eye)end
	end
	for part,record in pairs(self.records)do
		record.hold-=dt
		local want=if record.hold>0 then 1 else 0
		local move=dt/Fade.Seconds
		local share=if want>record.share then math.min(want,record.share+move)else math.max(want,record.share-move)
		if share~=record.share then
			record.share=share
			if part.Parent then part.LocalTransparencyModifier=record.prior+(math.max(record.prior,Fade.Clear)-record.prior)*share end
		end
		if share==0 and want==0 then self:restore(part)end
	end
end
function Fade:restore(part)
	local record=self.records[part]
	if not record then return end
	self.records[part]=nil
	pcall(function()part.LocalTransparencyModifier=record.prior end)
end
function Fade:release()
	for part in pairs(table.clone(self.records))do self:restore(part)end
	self.ready,self.solids,self.crowns,self.params,self.wait=nil,nil,nil,nil,0
end
return Fade
