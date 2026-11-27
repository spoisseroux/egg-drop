-- The welcome gift on "You're all set!" (ONBOARDING-V3-BRIEF section 3; AllSetCard, Onboard "allset2"): the pill's
-- clock (never before the stamps are done, a late answer kept up a little longer, too late shows nothing), the 0 -> 5
-- roll-up with a blip a Star and stars_total at 5, the card's growth, the words, and a card that never waits for it.
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

	test("an early answer waits for the stamps; the count rolls 0 -> 5 over Gift.roll s; the card grows 28 px",function()
		local arrived=.2
		assert(Card.giftAt(arrived)==Card.T.gift and Card.T.gift>Card.T.stamps[3],"never before the third stamp")
		assert(Card.giftCount(.9,arrived,5)==nil and Card.giftCount(Card.T.gift,arrived,5)==0)
		local seen={}
		for i=0,80 do local n=Card.giftCount(Card.T.gift+i*.01,arrived,5);if n then seen[n]=true end end
		for n=0,5 do assert(seen[n],"shows "..n)end
		assert(Card.giftCount(Card.T.gift+Card.Gift.roll,arrived,5)==5 and Card.giftCount(4,arrived,5)==5)
		assert(Card.giftCount(Card.T.gift,arrived,5,true)==5,"Reduced Motion: at once")
		assert(near(Card.giftScale(Card.T.gift,arrived),Card.Gift.popFrom)and Card.giftScale(Card.T.gift+1,arrived)==1)
		assert(Card.giftGrow(Card.T.gift,arrived)==0 and near(Card.giftGrow(Card.T.gift+1,arrived),Card.Gift.grow))
		assert(Card.Size.h+Card.Gift.grow<=Card.Size.maxH,"the grown card fits its size cap")
		assert(Card.life(arrived)==math.max(Card.T.life,Card.T.gift+Card.Gift.hold))
	end)

	test("a late answer keeps the card up Gift.hold s more (at most T.lifeMax); after the card's end it shows nothing",function()
		assert(near(Card.life(3.5),3.5+Card.Gift.hold)and Card.life(4.9)==Card.T.lifeMax)
		assert(Card.giftCount(3.5,3.5,5)==0 and Card.giftCount(Card.T.lifeMax-.01,4.9,5)==5)
		assert(Card.life(Card.T.life)==Card.T.life and Card.giftCount(6,Card.T.life,5)==nil,"too late: no gift, no longer card")
	end)

	test("the cues: one count_blip a Star, rising, and stars_total once on reaching the total",function()
		local all={}
		local before=nil
		for _,n in ipairs({0,0,1,3,3,5,5})do
			for _,cue in ipairs(Card.giftCues(before,n,5))do table.insert(all,cue)end
			before=n
		end
		local blips,totals=0,0
		for _,cue in ipairs(all)do if cue.cue=="count_blip"then blips+=1 elseif cue.cue=="stars_total"then totals+=1 end end
		assert(blips==5 and totals==1,blips.." blips, "..totals.." totals")
		assert(all[1].speed<all[5].speed,"each a little higher")
		assert(#Card.giftCues(5,5,5)==0 and #Card.giftCues(nil,nil,5)==0)
	end)

	test("the words and the server's number agree",function()
		assert(UICopy.get("onbAllSet.gift",{count=Gift.Bonus})=="+5 ★ Welcome gift!")
		assert(UICopy.get("onbAllSet.gift",{count=0})=="+0 ★ Welcome gift!")
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
