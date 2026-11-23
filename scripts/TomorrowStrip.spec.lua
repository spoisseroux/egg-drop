-- The See you tomorrow strip (TomorrowStrip, Onboarding v3 slice E): nothing unless the nest is on and has an egg; the
-- nest clock, tomorrow's stamp and its Stars, and the new quests in the right words; text never truncates (shrink to
-- 11, then the short value); the Dash card makes room for it only when there is one.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.TomorrowStrip)(PlayerScripts.Client); offline in
-- scripts/run_dash_server_specs.py (DASH_SPECS="TomorrowStrip").
return function(client)
	local Nest=require(game:GetService("ReplicatedStorage").Shared.Nest)
	local Strip=require(client.TomorrowStrip)
	local Card=require(client.DashCard)
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
		assert(nest.text=="Ready in 7 h."and nest.short=="7 h"and not nest.gold,nest.text)
		assert(stamp.text=="Stamp 2: 4 Stars"and stamp.short=="4",stamp.text)
		assert(quests.text=="3 new quests"and quests.short=="3"and Strip.Quests==3)
		local soon=Strip.model(ctx(40*60)).chips[1]
		assert(soon.text=="Ready in 40 min."and soon.short=="40 min")
		local ready=Strip.model(ctx(0)).chips[1]
		assert(ready.text=="Ready!"and ready.short=="Ready!"and ready.gold==true)
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
		assert(wide.chips[1].text=="Ready in 7 h."and wide.title.w==Strip.TitleW and wide.h==44)
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
		assert(short.chips[1].text=="7 h"and short.chips[2].text=="4"and short.chips[3].text=="3","a narrow card: short at once")
	end)
	test("phone: three equal columns, the title on a tab, 36 px",function()
		local m=Strip.model(ctx(7*3600))
		local f=Strip.fit(m,600,measure,{phone=true})
		assert(f.h==36 and f.chips[1].w==f.chips[2].w and f.chips[2].w==f.chips[3].w)
		assert(f.chips[1].text=="Ready in 7 h."and f.chips[1].size==12)
		local small=Strip.fit(m,300,measure,{phone=true})
		assert(small.chips[2].text=="4"and small.chips[1].text=="7 h","small: short values")
	end)
	test("the strip draws the texts, is never a button, and hides for nil",function()
		local host=Instance.new("Frame")
		local view=Strip.new(host,{measure=measure,wait=true})
		view:set(Strip.model(ctx(40*60)),800)
		local texts=view:texts()
		assert(texts.title=="See you tomorrow"and texts.nest=="Ready in 40 min."and texts.stamp=="Stamp 2: 4 Stars"and texts.quests=="3 new quests")
		assert(view.wait.Text=="Miss a day, lose nothing.")
		for _,item in ipairs(view.root:GetDescendants())do
			assert(item.ClassName~="TextButton"and item.ClassName~="ImageButton","never a button")
		end
		assert(view.root.Selectable==false and view.root.Active==false)
		view:set(Strip.model(ctx(0)),800)
		assert(view.chips[1].frame.BackgroundColor3==Strip.Color.stars and view:texts().nest=="Ready!","ready: gold")
		assert(view.chips[2].text.AutoLocalize==true)
		view:set(nil,800);assert(view.root.Visible==false)
		assert(view:enter(1,false)==false,"hidden: no entrance")
		view:destroy();assert(#host:GetChildren()==0)
		local phone=Strip.new(host,{measure=measure,phone=true,short=true})
		phone:set(Strip.model(ctx(3600)),200)
		assert(phone:texts().stamp=="4"and phone.chips[2].text.AutoLocalize==false,"a number is never sent for translation")
		assert(phone.tab~=nil and phone.wait==nil)
	end)
	test("enter: refused before set; after it, the tween goes home to where the strip was placed",function()
		local host=Instance.new("Frame")
		local view=Strip.new(host,{measure=measure,phone=true,short=true})
		local before=view.root.Position
		assert(view:enter(1,false)==false and view.home==nil and view.root.Position==before,"before set: nothing moves")
		local placed=UDim2.fromOffset(10,240)
		view.root.Position=placed
		view:set(Strip.model(ctx(3600)),180)
		assert(view:enter(1,false)==true and view.home==placed,"home is the placed spot, not (0, 0)")
		assert(#view.chips==3,"the chips exist when they fade in")
	end)
	test("the Dash card: room for the strip only when there is one",function()
		for _,screen in ipairs({{1280,720},{700,400}})do
			local plain=Card.layout(screen[1],screen[2],{24,24,24},2)
			local with=Card.layout(screen[1],screen[2],{24,24,24},2,true)
			assert(plain.stripY==nil and plain.stripH==0)
			local extra=if with.compact then 42 else 52
			assert(with.buttonY==plain.buttonY+extra and with.stripY==plain.buttonY,"the buttons move down under it")
			assert(with.stripH==(if with.compact then 36 else 44))
		end
	end)
	return{passed=#cases,cases=cases}
end
