-- The lead's trail (onboarding v3 brief section 1): the one place the lead lays prints. With glow steps on (switch
-- `trail2`) the Things trail leads: it starts as a guide trail to the nest ({position, name, guide = true}) and then
-- `trail:leadBy(petModel)` swaps the route's prints for the pet's own, under its feet. With trail2 off leadBy refuses
-- (false) and the trail just started is today's Show me trail (ThingsTrail:start) from the player to the nest.
-- Never edits either trail.
--   LeadTrail.new({things = the ThingsTrail, leaders = function() -> {trail, ...} (optional: other trails that may lead)})
--   :lead(model, target) -> bool   the pet's prints (trail2) or today's, to the target
--   :show(target) -> bool          today's prints from the player (no leader: the pet is stowed, or the lead is parked)
--   :hold(on)                      no new prints while on (the pet runs back for a nudge; trail:leadHold)
--   :active() -> bool, :stop()     stop ends a lead first (trail:leadBy(nil)), then the trail
local Adapter={};Adapter.__index=Adapter
function Adapter.new(deps)return setmetatable({d=deps or {},by=nil,mode=nil,started=nil},Adapter)end
-- Pure: the first trail that can lead (has a leadBy method), or nil.
function Adapter.leader(list)
	for _,trail in ipairs(list or {})do
		if type(trail)=="table"and type(trail.leadBy)=="function"then return trail end
	end
	return nil
end
function Adapter:candidates()
	local list={}
	if self.d.things then table.insert(list,self.d.things)end
	if self.d.leaders then
		local ok,more=pcall(self.d.leaders)
		if ok and type(more)=="table"then for _,t in ipairs(more)do table.insert(list,t)end end
	end
	return list
end
local function guided(target)
	local out=table.clone(target or {})
	out.guide=true
	return out
end
function Adapter:lead(model,target)
	local leader=if model~=nil then Adapter.leader(self:candidates())else nil
	if not leader or type(leader.start)~="function"then return self:show(target)end
	self:stop()
	-- leadBy needs a started trail: the guide trail to the nest first, then the pet takes the prints
	local want=guided(target)
	local ok,began=pcall(leader.start,leader,want)
	if not ok or began~=true then return self:show(target)end
	self.by,self.started=leader,want
	local okLead,took=pcall(leader.leadBy,leader,model)
	if okLead and took==true then self.mode="lead";return true end
	-- trail2 off: the trail just started is today's
	self.mode="show"
	return true
end
function Adapter:show(target)
	local things=self.d.things
	if not things then return false end
	self:stop()
	local ok,result=pcall(things.start,things,target)
	self.by,self.mode,self.started=things,"show",target
	return ok and result==true
end
function Adapter:hold(on)
	local by=self.by
	if self.mode~="lead"or not by or type(by.leadHold)~="function"then return end
	pcall(by.leadHold,by,on==true)
end
-- Still ours: a trail that knows its target is ours only while that target is the one we started.
function Adapter:ours()
	local by=self.by
	if not by then return false end
	local target=rawget(by,"target")
	return target==nil or self.started==nil or target==self.started
end
function Adapter:active()
	local by=self.by
	if not by or not self:ours()then return false end
	local ok,on=pcall(function()
		if type(by.active)=="function"then return by:active()end
		return by.active==true
	end)
	return ok and on==true
end
function Adapter:stop()
	local by,mode=self.by,self.mode
	local mine=self:ours()
	self.by,self.mode,self.started=nil,nil,nil
	if not by or not mine then return end -- another trail took it over (Show me elsewhere): never end that one
	pcall(function()
		if mode=="lead"and type(by.leadBy)=="function"then by:leadBy(nil)end
		if type(by.stop)=="function"then by:stop("lead")end
	end)
end
return Adapter
