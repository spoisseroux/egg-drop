-- Native Client fixtures. Callback counters replace remotes and account writes.
return function(client, parent)
	local Menu = require(client.DeckMenu)
	local Mastery = require(game:GetService("ReplicatedStorage").Shared.FamilyMastery)
	local root = Instance.new("Frame")
	root.Name, root.Size, root.BackgroundTransparency, root.Parent = "_MenuPolishSpec", UDim2.fromOffset(568, 390), 1, parent
	local views, cases = {}, {}
	local function fitDiagnostic(...)
		local rows={}
		for _,node in ipairs({...})do
			table.insert(rows,string.format("%s text=%q size=%s bounds=%s position=%s fontSize=%s visible=%s fits=%s",
				node:GetFullName(),node.Text,tostring(node.AbsoluteSize),tostring(node.TextBounds),tostring(node.AbsolutePosition),
				tostring(node.TextSize),tostring(node.Visible),tostring(node.TextFits)))
		end
		return table.concat(rows," | ")
	end
	local function test(name, run) run(); table.insert(cases, name) end
	local function snapshot()
		return { status = "Ready", nectar = 24, inventoryMask = 127, dailyAvailable = true, dailyBonus = 6,
			-- Hatching v9: today's quests replace the daily contracts.
			quests = { day = "20", daily = { { id = "d_wins2", title = "Win 2 rounds", progress = 1, target = 2, reward = 4 },
				{ id = "d_chain3", title = "Chain 3 merges", progress = 3, target = 3, reward = 4, claimed = true },
				{ id = "d_score600", title = "Score 600", progress = 250, target = 600, reward = 4 } } },
			mastery = { pip = 60, wick = 25 }, masteryDetails = { pip = Mastery.describe(60, 7), wick = Mastery.describe(25, 5) } }
	end
	local function fixture()
		local calls, callbacks = {}, {}
		for _, key in ipairs({ "close", "eggs", "pets", "style", "trials", "settings", "play", "daily", "family" }) do
			callbacks[key] = function(value) table.insert(calls, { key, value }) end
		end
		local menu = Menu.new(root, callbacks)
		table.insert(views, menu)
		menu:update(snapshot(), "pip", "wick", 500, 3, 1000, "sprout"); menu:open()
		return menu, calls
	end
	local function resize(menu,width,height)
		root.Size=UDim2.fromOffset(width,height);menu:layout()
		local deadline=os.clock()+2
		repeat task.wait(.03) until menu.shade.AbsoluteSize==Vector2.new(width,height) or os.clock()>=deadline
		menu:layout();task.wait(.03)
	end
	local function inside(node, host)
		return node.AbsolutePosition.X >= host.AbsolutePosition.X - .1 and node.AbsolutePosition.Y >= host.AbsolutePosition.Y - .1
			and node.AbsolutePosition.X + node.AbsoluteSize.X <= host.AbsolutePosition.X + host.AbsoluteSize.X + .1
			and node.AbsolutePosition.Y + node.AbsoluteSize.Y <= host.AbsolutePosition.Y + host.AbsoluteSize.Y + .1
	end
	local ok, problem = pcall(function()
		test("one readable header and44px controls fit desktop portrait and shallow roots",function()
			local menu=fixture()
			for _,size in ipairs({Vector2.new(568,160),Vector2.new(350,279),Vector2.new(568,390),Vector2.new(390,740),Vector2.new(1649,971)}) do
				resize(menu,size.X,size.Y)
				assert(menu.heading.TextFits and menu.nectar.TextFits and menu.nectar.Text=="24" and menu.nectar:GetAttribute("AccessibleLabel")=="24 Stars",fitDiagnostic(menu.heading,menu.nectar))
				assert(menu.closeButton.Text=="×" and menu.closeButton:GetAttribute("AccessibleLabel")=="Close")
				for _,tab in pairs(menu.tabs) do
					assert(tab.AbsoluteSize.Y>=44 and tab.TextFits and inside(tab,menu.card),fitDiagnostic(tab))
					assert(menu.body.AbsolutePosition.Y>=tab.AbsolutePosition.Y+tab.AbsoluteSize.Y+4,"body overlaps measured tab: "..fitDiagnostic(tab))
				end
				local roomy=size.X>=1000 and size.Y>=650
                local maximumWidth=math.min(if roomy then 740 else 680,size.X-24)
                assert(menu.card.AbsoluteSize.Y<=size.Y and menu.card.AbsoluteSize.X<=maximumWidth+.1 and inside(menu.card,menu.shade),"approved roomy/compact sheet bounds exceeded")
			end
			menu:close()
		end)
		test("page changes keep absolute header and tab positions stable",function()
			local menu=fixture();resize(menu,1649,971);menu:open();task.wait(.03)
			local headerY,tabY=menu.heading.AbsolutePosition.Y,menu.tabs.play.AbsolutePosition.Y
			for _,key in ipairs({"daily","play","daily","play","daily"}) do
				menu:setPage(key);task.wait(.03)
				assert(menu.heading.AbsolutePosition.Y==headerY and menu.tabs.play.AbsolutePosition.Y==tabY,"tabs shifted on "..key)
			end
			menu:close()
		end)
		test("complete illustrated destinations start below the scroll clip",function()
			local menu,calls=fixture();resize(menu,680,700);menu:setPage("play");task.wait(.03)
			assert(#menu.destinations==3 and not menu.resumeButton and not menu.card:FindFirstChild("Deck",true)and not menu.dailyButton.Visible)
			for _,item in ipairs(menu.destinations) do
				assert(item.art.Visible and #item.art:GetChildren()>0 and item.title.TextFits and item.subtitle.TextFits,fitDiagnostic(item.title,item.subtitle))
				assert(item.button.Position.Y.Offset>=4 and item.art.Position.Y.Offset>=8)
				assert(menu:activate(item.kind))
			end
			assert(menu:activate("close") and #calls==4)
			menu:close()
		end)
        test("roomy destination text grows within measured cards and retired shortcuts refuse activation",function()
            local menu,calls=fixture();resize(menu,568,160);menu:setPage("play");task.wait(.03)
            local compactTitle=menu.destinations[1].title.TextSize
            local compactTab=menu.tabs.play.TextSize
            resize(menu,1649,971);menu:setPage("play");task.wait(.03)
            assert(menu.roomy and not menu.compact)
            for _,item in ipairs(menu.destinations)do
                assert(item.title.TextSize>=require(client.DeckArt).Type.Action and item.subtitle.TextSize>=require(client.DeckArt).Type.Supporting and item.title.TextFits and item.subtitle.TextFits,fitDiagnostic(item.title,item.subtitle))
                assert(inside(item.title,item.button)and inside(item.subtitle,item.button),"larger text escaped its measured card")
                assert(item.subtitle.AbsolutePosition.Y>=item.title.AbsolutePosition.Y+item.title.AbsoluteSize.Y+5.9,"roomy labels overlap")
                assert(item.kind~="pets"and item.kind~="style")
            end
            assert(not menu:activate("pets")and not menu:activate("style")and #calls==0)
            assert(not menu.playHint.Visible and menu.playHint.Size.Y.Offset==0)
            resize(menu,568,160);menu:setPage("play");task.wait(.03)
            assert(menu.destinations[1].title.TextSize==compactTitle and menu.tabs.play.TextSize==compactTab,"roomy-only change leaked into compact type")
            menu:close()
        end)
		test("all three shallow contracts show a complete44px first row and independent gift",function()
			local menu,calls=fixture();resize(menu,568,160);menu:setPage("daily");task.wait(.03)
			assert(menu.dailyButton.Visible and menu.dailyButton.AbsoluteSize.Y>=44 and menu.dailyButton.TextFits and inside(menu.dailyButton,menu.card),fitDiagnostic(menu.dailyButton))
			-- Largest text in the 160px safe area deliberately uses a scrollable
			-- exception: the complete gift/action row leads, contracts follow.
			if menu.dailyButton.Parent==menu.pages.daily then assert(inside(menu.dailyButton,menu.body),"first gift/action row must be complete") end
			for _,row in ipairs(menu.dailyCards) do
				assert(row.panel.AbsoluteSize.Y>=44 and inside(row.panel,menu.pages.daily),"contract outside scroll content")
				assert(row.title.TextFits and row.count.TextFits and row.reward.TextFits,fitDiagnostic(row.title,row.count,row.reward))
				local scroll=menu.body
				local contentTop=row.panel.AbsolutePosition.Y-scroll.AbsolutePosition.Y+scroll.CanvasPosition.Y
				local maximum=math.max(0,scroll.CanvasSize.Y.Offset-scroll.AbsoluteSize.Y)
				for _,edge in ipairs({"top","bottom"})do
					local target=contentTop+(if edge=="bottom" then row.panel.AbsoluteSize.Y-scroll.AbsoluteSize.Y else 0)
					scroll.CanvasPosition=Vector2.new(0,math.clamp(target,0,maximum))
					game:GetService("RunService").RenderStepped:Wait();game:GetService("RunService").RenderStepped:Wait()
					if row.panel.AbsoluteSize.Y<=scroll.AbsoluteSize.Y then
						assert(inside(row.panel,scroll),"complete contract row not reachable")
					elseif edge=="top" then
						assert(row.panel.AbsolutePosition.Y>=scroll.AbsolutePosition.Y-.1 and row.panel.AbsolutePosition.Y<scroll.AbsolutePosition.Y+scroll.AbsoluteSize.Y,"contract top not reachable")
					else
						local bottom=row.panel.AbsolutePosition.Y+row.panel.AbsoluteSize.Y
						assert(bottom<=scroll.AbsolutePosition.Y+scroll.AbsoluteSize.Y+.1 and bottom>scroll.AbsolutePosition.Y,"contract bottom not reachable")
					end
					assert(inside(scroll,menu.card),"scroll content covers menu chrome")
				end
			end
			assert(menu.dailyCards[1].count.Text=="1/2" and menu.dailyCards[2].complete)
			assert(menu:activate("daily") and #calls==1 and calls[1][1]=="daily")
			menu:close()
		end)
		test("claimed gift cannot claim again and earned contracts remain informational",function()
			local menu,calls=fixture();resize(menu,390,740);menu:setPage("daily")
			local state=snapshot();state.dailyAvailable=false
			menu:update(state,"pip","wick",0,0,0,"meadow");task.wait(.03)
			assert(menu.dailyButton.Text==require(game:GetService("ReplicatedStorage").Shared.UICopy).get("stamp.done") and not menu.dailyButton.Interactable and not menu:activate("daily") and #calls==0)
			assert(menu.dailyCards[2].reward.Text=="Claimed" and menu.dailyCards[1].reward.Text=="+4 Stars")
			-- Play-forever F2: the stamp card sits on the daily page whether or not today's stamp is in.
			assert(menu.stampCard and menu.stampCard.root.Parent==menu.pages.daily and inside(menu.stampCard.root,menu.pages.daily),"stamp card on the daily page")
			menu:close()
		end)
		test("fresh open and page entry reset scroll while snapshots retain reading position",function()
			local menu=fixture();resize(menu,568,160);menu:setPage("play");task.wait(.03)
			menu.body.CanvasPosition=Vector2.new(0,100);task.wait(.03)
			local before=menu.body.CanvasPosition.Y
			menu:update(snapshot(),"pip","wick",500,3,1000,"sprout");task.wait(.03)
			assert(menu.body.CanvasPosition.Y==before,"snapshot moved reading position")
			menu:close();menu:open();task.wait(.03);assert(menu.body.CanvasPosition.Y==0)
			menu:setPage("play");task.wait(.03);assert(menu.body.CanvasPosition.Y==0 and menu.destinations[1].button.Position.Y.Offset>=4)
			menu:close()
		end)
		test("scroll cue ends at reachable content and small pages end after content",function()
			local menu=fixture();resize(menu,568,160);menu:setPage("daily");task.wait(.03)
			assert(menu.moreCue.Visible and menu.body.ScrollBarImageTransparency==0)
			menu.body.CanvasPosition=Vector2.new(0,menu.body.CanvasSize.Y.Offset-menu.body.AbsoluteSize.Y);task.wait(.03)
			assert(not menu.moreCue.Visible)
			resize(menu,1649,971);menu:setPage("daily");task.wait(.03)
			assert(inside(menu.card,root) and menu.card.AbsoluteSize.Y<=root.AbsoluteSize.Y,"measured card exceeds viewport")
			local scroll,hint=menu.body,menu.dailyHint
			assert(hint.TextFits,fitDiagnostic(hint))
			local contentBottom=hint.AbsolutePosition.Y+hint.AbsoluteSize.Y-scroll.AbsolutePosition.Y+scroll.CanvasPosition.Y
			local tail=scroll.CanvasSize.Y.Offset-contentBottom
			assert(tail>=-.1 and tail<=menu.pad+.1,"empty tail after final measured content: "..tail)
			local overflow=scroll.CanvasSize.Y.Offset>scroll.AbsoluteSize.Y+1
			assert(menu.moreCue.Visible==overflow,"cue must match real measured overflow")
			if not overflow then
				assert(scroll.AbsoluteSize.Y-scroll.CanvasSize.Y.Offset<=1,"content-fit card stretches empty body")
			else
				scroll.CanvasPosition=Vector2.new(0,scroll.CanvasSize.Y.Offset-scroll.AbsoluteSize.Y)
				game:GetService("RunService").RenderStepped:Wait();game:GetService("RunService").RenderStepped:Wait()
				assert(not menu.moreCue.Visible,"cue persists at the reachable scroll end")
			end
			local bottomGap=menu.card.AbsolutePosition.Y+menu.card.AbsoluteSize.Y-hint.AbsolutePosition.Y-hint.AbsoluteSize.Y
			assert(bottomGap>=-.1 and bottomGap<=menu.pad+16,"card does not end after its final content: "..bottomGap)
			menu:close()
		end)
        test("retired mastery and egg goal leave only distinct Play and Daily destinations",function()
            local menu,calls=fixture();resize(menu,350,279)
            assert(menu.tabs.mastery==nil and menu.pages.mastery==nil and menu.recipePanel==nil)
            assert(not menu.card:FindFirstChild("EggGoalPanel",true)and not menu.card:FindFirstChild("FamilyNote",true))
            menu:setPage("play");assert(menu.tabs.play:GetAttribute("SelectedTab")and not menu.tabs.daily:GetAttribute("SelectedTab")and not menu.tabs.play:FindFirstChild("SelectedEdge"))
            assert(menu.tabs.play.BackgroundColor3~=menu.tabs.daily.BackgroundColor3 and menu.tabs.play.TextColor3~=menu.tabs.daily.TextColor3)
            menu:setPage("daily");assert(menu.tabs.daily:GetAttribute("SelectedTab")and not menu.tabs.play:GetAttribute("SelectedTab")and not menu.tabs.daily:FindFirstChild("SelectedEdge"))
            assert(not menu:activate("family","pip")and #calls==0)
            menu:close()
        end)
		test("hidden and unchanged snapshots perform no text measurement layout",function()
			local menu=fixture();resize(menu,680,700);menu:setPage("play");task.wait(.03)
			menu:close();local before=menu.layoutPasses
			for i=1,12 do menu:update(snapshot(),"pip","wick",500+i,3,1000,"sprout") end
			assert(menu.layoutPasses==before,"hidden update measured cards")
			menu:open();before=menu.layoutPasses
			for i=1,12 do menu:update(snapshot(),"pip","wick",500+i,3,1000,"sprout") end
			assert(menu.layoutPasses==before,"unchanged visible update reflowed cards")
            local changed=snapshot();changed.masteryDetails.wick.nextGoal="Archived condition"
            menu:update(changed,"pip","wick",500,3,1000,"sprout")
            assert(menu.layoutPasses==before,"archived mastery must not measure live UI")
			menu:close()
		end)

	end)
	for _,menu in ipairs(views) do menu:close();menu.shade:Destroy() end
	root:Destroy();assert(ok,problem)
	return{passed=#cases,cases=cases}
end
