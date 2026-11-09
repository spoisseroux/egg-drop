-- Execute this fixture from a real LocalScript with a ScreenGui parent at Medium, then Largest.
-- Plugin-thread TextService measurements and Frames directly under PlayerGui do not exercise the game text pipeline.
-- The engine preference is read-only.
-- This fixture never changes player settings, remotes, purchases, inventory or save data.
return function(client,parent)
	local GuiService=game:GetService("GuiService")
	assert(parent:IsA("ScreenGui") or parent:FindFirstAncestorOfClass("ScreenGui"),"preferred text fixture requires a real ScreenGui host")
	local Art=require(client.DeckArt)
	local Menu=require(client.DeckMenu)
	local Recap=require(client.RoundRecap)
	local Shop=require(client.EggHatchView)
	local Catalog=require(game.ReplicatedStorage.Shared.EggCatalog)
	local Mastery=require(game.ReplicatedStorage.Shared.FamilyMastery)
	local root=Instance.new("Frame");root.Name="_PreferredTextLayout";root.BackgroundTransparency=1;root.Parent=parent
	local cases,views={},{}
	local function test(name,run)run();table.insert(cases,name)end
	local function settle()game:GetService("RunService").Heartbeat:Wait();game:GetService("RunService").Heartbeat:Wait()end
	local function readable(label)
		assert(label.TextFits,"preferred text clipped: "..label:GetFullName().." ["..label.Text.."] "..tostring(label.AbsoluteSize))
		assert(not label.TextScaled and not label:FindFirstChildOfClass("UITextSizeConstraint"),"preference disabled: "..label.Name)
	end
	local function state()
		return{status="Ready",nectar=20,inventoryMask=Catalog.mask({"pip","wick"}),dailyAvailable=false,
			contracts={{title="Finish 2 quests",progress=1,target=2,reward=4},{title="Chain 3 merges",progress=2,target=3,reward=3},{title="Score 500",progress=300,target=500,reward=3}},
			mastery={pip=3,wick=25},masteryDetails={pip=Mastery.describe(3,0),wick=Mastery.describe(25,0)}}
	end
	local ok,problem=pcall(function()
		for _,size in ipairs({Vector2.new(680,700),Vector2.new(390,740),Vector2.new(568,160)})do
			root.Size=UDim2.fromOffset(size.X,size.Y);settle()
			local menu=Menu.new(root,{close=function()end});table.insert(views,menu.shade)
			menu:update(state(),"pip","wick",500,3,700,"meadow");menu:open();settle()
			test(tostring(size).." measured Daily and destinations preserve tabs and readable full content",function()
				local tabY=menu.tabs.play.AbsolutePosition.Y
				for _,page in ipairs({"daily","play","daily"})do
					menu:setPage(page);settle();assert(menu.tabs.play.AbsolutePosition.Y==tabY)
					readable(menu.heading);readable(menu.nectar)
					assert(menu.nectar.Font==Art.Font.Counter)
					for _,tab in pairs(menu.tabs)do readable(tab);assert(tab.AbsoluteSize.Y>=44)end
					if page=="daily" then
						readable(menu.dailyButton);assert(menu.dailyButton.AbsoluteSize.Y>=44)
						for _,row in ipairs(menu.dailyCards)do readable(row.title);readable(row.count);readable(row.reward)end
						readable(menu.dailyHint)
					else
						assert(not menu.playHint.Visible and menu.playHint.Size.Y.Offset==0)
						for _,entry in ipairs(menu.destinations)do readable(entry.title);if entry.subtitle.Visible then readable(entry.subtitle)end;assert(entry.button.AbsoluteSize.Y>=44)end
					end
					menu.body.CanvasPosition=Vector2.new(0,math.max(0,menu.body.CanvasSize.Y.Offset-menu.body.AbsoluteSize.Y));settle()
					local last=if page=="daily"then menu.dailyHint else menu.destinations[#menu.destinations].button
					assert(last.AbsolutePosition.Y+last.AbsoluteSize.Y<=menu.body.AbsolutePosition.Y+menu.body.AbsoluteSize.Y+1,"final text cannot scroll into view")
				end
			end)
			menu:close()
			local shop=Shop.new(root,{play=function()end},function()return true end,function()error("fixture must not purchase")end)
			table.insert(views,shop.shade);shop:open(state());settle()
			test(tostring(size).." measured shop header and pinned purchase route fit",function()
				for _,balance in ipairs({0,20,1000000}) do
					local snapshot=state();snapshot.nectar=balance
					shop:update(snapshot);settle()
					readable(shop.heading);readable(shop.action)
						assert(shop.action.Font==Art.Font.Action and shop.action.AbsoluteSize.Y>=44)
					assert(shop.nectar.Visible and shop.nectar.Text==tostring(balance) and shop.nectar:GetAttribute("AccessibleLabel")==tostring(balance).." Stars")
					do
						readable(shop.nectar)
						assert(shop.nectar.AbsolutePosition.X>=shop.wallet.AbsolutePosition.X and shop.nectar.AbsolutePosition.X+shop.nectar.AbsoluteSize.X<=shop.wallet.AbsolutePosition.X+shop.wallet.AbsoluteSize.X,"amount exceeds its chip")
					end
					if shop.note.Visible then readable(shop.note)end
					assert(shop.action.AbsoluteSize.Y>=44 and shop.closeButton.AbsoluteSize==Vector2.new(44,44))
					assert(shop.body.AbsoluteSize.Y>=44 and shop.body.AbsolutePosition.Y+shop.body.AbsoluteSize.Y<=shop.action.AbsolutePosition.Y,"shop must preserve a whole44px row outside footer at balance "..balance)
					assert(shop.selected=="meadow" and (balance<18 or shop.action.Text:find("18",1,true)),"selected cost lost from affordable CTA")
				end
			end)
			shop:close()
			root.Size=UDim2.fromOffset(if size.Y<200 then 536 else math.min(600,size.X),if size.Y<200 then 144 else 500);settle()
			local recap=Recap.new(root,nil,true);table.insert(views,recap.frame);recap.frame.Visible=true
			recap:update(600,3,0,nil,0,nil,0,700)
			recap:updateField({sequence=1,status="Saved",success=true,stage=2,award=8,daily=0,balance=9,recipe=Catalog.ById.meadow,
				reward={sequence=1,total=8,base=8,daily=0,family="wick",masteryPoints=1,contracts={}},mastery=Mastery.describe(25,0)})
			settle()
			test(tostring(size).." recap reward wallet and complete receipt stay readable",function()
				for _,label in ipairs({recap.earnedGraphic,recap.componentLabels[1],recap.componentLabels[2]})do readable(label)end
				assert(recap.earnedGraphic.Font==Art.Font.Reward)
				for _,label in ipairs(recap.componentLabels)do readable(label);assert(label.Font==Art.Font.Counter)end
				recap:setDetails(true);settle();for _,row in ipairs(recap.receiptRows)do readable(row)end
				local iterations=0;while recap:scrollReceipt(1)do iterations+=1;assert(iterations<100)end
				settle();local last=recap.receiptRows[#recap.receiptRows]
				assert(last.AbsolutePosition.Y+last.AbsoluteSize.Y<=recap.fieldBody.AbsolutePosition.Y+recap.fieldBody.AbsoluteSize.Y+1)
			end)
			recap.frame:Destroy()
		end
	end)
	for _,view in ipairs(views)do view:Destroy()end;root:Destroy();assert(ok,problem)
	return{passed=#cases,cases=cases,preference=GuiService.PreferredTextSize.Name}
end
