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

	return {passed=#cases,cases=cases}
end
