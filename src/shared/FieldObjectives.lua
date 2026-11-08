local Config=require(script.Parent.BoardConfig)
local Objectives={Order=table.freeze({"bank_pair","creek_crossing","lantern_chain"})}
local names={bank_pair="Bank pair",creek_crossing="Creek crossing",lantern_chain="Lantern chain"}
local function frozenCopy(value)
	if type(value)~="table"then return value end
	local copy={};for key,item in pairs(value)do copy[key]=frozenCopy(item)end;return table.freeze(copy)
end
Objectives.copy=frozenCopy
function Objectives.next(completedFieldCount)
	return Objectives.Order[(completedFieldCount or 0)%#Objectives.Order+1] -- Zero based.
end
function Objectives.create(id,seed)
	assert(names[id],"Unknown field template")
	assert(type(seed)=="number"and seed%1==0 and seed>=1 and seed<=2147483646,"Invalid field seed")
	local function bank(side)
		return {kind=if side<0 then "left"else "right",min=if side<0 then -Config.Width/2 else 2.6,max=if side<0 then -2.6 else Config.Width/2}
	end
	local goals,dynamics
	if id=="bank_pair"then
		goals={{id="left_iii",kind="merge",minTier=3,zone=bank(-1),target=1},{id="right_iii",kind="merge",minTier=3,zone=bank(1),target=1}}
		dynamics={id="classic",label="Classic banks",kick=6,bounceScale=1}
	elseif id=="creek_crossing"then
		-- Independent deterministic derivation never consumes the queue RNG.
		local side=if seed%2==0 then -1 else 1
		goals={{id="center_ii",kind="merge",tier=2,zone={kind="center",min=-1.6,max=1.6},target=1},
			{id="far_iii",kind="merge",minTier=3,zone=bank(side),target=1}}
		dynamics={id="soft",label="Soft banks",kick=4.5,bounceScale=.75}
	else
		goals={{id="two_merges",kind="count",zone={kind="any"},target=2},{id="two_linked",kind="chain",zone={kind="any"},target=2}}
		dynamics={id="springy",label="Springy banks",kick=7.5,bounceScale=1}
	end
	return frozenCopy({id=id,seed=seed,title=names[id],dynamics=dynamics,goals=goals})
end
function Objectives.simulationOptions(descriptor,presetName)
	local preset=assert(Config.Presets[presetName],"Unknown dynamics preset")
	return frozenCopy({seed=descriptor.seed,starter={},contactGate=true,kick=descriptor.dynamics.kick,
		bounce=preset.bounce*descriptor.dynamics.bounceScale})
end
function Objectives.validatePublic(value,sequence)
	local function integer(n,minimum,maximum)return type(n)=="number"and n==n and n%1==0 and n>=minimum and n<=maximum end
	local function finite(n)return type(n)=="number"and n==n and math.abs(n)<math.huge end
	if type(value)~="table"or value.sequence~=sequence or not names[value.templateId]
		or not integer(value.sequence,1,2147483647)or value.title~=names[value.templateId]
		or type(value.goals)~="table"or #value.goals~=2 or type(value.dynamics)~="table"
		or not({classic=true,soft=true,springy=true})[value.dynamics.id]or type(value.dynamics.label)~="string"
		or not integer(value.step,1,3)or not integer(value.progress,0,2)or not integer(value.target,0,2)
		or type(value.complete)~="boolean"then return false end
	local dynamics={bank_pair="classic",creek_crossing="soft",lantern_chain="springy"}
	if value.dynamics.id~=dynamics[value.templateId]then return false end
	for _,goal in ipairs(value.goals)do
		if type(goal)~="table"or type(goal.id)~="string"or not({merge=true,count=true,chain=true})[goal.kind]
			or not integer(goal.target,1,2)or type(goal.zone)~="table"
			or not({left=true,right=true,center=true,any=true})[goal.zone.kind]
			or goal.tier~=nil and not integer(goal.tier,1,5)or goal.minTier~=nil and not integer(goal.minTier,1,5)
			or goal.tier~=nil and goal.minTier~=nil then return false end
		if goal.zone.kind~="any"and(not finite(goal.zone.min)or not finite(goal.zone.max)or goal.zone.min>goal.zone.max)then return false end
		if goal.kind=="merge"then
			if goal.zone.kind=="any"or(goal.tier==nil and goal.minTier==nil)then return false end
		elseif goal.zone.kind~="any"or goal.tier~=nil or goal.minTier~=nil or goal.zone.min~=nil or goal.zone.max~=nil then return false end
	end
	local first,second=value.goals[1],value.goals[2]
	if value.templateId=="bank_pair"then
		if first.id~="left_iii"or second.id~="right_iii"or first.kind~="merge"or second.kind~="merge"
			or first.minTier~=3 or second.minTier~=3 or first.zone.kind~="left"or second.zone.kind~="right"then return false end
	elseif value.templateId=="creek_crossing"then
		if first.id~="center_ii"or second.id~="far_iii"or first.kind~="merge"or second.kind~="merge"
			or first.tier~=2 or second.minTier~=3 or first.zone.kind~="center"or(second.zone.kind~="left"and second.zone.kind~="right")then return false end
	else
		if first.id~="two_merges"or second.id~="two_linked"or first.kind~="count"or second.kind~="chain"then return false end
	end
	if value.step==3 then return value.complete and value.progress==0 and value.target==0 end
	return not value.complete and value.target==value.goals[value.step].target and value.progress<value.target
end
return table.freeze(Objectives)
