-- Production geometry/quest/dispenser with isolated state, at the player's actual native text preference.
return function(client,parent)
	assert(parent:IsA("ScreenGui") or parent:FindFirstAncestorOfClass("ScreenGui"),"handheld text fixture requires a real ScreenGui host")
	local Art=require(client.DeckArt)
	local Layout=require(client.DeckLayout)
	local Quest=require(client.BoardQuestHUD)
	local Dispenser=require(client.DropDispenser)
	local TextService=game:GetService("TextService")
	local GuiService=game:GetService("GuiService")
	local root=Instance.new("Frame");root.Name="_HandheldTextLayout";root.BackgroundTransparency=1;root.Parent=parent
	local cases={}
	local function settle()game:GetService("RunService").Heartbeat:Wait();game:GetService("RunService").Heartbeat:Wait()end
	local function frame(name,r)
		return Art.frame(root,name,Art.Ink,UDim2.fromOffset(r.x,r.y),UDim2.fromOffset(r.w,r.h),2)
	end
	local function readable(label)
		assert(label.TextFits,"preferred handheld clipped: "..label.Name.." ["..label.Text.."] "..tostring(label.AbsoluteSize).." bounds "..tostring(label.TextBounds))
		assert(not label.TextScaled,"preferred handheld opted out: "..label.Name)
	end
	local ok,problem=pcall(function()
		for _,size in ipairs({Vector2.new(568,160),Vector2.new(480,160),Vector2.new(350,279),Vector2.new(844,390),Vector2.new(390,740)})do
			root.Size=UDim2.fromOffset(size.X,size.Y);settle()
			local short=size.X>=size.Y*1.2 and size.Y<280
			local cap=if short then 12 else 14
			local utility=TextService:GetTextSize("Lounge",cap,Enum.Font.GothamBold,Vector2.new(1000,100)).X+14
			local line=TextService:GetTextSize("Next",12,Enum.Font.Gotham,Vector2.new(1000,100)).Y+4
			local glyph=TextService:GetTextSize("III",12,Enum.Font.GothamBold,Vector2.new(1000,100))
			local diameter=math.max(18,math.ceil(math.max(glyph.X,glyph.Y))+6)
			local walletLine=TextService:GetTextSize("0",18,Enum.Font.GothamBold,Vector2.new(1000,100)).Y+4
			local l=Layout.resolve(size,11.8/19.8,{utilityWidth=utility,lineHeight=line,queueHeight=math.max(line+diameter+2,line*2+4),walletLineHeight=walletLine,countWidth=TextService:GetTextSize("24/24",12,Enum.Font.Gotham,Vector2.new(1000,100)).X+4})
			local compact=l.short or l.dense or l.quest.h<60
			local host=frame("Quest",l.quest);local quest=Quest.new(host)
			local meter=frame("Meter",l.meter);local dispenser=Dispenser.new(meter,function()return true end)
			dispenser:update(1,1,24,true)
			local wallet=frame("Wallet",l.wallet)
			local amount=Art.text(wallet,"Amount","6",UDim2.fromOffset(26,0),UDim2.new(1,-26,1,0),Art.Silver,12)
			Art.type(amount,if l.short or l.dense or not l.lateral then "Supporting" else "Action",l.short or l.dense or not l.lateral)
			settle();dispenser:layout()
			for stage=0,2 do
				quest:update(stage,"Playing",true,compact);settle();readable(quest.title)
				local text=quest.title.Text
				if stage==0 then assert(text:find("LEFT",1,true) or text:find("←",1,true),"left target lost from compact instruction")
				elseif stage==1 then assert(text:find("RIGHT",1,true) or text:find("→",1,true),"right target lost from compact instruction")
				else assert(text:lower():find("done",1,true) or text:find("✓",1,true),"completion state lost") end
			end
			readable(amount);readable(dispenser.label)
			assert(l.tray.w>=70-1e-6 and l.tray.h>=120-1e-6 and l.menu.w>=44-1e-6 and l.menu.h>=44-1e-6 and l.lounge.w>=44-1e-6 and l.lounge.h>=44-1e-6,"handheld minimums: tray="..l.tray.w.."x"..l.tray.h..", menu="..l.menu.w.."x"..l.menu.h..", lounge="..l.lounge.w.."x"..l.lounge.h)
			table.insert(cases,tostring(size).." active LEFT RIGHT complete and exact wallet/drop count fit")
			root:ClearAllChildren()
		end
	end)
	root:Destroy();assert(ok,problem)
	return{passed=#cases,cases=cases,preference=GuiService.PreferredTextSize.Name}
end
