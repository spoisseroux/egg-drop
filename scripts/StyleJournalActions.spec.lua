-- Explicit production UI actions, counters replace remotes/settings transport. Real ScreenGui host.
return function(client,parent)
	local selectionService=game:GetService("GuiService")
	local fixturePreviousSelection=selectionService.SelectedObject
	local function restoreFixtureSelection()
		selectionService.SelectedObject=nil
		local node=fixturePreviousSelection
		local playerGui=game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
		if not node or not node.Parent or not node:IsA("GuiObject") or not node.Selectable or not playerGui or not node:IsDescendantOf(playerGui)then return end
		local ancestor=node
		while ancestor do
			if ancestor:IsA("GuiObject")and not ancestor.Visible then return end
			if ancestor:IsA("ScreenGui")and not ancestor.Enabled then return end
			ancestor=ancestor.Parent
		end
		selectionService.SelectedObject=node
	end
	assert(parent:IsA("ScreenGui"),"ScreenGui host required")
	local Picker=require(client.DeckPicker);local Journal=require(client.PetJournal);local Menu=require(client.DeckMenu)
	local GuiService=game:GetService("GuiService");local Catalog=require(game.ReplicatedStorage.Shared.EggCatalog)
	local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
	local root=Instance.new("Frame");root.Name="_StyleJournalActions";root.Size=UDim2.fromOffset(733,307);root.BackgroundTransparency=1;root.Parent=parent
	local cases,views={},{}
	local function test(name,run)run();table.insert(cases,name)end
	local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
	local function picker()
		local f={previews={},applied={},settings={},closed=0,sound="On",reduced=false,music=true,musicChanges=0}
		local view
		view=Picker.new(root,nil,nil,function(theme,sticker)table.insert(f.previews,{theme,sticker})end,function()
			f.closed+=1;f.visibleTheme,f.visibleSticker="sherbet","none"
			if f.resetIds then view.themeId,view.stickerId="sherbet","none"end
		end,function(theme,sticker)table.insert(f.applied,{theme,sticker})end,function(key)
			if key=="music"then
				f.music=not f.music;f.musicChanges+=1
				view:updateClub(1,0,0,0,f.sound,f.reduced,false,Catalog.bit("pip"),f.music)
				return
			end
			table.insert(f.settings,key)
			if key=="sound"then f.sound="Muted"else f.reduced=true end
			view:updateClub(1,0,0,0,f.sound,f.reduced,false,Catalog.bit("pip"),f.music)
		end)
		table.insert(views,view);f.view=view
		view:updateClub(1,0,0,0,f.sound,f.reduced,false,Catalog.bit("pip"),f.music);view:open("sherbet","none");return f
	end
	local function journal()
		local f={visits={},tracks={},goals=0};local view
		view=Journal.new(root,nil,nil,function(pet)table.insert(f.visits,pet.id)end,function(pet)table.insert(f.tracks,pet.id)end,function()
			assert(not view.shade.Visible);f.goals+=1
		end)
		table.insert(views,view);f.view=view;return f
	end
	local ok,problem=pcall(function()
		test("unlocked choices submit one slot immediately and never on reflow",function()
   local f=picker();local v=f.view;assert(v:activateChoice("Shell","brick"));v:showTab("Sticker");assert(v:activateChoice("Sticker","star"))
   assert(#f.applied==2 and f.applied[1][1]=="theme"and f.applied[1][2]=="brick"and f.applied[2][1]=="sticker"and f.applied[2][2]=="star")
   v:layout();v:close();assert(#f.applied==2 and #f.settings==0 and #f.previews==0)
  end)
  test("X Back forced close and reopen never submit or rollback",function()
   local f=picker();local v=f.view
   for _,route in ipairs({"back","forced","back"})do if not v.shade.Visible then v:open("ice","star")end;v:close(route);v:close(route)end
   assert(f.closed==3 and #f.applied==0 and not v.card:FindFirstChild("Apply"))
  end)
  test("confirmed checks follow acknowledged pair independently of pending choice",function()
   local f=picker();local v=f.view
   v:setAppearance({themeId="brick",stickerId="star",confirmedTheme="sherbet",confirmedSticker="none",slots={theme={status="Pending"},sticker={status="Pending"}}})
   assert(v.choices.Shell.sherbet.Enabled and not v.choices.Shell.brick.Enabled)
   v:setAppearance({themeId="brick",stickerId="star",confirmedTheme="brick",confirmedSticker="star",slots={theme={status="Applied"},sticker={status="Saved"}}})
   assert(v.choices.Shell.brick.Enabled and v.choices.Sticker.star.Enabled and #f.applied==0);v:close()
  end)
  test("locked art remains inspectable with concrete unlock and no appearance send",function()
   local f=picker();local v=f.view;v:showTab("Sticker")
   assert(v:activateChoice("Sticker","club")and v.trialsLink.Visible and v.appearanceStatus.Text:find("three Pocket Trials",1,true))
   assert(v:activateChoice("Sticker","wick")and v.appearanceStatus.Text:find("Own Wick",1,true)and #f.applied==0)
   v:showTab("Trials");assert(not v.sound.Visible and not v.tabs.Shell.Visible);v:close()
  end)
		test("Settings apply once immediately and persist through closing",function()
			local f=picker();local view=f.view;view:showTab("Settings")
			assert(view:changeSetting("sound") and view:changeSetting("motion"))
			assert(#f.settings==2 and f.sound=="Muted" and f.reduced and view.sound.Text=="SFX: Muted" and view.motion.Text=="Motion: Low")
			for _=1,3 do view:layout();view.scroll.CanvasPosition=Vector2.new(0,60)end
			view:close();assert(f.sound=="Muted" and f.reduced and #f.settings==2 and #f.applied==0)
			assert(not view:changeSetting("sound"))
		end)
		test("Roblox reduced motion cannot be overridden by a setting or reflow",function()
			local f=picker();local view=f.view;view:updateClub(1,0,0,0,"On",false,true,Catalog.bit("pip"));view:showTab("Settings")
			assert(not view.motion.Interactable and not view:changeSetting("motion"));view:layout();assert(#f.settings==0);view:close()
		end)
		test("Music stays session-local through four viewport reflows and reopening while SFX submits once",function()
			local f=picker();local view=f.view;view:showTab("Settings")
			assert(view:changeSetting("music") and not f.music and f.musicChanges==1 and #f.settings==0)
			for _,size in ipairs({Vector2.new(733,307),Vector2.new(568,160),Vector2.new(385,703),Vector2.new(1649,971)})do
				root.Size=UDim2.fromOffset(size.X,size.Y);settle();view:layout()
				view:close();view:open("sherbet","none");view:showTab("Settings");settle()
				assert(view.music.Visible and view.music.Interactable and view.music.Selectable)
				assert(view.music.Text=="Music: Off" and f.musicChanges==1 and #f.settings==0)
			end
			assert(view:changeSetting("sound") and #f.settings==1 and f.settings[1]=="sound")
			assert(view:changeSetting("music") and f.music and f.musicChanges==2 and #f.settings==1)
			view:close();assert(not view:changeSetting("music") and f.musicChanges==2)
			root.Size=UDim2.fromOffset(733,307);settle()
		end)
		test("sparse rare-only gamepad focus skips locked earlier pets and scrolls to the owned row",function()
			local f=journal();local view=f.view
			view:open(0,0,"foxfire_wick",true,nil,Catalog.bit("foxfire_wick"),{wick=3});settle()
			local entry=view.cards[Pets.byId.foxfire_wick.index]
			assert(GuiService.SelectedObject==entry and not view.cards[1].Interactable and entry.FamilyRank.Text=="Wick · III")
			assert(entry.AbsolutePosition.Y>=view.scroll.AbsolutePosition.Y-.1 and entry.AbsolutePosition.Y<view.scroll.AbsolutePosition.Y+view.scroll.AbsoluteSize.Y)
			assert(#f.visits==0 and #f.tracks==0 and f.goals==0);view:close()
		end)
		test("authoritative empty inventory has no legacy track or hidden selectable row",function()
			local f=journal();local view=f.view;view:open(4,255,"pip",true,nil,0,{});settle()
			for _,entry in ipairs(view.cards)do assert(not entry.Interactable and not entry.Selectable and not entry.Track.Visible)end
			assert(GuiService.SelectedObject==view.closeButton and not view:activatePet(1));view:close()
		end)
		test("legacy tracking remains explicit only when the inventory mask is absent",function()
			local f=journal();local view=f.view;view:open(0,0,"pip",true);settle()
			local index=Pets.byId.bloom_pip.index
			assert(GuiService.SelectedObject==view.cards[index] and view.cards[index].Track.Visible)
			assert(view:activatePet(index) and not view:activatePet(index) and f.tracks[1]=="bloom_pip" and #f.tracks==1 and #f.visits==0)
		end)
		test("owned row equips once and Family goals never equips tracks or selects a family",function()
			local f=journal();local view=f.view;local mask=Catalog.bit("eclipse_orbit")
			local ranks={orbit=2};view:open(0,0,"pip",false,nil,mask,ranks)
			assert(view:activatePet(Pets.byId.eclipse_orbit.index) and #f.visits==1 and f.visits[1]=="eclipse_orbit")
			view:open(0,0,"pip",false,nil,mask,ranks);assert(view:openFamilyGoals() and not view:openFamilyGoals())
			assert(f.goals==1 and #f.visits==1 and #f.tracks==0 and ranks.orbit==2 and mask==Catalog.bit("eclipse_orbit"))
		end)
		test("focus restoration rejects hidden former menus disabled screens and unselectable openers",function()
			local opener=Instance.new("TextButton");opener.Size=UDim2.fromOffset(44,44);opener.Parent=root
			for _,kind in ipairs({"style","journal"})do
				local f=if kind=="style"then picker()else journal();local view=f.view
				for _,blocked in ipairs({"ancestor","selectable","screen"})do
					root.Visible=true;opener.Selectable=true
					GuiService.SelectedObject=opener
					if kind=="style"then view:open("sherbet","none")else view:open(1,0,"pip",false,nil,1,{})end
					GuiService.SelectedObject=if kind=="style"then view.cancel else view.closeButton
					if blocked=="ancestor"then root.Visible=false elseif blocked=="selectable"then opener.Selectable=false else parent.Enabled=false end
					view:close();assert(GuiService.SelectedObject~=opener,"restored blocked opener: "..blocked)
					root.Visible=true;opener.Selectable=true;parent.Enabled=true
				end
				GuiService.SelectedObject=opener
				if kind=="style"then view:open("sherbet","none")else view:open(1,0,"pip",false,nil,1,{})end
				GuiService.SelectedObject=if kind=="style"then view.cancel else view.closeButton;view:close();assert(GuiService.SelectedObject==opener)
			end
			opener:Destroy()
		end)
		test("measured Ranks caption retains mastery page identity and callback",function()
			local menu=Menu.new(root,{});table.insert(views,menu);menu:open();menu:setPage("mastery");settle()
			assert(menu.page=="mastery" and menu.pages.mastery.Visible and menu.tabs.mastery.TextFits)
			assert(menu.tabs.mastery.Text=="Mastery" or menu.tabs.mastery.Text=="Ranks")
			assert(menu.tabs.mastery:GetAttribute("AccessibleLabel")=="Family mastery ranks");menu:close()
		end)
	end)
	root.Visible=true;parent.Enabled=true
	selectionService.SelectedObject=nil
	for _,view in ipairs(views)do view:close();view.shade:Destroy()end;root:Destroy();restoreFixtureSelection();assert(ok,problem)
	return{passed=#cases,cases=cases}
end
