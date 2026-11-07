-- Real LocalScript + ScreenGui component targets; injected input is semantic, not hardware emulation.
return function(client,parent)
	assert(parent:IsA("ScreenGui"),"ScreenGui host required")
	local Focus=require(client.ControllerFocus)
	local Menu,Picker,Journal,View=require(client.DeckMenu),require(client.DeckPicker),require(client.PetJournal),require(client.EggHatchView)
	local Catalog=require(game.ReplicatedStorage.Shared.EggCatalog)
	local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
	local GuiService=game:GetService("GuiService")
	local playerGui=game.Players.LocalPlayer.PlayerGui
	local previous=GuiService.SelectedObject
	local U,S,R=Enum.UserInputType,Enum.UserInputState,Enum.ContextActionResult
	local root=Instance.new("Frame");root.Name="_ControllerSheets";root.Size=UDim2.fromOffset(733,307);root.BackgroundTransparency=1;root.Parent=parent
	local cases,views,coordinators={},{},{}
	local calls={route=0,preview=0,apply=0,setting=0,equip=0,track=0,goals=0,send=0,closed=0}
	local function count(key)return function()calls[key]+=1 end end
	local function total()local n=0;for _,value in pairs(calls)do n+=value end;return n end
	local function settle()for _=1,2 do game:GetService("RunService").Heartbeat:Wait()end end
	local function test(name,run)run();table.insert(cases,name)end
	local function keep(view)table.insert(views,view);return view end
	local function coordinator(view)
		local f={view=view,kind=U.MouseMovement,down=false,queue={},writes=0}
		GuiService.SelectedObject=nil
		f.co=Focus.new({read=function()return{owner=view:getControllerFocus(),native=f.native,blocked=f.blocked}end,
			playerGui=function()return playerGui end,input=function()return f.kind end,aDown=function()return f.down end,
			selected=function()return GuiService.SelectedObject end,select=function(target)f.writes+=1;GuiService.SelectedObject=target end,
			afterInput=function(run)table.insert(f.queue,run)end})
		f.co:watch(view.shade:GetPropertyChangedSignal("Visible"))
		f.co:watch(view.shade:GetAttributeChangedSignal("ControllerEpoch"))
		function f:flush()settle();local queue=self.queue;self.queue={};for _,run in ipairs(queue)do run()end;settle()end
		function f:pad()self.kind=U.Gamepad1;self.co:onInputTypeChanged(self.kind)end
		function f:press(state)
			self.down=state==S.Begin or state==S.Change
			return self.co:handleA(state,{KeyCode=Enum.KeyCode.ButtonA,UserInputType=U.Gamepad1})
		end
		table.insert(coordinators,f.co);return f
	end
	local function close(view)GuiService.SelectedObject=nil;view:close()end
	local function menu()
		local callbacks={};for _,key in ipairs({"close","eggs","pets","style","play","daily","family"})do callbacks[key]=count("route")end
		local view=keep(Menu.new(root,callbacks))
		view:update({status="Ready",nectar=24,inventoryMask=127},"pip","pip",0,0,0,"sprout");view:open();return view
	end
	local function picker()
		local view=keep(Picker.new(root,nil,nil,count("preview"),count("closed"),count("apply"),count("setting")))
		view:updateClub(1,0,0,0,"On",false,false,Catalog.bit("pip"));view:open("sherbet","none");return view
	end
	local function journal(mask,selected)
		local view=keep(Journal.new(root,nil,nil,count("equip"),count("track"),count("goals")))
		view:open(0,0,"foxfire_wick",selected==true,nil,mask,{wick=3});return view
	end
	local function eggs()
		local view=keep(View.new(root,{play=function()end},function()return true end,count("send")))
		view:open({status="Ready",revision=4,nectar=24,inventoryMask=Catalog.bit("pip")});return view
	end
	local ok,problem=pcall(function()
		test("pointer-open Menu seeds current Daily or Mastery tab without routing",function()
			local view=menu()
			for _,page in ipairs({"daily","mastery"})do
				view:setPage(page);local f=coordinator(view);local before=total();f:pad();f:flush()
				assert(GuiService.SelectedObject==view.tabs[page] and f.writes==1 and total()==before,page)
				f.co:destroy()
			end
			close(view)
		end)
		test("pointer-open Style seeds active Sticker or Club tab without preview Apply or settings writes",function()
			local view=picker()
			for _,tab in ipairs({"Sticker","Club"})do
				view:showTab(tab);local f=coordinator(view);local before=total();f:pad();f:flush()
				assert(GuiService.SelectedObject==view.tabs[tab] and f.writes==1 and total()==before,tab)
				f.co:destroy()
			end
			close(view)
		end)
		test("sparse rare-only Journal seeds and scrolls first owned row without equipping or tracking",function()
			local view=journal(Catalog.bit("foxfire_wick"));settle();local f=coordinator(view);local before=total()
			f:pad();f:flush();local entry=view.cards[Pets.byId.foxfire_wick.index]
			assert(GuiService.SelectedObject==entry and f.writes==1 and total()==before)
			assert(entry.AbsolutePosition.Y>=view.scroll.AbsolutePosition.Y-1 and entry.AbsolutePosition.Y<view.scroll.AbsolutePosition.Y+view.scroll.AbsoluteSize.Y,"owned row not visible")
			assert(not view.cards[1].Selectable and not view.cards[1].Interactable);close(view)
		end)
		test("explicit empty Journal uses X while legitimate legacy Journal can focus Track",function()
			for _,explicit in ipairs({true,false})do
				local view=journal(if explicit then 0 else nil);local f=coordinator(view);local before=total();f:pad();f:flush()
				local target=if explicit then view.closeButton else view.cards[Pets.byId.bloom_pip.index]
				assert(GuiService.SelectedObject==target and total()==before)
				if not explicit then assert(target.Track.Visible)end;close(view)
			end
		end)
		test("ordinary shop acquires neutral X on first released A with no purchase or acknowledgement",function()
			local view=eggs();settle();local f=coordinator(view);local before=total()
			-- CAS can see an unequivocal gamepad A before UIS's last-input notification.
			assert(f:press(S.Begin)==R.Sink);f:pad();f:flush();assert(GuiService.SelectedObject==nil)
			assert(f:press(S.End)==R.Sink);f:flush()
			assert(GuiService.SelectedObject==view.closeButton and f.writes==1 and total()==before)
			assert(view.state.nectar==24 and view.state.lastHatch==nil);close(view)
		end)
		test("direct controller Journal opening retains its valid existing owned selection",function()
			local view=journal(Catalog.bit("foxfire_wick"),true);settle();local target=GuiService.SelectedObject
			local f=coordinator(view);GuiService.SelectedObject=target;local before=total();f:pad();f:flush()
			assert(target==view.cards[Pets.byId.foxfire_wick.index] and GuiService.SelectedObject==target and f.writes==0 and total()==before)
			assert(f:press(S.Begin)==R.Pass and f:press(S.End)==R.Pass);close(view)
		end)
		test("result arriving under an open shop revokes the captured ordinary-shop owner",function()
			local view=eggs();settle();local f=coordinator(view);f:pad();assert(f:press(S.Begin)==R.Sink)
			local oldEpoch=view.shade:GetAttribute("ControllerEpoch")
			local result={id="controller-fixture-only",petId="pip",family="pip",rare=false}
			view:update({status="Ready",revision=5,nectar=24,inventoryMask=Catalog.bit("pip"),lastHatch=result})
			assert(view.shade.Visible and view:getControllerFocus()==nil and view.shade:GetAttribute("ControllerEpoch")>oldEpoch)
			local before=total();GuiService.SelectedObject=nil;assert(f:press(S.End)==R.Sink);f:flush()
			assert(GuiService.SelectedObject==nil and f.writes==0 and total()==before and view.state.lastHatch.id==result.id and view.state.nectar==24)
			assert(f:press(S.Begin)==R.Pass and f:press(S.End)==R.Pass);close(view)
		end)
		test("all four same-instance openings advance generation and hidden sheets expose no target",function()
			local all={menu(),picker(),journal(Catalog.bit("pip")),eggs()}
			for _,view in ipairs(all)do
				local epoch=view:getControllerFocus().epoch
				if view==all[1]then view:open()elseif view==all[2]then view:open("sherbet","none")elseif view==all[3]then view:open(1,0,"pip",false,nil,Catalog.bit("pip"),{})else view:open(view.state)end
				assert(view:getControllerFocus().epoch>epoch);close(view);assert(view:getControllerFocus()==nil)
			end
		end)
	end)
	for _,co in ipairs(coordinators)do co:destroy()end
	GuiService.SelectedObject=nil
	for _,view in ipairs(views)do view:close();view.shade:Destroy()end
	root:Destroy()
	if Focus.live(previous,nil,playerGui,true)then GuiService.SelectedObject=previous end
	assert(ok,problem)
	return{passed=#cases,cases=cases,inputIsSemanticFixture=true}
end
