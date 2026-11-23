-- Things to do: which line is due, every gate, the caps, veterans and "once" (ThingsTips, CoachMarks), and the page's rows and
-- layout (ThingsPage). Pure: no instances, no writes.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.ThingsTips)(PlayerScripts.Client)
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Coach=require(Shared.CoachMarks)
	local UICopy=require(Shared.UICopy)
	local Notices=require(client.NoticeCards)
	local Tips=require(client.ThingsTips)
	local Page=require(client.ThingsPage)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function with(base,t)local c=table.clone(base);for k,v in pairs(t or {})do c[k]=v end;return c end
	local GATE={on=true,mode="Room",canRoam=true,idleFor=5,awayFor=0,roomFor=5,windowActive=true,railEmpty=true,parkPending=0,action="idle"}
	local toured=Coach.with(0,"gardenIntro")
	local CTX={mask=toured,seen={},totalWins=1,owned=1,firstEgg=true,dashOn=false,raced=false,playDates=0,returning=false,now=1000,gate=GATE}
	test("the park line: a new player, after the tour and the first egg, who has not been there",function()
		local id,copy=Tips.due(CTX);assert(id=="parkInvite"and copy=="parkInvite")
		assert(Tips.due(with(CTX,{mask=0}))==nil,"not before the tour")
		assert(Tips.due(with(CTX,{firstEgg=false}))==nil,"not before the first egg")
		assert(Tips.due(with(CTX,{owned=0}))==nil,"not before the first pet")
		assert(Tips.due(with(CTX,{mask=Coach.with(toured,"park")}))==nil and Tips.due(with(CTX,{seen={park=true}}))==nil,"not once they have been")
		assert(Tips.due(with(CTX,{totalWins=Coach.VeteranWins}))==nil,"never a veteran")
		assert(Tips.due(with(CTX,{mask=Coach.with(toured,"parkInvite")}))==nil and Tips.due(with(CTX,{seen={parkInvite=true}}))==nil,"once")
	end)
	local DASH=with(CTX,{mask=Coach.with(toured,"park"),dashOn=true})
	test("the race line: after a play date, or at once for a returning player, veterans too; never both, never once raced",function()
		assert(Tips.due(DASH)==nil,"a new player plays in the park first")
		local id,copy=Tips.due(with(DASH,{playDates=1}));assert(id=="dashIntro"and copy=="dashIntro")
		id,copy=Tips.due(with(DASH,{returning=true}));assert(id=="dashIntro"and copy=="dashNew")
		id,copy=Tips.due(with(DASH,{returning=true,totalWins=50,mask=0}));assert(id=="dashIntro"and copy=="dashNew","a veteran from before the tour")
		assert(Tips.due(with(DASH,{returning=true,dashOn=false}))==nil,"only while the race is on")
		assert(Tips.due(with(DASH,{returning=true,raced=true}))==nil)
		assert(Tips.due(with(DASH,{returning=true,mask=Coach.with(DASH.mask,"dashSeen")}))==nil,"raced in another session: the saved mark")
		assert(Tips.due(with(DASH,{returning=true,mask=Coach.with(DASH.mask,"dashIntro")}))==nil,"one bit: the other wording never follows")
		assert(Tips.due(with(DASH,{returning=true,playDates=3,seen={dashIntro=true}}))==nil)
		assert(Tips.returning({coachMask=toured,totalWins=0})and Tips.returning({coachMask=0,totalWins=Coach.VeteranWins})and not Tips.returning({coachMask=0,totalWins=2})and not Tips.returning(nil))
	end)
	local FINDS=with(CTX,{mask=Coach.with(toured,"park"),findsNear=true})
	test("tip 3, the finds line: once ever, the first time a find sparkles near; veterans too; after the park and race lines",function()
		local id,copy=Tips.due(FINDS);assert(id=="findsIntro"and copy=="findsIntro")
		assert(Tips.due(with(FINDS,{findsNear=false}))==nil and Tips.due(with(CTX,{mask=FINDS.mask}))==nil,"only with a find near")
		assert(Tips.due(with(FINDS,{totalWins=50,mask=0}))=="findsIntro","a veteran from before the tour")
		assert(Tips.due(with(FINDS,{mask=Coach.with(FINDS.mask,"findsIntro")}))==nil and Tips.due(with(FINDS,{seen={findsIntro=true}}))==nil,"once")
		assert(Tips.due(with(FINDS,{firstEgg=false}))==nil and Tips.due(with(FINDS,{owned=0}))==nil,"after the first egg, as the others")
		assert(Tips.due(with(FINDS,{shown=2}))==nil and Tips.due(with(FINDS,{shown=1,lastAt=900}))==nil,"the caps")
		assert(Tips.due(with(FINDS,{mask=toured}))=="parkInvite","the park line first")
		assert(Tips.due(with(FINDS,{dashOn=true,returning=true}))=="dashIntro","the race line first")
		for reason,change in pairs({menu={modal=true},race={engaged=true},petting={petting=true},moving={idleFor=.3},rail={railEmpty=false},roam={mode="Board"}})do
			assert(Tips.due(with(FINDS,{gate=with(GATE,change)}))==nil,reason)
		end
		assert(Coach.Gated.findsIntro=="tips")
	end)
	test("every gate holds a line back, and gives its reason",function()
		for reason,change in pairs({off={on=false},roam={canRoam=false},reveal={revealPending=true},menu={modal=true},hatch={hatch=true},card={card=true},tour={tour=true},
			greeting={greeting=true},race={engaged=true},care={care=true},petting={petting=true},purchase={purchase=true},away={awayFor=20},moving={idleFor=.3},
			settling={roomFor=1},rail={railEmpty=false}})do
			assert(Tips.blocked(with(GATE,change))==reason,reason);assert(Tips.due(with(CTX,{gate=with(GATE,change)}))==nil,reason)
		end
		assert(Tips.blocked(with(GATE,{mode="Board"}))=="roam"and Tips.blocked(with(GATE,{windowActive=false}))=="away"and Tips.blocked(nil)=="off")
		assert(Tips.blocked(with(GATE,{parkPending=1}))=="playDate")
		for _,action in ipairs({"parkApproach","parkSwing","parkCheer"})do assert(Tips.blocked(with(GATE,{action=action}))=="playDate",action)end
		assert(Tips.blocked(GATE)==nil)
	end)
	test("a waiting line lets its place on the rail and the settle time go, a shown one walking too; nothing else",function()
		assert(Tips.blocked(with(GATE,{railEmpty=false,roomFor=0}),"queued")==nil and Tips.blocked(with(GATE,{idleFor=0}),"queued")=="moving")
		assert(Tips.blocked(with(GATE,{railEmpty=false,roomFor=0,idleFor=0}),"shown")==nil)
		for reason,change in pairs({roam={mode="Board"},menu={modal=true},race={engaged=true},playDate={action="parkDig"},purchase={purchase=true},off={on=false},away={windowActive=false}})do
			assert(Tips.blocked(with(GATE,change),"shown")==reason and Tips.blocked(with(GATE,change),"queued")==reason,reason)
		end
	end)
	test("caps: two a session, five minutes apart",function()
		assert(Tips.Max==2 and Tips.Gap==300)
		assert(Tips.due(with(CTX,{shown=2}))==nil and Tips.due(with(CTX,{shown=1}))=="parkInvite")
		assert(Tips.due(with(CTX,{shown=1,lastAt=701}))==nil and Tips.due(with(CTX,{shown=1,lastAt=700}))=="parkInvite")
	end)
	test("bits 11 to 14 are appended, fit the saved range and older ones are kept",function()
		assert(Coach.Bits.parkInvite==11 and Coach.Bits.dashIntro==12 and Coach.Bits.dashSeen==13 and Coach.Bits.findsIntro==14)
		local mask=0
		for _,id in ipairs(Coach.Order)do mask=Coach.with(mask,id)end
		assert(Coach.integer(mask)and mask==2^#Coach.Order-1 and #Coach.Order>=15 and Coach.valid({coachMask=mask}),"every bit up to the last appended one")
		assert(not Coach.validId("nope")and Coach.validId("dashSeen")and Coach.validId("findsIntro"))
	end)
	test("lines: a notice with Show me each, short titles, no Stars, nothing left to fill",function()
		for _,id in ipairs({"parkInvite","dashIntro","dashNew","findsIntro"})do
			assert(Notices.go(id).target=="show"and Notices.go(id).text==UICopy.get("things.show"),id)
			local text=Notices.title(id)
			assert(#string.split(text," ")<=4)
			for _,card in ipairs(Notices.cards(id,{pet="Bear"}))do text..=" "..card.line;assert(#card.line<=60,card.line)end
			assert(not string.find(text,"Star",1,true)and not string.find(text,"{",1,true),text)
		end
	end)
	test("rows: what is open now, live counts, and Stars only with the prizes on",function()
		local rows=Page.rows({})
		assert(#rows==1 and rows[1].id=="deck"and rows[1].help==nil)
		rows=Page.rows({park=true,playDate={count=2,target=3}});assert(#rows==2 and rows[2].line==UICopy.get("park.playDate",{count=2,target=3}))
		rows=Page.rows({park=true,playDate={count=9,target=3}});assert(rows[2].line==UICopy.get("park.playDate",{count=3,target=3}))
		rows=Page.rows({park=true});assert(rows[2].line==UICopy.get("park.playDate",{count=0,target=3}))
		local function dash(phase,count,extra)return Page.rows(with({park=true,dash={phase=phase,count=count}},extra))[3]end
		assert(dash("gather",3).line==UICopy.get("things.dash.gather",{count=3})and dash("live").line==UICopy.get("things.dash.live")and dash("idle").line==UICopy.get("things.dash.idle"))
		local saved={paid=2,limit=5}
		assert(dash("idle",0,{saved=saved}).line==UICopy.get("things.dash.idle"),"prizes off")
		assert(dash("idle",0,{saved=saved,prizes=true}).line==UICopy.get("things.dash.prizes",{done=2,total=5}))
		assert(dash("idle",0,{prizes=true}).line==UICopy.get("things.dash.idle"))
		assert(dash("idle",0,{new=true}).new and not dash("idle").new)
		for _,row in ipairs(Page.rows({park=true,playDate={count=1,target=3},dash={phase="idle"},saved=saved}))do assert(not string.find(row.name..row.line..row.button,"Stars",1,true)and not string.find(row.line,"★",1,true),row.id)end
	end)
	test("the finds row: only with finds on, before the race (which stays last), and how many wait",function()
		local function ids(rows)local out={};for _,row in ipairs(rows)do table.insert(out,row.id)end;return table.concat(out,",")end
		assert(ids(Page.rows({park=true,dash={phase="idle"}}))=="deck,park,dash","off: no row")
		local rows=Page.rows({park=true,finds={waiting=2,count=3,limit=12},dash={phase="idle"},new=true})
		assert(ids(rows)=="deck,park,finds,dash"and rows[#rows].id=="dash"and rows[#rows].new,"before the race")
		assert(ids(Page.rows({finds={waiting=0}}))=="deck,finds")
		local function line(finds)return Page.rows({finds=finds})[2].line end
		assert(line({waiting=2,count=3,limit=12})==UICopy.get("things.finds.waiting",{count=2}))
		assert(line({waiting=1,count=0,limit=12})==UICopy.get("things.finds.one"))
		assert(line({waiting=0,count=5,limit=12})==UICopy.get("things.finds.later")and line({waiting=0})==UICopy.get("things.finds.later"))
		assert(line({waiting=0,count=12,limit=12})==UICopy.get("things.finds.done")and line({waiting=0,count=13,limit=12})==UICopy.get("things.finds.done"))
		assert(line({waiting="junk",count={},limit=nil})==UICopy.get("things.finds.later"),"junk reads as nothing waiting")
		local finds=Page.rows({finds={waiting=3}})[2]
		assert(finds.button==UICopy.get("things.show")and finds.help==nil and finds.name==UICopy.get("things.finds.name"))
		for _,key in ipairs({"things.finds.name","things.finds.waiting","things.finds.one","things.finds.later","things.finds.done","finds.name","finds.gain"})do
			local text=UICopy.get(key,{count=3});assert(text~=key and #text<=60 and not string.find(text,"Star",1,true),key)
		end
	end)
	test("layout: rows and 44 px buttons inside every page, apart from each other",function()
		for _,case in ipairs({{568,250,true},{667,300,true},{844,312,true},{812,294,true},{848,608,false}})do
			for count=1,4 do
				local W,H,phone=case[1],case[2],case[3]
				local L=Page.layout(W,H,phone,count)
				local label=W.."x"..H.." "..count
				local s=L.scroll
				assert(count<=3 and s==nil or count==4,label.." up to three rows never scroll")
				if s then assert(s.y>=(if phone then 64 else 84)and s.y+s.h<=H-(if phone then 20 else 60)and s.canvas>s.h,label.." the window")end
				for i,r in ipairs(L.rows)do
					if s then assert(r.x>=0 and r.x+r.w<=W and r.y>=0 and r.y+r.h<=s.canvas,label.." row in the canvas "..i)
					else assert(r.x>=0 and r.x+r.w<=W and r.y>=(if phone then 64 else 84)and r.y+r.h<=H-(if phone then 20 else 60),label.." row "..i)end
					if i>1 then assert(r.y-(L.rows[i-1].y+L.rows[i-1].h)>=6,label.." gap")end
				end
				local h=L.rows[1].h
				for _,b in ipairs({L.go,L.help})do assert(b.w>=44 and b.h>=44 and b.y>=0 and b.y+b.h<=h and b.x>=0 and b.x+b.w<=L.rows[1].w,label.." button")end
				assert(L.help.x+L.help.w<L.go.x and L.name.x+L.name.w<L.help.x and L.name.w>=140 and L.name.y>=0 and L.line.y+L.line.h<=h,label.." text")
				assert(L.pad+L.disc<L.name.x and L.disc<=h)
			end
		end
	end)
	return{passed=#cases,cases=cases}
end
