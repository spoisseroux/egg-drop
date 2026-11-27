-- Paint, Shine, Dress, the client (PAINT-SHINE-DRESS-PLAN): the door's switch and tabs (DressUp), the Colour tab's
-- cards and acts (PaintPanel), and the pot intent (PaintPotIntent). Beta (38), gacha only: pots come only from the
-- Paint Egg, so a swatch with no pot is locked (previewed, "Hatch a Paint Egg"), nothing shows a price, nothing buys.
-- Offline: scripts/run_dash_server_specs.py (client). Studio: require(PlayerScripts.Client.ZZSpecs.DressUp)(Client).
return function(client)
	local DressUp=require(client.DressUp)
	local Panel=require(client.PaintPanel)
	local Intent=require(client.PaintPotIntent)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Pots=require(Shared.PaintPotCatalog)
	local Alive=require(Shared.Alive)
	local Copy=require(Shared.UICopy)
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

	test("cards: ten swatches; paint with a pot, locked without one (Hatch a Paint Egg), full at 5; a mix paints its lower pot",function()
		local cards=Panel.cards(state(),"pip","main",true);assert(#cards==10)
		local byId={};for _,c in ipairs(cards)do byId[c.id]=c end
		assert(byId.tide.action=="paint"and byId.tide.enabled and byId.tide.pips==1 and byId.tide.stock==2 and not byId.tide.locked)
		local rose=byId.rose
		assert(rose.action=="hatch"and rose.locked and rose.enabled and rose.button=="Hatch a Paint Egg","locked: "..tostring(rose.button))
		assert(rose.line=="Win it from a Paint Egg."and rose.status=="0/5 · Locked",rose.line.." / "..rose.status)
		local green=byId["citrus:tide"];assert(green.mix and green.pot=="citrus"and green.action=="paint"and green.pips==0)
		local violet=byId["rose:tide"];assert(violet.pot=="rose"and violet.action=="hatch"and violet.locked and string.find(violet.line,"Pink pot",1,true),violet.line)
		local full=state();full.petHues.pip.main.tide=5
		assert(Panel.card("tide",full,"pip","main",true).action=="full"and not Panel.card("tide",full,"pip","main",true).enabled)
		assert(not Panel.card("tide",state(),"pip","main",false).enabled and not Panel.card("rose",state(),"pip","main",false).enabled,"not ready: nothing enabled")
		-- the wallet never matters: a locked swatch is the same with no Stars or a fortune
		local poor,rich=Panel.card("rose",state({nectar=0}),"pip","main",true),Panel.card("rose",state({nectar=99999}),"pip","main",true)
		assert(poor.action=="hatch"and poor.enabled and rich.action=="hatch"and poor.line==rich.line and poor.button==rich.button)
		assert(Panel.painted(state(),"pip","main")and not Panel.painted(state(),"pip","secondary"))
	end)

	test("gacha only: no card, wallet or stock shows a price or a buy; the Colour words have no price or Buy in them",function()
		for _,wallet in ipairs({0,3,15,40,99999})do
			for _,stock in ipairs({0,1})do
				local s=state({nectar=wallet,hueInventory={rose=stock,tide=stock,citrus=stock,iris=stock,reset=0}})
				for _,channel in ipairs({"main","secondary"})do
					for _,c in ipairs(Panel.cards(s,"pip",channel,true))do
						assert(c.action~="buy","no buy action: "..c.id)
						for _,text in ipairs({c.button,c.line,c.status,c.name})do
							assert(type(text)=="string"and not string.find(text,"★",1,true)and not string.find(text,"Star",1,true)and not string.find(text,"Buy",1,true),c.id..": "..tostring(text))
						end
					end
				end
			end
		end
		local function walk(node,path)
			for key,value in pairs(node)do
				local at=path.."."..key
				if type(value)=="table"then walk(value,at)
				elseif type(value)=="string"then
					assert(not string.find(value,"{price}",1,true)and not string.find(value,"Buy",1,true),at.." still sells: "..value)
				end
			end
		end
		walk(Copy.Table.paint,"paint")
		assert(Copy.get("paint.hatch")=="Hatch a Paint Egg"and Copy.get("paint.lockedLine")=="Win it from a Paint Egg.")
		assert(Copy.get("paint.reason.NotSold")~="")
		assert(Pots.Sold==false,"the catalogue says pots are not sold")
	end)

	-- A fake hue intent and the real pot intent (replies only now).
	local function intents(s)
		local sent={}
		local hue={state=s,pending=nil,use=function(self,petId,channel,item,resultId)table.insert(sent,{"hueUse",petId,channel,item,resultId});return true end}
		local pot=Intent.new({id=function()return "g1"end,send=function(action,value,revision)table.insert(sent,{action,value,revision})end,defer=function(f,...)f(...)end})
		pot:update(s)
		return hue,pot,sent
	end

	test("act: paint is one hueUse on the pot the swatch needs; a pending egg jar of that pot is acknowledged",function()
		local s=state();local hue,_,sent=intents(s)
		assert(Panel.act(Panel.card("citrus:tide",s,"pip","main",true),{hue=hue},"pip","main",s))
		assert(#sent==1 and sent[1][1]=="hueUse"and sent[1][4]=="citrus"and sent[1][5]==nil)
		s.pendingHueResult={id="r1",itemId="tide"};hue.state=s
		assert(Panel.act(Panel.card("tide",s,"pip","main",true),{hue=hue},"pip","main",s))
		assert(sent[2][4]=="tide"and sent[2][5]=="r1")
	end)

	test("act: a locked swatch opens the Paint Egg (the hatch route) and sends nothing; no route, nothing happens",function()
		local s=state();local hue,_,sent=intents(s)
		local opened=0
		assert(Panel.act(Panel.card("rose",s,"pip","main",true),{hue=hue,hatch=function()opened+=1;return true end},"pip","main",s))
		assert(opened==1 and #sent==0,"the egg machine opened, no request went out")
		assert(not Panel.act(Panel.card("rose",s,"pip","main",true),{hue=hue},"pip","main",s)and #sent==0)
		assert(not Panel.act(Panel.card("rose",s,"pip","main",false),{hue=hue,hatch=function()opened+=1;return true end},"pip","main",s)and opened==1,"not ready")
	end)

	test("intent: buy is refused as NotSold and sends nothing, whatever the wallet; a stray reply with nothing pending is dropped",function()
		local s=state({nectar=99999});local _,pot,sent=intents(s)
		for _,item in ipairs(Pots.Items)do
			assert(Intent.blocked(s,item)=="NotSold")
			assert(not pot:buy(item,function()error("never chained")end))
		end
		assert(#sent==0 and pot.pending==nil and pot.reason=="NotSold"and pot.message==Copy.get("paint.reason.NotSold"))
		assert(not pot:receive({id="8:pot-g1",action="potBuy",status="Saved",receipt={id="8:pot-g1",revision=9,itemId="rose"}}))
		assert(not pot:retry())
	end)

	return {passed=#cases,cases=cases}
end
