-- Pure authoritative charge -> cumulative mystery-egg stage and quiet cue gating.
local Progress={Pitches=table.freeze({1,1.05946,1.12246})}
function Progress.stage(charge,threshold)
	if type(threshold)~="number"or threshold~=threshold or threshold<=0 or threshold==math.huge then return 0 end
	charge=if type(charge)=="number"and charge==charge then math.max(0,charge)else 0
	if charge>=threshold then return 3 end
	if charge>=math.ceil(2*threshold/3)then return 2 end
	if charge>=math.ceil(threshold/3)then return 1 end
	return 0
end
function Progress.lesson(stage,drops)
	return if stage>=2 then "onboarding.welcome.more"elseif(drops or 0)>0 or stage>0 then "onboarding.welcome.match"else "onboarding.welcome.friend"
end
function Progress.new()return {generation=nil,charge=nil,stage=0}end
function Progress.update(state,generation,charge,threshold,active)
	charge=if type(charge)=="number"and charge==charge then math.max(0,charge)else 0
	local stage=Progress.stage(charge,threshold)
	local cue=active==true and state.generation==generation and state.charge~=nil and charge>state.charge and stage>state.stage
	state.generation,state.charge,state.stage=generation,charge,stage
	return stage,if cue then math.clamp(stage,1,3)else nil
end
-- Best-effort host replies can be reordered by concurrent duplicate requests.
-- Caller first validates the current board RunSequence. Applied is terminal for
-- that generation, independent of rebuilding its GUI or a late Retrying reply.
function Progress.reply(state,generation,status)
	if status~="Applied"and status~="Retrying"and status~="Rejected"then return nil end
	if state.generation~=generation then state.generation,state.applied=generation,false end
	if state.applied then return nil end
	if status=="Applied"then state.applied=true end
	return status=="Retrying"
end
return table.freeze(Progress)
