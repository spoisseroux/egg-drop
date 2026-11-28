-- The Hatch eggs screen's gift mode (GiftShop; ONBOARDING-P2-BRIEF section 1, ARCH-REVIEW-P2 section 2; Onboard "gifts"):
-- only the server's ready gift, never given, no unseen card first; the gift branch first and latched until the chain's
-- done (never a send, never a paid buy page); the switch going off drops it. Pure, no screen.
-- Offline: scripts/run_dash_server_specs.py. Studio: require(PlayerScripts.Client.ZZSpecs.GiftShop)(PlayerScripts.Client).
return function(client)
	local Shop=require(client.GiftShop)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local order={"toy","look","stat"}
	local function state(g)return{nectar=0,gifts=g}end

	test("mode: only a ready gift, never given, no unseen card, its tile on the list; off: nothing",function()
		assert(Shop.mode("paint",state({owed=true,ready="paint",granted={}}),order)=="paint")
		assert(Shop.mode("toy",state({owed=true,ready="toy",granted={paint=true}}),order)=="toy")
		assert(Shop.mode("snack",state({owed=true,ready="snack",granted={paint=true}}),order)=="snack")
		assert(Shop.mode("paint",state({owed=true,ready="toy",granted={}}),order)==nil,"not the ready one")
		assert(Shop.mode("paint",state({owed=true,ready="paint",granted={paint=true}}),order)==nil,"given: the paid egg is back")
		assert(Shop.mode("paint",state({owed=true,ready="paint",granted={},unseen={kind="toy"}}),order)==nil,"an unseen card replays first")
		assert(Shop.mode("paint",state(nil),order)==nil and Shop.mode(nil,state({ready="paint"}),order)==nil,"the switch off: no gift mode")
		assert(Shop.mode("snack",state({owed=true,ready="snack",granted={}}),{"toy","look"})==nil,"no tile: no gift mode")
		assert(Shop.Tile.paint=="look"and Shop.Tile.toy=="toy"and Shop.Tile.snack=="stat")
	end)

	test("route: the gift branch first and only on its tile; latched: nothing at all; another tile: today's press",function()
		assert(Shop.route({gift="paint",selected="look"})=="gift")
		assert(Shop.route({gift="paint",selected="toy"})=="normal","another egg: its own pane, still buys")
		assert(Shop.route({gift="paint",selected="look",lastHatch={}})=="normal","a hatch result is up: its own buttons")
		assert(Shop.route({latch="paint",gift="paint",selected="look"})=="latched","a second press while the ask is out: nothing")
		assert(Shop.route({latch="paint",gift=nil,selected="look"})=="latched","given before the answer: still nothing (never a paid buy)")
		assert(Shop.route({selected="look"})=="normal","no gift: as before")
	end)

	test("the latch: held until done; the switch off or no answer for Latch s lets go",function()
		local g=state({owed=true,ready="paint",granted={}})
		assert(Shop.held({at=10},g,10+Shop.Latch)and not Shop.held({at=10},g,10+Shop.Latch+.1))
		assert(not Shop.held({at=10},state(nil),11),"gifts off mid-chain: the latch clears")
		assert(not Shop.held(nil,g,11))
		assert(Shop.held({at=10},state({owed=true,granted={paint=true}}),12),"given: held until the chain's done")
	end)

	test("a simulated screen: two presses send one ask and never a buy; done lets the next press through",function()
		-- the same order EggHatchView:actPrimary runs (route, then the gift ask or today's press)
		local asks,buys=0,0
		local view={gift="paint",selected="look",latch=nil}
		local pending
		local function press()
			local r=Shop.route({latch=view.latch,gift=view.gift,selected=view.selected})
			if r=="latched"then return r end
			if r=="gift"then view.latch="paint";asks+=1;pending=function()view.latch=nil end;return r end
			buys+=1;return r
		end
		assert(press()=="gift"and press()=="latched"and asks==1 and buys==0)
		view.gift=nil -- the snapshot now says given
		assert(press()=="latched"and buys==0,"still latched: the paid egg waits for the answer")
		pending()
		assert(press()=="normal"and buys==1,"after the answer the paid egg is the paid egg again")
	end)

	-- Beta 42 note 4: "when we click paint egg, it should move the hand to point us to click hatch egg then".
	test("beta 42: the first tap on the gift's tile only picks it; the pointer goes to Hatch free!, whose press is the ask",function()
		assert(Shop.route({gift="paint",selected="look",tile=true})=="pick","the first tap on its tile: picked, no ask")
		assert(Shop.route({gift="paint",selected="look",tile=true,picked=true})=="gift","a second tap on it: the ask")
		assert(Shop.route({gift="paint",selected="look"})=="gift","Hatch free! (the pane's button) asks at once")
		assert(Shop.route({gift="paint",selected="toy",tile=true})=="normal","another tile: today's tap")
		assert(Shop.route({latch="paint",gift="paint",selected="look",tile=true})=="latched")
		assert(Shop.aim({gift="paint",selected="look"})=="tile","opened on the gift: the tile")
		assert(Shop.aim({gift="paint",selected="look",picked=true})=="hatch","picked: Hatch free!")
		assert(Shop.aim({gift="paint",selected="toy",picked=true})=="tile","browsed away: back to the tile")
		assert(Shop.aim({gift="paint",selected="look",picked=true,latch="paint"})==nil,"the ask is out: no pointer")
		assert(Shop.aim({gift="paint",selected="look",lastHatch={}})==nil and Shop.aim({selected="look"})==nil)
		-- a simulated screen (EggHatchView:pickGift, then actPrimary): tap, tap; tap, Hatch free!; reopen clears
		local view={gift="paint",selected="look",picked=nil,serial=1,pickSerial=1}
		local asks,bounces=0,0
		local function refresh()if view.pickSerial~=view.serial then view.pickSerial=view.serial;view.picked=nil end end
		local function tapTile(id)
			refresh()
			if Shop.route({gift=view.gift,selected=id,tile=true,picked=view.picked,latch=view.latch})=="pick"then
				view.picked=true;view.selected=id;bounces+=1;return "pick"
			end
			if view.selected~=id then view.selected=id;return "select"end
			if Shop.route({gift=view.gift,selected=view.selected,latch=view.latch})=="gift"then asks+=1;view.latch="paint"end
			return "press"
		end
		assert(tapTile("look")=="pick"and asks==0 and bounces==1 and Shop.aim({gift="paint",selected=view.selected,picked=view.picked})=="hatch")
		assert(tapTile("look")=="press"and asks==1,"the second tap hatches")
		view.latch=nil;view.serial=2 -- closed and opened again
		refresh();assert(view.picked==nil and Shop.aim({gift="paint",selected="look",picked=view.picked})=="tile","reopen: the tile again")
		assert(tapTile("toy")=="select"and tapTile("look")=="pick","from another tile: the tap on the gift picks it")
	end)

	return {passed=#cases,cases=cases}
end
