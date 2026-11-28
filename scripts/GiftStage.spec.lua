-- The free egg's reveal on the regular full-screen hatch stage (GiftStage; beta 42 note 5, DIAGNOSIS A5; Onboard
-- "gifts"): the Paint gift plays the Paint Egg's hatch (recipe "hue", its pot), the Toy gift the Toy Egg's (recipe
-- "toy"), the Snack gift never comes here (the Stat Egg's own reveal); the sticker "A gift from {pet}!", the gift's
-- odds line, the keys Paint {pet}! / Play! and Later; one choice, the callbacks once and in order (act at the press;
-- landed, seen and closed once the stage has left); a stage lost any other way still says closed, never seen.
-- Pure, no screen. Offline: scripts/run_dash_server_specs.py. Studio: require(PlayerScripts.Client.ZZSpecs.GiftStage)(PlayerScripts.Client).
return function(client)
	local Stage=require(client.GiftStage)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function text(key,vars)
		local s=key
		for k,v in pairs(vars or {})do s..="|"..k.."="..tostring(v)end
		return s
	end

	test("the result and recipe: a Paint gift is the Paint Egg's pot, a Toy gift the Toy Egg's toy; nothing else",function()
		local r,recipe=Stage.result({kind="paint",item="rose",id="g1"})
		assert(recipe=="hue"and r.itemId=="rose"and r.id=="gift:g1"and r.toyId==nil)
		r,recipe=Stage.result({kind="toy",item="ball",id=7})
		assert(recipe=="toy"and r.toyId=="ball"and r.id=="gift:7")
		r=Stage.result({kind="paint",item="tide"});assert(r.id=="gift:paint:tide","no id: kind and item")
		assert(Stage.result({kind="snack",item="x"})==nil,"the Snack gift plays the Stat Egg's reveal")
		assert(Stage.result({kind="paint"})==nil and Stage.result(nil)==nil)
	end)

	test("the words: the sticker is the gift tag, the line its odds, the keys the card's",function()
		local w=Stage.words({kind="paint",item="rose"},{text=text,pet="Bear",itemName="Rose"})
		assert(w.sticker=="onbGift.card.from|pet=Bear"and w.secondary=="onbGift.card.later")
		assert(w.name=="onbGift.card.pot|name=Rose"and w.detail=="onbGift.card.potOdds"and w.primary=="onbGift.card.paint|pet=Bear")
		w=Stage.words({kind="paint",item="rose"},{text=text,pet="Bear",itemName="Rose",deeper=true})
		assert(w.name=="onbGift.card.deeper|name=Rose","a pot it already wears: Deeper")
		w=Stage.words({kind="toy",item="ball"},{text=text,pet="Bear",itemName="Ball",poolSize=3})
		assert(w.name=="Ball"and w.detail=="onbGift.card.toyOdds|count=3"and w.primary=="onbGift.card.play")
	end)

	test("one choice: Paint acts at the press, then landed, seen and closed once the stage has left; a second press nothing",function()
		local log={}
		local rec={kind="paint",item="rose",id="g"}
		local leaving=nil
		local f=Stage.flow(rec,{act=function(r)table.insert(log,"act:"..r.item)end,landed=function()table.insert(log,"landed")end,
			seen=function()table.insert(log,"seen")end,closed=function()table.insert(log,"closed")end},function(acted)leaving=acted end)
		assert(f.choose(true)and leaving==true and table.concat(log,",")=="act:rose","the act at the press (lesson A's hand-off)")
		assert(not f.choose(false)and not f.choose(true),"one choice")
		f.finish();f.finish()
		assert(table.concat(log,",")=="act:rose,landed,seen,closed","then the rest, once")
	end)

	test("Later (or the x): no act, no landed; seen and closed; a stage lost without a choice: closed only (it replays)",function()
		local log={}
		local opts={act=function()table.insert(log,"act")end,landed=function()table.insert(log,"landed")end,
			seen=function()table.insert(log,"seen")end,closed=function()table.insert(log,"closed")end}
		local f=Stage.flow({kind="toy",item="ball"},opts,function()end)
		f.choose(false);f.finish()
		assert(table.concat(log,",")=="seen,closed")
		table.clear(log)
		local g=Stage.flow({kind="paint",item="rose"},opts,function()end)
		g.finish("lost");g.finish()
		assert(table.concat(log,",")=="closed","the camera and the chain still hear it; never seen")
		assert(not g.choose(true)and #log==1,"gone: no choice after")
		-- a callback that throws never stops the rest
		table.clear(log)
		local h=Stage.flow({kind="paint",item="rose"},{act=function()error("boom")end,seen=function()table.insert(log,"seen")end,
			closed=function()table.insert(log,"closed")end},function()end)
		h.choose(true);h.finish()
		assert(table.concat(log,",")=="seen,closed")
	end)

	test("closed: nothing open until a stage shows",function()
		assert(Stage.isOpen()==false)
		assert(Stage.IrisShut<Stage.Teardown and Stage.ReducedShut<Stage.IrisShut,"the callbacks run under the shut iris, before the gui goes")
	end)

	return {passed=#cases,cases=cases}
end
