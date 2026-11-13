-- Studio Client (pure; no Instances). Ball faces (batch 2026-11-13 R1, scope B2-B4):
-- the crude pixel patterns per size and expression, the expression state machine
-- (idle, blink, near, merged, danger, last, sleepy, frozen), the face-only shiver
-- (continuous over the line, rare when calm, at most 6 a tick, none under Reduced
-- Motion) and the Next / Then preview faces.
-- Usage: require(PlayerScripts.Client.ZZSpecs.BallFaces)(PlayerScripts.Client)
return function(client)
	local Faces=require(client.BallFaces)
	local Config=require(game.ReplicatedStorage.Shared.BoardConfig)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function key(px)local parts={};for _,p in ipairs(px)do table.insert(parts,p[1]..","..p[2]..","..p[3])end;table.sort(parts);return table.concat(parts,";")end
	local function calm()return{dangerY=8.6,pressure=0,graceLeft=0,itemsOpen=false,reduced=false}end
	local function ball(id,tier,x,y)return{id=id,tier=tier,x=x,y=y,radius=Config.Tiers[tier].radius}end

	test("patterns: every style, size and expression is a small ink face inside the ball",function()
		for _,style in ipairs({"smiley","happy","dots","sleepy","cat"})do
			for tier=1,5 do
				local r=Config.Tiers[tier].radius*64/(Config.Width+.8)
				for _,expr in ipairs(Faces.Expressions)do
					local px=Faces.pixels(style,tier,expr)
					assert(type(px)=="table"and table.isfrozen(px),style.." "..tier.." "..expr)
					local inside=0
					for _,p in ipairs(px)do
						assert(p[3]=="ink"or p[3]=="glint"or p[3]=="light"or p[3]=="blush","tone "..tostring(p[3]))
						if(p[1]+.5)^2+(p[2]+.5)^2<=(r-.6)^2 then inside+=1 end
					end
					assert(#px==0 or inside/#px>=.8,style.." "..tier.." "..expr.." face spills out of the ball")
					assert(#px<=60,"busiest face stays small: "..#px)
				end
			end
		end
		assert(Faces.pixels("none",3,"idle")==nil,"Marbles draws no face")
	end)
	test("each size has its own resting face, and worried / panic faces differ from it",function()
		local seen={}
		for tier=1,5 do
			local idle=key(Faces.pixels("smiley",tier,"idle"));assert(not seen[idle],"tier "..tier.." repeats a face");seen[idle]=true
			assert(key(Faces.pixels("smiley",tier,"danger"))~=idle and key(Faces.pixels("smiley",tier,"last"))~=idle,"tier "..tier.." danger looks idle")
			assert(key(Faces.pixels("smiley",tier,"blink"))~=idle,"tier "..tier.." blink")
		end
		-- Panic gets a sweat drop from size 2 up.
		local sweat=false;for _,p in ipairs(Faces.pixels("smiley",3,"last"))do if p[3]=="light"then sweat=true end end;assert(sweat)
		-- Gems: two tiny eyes, no mouth at rest.
		local mouth=false;for _,p in ipairs(Faces.pixels("dots",4,"idle"))do if p[2]>0 then mouth=true end end;assert(not mouth,"gems grew a mouth")
	end)
	test("simple faces (span budget): eyes only on the two smallest sizes, unchanged above",function()
		for tier=1,2 do
			local full,lean=Faces.pixels("smiley",tier,"idle"),Faces.pixels("smiley",tier,"idle",true)
			assert(#lean<#full and #lean>0,"tier "..tier.." simple face")
			for _,p in ipairs(lean)do assert(p[2]<=0,"a mouth survived on tier "..tier)end
		end
		-- Larger sizes keep their whole face shape, ink only (no glints, sweat or blush).
		for tier=3,5 do
			local full,lean=Faces.pixels("smiley",tier,"last"),Faces.pixels("smiley",tier,"last",true)
			local inks=0;for _,p in ipairs(full)do if p[3]=="ink"then inks+=1 end end
			assert(#lean==inks,"tier "..tier.." lost ink");for _,p in ipairs(lean)do assert(p[3]=="ink")end
		end
	end)
	test("state machine: idle, near, merged (0.32 s), danger over the line, last second, frozen",function()
		local f=Faces.new();local now=100.05 -- mid-tick times: one update per 0.1 s tick
		local list={ball(1,2,-3,1),ball(2,2,-3+2.2,1),ball(3,4,3,1)}
		f:update(now,list,calm())
		assert(f:get(1)=="near"and f:get(2)=="near","touching same-size balls")
		assert(f:get(3)=="idle"or f:get(3)=="blink")
		f:merged(3,now+.2);f:update(now+.2,list,calm());assert(f:get(3)=="merged")
		f:update(now+.6,list,calm());assert(f:get(3)~="merged","merged face outlived 0.32 s")
		local high={ball(4,1,0,9),ball(5,3,2,2)}
		local mood=calm();mood.pressure=.5
		f:update(now+.7,high,mood);assert(f:get(4)=="danger"and f:get(5)~="danger","only balls over the line worry")
		mood.graceLeft=.6;f:update(now+.8,high,mood);assert(f:get(4)=="last","last second")
		mood.graceLeft=1.6;f:update(now+.9,high,mood);assert(f:get(4)=="danger")
		mood.itemsOpen=true;f:update(now+1,high,mood);assert(f:get(4)=="frozen"and f:get(5)=="frozen","items open")
		-- Updates run once a tick; ids that leave the board are forgotten.
		assert(not f:update(now+1.01,high,mood),"more than one update per tick")
		f:update(now+1.1,{high[2]},calm());assert(f.balls[4]==nil and f.out[4]==nil)
	end)
	test("sleepy after 8 s untouched and calm; blinks come round within 6 s",function()
		local f=Faces.new();local list={ball(9,3,0,1)}
		local blinked=false
		for step=0,90 do f:update(step*.1+.05,list,calm());if f:get(9)=="blink"then blinked=true end end
		assert(blinked,"no blink in 9 s")
		assert(f:get(9)=="sleepy","not sleepy after 9 s calm")
		list[1].x=1;f:update(9.25,list,calm());assert(f:get(9)~="sleepy","moving wakes it")
	end)
	test("shiver: only the face, one pixel; worried balls continuously, at most 6 a tick; none when reduced",function()
		local f=Faces.new();local list={}
		for id=1,10 do table.insert(list,ball(id,1,(id-5)*1.6,9+id*.01))end
		local mood=calm();mood.pressure=1
		local moved,maxCount=0,0
		for step=0,20 do
			f:update(50.05+step*.1,list,mood)
			local count=0
			for id=1,10 do local _,dx=f:get(id);assert(dx==-1 or dx==0 or dx==1);if dx~=0 then count+=1;moved+=1 end end
			assert(count<=Faces.MaxShivering and f.shivering==count,"too many shivering: "..count);maxCount=math.max(maxCount,count)
		end
		assert(moved>0 and maxCount>=1,"worried balls never shivered")
		mood.reduced=true
		for step=21,40 do f:update(50.05+step*.1,list,mood);for id=1,10 do local _,dx=f:get(id);assert(dx==0,"Reduced Motion shiver")end end
		-- Calm balls shiver rarely (once every 2-5 s), never more than two ticks in a row.
		local g=Faces.new();local one={ball(77,2,0,1)};local ticks,run,longest=0,0,0
		for step=0,100 do g:update(200.05+step*.1,one,calm());local _,dx=g:get(77);if dx~=0 then ticks+=1;run+=1;longest=math.max(longest,run)else run=0 end end
		assert(ticks>=2 and ticks<=10 and longest<=2,"calm shiver ticks="..ticks.." longest="..longest)
	end)
	test("Next / Then previews share the faces: blink, worry, panic, frozen; still under Reduced Motion",function()
		local expressions={}
		for step=0,80 do local expr=Faces.preview(1,step*.1,calm());expressions[expr]=true end
		assert(expressions.idle and expressions.blink,"preview never blinked")
		local mood=calm();mood.pressure=1
		assert(Faces.preview(2,10,mood)=="danger");mood.graceLeft=.4;assert(Faces.preview(2,10,mood)=="last")
		mood.itemsOpen=true;assert(Faces.preview(0,10,mood)=="frozen")
		local reduced=calm();reduced.reduced=true
		for step=0,60 do local _,dx=Faces.preview(1,step*.1,reduced);assert(dx==0)end
	end)
	return{passed=#cases,cases=cases}
end
