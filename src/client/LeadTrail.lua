-- The lead's trail (onboarding v3 brief section 1): the one place the lead lays prints, so the "glow steps" trail
-- (switch `trail2`, built beside this) can take over without this module changing. When a trail offers a lead mode
-- (`trail:leadBy(petModel, target)`: the prints are the Bear's own, under its feet) that is used; otherwise today's
-- Show me trail (ThingsTrail:start) from the player to the nest. Never edits either trail.
--   LeadTrail.new({things = the ThingsTrail, leaders = function() -> {trail, ...} (optional: trails that may lead)})
--   :lead(model, target) -> bool   prints that follow the leading pet (or today's, to the target)
--   :show(target) -> bool          today's prints from the player (no leader: the pet is stowed, or the lead is parked)
--   :active() -> bool, :stop()
local Adapter={};Adapter.__index=Adapter
function Adapter.new(deps)return setmetatable({d=deps or {},by=nil,mode=nil},Adapter)end
-- Pure: the first trail that can lead (has a leadBy method), or nil.
function Adapter.leader(list)
	for _,trail in ipairs(list or {})do
		if type(trail)=="table"and type(trail.leadBy)=="function"then return trail end
	end
	return nil
end
function Adapter:candidates()
	local list={}
	if self.d.leaders then
		local ok,more=pcall(self.d.leaders)
		if ok and type(more)=="table"then for _,t in ipairs(more)do table.insert(list,t)end end
	end
	if self.d.things then table.insert(list,self.d.things)end
	return list
end
function Adapter:lead(model,target)
	local leader=if model~=nil then Adapter.leader(self:candidates())else nil
	if leader then
		local ok,result=pcall(leader.leadBy,leader,model,target)
		if ok and result~=false then self.by,self.mode=leader,"lead";return true end
	end
	return self:show(target)
end
function Adapter:show(target)
	local things=self.d.things
	if not things then return false end
	if self.mode=="lead"and self.by~=things then self:stop()end
	local ok,result=pcall(things.start,things,target)
	self.by,self.mode=things,"show"
	return ok and result==true
end
function Adapter:active()
	local by=self.by
	if not by then return false end
	local ok,on=pcall(function()
		if self.mode=="lead"and type(by.leading)=="function"then return by:leading()end
		if type(by.active)=="function"then return by:active()end
		return by.active==true
	end)
	return ok and on==true
end
function Adapter:stop()
	local by,mode=self.by,self.mode
	self.by,self.mode=nil,nil
	if not by then return end
	pcall(function()
		if mode=="lead"and type(by.stopLead)=="function"then by:stopLead()
		elseif type(by.stop)=="function"then by:stop("lead")end
	end)
end
return Adapter
