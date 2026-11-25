-- Growth cuts (GROWTH-CUTS-LOOK 2026-11-25 sections 2, 1 and 4): CoachCards' pure rules for the say-hi line that
-- replaces the garden tour (no stand-still wait, never for a veteran or a save that finished the tour, never on a
-- replay), the garden's Tomorrow line (onboarding done, after results or 4 minutes, once), the "See you tomorrow"
-- card, and the one name for the things you drop (balls, merge). The Studio pass covers the drawn lines.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.GrowthCoach)(PlayerScripts.Client)
return function(client)
	local Cards=require(client.CoachCards)
	local Notices=require(client.NoticeCards)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Coach=require(Shared.CoachMarks)
	local UICopy=require(Shared.UICopy)
	local Flags=require(Shared.FeatureFlags)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function ctx(extra)
		local c={mode="Room",canRoam=true,open={},windowActive=true,idleFor=.1,awayFor=0,owned=1,mask=0,seen={},totalWins=0,revealPending=false}
		for k,v in pairs(extra or {})do c[k]=v end
		return c
	end
	local settled=Coach.GardenSettle

	test("the three switches are on for the hotfix",function()
		assert(Flags.TomorrowStrip==true and Flags.GardenTourCut==true and Flags.StarterBonus==true)
	end)

	test("say-hi copy per input, the paw, no card behind it, 12 s at most",function()
		assert(Cards.sayHiKey("Touch")=="coach.sayHi.touch"and Cards.sayHiKey("Gamepad")=="coach.sayHi.pad"and Cards.sayHiKey("Keyboard")=="coach.sayHi.key"and Cards.sayHiKey(nil)=="coach.sayHi.key")
		assert((Cards.copy("sayHi",{pet="Bear",input="Touch"}))=="Tap Bear to say hi")
		assert((Cards.copy("sayHi",{pet="Bear",input="Keyboard"}))=="Press E near Bear to say hi")
		assert((Cards.copy("sayHi",{pet="Bear",input="Gamepad"}))=="Press X near Bear to say hi")
		local line=Cards.railLine("sayHi","sayHi",{pet="Bear",input="Touch"},false)
		assert(line.kitIcon=="paw"and line.kind=="info"and line.notice==nil and line.help==nil and line.icon==nil)
		assert(Cards.SayHiSeconds==12 and Cards.Spec.sayHi.icon=="paw"and Cards.Spec.sayHi.tint=="companions")
	end)

	test("say-hi starts where the tour would, minus the stand-still wait",function()
		assert(Cards.sayHiMayStart(ctx(),settled),"walking is fine")
		assert(not Cards.beatMayStart(ctx(),settled,false),"the old tour waited for a still player")
		assert(not Cards.sayHiMayStart(ctx(),settled-.1),"after the greeting settles")
		assert(not Cards.sayHiMayStart(ctx({open={hatch=true}}),10),"never over a menu")
		assert(not Cards.sayHiMayStart(ctx({canRoam=false}),10),"not on the deck")
		assert(not Cards.sayHiMayStart(ctx({revealPending=true}),10),"not over the reveal")
		assert(not Cards.sayHiMayStart(ctx({awayFor=Cards.AwaySeconds}),10),"not while away")
		assert(not Cards.sayHiMayStart(ctx({mask=Coach.with(0,"gardenIntro")}),10),"a save that finished the tour")
		assert(not Cards.sayHiMayStart(ctx({totalWins=Coach.VeteranWins}),10),"a veteran")
		assert(not Cards.sayHiMayStart(ctx({owned=0}),10),"no pet yet")
	end)

	test("the Tomorrow line: onboarding done, free garden, after results or 4 minutes, once",function()
		local done=Coach.with(0,"gardenIntro")
		local due={sawResults=true}
		assert(Cards.tomorrowReady(ctx({mask=done}),settled,due))
		assert(Cards.tomorrowReady(ctx({totalWins=Coach.VeteranWins}),settled,due),"veterans see it too")
		assert(not Cards.tomorrowReady(ctx(),settled,due),"the garden step goes first")
		assert(not Cards.tomorrowReady(ctx({mask=done}),settled,{sessionFor=60}),"too early")
		assert(Cards.tomorrowReady(ctx({mask=done}),settled,{sessionFor=240}),"4 minutes in")
		assert(not Cards.tomorrowReady(ctx({mask=done}),settled,{sawResults=true,shown=true}),"once a session")
		assert(not Cards.tomorrowReady(ctx({mask=done,mode="Board"}),settled,due),"never over a round")
		assert(not Cards.tomorrowReady(ctx({mask=done,open={quests=true}}),settled,due),"never over a menu")
		assert(not Cards.tomorrowReady(ctx({mask=done,revealPending=true}),settled,due),"never over a reveal")
		assert(not Cards.tomorrowReady(ctx({mask=done}),settled-.5,due),"after the garden settles")
		local go=Notices.go("tomorrow")
		assert(Notices.has("tomorrow")and go and go.target=="quests"and go.text==UICopy.get("notice.go.quests"))
		assert(Notices.title("tomorrow")=="See you tomorrow")
		assert(UICopy.get("notice.tomorrow.next")==UICopy.get("stamp.promise"),"the card's promise is the stamp card's")
	end)

	test("one name: the things you drop are balls, the verb is merge",function()
		assert(UICopy.get("qa.coach.welcome")=="Merge balls. Hatch a friend.")
		assert(UICopy.get("notice.welcome.what")=="Drop balls into the deck. Two of the same kind merge into a bigger one.")
		assert(UICopy.get("notice.fillLine.next")=="Merge to make room, and drop each ball next to its match.")
		assert(UICopy.get("onboarding.welcome.match")=="Merge")
		assert(UICopy.get("onboarding.welcome.egg")=="Mystery egg","the real egg keeps its name")
	end)

	return {passed=#cases,cases=cases}
end
