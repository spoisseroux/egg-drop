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
		assert(Objectives.next(0)=="bank_pair"and Objectives.next(1)=="creek_crossing"and Objectives.next(2)=="lantern_chain"and Objectives.next(3)=="ripple_relay"and Objectives.next(4)=="bank_bounce"and Objectives.next(5)=="mirror_marks"and Objectives.next(6)=="bank_pair")
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
 test("new bounded templates retain seed orientation, unique events and unchanged reward budget",function()
  for _,seed in ipairs({40001,40002,40003,40004})do
   local ripple=fixture("ripple_relay",seed)
   assert(merge(ripple,2,-3,1)and merge(ripple,3,0,2)and ripple.rootStage==1)
   assert(not merge(ripple,3,0,2)and ripple.rootStage==1)
   assert(not merge(ripple,2,0,3));assert(merge(ripple,4,1.6,4)and ripple.rootStage==2)
   local bounce=fixture("bank_bounce",seed);local zone=bounce:objective().zone;local x=(zone.min+zone.max)/2
   assert(not merge(bounce,3,x,1));assert(merge(bounce,2,x,2)and bounce.rootStage==1)
   assert(not merge(bounce,2,x,2));assert(merge(bounce,2,0,3,3)and bounce.goalProgress==1)
   assert(merge(bounce,2,0,4,4)and bounce.rootStage==2)
   local mirror=fixture("mirror_marks",seed);local first=mirror:objective().zone;local firstX=(first.min+first.max)/2
   assert(merge(mirror,2,firstX,1)and mirror.rootStage==1)
   assert(not merge(mirror,2,firstX,2));local opposite=mirror:objective().zone
   assert(first.kind~=opposite.kind and merge(mirror,2,(opposite.min+opposite.max)/2,3)and mirror.rootStage==2)
   for _,field in ipairs({ripple,bounce,mirror})do
    assert(field.budget==24 and Objectives.validatePublic(field:public(7),7))
    field:step({},0,24,false);local result=field:step({},4,24,false);assert(result.success and result.reward==8)
   end
  end
 end)
 test("strict public descriptors reject altered bounds goal IDs targets and mismatched mirrored banks",function()
  local function mutable(t)if type(t)~="table"then return t end;local r={};for k,v in pairs(t)do r[k]=mutable(v)end;return r end
  for _,id in ipairs(Objectives.Order)do
   local original=fixture(id):public(7);assert(Objectives.validatePublic(original,7))
   for _,mutate in ipairs({function(v)v.goals[1].id="unknown"end,function(v)v.goals[1].target=if v.goals[1].target==2 then 1 else 2 end,function(v)v.dynamics.label="incorrect"end})do
    local invalid=mutable(original);mutate(invalid)
    assert(not Objectives.validatePublic(invalid,7))
   end
   local invalid=mutable(original)
   for _,goal in ipairs(invalid.goals)do if goal.zone.min then goal.zone.min+=.01;assert(not Objectives.validatePublic(invalid,7));break end end
  end
  local mirror=mutable(fixture("mirror_marks"):public(7));mirror.goals[2].zone=mirror.goals[1].zone;assert(not Objectives.validatePublic(mirror,7))
 end)
	-- Difficulty (QUESTS-DIFFICULTY-PLAN section 1).
	test("medium equals today: same goals, queue, round options and tidy line",function()
		for _,id in ipairs(Objectives.Order)do for seed=40001,40006 do
			local today,medium=Objectives.create(id,seed),Objectives.create(id,seed,"medium")
			assert(#today.goals==2 and #medium.goals==2)
			for i,goal in ipairs(today.goals)do assert(goal.id==medium.goals[i].id and goal.target==medium.goals[i].target)end
			local a=Simulation.new("Springy",0,Objectives.simulationOptions(today,"Springy"))
			local b=Simulation.new("Springy",0,Objectives.simulationOptions(medium,"Springy","medium"))
			assert(table.concat(a.queue,",")==table.concat(b.queue,","))
		end end
		local o,m=Field.roundOptions(),Field.roundOptions("medium")
		assert(o.overflowY==8.6 and o.grace==2.4 and o.armAfterDrops==12 and m.overflowY==8.6 and m.grace==2.4 and m.armAfterDrops==12)
		assert(fixture("bank_pair").bonusHeight==7.5 and Field.new({descriptor=Objectives.create("bank_pair",1,"medium")}).bonusHeight==7.5)
	end)
	test("hard has three goals, a lower line and a faster mix; easy a calmer one",function()
		for _,id in ipairs(Objectives.Order)do
			local hard=Objectives.create(id,40001,"hard");assert(#hard.goals==3)
			local third=hard.goals[3];assert(third.id=="hard_iv"or third.id=="hard_chain3")
			local f=Field.new({descriptor=hard,sequence=7});assert(f.goalCount==3 and f.bonusHeight==6.5 and f.heat=="hard")
			assert(Objectives.validatePublic(f:public(7),7))
			local easy=Objectives.create(id,40001,"easy");assert(#easy.goals==2)
			local sim=Simulation.new("Springy",0,Objectives.simulationOptions(hard,"Springy"))
			local threes=0;for _,t in ipairs(sim.queue)do if t==3 then threes+=1 end end;assert(threes==4 and #sim.queue==24)
			local calm=Simulation.new("Springy",0,Objectives.simulationOptions(easy,"Springy"))
			local twos=0;for _,t in ipairs(calm.queue)do if t==2 then twos+=1 end end;assert(twos==4)
		end
		local h,e=Field.roundOptions("hard"),Field.roundOptions("easy")
		assert(h.overflowY==7.6 and h.grace==2 and h.armAfterDrops==10 and e.overflowY==9.6 and e.grace==3 and e.armAfterDrops==16)
		assert(not pcall(Objectives.create,"bank_pair",1,"insane"))
	end)
	test("hard needs all three goals; the third counts after the first two",function()
		local f=Field.new({descriptor=Objectives.create("bank_pair",40001,"hard"),sequence=7})
		merge(f,3,-3,1);merge(f,3,3,2);assert(f.rootStage==2 and not f:public(7).complete)
		f:step({},0,24,false);local fail=f:step({},4,24,false);assert(not fail.success and fail.reward==0)
		local g=Field.new({descriptor=Objectives.create("bank_pair",40001,"hard"),sequence=7})
		merge(g,3,-3,1);merge(g,3,3,2);merge(g,2,0,3,1);merge(g,2,0,4,2);merge(g,2,0,5,3)
		assert(g.rootStage==3);local done=g:public(7);assert(done.complete and done.step==4 and Objectives.validatePublic(done,7))
		g:step({},0,24,false);assert(g:step({},4,24,false).success)
		local l=Field.new({descriptor=Objectives.create("lantern_chain",40001,"hard"),sequence=7})
		for i=1,4 do merge(l,2,0,i)end;assert(l.rootStage==2)
		assert(not merge(l,3,0,5));assert(merge(l,4,0,6)and l.rootStage==3)
	end)
	test("the tidy bonus moves with hard's lower line",function()
		local function finish(heat,top)
			local f=Field.new({descriptor=Objectives.create("bank_pair",40001,heat),sequence=7})
			for i=1,(if heat=="hard"then 5 else 2)do merge(f,if i<=2 then 3 else 2,if i==1 then -3 elseif i==2 then 3 else 0,i,if i<=2 then 1 else i-2)end
			local egg={{position=Vector2.new(0,top-1),radius=1}}
			f:step(egg,0,24,false);return f:step(egg,4,24,false)
		end
		assert(finish("medium",7.2).reward==8 and finish("medium",7.9).reward==6)
		-- Under Hard's 7.6 line but above its 6.5 tidy line: no free +2.
		assert(finish("hard",7.2).reward==6 and finish("hard",6.4).reward==8)
		assert(finish("easy",8.4).reward==8 and finish("easy",8.7).reward==6)
	end)
	test("public validation accepts two or three goals but not a forged third",function()
		local function mutable(t)if type(t)~="table"then return t end;local r={};for k,v in pairs(t)do r[k]=mutable(v)end;return r end
		local two=mutable(fixture("bank_pair"):public(7));table.insert(two.goals,{id="hard_chain3",kind="chain",zone={kind="any"},target=9})
		assert(not Objectives.validatePublic(two,7))
		local three=mutable(Field.new({descriptor=Objectives.create("bank_pair",40001,"hard"),sequence=7}):public(7))
		assert(Objectives.validatePublic(three,7));three.step=5;assert(not Objectives.validatePublic(three,7))
		local four=mutable(three);four.step=1;table.insert(four.goals,four.goals[3]);assert(not Objectives.validatePublic(four,7))
	end)
	shared:Destroy()
	return{passed=#cases,cases=cases,persistentWrites=false,evidence="fresh pure solver sources and immutable catalog; no live state"}
end
