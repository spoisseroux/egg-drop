-- The "Coming up" strip (TomorrowStrip, Onboarding v3 slice E; QA-R2-LOOK 5): nothing unless the nest is on and has an
-- egg; the egg's live clock, the next stamp and the day's quests in whole, short and tiny words, ready chips first;
-- text never truncates; the live pass writes only what changed and keeps the last model through a nil; the Dash card
-- makes room for it only when there is one.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.TomorrowStrip)(PlayerScripts.Client); offline in
-- scripts/run_dash_server_specs.py (DASH_SPECS="TomorrowStrip").
return function(client)
	local Strip=require(client.TomorrowStrip)
	local Card=require(client.DashCard)
	local UICopy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
	local Eggs=require(game:GetService("ReplicatedStorage").Shared.EggCatalog)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function measure(text,size)return #text*size*.55 end
	-- 19:00 on a game day (the day starts at 05:00 UTC): the reset is 5 h away.
	local DAY=100
	local NOW=DAY*86400-Eggs.DayOffsetSeconds+19*3600
	local function ctx(left,state,on,now)return{on=on~=false,nest={left=left},state=state or {stamps=1,dailyAvailable=false},now=now or NOW}end
	local function chip(model,id)for _,c in ipairs(model.chips)do if c.id==id then return c end end end
	local function ids(model)local out={};for _,c in ipairs(model.chips)do table.insert(out,c.id)end;return table.concat(out,",")end
	local function quests(rows)local daily={};for i,r in ipairs(rows)do daily[i]={claimed=r=="claimed",ready=r=="ready"}end;return{day=DAY,daily=daily}end

	test("off: no strip with the nest off, with no egg, or for junk",function()
		assert(Strip.model(ctx(3600,nil,false))==nil,"switch off")
		assert(Strip.model({on=true,nest=nil,state={}})==nil,"no egg")
		assert(Strip.model(nil)==nil and Strip.model("junk")==nil and Strip.model({on=true,nest={left="soon"}})==nil)
	end)
	test("the egg's clock: hours floored, minutes rounded up, 60 rolls to the hour; whole, short and tiny",function()
		local rows={
			{7*3600+52*60,"Egg in 7 h 52 m","7 h 52 m","7h 52m"},
			{7*3600+51*60+1,"Egg in 7 h 52 m","7 h 52 m","7h 52m"},
			{7*3600+10*60,"Egg in 7 h 10 m","7 h 10 m","7h 10m"},
			{7*3600,"Egg in 7 h","7 h","7h"},
			{7*3600+59*60+30,"Egg in 8 h","8 h","8h"},
			{42*60,"Egg in 42 min","42 min","42m"},
			{59*60+30,"Egg in 1 h","1 h","1h"},
			{61,"Egg in 2 min","2 min","2m"},
			{59,"Egg in under 1 min","<1 min","<1m"},
			{0,"Egg ready!","Ready!","Ready!"},
		}
		for _,row in ipairs(rows)do
			local egg=chip(Strip.model(ctx(row[1])),"nest")
			assert(egg.text==row[2]and egg.short==row[3]and egg.tiny==row[4],row[1]..": "..egg.text.." / "..egg.short.." / "..egg.tiny)
			assert((egg.gold==true)==(row[1]==0),"gold only when ready")
		end
		assert(Strip.model(ctx(3600)).title=="Coming up"and Strip.model(ctx(3600)).wait=="Miss a day, lose nothing.")
	end)
	test("the stamp: ready (gold outline) while today's waits, its time once taken, the next one past the boundary",function()
		local ready=chip(Strip.model(ctx(3600,{stamps=2,dailyAvailable=true})),"stamp")
		assert(ready.text=="Stamp 3 ready: +"..Strip.stamp({stamps=2,dailyAvailable=true}).reward and ready.outline and ready.ready,ready.text)
		assert(ready.short=="+"..ready.stars and Strip.numeric(ready.short),"a bare number")
		local taken=chip(Strip.model(ctx(3600,{stamps=3,dailyAvailable=false})),"stamp")
		assert(taken.text=="Stamp 4 in 5 h"and taken.short=="5 h"and taken.tiny=="5h"and not taken.ready,taken.text)
		-- Past the day boundary the snapshot is stale (its quests say yesterday): no time until the next snapshot.
		local stale=chip(Strip.model(ctx(3600,{stamps=3,dailyAvailable=false,quests=quests({"claimed"})},true,NOW+6*3600)),"stamp")
		assert(stale.text=="Next stamp: +"..stale.stars and stale.short=="+"..stale.stars,stale.text)
		-- FABLE-REVIEW-R3 5.3: the egg's words (7 h 17 m left never reads "8 h"); under 1 h in minutes.
		local later=chip(Strip.model(ctx(3600,{stamps=0,dailyAvailable=false},true,NOW-(2*3600+17*60))),"stamp")
		assert(later.text=="Stamp 1 in 7 h 17 m"and later.short=="7 h 17 m"and later.tiny=="7h 17m",later.text)
		local soon=chip(Strip.model(ctx(3600,{stamps=0,dailyAvailable=false},true,NOW+5*3600-40*60)),"stamp")
		assert(soon.text=="Stamp 1 in 40 min"and soon.short=="40 min",soon.text)
		assert(chip(Strip.model(ctx(3600,{stamps=0,dailyAvailable=false},true,NOW+5*3600-20)),"stamp").text=="Stamp 1 in 1 min")
		assert(math.abs(Strip.resetIn(NOW)-5*3600)<1e-6 and Strip.dayOf(NOW)==DAY)
		assert(chip(Strip.model(ctx(60,{stamps=7,dailyAvailable=false})),"stamp").index==1,"a full card: the first of the next")
	end)
	test("the quests: ready to claim (gold) first, else to go; done is every daily claimed; weekly ignored",function()
		local m=Strip.model(ctx(3600,{stamps=1,quests=quests({"open","ready","claimed"})}))
		local q=chip(m,"quests")
		assert(q.text=="1 ready to claim"and q.short=="Ready!"and q.tiny=="Ready!"and q.outline and q.ready,"FABLE-REVIEW-R3 5.1: "..q.text)
		local open=chip(Strip.model(ctx(3600,{stamps=1,quests=quests({"open","open","claimed"})})),"quests")
		assert(open.text=="2 quests to go"and open.short=="2 left"and open.tiny=="2"and not open.outline and not open.ready,open.text)
		assert(chip(Strip.model(ctx(3600,{quests=quests({"open","claimed","claimed"})})),"quests").text=="1 quest to go")
		local done=chip(Strip.model(ctx(3600,{quests=quests({"claimed","claimed","claimed"})})),"quests")
		assert(done.text=="New quests in 5 h"and done.icon=="check"and done.soft,done.text)
		assert(chip(Strip.model(ctx(3600,{quests=quests({"claimed"})},true,NOW-(2*3600+17*60))),"quests").text=="New quests in 7 h 17 m")
		local stale=chip(Strip.model(ctx(3600,{quests=quests({"claimed","claimed","claimed"})},true,NOW+6*3600)),"quests")
		assert(stale.text=="Quests done!"and stale.short=="Done!"and stale.tiny=="Done",stale.text)
		assert(chip(Strip.model(ctx(3600,{})),"quests").text==Strip.Quests.." quests to go","no snapshot: the day's set")
		local weekly={day=DAY,daily={{claimed=true},{claimed=true},{claimed=true}},weekly={{claimed=false}}}
		assert(chip(Strip.model(ctx(3600,{quests=weekly})),"quests").text=="New quests in 5 h")
	end)
	test("ready chips sort first: egg, then stamp, then quests",function()
		assert(ids(Strip.model(ctx(3600)))=="nest,stamp,quests")
		assert(ids(Strip.model(ctx(3600,{stamps=1,dailyAvailable=true})))=="stamp,nest,quests")
		assert(ids(Strip.model(ctx(0,{stamps=1,dailyAvailable=true,quests=quests({"ready"})})))=="nest,stamp,quests")
		assert(ids(Strip.model(ctx(3600,{stamps=1,quests=quests({"ready"})})))=="quests,nest,stamp")
	end)
	test("fit: wide keeps every long text at 14; narrow shrinks, then short, then tiny; never cut",function()
		local m=Strip.model(ctx(7*3600+52*60))
		local wide=Strip.fit(m,800,measure)
		for _,c in ipairs(wide.chips)do assert(c.size==14,"wide: 14")end
		assert(wide.chips[1].text=="Egg in 7 h 52 m"and wide.title.w==Strip.TitleW and wide.h==44)
		assert(wide.chips[2].x>wide.chips[1].x+wide.chips[1].w and wide.chips[3].x>wide.chips[2].x+wide.chips[2].w,"flows right")
		for _,width in ipairs({560,480,420,360,300})do
			local f=Strip.fit(m,width,measure)
			for index,c in ipairs(f.chips)do
				local spec=m.chips[index]
				assert(c.text==spec.text or c.text==spec.short or c.text==spec.tiny,"whole, short or tiny, never cut")
			end
		end
		local short=Strip.fit(m,800,measure,{short=true})
		assert(short.chips[1].text=="7 h 52 m"and short.chips[3].text=="3 left","a narrow card: short at once")
	end)
	test("phone (v2): 48 px, the title row inside, three equal centred chips; whole from 400 if it fits, short, tiny under 300, none under 240",function()
		local m=Strip.model(ctx(42*60))
		local f=Strip.fit(m,800,measure,{phone=true})
		assert(f.h==48 and f.chips[1].w==f.chips[2].w and f.chips[2].w==f.chips[3].w)
		assert(f.chips[1].text=="Egg in 42 min"and f.chips[1].size==12,f.chips[1].text)
		assert(f.title.y==11 and f.title.x==25,"the title has its own row")
		for _,c in ipairs(f.chips)do
			assert(c.y==21 and c.h==22 and c.y+c.h<=f.h-4,"chips under the title, inside the strip")
			assert(c.inset>=4 and c.inset*2+c.icon+5+measure(c.text,c.size)<=c.w+1 or c.inset==4,"centred")
		end
		local long=Strip.model(ctx(7*3600+52*60))
		local f400=Strip.fit(long,400,measure,{phone=true})
		assert(f400.chips[1].text=="7 h 52 m"or f400.chips[1].text=="7h 52m","the whole words do not fit a 125 px column: short")
		local mid=Strip.fit(long,320,measure,{phone=true})
		assert(mid.chips[1].text=="7 h 52 m"or mid.chips[1].text=="7h 52m")
		local small=Strip.fit(long,290,measure,{phone=true})
		assert(small.chips[1].text=="7h 52m"and small.chips[3].text=="3","under 300: tiny")
		assert(Strip.fit(long,239,measure,{phone=true})==nil and Strip.fit(long,240,measure,{phone=true})~=nil,"under 240: no strip")
	end)
	test("DeckLook off: the phone strip before v2 (36 px, the title on a tab, drawn at any width)",function()
		local m=Strip.model(ctx(7*3600))
		local f=Strip.fit(m,600,measure,{phone=true,v2=false})
		assert(f.h==36 and not f.v2 and f.chips[1].w==f.chips[2].w and f.chips[1].y==nil and f.chips[1].inset==nil)
		local small=Strip.fit(m,200,measure,{phone=true,v2=false,short=true})
		assert(small~=nil,"no 240 floor before v2")
		local host=Instance.new("Frame")
		local old=Strip.new(host,{measure=measure,phone=true,short=true,v2=false})
		old:set(m,200)
		assert(old.tab~=nil and old.mark==nil and old.h==36 and old.root.Visible)
		assert(Strip.phoneHeight(false)==36 and Strip.phoneHeight(true)==48)
	end)
	test("the strip draws the texts, is ComingUpStrip, never a button, and hides for nil",function()
		local host=Instance.new("Frame")
		local view=Strip.new(host,{measure=measure,wait=true})
		view:set(Strip.model(ctx(40*60,{stamps=3,dailyAvailable=false})),800)
		local texts=view:texts()
		assert(view.root.Name=="ComingUpStrip")
		assert(texts.title=="Coming up"and texts.nest=="Egg in 40 min"and texts.stamp=="Stamp 4 in 5 h"and texts.quests=="3 quests to go",texts.stamp)
		assert(view.wait.Text=="Miss a day, lose nothing.")
		assert(view.byId.stamp.text.TextColor3==Strip.Color.text,"FABLE-REVIEW-R3 5.2: hours away is not gold")
		view:set(Strip.model(ctx(40*60,{stamps=3,dailyAvailable=true,quests=quests({"ready"})})),800)
		assert(view.byId.stamp.text.TextColor3==Strip.Color.stars and view.byId.stamp.stroke.Color==Strip.Color.stars and view.byId.stamp.stroke.Thickness==2,"ready: gold")
		assert(view.byId.quests.stroke.Color==Strip.Color.stars and view.byId.quests.stroke.Thickness==2 and view.byId.quests.text.TextColor3==Strip.Color.text)
		for _,item in ipairs(view.root:GetDescendants())do
			assert(item.ClassName~="TextButton"and item.ClassName~="ImageButton","never a button")
		end
		assert(view.root.Selectable==false and view.root.Active==false)
		view:set(Strip.model(ctx(0)),800)
		assert(view.byId.nest.frame.BackgroundColor3==Strip.Color.stars and view:texts().nest=="Egg ready!","ready: gold")
		assert(view.chips[1].id=="nest","ready first")
		view:set(nil,800);assert(view.root.Visible==false)
		assert(view:enter(1,false)==false,"hidden: no entrance")
		view:destroy();assert(#host:GetChildren()==0)
		local phone=Strip.new(host,{measure=measure,phone=true,short=true})
		phone:set(Strip.model(ctx(3600,{stamps=1,dailyAvailable=true})),300)
		assert(phone:texts().stamp=="+"..Strip.stamp({stamps=1}).reward and phone.byId.stamp.text.AutoLocalize==false,"a number is never sent for translation")
		assert(phone.byId.nest.text.AutoLocalize==true,"words with units are")
		assert(phone.mark~=nil and phone.mark.Name=="Clock"and phone.tab==nil and phone.wait==nil,"v2: the clock mark, no tab")
		phone:set(Strip.model(ctx(3600)),200);assert(phone.root.Visible==false,"too narrow: not drawn")
	end)
	test("live: a pass a second, a write only when a word changes, the last model kept through a nil, gone on destroy",function()
		local host=Instance.new("Frame");host.Parent=workspace
		local ticks={}
		local watches={}
		local clock={connect=function(fn)local handle={fn=fn};function handle:Disconnect()self.gone=true end;table.insert(ticks,handle);return handle end,
			watch=function(node,property,fn)local handle={node=node,property=property,fn=fn};function handle:Disconnect()self.gone=true end;table.insert(watches,handle);return handle end}
		local left,answer=7*3600+52*60,true
		local calls=0
		local view=Strip.new(host,{measure=measure,source=function()calls+=1;return if answer then Strip.model(ctx(left))else nil end,clock=clock})
		view:set(Strip.model(ctx(left)),800)
		assert(#ticks==1 and view.link==ticks[1],"one connection")
		view:set(Strip.model(ctx(left)),800);assert(#ticks==1,"a second set adds none")
		local function second()ticks[#ticks].fn(1)end
		local text=view.byId.nest.text
		local writes=0
		local set=view.set
		view.set=function(self,...)writes+=1;return set(self,...)end
		for _=1,20 do left-=1;second()end
		assert(calls==20 and writes==0 and text.Text=="Egg in 7 h 52 m","same minute: nothing written")
		left=7*3600+51*60;second()
		assert(text.Text=="Egg in 7 h 51 m"and writes==1,"the next minute: one write")
		answer=false;second()
		assert(view.root.Visible and text.Text=="Egg in 7 h 51 m","a nil keeps the last model: no collapse")
		answer=true;left=0;second()
		assert(view.byId.nest.gold and view.chips[1].id=="nest"and text.Text=="Egg ready!","ready: gold, first")
		host.Visible=false;left=600;second()
		assert(text.Text=="Egg ready!"and view.link==nil and ticks[1].gone,"hidden: the pass is cut")
		assert(#watches==1 and watches[1].node==host and watches[1].property=="Visible"and view.wake==watches[1],"one watch on what hides it")
		host.Visible=true;watches[1].fn()
		assert(watches[1].gone and view.wake==nil and #ticks==2 and view.link==ticks[2],"shown again: the pass comes back")
		second();assert(text.Text=="Egg in 10 min","a new egg (no bounce)")
		host.Visible=false;second();assert(#watches==2 and view.link==nil)
		view:destroy();assert(watches[2].gone and view.wake==nil and view.link==nil,"destroy: everything goes")
		-- Hidden when the screen first sets it (a sheet's entrance): parked at once, no pass a second.
		local hidden=Instance.new("Frame");hidden.Parent=workspace;hidden.Visible=false
		local parked=Strip.new(hidden,{measure=measure,source=function()return Strip.model(ctx(left))end,clock=clock})
		local before=#ticks;parked:set(Strip.model(ctx(left)),800)
		assert(#ticks==before and parked.wake and parked.link==nil,"no pass while hidden")
		parked:destroy();hidden:Destroy()
		host:Destroy()
	end)
	test("enter: refused before set; after it, the tween goes home to where the strip was placed",function()
		local host=Instance.new("Frame")
		local view=Strip.new(host,{measure=measure,phone=true,short=true})
		local before=view.root.Position
		assert(view:enter(1,false)==false and view.home==nil and view.root.Position==before,"before set: nothing moves")
		local placed=UDim2.fromOffset(10,240)
		view.root.Position=placed
		view:set(Strip.model(ctx(3600)),300)
		assert(view:enter(1,false)==true and view.home==placed,"home is the placed spot, not (0, 0)")
		assert(#view.chips==3,"the chips exist when they fade in")
	end)
	test("the Dash card: room for the strip only when there is one",function()
		for _,screen in ipairs({{1280,720},{700,400}})do
			local plain=Card.layout(screen[1],screen[2],{24,24,24},2)
			local with=Card.layout(screen[1],screen[2],{24,24,24},2,true)
			assert(plain.stripY==nil and plain.stripH==0)
			local extra=if with.compact then 54 else 52
			assert(with.buttonY==plain.buttonY+extra and with.stripY==plain.buttonY,"the buttons move down under it")
			assert(with.stripH==(if with.compact then 48 else 44))
		end
	end)
	return{passed=#cases,cases=cases}
end
