-- Fresh pure solver sources; no Workspace, profiles, remotes or persistent writes.
return function(server,sources)
	assert(type(sources)=="table","Pass current FieldRun/BoardSimulation/BoardRound sources")
	local shared=game.ReplicatedStorage.Shared:Clone();shared.Name="_FieldObjectivesShared";shared.Parent=server
	local realGame=game
	local fakeGame={}
	function fakeGame:GetService(name)if name=="ReplicatedStorage"then return{Shared=shared}end;return realGame:GetService(name)end
	local function load(name)
		local module=Instance.new("ModuleScript");module.Name="_FieldObjectives_"..name
		module.Source="return function(e)local game,script,require=e.game,e.script,e.require\n"..assert(sources[name]).."\nend"
		module.Parent=server;local ok,run=pcall(require,module);module:Destroy();assert(ok,run)
		return run({game=fakeGame,script=server[name],require=require})
	end
	local Field=load("FieldRun");local Simulation=load("BoardSimulation");local Round=load("BoardRound")
	local Objectives=require(shared.FieldObjectives);local Config=require(shared.BoardConfig)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function fixture(id,seed)return Field.new({descriptor=Objectives.create(id,seed or 40001),sequence=7})end
	local function merge(field,tier,x,ordinal,chain,sequence)
		return field:observe({tier=tier,position=Vector2.new(x,2),id=nil},{sequence=sequence or 7,ordinal=ordinal,chain=chain or ordinal})
	end
	test("zero-based rotation and deep frozen descriptors have no mutable aliases",function()
		assert(Objectives.next(0)=="bank_pair"and Objectives.next(1)=="creek_crossing"and Objectives.next(2)=="lantern_chain"and Objectives.next(3)=="bank_pair")
		local descriptor=Objectives.create("creek_crossing",40001)
		assert(table.isfrozen(descriptor)and table.isfrozen(descriptor.goals[1].zone)and table.isfrozen(descriptor.dynamics))
		assert(not pcall(function()descriptor.goals[1].tier=3 end))
	end)
	test("Bank minimum tier and inclusive left and right boundaries retain the original behavior",function()
		local f=fixture("bank_pair");assert(not merge(f,2,-3,1))
		assert(not merge(f,3,-2.5999,2));assert(merge(f,4,-2.6,3)and f.rootStage==1)
		assert(not merge(f,3,2.5999,4));assert(merge(f,3,2.6,5)and f.rootStage==2)
	end)
	test("Creek exact II center includes endpoints but rejects higher tier and outside",function()
		for _,x in ipairs({-1.6,1.6})do local f=fixture("creek_crossing");assert(merge(f,2,x,1)and f.rootStage==1)end
		for _,entry in ipairs({{3,0},{2,-1.6001},{2,1.6001}})do local f=fixture("creek_crossing");assert(not merge(f,entry[1],entry[2],1)and f.rootStage==0)end
	end)
	test("Creek seeded bank uses a separate derivation while the bag is identical across templates",function()
		for seed=40001,40024 do
			local reference
			for _,id in ipairs(Objectives.Order)do
				local descriptor=Objectives.create(id,seed)
				local sim=Simulation.new("Springy",0,Objectives.simulationOptions(descriptor,"Springy"))
				local ones,twos=0,0;for i,tier in ipairs(sim.queue)do
					if tier==1 then ones+=1 else twos+=1 end
					if reference then assert(reference[i]==tier)end
				end;assert(ones==16 and twos==8 and #sim.queue==24)
				for bag=0,3 do local count=0;for i=1,6 do if sim.queue[bag*6+i]==1 then count+=1 end end;assert(count==4)end
				reference=reference or sim.queue
			end
		end
		assert(Objectives.create("creek_crossing",40001).goals[2].zone.kind~=
			Objectives.create("creek_crossing",40002).goals[2].zone.kind)
	end)
	test("Lantern needs four different events; second event cannot serve both objectives",function()
		local f=fixture("lantern_chain")
		assert(merge(f,2,0,1)and f.goalProgress==1)
		assert(merge(f,2,0,2)and f.rootStage==1 and f.goalProgress==0)
		assert(not merge(f,2,0,2)and f.goalProgress==0)
		assert(merge(f,2,0,3)and f.goalProgress==1 and f.rootStage==1)
		assert(merge(f,2,0,4)and f.rootStage==2)
	end)
	test("fresh second-stage events may continue the physical chain but a broken chain resets progress",function()
		local f=fixture("lantern_chain");merge(f,2,0,1);merge(f,2,0,2)
		merge(f,2,0,3,3);assert(f.goalProgress==1)
		merge(f,2,0,4,1);assert(f.goalProgress==1 and f.rootStage==1)
		merge(f,2,0,5,2);assert(f.rootStage==2)
	end)
	test("expiry is strictly after 1.25 and clears a partial link exactly once",function()
		local f=fixture("lantern_chain");merge(f,2,0,1);merge(f,2,0,2);merge(f,2,0,3)
		assert(not f:expireChain(11.25,10)and f.goalProgress==1)
		assert(f:expireChain(11.25001,10)and f.goalProgress==0)
		assert(not f:expireChain(12,10));merge(f,2,0,4,1);assert(f.goalProgress==1)
	end)
	test("wrong run and stale ordinals cannot advance a new run even when cleared id is nil",function()
		local f=fixture("lantern_chain")
		assert(not f:observe({tier=5,position=Vector2.zero})and f.lastOrdinal==0,"sequence-bound fields reject unscoped events")
		assert(not merge(f,5,0,1,1,6)and f.lastOrdinal==0)
		merge(f,5,0,1);assert(not merge(f,5,0,1)and f.goalProgress==1)
	end)
	test("terminal tick observations count before settlement and overflow still has priority",function()
		for _,overflow in ipairs({false,true})do
			local f=fixture("bank_pair");merge(f,3,-3,1);merge(f,3,3,2)
			assert(f:step({},0,24,overflow)==nil or overflow)
			local result=if overflow then f.outcome else f:step({},4,24,false)
			assert(result.reward==(if overflow then 0 else 8)and result.success==not overflow)
		end
		local partial=fixture("bank_pair");partial:step({},0,24,false);assert(partial:step({},4,24,false).reward==0)
	end)
	test("Gentle Springy and descriptor overrides remain per-board without changing Config",function()
		local before=Config.Presets.Springy.bounce
		for _,preset in ipairs({"Gentle","Springy"})do
			for _,id in ipairs(Objectives.Order)do
				local d=Objectives.create(id,40001);local sim=Simulation.new(preset,0,Objectives.simulationOptions(d,preset))
				assert(sim.physics.bounce==Config.Presets[preset].bounce*d.dynamics.bounceScale and sim.physics.kick==d.dynamics.kick)
			end
		end;assert(Config.Presets.Springy.bounce==before)
	end)
	test("legacy custom targets are copied and remain supported",function()
		local targets={{side=-1,tier=4},{side=1,tier=5}}
		local f=Field.new({targets=targets});targets[1].tier=2
		assert(not f:observe({tier=3,position=Vector2.new(-3,0)}))
		assert(f:observe({tier=4,position=Vector2.new(-3,0)})and f.rootStage==1)
		assert(f:observe({tier=5,position=Vector2.new(3,0)})and f.rootStage==2)
	end)
	test("public snapshots are coherent copied schema and complete at step three",function()
		local f=fixture("lantern_chain");local first=f:public(7)
		assert(Objectives.validatePublic(first,7)and not Objectives.validatePublic(first,8))
		for i=1,4 do merge(f,2,0,i)end
		local done=f:public(7);assert(done.step==3 and done.complete and done.progress==0 and done.target==0 and Objectives.validatePublic(done,7))
		assert(first.step==1 and first.progress==0 and table.isfrozen(first.goals[1]))
		assert(not Objectives.validatePublic({sequence=7},7))
	end)
	test("public decoder rejects malformed goal shape title and template dynamics",function()
		local function copy(value)
			if type(value)~="table"then return value end
			local result={};for key,item in pairs(value)do result[key]=copy(item)end;return result
		end
		for _,breakIt in ipairs({
			function(v)v.goals[1].minTier=nil end,
			function(v)v.goals[1].tier=2 end,
			function(v)v.title={}end,
			function(v)v.dynamics.id="soft"end,
			function(v)v.goals[1].zone.max=0/0 end,
			function(v)v.sequence=nil end,
		})do local invalid=copy(fixture("bank_pair"):public(7));breakIt(invalid);assert(not Objectives.validatePublic(invalid,7))end
		local lantern=copy(fixture("lantern_chain"):public(7));lantern.goals[1].tier=2;assert(not Objectives.validatePublic(lantern,7))
		lantern=copy(fixture("lantern_chain"):public(7));lantern.goals[1].zone={kind="left",min=-5.5,max=-2.6};assert(not Objectives.validatePublic(lantern,7))
	end)
	shared:Destroy()
	return{passed=#cases,cases=cases,persistentWrites=false,evidence="fresh pure solver sources and immutable catalog; no live state"}
end
