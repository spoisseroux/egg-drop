-- Native LocalScript/ScreenGui. Explicit UI authority and measured geometry, no real remotes.
return function(client,parent)
	local View=require(client.EggHatchView)
	local GuiService=game:GetService("GuiService");local previousSelection=GuiService.SelectedObject
	local root=Instance.new("Frame");root.Name="_CompactEggShopSpec";root.BackgroundTransparency=1;root.Parent=parent
	local cases,views={},{ }
	local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
	local function test(name,run)run();table.insert(cases,name)end
	local function fit(n)assert(n.TextFits,n.Name.." ["..n.Text.."] box="..tostring(n.AbsoluteSize).." bounds="..tostring(n.TextBounds))end
	local function inside(n,host)local p,s,h,t=n.AbsolutePosition,n.AbsoluteSize,host.AbsolutePosition,host.AbsoluteSize;return p.X>=h.X-.1 and p.Y>=h.Y-.1 and p.X+s.X<=h.X+t.X+.1 and p.Y+s.Y<=h.Y+t.Y+.1 end
	local function resize(w,h,view)root.Size=UDim2.fromOffset(w,h);settle();if view then view:layout();settle()end end
	local function snapshot(nectar,result,revision)return{status="Ready",revision=revision or 10,nectar=nectar or 18,lastHatch=result,dailyAvailable=true,dailyDay="20000",dailyBonus=6,misses=3}end
	local function fixture()
		local sent={};local view=View.new(root,{play=function()end},function()return true end,function(command,value)table.insert(sent,{command,value})end)
		table.insert(views,view);view:open(snapshot());settle();return view,sent
	end
	local function header(view)
		fit(view.heading);fit(view.nectar);fit(view.closeButton)
		assert(view.nectar.Visible and view.wallet.Visible and view.nectar.Text==tostring(view.state.nectar or 0))
		assert(view.nectar:GetAttribute("AccessibleLabel")==view.nectar.Text.." Stars" and view.wallet.BackgroundTransparency==1)
		assert(inside(view.wallet,view.card)and inside(view.closeButton,view.card)and view.closeButton.AbsoluteSize==Vector2.new(44,44))
		assert(view.body.AbsolutePosition.Y>=view.closeButton.AbsolutePosition.Y+44+3)
	end
	local function scrollTo(view,node)
		local scroll=view.body;local y=node.AbsolutePosition.Y-scroll.AbsolutePosition.Y+scroll.CanvasPosition.Y
		scroll.CanvasPosition=Vector2.new(0,math.clamp(y,0,math.max(0,scroll.CanvasSize.Y.Offset-scroll.AbsoluteSize.Y)));settle()
		assert(inside(node,scroll),"scroll target unreachable: "..node.Name)
	end
	local ok,problem=pcall(function()
		test("160/198/236 roots retain measured choices exact wallet and pinned action",function()
			for _,h in ipairs({160,198,236})do
				resize(568,h);local view=fixture();header(view)
				assert(view.compactShop and view.card.AbsoluteSize.Y==h-16)
				for _,id in ipairs({"meadow","sprout"})do
					local row=view.body.EggColumn["Recipe_"..id]
					assert(row.AbsoluteSize.Y>=44 and row.RecipeName.TextSize>=12 and row.Cost.TextSize>=12 and not row.RecipeName.TextScaled and not row.Cost.TextScaled)
					fit(row.RecipeName);fit(row.Cost)
					assert(row.RecipeName.TextXAlignment==Enum.TextXAlignment.Left and row.Cost.Position.X==row.RecipeName.Position.X)
					assert(row.Cost.Position.Y.Offset-row.RecipeName.Position.Y.Offset-row.RecipeName.Size.Y.Offset==3)
					if row.AbsoluteSize.Y<=view.body.AbsoluteSize.Y-8 then assert(inside(row,view.body))else scrollTo(view,row.Cost)end
				end
				fit(view.action);assert(view.action.AbsoluteSize.Y>=44 and inside(view.action,view.card))
				assert(view.body.AbsoluteSize.Y>=44 and view.body.AbsolutePosition.Y+view.body.AbsoluteSize.Y<view.action.AbsolutePosition.Y)
				view:close()
			end
		end)
		test("Sprout selection retains exact24price and6shortfall without purchasing",function()
			resize(568,160);local view,sent=fixture();view.body.CanvasPosition=Vector2.new(0,100)
			assert(view:selectRecipe("sprout"));settle();local row=view.body.EggColumn.Recipe_sprout
			assert(inside(row.RecipeName,view.body),"selected name must stay visible even when full row is taller")
			assert(view.action.Text:find("egg",1,true)and view.action.Text:find("24",1,true)and view.action.Text:find("6",1,true)and row.Cost.Text:find("24",1,true))
			view:update(snapshot(24));settle();assert(view.selected=="sprout"and view.action.Text:find("24",1,true)and view.action.Interactable and #sent==0);view:close()
		end)
		test("350x279 names and costs remain native readable and reachable",function()
			resize(350,279);local view,sent=fixture();header(view)
			for _,id in ipairs({"meadow","sprout"})do local row=view.body.EggColumn["Recipe_"..id];fit(row.RecipeName);fit(row.Cost);assert(row.AbsoluteSize.Y>=44);scrollTo(view,row.Cost)end
			view:selectRecipe("sprout");view:update(snapshot(24));settle();fit(view.action);assert(inside(view.action,view.card)and view.action.Interactable and #sent==0);view:close()
		end)
		test("errors pending and terminal notices never replace authoritative wallet data",function()
			resize(568,160);local view,sent=fixture()
			for _,message in ipairs({"One moment…","Your hatch progress updated. Try again."})do
				view:setError(message);settle();header(view);assert(view.heading.Text=="Try again" and view.nectar.Text=="18")
				local detail=view.body.EggColumn:FindFirstChild("ActionInstruction");assert(detail and detail.Text==message);fit(detail)
			end
			view:send("hatch","meadow");settle();assert(view.errorMessage==nil and view.heading.Text=="Saving…"and view.nectar.Text=="18"and #sent==1)
			view:update(snapshot(0,nil,11));settle();assert(view.heading.Text=="Companion eggs"and view.nectar.Text=="0")
			local unavailable=snapshot(0,nil,12);unavailable.status="SessionLost";view:update(unavailable);settle()
			assert(not view.action.Interactable and view.nectar.Text=="0" and view.body.EggColumn.SaveInstruction.Text:find("Rejoin",1,true))
			view:update(snapshot(0,nil,13));view:setError("One moment…");resize(390,740,view)
			assert(view.note.Visible and view.note.Text=="One moment…"and view.heading.Text=="Try again")
			view:update(snapshot(24,{id="error-result-fixture",petId="pip",family="pip"},14));settle()
			assert(not view.heading.Visible and not view.nectar.Visible and not view.note.Visible and view.meetButton.Visible);view:close()
		end)
		test("daily gift all odds and rare protection stay reachable",function()
			resize(568,160);local view=fixture();local daily,odds=view.body.EggColumn.DailyNectar,view.body.OutcomeColumn
			assert(daily.AbsoluteSize.Y>=44 and daily.Interactable);fit(daily);scrollTo(view,daily)
			local count=0;for _,row in ipairs(odds:GetChildren())do if row.Name:match("^Outcome_")then count+=1;scrollTo(view,row);fit(row:FindFirstChild("Name"));fit(row.Probability)end end
			assert(count==7);scrollTo(view,odds.RareProtection);fit(odds.RareProtection);assert(odds.RareProtection.Text:find("3 / 7",1,true))
			scrollTo(view,odds.Duplicates);fit(odds.Duplicates);view:close()
		end)
		test("rotation preserves selection while unchanged snapshots preserve reading scroll",function()
			resize(568,160);local view=fixture();view:selectRecipe("sprout");resize(390,740,view)
			assert(view.selected=="sprout");header(view);assert(view.card.AbsoluteSize.Y==580)
			view.body.CanvasPosition=Vector2.new(0,100);settle();local before=view.body.CanvasPosition.Y;view:update(snapshot(18));settle();assert(view.body.CanvasPosition.Y==before)
			resize(733,307,view);local row=view.body.EggColumn.Recipe_sprout
			assert(view.selected=="sprout"and inside(row,view.body)and view.action.Text:find("24",1,true));resize(568,160,view)
			assert(inside(view.body.EggColumn.Recipe_sprout.RecipeName,view.body));view:close()
		end)
		test("compact shop result transition preserves ID and both safe actions",function()
			resize(568,160);local view,sent=fixture();view:update(snapshot(24,{id="compact-result-fixture",petId="foxfire_wick",family="wick",rare=true}));settle()
			assert(not view.compactShop and view.meetButton.Visible,"result transition lost its reveal/footer")
            local directW=math.max(1,view.card.AbsoluteSize.X-20)
            local normalH=math.max(1,view.card.AbsoluteSize.Y-80)
            local expectedScroll=view.cinematic:minimumHeightForWidth(directW,normalH)>normalH
            assert(view.body.Visible==expectedScroll and view.revealHost.Parent==(if expectedScroll then view.body else view.card),
                string.format("measured result owner mismatch direct=%dx%d minimum=%d scroll=%s parent=%s",directW,normalH,view.cinematic:minimumHeightForWidth(directW,normalH),tostring(view.body.Visible),view.revealHost.Parent.Name))
			for _,n in ipairs({view.meetButton,view.action,view.closeButton})do fit(n);assert(n.AbsoluteSize.Y>=44 and inside(n,view.card))end
			assert(view.meetButton.Interactable and view.action.Interactable,
                "result actions not ready: "..game:GetService("HttpService"):JSONEncode({ackReady=view.ackReady,pending=view.pending,status=view.state.status,cinematic=view.cinematic:getStats()}))
            assert(view.state.lastHatch.id=="compact-result-fixture"and #sent==0,"result identity changed or fixture sent an acknowledgment")
			assert(view.closeButton.AbsolutePosition.Y+44<=view.meetButton.AbsolutePosition.Y);view:close()
		end)
		test("reopening keeps selected recipe and explicit pinned price without sends",function()
			resize(568,160);local view,sent=fixture();view:selectRecipe("sprout");view:update(snapshot(24));view:close();view:open(snapshot(24));settle()
			assert(view.selected=="sprout"and view.action.Text:find("24",1,true)and view.action.Interactable and #sent==0);fit(view.action);assert(inside(view.action,view.card));view:close()
		end)
	end)
	game:GetService("GuiService").SelectedObject=nil
	for _,view in ipairs(views)do view:close();view.shade:Destroy()end;root:Destroy();if require(client.ControllerFocus).live(previousSelection,nil,game.Players.LocalPlayer.PlayerGui,true)then GuiService.SelectedObject=previousSelection end;assert(ok,problem)
	return{passed=#cases,cases=cases}
end
