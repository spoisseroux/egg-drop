-- Things to do's learn rows (beta 44: artifacts/qa-2026-11-28-beta44/ONBOARD-SIMPLIFY-BRIEF.md section 4, ARCH-REVIEW-SIMPLIFY
-- 9 and 11; Spencer's notes 13, 14 and 24): Customize, Dress up, Finish quests, the book and Deck style, each ticked from a
-- latch or a saved fact (never a client-only latch), the done ones below the undone ones with their button kept; no
-- learn rows without `teach`; no Play Den row; the Show me ring's way through the pet screen; the window focus rule.
-- Offline: scripts/run_dash_server_specs.py. Studio: require(PlayerScripts.Client.ZZSpecs.ThingsLearn)(PlayerScripts.Client).
return function(client)
	local Page=require(client.ThingsPage)
	local Wiring=require(client.TeachWiring)
	local Focus=require(client.WindowFocus)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Teach=require(Shared.TeachMarks)
	local Coach=require(Shared.CoachMarks)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function ids(rows)local out={};for _,r in ipairs(rows)do table.insert(out,r.id)end;return table.concat(out,",")end

	test("ticks: each from its latch or saved fact (ARCH-REVIEW-SIMPLIFY 9)",function()
		local none=Page.learn({},{})
		for _,id in ipairs(Page.LearnOrder)do assert(none[id].done==false,id)end
		assert(Page.learn({teachMask=Teach.with(0,"dress")}).customize.done,"lesson A's latch")
		assert(Page.learn({petHues={pip={main={rose=1}}}}).customize.done,"paint on a pet")
		assert(Page.learn({},{teachMask=Teach.with(0,"dress")}).customize.done,"this session's latch")
		assert(Page.learn({petWearables={pip={equipped={hat="beret"}}}}).dress.done,"a wearable saved as equipped")
		assert(not Page.learn({petWearables={pip={equipped={}}},teachMask=Teach.with(0,"wardrobe")}).dress.done,"never the client-only wardrobe latch")
		assert(Page.learn({coachMask=Coach.bit("questDone")}).quests.done and Page.learn({lastQuestClaim={id="q"}}).quests.done)
		assert(Page.learn({},{coachMask=Coach.bit("book")}).book.done and Page.learn({coachMask=Coach.bit("style")}).style.done)
		local q=Page.learn({quests={daily={{ready=true},{claimed=true},{ready=false}}}}).quests
		assert(q.count==2 and q.total==3,"2/3 today")
		local s=Page.learn({faceplates={}}).style;assert(s.owned==0 and s.total>0)
	end)

	test("rows: in the brief's order after the deck, the done ones below the undone; none without teach; no den",function()
		local learn=Page.learn({})
		local rows=Page.rows({learn=learn,park=true})
		assert(ids(rows)=="deck,customize,dress,quests,book,style,park","the order: "..ids(rows))
		learn.customize.done=true;learn.book.done=true
		rows=Page.rows({learn=learn,park=true})
		assert(ids(rows)=="deck,dress,quests,style,customize,book,park","ticked ones drop: "..ids(rows))
		for _,r in ipairs(rows)do
			if r.id=="customize"then assert(r.tick==true and r.button~=nil,"ticked, button kept")end
			if r.id=="dress"then assert(r.tick==false)end
		end
		assert(ids(Page.rows({park=true}))=="deck,park","teach off (no learn facts): as built")
		assert(not string.find(ids(Page.rows({den=true,learn=learn})),"den"),"note 24: no Play Den row")
		local gift=Page.rows({gift="paint",learn=learn});assert(gift[1].id=="gift"and gift[2].id=="deck","a waiting gift still leads")
		local dash=Page.rows({learn=learn,dash={phase="idle"}});assert(dash[#dash].id=="dash","the race stays last")
	end)

	test("Show me (ARCH-REVIEW-SIMPLIFY 11): Dress up first, then the Colour or Outfit tab; done on the tab",function()
		assert(Wiring.showTarget("customize",{hueOpen=false})=="dressUp")
		assert(Wiring.showTarget("customize",{hueOpen=true,tab="finish"})=="tab")
		assert(Wiring.showTarget("customize",{hueOpen=true,tab="hue"})=="tab","the Colour tab is first: ringed a moment (ColourSeen)")
		assert(Wiring.showTarget("dress",{hueOpen=true,tab="hue"})=="tab")
		assert(Wiring.showTarget("dress",{hueOpen=true,tab="outfit"})=="done"and Wiring.showTarget("dress",{hueOpen=true,wardrobe=true})=="done")
		assert(Wiring.ShowFor==12 and Wiring.AllSetAfter==.6)
	end)

	test("the window's focus (note 13): lost on release, back on focus or any input",function()
		assert(Focus.after(true,"lost")==false and Focus.after(false,"gained")==true and Focus.after(false,"input")==true)
		assert(Focus.after(false,"other")==false and Focus.after(true,"other")==true)
	end)

	return{passed=#cases,cases=cases}
end
