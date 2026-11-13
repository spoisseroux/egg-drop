-- Real LocalScript + ScreenGui parent at Medium and Largest. No remotes or profile writes.
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
	assert(parent:IsA("ScreenGui") or parent:FindFirstAncestorOfClass("ScreenGui"),"ScreenGui host required")
	local Picker=require(client.DeckPicker);local Journal=require(client.PetJournal)
	local Themes=require(game.ReplicatedStorage.Shared.DeckThemes)
	local Backgrounds=require(game.ReplicatedStorage.Shared.DeckBackgrounds)
	local Catalog=require(game.ReplicatedStorage.Shared.EggCatalog)
	local root=Instance.new("Frame");root.Name="_StyleJournalLayout";root.BackgroundTransparency=1;root.Parent=parent
	local views,cases={},{}
	local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
	local function test(name,run)run();table.insert(cases,name)end
	local function inside(node,host)
		local p,s,hp,hs=node.AbsolutePosition,node.AbsoluteSize,host.AbsolutePosition,host.AbsoluteSize
		return p.X>=hp.X-.1 and p.Y>=hp.Y-.1 and p.X+s.X<=hp.X+hs.X+.1 and p.Y+s.Y<=hp.Y+hs.Y+.1
	end
	local function readable(node)
		assert(node.TextFits,string.format("%s text=%q box=%s bounds=%s",node:GetFullName(),node.Text,tostring(node.AbsoluteSize),tostring(node.TextBounds)))
		assert(not node.TextScaled,"preferred text disabled: "..node.Name)
	end
	local function reach(node,scroll)
		local top=node.AbsolutePosition.Y-scroll.AbsolutePosition.Y+scroll.CanvasPosition.Y
		local maximum=math.max(0,scroll.CanvasSize.Y.Offset-scroll.AbsoluteSize.Y)
		scroll.CanvasPosition=Vector2.new(0,math.clamp(top,0,maximum));settle()
		assert(node.AbsolutePosition.Y>=scroll.AbsolutePosition.Y-.1 and node.AbsolutePosition.Y<scroll.AbsolutePosition.Y+scroll.AbsoluteSize.Y,"row top unreachable: "..node.Name)
		scroll.CanvasPosition=Vector2.new(0,math.clamp(top+node.AbsoluteSize.Y-scroll.AbsoluteSize.Y,0,maximum));settle()
		assert(node.AbsolutePosition.Y+node.AbsoluteSize.Y<=scroll.AbsolutePosition.Y+scroll.AbsoluteSize.Y+.1,"row bottom unreachable: "..node.Name)
		if node.AbsoluteSize.Y<=scroll.AbsoluteSize.Y then assert(inside(node,scroll),"complete row unreachable: "..node.Name)end
	end
	local function club(view)
		view:updateClub(1,0,5,900,"On",false,false,Catalog.bit("pip"))
	end
	local ok,problem=pcall(function()
		for _,size in ipairs({Vector2.new(733,307),Vector2.new(568,160),Vector2.new(385,703),Vector2.new(1649,971)})do
			root.Size=UDim2.fromOffset(size.X,size.Y);settle()
			test(tostring(size).." Style Settings and Trials pin the header back around reachable preferred-text content",function()
				local events=0
				local view=Picker.new(root,nil,nil,function()end,function()end,function()events+=1 end,function()events+=1 end)
				table.insert(views,view);club(view);view:open("brick","none","Settings");settle()
				-- Faceplates and Backgrounds are the Deck style screen (DeckStyle spec); the card hosts Settings and Trials.
				local closeY=view.cancel.AbsolutePosition.Y
				for _,tab in ipairs({"Trials","Settings","Trials"})do
					view:showTab(tab);settle()
					assert(inside(view.card,root) and inside(view.scroll,view.card) and view.scroll.AbsoluteSize.Y>=44)
					assert(view.cancel.AbsoluteSize==Vector2.new(44,44) and inside(view.cancel,view.card) and not view.cancel:IsDescendantOf(view.scroll))
					assert(view.cancel.AbsolutePosition.Y==closeY,"header back moved between pages")
					assert(view.heading.AbsolutePosition.X+view.heading.AbsoluteSize.X<=view.cancel.AbsolutePosition.X,"title overlaps back")
     assert(not view.card:FindFirstChild("Apply")and not view.shop.visible)
     if tab=="Trials"then
      assert(not view.sound.Visible);for _,row in ipairs(view.rows)do readable(row.title);readable(row.status);reach(row.frame,view.scroll)end
      readable(view.reward);reach(view.reward,view.scroll)
     else
      assert(not view.clubHeader.Visible);readable(view.sound);readable(view.music);readable(view.motion)
      assert(view.music.AbsoluteSize.Y>=44 and view.music.Selectable and view.music.Interactable)
      reach(view.music,view.scroll);reach(view.motion,view.scroll)
     end
     local before=view.scroll.CanvasPosition.Y;club(view);settle();assert(view.scroll.CanvasPosition.Y==before,"unchanged data reset reading")
     view.scroll.CanvasPosition=Vector2.new(0,math.max(0,view.scroll.CanvasSize.Y.Offset-view.scroll.AbsoluteSize.Y));settle();assert(not view.moreCue.Visible)
					assert(view.themeId=="brick" and view.stickerId=="none" and events==0,"layout or scroll submitted an action")
				end
				view:close()
			end)
			test(tostring(size).." Journal measures all seven name status rank and crest rows",function()
				local events=0
				local view=Journal.new(root,nil,nil,function()events+=1 end,function()events+=1 end,function()events+=1 end)
				table.insert(views,view);view:open(0,0,"foxfire_wick",false,nil,127,{pip=1,puddle=2,wick=3,orbit=2});settle()
				assert(#view.cards==7 and inside(view.card,root) and inside(view.scroll,view.card) and view.scroll.AbsoluteSize.Y>=44)
				assert(view.closeButton.AbsoluteSize==Vector2.new(44,44) and inside(view.closeButton,view.card));readable(view.closeButton);readable(view.title)
				assert(view.closeButton.AbsolutePosition.Y+44<=view.scroll.AbsolutePosition.Y)
				assert(view.goalsButton.AbsoluteSize.Y>=44 and inside(view.goalsButton,view.card));readable(view.goalsButton)
				assert(view.scroll.AbsolutePosition.Y+view.scroll.AbsoluteSize.Y<=view.goalsButton.AbsolutePosition.Y)
				assert(view.moreCue.Visible==(view.scroll.CanvasSize.Y.Offset>view.scroll.AbsoluteSize.Y+1) and not view.moreCue.Active and not view.moreCue.Selectable,"Journal overflow undiscoverable")
				for _,entry in ipairs(view.cards)do
					assert(entry.AbsoluteSize.Y>=44 and inside(entry.PortraitWell,entry) and inside(entry.FamilyCrest,entry))
					readable(entry.Species);readable(entry.Status);readable(entry.FamilyRank)
					assert(inside(entry.Species,entry) and inside(entry.Status,entry) and inside(entry.FamilyRank,entry))
					assert(entry.PortraitWell.AbsolutePosition.X+entry.PortraitWell.AbsoluteSize.X<=entry.Species.AbsolutePosition.X)
					assert(entry.Species.AbsolutePosition.X+entry.Species.AbsoluteSize.X<=entry.FamilyCrest.AbsolutePosition.X)
					reach(entry,view.scroll)
				end
				view.scroll.CanvasPosition=Vector2.new(0,math.max(0,view.scroll.CanvasSize.Y.Offset-view.scroll.AbsoluteSize.Y));settle()
				assert(not view.moreCue.Visible,"Journal cue persists at end")
				assert(events==0);view:close()
			end)
		end
	end)
	selectionService.SelectedObject=nil
	for _,view in ipairs(views)do view:close();view.shade:Destroy()end;root:Destroy();restoreFixtureSelection();assert(ok,problem)
	return{passed=#cases,cases=cases,preference=game:GetService("GuiService").PreferredTextSize.Name}
end
