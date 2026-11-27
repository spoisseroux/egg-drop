-- The welcome gift on "You're all set!" (ONBOARDING-V3-BRIEF section 3; AllSetCard, Onboard "allset2"): the pill's
-- clock (never before the stamps are done, a late answer kept up a little longer, too late shows nothing), the five
-- Stars flying in from the headshot (the onboarding fun pass) with a rising `charge` each and stars_total at 5, the
-- pill's punch, the card's growth, the words, and a card that never waits for it.
-- Offline: scripts/run_dash_server_specs.py (client). Studio: require(PlayerScripts.Client.ZZSpecs.AllSetGift)(Client).
return function(client)
	local Card=require(client.AllSetCard)
	local UICopy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
	local Gift=require(game:GetService("ReplicatedStorage").Shared.WelcomeGift)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,e)return type(a)=="number"and math.abs(a-b)<=(e or 1e-6)end

	test("no gift (refused, slow, never asked): the card's clock is today's, 5 s, nothing shown",function()
		assert(Card.life(nil)==Card.T.life and Card.giftCount(3,nil,5)==nil and Card.giftScale(3,nil)==nil and Card.giftGrow(3,nil)==0)
		assert(Card.over(Card.T.life,Card.life(nil))and not Card.over(4.9,Card.life(nil)))
	end)

	test("an early answer waits for the stamps (0.9 s); five Stars fly from the headshot one by one, each counting one; the card grows",function()
		local arrived=.2
		assert(Card.T.gift==.9,"the fun pass: at 0.9 s")
		assert(Card.giftAt(arrived)==Card.T.gift and Card.T.gift>Card.T.stamps[3]+Card.T.stamp,"never before the third stamp")
		assert(Card.giftCount(.89,arrived,5)==nil and Card.giftCount(Card.T.gift,arrived,5)==0)
		local at=Card.T.gift
		-- Star i lands at at + (i-1) * gap + fly, and the pill shows i
		for i=1,5 do
			local land=Card.giftLand(i,at)
			assert(near(land,at+(i-1)*Card.Gift.gap+Card.Gift.fly),"lands "..i)
			assert(Card.giftCount(land-.001,arrived,5)==i-1 and Card.giftCount(land,arrived,5)==i,"counts "..i)
			assert(Card.giftStar(i,land-.01,arrived,5)~=nil and Card.giftStar(i,land,arrived,5)==nil,"in the air, then landed")
			assert(Card.giftStar(i,at+(i-1)*Card.Gift.gap-.01,arrived,5)==nil,"not before its launch")
		end
		assert(Card.Gift.gap==.08 and Card.giftStar(6,at+.5,arrived,5)==nil,"five fly for five")
		assert(Card.giftCount(4,arrived,5)==5 and Card.giftCount(Card.T.gift,arrived,5,true)==5,"Reduced Motion: at once")
		assert(Card.giftStar(1,at+.1,arrived,5,true)==nil,"Reduced Motion: no flight")
		-- the path: the headshot to the pill, fanned out between
		local from,to=Vector2.new(160,0),Vector2.new(160,150)
		assert(Card.giftPath(1,5,0,from,to)==from and(Card.giftPath(5,5,1,from,to)-to).Magnitude<1e-4)
		assert(Card.giftPath(1,5,.5,from,to).X<Card.giftPath(5,5,.5,from,to).X,"fanned out")
		-- the pill pops in, then punches 1.3 as the last lands
		assert(near(Card.giftScale(Card.T.gift,arrived,false,5),Card.Gift.popFrom))
		local last=Card.giftLand(5,at)
		local peak=0
		for i=0,30 do peak=math.max(peak,Card.giftScale(last+i*.01,arrived,false,5)or 0)end
		assert(near(peak,Card.Gift.punch,.02),"the punch: "..peak)
		assert(Card.giftScale(last+Card.Gift.punchTime+.01,arrived,false,5)==1 and Card.giftScale(last+.1,arrived,true,5)==1)
		assert(Card.giftGrow(Card.T.gift,arrived)==0 and near(Card.giftGrow(Card.T.gift+1,arrived),Card.Gift.grow))
		assert(Card.Size.h+Card.Gift.grow<=Card.Size.maxH,"the grown card fits its size cap")
		assert(Card.life(arrived)==math.max(Card.T.life,Card.T.gift+Card.Gift.hold))
		assert(last<Card.T.gift+Card.Gift.hold,"every Star lands before the card goes")
	end)

	test("a late answer keeps the card up Gift.hold s more (at most T.lifeMax); after the card's end it shows nothing",function()
		assert(near(Card.life(3.5),3.5+Card.Gift.hold)and Card.life(4.9)==Card.T.lifeMax)
		assert(Card.giftCount(3.5,3.5,5)==0 and Card.giftCount(Card.T.lifeMax-.01,4.9,5)==5)
		assert(Card.life(Card.T.life)==Card.T.life and Card.giftCount(6,Card.T.life,5)==nil,"too late: no gift, no longer card")
	end)

	test("the cues: a `charge` a Star landed, rising, and stars_total once on reaching the total",function()
		local all={}
		local before=nil
		for _,n in ipairs({0,0,1,3,3,5,5})do
			for _,cue in ipairs(Card.giftCues(before,n,5))do table.insert(all,cue)end
			before=n
		end
		local charges,totals=0,0
		for _,cue in ipairs(all)do if cue.cue=="charge"then charges+=1 elseif cue.cue=="stars_total"then totals+=1 end end
		assert(charges==5 and totals==1,charges.." charges, "..totals.." totals")
		assert(all[1].speed<all[5].speed,"each a little higher")
		assert(#Card.giftCues(5,5,5)==0 and #Card.giftCues(nil,nil,5)==0)
	end)

	test("the words and the server's number agree",function()
		assert(UICopy.get("onbAllSet.gift",{count=Gift.Bonus})=="+5 ★ Welcome gift!")
		assert(UICopy.get("onbAllSet.gift",{count=0})=="+0 ★ Welcome gift!")
		assert(UICopy.get("onbAllSet.giftSub",{pet="Bear"})=="A welcome gift from Bear.")
	end)

	test("gift(stars) on a card: only while it is up and before its own end, once",function()
		local fake=setmetatable({open=true,t=1.5},Card)
		assert(fake:gift(5)and fake.giftArrived==1.5 and fake.giftStars==5)
		assert(not fake:gift(5)and fake.giftArrived==1.5,"once")
		local late=setmetatable({open=true,t=Card.T.life},Card);assert(not late:gift(5)and late.giftArrived==nil)
		local closed=setmetatable({open=false,t=1},Card);assert(not closed:gift(5))
	end)

	return {passed=#cases,cases=cases}
end
