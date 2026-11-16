-- Real LocalScript/ScreenGui harness. Only presentation root sizes change; no pet interaction.
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
	assert(parent:IsA("ScreenGui"),"roam hint fixture requires ScreenGui host")
	local Focus=require(client.PetFocusUI)
	local host=Instance.new("ScreenGui");host.Name="_RoamHintHost";host.Parent=parent.Parent
	host.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets
	local dock=Instance.new("Frame");dock.Name="LoungeControls";dock.AnchorPoint=Vector2.new(1,0)
	dock.Position,dock.Size=UDim2.new(1,-12,0,12),UDim2.fromOffset(180,48);dock.Parent=host
	local calls=0
	local ui=Focus.new(host,{back=function()calls+=1 end,greet=function()calls+=1 end,pet=function()calls+=1 end,
		canReact=function()return true end,canOwnInput=function()return true end})
	local cases={}
	local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
	local ok,problem=pcall(function()
		for _,size in ipairs({Vector2.new(733,307),Vector2.new(568,160),Vector2.new(385,703),Vector2.new(1649,971)})do
			ui.root.Size=UDim2.fromOffset(size.X,size.Y);settle();ui.feedbackUntil=nil;ui:update(nil,nil,true);settle()
			local hint,root=ui.hint,ui.root
			-- QA v775: no always-on "say hi" hint (the Your garden guide teaches it); the line
			-- only carries feedback or a save notice.
			assert(not hint.Visible,"the always-on say-hi hint is back at "..tostring(size))
			ui:showFeedback("Let your pet come closer, then try again");ui:update(nil,nil,true);settle()
			assert(hint.Visible and hint.TextFits and not hint.TextScaled,string.format("hint %s text=%q box=%s bounds=%s",tostring(size),hint.Text,tostring(hint.AbsoluteSize),tostring(hint.TextBounds)))
			local p,s,hp,hs=hint.AbsolutePosition,hint.AbsoluteSize,root.AbsolutePosition,root.AbsoluteSize
			assert(p.X>=hp.X and p.Y>=hp.Y and p.X+s.X<=hp.X+hs.X and p.Y+s.Y<=hp.Y+hs.Y,"hint escapes core safe root")
			assert(p.Y>=dock.AbsolutePosition.Y+dock.AbsoluteSize.Y,"hint overlaps roam dock")
			assert(not ui.active and not ui.panel.Visible and ui.gui.DisplayOrder==9 and calls==0)
			table.insert(cases,tostring(size).." no say-hi hint; feedback stays measured below a top dock inside core safe root")
		end
		-- QA v2 R2.6: the dock lives at the lower right (clear of the player list). QA v775: the
		-- lane above it is the park's (Throw, "Pets playing 3/9"), so the line sits on the
		-- dock's row, to its left, and never above the dock.
		local Counter=require(client.ParkCounter)
		local Notice=require(client.SaveNotice)
		dock.AnchorPoint=Vector2.new(1,1);dock.Size=UDim2.fromOffset(104,48)
		for _,size in ipairs({Vector2.new(733,307),Vector2.new(750,402),Vector2.new(385,703),Vector2.new(1649,971)})do
			ui.root.Size=UDim2.fromOffset(size.X,size.Y);settle()
			-- The real dock shares the root's screen space: its lower-right corner, 16 px in.
			local origin=ui.root.AbsolutePosition-host.AbsolutePosition
			dock.Position=UDim2.fromOffset(math.floor(origin.X+size.X-16),math.floor(origin.Y+size.Y-16));settle()
			ui.feedbackUntil=nil;ui:setSaveNotice(nil);ui:update(nil,nil,true);settle()
			assert(not ui.hint.Visible,"the always-on say-hi hint is back (low dock)")
			-- The park's stack: the dock's columns, from the dock up past Throw and a two-line counter.
			local stackTop=dock.AbsolutePosition.Y-(Counter.Gap+Counter.ThrowHeight+Counter.Gap+Counter.LineHeight+Counter.LineExtra)
			for _,kind in ipairs({"feedback","save"})do
				if kind=="feedback"then ui:showFeedback("Let your pet come closer, then try again")
				else ui.feedbackUntil=nil;ui:setSaveNotice(Notice.resolve("Retrying",{status="Ready"}))end
				ui:update(nil,nil,true);settle()
				local hint,root=ui.hint,ui.root
				local p,s,hp,hs=hint.AbsolutePosition,hint.AbsoluteSize,root.AbsolutePosition,root.AbsoluteSize
				assert(hint.Visible and hint.TextFits,kind.." line hidden or cut at "..tostring(size))
				assert(p.X>=hp.X and p.Y>=hp.Y and p.X+s.X<=hp.X+hs.X+1 and p.Y+s.Y<=hp.Y+hs.Y+1,kind.." line escapes core safe root (low dock) at "..tostring(size))
				assert(p.X+s.X<=dock.AbsolutePosition.X,kind.." line overlaps the Menu / Pocket Deck dock at "..tostring(size))
				-- Left of the dock's columns, so it can never cover the park counter or Throw above the dock.
				assert(p.X+s.X<=dock.AbsolutePosition.X or p.Y+s.Y<=stackTop,kind.." line covers the park's Pets playing lane at "..tostring(size))
			end
			ui:setSaveNotice(nil)
			table.insert(cases,tostring(size).." feedback and save notices sit left of the lower-right dock, clear of the park counter")
		end
	end)
	selectionService.SelectedObject=nil;ui:destroy();host:Destroy();restoreFixtureSelection();assert(ok,problem)
	return{passed=#cases,cases=cases}
end
