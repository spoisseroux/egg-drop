-- Studio Client presentation fixtures for the RecapFeedback clock (used by
-- DeckResults). No remotes or progression writes.
return function(client, parent)
	local Feedback=require(client.RecapFeedback)
	local Catalog = require(game:GetService("ReplicatedStorage").Shared.EggCatalog)
	local root = Instance.new("Frame")
	root.Name, root.Size, root.BackgroundTransparency, root.Parent = "_RecapFeedbackSpec", UDim2.fromOffset(360, 236), 1, parent
	local reduced, sounds = false, {}
	local audio = { group = { Volume = 1 } }
	function audio:play(name, speed, volume)
		if self.group.Volume ~= 0 then table.insert(sounds, { name, speed, volume }) end
	end
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
	local function advance(feedback,duration)
		local remaining=duration
		while remaining>.000001 do local dt=math.min(.01,remaining);feedback:step(dt);remaining-=dt end
	end
	local function clockFixture()
		local owner,reduced,last=true,false,nil
		local audio={group={Volume=1},deviceActive=true,deviceEpoch=0,cues={},stops=0,blip=true}
		function audio:play(name,pitch,volume,token)
			-- Like BoardAudio: a cue with no voice (count_blip before its upload) plays nothing.
			if name=="count_blip"and not self.blip then return false end
			if self.group.Volume>0 and self.deviceActive then table.insert(self.cues,{name=name,pitch=pitch,volume=volume,owner=token});return true end
			return false
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
		test("committed timeline uses two source notes, one rising tick per Star and one quiet cadence",function()
			local f,a,observe,last=clockFixture();local packet=result(800)
			table.freeze(packet.reward);table.freeze(packet)
			assert(observe(packet,true)and last().earned==1 and last().counted==0 and #a.cues==0 and f.chips==5)
			advance(f,.17);assert(#a.cues==0)
			advance(f,.17);assert(#a.cues==2 and a.cues[1].name=="bank"and a.cues[2].pitch>a.cues[1].pitch)
			-- The Star lands at 450 ms; the count starts at 600 ms.
			advance(f,.3);assert(a.cues[3].name=="star_land");local mid=last().counted;assert(mid>0 and mid<14,"no partial count "..tostring(mid))
			advance(f,1.5);assert(not f.active and last()==nil)
			local ticks,pitch=0,0
			-- Count blips (batch 2026-11-13): one very short count_blip per +1, rising.
			for i=4,#a.cues-2 do local cue=a.cues[i];assert(cue.name==Feedback.BlipCue and cue.volume<=.25 and cue.owner==f,"blip "..tostring(cue.name));ticks+=1;assert(math.abs(cue.pitch-math.min(1.6,1+ticks*.02))<1e-6 and cue.pitch>pitch,"blip pitch");pitch=cue.pitch end
			assert(ticks==14,"ticks="..ticks)
			assert(a.cues[#a.cues-1].name=="bank"and a.cues[#a.cues-1].volume<=.14 and a.cues[#a.cues].name=="stars_total","finale cadence")
			assert(packet.reward.total==14 and packet.balance==20)
			local count=#a.cues;assert(not observe(packet,true)and #a.cues==count)
		end)
		test("count blips: one per +1, each cut by the next (one voice), and the old tick stands in when the blip has no voice",function()
			local f,a,observe=clockFixture();local packet=result(805)
			assert(observe(packet,true));advance(f,3)
			local blips,charges=0,0
			for _,cue in ipairs(a.cues)do if cue.name=="count_blip"then blips+=1 elseif cue.name=="charge"then charges+=1 end end
			assert(blips==14 and charges==0,"blips="..blips.." charges="..charges)
			-- BoardAudio registers count_blip with one voice: a new play restarts it (cut by the next).
			local BoardAudio=require(client.BoardAudio);assert(not BoardAudio.PendingCues.count_blip,"count_blip is uploaded (108647439201867)")
			local g,b,observe2=clockFixture();b.blip=false;assert(observe2(result(806),true));advance(g,3)
			blips,charges=0,0
			for _,cue in ipairs(b.cues)do if cue.name=="count_blip"then blips+=1 elseif cue.name=="charge"then charges+=1 end end
			assert(blips==0 and charges==14,"fallback charges="..charges)
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
		test("count rule holds for every payout: at most 80 ms a Star, all within 900 ms, finale after the last",function()
			for earned=1,40 do
				local spacing,countEnd=Feedback.spacingFor(earned),Feedback.countEndFor(earned)
				assert(spacing<=Feedback.CountStep+1e-9 and countEnd-Feedback.CountStart<=Feedback.CountSpan+1e-9,"rule at "..earned)
				local finale=Feedback.finaleAt(countEnd)
				assert(math.abs(finale-countEnd-.08)<1e-9 and math.abs(Feedback.durationFor(earned)-math.max(1.1,finale+.5))<1e-9)
			end
			assert(Feedback.CountStart==.6 and Feedback.DropAt==.45)
		end)
		test("celebration lanes: entrance, drop, per-Star pop and finale phases",function()
			local countEnd=Feedback.countEndFor(6);local finale=Feedback.finaleAt(countEnd)
			local s0=Feedback.sample(0,countEnd);assert(s0.entrance==0 and s0.drop==0 and s0.finale==0 and not s0.hints)
			assert(Feedback.sample(.22,countEnd).entrance==1 and Feedback.sample(.45,countEnd).drop==0 and Feedback.sample(.75,countEnd).drop==1)
			assert(Feedback.sample(finale,countEnd).finale==0 and math.abs(Feedback.sample(finale+.25,countEnd).finale-.5)<1e-6)
			assert(Feedback.sample(finale+.19,countEnd).best==0 and Feedback.sample(finale+.4,countEnd).best==1)
			assert(not Feedback.sample(finale+.45,countEnd).hints and Feedback.sample(finale+.6,countEnd).hints and Feedback.sample(finale+.6,countEnd).strip==1)
			local spacing=Feedback.spacingFor(6)
			assert(Feedback.popAt(.6,1,spacing)==1 and Feedback.popAt(.6+.091,1,spacing)==0 and Feedback.popAt(.5,0,spacing)==0)
			assert(math.abs(Feedback.popAt(.6+spacing+.045,2,spacing)-.5)<1e-6)
			assert(Feedback.stagger(.15,1,.15,.09,.12)==0 and Feedback.stagger(.4,2,.15,.09,.12)==1)
		end)
		test("view beats fire once at their time, finale beats after the finale",function()
			local f,a,observe=clockFixture()
			f:setBeats({{at=.15,cue="goal_tick",pitch=1},{at=.24,cue="goal_tick",pitch=1.06},{at=.2,cue="new_best",finale=true}})
			assert(observe(result(809),true));advance(f,.2)
			local ticks=0;for _,cue in ipairs(a.cues)do if cue.name=="goal_tick"then ticks+=1 end end;assert(ticks==1)
			advance(f,3);ticks=0;local best=0
			for _,cue in ipairs(a.cues)do if cue.name=="goal_tick"then ticks+=1 elseif cue.name=="new_best"then best+=1 end end
			assert(ticks==2 and best==1 and not f.active)
		end)
		-- The view tests moved to DeckResults.spec.lua with the in-deck results screen.
	end)
	root:Destroy()
	assert(ok, problem)
	return { passed = #cases, cases = cases }
end
