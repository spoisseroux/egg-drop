-- Studio Client presentation fixtures. No remotes or progression writes.
return function(client, parent)
	local Recap = require(client.RoundRecap)
	local Feedback=require(client.RecapFeedback)
	local Catalog = require(game:GetService("ReplicatedStorage").Shared.EggCatalog)
	local root = Instance.new("Frame")
	root.Name, root.Size, root.BackgroundTransparency, root.Parent = "_RecapFeedbackSpec", UDim2.fromOffset(360, 236), 1, parent
	local reduced, sounds = false, {}
	local audio = { group = { Volume = 1 } }
	function audio:play(name, speed, volume)
		if self.group.Volume ~= 0 then table.insert(sounds, { name, speed, volume }) end
	end
	local recap = Recap.new(root, audio, function() return reduced end)
	recap.frame.Visible = true
	local cases = {}
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
	local function result(sequence, changes)
		local value = { sequence = sequence, status = "Saved", success = true, stage = 2, reason = "Completed",
			award = 14, daily = 6, balance = 20, recipe = Catalog.ById.meadow,
			reward = { sequence = sequence, total = 14, base = 8, daily = 6, family = "pip", masteryPoints = 2, contracts = { "chain", "score" } } }
		for key, item in pairs(changes or {}) do value[key] = item end
		return value
	end
	local function show(value)
		recap:update(630, 4, 2, nil, 0, nil, 0, 700)
		recap:updateField(value)
		-- Advance deterministically without waiting for native rendering frames.
		if recap.feedback.connection then recap.feedback.connection:Disconnect(); recap.feedback.connection = nil end
	end
	local function advance(feedback,duration)
		local remaining=duration
		while remaining>.000001 do local dt=math.min(.01,remaining);feedback:step(dt);remaining-=dt end
	end
	local function clockFixture()
		local owner,reduced,last=true,false,nil
		local audio={group={Volume=1},deviceActive=true,deviceEpoch=0,cues={},stops=0}
		function audio:play(name,pitch,volume,token)
			if self.group.Volume>0 and self.deviceActive then table.insert(self.cues,{name=name,pitch=pitch,volume=volume,owner=token})end
		end
		function audio:stopOwner()self.stops+=1 end
		local f=Feedback.new(function(sample)last=sample end,audio,function()return reduced end,function()return owner end)
		local function observe(value,visible)
			local started=f:observe(value,visible)
			if f.connection then f.connection:Disconnect();f.connection=nil end
			return started
		end
		return f,audio,observe,function()return last end,function(value)owner=value end,function(value)reduced=value end
	end
	local ok, problem = pcall(function()
		test("feedback has a separate exact-value lane and bounded 1100ms four-stage sample",function()
			assert(Feedback.Duration==1.1)
			for _,age in ipairs({0,.09,.18,.28,.45,.66,.88,1.1})do
				local sample=Feedback.sample(age);assert(sample.earned==1 and sample.age==age)
				for _,key in ipairs({"pop","sources","transfer","settle"})do assert(sample[key]>=0 and sample[key]<=1.000001)end
			end
			assert(math.abs(Feedback.sample(.09).pop-1)<.000001 and Feedback.sample(.18).pop==0)
			assert(Feedback.sample(.17).sources==0 and Feedback.sample(.28).sources>.99 and Feedback.sample(.45).sources<.000001)
			assert(Feedback.sample(.45).transfer==0 and math.abs(Feedback.sample(.88).transfer-1)<.000001 and Feedback.sample(1.1).settle==1)
		end)
		test("committed timeline uses two source notes five rising drops and one quiet cadence",function()
			local f,a,observe,last=clockFixture();local packet=result(800)
			table.freeze(packet.reward);table.freeze(packet)
			assert(observe(packet,true)and last().earned==1 and #a.cues==0 and f.chips==5)
			advance(f,.17);assert(#a.cues==0)
			advance(f,.17);assert(#a.cues==2 and a.cues[1].name=="bank"and a.cues[2].pitch>a.cues[1].pitch)
			advance(f,.55);assert(#a.cues==8)
			local pitch=0;for i=3,7 do local cue=a.cues[i];assert(cue.name=="charge"and cue.pitch>pitch and cue.volume<=.18 and cue.owner==f);pitch=cue.pitch end
			assert(a.cues[8].name=="bank"and a.cues[8].volume<=.14)
			advance(f,.3);assert(not f.active and last()==nil and packet.reward.total==14 and packet.balance==20)
			assert(not observe(packet,true)and #a.cues==8)
		end)
		test("owner loss or skipped resume lands final and cannot emit delayed cues",function()
			for _,mode in ipairs({"covered","skipped","deviceEpoch"})do
				local f,a,observe,last,owner=clockFixture();local packet=result(801)
				assert(observe(packet,true));advance(f,.1)
				if mode=="covered"then owner(false);f:step(.01)
				elseif mode=="skipped"then f:step(.3)
				else a.deviceEpoch=2;f:step(.01)end
				assert(not f.active and last()==nil and #a.cues==0)
				owner(true);f:step(.01);assert(not observe(packet,true)and #a.cues==0)
			end
		end)
		test("matching late receipt starts once while pending stale and repeated Saved packets cannot replay",function()
			local f,a,observe=clockFixture();local pending=result(804,{receiptPending=true})
			assert(not observe(pending,true)and #a.cues==0)
			local stale=result(804);stale.reward.sequence=803
			assert(not observe(stale,true)and #a.cues==0)
			local saved=result(804);assert(observe(saved,true));advance(f,.2);local count=#a.cues
			assert(not observe(pending,true)and not f.active)
			assert(not observe(saved,true)and #a.cues==count and f.starts==1)
		end)
		test("cancel inside first render cannot install an inactive clock or emit a zero cue after close",function()
			local f;local cues=0;local audio={play=function()cues+=1 end}
			f=Feedback.new(function(sample)if sample then f:cancel()end end,audio,false)
			assert(not f:observe(result(805),true)and not f.active and f.connection==nil and cues==0)
			local zero=result(806);zero.reward.total=0
			local closing=false
			f=Feedback.new(function()if closing then closing=false;f:cancel()end end,audio,false)
			-- Initial key publication can render too; close only the zero final paint.
			f.key=806;closing=true
			assert(not f:observe(zero,true)and f.connection==nil and cues==0)
			f=Feedback.new(function(sample)if sample and f.key==807 then f:observe(result(808),true)end end,audio,false)
			assert(not f:observe(result(807),true)and f.key==808 and f.active and f.connection~=nil)
			f:cancel();assert(f.connection==nil)
		end)
		test("zero is one quiet accent only while hidden reduced muted and background receipts stay quiet",function()
			local zero=result(802);zero.reward.total=0
			local f,a,observe,last=clockFixture();assert(not observe(zero,false)and #a.cues==0)
			assert(not observe(zero,true)and #a.cues==1 and not f.active and last()==nil)
			assert(not observe(zero,true)and #a.cues==1)
			for _,mode in ipairs({"reduced","muted","background"})do
				local g,b,show,_,_,reduce=clockFixture()
				if mode=="reduced"then reduce(true)elseif mode=="muted"then b.group.Volume=0 else b.deviceActive=false end
				show(result(803),true);advance(g,1.2);assert(#b.cues==0)
				reduce(false);b.group.Volume=1;b.deviceActive=true;assert(not show(result(803),true)and #b.cues==0)
			end
		end)
		test("owned pooled voices stop on cancel without stopping a newer ordinary or owned cue",function()
			local Audio=require(client.BoardAudio)
			local voice={IsLoaded=true,plays=0,stops=0};function voice:Play()self.plays+=1 end;function voice:Stop()self.stops+=1 end
			local audio=setmetatable({group={Volume=1},deviceActive=true,indices={},voices={bank={voice}}},Audio)
			local first,second={},{}
			assert(audio:play("bank",1,.1,first));assert(audio:play("bank",1,.1));assert(audio:stopOwner(first)==0 and voice.stops==0)
			assert(audio:play("bank",1,.1,first)and audio:play("bank",1,.1,second))
			assert(audio:stopOwner(first)==0 and audio:stopOwner(second)==1 and voice.stops==1)
			voice.IsLoaded=false;assert(not audio:play("bank",1,.1,first)and next(audio.voiceOwners)==nil)
			voice.IsLoaded=true;assert(audio:play("bank",1,.1,first))
			for _,name in ipairs({"cancelBoot","stopField","silencePurr","refreshLoops"})do audio[name]=function()end end
			audio:setDeviceActive(false);assert(audio.deviceEpoch==1 and audio.voiceOwners==nil and voice.stops==2)
			audio:setDeviceActive(true);audio:setDeviceActive(true);assert(audio.deviceEpoch==2)
		end)
		test("matching committed receipt starts once and retains count through HUD refresh", function()
			local value = result(1)
			show(value)
			assert(recap.feedback.active and recap.feedback.starts == 1 and recap.values[1].Text == "0"and recap.earnedGraphic.Text=="+14 Stars")
			recap.feedback:step(.2)
			local count = recap.values[1].Text
			show(value)
			assert(recap.feedback.starts == 1 and recap.values[1].Text == count)
			assert(recap.bankGraphic.Text == "Stars saved: 20" and value.balance == 20 and value.reward.total == 14)
		end)
		test("count up lands on exact score chain clears and earned Stars", function()
			advance(recap.feedback,.5)
			assert(recap.values[1].Text == "630" and recap.values[2].Text == "×4" and recap.values[3].Text == "2")
			assert(recap.transfer.Visible==recap.transferAnchorsVisible and recap.bankGraphic.Text == "Stars saved: 20"and recap.earnedGraphic.Text=="+14 Stars")
			recap.feedback:step(.8)
			assert(not recap.feedback.active and not recap.transfer.Visible)
			assert(recap.earnedGraphic.Text == "+14 Stars" and recap.scales[1].Scale == 1)
			assert(#sounds > 0 and recap.feedback.connection == nil)
		end)
		test("hide cancels immediately and reopening the same receipt cannot replay", function()
			show(result(2)); recap.feedback:step(.1)
			recap.frame.Visible = false
			assert(not recap.feedback.active and recap.values[1].Text == "630" and recap.feedback.connection == nil)
			local count, starts = #sounds, recap.feedback.starts
			recap.frame.Visible = true; show(result(2))
			assert(not recap.feedback.active and #sounds == count and recap.feedback.starts == starts)
		end)
		test("hidden ancestor cancels and does not consume a future receipt", function()
			root.Visible = false; show(result(3))
			assert(not recap.feedback.active)
			root.Visible = true; show(result(3)); assert(recap.feedback.active)
			root.Visible = false; assert(not recap.feedback.active and not recap.transfer.Visible)
			root.Visible = true
		end)
		test("Saving delayed and pending states suppress old receipt and currency transfer", function()
			for index, change in ipairs({ { status = "Saving" }, { status = "Save delayed" }, { receiptPending = true } }) do
				show(result(10 + index, change))
				assert(not recap.feedback.active and not recap.hasReceipt and not recap.transfer.Visible)
				assert(not recap.earnedGraphic.Visible and not recap.bankGraphic.Visible and not recap.fill.Parent.Visible)
				assert(recap.receiptLines == nil and not recap.title.Text:find("20/18", 1, true))
			end
		end)
		test("stale sequence cannot announce the previous reward", function()
			local value = result(20); value.reward.sequence = 19
			show(value)
			assert(not recap.hasReceipt and not recap.feedback.active and recap.title.Text == "Loading receipt…")
			value.reward.sequence = 20; show(value); assert(recap.feedback.active)
		end)
		test("new receipt cancels the old animation and reinitializes every counter", function()
			recap.feedback:step(.4); show(result(21))
			assert(recap.feedback.active and recap.feedback.age == 0 and recap.values[1].Text == "0")
			recap.feedback:step(2); assert(recap.values[1].Text == "630")
		end)
		test("daily only failure retains missed side quest zero and exact total", function()
			local value = result(22, { success = false, stage = 1, award = 6, daily = 6, balance = 12 })
			value.reward.total, value.reward.base, value.reward.masteryPoints = 6, 0, 0
			show(value); recap.feedback:step(2)
			assert(recap.fieldHeading == "1 of 2 goals" and recap.earnedGraphic.Text == "+6 Stars")
			assert(recap.receiptLines[1] == "Quest Stars +0" and recap.bankGraphic.Text == "Stars saved: 12")
		end)
		test("zero earned never invents Stars drops or transfer sounds", function()
			local value = result(23, { success = false, stage = 0, award = 0, daily = 0, balance = 6 })
			value.reward.total, value.reward.base, value.reward.daily, value.reward.masteryPoints = 0, 0, 0, 0
			value.reward.contracts = {}
			show(value); recap.feedback:step(.85)
			local count = #sounds
			assert(recap.earnedGraphic.Text == "+0 Stars" and not recap.transfer.Visible)
			recap.feedback:step(.6)
			assert(#sounds == count and recap.fieldHeading == "0 of 2 goals")
		end)
		test("reduced effects shows final static values with no recap cues", function()
			reduced = true
			local count = #sounds
			show(result(24))
			assert(not recap.feedback.active and recap.earnedGraphic.Text == "+14 Stars" and #sounds == count)
			reduced = false; show(result(25)); reduced = true; recap.feedback:step(.01)
			assert(not recap.feedback.active and recap.values[1].Text == "630")
			reduced = false
		end)
		test("audio remains routed through the muted shared audio group", function()
			audio.group.Volume = 0
			local count = #sounds
			show(result(26)); recap.feedback:step(2)
			assert(#sounds == count and recap.earnedGraphic.Text == "+14 Stars")
		end)
		test("short recap scrolls readable center while excluding pinned footer",function()
			reduced=true
			for _,height in ipairs({128,166,198,236}) do
				root.Size=UDim2.fromOffset(360,height);task.wait(.06);show(result(30+height));task.wait(.06)
				assert(recap.fieldBody.Position.Y.Offset+recap.fieldBody.Size.Y.Offset<=height-60)
				assert(recap.earnedGraphic.TextFits and recap.bankGraphic.TextFits and recap.eggGoal.TextFits,fitDiagnostic(recap.earnedGraphic,recap.bankGraphic,recap.eggGoal))
				assert(not recap.earnedGraphic.TextScaled and recap.earnedGraphic.TextSize>=20)
				assert(recap.detailsButton.Visible and not recap.detailsContent.Visible and not recap.receiptScroll.Visible)
				recap:setDetails(true)
				game:GetService("RunService").RenderStepped:Wait();game:GetService("RunService").RenderStepped:Wait()
				for _,row in ipairs(recap.receiptRows) do assert(row.TextFits and row.TextSize>=14 and not row.TextScaled,fitDiagnostic(row)) end
			end
		end)
		test("roomy recap follows reward egg metrics details and keeps saved values",function()
			root.Size=UDim2.fromOffset(600,500);task.wait(.06);show(result(450));task.wait(.06)
			assert(recap.detailsButton.Visible and recap.detailsButton.AbsoluteSize.Y>=44 and recap.detailsButton.TextFits,fitDiagnostic(recap.detailsButton))
			assert(not recap.detailsContent.Visible and not recap.receiptScroll.Visible and not recap.stats.Visible)
			local summary=recap.summaryLayout
			assert(recap.twoColumn and summary.twoColumn and summary.egg.x>=summary.earned.x+summary.earned.w+11.9 and summary.egg.y==summary.earned.y)
			assert(recap.values[1].Text=="630" and recap.receiptSignature:find("Personal best 700",1,true)and recap.receiptSignature:find("Longest chain ×4",1,true))
			assert(recap.componentLabels[1].Text=="Quest +8" and recap.componentLabels[2].Text=="Daily +6")
			assert(recap:scrollReceipt(1) and recap.detailsOpen and recap.detailsContent.Visible and not recap.receiptScroll.Visible)
			local signature=recap.receiptSignature;show(result(450));assert(recap.detailsOpen and recap.receiptSignature==signature)
			recap:setDetails(false);assert(not recap.detailsContent.Visible and not recap.receiptScroll.Visible)
			show(result(451));assert(not recap.detailsOpen and recap.shortfall.Text=="Ready to hatch")
		end)
		test("transfer uses visible measured anchors and hides every drop when Details scrolls them away",function()
			reduced=false;root.Size=UDim2.fromOffset(600,500);task.wait(.06);show(result(452));task.wait(.06)
			recap.fieldBody.CanvasPosition=Vector2.zero
			game:GetService("RunService").RenderStepped:Wait();game:GetService("RunService").RenderStepped:Wait()
			advance(recap.feedback,.62)
			assert(recap.transferAnchorsVisible and recap.transfer.Visible,"roomy visible summary did not own measured transfer")
			assert(#recap.chips==5 and recap.earnedGraphic.Text=="+14 Stars"and recap.bankGraphic.Text=="Stars saved: 20")
			local savedHeader,savedFooter,savedWidth=recap.headerInset,recap.footerInset,recap.layoutWidth
			root.Size=UDim2.fromOffset(600,220);recap.headerInset,recap.footerInset,recap.layoutWidth=30,60,600
			recap:layoutField(220);recap:setDetails(true)
			game:GetService("RunService").RenderStepped:Wait();game:GetService("RunService").RenderStepped:Wait()
			assert(recap.fieldBody.CanvasSize.Y.Offset>recap.fieldBody.AbsoluteSize.Y+1,"clip fixture needs actual expanded overflow")
			recap.fieldBody.CanvasPosition=Vector2.new(0,math.max(0,recap.fieldBody.CanvasSize.Y.Offset-recap.fieldBody.AbsoluteSize.Y))
			game:GetService("RunService").RenderStepped:Wait();game:GetService("RunService").RenderStepped:Wait()
			local function physicallyInside(node)
				local p,s,q,v=node.AbsolutePosition,node.AbsoluteSize,recap.fieldBody.AbsolutePosition,recap.fieldBody.AbsoluteSize
				return p.X>=q.X-.5 and p.Y>=q.Y-.5 and p.X+s.X<=q.X+v.X+.5 and p.Y+s.Y<=q.Y+v.Y+.5
			end
			assert(not physicallyInside(recap.nectarIcon)or not physicallyInside(recap.fill.Parent),"scroll fixture left both measured anchors inside the viewport")
			recap:paintFeedback(Feedback.sample(.62))
			assert(not recap.transferAnchorsVisible and not recap.transfer.Visible,"clipped bottle or meter kept a travel lane")
			for _,chip in ipairs(recap.chips)do assert(not chip.Visible)end
			recap.feedback:cancel()
			recap.headerInset,recap.footerInset,recap.layoutWidth=savedHeader,savedFooter,savedWidth
			root.Size=UDim2.fromOffset(600,500);recap:layoutField(500)
		end)
		test("selected egg progress draws above its panel and retains partial or full saved balance",function()
			reduced=true
			for _,balance in ipairs({9,18,25}) do
				show(result(600+balance,{balance=balance}))
				assert(recap.fill.Parent.ZIndex>recap.eggPanel.ZIndex and recap.fill.ZIndex>recap.fill.Parent.ZIndex)
				assert(math.abs(recap.fill.Size.X.Scale-math.clamp(balance/18,0,1))<.00001)
				assert(recap.bankGraphic.Text=="Stars saved: "..balance)
				for _,label in ipairs({recap.eggGoal,recap.bankGraphic,recap.shortfall}) do assert(label.TextXAlignment==Enum.TextXAlignment.Left) end
			end
		end)
		test("first Saved receipt survives synchronous resize during publication",function()
			local isolated=Recap.new(root,nil,true);isolated.frame.Visible=true
			local title=isolated.title;local calls=0
			-- Force the same callback path synchronously from the first title write,
			-- independent of Studio's Immediate/Deferred signal setting.
			isolated.title=setmetatable({},{
				__index=function(_,key)
					local value=title[key]
					if type(value)=="function" then return function(_,...)return value(title,...)end end
					return value
				end,
				__newindex=function(_,key,value)
					title[key]=value
					if key=="Text" and isolated.updatingField then
						calls+=1
						assert(isolated.displayRecipe==Catalog.ById.meadow and isolated.displayCost==18 and isolated.displayBalance==20 and isolated.displayReward==14,"partial canonical presentation exposed")
						isolated.frame.Size=UDim2.fromOffset(600,500)
						isolated:layoutField(500)
					end
				end,
			})
			local passed,problem=pcall(function()isolated:updateField(result(701))end)
			isolated.title=title
			assert(passed,problem);assert(calls>0 and isolated.hasReceipt and isolated.updatingField==false)
			isolated:layoutField(500)
			assert(isolated.eggGoal.Text:find("20/18",1,true) and isolated.bankGraphic.Text=="Stars saved: 20")
			isolated.frame:Destroy()
		end)
		test("destroying the component removes its animation connection", function()
			reduced = false; show(result(500))
			assert(recap.feedback.active)
			recap.frame:Destroy()
			assert(not recap.feedback.active and recap.feedback.connection == nil)
		end)
	end)
	root:Destroy()
	assert(ok, problem)
	return { passed = #cases, cases = cases }
end
