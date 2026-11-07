-- Real LocalScript/ScreenGui at current native PreferredTextSize; never changes preferences.
return function(client,parent)
	assert(parent:IsA("ScreenGui") and parent.Enabled,"enabled ScreenGui required")
	local Sprite=require(client.JellySprite);local Config=require(game.ReplicatedStorage.Shared.BoardConfig)
	local RunService=game:GetService("RunService")
	local root=Instance.new("Frame");root.Name="_JellyMarks";root.BackgroundTransparency=1;root.Position=UDim2.fromOffset(20,20);root.Size=UDim2.fromOffset(172,289);root.Parent=parent
	local cases,legacyBounds={},{ }
	local function settle()RunService.RenderStepped:Wait();RunService.RenderStepped:Wait()end
	local ok,problem=pcall(function()
		settle();Sprite.invalidateMarkSizes()
		for _,tier in ipairs(Config.Tiers)do
			local label=Instance.new("TextLabel");label.Name="Mark_"..tier.mark;label.Text=tier.mark
			label.Font,label.TextSize,label.BackgroundTransparency=Enum.Font.GothamMedium,15,1
			label.AnchorPoint,label.Position,label.Size=Vector2.new(.5,.5),UDim2.fromScale(.5,.5),UDim2.fromOffset(30,22)
			label.Parent=root;settle()
			legacyBounds[tier.mark]={labelSize=tostring(label.AbsoluteSize),nativeContent=tostring(label.TextBounds),textFits=label.TextFits}
			local original=label.Position;label.Size=Sprite.markSize(tier.mark);settle()
			local bounds,size=label.TextBounds,label.AbsoluteSize
			assert(size.X>=bounds.X+2-.01 and size.Y>=bounds.Y+2-.01,tier.mark.." native content "..tostring(bounds).." exceeds mark well "..tostring(size))
			assert(size.X>=30 and size.Y>=22 and label.TextFits)
			assert(label.TextSize==15 and label.Font==Enum.Font.GothamMedium and not label.TextScaled and label.Rotation==0)
			assert(label.Position==original and label.AnchorPoint==Vector2.new(.5,.5),"mark projection changed")
			local actual=label.AbsolutePosition+label.AbsoluteSize/2;local expected=root.AbsolutePosition+root.AbsoluteSize/2
			assert((actual-expected).Magnitude<=1,"native size adjustment moved center")
			local cached=Sprite.markSize(tier.mark);assert(cached==label.Size,"unchanged mark size was unstable")
			table.insert(cases,tier.mark.." bounds contain native ink without changing font or projected center")
			label:Destroy()
		end
	end)
	root:Destroy();assert(ok,problem)
	return{passed=#cases,cases=cases,legacyBounds=legacyBounds,preference=game:GetService("GuiService").PreferredTextSize.Name}
end
