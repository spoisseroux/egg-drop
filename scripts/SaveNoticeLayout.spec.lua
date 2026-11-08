-- Real LocalScript + ScreenGui host at Medium/Largest. Counters replace every outgoing action.
-- Optional rootSize Vector2 runs a bounded part:733x307=2,568x160=2,385x703=2,1649x971=3 cases.
-- Omitting it retains the full9-case matrix; minimum frame waits alone take about28s at60fps.
return function(client,parent,rootSize)
	assert(parent:IsA("ScreenGui"),"ScreenGui host required")
	local Notice=require(client.SaveNotice);local Menu=require(client.DeckMenu);local Picker=require(client.DeckPicker)
	local Journal=require(client.PetJournal);local Shop=require(client.EggHatchView);local Recap=require(client.RoundRecap);local Focus=require(client.PetFocusUI)
	local Catalog=require(game.ReplicatedStorage.Shared.EggCatalog);local GuiService=game:GetService("GuiService")
	local previousSelection=GuiService.SelectedObject
	local root=Instance.new("Frame");root.Name="_SaveNoticeLayout";root.BackgroundTransparency=1;root.Parent=parent
	local views,focusViews,cases={}, {},{}
	local statuses={"Temporary","Unavailable","Locked","Retrying","SessionLost","InvalidData"}
	local callbacks,sounds=0,0
	local audio={play=function()sounds+=1 end}
	local function outgoing()callbacks+=1 end
	local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
	local function progress(value)
		parent:SetAttribute("SaveNoticeFixtureProgress",value)
		parent:SetAttribute("SaveNoticeFixtureCases",#cases)
	end
	local function test(name,run)
		progress("Running "..name);run();table.insert(cases,name);progress("Passed "..name)
	end
	local function readable(node)
		assert(node.TextFits,string.format("%s text=%q box=%s bounds=%s",node:GetFullName(),node.Text,tostring(node.AbsoluteSize),tostring(node.TextBounds)))
		assert(not node.TextScaled and not node.Active and not node.Selectable,"notice must be passive preferred text: "..node.Name)
	end
	local function inside(node,host)
		local p,s,hp,hs=node.AbsolutePosition,node.AbsoluteSize,host.AbsolutePosition,host.AbsoluteSize
		return p.X>=hp.X-.1 and p.Y>=hp.Y-.1 and p.X+s.X<=hp.X+hs.X+.1 and p.Y+s.Y<=hp.Y+hs.Y+.1
	end
	local function overlaps(a,b)
		local ap,az,bp,bz=a.AbsolutePosition,a.AbsoluteSize,b.AbsolutePosition,b.AbsoluteSize
		return ap.X<bp.X+bz.X-.1 and bp.X<ap.X+az.X-.1 and ap.Y<bp.Y+bz.Y-.1 and bp.Y<ap.Y+az.Y-.1
	end
	local function visibleRect(node)
		local p,s=node.AbsolutePosition,node.AbsoluteSize
		local x,y,r,b=p.X,p.Y,p.X+s.X,p.Y+s.Y;local ancestor=node
		while ancestor do
			if ancestor:IsA("GuiObject")then
				if not ancestor.Visible then return nil end
				if ancestor.ClipsDescendants then
					local p,s=ancestor.AbsolutePosition,ancestor.AbsoluteSize
					x,y,r,b=math.max(x,p.X),math.max(y,p.Y),math.min(r,p.X+s.X),math.min(b,p.Y+s.Y)
				end
			elseif ancestor:IsA("ScreenGui")and not ancestor.Enabled then return nil end
			ancestor=ancestor.Parent
		end
		return if r>x and b>y then {x=x,y=y,r=r,b=b}else nil
	end
	local function visibleOverlap(a,b)
		local a,b=visibleRect(a),visibleRect(b)
		return a and b and a.x<b.r-.1 and b.x<a.r-.1 and a.y<b.b-.1 and b.y<a.b-.1
	end
	local function reach(node,scroll)
		local top=node.AbsolutePosition.Y-scroll.AbsolutePosition.Y+scroll.CanvasPosition.Y
		local maximum=math.max(0,scroll.CanvasSize.Y.Offset-scroll.AbsoluteSize.Y)
		for _,target in ipairs({top,top+node.AbsoluteSize.Y-scroll.AbsoluteSize.Y})do
			scroll.CanvasPosition=Vector2.new(0,math.clamp(target,0,maximum));settle()
			assert(node.AbsolutePosition.Y<scroll.AbsolutePosition.Y+scroll.AbsoluteSize.Y and node.AbsolutePosition.Y+node.AbsoluteSize.Y>scroll.AbsolutePosition.Y,"instruction not reachable")
		end
	end
	local function state(result)
		return{status="Ready",revision=20,nectar=24,inventoryMask=127,lastHatch=result,dailyAvailable=false,mastery={pip=3,wick=10}}
	end
	local function cycle(view,validate)
		local before=callbacks
		for _,status in ipairs(statuses)do
			progress(tostring(root.AbsoluteSize).." "..view.shade.Name.." "..status)
			local notice=Notice.resolve(status,{status="Ready"})
			view:setSaveNotice(notice);settle();validate(view,notice)
			local layout=view.layout;local passes=0
			if layout then view.layout=function(self,...)passes+=1;return layout(self,...)end end
			for _=1,5 do assert(not view:setSaveNotice(Notice.resolve(status,{status="Ready"})))end
			if layout then view.layout=layout;assert(passes==0,"unchanged notice reflowed")end
			assert(callbacks==before,"notice submitted an action")
		end
		view:setSaveNotice(nil);settle();assert(callbacks==before)
	end
	local ok,problem=pcall(function()
		local sizes=if rootSize then {rootSize}else {Vector2.new(733,307),Vector2.new(568,160),Vector2.new(385,703),Vector2.new(1649,971)}
		for _,size in ipairs(sizes)do
			root.Size=UDim2.fromOffset(size.X,size.Y);settle()
			test(tostring(size).." passive status belongs to each modal without covering pinned actions",function()
				local menu=Menu.new(root,{});table.insert(views,menu);menu:update(state(),"pip","wick",0,0,0,"sprout");menu:open();settle()
				cycle(menu,function(v,n)
					assert(v.heading.Text==n.short or v.heading.Text==n.narrow);assert(v.nectar.Text=="24" and v.nectar:GetAttribute("AccessibleLabel")=="24 nectar");readable(v.nectar);readable(v.heading);assert(inside(v.heading,v.card) and not overlaps(v.heading,v.closeButton))
					assert(v.playHint.Text:find(n.detail,1,true));readable(v.playHint);reach(v.playHint,v.body)
				end)
				assert((menu.heading.Text=="Pocket menu" or menu.heading.Text=="Menu") and not menu.playHint.Text:find("retry",1,true));menu:close()
				local picker=Picker.new(root,nil,nil,outgoing,outgoing,outgoing,outgoing);table.insert(views,picker)
				picker:updateClub(1,0,0,0,"On",false,false,1);picker:open("brick","star");settle()
				cycle(picker,function(v,n)
					assert(v.themeId=="brick" and v.stickerId=="star" and inside(v.cancel,v.card) and not v.card:FindFirstChild("Apply"))
					assert(v.scroll.AbsoluteSize.Y>=44 and inside(v.scroll,v.card));readable(v.saveDetail);reach(v.saveDetail,v.scroll)
					if v.saveMarker.Visible then readable(v.saveMarker);assert(inside(v.saveMarker,v.card) and not overlaps(v.saveMarker,v.scroll))
					else readable(v.heading);assert(v.heading.Text==n.short and not overlaps(v.heading,v.cancel))end
				end)
				assert(not picker.saveMarker.Visible and not picker.saveDetail.Visible);picker:close()
				local journal=Journal.new(root,nil,nil,outgoing,outgoing,outgoing);table.insert(views,journal)
				journal:open(0,0,"foxfire_wick",false,nil,Catalog.bit("foxfire_wick"),{wick=3});settle()
				cycle(journal,function(v,n)
					assert(v.title.Text==n.short);readable(v.title);readable(v.saveDetail);reach(v.saveDetail,v.scroll)
					assert(not overlaps(v.title,v.closeButton) and inside(v.closeButton,v.card) and inside(v.goalsButton,v.card) and not overlaps(v.scroll,v.goalsButton))
					assert(v.cards[6].Interactable and not v.cards[1].Interactable and v.cards[6].FamilyRank.Text=="Wick · III")
				end)
				assert(journal.title.Text:find("01/07",1,true) and not journal.saveDetail.Visible);journal:close()
				local recap=Recap.new(root,audio,true);table.insert(views,{shade=recap.frame,close=function()end})
				recap.frame.Visible=true;recap:update(600,3,0,nil,0,nil,0,700)
				recap:updateField({sequence=1,status="Saved",success=true,stage=2,award=14,daily=6,balance=24,recipe=Catalog.ById.sprout,
					reward={sequence=1,total=14,base=8,daily=6,family="pip",masteryPoints=1,contracts={}}});settle()
				local starts,signature,oldSounds=recap.feedback.starts,recap.receiptSignature,sounds
				for _,status in ipairs(statuses)do
					recap:setSaveNotice(Notice.resolve(nil,status),"Both sides complete");settle();readable(recap.saveDetail);reach(recap.saveDetail,recap.fieldBody)
					assert(recap.earnedGraphic.Text=="+14 nectar" and recap.bankGraphic.Text=="Nectar saved: 24" and recap.receiptSignature==signature)
					assert(recap.feedback.starts==starts and sounds==oldSounds)
				end
				recap:setSaveNotice(nil,nil);assert(not recap.saveDetail.Visible);recap.frame.Visible=false
				local focus=Focus.new(parent,{back=outgoing,greet=outgoing,pet=outgoing,canReact=function()return true end,canOwnInput=function()return true end})
				focus.gui.Name="_SaveNoticeLayoutFocus";focus.gui:SetAttribute("FixtureRootSize",tostring(size))
				table.insert(focusViews,focus);focus.root.Size=UDim2.fromOffset(size.X,size.Y);settle()
				for _,active in ipairs({false,true})do
					focus:setActive(active)
					for _,status in ipairs(statuses)do
						focus:setSaveNotice(Notice.resolve(nil,status));focus:update(nil,nil,true);settle()
						local label=if active then focus.helper else focus.hint;readable(label)
						assert(inside(label,focus.root) and not overlaps(label,focus.back))
					end
				end
				focus:setSaveNotice(nil);focus:setActive(false);focus:destroy()
			end)
			test(tostring(size).." same-ID reveal and ordinary shop retain authority across status recovery",function()
				local shop=Shop.new(root,audio,function()return true end,outgoing);table.insert(views,shop)
				shop:open(state());shop:selectRecipe("sprout");settle()
				local before=callbacks
				cycle(shop,function(v,n)
					readable(v.heading);assert((v.heading.Text==n.short or v.heading.Text==n.narrow) and not overlaps(v.heading,v.closeButton));assert(v.nectar.Visible and v.nectar.Text=="24" and v.nectar:GetAttribute("AccessibleLabel")=="24 nectar");readable(v.nectar)
					assert(v.selected=="sprout" and v.state.nectar==24 and v.action.Interactable and v.action.Text:find("24",1,true))
					assert(inside(v.closeButton,v.card) and inside(v.action,v.card) and not overlaps(v.body,v.action) and v.body.AbsoluteSize.Y>=44)
					if v.notePinned then readable(v.note);assert(v.note.Visible and v.note.Text==n.detail)else local label=v.body.EggColumn.SaveInstruction;assert(label and label.Text==n.detail);readable(label);reach(label,v.body)end
				end)
				assert((shop.heading.Text=="Hatch eggs" or shop.heading.Text=="Eggs") and shop.nectar.Text=="24" and callbacks==before)
				local result={id="save-notice-result-"..size.Y,petId="foxfire_wick",family="wick",rare=true}
				shop:update(state(result));settle()
				local epoch,viewport,ready=shop.cinematic.epoch,shop.cinematic.heroViewport,shop.ackReady
				local pixelSize=shop.revealHost.AbsoluteSize;local soundCount=sounds
				assert(viewport and viewport.Parent and ready)
				cycle(shop,function(v,n)
					readable(v.heading);readable(v.note)
					assert(v.revealHost.Parent==v.body and v.note.Parent==v.body and v.heading.Text==n.short)
					assert(v.revealHost.AbsoluteSize==pixelSize and v.cinematic.epoch==epoch and v.cinematic.heroViewport==viewport and viewport.Parent,"status reflow replaced cinematic")
					assert(v.playingId==result.id and v.state.lastHatch.id==result.id and v.ackReady==ready and v.selected=="sprout" and v.state.nectar==24)
					assert(v.meetButton.Interactable and v.action.Interactable and inside(v.closeButton,v.card) and inside(v.action,v.card) and inside(v.meetButton,v.card))
					assert(not overlaps(v.heading,v.closeButton) and not overlaps(v.body,v.action) and not overlaps(v.body,v.meetButton))
					local name=v.cinematic.frame:FindFirstChild("PetName",true);assert(name)
					assert(not visibleOverlap(name,v.heading) and not visibleOverlap(name,v.closeButton) and not visibleOverlap(name,v.action) and not visibleOverlap(name,v.meetButton),"visible pet name covered by notice/control")
					reach(v.note,v.body)
					assert(callbacks==before and sounds==soundCount)
				end)
				local normalH=math.max(1,shop.card.Size.Y.Offset-80)
				local minimum=shop.cinematic:minimumHeightForWidth(math.max(1,shop.card.Size.X.Offset-20),normalH)
				local shortStage=minimum>normalH
				local expectedParent=if shortStage then shop.body else shop.card
				local diagnostic=string.format("root=%s parent=%s expected=%s normalH=%g minimum=%g stage=%s body=%s canvas=%s epoch=%s/%s",
					tostring(size),shop.revealHost.Parent:GetFullName(),expectedParent:GetFullName(),normalH,minimum,tostring(shop.revealHost.AbsoluteSize),
					tostring(shop.body.AbsoluteSize),tostring(shop.body.CanvasPosition),tostring(shop.cinematic.epoch),tostring(epoch))
				assert(shop.revealHost.Parent==expectedParent,diagnostic)
				assert(shop.body.Visible==shortStage and shop.revealHost.AbsoluteSize==pixelSize,diagnostic)
				assert(shop.cinematic.epoch==epoch and shop.cinematic.heroViewport==viewport and viewport.Parent,diagnostic)
				assert(shop.playingId==result.id and shop.state.lastHatch.id==result.id and shop.ackReady==ready and shop.selected=="sprout" and shop.state.nectar==24)
				assert(shop.meetButton.Interactable and shop.action.Interactable and callbacks==before and sounds==soundCount)
				for _,control in ipairs({shop.closeButton,shop.meetButton,shop.action})do
					assert(control.AbsoluteSize.Y>=44 and inside(control,shop.card) and control.TextFits,diagnostic)
				end
				if shortStage then
					assert(shop.body.AbsoluteSize.Y>=44 and not overlaps(shop.body,shop.closeButton) and not overlaps(shop.body,shop.action) and not overlaps(shop.body,shop.meetButton),diagnostic)
				end
				for _,name in ipairs({"PetName","Mastery"})do
					local label=shop.cinematic.frame:FindFirstChild(name,true);assert(label and label.Visible,diagnostic);readable(label)
					if shortStage then reach(label,shop.body)end
				end
				shop:close();shop:open(state(result));settle()
				assert(shop.state.lastHatch.id==result.id and callbacks==before and shop.selected=="sprout");shop:close()
			end)
		end
		if not rootSize or rootSize==Vector2.new(1649,971)then
		test("persistent retry wins over stale command feedback and newer Ready clears that feedback",function()
			local shop=Shop.new(root,audio,function()return true end,outgoing);table.insert(views,shop);shop:open(state());settle()
			shop:setError("RevisionChanged");shop:setSaveNotice(Notice.resolve(nil,"Unavailable"));settle()
			assert((shop.heading.Text=="Retrying load" or shop.heading.Text=="Load retry") and shop.errorMessage=="RevisionChanged" and shop.nectar.Text=="24")
			local nextState=state();nextState.revision=21;shop:update(nextState);shop:setSaveNotice(nil);settle()
			assert(shop.errorMessage==nil and (shop.heading.Text=="Hatch eggs" or shop.heading.Text=="Eggs") and not shop.note.Text:find("unavailable",1,true));shop:close()
		end)
		end
	end)
	GuiService.SelectedObject=nil
	for _,view in ipairs(focusViews)do view:destroy()end
	for _,view in ipairs(views)do view:close();view.shade:Destroy()end;root:Destroy()
	if previousSelection and previousSelection.Parent and previousSelection:IsDescendantOf(game.Players.LocalPlayer.PlayerGui) and previousSelection.Visible and previousSelection.Selectable then
		local valid=true;local ancestor=previousSelection
		while ancestor do if ancestor:IsA("GuiObject")and not ancestor.Visible or ancestor:IsA("ScreenGui")and not ancestor.Enabled then valid=false;break end;ancestor=ancestor.Parent end
		if valid then GuiService.SelectedObject=previousSelection end
	end
	progress(if ok then "Complete"else "Failed: "..tostring(problem))
	assert(ok,problem);return{passed=#cases,cases=cases,preference=GuiService.PreferredTextSize.Name,rootSize=if rootSize then tostring(rootSize)else "full matrix"}
end
