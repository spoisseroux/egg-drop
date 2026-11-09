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
	return frozenCopy({id=id,seed=seed,title=names[id],dynamics=dynamics,goals=goals})
end
function Objectives.simulationOptions(descriptor,presetName)
	local preset=assert(Config.Presets[presetName],"Unknown dynamics preset")
	return frozenCopy({seed=descriptor.seed,starter={},contactGate=true,kick=descriptor.dynamics.kick,
		bounce=preset.bounce*descriptor.dynamics.bounceScale})
end
function Objectives.validatePublic(value,sequence)
	local function integer(n,minimum,maximum)return type(n)=="number"and n==n and n%1==0 and n>=minimum and n<=maximum end
	if type(value)~="table"or value.sequence~=sequence or not names[value.templateId]
		or not integer(value.sequence,1,2147483647)or value.title~=names[value.templateId]
		or type(value.goals)~="table"or #value.goals~=2 or type(value.dynamics)~="table"
		or not({classic=true,soft=true,springy=true})[value.dynamics.id]or type(value.dynamics.label)~="string"
		or not integer(value.step,1,3)or not integer(value.progress,0,2)or not integer(value.target,0,2)
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
 for seed=1,2 do
  local descriptor=Objectives.create(value.templateId,seed)
  if same(value.goals,descriptor.goals)and value.dynamics.id==descriptor.dynamics.id and value.dynamics.label==descriptor.dynamics.label then canonical=true;break end
 end
 if not canonical then return false end
	if value.step==3 then return value.complete and value.progress==0 and value.target==0 end
	return not value.complete and value.target==value.goals[value.step].target and value.progress<value.target
end
return table.freeze(Objectives)
