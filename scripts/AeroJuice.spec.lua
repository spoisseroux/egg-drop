-- The Aero Glass palette and the Pocket Deck juice pass (AERO-JUICE-BRIEF 1 and 2). Pure parts only:
--   palette  the five Aero ramps (Smileys, Marbles and Pico8.TierRamps), 20 dE or more between every pair under
--            simulated deuteranopia and protanopia (Machado 2009, severity 1, CIELAB), neighbours 20 apart in full
--            vision, the ramp order, the ink's contrast; every other theme untouched (no rim / spec).
--   shade    AeroShade on each tier at every sub-pixel centre: the glint bar whole and inside the ball, the dot on
--            II to V, the crescent on III to V, none of them under any face pixel, the budget levels, six tones at most.
--   juice    the switch rules (AliveBudget levels, Reduced Motion), the overshoot, hold, beads, combos, praise words,
--            three sound layers at most (body by tier, sparkle never twice running and an octave up past chain 8, the
--            sub), the duck, the land and stretch shapes, the drift, nudges (6 at most), idle bubbles, the drop and land
--            buzz patterns, the rolling counters; off, the layer answers as if it were not there.
-- Usage (Client): require(ZZSpecs.AeroJuice)(StarterPlayerScripts.Client)
-- Offline: scripts/run_dash_server_specs.py
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Themes=require(Shared.BallThemes)
	local Pico8=require(Shared.Pico8)
	local Alive=require(Shared.Alive)
	local Flags=require(Shared.FeatureFlags)
	local Config=require(Shared.BoardConfig)
	local Shade=require(client.AeroShade)
	local Juice=require(client.AeroJuice)
	local Faces=require(client.BallFaces)
	local Haptics=require(client.Haptics)
	local UI=require(client.AeroUI)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end

	-- Colour maths from hex (no engine Color3 maths offline).
	local function rgb(hex)hex=string.gsub(hex,"#","");return tonumber(string.sub(hex,1,2),16)/255,tonumber(string.sub(hex,3,4),16)/255,tonumber(string.sub(hex,5,6),16)/255 end
	local function linear(v)return if v<=.04045 then v/12.92 else((v+.055)/1.055)^2.4 end
	local function lab(r,g,b)
		r,g,b=math.clamp(r,0,1),math.clamp(g,0,1),math.clamp(b,0,1)
		local x,y,z=(r*.4124+g*.3576+b*.1805)/.95047,r*.2126+g*.7152+b*.0722,(r*.0193+g*.1192+b*.9505)/1.08883
		local function f(t)return if t>.008856 then t^(1/3)else 7.787*t+16/116 end
		return 116*f(y)-16,500*(f(x)-f(y)),200*(f(y)-f(z))
	end
	local Machado={
		protan={{.152286,1.052583,-.204868},{.114503,.786281,.099216},{-.003882,-.048116,1.051998}},
		deutan={{.367322,.860646,-.227968},{.280085,.672501,.047413},{-.011820,.042940,.968881}},
		full={{1,0,0},{0,1,0},{0,0,1}},
	}
	local function seen(hex,m)
		local r,g,b=rgb(hex);r,g,b=linear(r),linear(g),linear(b)
		return lab(m[1][1]*r+m[1][2]*g+m[1][3]*b,m[2][1]*r+m[2][2]*g+m[2][3]*b,m[3][1]*r+m[3][2]*g+m[3][3]*b)
	end
	local function dE(a,b,m)local l1,a1,b1=seen(a,m);local l2,a2,b2=seen(b,m);return math.sqrt((l1-l2)^2+(a1-a2)^2+(b1-b2)^2)end
	local function luminance(hex)local r,g,b=rgb(hex);return .2126*linear(r)+.7152*linear(g)+.0722*linear(b)end
	local function contrast(a,b)local x,y=luminance(a),luminance(b);return(math.max(x,y)+.05)/(math.min(x,y)+.05)end

	test("palette: the Aero Glass table, on Smileys and Marbles and in Pico8.TierRamps; other themes untouched",function()
		local expect={{"#22B8F2","#A6ECFF","#0B74D1","#5FE3FF"},{"#FFB52A","#FFEFA3","#EC7A0E","#FFD866"},{"#2FCB5A","#C4FF9A","#0E8F45","#7CF08A"},
			{"#FF6FA8","#FFD3E6","#D8327E","#FFA3C8"},{"#7D5CF0","#D6CBFF","#4426C2","#A893FF"}}
		for tier,row in ipairs(expect)do
			for _,id in ipairs({"smileys","marbles"})do
				local r=Themes.ById[id].ramps[tier]
				assert(r.body==row[1]and r.light==row[2]and r.deep==row[3]and r.rim==row[4]and r.spec=="#FFFFFF",id.." tier "..tier)
			end
			local p=Pico8.TierRamps[tier]
			assert(p.body==row[1]and p.light==row[2]and p.deep==row[3],"Pico8 tier "..tier)
		end
		assert(Themes.Default=="smileys"and Themes.ById.smileys.ink=="#15102B")
		for _,id in ipairs(Themes.Order)do
			if id~="smileys"and id~="marbles"then for tier=1,5 do assert(Themes.ById[id].ramps[tier].rim==nil and Themes.ById[id].ramps[tier].spec==nil,id)end end
		end
	end)
	test("palette: 20 dE or more between every pair under deutan and protan; neighbours 20 apart; ramp order; ink",function()
		local ramps=Themes.Aero
		for i=1,5 do for j=i+1,5 do
			for _,kind in ipairs({"deutan","protan"})do
				local d=dE(ramps[i].body,ramps[j].body,Machado[kind])
				assert(d>=20,kind.." tiers "..i.."/"..j.." only "..string.format("%.1f",d).." dE apart")
			end
		end end
		for tier=2,5 do assert(dE(ramps[tier].body,ramps[tier-1].body,Machado.full)>=20,"neighbours "..tier)end
		local worst=math.huge
		for i=1,5 do for j=i+1,5 do worst=math.min(worst,dE(ramps[i].body,ramps[j].body,Machado.deutan))end end
		assert(worst>30,"blue and violet are far apart for deutans now ("..worst..")")
		for tier,r in ipairs(ramps)do
			assert(luminance(r.deep)<luminance(r.body)and luminance(r.body)<luminance(r.light),"ramp order "..tier)
			local c=contrast("#15102B",r.body)
			assert(c>=(if tier==5 then 4 else 7),"ink on tier "..tier.." "..string.format("%.2f",c))
		end
		-- The old vivid blue and violet failed this gate (the reason for the change).
		assert(dE("#2E8BFF","#A66BFF",Machado.deutan)<10)
	end)

	-- One ball on a canvas exactly as JellyLCD.ballRuns lays it out, with its centre shifted by (fx, fy).
	local function render(tier,fx,fy,twinkle,simple)
		local r=Config.Tiers[tier].radius*64/(Config.Width+.8)
		local size=math.ceil(r*2)+2
		local cx,cy=size/2+fx,size/2+fy
		local tones={tier=tier}
		for role=1,12 do tones[role]=role end
		Shade.setSimple(simple or 0)
		Shade.begin(cx,cy,r,r,twinkle or 0)
		local out={}
		for y=-1,size do for x=-1,size do
			local ux,uy=(x+.5-cx)/r,(y+.5-cy)/r
			local q=ux*ux+uy*uy
			if q<=1 then out[(x-math.round(cx)).."|"..(y-math.round(cy))]=Shade.shade(tones,ux,uy,q)end
		end end
		Shade.setSimple(0)
		return out
	end
	local function count(out,role)local n=0;for _,v in pairs(out)do if v==role then n+=1 end end;return n end
	test("shade: the glint bar whole and inside the ball at every sub-pixel centre; the dot on II to V; twinkle moves it",function()
		for tier=1,5 do
			local g=Shade.Glint[tier]
			for _,fx in ipairs({-.49,-.25,0,.25,.49})do for _,fy in ipairs({-.49,-.25,0,.25,.49})do
				for twinkle=0,1 do
					local out=render(tier,fx,fy,twinkle)
					for dx=0,g[3]-1 do for dy=0,g[4]-1 do
						assert(out[(g[1]+dx+twinkle).."|"..(g[2]+dy)]==Shade.GLINT,"tier "..tier.." bar pixel missing at "..fx..","..fy)
					end end
					if g[5]then assert(out[g[5].."|"..g[6]]==Shade.GLINT,"tier "..tier.." dot")end
					assert(count(out,Shade.GLINT)==g[3]*g[4]+(if g[5]then 1 else 0),"tier "..tier.." glint size")
				end
			end end
			assert((g[5]~=nil)==(tier>=2),"the dot from tier II")
		end
	end)
	test("shade: no glint pixel under any face pixel (every expression, wide eyes too)",function()
		for tier=1,5 do
			local g=Shade.Glint[tier]
			local glint={}
			for twinkle=0,1 do for dx=0,g[3]-1 do for dy=0,g[4]-1 do glint[(g[1]+dx+twinkle).."|"..(g[2]+dy)]=true end end end
			if g[5]then glint[g[5].."|"..g[6]]=true end
			for _,expr in ipairs(Faces.Expressions)do
				for _,p in ipairs(Faces.pixels("smiley",tier,expr,false))do
					assert(not glint[p[1].."|"..p[2]],"tier "..tier.." "..expr.." face covers the glint at "..p[1]..","..p[2])
				end
			end
		end
	end)
	test("shade: three bands, the crescent on III to V only, simpler over budget, six tones at most, no outline",function()
		for tier=1,5 do
			local out=render(tier,0,0,0)
			local tones={}
			for _,v in pairs(out)do tones[v]=true end
			local n=0;for _ in pairs(tones)do n+=1 end
			assert(n<=6,"tier "..tier.." "..n.." tones")
			assert(count(out,Shade.LIGHTMID)>0 and count(out,Shade.BODY)>0 and count(out,Shade.DEEP)>0,"tier "..tier.." bands")
			assert(not tones[1+2]or tier==0,"no `light` outline role in the body (LIGHT is the flash only)")
			assert((count(out,Shade.RIM)>0)==(tier>=3),"tier "..tier.." crescent")
			if tier>=3 then
				assert(count(render(tier,0,0,0,1),Shade.RIM)==0,"level 1 drops the crescent")
				local g=Shade.Glint[tier]
				assert(render(tier,0,0,0,1)[g[5].."|"..g[6]]==Shade.GLINT,"level 1 keeps the dot")
				assert(render(tier,0,0,0,2)[g[5].."|"..g[6]]~=Shade.GLINT,"level 2 drops the dot")
			end
			-- The crescent hugs the lower right; the top band is the top.
			for key,v in pairs(out)do
				if v==Shade.RIM then local x,y=string.match(key,"(-?%d+)|(-?%d+)");assert(tonumber(x)>=0 and tonumber(y)>=0,"crescent at "..key)end
			end
		end
	end)

	test("juice: the switch is Alive deckjuice (beta and Studio only); levels and Reduced Motion",function()
		assert(table.find(Alive.Features,"deckjuice")and Flags.AliveDeckJuice==true)
		assert(Alive.ceiling("deckjuice",{AliveDeckJuice=true},107705084891479,false))
		assert(not Alive.ceiling("deckjuice",{AliveDeckJuice=true},96451847774961,false),"never on the live place")
		for _,f in ipairs(Juice.Features)do assert(Juice.allows(f,0,false),f.." at level 0")end
		for _,f in ipairs({"caustics","bubbles","echo"})do assert(not Juice.allows(f,1,false),f.." off at level 1")end
		assert(Juice.allows("beads",1,false)and Juice.allows("praise",1,false))
		for _,f in ipairs(Juice.Features)do
			assert(Juice.allows(f,2,false)==(f=="body"or f=="overshoot"or f=="haptics"),f.." at level 2")
		end
		for _,f in ipairs({"hold","sweep","caustics","scanline","drift","counters","beads","breath","twinkle","press","glint"})do
			assert(not Juice.allows(f,0,true),f.." under Reduced Motion")
		end
		for _,f in ipairs({"body","sparkle","sub","duck","haptics","tint","pulse","praise","landcue"})do
			assert(Juice.allows(f,0,true),f.." stays under Reduced Motion")
		end
		assert(not Juice.allows("nope",0,false))
	end)
	test("juice: hold, overshoot 1.10 .96 1.02 1.0, beads 6 or 12, combos and praise words; nothing on a clear",function()
		assert(Juice.holdFor(3)==0 and Juice.holdFor(4)==.04 and Juice.holdFor(5)==.04)
		assert(math.abs(Juice.overshoot(0)-1.10)<1e-9 and math.abs(Juice.overshoot(.09)-.96)<1e-9 and math.abs(Juice.overshoot(.17)-1.02)<1e-9)
		assert(Juice.overshoot(.26)==nil and Juice.overshoot(1)==nil)
		local low,high=math.huge,0
		for t=0,.259,.005 do local k=Juice.overshoot(t);low=math.min(low,k);high=math.max(high,k)end
		assert(low>=.96-1e-9 and high<=1.10+1e-9)
		assert(Juice.beadCount(3,false)==6 and Juice.beadCount(5,false)==12 and Juice.beadCount(2,true)==12 and Juice.Beads.max==12)
		for j=1,12 do
			local vx,vy,size=Juice.beadStart(j,12,30,5)
			assert(size>=3 and size<=9)
			local x,y,k,fade=Juice.beadAt(vx,vy,Juice.Beads.life,Juice.Beads.life,600)
			assert(fade>=.99 and k<1,"a bead fades out by its end")
		end
		local c2,c3,c4,c5,c7=Juice.combo(2),Juice.combo(3),Juice.combo(4),Juice.combo(5),Juice.combo(7)
		assert(not c2.tint and c3.tint and not c3.banks and c4.banks and c4.praise==nil and c5.praise=="deck.praise.bubbly"and not c5.sweep and c7.sweep)
		assert(Juice.combo(12).praise=="deck.praise.sky")
		local clear=Juice.combo(9,true)
		assert(not clear.tint and not clear.banks and clear.praise==nil and not clear.sweep,"nothing stacks above a clear")
		assert(Juice.praiseText(5)=="Bubbly!"and Juice.praiseText(6)=="Fizzy!"and Juice.praiseText(7)=="Sparkly!"and Juice.praiseText(8)=="Sky high!"and Juice.praiseText(4)==nil)
	end)
	test("juice: three layers at most; body by tier, sparkle never twice running and an octave up past 8, sub, duck",function()
		for tier=2,5 do for chain=1,10 do for _,cleared in ipairs({false,true})do
			assert(#Juice.layers(tier,chain,cleared)<=3)
		end end end
		assert(#Juice.layers(2,1,false)==1 and #Juice.layers(4,1,false)==2 and #Juice.layers(5,3,false)==3)
		local last=nil
		for tier=2,5 do
			local cue,speed,gain=Juice.bodyPlay(tier,1,.5,.5)
			assert(cue==(if tier<=3 then "merge_bubble"else "merge_jelly"))
			assert(math.abs(speed-Juice.TierPitch[tier])<1e-9 and math.abs(gain-.56)<1e-9)
			if last then assert(speed<last,"pitched down by tier")end;last=speed
		end
		local s1=select(2,Juice.bodyPlay(3,1,0,0));local s2=select(2,Juice.bodyPlay(3,1,1,1))
		assert(s1>=.92*.97-1e-9 and s2<=.92*1.03+1e-9,"speed within 3%")
		local g1,g2=select(3,Juice.bodyPlay(3,1,.5,0)),select(3,Juice.bodyPlay(3,1,.5,1))
		assert(math.abs(20*math.log10(g2/g1)-2)<1e-6,"gain within 1 dB either way")
		local prev=nil
		for i=1,60 do
			local cue,speed=Juice.sparklePlay(3,.5,.5,(i*.37)%1,prev)
			assert(cue~=prev and table.find(Juice.Sparkle,cue),"sparkle repeated")
			prev=cue
		end
		local _,at8=Juice.sparklePlay(8,.5,.5,0,nil);local _,at9=Juice.sparklePlay(9,.5,.5,0,nil)
		assert(math.abs(at8-2)<1e-9 and math.abs(at9-4)<1e-9,"held at the octave, the sparkle an octave up past chain 8")
		assert(Juice.subPlay(3,false,.5,.5)==nil and Juice.subPlay(4,false,.5,.5)=="merge_thump"and Juice.subPlay(2,true,.5,.5)=="merge_thump")
		assert(Juice.ducks(5,false)and Juice.ducks(2,true)and not Juice.ducks(4,false))
	end)
	test("juice: the layer plays layers through the board's audio; off, it plays nothing and answers false",function()
		local plays,layers,ducks={},{},{}
		local audio={play=function(_,cue,speed,gain)table.insert(plays,{cue,speed,gain});return true end,
			playLayer=function(_,cue,speed,gain)table.insert(layers,{cue,speed,gain});return true end,
			duck=function(_,name,seconds,gain)table.insert(ducks,{name,seconds,gain})end}
		local n=0
		local layer=Juice.new({audio=audio,random=function()n+=1;return(n*.618)%1 end})
		Juice.setSwitch(false);layer:refresh(100)
		assert(layer:mergeSound(5,3,1,false,"all")==false and #plays==0 and #layers==0)
		assert(layer:mergeHold(5)==nil,"off: the merge is drawn as before")
		local kx,ky=layer:shape(1,99.99,100);assert(kx==1 and ky==1)
		Juice.setSwitch(true);layer.checkedAt=-math.huge;layer:refresh(101)
		assert(layer:mergeHold(5)==.04 and layer:mergeHold(2)==0)
		assert(layer:mergeSound(5,3,1,false,"body"))
		assert(#plays==1 and plays[1][1]=="merge_jelly"and #layers==1 and layers[1][1]=="merge_thump"and #ducks==1)
		assert(math.abs(ducks[1][3]-10^(-2/20))<1e-9 and ducks[1][2]==.25)
		assert(layer:mergeSound(5,3,1,false,"chain")and #layers==2 and string.find(layers[2][1],"^merge_glass_tick_"))
		assert(layer:mergeSound(2,1,1,false,"chain")and #layers==2,"no sparkle on chain 1")
		layer:bornAt(7,200)
		kx,ky=layer:shape(7,nil,200);assert(math.abs(kx-1.10)<1e-9 and kx==ky)
		kx=layer:shape(7,nil,200.3);assert(kx==1,"the wobble ends")
		kx,ky=layer:shape(8,300,300);assert(ky>1 and kx<1,"a fresh drop stretches along its fall")
		Juice.setSwitch(nil)
	end)
	test("juice: land squash and stretch end, drift wraps, nudges capped at 6, idle bubbles, twinkle spacing",function()
		local sx,sy=Juice.landSquash(0);assert(math.abs(sy-.9)<1e-9 and sx>1)
		assert(Juice.landSquash(.14)==nil and Juice.stretch(.08)==nil)
		local x,y=Juice.stretch(0);assert(math.abs(y-1.06)<1e-9 and x<1)
		for t=0,5,.37 do local p=Juice.drift(t,3);assert(p>=0 and p<1)end
		assert(math.abs(Juice.drift(.5,3)-1)<1e-9 or Juice.drift(.5,3)<1e-9,"6 px/s over 3 px steps: a full step every half second")
		local list={}
		for i=1,10 do list[i]={id=i,x=(i%2==0 and 1 or -1)*.5,y=0,radius=.7}end
		local out=Juice.nudges(list,0,0,1.43,3)
		assert(#out==6,"six at most ("..#out..")")
		for _,o in ipairs(out)do assert(o.id~=3 and o.dir==(if o.id%2==0 then 1 else -1))end
		assert(#Juice.nudges({{id=1,x=20,y=0,radius=1}},0,0,1)==0,"far balls are left alone")
		assert(not Juice.bubbleDue(4,0,-10,0)and Juice.bubbleDue(5,0,-10,0)and not Juice.bubbleDue(6,0,5,0)and not Juice.bubbleDue(9,0,0,3))
		for _,r in ipairs({0,.5,1})do local t=Juice.nextTwinkle(10,r);assert(t>=11.2-1e-9 and t<=12.5+1e-9)end
		assert(math.abs(Juice.pulse(0)-1)<1e-9 and math.abs(Juice.pulse(1/(4*.8))-1.15)<1e-9)
		assert(math.abs(Juice.breath(1.6/4)-1.03)<1e-9)
	end)
	test("juice: faces bump 1 px away for 120 ms; the drop and land buzzes are short, small and below a merge",function()
		local faces=Faces.new()
		faces:nudge(5,-1,10,.12)
		local expr,dx=faces:get(5,10.05);assert(expr=="idle"and dx==-1)
		expr,dx=faces:get(5,10.2);assert(dx==0,"the bump ends")
		faces:nudge(6,1,10,.12);local _,plain=faces:get(6);assert(plain==0,"a reader without a clock never sees the bump")
		local drop,land=Haptics.Patterns.drop,Haptics.Patterns.land
		assert(drop.motor=="Small"and math.abs(drop.on-.012)<1e-9 and drop.peak==.15 and drop.priority==1)
		assert(land.motor=="Small"and math.abs(land.on-.018)<1e-9 and land.peak==.25 and land.priority==2)
		assert(Haptics.Patterns.merge2.priority>land.priority)
		local gate=Haptics.Gate.new()
		assert(gate:try(Haptics.Patterns.merge3,0))
		assert(not gate:try(drop,.01),"a merge still buzzing is never cut by a drop")
	end)
	test("counters: roll up only, ease out to the exact value, 250 ms a change and 600 ms at most",function()
		assert(UI.rolls(10,20)and not UI.rolls(20,10)and not UI.rolls(nil,5)and not UI.rolls(5,5))
		assert(UI.rollValue(100,250,0,.25)==100 and UI.rollValue(100,250,.25,.25)==250 and UI.rollValue(100,250,1,.25)==250)
		local last=100
		for t=0,.25,.01 do local v=UI.rollValue(100,250,t,.25);assert(v>=last and v<=250);last=v end
		assert(UI.rollDuration(0)==.25 and UI.rollDuration(.2)==.45 and UI.rollDuration(.5)==.6 and UI.rollDuration(-1)==.25)
		assert(UI.Press.scale==.94 and UI.Press.top==1.04 and UI.Pop.scale==1.25 and UI.Glint.seconds==.3 and UI.Glint.every==6)
		assert(UI.Glint.alpha>=.9,"a glint is 10% alpha or less")
		assert(UI.CausticsImage==""or string.find(UI.CausticsImage,"^rbxassetid://%d+$"),"an empty slot or an uploaded id")
	end)
	return{passed=#cases,cases=cases}
end
