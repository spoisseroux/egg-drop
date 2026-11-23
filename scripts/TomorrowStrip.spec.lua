-- The See you tomorrow strip (TomorrowStrip, Onboarding v3 slice E): nothing unless the nest is on and has an egg; the
-- nest clock, tomorrow's stamp and its Stars, and the new quests in the right words; text never truncates (shrink to
-- 11, then the short value); the Dash card makes room for it only when there is one.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.TomorrowStrip)(PlayerScripts.Client); offline in
-- scripts/run_dash_server_specs.py (DASH_SPECS="TomorrowStrip").
return function(client)
	local Nest=require(game:GetService("ReplicatedStorage").Shared.Nest)
	local Strip=require(client.TomorrowStrip)
	local Card=require(client.DashCard)
	local UICopy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function measure(text,size)return #text*size*.55 end
	local function ctx(left,state,on)return{on=on~=false,nest={left=left},state=state or {stamps=1,dailyAvailable=false}}end

	test("off: no strip with the nest off, with no egg, or for junk",function()
		assert(Strip.model(ctx(3600,nil,false))==nil,"switch off")
		assert(Strip.model({on=true,nest=nil,state={}})==nil,"no egg")
		assert(Strip.model(nil)==nil and Strip.model("junk")==nil and Strip.model({on=true,nest={left="soon"}})==nil)
	end)
	test("texts: the nest clock, tomorrow's stamp with its Stars, three new quests",function()
		local m=Strip.model(ctx(7*3600-30))
		assert(m.title=="See you tomorrow"and m.wait=="Miss a day, lose nothing.")
		local nest,stamp,quests=m.chips[1],m.chips[2],m.chips[3]
		assert(nest.text==UICopy.get("onb3.nest.hours",{hours=7})and nest.short==UICopy.get("onb3.nest.chipHours",{hours=7})and not nest.gold,nest.text)
		assert(stamp.text=="Stamp 2: 4 Stars"and stamp.short=="4",stamp.text)
		assert(quests.text=="3 new quests"and quests.short=="3"and Strip.Quests==3)
		local soon=Strip.model(ctx(40*60)).chips[1]
		assert(soon.text==UICopy.get("onb3.nest.minutes",{minutes=40})and soon.short==UICopy.get("onb3.nest.chipMinutes",{minutes=40}))
		local ready=Strip.model(ctx(0)).chips[1]
		assert(ready.text==UICopy.get("onb3.nest.ready")and ready.short==UICopy.get("onb3.nest.ready")and ready.gold==true)
		-- Today's stamp still waiting: that stamp; the card full: the first of the next card.
		assert(Strip.model(ctx(60,{stamps=3,dailyAvailable=true})).chips[2].text=="Stamp 4: 5 Stars")
		assert(Strip.model(ctx(60,{stamps=6,dailyAvailable=false})).chips[2].text=="Stamp 7: 12 Stars")
		assert(Strip.model(ctx(60,{stamps=7,dailyAvailable=false})).chips[2].text=="Stamp 1: 4 Stars")
		assert(Strip.model(ctx(60,{})).chips[2].text=="Stamp 1: 4 Stars","a new save")
		assert(Nest.countdown(0)=="ready")
	end)
	test("fit: wide keeps every long text at 14; narrow shrinks to 11, then the short values; never wider than the strip",function()
		local m=Strip.model(ctx(7*3600))
		local wide=Strip.fit(m,800,measure)
		for _,chip in ipairs(wide.chips)do assert(chip.size==14,"wide: 14")end
		assert(wide.chips[1].text==UICopy.get("onb3.nest.hours",{hours=7})and wide.title.w==Strip.TitleW and wide.h==44)
		assert(wide.chips[2].x>wide.chips[1].x+wide.chips[1].w and wide.chips[3].x>wide.chips[2].x+wide.chips[2].w,"flows right")
		for _,width in ipairs({560,480,420,360})do
			local f=Strip.fit(m,width,measure)
			local right=f.chips[3].x+f.chips[3].w
			local allShort=true
			for index,chip in ipairs(f.chips)do if chip.text~=m.chips[index].short then allShort=false end end
			assert(right<=width or allShort,width..": fits ("..right..")")
			for index,chip in ipairs(f.chips)do
				assert(chip.text==m.chips[index].text or chip.text==m.chips[index].short,"long or short, never cut")
				assert(chip.size==14 or chip.size==11)
			end
		end
		local tight=Strip.fit(m,360,measure)
		assert(tight.title.w==0,"no room for the title")
		local short=Strip.fit(m,800,measure,{short=true})
		assert(short.chips[1].text==UICopy.get("onb3.nest.chipHours",{hours=7})and short.chips[2].text=="4"and short.chips[3].text=="3","a narrow card: short at once")
	end)
	test("phone (v2, beta 12 U7): 48 px, the title row inside, three equal centred chips; whole words from 400, none under 240",function()
		local m=Strip.model(ctx(7*3600))
		local f=Strip.fit(m,600,measure,{phone=true})
		assert(f.h==48 and f.chips[1].w==f.chips[2].w and f.chips[2].w==f.chips[3].w)
		assert(f.chips[1].text==UICopy.get("onb3.nest.hours",{hours=7})and f.chips[1].size==12)
		assert(f.title.y==11 and f.title.x==25,"the title has its own row")
		for _,chip in ipairs(f.chips)do
			assert(chip.y==21 and chip.h==22 and chip.y+chip.h<=f.h-4,"chips under the title, inside the strip")
			assert(chip.inset>=4 and chip.inset*2+chip.icon+5+measure(chip.text,chip.size)<=chip.w+1,"centred, never cut")
		end
		local f427=Strip.fit(m,427,measure,{phone=true})
		assert(f427.chips[2].text=="Stamp 2: 4 Stars"or f427.chips[2].text=="4","the full LCD width")
		local small=Strip.fit(m,300,measure,{phone=true})
		assert(small.chips[2].text=="4"and small.chips[1].text==UICopy.get("onb3.nest.chipHours",{hours=7}),"under 400: short values")
		assert(Strip.fit(m,239,measure,{phone=true})==nil and Strip.fit(m,240,measure,{phone=true})~=nil,"under 240: no strip")
	end)
	test("DeckLook off: the phone strip before v2, exactly (36 px, the title on a tab, drawn at any width)",function()
		local m=Strip.model(ctx(7*3600))
		local f=Strip.fit(m,600,measure,{phone=true,v2=false})
		assert(f.h==36 and not f.v2 and f.chips[1].w==f.chips[2].w and f.chips[1].y==nil and f.chips[1].inset==nil)
		assert(f.chips[1].text==UICopy.get("onb3.nest.hours",{hours=7})and f.chips[1].size==12)
		local small=Strip.fit(m,200,measure,{phone=true,v2=false,short=true})
		assert(small~=nil and small.chips[2].text=="4","no 240 floor before v2")
		local host=Instance.new("Frame")
		local old=Strip.new(host,{measure=measure,phone=true,short=true,v2=false})
		old:set(m,200)
		assert(old.tab~=nil and old.moon==nil and old.h==36 and old.root.Visible)
		assert(Strip.phoneHeight(false)==36 and Strip.phoneHeight(true)==48)
	end)
	test("the strip draws the texts, is never a button, and hides for nil",function()
		local host=Instance.new("Frame")
		local view=Strip.new(host,{measure=measure,wait=true})
		view:set(Strip.model(ctx(40*60)),800)
		local texts=view:texts()
		assert(texts.title=="See you tomorrow"and texts.nest==UICopy.get("onb3.nest.minutes",{minutes=40})and texts.stamp=="Stamp 2: 4 Stars"and texts.quests=="3 new quests")
		assert(view.wait.Text=="Miss a day, lose nothing.")
		for _,item in ipairs(view.root:GetDescendants())do
			assert(item.ClassName~="TextButton"and item.ClassName~="ImageButton","never a button")
		end
		assert(view.root.Selectable==false and view.root.Active==false)
		view:set(Strip.model(ctx(0)),800)
		assert(view.chips[1].frame.BackgroundColor3==Strip.Color.stars and view:texts().nest==UICopy.get("onb3.nest.ready"),"ready: gold")
		assert(view.chips[2].text.AutoLocalize==true)
		view:set(nil,800);assert(view.root.Visible==false)
		assert(view:enter(1,false)==false,"hidden: no entrance")
		view:destroy();assert(#host:GetChildren()==0)
		local phone=Strip.new(host,{measure=measure,phone=true,short=true})
		phone:set(Strip.model(ctx(3600)),300)
		assert(phone:texts().stamp=="4"and phone.chips[2].text.AutoLocalize==false,"a number is never sent for translation")
		assert(phone.moon~=nil and phone.tab==nil and phone.wait==nil,"v2: no tab over the edge")
		phone:set(Strip.model(ctx(3600)),200);assert(phone.root.Visible==false,"too narrow: not drawn")
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
