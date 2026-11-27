-- Paint, Shine, Dress, the client (PAINT-SHINE-DRESS-PLAN): the door's switch and tabs (DressUp), the Colour tab's
-- cards and acts (PaintPanel), and the pot intent with its buy-then-paint chain (PaintPotIntent).
-- Offline: scripts/run_dash_server_specs.py (client). Studio: require(PlayerScripts.Client.ZZSpecs.DressUp)(Client).
return function(client)
	local DressUp=require(client.DressUp)
	local Panel=require(client.PaintPanel)
	local Intent=require(client.PaintPotIntent)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Pots=require(Shared.PaintPotCatalog)
	local Alive=require(Shared.Alive)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function state(extra)
		local s={revision=8,nectar=40,inventoryMask=1,status="Ready",hueInventory={rose=0,tide=2,citrus=1,iris=0,reset=0},
			petHues={pip={main={rose=0,tide=1,citrus=0,iris=0},secondary={rose=0,tide=0,citrus=0,iris=0}}}}
		for k,v in pairs(extra or {})do s[k]=v end
		return s
	end

	test("the switch: Alive paint, beta and Studio only; the forced seam; off and on tab rows",function()
		assert(table.find(Alive.Features,"paint")and Alive.ceiling("paint",{AlivePaint=true},107705084891479,false))
		assert(not Alive.ceiling("paint",{AlivePaint=true},96451847774961,false),"never on the live place")
		DressUp.forced=false;assert(DressUp.on()==false)
		DressUp.forced=true;assert(DressUp.on()==true)
		local tabs=DressUp.tabs();assert(#tabs==4)
		for i,id in ipairs({"hue","finish","outfit","charm"})do assert(tabs[i].id==id and type(tabs[i].label)=="string"and tabs[i].label~="")end
		assert(tabs[1].label=="Colour"and tabs[2].label=="Shine"and tabs[3].label=="Outfit"and tabs[4].label=="Charm")
		DressUp.forced=nil
	end)

	test("cards: ten swatches; paint with a pot, buy without one, full at 5; the mix paints its lower pot",function()
		local cards=Panel.cards(state(),"pip","main",true);assert(#cards==10)
		local byId={};for _,c in ipairs(cards)do byId[c.id]=c end
		assert(byId.tide.action=="paint"and byId.tide.enabled and byId.tide.pips==1 and byId.tide.stock==2)
		assert(byId.rose.action=="buy"and byId.rose.enabled and byId.rose.button==("Buy · "..Pots.Price.."★"))
		local green=byId["citrus:tide"];assert(green.mix and green.pot=="citrus"and green.action=="paint"and green.pips==0)
		local violet=byId["rose:tide"];assert(violet.pot=="rose"and violet.action=="buy")
		local full=state();full.petHues.pip.main.tide=5
		assert(Panel.card("tide",full,"pip","main",true).action=="full"and not Panel.card("tide",full,"pip","main",true).enabled)
		assert(not Panel.card("tide",state(),"pip","main",false).enabled,"not ready: nothing enabled")
		local poor=Panel.card("rose",state({nectar=3}),"pip","main",true)
		assert(poor.action=="buy"and not poor.enabled and string.find(poor.line,"12"),"short by 12: "..poor.line)
		assert(Panel.painted(state(),"pip","main")and not Panel.painted(state(),"pip","secondary"))
	end)

	-- A fake pair of intents.
	local function intents(s)
		local sent={}
		local hue={state=s,pending=nil,use=function(self,petId,channel,item,resultId)table.insert(sent,{"hueUse",petId,channel,item,resultId});return true end}
		local pot=Intent.new({id=function()return "g1"end,send=function(action,value,revision)table.insert(sent,{action,value,revision})end,defer=function(f,...)f(...)end})
		pot:update(s)
		return hue,pot,sent
	end

	test("act: paint is one hueUse on the pot the swatch needs; a pending egg jar of that pot is acknowledged",function()
		local s=state();local hue,pot,sent=intents(s)
		assert(Panel.act(Panel.card("citrus:tide",s,"pip","main",true),{hue=hue,pot=pot},"pip","main",s))
		assert(#sent==1 and sent[1][1]=="hueUse"and sent[1][4]=="citrus"and sent[1][5]==nil)
		s.pendingHueResult={id="r1",itemId="tide"};hue.state=s
		assert(Panel.act(Panel.card("tide",s,"pip","main",true),{hue=hue,pot=pot},"pip","main",s))
		assert(sent[2][4]=="tide"and sent[2][5]=="r1")
	end)

	test("buy and paint: two saves; the paint goes out only once the pot is saved and the snapshot has it",function()
		local s=state();local hue,pot,sent=intents(s)
		assert(Panel.act(Panel.card("rose",s,"pip","main",true),{hue=hue,pot=pot},"pip","main",s,function()return true end))
		assert(#sent==1 and sent[1][1]=="potBuy"and sent[1][2].itemId=="rose"and sent[1][2].price==Pots.Price and sent[1][2].id=="8:pot-g1")
		assert(pot.pending and not Panel.card("rose",s,"pip","main",false).enabled)
		-- Saved, but the snapshot is still revision 8: no paint yet.
		assert(pot:receive({id="8:pot-g1",action="potBuy",status="Saved",receipt={id="8:pot-g1",revision=9,itemId="rose"}}))
		assert(pot.pending and #sent==1)
		local after=state({revision=9,nectar=25});after.hueInventory.rose=1;hue.state=after
		pot:update(after)
		assert(not pot.pending and pot.status=="Saved"and #sent==2 and sent[2][1]=="hueUse"and sent[2][4]=="rose")
	end)

	test("intent: Retrying resends the same id; NotReady drops the buy and its chained paint; local blocks",function()
		local s=state();local hue,pot,sent=intents(s)
		local painted=false
		assert(pot:buy("iris",function()painted=true end))
		assert(pot:receive({id="8:pot-g1",action="potBuy",status="Retrying",reason="Busy"})and pot.status=="Retrying")
		assert(pot:retry()and #sent==2 and sent[2][2].id==sent[1][2].id)
		assert(pot:receive({id="8:pot-g1",action="potBuy",status="Rejected",reason="NotReady"}))
		assert(not pot.pending and pot.reason=="NotReady"and type(pot.message)=="string")
		pot:update(state({revision=9}));assert(not painted,"no paint after NotReady")
		assert(Intent.blocked(state({nectar=1}),"rose")=="NeedStars"and Intent.blocked(state(),"gloss")=="InvalidPot")
		assert(Intent.blocked(state({lastHatch={id="h"}}),"rose")=="RevealPending"and Intent.blocked(state(),"rose",{})=="Busy")
		assert(Intent.blocked(state(),"rose")==nil)
		local _=hue
	end)

	return {passed=#cases,cases=cases}
end
