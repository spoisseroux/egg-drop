-- v2 Stat Eggs on the client: the odds card and button (StatEggOdds), the pouch tray's pure
-- parts (SnackTray), the eating beats (SnackEating), the network intent (SnackIntent), the
-- reveal words and the boost line. Run in Play (UICopy keys are new).
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.StatEggsClient)(PlayerScripts.Client)
return function(client)
	local Odds=require(client.StatEggOdds)
	local Tray=require(client.SnackTray)
	local Eating=require(client.SnackEating)
	local Intent=require(client.SnackIntent)
	local Reveal=require(client.StatEggReveal)
	local Host=require(client.SnackHost)
	local Panel=require(client.StatsPanel)
	local SnackModel=require(client.SnackModel)
	local Shop=require(client.EggHatchView)
	local K=require(game:GetService("ReplicatedStorage").Shared.StatEggCatalog)
	local Stats=require(game:GetService("ReplicatedStorage").Shared.StatCatalog)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local all={"heart","power","energy","jump","speed","smarts"}
	local function state(over)
		local egg={enabled=true,mode="random",price=15,pouch={},pouchSize=12,free=0,freeLimit=10,boughtToday=0,dailyBuys=3,misses=0,pityLeft=8,
			quotes={pip={key="k",eligible=table.clone(all)}}}
		for k,v in pairs(over or {})do egg[k]=v end
		return{nectar=100,statEgg=egg}
	end

	test("odds card: equal stat share, the size table, the Feast promise, and the restricted Next line",function()
		local o=Odds.rows(state(),"pip")
		assert(o.rows[1].id=="stat"and o.rows[1].value=="16.67%","stat share "..tostring(o.rows[1].value))
		assert(o.rows[2].id=="nibble"and o.rows[2].value=="60%"and o.rows[3].value=="30%"and o.rows[4].id=="feast"and o.rows[4].value=="10%")
		assert(o.rows[5].id=="pity"and o.rows[5].name:find("8"),"pity "..o.rows[5].name)
		assert(o.rows[#o.rows].id=="rounded","16.67% is rounded, so the note shows")
		local due=Odds.rows(state({misses=7}),"pip")
		assert(due.rows[2].value=="0%"and due.rows[4].value=="100%","a promised Feast reads 100%")
		local five=state();five.statEgg.quotes.pip.eligible={"heart","power","energy","jump","speed"}
		assert(Odds.rows(five,"pip").rows[1].value=="20%","a stat at 99 leaves the pool")
		local fixed=Odds.rows(state({mode="fixed",quotes={pip={key="k",eligible=all,next={stat="energy",size="nibble"}}}}),"pip")
		assert(fixed.restricted and fixed.rows[1].name:find("Energy")and fixed.rows[1].name:find("Nibble"),"Next: Energy Nibble")
		for _,row in ipairs(fixed.rows)do assert(not string.find(row.value,"%%"),"no percentages for a restricted player")end
		assert(Odds.rows(state(),"bunny").empty and Odds.rows({},"pip").empty)
	end)

	test("button: free eggs first, the daily stock, a full pouch, Stars",function()
		assert(Odds.action(state(),"pip").enabled)
		local a=Odds.action(state({free=2}),"pip");assert(a.enabled and a.free and a.text:find("2"))
		assert(not Odds.action(state({boughtToday=3}),"pip").enabled)
		local pouch={};for i=1,12 do pouch[i]={id=i,stat="heart",size="nibble"}end
		assert(not Odds.action(state({pouch=pouch,free=3}),"pip").enabled,"a full pouch blocks even a free egg")
		local poor=state();poor.nectar=3
		local p=Odds.action(poor,"pip");assert(not p.enabled and p.need)
		assert(Shop.hatchAction("stat",state(),"pip").enabled and Shop.oddsRows("stat",state(),"pip").rows[1].id=="stat")
		assert(table.find(Shop.liveOrder({StatEgg=true}),"stat")and not table.find(Shop.liveOrder({}),"stat"))
	end)

	test("tray: groups by stat then size with counts, the card line, the forgiving drop target",function()
		local groups=Tray.groups({{id=3,stat="jump",size="snack"},{id=1,stat="heart",size="feast"},{id=2,stat="jump",size="snack"},{id=4,stat="heart",size="nibble"},{id=9,stat="future",size="x"}})
		assert(#groups==4 and groups[1].key=="heart:nibble"and groups[2].key=="heart:feast"and groups[3].key=="jump:snack")
		assert(groups[3].count==2 and groups[3].ids[1]==2,"oldest first")
		assert(groups[4].known==false,"an unknown snack is shown, never fed")
		local line=Tray.cardLine(groups[3],{jump={mult=2,left=80}})
		assert(line:find("120")and line:find("80"),line)
		assert(Tray.inside(Vector2.new(100,100),Vector2.new(90,90),Vector2.new(20,20)),"tiny pets still get 96 px")
		assert(not Tray.inside(Vector2.new(200,200),Vector2.new(90,90),Vector2.new(20,20)))
		assert(Tray.inside(Vector2.new(114,100),Vector2.new(0,0),Vector2.new(100,200)),"grown 30%")
		assert(not Tray.inside(Vector2.new(1,1),nil,nil))
	end)

	test("eating: bite counts and times by size, the Feast crunch first, never the same nom twice",function()
		local function count(kind,beats)local n=0;for _,b in ipairs(beats)do if b.kind==kind then n+=1 end end;return n end
		for size,bites in pairs({nibble=2,snack=3,feast=4})do
			local beats,plan=Eating.beats(size,false)
			assert(count("bite",beats)==bites and count("gulp",beats)==1 and count("burst",beats)==1,size)
			assert(beats[#beats].t<plan.length,"everything inside the "..plan.length.." s")
			local prev
			for _,b in ipairs(beats)do if b.kind=="bite"then assert(b.cue~=prev,"repeat nom");prev=b.cue end end
		end
		assert(Eating.beats("feast",false)[1].cue=="snack_crunch_feast")
		local reduced=Eating.beats("feast",true)
		assert(count("bite",reduced)==1 and count("burst",reduced)==0 and count("happy",reduced)==0,"Reduced Motion: one bite, no burst")
	end)

	test("intent: one id per press, resent on Retrying/Busy, a timeout ends the feed",function()
		local sent,delays,results={}, {},{}
		local request={FireServer=function(_,action,value)table.insert(sent,{action=action,id=value.id})end}
		local n=0
		local intent=Intent.new(request,nil,{guid=function()n+=1;return "g"..n end,delay=function(t,f)table.insert(delays,{t=t,f=f})end})
		intent:feed(7,"pip",function(m)table.insert(results,m)end)
		assert(#sent==1 and sent[1].action=="snackFeed"and sent[1].id=="g1")
		intent:onResult({id="g1",status="Retrying",reason="Retrying"})
		delays[2].f() -- the resend
		assert(#sent==2 and sent[2].id=="g1","the same id is resent")
		intent:onResult({id="g1",status="Saved",reason="Saved",receipt={snackId=7}})
		assert(#results==1 and results[1].status=="Saved")
		delays[1].f() -- the timeout after the answer does nothing
		assert(#results==1)
		intent:feed(8,"pip",function(m)table.insert(results,m)end)
		delays[#delays].f()
		assert(#results==2 and results[2].status=="Timeout")
		local late
		intent.onLate=function(action,m)late={action=action,status=m.status}end
		intent:onResult({id="g2",status="Saved"})
		assert(#results==2 and late and late.action=="snackFeed"and late.status=="Saved","a late answer goes to onLate, not the closed press")
		late=nil;intent:onResult({id="g2",status="Saved"})
		assert(late==nil,"once")
		assert(not intent:pending())
	end)

	test("beta (34): the machine's gate holds only the reveal it names; none set (live) holds nothing; a throwing gate never does",function()
		local saved=Reveal.gate
		local mine,other={},{}
		Reveal.gate=nil
		assert(not Reveal.gated(mine))
		Reveal.gate=function(r)return r==mine end
		assert(Reveal.gated(mine)and not Reveal.gated(other))
		Reveal.gate=function()error("boom")end
		assert(not Reveal.gated(mine))
		Reveal.gate=saved
	end)
	test("words: the reveal, the boost line, the stat tile, refusal lines",function()
		local w=Reveal.copy({stat="jump",size="snack",snackId=1},"Bear")
		assert(w.name:find("Jump")and w.name:find("Snack")and w.boost:find("2")and w.boost:find("120"))
		assert(Host.boostLine({stat="power",size="feast"}):find("3x"))
		assert(Panel.boostText({boost={mult=2,left=80,queued=80}})=="2x · 80 XP left")
		assert(Panel.boostText({boost={mult=2,left=80,queued=200}}):find("120"))
		assert(Panel.boostText({})==nil)
		assert(Host.reasonText("InRound","Bear"):find("round"))
		assert(Host.reasonText("QueueFull","Bear","jump"):find("Jump"))
		assert(Host.reasonText("Weird","Bear")~="stats.snacks.reason.Weird")
		assert(Host.reasonText("PouchFull",nil,nil,true):find("pouch"))
		assert(Host.revealPill({statEgg={mode="random",misses=4}},"pip"):find("4"))
	end)

	test("the snack model: layers by size, icon on the icing, pearls on the Feast",function()
		for size,layers in pairs({nibble=1,snack=2,feast=3})do
			local m=SnackModel.build(size,"heart",.3,{placeholder=true})
			assert(m:GetAttribute("SnackBackend")=="Placeholder")
			assert(m:GetAttribute("Layers")==layers and m.PrimaryPart and m:FindFirstChild("Layer"..layers)and m:FindFirstChild("Icing"))
			assert((m:FindFirstChild("Pearl1")~=nil)==(size=="feast"))
			for _,part in ipairs(m:GetDescendants())do if part:IsA("BasePart")then assert(not part.CanCollide and part.Anchored)end end
			m:Destroy()
		end
		-- Production meshes (ReplicatedStorage.SnackAssets, or their runtime copies): same contract.
		SnackModel.warm()
		local deadline=os.clock()+8
		while not(SnackModel.template("nibble")and SnackModel.template("snack")and SnackModel.template("feast"))and os.clock()<deadline do task.wait(.2)end
		for size,layers in pairs({nibble=1,snack=2,feast=3})do
			local m=SnackModel.build(size,"jump",.3)
			assert(m:GetAttribute("SnackBackend")=="Production","production snack "..size)
			assert(m:GetAttribute("Layers")==layers and m:GetAttribute("StatId")=="jump"and m:GetAttribute("SizeId")==size and m.PrimaryPart)
			local biscuit,icing=m:FindFirstChild("Biscuit"),m:FindFirstChild("Icing")
			assert(biscuit and icing and biscuit:GetAttribute("SnackLayer")==1 and icing:GetAttribute("SnackLayer")==layers)
			assert(icing.Color==Stats.ById.jump.color and icing.Parent:FindFirstChild("Topper")and icing.Parent.Topper.Mark.Texture==SnackModel.IconDecal.jump,"the icon topper on the stat-colour icing")
			assert((m:FindFirstChild("Pearls")~=nil)==(size=="feast"))
			assert(math.abs(m:GetExtentsSize().X-.3)<.02,"scaled to the asked width")
			for _,part in ipairs(m:GetDescendants())do if part:IsA("BasePart")then assert(not part.CanCollide and part.Anchored)end end
			m:Destroy()
		end
		local _=K
	end)

	return {passed=#cases,cases=cases}
end
