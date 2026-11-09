-- Pure production-solver experiment. No Workspace/profile/store mutation.
-- Run 24 common seeds x 3 templates x 3 policies, or one template/policy chunk.
local Benchmark={ControlVersion="center-angle-v1"}
local function aimAt(x,tier,Config,y)
 return Config.aimAt(x,y or Config.Tiers[tier].radius)
end
local function chooseAim(policy,sim,field,state,Simulation,Config)
	local tier=Simulation.nextTier(sim)
	if policy=="naive_spread"then return ({.12,.5,.88,.32,.68})[sim.drops%5+1]end
	if policy=="fixed_bank"or policy=="fast_center"then return if policy=="fast_center"then .5 else aimAt(-3.7,tier,Config)end
	local goal=field:objective()
	local desired,zone=0,goal and goal.zone
	if zone and zone.kind=="left"then desired=-3.7
	elseif zone and zone.kind=="right"then desired=3.7
	elseif zone and zone.kind=="center"then
		-- An incoming II cannot make the exact-II objective. Build the next bank
		-- while the I pieces in the same untouched bag make the central II.
		if goal.tier==2 and tier==2 then desired=if field.descriptor.goals[2].zone.kind=="left"then -3.7 else 3.7;zone=nil end
	elseif goal and goal.kind=="chain"and field.goalProgress==1 and state.lastMergeX then
		desired=if state.separatedChain and state.linkAnchorX then state.linkAnchorX+(if state.linkAnchorX<0 then 2.8 else -2.8)else state.lastMergeX
	else
		local left,right=0,0
		for _,egg in ipairs(sim.eggs)do if egg.position.X<0 then left+=2^(egg.tier-1)else right+=2^(egg.tier-1)end end
		desired=if left<=right then -3.7 else 3.7
	end
	local chosen,value=nil,math.huge
	for _,egg in ipairs(sim.eggs)do if egg.tier==tier then
		local x=egg.position.X
		local eligible=not zone or zone.kind=="any"or (x>=zone.min and x<=zone.max)
		if state.separatedChain and goal and goal.kind=="chain"and field.goalProgress==1 and state.linkAnchorX then
			eligible=eligible and math.abs(x-state.linkAnchorX)>=2.2
		end
		if eligible then
			local score=math.abs(x-desired)+egg.position.Y*.07
			if score<value then chosen,value=egg,score end
		end
	end end
	return aimAt(if chosen then chosen.position.X else desired,tier,Config,chosen and chosen.position.Y)
end
local function runOne(d,id,seed,policy,options)
	local Simulation,Round,Field,Config=d.Simulation,d.Round,d.FieldRun,d.Config
	local descriptor=d.Objectives.create(id,seed)
	local sim=Simulation.new("Springy",0,d.Objectives.simulationOptions(descriptor,"Springy"))
	local field=Field.new({descriptor=descriptor,sequence=1})
	local round=Round.new(Field.roundOptions())
	local cadence=if policy=="fast_center"then Config.DropInterval else options.cadence or 1.25
	local now,nextIntent,lastDrop,lastMerge,chain,ordinal=0,0,-math.huge,-math.huge,0,0
	local merged,trace,state={}, {}, {separatedChain=options.separatedChain==true}
	local attempts,rejected,firstStageDrop,chainExpiries,stage2CompletionDrop,separationMisses=0,0,nil,0,nil,0
	local deadline=options.deadline or 180
	while not field.outcome and now<deadline do
		if now+1e-7>=nextIntent and field:canDrop(sim.drops)then
			attempts+=1;nextIntent=now+cadence
			if Simulation.canDrop(sim)and now-lastDrop>=Config.DropInterval then
				local aim=chooseAim(policy,sim,field,state,Simulation,Config)
				local tier=Simulation.nextTier(sim)
				lastDrop=now -- Host debits cooldown before an attempted solver drop.
				if Simulation.drop(sim,aim)then table.insert(trace,{at=now,aim=aim,tier=tier,drop=sim.drops})else rejected+=1 end
			else rejected+=1 end
		end
		table.clear(merged);Simulation.step(sim,Config.FixedStep,merged)
		-- Mirror the host order, including terminal-tick observations.
		round:step(sim.eggs,Config.FixedStep,sim.drops)
		for _,event in ipairs(merged)do
			chain=if now-lastMerge<=1.25 then chain+1 else 1
			lastMerge=now;ordinal+=1;state.lastMergeX=event.position.X
			round.score+=10*(event.tier+math.min(chain-1,9))+(if event.cleared then 100 else 0)
			if event.cleared then round.maxClears+=1 end
			field:observe(event,{sequence=1,ordinal=ordinal,chain=chain,playTime=now})
			if not firstStageDrop and field.rootStage>=1 then firstStageDrop=sim.drops end
			if not stage2CompletionDrop and field.rootStage>=2 then stage2CompletionDrop=sim.drops end
			if state.separatedChain then
				if field:objective()and field:objective().kind=="chain"and field.goalProgress==1 then
					local identity=ordinal-chain+1
					if state.linkIdentity~=identity or not state.linkAnchorX then state.linkIdentity,state.linkAnchorX=identity,event.position.X
					elseif math.abs(event.position.X-state.linkAnchorX)<2 then separationMisses+=1 end
				else state.linkIdentity,state.linkAnchorX=nil,nil end
			end
			if policy=="goal_aware"and field:objective()and field:objective().kind=="chain"and field.goalProgress==1 then
				-- An observable first link invites a quicker legal follow-up press.
				-- This changes no physics, queue, contact gate or host cooldown.
				nextIntent=math.min(nextIntent,math.max(now,lastDrop+Config.DropInterval))
			end
		end
		if field:expireChain(now,lastMerge)then chainExpiries+=1;state.linkIdentity,state.linkAnchorX=nil,nil end
		field:step(sim.eggs,Config.FixedStep,sim.drops,round.over)
		now+=Config.FixedStep
	end
	local outcome=field.outcome
	local success=outcome and outcome.success==true
	return {controlVersion=Benchmark.ControlVersion,template=id,seed=seed,policy=policy,success=success==true,timeout=outcome==nil,
		overflow=round.over,baseReward=outcome and outcome.reward or 0,drops=sim.drops,seconds=now,
		score=round.score,firstStageDrop=firstStageDrop,stages=field.rootStage,merges=ordinal,
		stage2CompletionDrop=stage2CompletionDrop,separationMisses=separationMisses,
		chainExpiries=chainExpiries,attempts=attempts,rejectedAttempts=rejected,
		trace=if success or options.retainAllTraces then trace else nil,finalHeight=outcome and outcome.maxHeight or nil}
end
function Benchmark.run(dependencies,options)
	options=options or {}
	local count=options.count or 24
	local templates=if options.templateId then {options.templateId}else dependencies.Objectives.Order
	local policies=if options.policy then {options.policy}else {"naive_spread","fixed_bank","goal_aware"}
	local result={controlVersion=Benchmark.ControlVersion,count=count,firstSeed=options.firstSeed or 40001,cadence=options.cadence or 1.25,
		separatedChain=options.separatedChain==true,
		diagnosticAssumption=if options.separatedChain then "NONSHIPPING A/B; goal-aware assumes a visible fixed first-link anchor marker which runtime does not publish"else nil,
		rows={},samples={},persistentWrites=false,liveState=false,
		evidence="production solver; legal host cooldown/contact gate; goal-aware timing reacts only to public first-link events"}
	for _,id in ipairs(templates)do for _,policy in ipairs(policies)do
		local row={template=id,policy=policy,runs=0,wins=0,overflows=0,timeouts=0,reward=0,
			firstStages=0,firstStageDropSum=0,stages=0,successfulSeeds={},winningTraces={}}
		for index=0,count-1 do
			local sample=runOne(dependencies,id,result.firstSeed+index,policy,options)
			table.insert(result.samples,sample);row.runs+=1
			row.wins+=if sample.success then 1 else 0;row.overflows+=if sample.overflow then 1 else 0
			row.timeouts+=if sample.timeout then 1 else 0;row.reward+=sample.baseReward;row.stages+=sample.stages
			if sample.firstStageDrop then row.firstStages+=1;row.firstStageDropSum+=sample.firstStageDrop end
			if sample.success then
				table.insert(row.successfulSeeds,sample.seed)
				if #row.winningTraces<3 then table.insert(row.winningTraces,{seed=sample.seed,trace=sample.trace})end
			end
			if options.yieldEach~=false then task.wait()end -- Experiment only, never production.
		end
		row.successRate=row.wins/count;row.meanReward=row.reward/count;row.meanStages=row.stages/count
		row.firstStageRate=row.firstStages/count
		row.meanFirstStageDrop=if row.firstStages>0 then row.firstStageDropSum/row.firstStages else nil
		row.threeDistinctWinningSeeds=#row.successfulSeeds>=3
		table.insert(result.rows,row)
	end end
	return result
end
function Benchmark.separatedLanternSource(original)
	-- Modify only a returned source string for a private experiment module.
	-- The checked runtime source, descriptors, budget and dynamics stay untouched.
	local needle="self.goalProgress=if identity==self.chainIdentity then self.goalProgress+1 else 1"
	local first,last=string.find(original,needle,1,true)
	assert(first and not string.find(original,needle,last+1,true),"Expected one checked chain progression branch")
	local replacement=[[if identity~=self.chainIdentity or self.goalProgress==0 then
			self.goalProgress=1;self.experimentalAnchorX=merge.position.X
		elseif math.abs(merge.position.X-self.experimentalAnchorX)>=2 then self.goalProgress+=1 end]]
	return original:sub(1,first-1)..replacement..original:sub(last+1)
end
function Benchmark.replay(d,sample)
 assert(sample.controlVersion==Benchmark.ControlVersion,"Legacy X-spawn traces cannot replay as center-angle controls")
	assert(sample.success and type(sample.trace)=="table"and #sample.trace==24,"A successful 24-drop trace is required")
	local descriptor=d.Objectives.create(sample.template,sample.seed)
	local sim=d.Simulation.new("Springy",0,d.Objectives.simulationOptions(descriptor,"Springy"))
	local field=d.FieldRun.new({descriptor=descriptor,sequence=1})
	local round=d.Round.new(d.FieldRun.roundOptions())
	local now,lastDrop,lastMerge,chain,ordinal,index=0,-math.huge,-math.huge,0,0,1
	local merged={}
	while not field.outcome and now<180 do
		local drop=sample.trace[index]
		if drop and drop.at<=now+1e-7 then
			assert(math.abs(now-drop.at)<1e-6,"Trace must land on its original fixed tick")
			assert(not round.over and field:canDrop(sim.drops)and d.Simulation.canDrop(sim),"Trace violated the real contact gate")
			assert(now-lastDrop>=d.Config.DropInterval,"Trace violated host cooldown")
			assert(drop.drop==sim.drops+1 and drop.tier==d.Simulation.nextTier(sim),"Trace changed its bag/drop ordinal")
			assert(type(drop.aim)=="number"and drop.aim>=0 and drop.aim<=1 and d.Simulation.drop(sim,drop.aim),"Trace drop was not legal")
			lastDrop=now;index+=1
		end
		table.clear(merged);d.Simulation.step(sim,d.Config.FixedStep,merged)
		round:step(sim.eggs,d.Config.FixedStep,sim.drops)
		for _,event in ipairs(merged)do
			chain=if now-lastMerge<=1.25 then chain+1 else 1;lastMerge=now;ordinal+=1
			round.score+=10*(event.tier+math.min(chain-1,9))+(if event.cleared then 100 else 0)
			if event.cleared then round.maxClears+=1 end
			field:observe(event,{sequence=1,ordinal=ordinal,chain=chain,playTime=now})
		end
		field:expireChain(now,lastMerge)
		field:step(sim.eggs,d.Config.FixedStep,sim.drops,round.over)
		now+=d.Config.FixedStep
	end
	local outcome=assert(field.outcome,"Replay did not terminate")
	local matches=outcome.success==sample.success and outcome.reward==sample.baseReward
		and sim.drops==sample.drops and round.score==sample.score and field.rootStage==sample.stages
		and ordinal==sample.merges and round.over==sample.overflow
		and math.abs(outcome.maxHeight-sample.finalHeight)<1e-5 and math.abs(now-sample.seconds)<1e-6
	assert(matches,"Replayed solver outcome differs from the recorded winning sample")
	return{template=sample.template,seed=sample.seed,policy=sample.policy,matches=true,drops=sim.drops,
		reward=outcome.reward,score=round.score,merges=ordinal,seconds=now,persistentWrites=false}
end
function Benchmark.replayWinningTraces(dependencies,results,templateIds)
	local counts,rows,seen={},{},{}
	for _,sample in ipairs(results.samples)do
		seen[sample.template]=seen[sample.template]or {}
		if sample.policy=="goal_aware"and sample.success and not seen[sample.template][sample.seed]and(counts[sample.template]or 0)<3 then
			seen[sample.template][sample.seed]=true
			table.insert(rows,Benchmark.replay(dependencies,sample));counts[sample.template]=(counts[sample.template]or 0)+1
		end
	end
	for _,id in ipairs(templateIds or dependencies.Objectives.Order)do assert(counts[id]==3,"Need three distinct successful seeds for "..id)end
	return{passed=#rows,rows=rows,evidence="exact accepted aim/time/tier trace replay through the unchanged production solver",persistentWrites=false}
end
return Benchmark
