-- G2 (G2-FIRST-SESSION-LOOK 2026-11-25): the client's pure rules. The paw prints (PetTrail: where they go, the walk,
-- the fade, when they end, which ground takes a print, the screen-edge chip) and the pet's head on the owner
-- (PetLookAt.faceOwner); the toy pill's words and the round-two pill (GrowthNudge, NoticeCards firstToy); the calm
-- Welcome deck's plan (DeckCalm). The Studio pass covers the drawn prints, pills and deck.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.GrowthG2)(PlayerScripts.Client)
-- Offline: the G2 harness (see artifacts/growth-2026-11-26/G2-PLAN.md, Verification).
return function(client)
	local Trail=require(client.PetTrail)
	local Nudge=require(client.GrowthNudge)
	local Calm=require(client.DeckCalm)
	local Notices=require(client.NoticeCards)
	local Look=require(client.PetLookAt)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local UICopy=require(Shared.UICopy)
	local Flags=require(Shared.FeatureFlags)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
	local ON={RoundTwoNudge=true,StarterBonus=true,ToyPillCopy=true}

	test("the five switches are on for the build",function()
		assert(Flags.PetTrail==true and Flags.FirstHelloBonus==true and Flags.RoundTwoNudge==true and Flags.ToyPillCopy==true and Flags.CalmFirstDeck==true)
	end)

	test("the seven new strings, and the old toy pill words kept for the switch off",function()
		assert(UICopy.get("pet.hello",{count=3})=="First hello! +3 ★")
		assert(UICopy.get("coach.roundTwo.bonus",{count=12})=="Round two: ★ 12 Welcome bonus")
		assert(UICopy.get("coach.roundTwo.toy",{pet="Bear"})=="Round two: hatch a toy for Bear")
		assert(UICopy.get("coach.roundTwo.plain")=="Play round two on your Pocket Deck")
		assert(UICopy.get("notice.pill.firstToy",{pet="Bear"})=="Hatch a toy for Bear")
		assert(UICopy.get("notice.firstToy.title",{pet="Bear"})=="A toy for Bear")
		assert(UICopy.get("notice.firstToy.what",{pet="Bear"})=="You have enough Stars for a Toy Egg. It hatches a toy for Bear to carry and play with.")
		assert(UICopy.get("notice.pill.firstSpend")=="Hatch your first egg"and UICopy.get("notice.firstSpend.title")=="Your first egg")
	end)

	test("toy pill: the switch picks the words; its card keeps firstSpend's next line and button",function()
		local on,off=Nudge.toyCopy(ON),Nudge.toyCopy({ToyPillCopy=false})
		assert(on.pill=="notice.pill.firstToy"and on.card=="firstToy"and on.named==true)
		assert(off.pill=="notice.pill.firstSpend"and off.card=="firstSpend"and off.named==false)
		assert(Notices.has("firstToy")and table.find(Notices.Order,"firstToy"))
		assert(Notices.title("firstToy",{pet="Bear"})=="A toy for Bear")
		local cards=Notices.cards("firstToy",{pet="Bear"})
		assert(cards[1].line==UICopy.get("notice.firstToy.what",{pet="Bear"}))
		assert(cards[2].line==UICopy.get("notice.firstSpend.next"),"the next line is firstSpend's")
		assert(Notices.go("firstToy").target=="hatch")
		assert(Notices.cards("firstSpend")[2].line==UICopy.get("notice.firstSpend.next"),"firstSpend unchanged")
	end)

	test("round-two pill: after the toy (bonus or plain), at earn (toy), never with the toy pill, a veteran or a played save",function()
		local fresh={stats={rounds=0},totalWins=0}
		assert(Nudge.variant("done",fresh,ON,false)=="bonus")
		assert(Nudge.variant("done",fresh,{RoundTwoNudge=true,StarterBonus=false},false)=="plain")
		assert(Nudge.variant("earn",fresh,ON,false)=="toy")
		for _,stage in ipairs({"purchase","receipt","reveal","welcome","free"})do assert(Nudge.variant(stage,fresh,ON,false)==nil,stage)end
		assert(Nudge.variant("done",{stats={rounds=1},totalWins=0},ON,false)==nil,"a field round saved")
		assert(Nudge.variant("done",{stats={rounds=0},totalWins=99},ON,false)==nil,"a veteran")
		assert(Nudge.variant("done",{totalWins=0},ON,false)==nil,"no stats: the snapshot cannot say")
		assert(Nudge.variant("done",{stats={rounds=0},totalWins=0,lastRunReward={sequence=3}},ON,false)==nil,
			"an old save whose round counter started at 0 (StarterBonus would not pay it)")
		assert(Nudge.variant("done",fresh,ON,true)==nil,"a field round started this session")
		assert(Nudge.variant("done",fresh,{RoundTwoNudge=false,StarterBonus=true},false)==nil,"switch off")
		local key,vars=Nudge.copy("bonus","Bear")
		assert(UICopy.get(key,vars)=="Round two: ★ 12 Welcome bonus","the count comes from StarterBonus")
		key,vars=Nudge.copy("toy","Momo");assert(UICopy.get(key,vars)=="Round two: hatch a toy for Momo")
		key,vars=Nudge.copy("plain","Bear");assert(UICopy.get(key,vars)=="Play round two on your Pocket Deck")
		assert(Nudge.Delay==2.5)
	end)

	test("prints: 3 studs ahead, 2.5 short of the pet, 2.2 apart, left and right by 0.35; none under 6; 12 at most",function()
		local from,to=Vector3.new(0,0,0),Vector3.new(0,0,-20)
		local list=Trail.prints(from,to)
		assert(#list==7,"3, 5.2, ... 16.2 (17.5 is the stop)")
		for i,p in ipairs(list)do
			assert(near(p.along,3+(i-1)*2.2,1e-4)and p.index==i)
			assert(near(math.abs(p.position.X),.35,1e-6)and p.side==(if i%2==1 then -1 else 1))
			assert(near(p.position.Z,-p.along,1e-4))
		end
		assert(list[#list].along<=20-2.5)
		assert(#Trail.prints(from,Vector3.new(5.9,0,0))==0,"under 6 studs: the ring only")
		local long=Trail.prints(from,Vector3.new(100,4,0))
		assert(#long==12 and near(long[1].along,3)and near(long[12].along,3+11*2.2,1e-4),"the 12 nearest the player")
		assert(near(long[1].lineY,4*3/100,1e-6),"Y follows the line")
		local h=Trail.heading(from,Vector3.new(0,0,-20));assert(near(h.Z,-1))
		local flatFrame=Trail.frame(Vector3.new(1,2,3),Vector3.new(0,0,-1),Vector3.new(0,1,0))
		assert(near(flatFrame.LookVector.Z,-1,1e-6)and near(flatFrame.UpVector.Y,1,1e-6)and flatFrame.Position==Vector3.new(1,2,3),"toes along the line")
		local n=Vector3.new(.3,1,0).Unit
		local slope=Trail.frame(Vector3.zero,Vector3.new(1,0,0),n)
		assert(near(slope.UpVector:Dot(n),1,1e-6)and near(slope.LookVector:Dot(n),0,1e-6)and slope.LookVector.X>.9,"lies on a slope, still toward the pet")
	end)

	test("the walk: each print swells to 1.15 in turn, 0.12 s apart, every 1.6 s; Reduced Motion keeps them still",function()
		assert(near(Trail.swell(Trail.WalkTime/2,1,false),1.15,1e-6))
		assert(near(Trail.swell(.12+Trail.WalkTime/2,2,false),1.15,1e-6))
		assert(Trail.swell(.1,2,false)==1,"print 2 waits 0.12 s")
		assert(near(Trail.swell(1.6+Trail.WalkTime/2,1,false),1.15,1e-6),"again every 1.6 s")
		assert(Trail.swell(Trail.WalkTime/2,1,true)==1)
		for t=0,3.2,.05 do for i=1,12 do local s=Trail.swell(t,i,false);assert(s>=1 and s<=1.15+1e-9)end end
	end)

	test("leaving: 0.4 s, nearest the player first",function()
		assert(Trail.fade(0,1,6)==0 and Trail.fade(.1,1,6)>Trail.fade(.1,6,6))
		for i=1,6 do assert(Trail.fade(.4,i,6)==1,"gone by 0.4 s")end
		assert(Trail.fade(.2,1,1)==.5 and Trail.fade(.4,1,1)==1)
	end)

	test("it ends on the first hello, at 30 s, or when a menu, a machine or the deck opens; redraws after 3 / 2 studs",function()
		assert(Trail.endReason(1,{})==nil)
		assert(Trail.endReason(1,{hello=true})=="hello"and Trail.endReason(30,{})=="time")
		assert(Trail.endReason(1,{menu=true})=="menu"and Trail.endReason(1,{deck=true})=="deck")
		local drawn={player=Vector3.new(0,0,0),pet=Vector3.new(10,0,0)}
		assert(Trail.moved(nil,drawn.player,drawn.pet))
		assert(not Trail.moved(drawn,Vector3.new(2.9,5,0),Vector3.new(11.9,0,0)),"height and small moves do not redraw")
		assert(Trail.moved(drawn,Vector3.new(3,0,0),drawn.pet)and Trail.moved(drawn,drawn.player,Vector3.new(10,0,2)))
	end)

	test("ground: lawn takes a print; water, a steep face, a machine top or a wet footprint do not",function()
		local lawn={ground=true,water=false,position=Vector3.new(0,1,0),normal=Vector3.new(0,1,0)}
		assert(Trail.ground(lawn,1,function()return false end))
		assert(not Trail.ground(nil,1))
		assert(not Trail.ground({ground=false,position=lawn.position,normal=lawn.normal},1),"not the world's ground")
		assert(not Trail.ground({ground=true,water=true,position=lawn.position,normal=lawn.normal},1),"water")
		assert(not Trail.ground({ground=true,position=lawn.position,normal=Vector3.new(.8,.6,0)},1),"a wall")
		assert(not Trail.ground({ground=true,position=Vector3.new(0,3,0),normal=lawn.normal},1),"off the line: a machine top")
		assert(not Trail.ground(lawn,1,function()return true end),"a wet or blocked footprint")
		assert(Trail.inFootprint(Vector3.new(1.9,0,-.9),Vector3.new(4,1,2))and not Trail.inFootprint(Vector3.new(2.1,0,0),Vector3.new(4,1,2)))
	end)

	test("the edge chip: none while the pet is on screen; else on the edge toward it (behind the camera flips)",function()
		local size=Vector2.new(800,400)
		assert(Trail.edge(size,Vector3.new(400,200,10))==nil)
		local right=Trail.edge(size,Vector3.new(2000,200,10))
		assert(right and near(right.y,200)and right.x<=800-28 and right.x>=800-29 and near(right.angle,0))
		local left=Trail.edge(size,Vector3.new(-50,200,10));assert(left.x<=29 and near(math.abs(left.angle),180))
		local behind=Trail.edge(size,Vector3.new(600,200,-10));assert(behind.x<400,"behind and right reads as left")
		local corner=Trail.edge(size,Vector3.new(5000,5000,10));assert(corner.x<=800-28 and corner.y<=400-28)
	end)

	test("the pet's head holds on the owner at trail distances (faceOwner), within the usual 35 degrees",function()
		local visual={origin=Vector3.new(0,0,0),yaw=0,time=0,worldContext=true}
		Look.step(visual,.25,true);visual.ownerPosition=Vector3.new(30,0,30)
		for _=1,40 do Look.step(visual,.25,true)end
		assert(visual.lookYaw==0,"out of range: no turn today")
		visual.faceOwner=true
		for _=1,40 do Look.step(visual,.25,true)end
		assert(near(visual.lookYaw,Look.Max,1e-3),"held, clamped")
		visual.faceOwner=nil;visual.reducedEffects=false
		for _=1,80 do Look.step(visual,.25,true)end
		assert(math.abs(visual.lookYaw)<1e-3,"lets go when the trail ends")
	end)

	test("calm deck: the gate is exactly the Welcome round with no pet",function()
		assert(Calm.wanted({phase="Welcome",owned=0},{CalmFirstDeck=true}))
		assert(not Calm.wanted({phase="Welcome",owned=1},{CalmFirstDeck=true}),"the first field round: everything back")
		assert(not Calm.wanted({phase="Play",owned=0},{CalmFirstDeck=true}))
		assert(not Calm.wanted({phase="Welcome",owned=0},{CalmFirstDeck=false}),"switch off")
		assert(Calm.textSize(false)==20 and Calm.textSize(true)==16)
	end)

	test("calm deck, PC: coach card to the column foot over the quests; egg over Difficulty and Win pays; Controls empty",function()
		local L,R,col=12,620,216
		local regular={Score={x=L,y=12,w=col,h=96},Chain={x=L,y=116,w=col,h=80},Goals={x=L,y=204,w=col,h=244},DailyQuests={x=L,y=456,w=col,h=140},
			Next={x=R,y=12,w=col,h=140},EggsLeft={x=R,y=160,w=col,h=96},Difficulty={x=R,y=264,w=col,h=72},WinPays={x=R,y=344,w=col,h=84},Controls={x=R,y=436,w=col,h=160}}
		local plan=Calm.plan("regular",regular)
		assert(#plan.hide==6 and not table.find(plan.hide,"Next")and not table.find(plan.hide,"Goals")and not table.find(plan.hide,"EggsLeft"))
		-- (beta 34 QA: the Chain card is 16 taller for its line, Goals 16 lower, Daily quests 16 shorter)
		assert(plan.coach.x==L and plan.coach.y==204 and plan.coach.h==596-204 and plan.coach.w==col)
		assert(plan.egg.y==160-56 and plan.egg.h==428-104,"the Controls slot stays empty; NEXT gives the egg 40%")
		assert(plan.next.y==12 and plan.next.h==140-56 and plan.next.x==R)
		local small={Score={x=6,y=6,w=100,h=54},Goals={x=6,y=66,w=100,h=136},Chain={x=6,y=208,w=100,h=85},
			Next={x=300,y=6,w=100,h=84},EggsLeft={x=300,y=96,w=100,h=64},Difficulty={x=300,y=166,w=100,h=60},WinPays={x=300,y=232,w=100,h=61}}
		plan=Calm.plan("small",small)
		assert(plan.coach.h==293-66 and plan.egg.h==293-(96-33)and plan.next.h==84-33)
	end)

	test("calm deck, phone: two columns grow down their own column; one column stacks the egg under the words",function()
		-- narrow at 750 x 402 (shape of resolveCompact): chain over score, goals, quest handle; next, eggs, difficulty, win pays, controls.
		local cards={Chain={x=150,y=70,w=110,h=44},Score={x=150,y=122,w=110,h=44},Goals={x=150,y=174,w=110,h=108},QuestHandle={x=150,y=320,w=110,h=44},
			Next={x=440,y=70,w=110,h=64},EggsLeft={x=440,y=142,w=110,h=44},Difficulty={x=440,y=194,w=110,h=44},WinPays={x=440,y=246,w=110,h=44},Controls={x=440,y=280,w=110,h=86}}
		local plan=Calm.plan("narrow",cards)
		assert(plan.coach.y==174 and plan.coach.h==364-174,"to the quest handle's foot")
		assert(plan.egg.y==142-24 and plan.egg.h==290-118 and plan.next.h==40,"to Win pays' foot, with NEXT's spare height (its ball stays 24 px)")
		local one={Score={x=10,y=40,w=80,h=44},Next={x=134,y=40,w=76,h=44},Goals={x=10,y=92,w=200,h=108},EggsLeft={x=10,y=208,w=88,h=44},
			Difficulty={x=106,y=208,w=104,h=44},WinPays={x=10,y=260,w=200,h=44},QuestHandle={x=10,y=320,w=200,h=44}}
		plan=Calm.plan("one",one)
		assert(plan.coach.x==10 and plan.coach.y==92 and plan.coach.w==200 and plan.coach.h>=108)
		assert(plan.egg.x==10 and plan.egg.w==200 and plan.egg.y==92+plan.coach.h+Calm.Gap and plan.egg.y+plan.egg.h==364,"egg under the words, to the foot")
		assert(plan.egg.h>=44)
		local short=Calm.plan("one",{Goals={x=10,y=92,w=200,h=120},EggsLeft={x=10,y=208,w=88,h=44},Difficulty={x=106,y=208,w=104,h=44}})
		assert(short.coach==nil and short.egg==nil and #short.hide==1,"too short for the card and a 44 px egg: hide, move nothing")
		assert(not table.find(plan.hide,"Next"),"Next stays at the top right")
		assert(#Calm.plan("narrow",{Goals=cards.Goals}).hide==0 and Calm.plan("narrow",{Goals=cards.Goals}).egg==nil,"missing cards: nothing moves")
	end)

	return {passed=#cases,cases=cases}
end
