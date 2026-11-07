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
		local f={previews={},applied={},settings={},closed=0,sound="On",reduced=false}
		local view
		view=Picker.new(root,nil,nil,function(theme,sticker)table.insert(f.previews,{theme,sticker})end,function()
			f.closed+=1;f.visibleTheme,f.visibleSticker="sherbet","none"
			if f.resetIds then view.themeId,view.stickerId="sherbet","none"end
		end,function(theme,sticker)table.insert(f.applied,{theme,sticker})end,function(key)
			table.insert(f.settings,key)
			if key=="sound"then f.sound="Muted"else f.reduced=true end
			view:updateClub(1,0,0,0,f.sound,f.reduced,false,Catalog.bit("pip"))
		end)
		table.insert(views,view);f.view=view
		view:updateClub(1,0,0,0,f.sound,f.reduced,false,Catalog.bit("pip"));view:open("sherbet","none");return f
	end
	local function journal()
		local f={visits={},tracks={},goals=0};local view
		view=Journal.new(root,nil,nil,function(pet)table.insert(f.visits,pet.id)end,function(pet)table.insert(f.tracks,pet.id)end,function()
			assert(not view.shade.Visible);f.goals+=1
		end)
		table.insert(views,view);f.view=view;return f
	end
	local ok,problem=pcall(function()
		test("swatches preview only across resize tabs and scrolling",function()
			local f=picker();local view=f.view
			assert(view:activateChoice("Shell","brick"));view:showTab("Sticker");assert(view:activateChoice("Sticker","star"))
			root.Size=UDim2.fromOffset(385,703);settle();view:showTab("Club");view.scroll.CanvasPosition=Vector2.new(0,60);view:showTab("Shell")
			assert(view.themeId=="brick" and view.stickerId=="star" and #f.applied==0 and #f.settings==0 and f.closed==0)
			view:close();root.Size=UDim2.fromOffset(733,307);settle()
		end)
		test("X Back and forced-dismiss common close route roll back once per opening",function()
			local f=picker();local view=f.view
			for _,route in ipairs({"X","Back","forced"})do
				if not view.shade.Visible then view:open("sherbet","none")end
				view:select("ice","star");view:close();view:close()
				assert(f.visibleTheme=="sherbet" and f.visibleSticker=="none" and #f.applied==0,route)
			end
			assert(f.closed==3)
		end)
		test("Equip captures pending IDs before rollback and submits exactly once",function()
			local f=picker();local view=f.view;f.resetIds=true
			view:select("brick","star");assert(view:applyPreview() and not view:applyPreview())
			assert(f.closed==1 and #f.applied==1 and f.applied[1][1]=="brick" and f.applied[1][2]=="star")
			assert(view.themeId=="sherbet" and view.stickerId=="none")
		end)
		test("locked stickers stay unavailable and a hidden tab cannot submit Equip",function()
			local f=picker();local view=f.view;view:showTab("Sticker")
			local before=#f.previews
			assert(not view:activateChoice("Sticker","club") and not view:activateChoice("Sticker","wick") and #f.previews==before)
			view:showTab("Club");assert(not view:applyPreview() and #f.applied==0);view:close()
		end)
		test("Club settings apply once immediately and persist through closing",function()
			local f=picker();local view=f.view;view:showTab("Club")
			assert(view:changeSetting("sound") and view:changeSetting("motion"))
			assert(#f.settings==2 and f.sound=="Muted" and f.reduced and view.sound.Text=="SFX: Muted" and view.motion.Text=="Motion: Low")
			for _=1,3 do view:layout();view.scroll.CanvasPosition=Vector2.new(0,60)end
			view:close();assert(f.sound=="Muted" and f.reduced and #f.settings==2 and #f.applied==0)
			assert(not view:changeSetting("sound"))
		end)
		test("Roblox reduced motion cannot be overridden by a setting or reflow",function()
			local f=picker();local view=f.view;view:updateClub(1,0,0,0,"On",false,true,Catalog.bit("pip"));view:showTab("Club")
			assert(not view.motion.Interactable and not view:changeSetting("motion"));view:layout();assert(#f.settings==0);view:close()
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
