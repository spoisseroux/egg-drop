-- Garden Dash screens (DashHud, DashCard, DashResults; slice S7): the pieces fit every phone, the ring, the words.
-- Usage (Client): require(ZZSpecs.DashHud)(StarterPlayerScripts.Client)
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local UICopy=require(Shared.UICopy)
	local Wire=require(Shared.DashWire)
	local Hud=require(client.DashHud)
	local Card=require(client.DashCard)
	local Results=require(client.DashResults)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function apart(a,b)return a.x+a.w<=b.x or b.x+b.w<=a.x or a.y+a.h<=b.y or b.y+b.h<=a.y end
	-- Whole screens and what the Roblox bar and a notch leave of them.
	local SCREENS={{667,375},{667,317},{579,317},{844,390},{844,332},{756,332},{600,360},{600,302},{1280,720},{1920,1080},{1024,768}}
	test("every piece is on screen and none covers another, on every phone",function()
		for _,screen in ipairs(SCREENS)do
			local W,H=screen[1],screen[2]
			local l=Hud.layout(W,H)
			local names={"jump","dash","stones","bar","strip","place","leave"}
			for i,name in ipairs(names)do
				local b=l[name]
				assert(b.x>=0 and b.y>=0 and b.x+b.w<=W and b.y+b.h<=H,name.." at "..W)
				for j=i+1,#names do assert(apart(b,l[names[j]]),name.." and "..names[j].." at "..W.."x"..H)end
			end
			assert(l.jump.w>=96 and l.dash.w>=96 and l.stones.h>=44 and l.leave.w>=44 and l.leave.h>=44,"targets")
			for _,name in ipairs({"jump","dash","stones","bar","word"})do assert(apart(l.hint,l[name]),"hint and "..name.." at "..W)end
			assert(l.hint.y+l.hint.h<=H)
			assert(apart(l.digits,l.strip)and apart(l.digits,l.jump)and apart(l.digits,l.dash),"digits at "..W)
			assert(l.zoneDash.x+l.zoneDash.w<=l.zoneJump.x+1 and l.zoneJump.x+l.zoneJump.w==W,"the halves meet")
			assert(l.zoneJump.x<=l.jump.x and l.zoneDash.w>=l.dash.x+l.dash.w)
		end
	end)
	test("beta 12 U4: the pads' lips on screen, the place pill just left of the strip, the digits high, key caps by input",function()
		for _,screen in ipairs(SCREENS)do
			local W,H=screen[1],screen[2]
			local l=Hud.layout(W,H)
			for _,name in ipairs({"jump","dash"})do assert(l[name].y+l[name].h+Hud.Lip<=H,name.." lip at "..W.."x"..H)end
			assert(l.place.x+l.place.w+8==l.strip.x and l.place.x>=Hud.Margin and l.place.w==Hud.PlaceW and l.place.h==Hud.PlaceH,"place beside the strip at "..W)
			assert(math.abs((l.place.y+l.place.h/2)-(l.strip.y+l.strip.h/2))<=1 and l.strip.h==Hud.StripH)
			assert(apart(l.strip,l.leave)and apart(l.place,l.leave))
			local centre=l.digits.y+l.digits.h/2
			assert(math.abs(centre-H*Hud.DigitsAt)<=1 or l.digits.y==l.strip.y+l.strip.h+6,"digits at 26% at "..W.."x"..H)
			assert(l.digits.y+l.digits.h<=l.word.y,"over the GO word")
			-- The key cap sits over the pad's inner top corner, clear of the bar and the stones key above.
			assert(l.bar.y+l.bar.h<=l.dash.y-Hud.Cap+Hud.CapIn and l.stones.y+l.stones.h<=l.jump.y-Hud.Cap+Hud.CapIn)
		end
		local jump,dash=Hud.capWords(true,false);assert(jump==""and dash=="","no caps on touch")
		jump,dash=Hud.capWords(false,true);assert(jump=="A"and dash=="RT")
		jump,dash=Hud.capWords(false,false);assert(jump=="Space"and dash=="Shift")
	end)
	test("Studio check beta 12: both key caps stay inside the safe area on every screen, clear of every other piece",function()
		for _,screen in ipairs(SCREENS)do
			local W,H=screen[1],screen[2]
			local l=Hud.layout(W,H)
			for _,width in ipairs({Hud.Cap,44,52,64,90})do
				local caps={}
				for _,name in ipairs({"jump","dash"})do
					local b=Hud.capBox(l,name,width);caps[name]=b
					assert(b.x>=Hud.CapEdge and b.y>=0 and b.x+b.w<=W-Hud.CapEdge and b.y+b.h<=H,name.." cap "..width.." on screen at "..W.."x"..H)
					assert(b.h==20,"20 tall")
					assert(not apart(b,l[name]),name.." cap touches its pad")
					for _,other in ipairs({"stones","bar","strip","place","leave","digits"})do
						assert(apart(b,l[other]),name.." cap and "..other.." at "..W.."x"..H)
					end
				end
				assert(apart(caps.jump,caps.dash)and apart(caps.jump,l.dash)and apart(caps.dash,l.jump),"caps apart at "..W)
				-- Dash's cap on its pad's top right; Jump's, by the screen's right edge, on its top left (toward the middle).
				assert(caps.jump.x+caps.jump.w==l.jump.x+Hud.CapIn and caps.dash.x==l.dash.x+l.dash.w-Hud.CapIn)
				assert(Hud.CapText>=11)
			end
		end
	end)
	test("the ring closes on the pad as the hoop comes, and is larger for a first race",function()
		assert(Hud.ring(nil)==nil and Hud.ring(Hud.RingTicks+1)==nil and Hud.ring(-20)==nil)
		assert(Hud.ring(0)==1 and Hud.ring(-5)==1)
		local last=math.huge
		for ticks=Hud.RingTicks,0,-1 do local r=Hud.ring(ticks);assert(r<=last and r>=1);last=r end
		assert(Hud.ring(50,true)>Hud.ring(50,false))
	end)
	test("FABLE-REVIEW-R1 5: the icons are fetched when Dash mounts, every uploaded one, and a failing fetch is quiet",function()
		local Icons=require(client.DashIcons)
		local list=Icons.list()
		assert(#list>=5 and list[1]==Icons.image("dash")and list[2]==Icons.image("jump"))
		local asked
		assert(Icons.preload({PreloadAsync=function(_,ids)asked=ids end})==#list and asked and #asked==#list)
		Icons.preload({PreloadAsync=function()error("offline")end})
	end)
	test("the setters write only what changed, and make nothing",function()
		local writes=0
		local function object()
			return setmetatable({},{__newindex=function(t,k,v)writes+=1;rawset(t,"_"..k,v)end,__index=function(t,k)return rawget(t,"_"..k)end})
		end
		local hud=setmetatable({shown={},dots={object()},digits=object(),ring=object(),fill=object(),place=object(),stones=object(),word=object(),l={pad=96}},Hud)
		rawset(hud.stones,"_Visible",false)
		local function frame(t)
			hud:setDigits(nil);hud:setRing(t);hud:setBar(.5,false);hud:setPlace(2);hud:setDot(1,.25,true);hud:setStones(false);hud:step(.016)
		end
		frame(50);frame(50)
		local before=writes
		for _=1,100 do frame(50)end
		assert(writes==before,"a still frame writes nothing")
		hud:setPlace(1);assert(hud.place._Text==UICopy.get("dash.ordinal.p1"))
		hud:say("Hi");for _=1,60 do hud:step(1/60)end;assert(hud.word._Text=="")
	end)
	test("cards fit: three lines and three buttons on the smallest phone",function()
		for _,screen in ipairs(SCREENS)do
			for _,lines in ipairs({{},{22,22,22},{42,42}})do
				for buttons=2,3 do
					local g=Card.layout(screen[1],screen[2],lines,buttons)
					assert(g.w<=screen[1]-16 and g.h<=screen[2]-8)
					assert(g.buttonY+g.bh<=g.h,"keys inside at "..screen[1].."x"..screen[2])
					assert(g.bw*buttons+g.gap*(buttons-1)+g.pad*2<=g.w and g.bw>=120 and g.bh>=44)
				end
			end
		end
	end)
	test("the gate card lies low: the bottom of every screen, its keys inside, the top line first to stay",function()
		for _,screen in ipairs(SCREENS)do
			for _,lines in ipairs({{},{20,20},{38,38}})do
				local W,H=screen[1],screen[2]
				local g=Card.lowLayout(W,H,lines,3)
				assert(g.w<=W-16 and g.buttonY+g.bh<=g.h and g.bh>=44 and g.bw>=120,W.."x"..H)
				assert(g.bw*3+g.gap*2+g.pad*2<=g.w and #g.lines<=#lines)
				assert(g.h<=math.max(H/3,H*.4),"low at "..W.."x"..H.." "..g.h)
				if H>=600 then assert(#g.lines==#lines and H-g.h-g.low>=H*.64)end
			end
		end
	end)
	test("the words: place, time, best; Stars only once the save has them; no losing screen",function()
		local title,lines=Results.words({place=5,us=41230000,mode="fun"},nil,nil)
		assert(title=="You finished 5th!"and lines[1]=="Time 41.2 s"and lines[2]==""and lines[3]=="")
		local mine={best=39500000,paid=2,limit=5,last={op="b",stars=2}}
		_,lines=Results.words({place=2,us=41230000,mode="fun"},mine,"b")
		assert(lines[2]=="Best 39.5 s"and lines[3]=="","an old receipt is not this race's")
		_,lines=Results.words({place=2,us=41230000,mode="fun"},mine,"a")
		assert(lines[3]=="+2 Stars (2 of 5 today)")
		mine.last.stars=0;_,lines=Results.words({place=2,us=1,mode="fun"},mine,"a");assert(lines[3]=="")
		title,lines=Results.words({trial=true,place=1,us=29900000,medal="gold"},nil,nil)
		assert(title=="29.9 s!"and lines[1]==UICopy.get("dash.medal.gold"))
		title,lines=Results.words({trial=true,place=1},nil,nil)
		assert(title==UICopy.get("dash.result.noTime")and lines[1]~="")
		_,lines=Results.words({place=8},nil,nil);assert(lines[1]==UICopy.get("dash.result.home"))
		for place=1,9 do assert(Results.words({place=place},nil,nil)~="")end
	end)
	test("every word the client can ask for exists and is short",function()
		for _,key in ipairs({"title","prompt","fun","stats","trial","jump","dash","stones","go","perfect","clear","trip","clover","zoom","puff","leave","again","done","newCup","queue"})do
			local text=UICopy.get("dash."..key);assert(text~="dash."..key and #text<=24,key)
		end
		for _,reason in ipairs({"Far","NoPet","NoCharacter","Carried","Busy","Petting","Hatching","Saving","Queued","WrongBand","Full","Off","Error","Empty","Deck","Left","PetChanged","AlreadySeated","Throttled","StalePet","other"})do
			assert(UICopy.has("dash.reason."..reason),reason)
		end
		assert(UICopy.get("dash.hint.jump")=="Tap Jump now!"and UICopy.get("dash.hint.dash")=="Hold Dash!")
		for _,kind in ipairs({"line","modes"})do assert(UICopy.has("dash.gate."..kind))end
		assert(Wire.Modes.fun and Wire.Modes.stats)
	end)
	test("STUDIO-CHECK-R2: a rival home first is ahead at the line; the pill goes when the result is in",function()
		local Client=require(client.DashClient)
		assert(Client.aheadOf(0,0,true)and not Client.aheadOf(0,0,false),"home first is ahead at the tie")
		assert(Client.aheadOf(3,5,false)and not Client.aheadOf(5,3,true)and not Client.aheadOf(5,0,true))
		local function object(props)return props end
		local hud=setmetatable({shown={},place=object({Text="4th",Visible=true}),jump={},dash={},bar={},leave={},ring={},stones={},hint={}},Hud)
		hud.keys=function()end;hud.shown.place=4
		hud:rest(false);assert(hud.place.Visible==true,"home, not yet the result: the pill stays")
		hud:rest(true);assert(hud.place.Visible==false and hud.place.Text=="","the result: the pill goes")
	end)
	return{passed=#cases,cases=cases}
end
