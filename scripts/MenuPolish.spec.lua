-- Native Client fixtures. Callback counters replace remotes and account writes.
return function(client, parent)
	local Menu = require(client.DeckMenu)
	local Mastery = require(game:GetService("ReplicatedStorage").Shared.FamilyMastery)
	local root = Instance.new("Frame")
	root.Name, root.Size, root.BackgroundTransparency, root.Parent = "_MenuPolishSpec", UDim2.fromOffset(568, 390), 1, parent
	local views, cases = {}, {}
	local function test(name, run) run(); table.insert(cases, name) end
	local function snapshot()
		return { status = "Ready", nectar = 24, inventoryMask = 127, dailyAvailable = true, dailyBonus = 6,
			contracts = { { id = "runs", title = "Finish 2 quests", progress = 1, target = 2, reward = 4 },
				{ id = "chain", title = "Chain 3 merges", progress = 3, target = 3, reward = 3, claimed = true },
				{ id = "score", title = "Score 500", progress = 250, target = 500, reward = 3 } },
			mastery = { pip = 60, wick = 25 }, masteryDetails = { pip = Mastery.describe(60, 7), wick = Mastery.describe(25, 5) } }
	end
	local function fixture()
		local calls, callbacks = {}, {}
		for _, key in ipairs({ "close", "eggs", "pets", "style", "play", "daily", "family" }) do
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
				assert(menu.heading.TextFits and menu.nectar.TextFits and menu.nectar.Text=="24 nectar")
				assert(menu.closeButton.Text=="×" and menu.closeButton:GetAttribute("AccessibleLabel")=="Close")
				for _,tab in pairs(menu.tabs) do
					assert(tab.AbsoluteSize.Y==44 and tab.TextFits and inside(tab,menu.card))
					assert(menu.body.AbsolutePosition.Y>=tab.AbsolutePosition.Y+44+4)
				end
				assert(menu.card.AbsoluteSize.Y<=size.Y and menu.card.AbsoluteSize.X<=680)
			end
			menu:close()
		end)
		test("page changes keep absolute header and tab positions stable",function()
			local menu=fixture();resize(menu,1649,971);menu:open();task.wait(.03)
			local headerY,tabY=menu.heading.AbsolutePosition.Y,menu.tabs.play.AbsolutePosition.Y
			for _,key in ipairs({"daily","mastery","play","mastery","daily"}) do
				menu:setPage(key);task.wait(.03)
				assert(menu.heading.AbsolutePosition.Y==headerY and menu.tabs.play.AbsolutePosition.Y==tabY,"tabs shifted on "..key)
			end
			menu:close()
		end)
		test("complete illustrated destinations start below the scroll clip",function()
			local menu,calls=fixture();resize(menu,680,700);menu:setPage("play");task.wait(.03)
			assert(#menu.destinations==3 and menu.resumeButton.Visible and not menu.dailyButton.Visible)
			for _,item in ipairs(menu.destinations) do
				assert(item.art.Visible and #item.art:GetChildren()>0 and item.title.TextFits and item.subtitle.TextFits)
				assert(item.button.Position.Y.Offset>=12 and item.art.Position.Y.Offset>=8)
				assert(menu:activate(item.kind))
			end
			assert(menu:activate("play") and menu:activate("close") and #calls==5)
			menu:close()
		end)
		test("all three shallow contracts show a complete44px first row and independent gift",function()
			local menu,calls=fixture();resize(menu,568,160);menu:setPage("daily");task.wait(.03)
			assert(menu.dailyButton.Visible and menu.dailyButton.AbsoluteSize.Y==44 and inside(menu.dailyButton,menu.card))
			for _,row in ipairs(menu.dailyCards) do
				assert(row.panel.AbsoluteSize.Y>=44 and inside(row.panel,menu.body))
				assert(row.title.TextFits and row.count.TextFits and row.reward.TextFits)
			end
			assert(menu.dailyCards[1].count.Text=="1/2" and menu.dailyCards[2].complete)
			assert(menu:activate("daily") and #calls==1 and calls[1][1]=="daily")
			menu:close()
		end)
		test("claimed gift cannot claim again and earned contracts remain informational",function()
			local menu,calls=fixture();resize(menu,390,740);menu:setPage("daily")
			local state=snapshot();state.dailyAvailable=false
			menu:update(state,"pip","wick",0,0,0,"meadow");task.wait(.03)
			assert(menu.dailyButton.Text=="Gift claimed" and not menu.dailyButton.Interactable and not menu:activate("daily") and #calls==0)
			assert(menu.dailyCards[2].reward.Text=="Earned" and menu.dailyCards[1].reward.Text=="+4 nectar")
			menu:close()
		end)
		test("fresh open and page entry reset scroll while snapshots retain reading position",function()
			local menu=fixture();resize(menu,568,160);menu:setPage("mastery");task.wait(.03)
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
			assert(menu.card.AbsoluteSize.Y<500 and not menu.moreCue.Visible)
			menu:close()
		end)
		test("mastery cards wrap exact missing conditions at real body size",function()
			local menu=fixture();resize(menu,350,279);menu:setPage("mastery");task.wait(.03)
			assert(menu.familyHints.wick.Text:find("Win with a chain of 3",1,true) and not menu.familyHints.wick.Text:find("Clean win",1,true))
			assert(menu.familyHints.pip.Text:find("Family mastered",1,true) and menu.families.pip.FamilyCrest:GetAttribute("Rank")==3)
			for _,family in ipairs({"pip","wick"}) do
				assert(menu.familyHints[family].TextFits and menu.familyHints[family].TextSize>=14 and not menu.familyHints[family].TextScaled)
				assert(menu.families[family].AbsoluteSize.Y==44)
			end
			menu:close()
		end)
		test("hidden and unchanged snapshots perform no text measurement layout",function()
			local menu=fixture();resize(menu,680,700);menu:setPage("mastery");task.wait(.03)
			menu:close();local before=menu.layoutPasses
			for i=1,12 do menu:update(snapshot(),"pip","wick",500+i,3,1000,"sprout") end
			assert(menu.layoutPasses==before,"hidden update measured cards")
			menu:open();before=menu.layoutPasses
			for i=1,12 do menu:update(snapshot(),"pip","wick",500+i,3,1000,"sprout") end
			assert(menu.layoutPasses==before,"unchanged visible update reflowed cards")
			local changed=snapshot();changed.masteryDetails.wick.nextGoal="Complete the remaining exact challenge"
			menu:update(changed,"pip","wick",500,3,1000,"sprout")
			assert(menu.layoutPasses==before+1,"changed visible condition must resize its page")
			menu:close()
		end)
		test("locked family rows are shorter and cannot select a family",function()
			local menu,calls=fixture();resize(menu,680,700)
			local state=snapshot();state.inventoryMask=1
			menu:update(state,"pip","pip",0,0,0,"meadow");menu:setPage("mastery");task.wait(.03)
			assert(not menu.families.wick.Interactable and not menu.families.wick.Selectable and not menu:activate("family","wick"))
			assert(menu.familyCards.wick.AbsoluteSize.Y<menu.familyCards.pip.AbsoluteSize.Y and #calls==0)
			menu:close()
		end)
	end)
	for _,menu in ipairs(views) do menu:close();menu.shade:Destroy() end
	root:Destroy();assert(ok,problem)
	return{passed=#cases,cases=cases}
end
