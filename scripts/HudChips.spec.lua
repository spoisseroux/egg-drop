-- Beta (17) QA U1 (artifacts/qa-2026-11-25-beta17/CAPSULE-AND-HUD-LOOK.md section 2): the HUD chip rules. The play date
-- ticket says "Play date 1/3 · +4 ★" with the snapshot's own reward (never a hard-coded 4), drops the reward on a
-- narrow top bar, and keeps its playing / saving / done states; the gate is Things to do (off: the live "Games 0/3").
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.HudChips)(PlayerScripts.Client); offline in
-- scripts/run_dash_server_specs.py.
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Things=require(Shared.Things)
	local UICopy=require(Shared.UICopy)
	local Activities=require(Shared.ParkActivities)
	local Chips=require(client.HudChips)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end

	test("the gate is Things to do: on with it, off without it (the live game keeps Games 0/3)",function()
		Things.inject({flags={ThingsToDo=true},studio=true})
		assert(Chips.on()==true)
		Things.inject({flags={ThingsToDo=true},studio=true,page=false})
		assert(Chips.on()==false)
		Things.inject({flags={ThingsToDo=false},studio=true})
		assert(Chips.on()==false)
		Things.inject({flags={ThingsToDo=true},studio=false,place=96451847774961})
		assert(Chips.on()==false,"never on the live place")
		Things.inject(nil)
	end)

	test("the play date reads Play date 1/3 and +N Stars with the snapshot's reward; a narrow bar drops the reward",function()
		local date={count=1,target=3,reward=7}
		local text=Chips.dateText(date,"games",false)
		assert(text==UICopy.get("park.date.games",{count=1,target=3,reward=7}),text)
		assert(string.find(text,"Play date",1,true)and string.find(text,"1/3",1,true)and string.find(text,"+7",1,true),text)
		assert(not string.find(text,"Games",1,true),"the old name is gone")
		local short=Chips.dateText(date,"games",true)
		assert(short==UICopy.get("park.playDate",{count=1,target=3})and not string.find(short,"★",1,true),short)
		-- Missing numbers fall back to ParkActivities, never a literal.
		local fallback=Chips.date(nil)
		assert(fallback.count==0 and fallback.target==Activities.PlayDate.Target and fallback.reward==Activities.PlayDate.Reward)
		assert(Chips.date({count=9,target=3}).count==3,"clamped to the target")
		assert(Chips.date({count=-2}).count==0)
	end)

	test("states: saving and playing keep the count; done says the reward; done wins over saving",function()
		local date={count=2,target=3,reward=4}
		assert(Chips.dateState(date,0,false)=="games")
		assert(Chips.dateState(date,0,true)=="playing")
		assert(Chips.dateState(date,1,true)=="saving")
		assert(Chips.dateState({count=3,target=3,reward=4},1,true)=="done")
		assert(Chips.dateState({count=1,target=3,done=true},0,false)=="done")
		assert(Chips.dateText(date,"playing",false)==UICopy.get("park.date.playing",{count=2,target=3}))
		assert(Chips.dateText(date,"saving",true)==UICopy.get("park.date.saving",{count=2,target=3}))
		local done=Chips.dateText({count=3,target=3,reward=5},"done",false)
		assert(done==UICopy.get("park.date.done",{reward=5})and string.find(done,"+5",1,true),done)
	end)

	test("narrow: only a known width under the limit; one slot order",function()
		assert(Chips.narrow(359,Chips.NarrowEgg)and not Chips.narrow(360,Chips.NarrowEgg))
		assert(Chips.narrow(590,Chips.NarrowDate)and not Chips.narrow(900,Chips.NarrowDate))
		assert(not Chips.narrow(0,Chips.NarrowDate)and not Chips.narrow(nil,Chips.NarrowDate),"unknown is wide")
		local P=Chips.Priority
		assert(P.ready>P.date and P.date>P.clock and P.ready<1)
	end)

	return{passed=#cases,cases=cases}
end
