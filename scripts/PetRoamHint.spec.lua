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
			ui.root.Size=UDim2.fromOffset(size.X,size.Y);settle();ui:update(nil,nil,true);settle()
			local hint,root=ui.hint,ui.root
			assert(hint.Visible and hint.TextFits and not hint.TextScaled,string.format("hint %s text=%q box=%s bounds=%s",tostring(size),hint.Text,tostring(hint.AbsoluteSize),tostring(hint.TextBounds)))
			local p,s,hp,hs=hint.AbsolutePosition,hint.AbsoluteSize,root.AbsolutePosition,root.AbsoluteSize
			assert(p.X>=hp.X and p.Y>=hp.Y and p.X+s.X<=hp.X+hs.X and p.Y+s.Y<=hp.Y+hs.Y,"hint escapes core safe root")
			assert(p.Y>=dock.AbsolutePosition.Y+dock.AbsoluteSize.Y,"hint overlaps roam dock")
			assert(not ui.active and not ui.panel.Visible and ui.gui.DisplayOrder==9 and calls==0)
			table.insert(cases,tostring(size).." preferred roam hint stays measured below dock inside core safe root")
		end
	end)
	selectionService.SelectedObject=nil;ui:destroy();host:Destroy();restoreFixtureSelection();assert(ok,problem)
	return{passed=#cases,cases=cases}
end
