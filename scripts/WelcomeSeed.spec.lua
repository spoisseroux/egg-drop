-- Real BoardSimulation solver, both presets. Finite sweep evidence, never a
-- mathematical proof for every real-valued aim. Studio signature (server,shared).
return function(server,shared,modules)
	modules=modules or {}
	local Seed=modules.Seed or require(server.WelcomeSeed)
	local Simulation=modules.Simulation or require(server.BoardSimulation)
	local Config=modules.Config or require(shared.BoardConfig)
	local Round=modules.Round or require(server.BoardRound)
	local count=modules.aimSteps or 1000
	local failures={};local tested=0;local minTime,maxTime=math.huge,0
	for _,preset in ipairs({"Gentle","Springy"})do
		for index=0,count do
			local board=Seed.create(Simulation,preset,0)
			assert(#board.eggs==3 and Simulation.nextTier(board)==1)
			local merged={}
			for _=1,120 do table.clear(merged);Simulation.step(board,Config.FixedStep,merged);assert(#merged==0,"seed must not earn automatic merges")end
			local aim=index/count
			assert(Simulation.drop(board,aim),"opening drop must accept original aim")
			local first
			for frame=1,480 do
				table.clear(merged);Simulation.step(board,Config.FixedStep,merged)
				if #merged>0 then first=frame*Config.FixedStep;break end
			end
			tested+=1
			if not first then table.insert(failures,{preset=preset,aim=aim})
			else minTime=math.min(minTime,first);maxTime=math.max(maxTime,first)end
		end
	end
	assert(#failures==0,"seed misses "..#failures.." sampled aims; first="..tostring(failures[1]and failures[1].aim))
	local sim=Seed.create(Simulation,"Springy",50,13)
	assert(Simulation.nextTier(sim)==1 and sim.drops==13 and Seed.afterMerge(sim)and not Seed.afterMerge(sim))
	assert(sim.queue==nil and Simulation.nextTier(sim)==Config.Queue[14%#Config.Queue])
	local record={position=Vector2.new(0,Config.SpawnY),radius=1,tier=1,velocity=Vector2.zero}
	sim.eggs=table.create(Config.MaxEggs,record)
	local safe,normal=Round.new({safe=true}),Round.new()
	safe:step(sim.eggs,4,100);normal:step(sim.eggs,4,100)
	assert(not safe.over and safe.danger==0 and normal.over,"only Welcome suppresses cap/overflow loss")
	assert(Seed.needsRefresh(sim))
	local fresh=Seed.refresh(Simulation,sim)
	assert(#fresh.eggs==3 and fresh.drops==sim.drops and fresh.serial>sim.serial,"bounded refresh preserves counters and monotonic egg ids")
	assert(Simulation.drop(fresh,.5),"refresh remains playable")
	-- The First Hatch opener (Onboard "opener", artifacts/onboarding-2026-11-26/PLAN.md): five balls that sit still; the
	-- first drop sets off a chain of three or more merges at nearly every aim; nothing reaches tier V (Trials); a
	-- refresh keeps the opener. A measured rate, not a proof.
	local opener={}
	for _,preset in ipairs({"Springy","Gentle"})do
		local steps=modules.openerSteps or 80
		local chains,misses,top=0,0,0
		for index=0,steps do
			local board=Seed.create(Simulation,preset,0,0,true)
			assert(#board.eggs==#Seed.Opener and board.welcomeOpener==true)
			local merged={}
			for _=1,120 do table.clear(merged);Simulation.step(board,Config.FixedStep,merged);assert(#merged==0,"the opener must not merge by itself")end
			for k,e in ipairs(board.eggs)do
				local s=Seed.Opener[k]
				assert((e.position-Vector2.new(s.x,s.y)).Magnitude<.05,preset..": the opener moves before the first drop")
			end
			assert(Simulation.drop(board,index/steps))
			local count=0
			for _=1,600 do
				table.clear(merged);Simulation.step(board,Config.FixedStep,merged)
				for _,m in ipairs(merged)do count+=1;top=math.max(top,m.tier or 0)end
			end
			if count>=3 then chains+=1 elseif count==0 then misses+=1 end
		end
		opener[preset]={aims=steps+1,chains=chains,misses=misses,topTier=top}
		assert(top<5,preset..": the opener reaches tier "..top.." (Trials)")
		assert(chains/(steps+1)>=.95,preset..": chain on "..chains.."/"..(steps+1))
		assert(misses==0,preset..": "..misses.." aims merge nothing")
	end
	local refreshed=Seed.refresh(Simulation,Seed.create(Simulation,"Springy",0,0,true))
	assert(refreshed.welcomeOpener==true and #refreshed.eggs==#Seed.Opener,"a refresh keeps the opener")
	assert(Seed.create(Simulation,"Springy",0).welcomeOpener==nil,"off: today's starter")
	return {passed=5,tested=tested,aimSteps=count,minFirstMerge=minTime,maxFirstMerge=maxTime,universalProof=false,opener=opener}
end
