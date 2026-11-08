-- Real LocalScript + ScreenGui host, run at Medium and Largest. No account writes/remotes.
return function(client,parent)
	assert(parent:IsA("ScreenGui") or parent:FindFirstAncestorOfClass("ScreenGui"),"ScreenGui host required")
	local Menu=require(client.DeckMenu);local Shop=require(client.EggHatchView)
	local Mastery=require(game.ReplicatedStorage.Shared.FamilyMastery)
	local root=Instance.new("Frame");root.BackgroundTransparency=1;root.Parent=parent
	local cases,views={},{}
	local function settle()game:GetService("RunService").Heartbeat:Wait();game:GetService("RunService").Heartbeat:Wait()end
	local function test(name,run)run();table.insert(cases,name)end
	local function inside(node,host)
		local p,s,hp,hs=node.AbsolutePosition,node.AbsoluteSize,host.AbsolutePosition,host.AbsoluteSize
		return p.X>=hp.X-.1 and p.Y>=hp.Y-.1 and p.X+s.X<=hp.X+hs.X+.1 and p.Y+s.Y<=hp.Y+hs.Y+.1
	end
	local function state()
		return{status="Ready",revision=12,nectar=6,inventoryMask=127,dailyAvailable=false,dailyDay="20000",
			contracts={{title="Finish 2 quests",progress=1,target=2,reward=4},{title="Chain 3 merges",progress=2,target=3,reward=3},
				{title="Score 500",progress=300,target=500,reward=3}},mastery={pip=3,wick=3},
			masteryDetails={pip=Mastery.describe(3,0),wick=Mastery.describe(3,0)}}
	end
	local function resize(w,h)root.Size=UDim2.fromOffset(w,h);settle()end
	local ok,problem=pcall(function()
		for _,height in ipairs({306,307,308})do
			resize(733,height)
			local menu=Menu.new(root,{close=function()end});table.insert(views,menu.shade)
			menu:update(state(),"wick","pip",0,0,0,"sprout");menu:open();settle()
			test("733x"..height.." measured menu landing shows all destination titles with stable tabs",function()
				assert(menu.shallow and menu.compact and menu.bodyBudget>=menu.body.AbsoluteSize.Y-1)
				assert(menu.body.CanvasPosition.Y==0 and menu.headerHeight<=116)
				for index,item in ipairs(menu.destinations)do
     if index>3 then menu.body.CanvasPosition=Vector2.new(0,math.clamp(item.button.Position.Y.Offset,0,math.max(0,menu.body.CanvasSize.Y.Offset-menu.body.AbsoluteSize.Y)));settle()end
					assert(inside(item.button,menu.body) and inside(item.title,menu.body),"first destination row clipped: "..item.kind)
					assert(item.title.TextFits and item.art.AbsoluteSize.X>=32 and item.button.AbsoluteSize.Y>=44)
					assert(not item.subtitle.Visible,"secondary caption must yield before primary title")
				end
				menu.body.CanvasPosition=Vector2.zero
				local tabY=menu.tabs.play.AbsolutePosition.Y
				for _,page in ipairs({"daily","mastery","play"})do
					menu:setPage(page);settle();assert(menu.tabs.play.AbsolutePosition.Y==tabY)
					for _,tab in pairs(menu.tabs)do assert(tab.AbsoluteSize.Y>=44 and tab.TextFits)end
					if page=="daily" then
						for _,row in ipairs(menu.dailyCards)do assert(inside(row.panel,menu.body) and row.title.TextFits and row.count.TextFits and row.reward.TextFits)end
					elseif page=="mastery" then
						assert(menu.familyCards.wick.Position.Y.Offset<menu.familyCards.pip.Position.Y.Offset,"selected family must lead")
						assert(inside(menu.families.wick.FamilyName,menu.body) and inside(menu.familyText.wick,menu.body) and inside(menu.familyHints.wick,menu.body),"first family name/marks/goal below fold")
						assert(menu.familyHints.wick.TextFits and menu.familyNote.Position.Y.Offset>menu.familyCards.orbit.Position.Y.Offset)
					end
				end
				menu:setPage("mastery");menu.body.CanvasPosition=Vector2.new(0,80);settle();local before=menu.body.CanvasPosition.Y
				menu:update(state(),"wick","pip",10,0,0,"sprout");settle();assert(menu.body.CanvasPosition.Y==before)
				menu:close();menu:open();settle();assert(menu.body.CanvasPosition.Y==0)
			end)
			menu:close()
			local shop=Shop.new(root,{play=function()end},function()return true end,function()error("browse cannot send")end)
			table.insert(views,shop.shade);shop:open(state());shop:selectRecipe("sprout");settle()
			test("733x"..height.." shop shows both complete recipes above a pinned exact shortfall",function()
				assert(shop.compactShop and shop.budgetCompact and shop.body.CanvasPosition.Y==0)
				for _,id in ipairs({"meadow","sprout"})do
					local row=shop.body.EggColumn["Recipe_"..id]
					assert(row.AbsoluteSize.Y>=44 and inside(row,shop.body) and row.RecipeName.TextFits and row.Cost.TextFits)
					assert(row:FindFirstChild("Egg"),"recipe silhouette lost")
				end
				assert(shop.selected=="sprout" and shop.action.Text:find("18",1,true) and shop.action.TextFits and shop.action.AbsoluteSize.Y>=44)
				assert(shop.body.AbsolutePosition.Y+shop.body.AbsoluteSize.Y<=shop.action.AbsolutePosition.Y)
				local odds=shop.body.OutcomeColumn
				assert(odds.Outcome_pip.Probability.Text=="80%" and odds.Outcome_bloom_pip.Probability.Text=="20%")
				shop.body.CanvasPosition=Vector2.new(0,math.max(0,shop.body.CanvasSize.Y.Offset-shop.body.AbsoluteSize.Y));settle()
				assert(inside(odds.Duplicates,shop.body) and odds.Duplicates.TextFits)
			end)
			shop:close()
		end
		test("portrait selection rotated to landscape stays selected at the top without a purchase",function()
			resize(385,703);local shop=Shop.new(root,{play=function()end},function()return true end,function()error("rotation cannot send")end)
			table.insert(views,shop.shade);shop:open(state());shop:selectRecipe("sprout");settle()
			assert(not shop.compactShop and shop.body.EggColumn.Recipe_sprout.AbsoluteSize.Y>=83)
			shop.body.CanvasPosition=Vector2.new(0,100);resize(733,307);settle()
			assert(shop.selected=="sprout" and shop.body.CanvasPosition.Y==0 and inside(shop.body.EggColumn.Recipe_sprout,shop.body))
			assert(shop.body.EggColumn.Recipe_sprout.Cost.Text:find("24",1,true) and shop.action.Text:find("18",1,true))
			resize(385,703);assert(not shop.compactShop and shop.selected=="sprout");shop:close()
		end)
		test("roomy desktop menu and shop retain their illustrated layouts",function()
			resize(1400,900);local menu=Menu.new(root,{close=function()end});table.insert(views,menu.shade)
			menu:update(state(),"pip","pip",0,0,0,"meadow");menu:open();settle()
			assert(not menu.compact and menu.destinations[1].art.AbsoluteSize.X==72 and menu.destinations[1].subtitle.Visible);menu:close()
			local shop=Shop.new(root,{play=function()end},function()return true end,function()error("browse cannot send")end)
			table.insert(views,shop.shade);shop:open(state());settle()
			assert(not shop.compactShop and shop.body.EggColumn.Recipe_meadow.AbsoluteSize.Y>=83 and shop.body.EggColumn.Recipe_meadow.Cost.TextFits);shop:close()
		end)
	end)
	for _,view in ipairs(views)do view:Destroy()end;root:Destroy();assert(ok,problem)
	return{passed=#cases,cases=cases,preference=game:GetService("GuiService").PreferredTextSize.Name}
end
