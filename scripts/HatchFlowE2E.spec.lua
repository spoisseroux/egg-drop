-- Studio Client. End-to-end hatch flow (v842 phone bug: a Customization Egg landed with no egg
-- and no sound, and the next Toy Egg hatch reopened that jar). Drives the real client pieces
-- the game wires together: Hatch eggs (EggHatchView, its Hatch button through actPrimary),
-- HatchFlow (the direct hatch the game uses), HueIntent and ToyIntent, and the Customize /
-- receipt view (HueEggView) with its hatch reveals. Only the server is simulated: each
-- request is answered one frame later with the next owner snapshot, as the real host would.
-- For Customization, then Toy, then Customization again it checks: the hatch reveal plays
-- as a fresh hatch (the egg intro, not a still receipt), a hatch sound is asked for, the reveal
-- shows that egg's item (never another egg's waiting result), then the reveal closes.
-- Usage: require(PlayerScripts.Client.ZZSpecs.HatchFlowE2E)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Shop=require(client.EggHatchView);local View=require(client.HueEggView)
	local Hue=require(client.HueIntent);local Toy=require(client.ToyIntent);local Flow=require(client.HatchFlow)
	local Hues=require(Shared.HueCatalog);local Toys=require(Shared.ToyCatalog);local Look=require(Shared.LookEggCatalog)
	local Pets=require(Shared.PetCatalog)
	local Run=game:GetService("RunService")
	local cases={};local function test(name,run)run();table.insert(cases,name)end
	local function frames(n)for _=1,n or 3 do Run.Heartbeat:Wait()end end
	local gui=Instance.new("ScreenGui");gui.Name="_HatchFlowE2E";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
	local root=Instance.new("Frame");root.BackgroundTransparency=1;root.Size=UDim2.fromOffset(750,402);root.Parent=gui
	do local anchor=Instance.new("Frame");anchor.Parent=gui;require(client.DeckKit).screenProbe(anchor);anchor:Destroy()end
	-- Audio: records every cue the hatch asks for.
	local cues={}
	local audio=setmetatable({deviceActive=true,deviceEpoch=0,cues=cues},{__index=function(_,key)
		return function(_,name)if key=="play"then table.insert(cues,tostring(name))end end
	end})
	-- The simulated server: the owner snapshot and one reply per request.
	local S={status="Ready",revision=1,nectar=200,inventoryMask=1,petHues={},hueInventory=Hues.emptyCounts(),toyUnlocks={},petToys={},
		charmUnlocks={dot=true,ring=true,pebble=true},finishInventory={gloss=0,matte=0,jelly=0},petFinish={},lookCharmMisses=0,lookAvailable=true,
		materialAvailable=true,materialUnlocks={},petMaterials={}}
	for _,pet in ipairs(Pets.collection)do S.petHues[pet.id]={main=Hues.emptyCounts(),secondary=Hues.emptyCounts()}end
	local hue,toy,view,nursery,flow
	local serial,looks,log=0,{"rose","tide"},{}
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function publish()
		hue:update(copy(S));toy:update(copy(S));if nursery.shade.Visible then nursery:update(copy(S))end
		view:refresh();flow:sync()
	end
	local function serve(action,value)
		table.insert(log,action)
		task.defer(function()
			local before=S.nectar;S=copy(S);S.revision+=1;local r=S.revision
			if action=="lookBuy"then
				local item=table.remove(looks,1)or "iris"
				S.nectar-=Look.Price;S.hueInventory[item]=(S.hueInventory[item]or 0)+1
				S.pendingHueResult={id=value.id,itemId=item,quantity=1,inventoryAfter=S.hueInventory[item],catalogVersion=Hues.CatalogVersion,revision=r}
				S.lastHueResult={id=value.id,action="lookBuy",revision=r,outcome="Applied",petId=value.petId}
			elseif action=="hueStore"then
				S.pendingHueResult=nil;S.lastHueResult={id=value.id,action="hueStore",revision=r,outcome="Applied",petId=value.petId}
			elseif action=="toyBuy"then
				local id=value.eligible[1];S.nectar-=Toys.Cost;S.toyUnlocks[id]=true
				S.pendingToyResult={id=value.id,toyId=id,revision=r,catalogVersion=Toys.CatalogVersion}
				S.lastToyResult={id=value.id,action="toyBuy",resultId=value.id,toyId=id,revision=r,catalogVersion=Toys.CatalogVersion,cost=Toys.Cost,balanceBefore=before,balanceAfter=S.nectar}
			elseif action=="toyEquip"then
				local beforeToy=S.petToys[value.petId]or Toys.Default
				S.pendingToyResult=nil;S.petToys[value.petId]=value.toyId
				S.lastToyResult={id=value.id,action="toyEquip",revision=r,catalogVersion=Toys.CatalogVersion,cost=0,petId=value.petId,toyId=value.toyId,
					selectedBefore=beforeToy,selectedAfter=value.toyId,acknowledgedResultId=value.resultId,balanceBefore=before,balanceAfter=before}
			elseif action=="toyAck"then
				S.pendingToyResult=nil
				S.lastToyResult={id=value.id,action="toyAck",revision=r,catalogVersion=Toys.CatalogVersion,cost=0,acknowledgedResultId=value.resultId,balanceBefore=before,balanceAfter=before}
			end
			publish()
		end)
	end
	local ok,problem=xpcall(function()
		hue=Hue.new({id=function()serial+=1;return "e2e"..serial end,send=serve,changed=function()if view then view:refresh()end;if flow then flow:sync()end end})
		toy=Toy.new({id=function()serial+=1;return "e2e"..serial end,send=serve,delay=function()end,changed=function()if view then view:refresh()end;if flow then flow:sync()end end})
		view=View.new(root,hue,{toyIntent=toy,audio=audio,reduceEffects=function()return false end,activePet=function()return "pip"end,canCustomize=function()return true end})
		nursery=Shop.new(root,audio,function()return false end,function()return true end)
		flow=Flow.new({intents={hueIntent=hue,toyIntent=toy},state=function()return S end,view=view,
			openHue=function(page,petId)nursery:close("hue");view.quietOpen=false;return view:open(copy(S),page,petId or "pip")end})
		nursery.onOpenLook=function(p)flow:open("look",p)end;nursery.onOpenHue=function(p)flow:open("hue",p)end
		nursery.onOpenToy=function(p)flow:open("toy",p)end
		hue:update(copy(S));toy:update(copy(S))
		local function hatch(egg,expectPage,expectItem,label)
			table.clear(cues)
			nursery:open(copy(S));frames()
			assert(nursery:selectRecipe(egg),label..": "..egg.." is on Hatch eggs");frames()
			assert(Shop.hatchAction(egg,S).text:find("Hatch",1,true),label..": the "..egg.." button reads Hatch, not another egg's saved result ("..Shop.hatchAction(egg,S).text..")")
			nursery:actPrimary()
			-- Wait for the reply (and a quiet store first, if another egg's result waited).
			local t=os.clock()
			while not(view.shade.Visible and view.page==expectPage)and os.clock()-t<5 do frames(1)end
			assert(view.shade.Visible and view.page==expectPage,label..": the "..expectPage.." reveal never opened (page "..tostring(view.page)..", log "..table.concat(log,",")..")")
			local art=if expectPage=="toyReceipt"then view.toyPanel.art else view.receiptArt
			local reveal=if expectPage=="toyReceipt"then view.toyPanel.reveal else view.itemReveal
			if reveal.cinematic then reveal.cinematic.windowActive=true end -- the Studio window may be in the background
			assert(art:GetAttribute("HatchIntro")==true,label..": the reveal skipped the egg (a still receipt, the v842 bug)")
			assert(art:GetAttribute("RevealItem")==expectItem,label..": the reveal shows "..tostring(art:GetAttribute("RevealItem")).." not "..expectItem)
			assert(art:GetAttribute("RevealRecipe")==(if egg=="toy"then "toy"else "hue"),label..": wrong egg on the stage")
			if egg=="toy"then
				-- v850: a toy always offers Give to <pet> and Store (it was "Store" twice).
				assert(view.action.Text:find("Give to",1,true)and view.toyPanel.useNow.Text=="Store",label..": toy buttons read "..view.action.Text.." / "..view.toyPanel.useNow.Text)
			end
			t=os.clock();while #cues==0 and os.clock()-t<4 do frames(1)end
			assert(#cues>0,label..": the hatch asked for no sound")
			view:close("back");frames()
			assert(not view.shade.Visible,label..": the reveal did not close")
		end
		test("Customization Egg: a fresh hatch (egg, sound) with its own jar",function()
			hatch("look","receipt","rose","Customization 1")
			assert(S.pendingHueResult and S.pendingHueResult.itemId=="rose","the jar waits to be stored (closed without storing)")
		end)
		test("Toy Egg after it: the waiting jar is stored first, then the Toy Egg hatches its own toy",function()
			local firstToy=(function()local e=Toys.remaining(S.toyUnlocks);table.sort(e);return e[1]end)()
			hatch("toy","toyReceipt",firstToy,"Toy")
			assert(table.find(log,"hueStore")and table.find(log,"hueStore")<table.find(log,"toyBuy"),"the jar was stored before the toy was bought: "..table.concat(log,","))
			assert(S.hueInventory.rose==1 and not S.pendingHueResult,"the jar is in the inventory, not lost")
		end)
		test("the saved toy reopens with Give to <pet> and Store; Give hands it over; a second toy keeps both labels",function()
			local before=#log
			nursery:open(copy(S));frames();nursery:selectRecipe("toy");frames()
			assert(Shop.hatchAction("toy",S).text=="Open saved toy","the first toy is still saved")
			nursery:actPrimary()
			local w=os.clock();while not(view.shade.Visible and view.page=="toyReceipt")and os.clock()-w<3 do frames(1)end
			assert(view.page=="toyReceipt","the saved toy reopens")
			assert(view.action.Text:find("Give to",1,true)and view.toyPanel.useNow.Text=="Store","reopened toy buttons read "..view.action.Text.." / "..view.toyPanel.useNow.Text)
			assert(view:activate(),"Give to <pet> acts")
			w=os.clock();while S.pendingToyResult and os.clock()-w<3 do frames(1)end
			local found=false;for i=before+1,#log do if log[i]=="toyEquip"then found=true end end
			assert(found and not S.pendingToyResult,"Give sent a toyEquip for the active pet: "..table.concat(log,","))
			assert(not(view.shade.Visible and view.page=="palette"and view.tab=="pet"),"the old pet picker never shows")
			view:close("back");frames()
			local t=(function()local e=Toys.remaining(S.toyUnlocks);table.sort(e);return e[1]end)()
			hatch("toy","toyReceipt",t,"Toy 2")
		end)
		test("no active pet: the saved toy offers Store only (no Give button naming a pet)",function()
			local saved=view.options.activePet;view.options.activePet=function()return nil end
			local ok,err=pcall(function()
				nursery:open(copy(S));frames();nursery:selectRecipe("toy");frames();nursery:actPrimary()
				local w=os.clock();while not(view.shade.Visible and view.page=="toyReceipt")and os.clock()-w<3 do frames(1)end
				assert(view.page=="toyReceipt","the saved toy reopens")
				assert(not view.action.Visible and view.toyPanel.useNow.Text=="Store","Give shows with no pet ("..view.action.Text..")")
				assert(not view:activate(),"nothing to give")
			end)
			view.options.activePet=saved;view:close("back");frames()
			assert(ok,err)
		end)
		test("Customization Egg again: the waiting toy is acknowledged first, then a fresh jar hatch",function()
			hatch("look","receipt","tide","Customization 2")
			assert(table.find(log,"toyAck"),"the toy was acknowledged before the second egg: "..table.concat(log,","))
		end)
	end,function(e)return tostring(e).." | "..debug.traceback()end)
	pcall(function()view:destroy()end);pcall(function()nursery:close("spec")end)
	gui:Destroy()
	if not ok then error(problem,0)end
	return{passed=#cases,cases=cases}
end
