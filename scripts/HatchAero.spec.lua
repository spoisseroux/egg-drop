-- Aero hatch screens (artifacts/qa-2026-11-26-beta36/AERO-JUICE-BRIEF.md section 3). Pure parts only: the Sky / Meadow /
-- Aurora palettes hex for hex, the rarity still reading apart (CIELAB distance), bright and never the "sad blue-ish" teal
-- Spencer rejected on v850 (saturation and value), WCAG AA text contrast on the plate, headline and stickers, the egg-type
-- accents (no Stars gold), the bubbles' motion (counts, sizes, rise, sway, the pop at the burst, still under Reduced
-- Motion), Rare's ray sweep, the horizon, and the Alive `aerohatch` switch.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.HatchAero)(ServerScriptService.Server)
-- Offline: python scripts/run_dash_server_specs.py
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local A=require(Shared.HatchAero)
	local Alive=require(Shared.Alive)
	local Flags=require(Shared.FeatureFlags)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function hexOf(c)return string.format("#%02X%02X%02X",math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
	-- CIELAB (D65) and the CIE76 distance.
	local function lab(c)
		local function lin(x)return if x<=.04045 then x/12.92 else((x+.055)/1.055)^2.4 end
		local r,g,b=lin(c.R),lin(c.G),lin(c.B)
		local x=(.4124*r+.3576*g+.1805*b)/.95047
		local y=(.2126*r+.7152*g+.0722*b)
		local z=(.0193*r+.1192*g+.9505*b)/1.08883
		local function f(t)return if t>.008856 then t^(1/3)else 7.787*t+16/116 end
		return 116*f(y)-16,500*(f(x)-f(y)),200*(f(y)-f(z))
	end
	local function dE(a,b)
		local l1,a1,b1=lab(a);local l2,a2,b2=lab(b)
		return math.sqrt((l1-l2)^2+(a1-a2)^2+(b1-b2)^2)
	end
	local TIERS={"Common","Uncommon","Rare"}
	local KEYS={"core","edge","ray","floor","deep","back","backDeep"}

	test("the brief's palettes, hex for hex; Neutral is the Common sky; unknown tiers fall back to it",function()
		local want={
			Common={core="#C9F1FF",edge="#2FA8F0",ray="#FFFFFF",floor="#F4FFFF",deep="#0E5FB8",back="#D9F4FF",backDeep="#58B8F2"},
			Uncommon={core="#E4FF9E",edge="#2DBE4E",ray="#F6FFC8",floor="#FBFFDC",deep="#0B7A3A",back="#DFFFB0",backDeep="#2DBE4E"},
			Rare={core="#C4F6FF",edge="#7D5CF0",ray="#FF9AE0",floor="#FFEAF9",deep="#2E1C9A",back="#D9CCFF",backDeep="#5340D8"},
		}
		for tier,row in pairs(want)do
			local p=A.palette(tier)
			for key,hex in pairs(row)do
				assert(p.hex[key]==hex,tier.." "..key.." "..tostring(p.hex[key]))
				assert(hexOf(p[key])==hex,tier.." "..key.." as a colour "..hexOf(p[key]))
			end
		end
		assert(A.palette("Neutral")==A.palette("Common")and A.palette(nil)==A.palette("Common")and A.palette("Mythic")==A.palette("Common"))
		assert(A.palette("Common").name=="Sky"and A.palette("Uncommon").name=="Meadow"and A.palette("Rare").name=="Aurora")
		assert(A.palette("Common").pattern=="bubbles"and A.palette("Uncommon").pattern=="bubbles"and A.palette("Rare").pattern=="diamonds")
		assert(A.palette("Common").spin==0 and A.palette("Uncommon").spin==18 and A.palette("Rare").spin==12,"the brief's ray turns (and the old tiers' own)")
		assert(A.palette("Common").horizon=="grass"and A.palette("Uncommon").horizon=="grass"and A.palette("Rare").horizon=="glass")
		assert(hexOf(A.Grass.top)=="#7BE04A"and hexOf(A.Grass.bottom)=="#2DBE4E"and A.Glint.hex=="#FFE58A"and A.Glint.size==24 and A.Glint.alpha==.30)
		assert(A.Rays.alpha>=.10 and A.Rays.alpha<=.18,"shafts at 10 to 18% alpha")
	end)

	test("rarity reads apart: Common, Uncommon and Rare edges, cores and backdrops 20 or more apart; Rare is the richest",function()
		for i=1,#TIERS do for j=i+1,#TIERS do
			local a,b=A.palette(TIERS[i]),A.palette(TIERS[j])
			for _,key in ipairs({"edge","deep","backDeep","ray"})do
				local d=dE(a[key],b[key])
				assert(d>=20,string.format("%s and %s %s only %.1f apart",TIERS[i],TIERS[j],key,d))
			end
			assert(dE(a.core,b.core)>=8 or dE(a.edge,b.edge)>=40,TIERS[i].." / "..TIERS[j].." cores and edges too close")
		end end
		local C,U,R=A.palette("Common"),A.palette("Uncommon"),A.palette("Rare")
		assert(C.bubbles==6 and U.bubbles==10 and R.bubbles==16,"6, 10 and 16 bubbles")
		assert(U.glints>0 and C.glints==0 and R.sparkles==12 and C.sparkles==0 and U.sparkles==0,"dew glints on Uncommon, twelve sparkles on Rare")
		assert(R.sweep==4 and C.sweep==0 and U.sweep==0,"only Rare sweeps its rays")
	end)

	test("bright and optimistic, never the sad blue-ish teal: saturated edges, luminous cores, no grey teal anywhere",function()
		for _,tier in ipairs(TIERS)do
			local p=A.palette(tier)
			local _,s,v=A.hsv(p.edge)
			assert(s>=.6 and v>=.7,tier.." edge is muted ("..hexOf(p.edge)..")")
			for _,key in ipairs({"core","floor","back","ray"})do
				local _,_,lv=A.hsv(p[key]);assert(lv>=.95,tier.." "..key.." is not luminous")
			end
			for _,key in ipairs(KEYS)do
				local h,ss,vv=A.hsv(p[key])
				local greyTeal=h>=150 and h<=200 and ss>.05 and ss<.45 and vv<.9
				assert(not greyTeal,tier.." "..key.." "..hexOf(p[key]).." is a grey teal")
			end
		end
		local h=A.hsv(A.palette("Common").edge);assert(h>=195 and h<=215,"the Bear's sky is a midday sky blue, not teal ("..h..")")
		local gh,gs,gv=A.hsv(A.Grass.top);assert(gh>=80 and gh<=140 and gs>=.6 and gv>=.75,"glossy grass, not olive")
	end)

	test("WCAG AA text: plate ink on white glass, the headline's white on its deep outline, tag strip, stickers, the headline tag",function()
		local ink=A.Plate.ink;local white=Color3.new(1,1,1)
		-- The plate is white at 85% over anything: the worst case is over black.
		local glassOverBlack=A.over(A.Plate.glass,1-A.Plate.transparency,Color3.new(0,0,0))
		assert(A.contrast(ink,glassOverBlack)>=4.5,string.format("plate ink on glass over black %.2f",A.contrast(ink,glassOverBlack)))
		local stickerInk=Color3.fromHex("#15143A") -- HatchItemStage.Ink
		for _,tier in ipairs(TIERS)do
			local p=A.palette(tier)
			assert(A.contrast(ink,A.over(A.Plate.glass,1-A.Plate.transparency,p.deep))>=4.5,tier.." plate over the deep")
			local c=A.contrast(white,p.deep);assert(c>=4.5,string.format("%s headline white on its deep outline %.2f",tier,c))
			c=A.contrast(p.core,ink);assert(c>=4.5,string.format("%s plate tag text (core) on ink %.2f",tier,c))
			c=A.contrast(p.look,stickerInk);assert(c>=4.5,string.format("%s sticker ink on %s %.2f",tier,hexOf(p.look),c))
			-- The tier rim and the floor light stay light enough for the ink outline round the well to read.
			assert(A.contrast(p.edge,stickerInk)>=3,tier.." well edge against its ink outline")
		end
		assert(A.contrast(ink,white)>=15,"headline tag: ink on white")
	end)

	test("egg-type accents (bubble rims and confetti): the brief's colours, Look Eggs a rainbow, unknown nil, never Stars gold",function()
		local want={companion="#FFE58A",stat="#FF9A5C",toy="#FF6FA8",material="#B9C6FF",feature="#7CF08A",name="#FFFFFF"}
		for kind,hex in pairs(want)do assert(hexOf(A.accent(kind,1))==hex,kind)end
		for _,kind in ipairs({"hue","look","finish","charm"})do
			local seen={}
			for i=1,#A.RainbowHex do seen[hexOf(A.accent(kind,i))]=true end
			local n=0;for _ in pairs(seen)do n+=1 end
			assert(n==#A.RainbowHex and hexOf(A.accent(kind,#A.RainbowHex+1))==hexOf(A.accent(kind,1)),kind.." cycles the rainbow")
		end
		assert(A.accent("medal",1)==nil and A.accent(nil,1)==nil,"an unknown kind keeps the host's accent")
		local gold=hexOf(A.Gold)
		for _,tier in ipairs(TIERS)do
			local p=A.palette(tier)
			for _,key in ipairs(KEYS)do assert(hexOf(p[key])~=gold,tier.." "..key.." is Stars gold")end
			for i=1,24 do
				local c=A.confetti("companion",tier,i);assert(c and hexOf(c)~=gold,"confetti "..i.." is Stars gold")
				assert(dE(c,A.Gold)>=8,"confetti "..i.." reads as gold")
			end
		end
		for _,hex in pairs(A.AccentHex)do assert(hex~=gold)end
	end)

	test("bubbles: 8 to 28 px, rise about 20 px/s with a 6 px sway, pop at the burst, come back from the floor; still when reduced",function()
		local W,H=380,292
		for _,tier in ipairs(TIERS)do
			local n=A.palette(tier).bubbles
			assert(A.bubble(0,n,1,nil,W,H,1,false)==nil and A.bubble(n+1,n,1,nil,W,H,1,false)==nil)
			for i=1,n do
				local x,y,size,alpha,pop=A.bubble(i,n,3.2,nil,W,H,1,false)
				assert(size>=A.Bubble.min and size<=A.Bubble.max,"size "..size)
				assert(x>=-A.Bubble.sway and x<=W+A.Bubble.sway and y>=-size and y<=H+size,"bubble "..i.." off the well")
				assert(alpha==1 and pop==0)
				local x2,y2=A.bubble(i,n,3.2,nil,W,H,1,false);assert(x==x2 and y==y2,"deterministic")
				-- Rise: over a short step it climbs 16 to 24 px/s (unless it wrapped back to the floor).
				local _,ya=A.bubble(i,n,5,nil,W,H,1,false);local _,yb=A.bubble(i,n,5.1,nil,W,H,1,false)
				local speed=(ya-yb)/.1
				assert((speed>=16-1e-6 and speed<=24+1e-6)or yb>ya,"bubble "..i.." rises at "..speed)
				-- The sway never takes it more than 6 px off its column.
				local xs={};for t=0,4,.05 do table.insert(xs,(A.bubble(i,n,t,nil,W,H,1,false)))end
				local lo,hi=math.huge,-math.huge;for _,v in ipairs(xs)do lo=math.min(lo,v);hi=math.max(hi,v)end
				assert(hi-lo<=2*A.Bubble.sway+1e-6,"sway "..(hi-lo))
			end
			-- At the burst every bubble pops where it was (grows, fades), is gone after, then rises from the floor again.
			local burstClock=2
			for i=1,n do
				local _,yPre=A.bubble(i,n,burstClock,-1e-6,W,H,1,false)
				local _,yPop,sPop,aPop,pop=A.bubble(i,n,burstClock+.075,.075,W,H,1,false)
				assert(pop>0 and pop<1 and aPop<1 and sPop>(A.Bubble.min*.99),"bubble "..i.." pops")
				assert(math.abs(yPop-yPre)<1,"it pops where it stood")
				local back=burstClock+A.Bubble.pop+A.Bubble.respawn+.05
				local x,y,_,alpha=A.bubble(i,n,back,back-burstClock,W,H,1,false)
				assert(x~=nil and alpha==1 and y>H*.5,"bubble "..i.." comes back from the floor")
			end
			local gone=0
			for i=1,n do if A.bubble(i,n,burstClock+A.Bubble.pop+.01,A.Bubble.pop+.01,W,H,1,false)==nil then gone+=1 end end
			assert(gone>=1,"the popped bubbles are gone for a moment")
			-- Reduced Motion: the same frame at any time, none pops.
			for i=1,n do
				local x1,y1,s1,a1,p1=A.bubble(i,n,0,nil,W,H,1,true);local x2,y2,s2,a2,p2=A.bubble(i,n,9,.05,W,H,1,true)
				assert(x1==x2 and y1==y2 and s1==s2 and a1==1 and a2==1 and p1==0 and p2==0,"still under Reduced Motion")
				assert(y1-s1/2>=-1e-6 and y1+s1/2<=H+1e-6,"a still bubble sits inside the well")
			end
		end
		local _,_,small=A.bubble(1,6,1,nil,W,H,.5,false);local _,_,big=A.bubble(1,6,1,nil,W,H,1,false)
		assert(math.abs(small*2-big)<1e-6,"sizes follow the stage scale")
	end)

	test("rays: Rare sweeps aqua to pink in 4 s and back, the others hold their colour; Reduced Motion holds; twinkles hold too",function()
		local R=A.palette("Rare")
		assert(hexOf(A.raySweep("Rare",0,false))==R.hex.sweepFrom and hexOf(A.raySweep("Rare",4,false))=="#FF9AE0"and hexOf(A.raySweep("Rare",8,false))==R.hex.sweepFrom)
		local mid=A.raySweep("Rare",2,false);assert(hexOf(mid)~=R.hex.sweepFrom and hexOf(mid)~="#FF9AE0","it moves through the middle")
		assert(A.raySweep("Rare",2,true)==R.ray,"still under Reduced Motion")
		for _,tier in ipairs({"Common","Uncommon","Neutral"})do
			for t=0,6,.5 do assert(A.raySweep(tier,t,false)==A.palette(tier).ray)end
		end
		for i=1,12 do
			assert(A.twinkle(i,1.3,true)==.7 and A.twinkle(i,7,true)==.7)
			local v=A.twinkle(i,1.3,false);assert(v>=0 and v<=1)
		end
		for i=1,12 do local x,y=A.spot("sparkle",i,12);assert(x>=.08 and x<=.92 and y>=.08 and y<=.63,"Rare sparkles sit in the sky")end
		for i=1,5 do local x,y=A.spot("glint",i,5,.75);assert(x>=.12 and x<=.88 and y>.75 and y<.84,"dew sits just under the crest")end
	end)

	test("the horizon: its crest just above the floor (clamped), a gentle dip at the well's sides",function()
		local h=A.horizon(.78,380,292)
		assert(math.abs(h.crest-.755)<1e-9 and math.abs(h.y-.755*292)<1e-6,"the egg stands on the grass")
		assert(A.horizon(.3,380,292).crest==.62 and A.horizon(.99,380,292).crest==.84,"clamped to the bottom third of the well")
		for _,size in ipairs({{380,292},{600,420},{300,500},{1200,560}})do
			local w,hh=size[1],size[2];local z=A.horizon(.8,w,hh)
			assert(z.diameter==A.Grass.diameter*w and z.dip>0 and z.dip<=.09*w,"a gentle arc at "..w.."x"..hh)
			assert(z.shows>0 and z.shows<=1)
		end
	end)

	test("the switch: Alive `aerohatch` with its flag, beta and Studio only, a missing config is on, the attribute decides",function()
		assert(A.Feature=="aerohatch"and table.find(Alive.Features,"aerohatch")~=nil and Flags.AliveAeroHatch==true)
		assert(Alive.attribute("aerohatch")=="Alive_aerohatch"and Alive.key("aerohatch")=="alive_aerohatch")
		assert(Alive.ceiling("aerohatch",{AliveAeroHatch=true},107705084891479,false),"on the beta")
		assert(Alive.ceiling("aerohatch",{AliveAeroHatch=true},96451847774961,true),"in Studio")
		assert(not Alive.ceiling("aerohatch",{AliveAeroHatch=true},96451847774961,false),"never on live")
		assert(not Alive.ceiling("aerohatch",{},107705084891479,true),"not without its flag")
		assert(Alive.resolve("aerohatch",nil,nil,true)==true,"a missing config is on (default on for the beta)")
		assert(Alive.resolve("aerohatch",false,nil,true)==false and Alive.resolve("aerohatch",true,false,true)==false,"config off and the chat override compare the old look")
		local saved=workspace:GetAttribute("Alive_aerohatch")
		workspace:SetAttribute("Alive_aerohatch",nil);local missing=A.on()
		workspace:SetAttribute("Alive_aerohatch",false);local off=A.on()
		workspace:SetAttribute("Alive_aerohatch",true);local on=A.on()
		workspace:SetAttribute("Alive_aerohatch",saved)
		assert(missing==false and off==false,"a missing or false attribute is the old look")
		assert(on==Alive.ceiling("aerohatch"),"a true attribute is the Aero look where the ceiling is open")
	end)

	return {passed=#cases,cases=cases}
end
