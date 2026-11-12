local Config=require(script.Parent.BoardConfig)
local Objectives={Order=table.freeze({"bank_pair","creek_crossing","lantern_chain","ripple_relay","bank_bounce","mirror_marks"})}
local names={bank_pair="Bank pair",creek_crossing="Creek crossing",lantern_chain="Lantern chain",ripple_relay="Ripple relay",bank_bounce="Bank bounce",mirror_marks="Mirror marks"}
local function frozenCopy(value)
	if type(value)~="table"then return value end
	local copy={};for key,item in pairs(value)do copy[key]=frozenCopy(item)end;return table.freeze(copy)
end
Objectives.copy=frozenCopy
function Objectives.next(completedFieldCount)
	return Objectives.Order[(completedFieldCount or 0)%#Objectives.Order+1] -- Zero based.
end
-- Hard appends one goal (plan section 1, "Third goal"): templates that already
-- ask for a chain get a tier IV anywhere; the others get a chain of 3.
local chainTemplates={lantern_chain=true,bank_bounce=true}
function Objectives.thirdGoal(id)
	if chainTemplates[id]then return {id="hard_iv",kind="merge",minTier=4,zone={kind="any"},target=1}end
	return {id="hard_chain3",kind="chain",zone={kind="any"},target=3}
end
function Objectives.create(id,seed,heat)
	assert(names[id],"Unknown field template")
	assert(heat==nil or Config.Heat[heat],"Unknown heat")
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
	elseif id=="lantern_chain"then
		goals={{id="two_merges",kind="count",zone={kind="any"},target=2},{id="two_linked",kind="chain",zone={kind="any"},target=2}}
		dynamics={id="springy",label="Springy banks",kick=7.5,bounceScale=1}
 elseif id=="ripple_relay"then
  goals={{id="ripple_two_merges",kind="count",zone={kind="any"},target=2},{id="ripple_center_iii",kind="merge",minTier=3,zone={kind="center",min=-1.6,max=1.6},target=1}}
  dynamics={id="soft",label="Soft banks",kick=4.5,bounceScale=.75}
 elseif id=="bank_bounce"then
  local side=if seed%2==0 then -1 else 1 -- Independent of the ball queue RNG.
  goals={{id="bounce_bank_ii",kind="merge",tier=2,zone=bank(side),target=1},{id="bounce_two_linked",kind="chain",zone={kind="any"},target=2}}
  dynamics={id="springy",label="Springy banks",kick=7.5,bounceScale=1}
 else
  local side=if seed%2==0 then -1 else 1
  goals={{id="mirror_first_ii",kind="merge",tier=2,zone=bank(side),target=1},{id="mirror_opposite_ii",kind="merge",tier=2,zone=bank(-side),target=1}}
  dynamics={id="classic",label="Classic banks",kick=6,bounceScale=1}
	end
	if heat and Config.Heat[heat].goals==3 then table.insert(goals,Objectives.thirdGoal(id))end
	return frozenCopy({id=id,seed=seed,title=names[id],dynamics=dynamics,goals=goals,heat=heat})
end
function Objectives.simulationOptions(descriptor,presetName,heat)
	local preset=assert(Config.Presets[presetName],"Unknown dynamics preset")
	local spec=Config.Heat[heat or descriptor.heat or Config.DefaultHeat]
	return frozenCopy({seed=descriptor.seed,starter={},contactGate=true,kick=descriptor.dynamics.kick,
		bounce=preset.bounce*descriptor.dynamics.bounceScale,bag=spec.bag})
end
function Objectives.validatePublic(value,sequence)
	local function integer(n,minimum,maximum)return type(n)=="number"and n==n and n%1==0 and n>=minimum and n<=maximum end
	if type(value)~="table"or value.sequence~=sequence or not names[value.templateId]
		or not integer(value.sequence,1,2147483647)or value.title~=names[value.templateId]
		or type(value.goals)~="table"or(#value.goals~=2 and #value.goals~=3)or type(value.dynamics)~="table"
		or not({classic=true,soft=true,springy=true})[value.dynamics.id]or type(value.dynamics.label)~="string"
		or not integer(value.step,1,#value.goals+1)or not integer(value.progress,0,3)or not integer(value.target,0,3)
		or type(value.complete)~="boolean"then return false end
 -- The public payload intentionally omits seed. Compare against both canonical
 -- orientations; bounds, IDs, tier, target and dynamics cannot drift independently.
 local function same(a,b)
  if type(a)~=type(b)then return false end
  if type(a)~="table"then return a==b end
  for key,item in pairs(a)do if not same(item,b[key])then return false end end
  for key in pairs(b)do if a[key]==nil then return false end end
  return true
 end
 local canonical=false
 -- Two goals: Easy or Medium (identical goals); three: Hard.
 local heat=if #value.goals==3 then "hard"else nil
 for seed=1,2 do
  local descriptor=Objectives.create(value.templateId,seed,heat)
  if same(value.goals,descriptor.goals)and value.dynamics.id==descriptor.dynamics.id and value.dynamics.label==descriptor.dynamics.label then canonical=true;break end
 end
 if not canonical then return false end
	if value.step==#value.goals+1 then return value.complete and value.progress==0 and value.target==0 end
	return not value.complete and value.target==value.goals[value.step].target and value.progress<value.target
end
return table.freeze(Objectives)
