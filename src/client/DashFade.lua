-- Garden Dash see-through (WORLD-PLAN-2026-11-22 section 2, camera rules): a crown or pillar between the race camera and
-- the pet goes 75% clear on this screen only, and comes back. Owner-client presentation: LocalTransparencyModifier,
-- never the replicated Transparency. Every part it touched gets its own value back when the view is clear again and
-- on release() (every way out of a race).
--   * pillars and trunks answer rays: one short cast every Fade.Every seconds, against those meshes alone;
--   * the crowns do not (nor the blossom), so where they cross the view is measured offline from the world meshes
--     (scripts/measure_dash_camera.py) and kept here as stretches of the course.
-- The island's crowns are one merged mesh, so they fade together until they are exported apart (plan slice 9).
local Fade={};Fade.__index=Fade
Fade.Clear=.75
Fade.Seconds=.18
Fade.Every=.1
Fade.Hold=.3 -- a mesh stays clear this long after the last time it was in the way
Fade.Lounge="EggDropLounge"
Fade.Solids=table.freeze({"W7_Trunks","W7_Architecture","W7_Rotunda","W7_Aqueduct","W7_Stations"})
-- Course version 2: 4900..5050 on Main, plus a stud and a half either side to have it clear on arrival.
Fade.Zones=table.freeze({table.freeze({mesh="W7_Vegetation__foliage",stones=false,from=4750,to=5200})})

function Fade.solid(name)
	for _,prefix in ipairs(Fade.Solids)do
		if string.sub(name,1,#prefix)==prefix then return true end
	end
	return false
end
local function world()
	local lounge=workspace:FindFirstChild(Fade.Lounge)
	return lounge and lounge:FindFirstChild("World")
end
-- options (specs): world() -> folder, cast(origin, direction, solids) -> part or nil
function Fade.new(options)
	options=options or {}
	return setmetatable({world=options.world or world,cast=options.cast,records={},wait=0},Fade)
end
-- The meshes of this race, found once.
function Fade:begin()
	if self.ready then return end
	self.ready=true
	self.solids,self.crowns={},{}
	local folder=self.world()
	if not folder then return end
	for _,part in ipairs(folder:GetChildren())do
		if part:IsA("MeshPart")and Fade.solid(part.Name)then table.insert(self.solids,part)end
	end
	for index,zone in ipairs(Fade.Zones)do self.crowns[index]=folder:FindFirstChild(zone.mesh)end
	if not self.cast and #self.solids>0 then
		local params=RaycastParams.new()
		params.FilterType=Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances=self.solids
		self.params=params
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
	self:begin()
	for index,zone in ipairs(Fade.Zones)do
		local crown=self.crowns[index]
		if crown and zone.stones==onStones and cs>=zone.from and cs<=zone.to then self:blocked(crown)end
	end
	self.wait-=dt
	if self.wait<=0 and #self.solids>0 then
		self.wait=Fade.Every
		local way=pet-eye
		local part
		if self.cast then part=self.cast(eye,way,self.solids)
		else
			local hit=workspace:Raycast(eye,way,self.params)
			part=hit and hit.Instance
		end
		if part then self:blocked(part)end
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
