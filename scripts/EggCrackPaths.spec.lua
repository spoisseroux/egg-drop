-- Onboarding v2 step 3: the first Bear's egg cracks in 3D, on the shell (Spencer, beta 36), to Fable's numbers
-- (FABLE-REVIEW-B37 sections 4 to 6). The crack is data (EggCrackPaths), drawn by EggCrack3D:
--   segments 0.06 to 0.15 studs, on the shell, turns within 35 degrees and not a regular zig-zag; 0.035 studs wide at
--   the tap tapering to 0.008; forks at 35 to 60 degrees, 40% of the parent's length, starting at 60% of its width,
--   each with a junction chip; no right-angle spurs; growth outward from the tap; the leak on tap 2; the ring only on
--   tap 3, all the way round; seeded; a tap lands where it was made. The look's numbers are checked too.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.EggCrackPaths)(PlayerScripts.Client)
return function(client)
	local Paths=require(client.EggCrackPaths)
	local Look=require(client.EggCrack3D)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local S,W=Paths.Shape,Paths.Walk
	local function onShell(p)
		local ry=if p.Y>=S.y0 then S.top else S.bottom
		local e=(p.X*p.X+p.Z*p.Z)/(S.rx*S.rx)+((p.Y-S.y0)/ry)^2
		return math.abs(e-1)<1e-6
	end
	local function wrap(a)return((a+math.pi)%(math.pi*2))-math.pi end
	local SEEDS={1,2,3,5,8,13,21,34,55,89}

	test("on the shell: every end on it, every sliver along it and turned out of it",function()
		for _,seed in ipairs(SEEDS)do
			local segs,chips=Paths.build(nil,seed)
			for _,seg in ipairs(segs)do
				for _,e in ipairs({seg.a,seg.b})do assert(onShell(Paths.point(e[1],e[2])),"an end off the shell")end
				local mid,along,normal=Paths.segment(seg)
				assert(onShell(mid),"the sliver's middle on the shell")
				assert((mid-Vector3.new(0,S.y0,0)):Dot(normal)>0,"the normal points out")
				assert(math.abs(along:Dot(normal))<1e-6,"along the shell")
			end
			for _,chip in ipairs(chips)do assert(onShell(Paths.point(chip.at[1],chip.at[2])))end
		end
	end)
	test("segments 0.06 to 0.15 studs; turns within 35 degrees; never a regular zig-zag",function()
		for _,seed in ipairs(SEEDS)do
			local segs=Paths.build(nil,seed)
			local prev={}
			local turns={}
			for _,seg in ipairs(segs)do
				if not seg.join then
					local c=Paths.chord(seg.a,seg.b)
					assert(c<=.15+.01,"at most 0.15 studs: "..c)
					assert(c>=.06-.01 or seg.branch,"at least 0.06 studs: "..c)
				end
				local key=tostring(seg.stage)..":"..tostring(seg.run)..":"..tostring(seg.branch)
				local p=prev[key]
				if p and p.b[1]==seg.a[1]and p.b[2]==seg.a[2]then
					local turn=math.abs(wrap(seg.heading-p.heading))
					assert(turn<=math.rad(35)+.08,"a turn of "..math.deg(turn))
					table.insert(turns,turn)
				end
				prev[key]=seg
			end
			-- not a sawtooth: the turns differ (a regular zig-zag repeats one turn)
			local lo,hi=math.huge,-math.huge
			for _,t in ipairs(turns)do lo=math.min(lo,t);hi=math.max(hi,t)end
			assert(#turns>10 and hi-lo>math.rad(10),"irregular")
		end
	end)
	test("width: 0.035 at the tap tapering to 0.008; forks at 35 to 60 degrees, 40% long, from 60% of the parent's width, a chip each; no spurs",function()
		for _,seed in ipairs(SEEDS)do
			local segs,chips=Paths.build(nil,seed)
			local widest,narrowest=0,1
			local branches={}
			for _,seg in ipairs(segs)do
				widest=math.max(widest,seg.width);narrowest=math.min(narrowest,seg.width)
				assert(seg.width<=W.widthTap+1e-9 and seg.width>=W.widthTip-1e-9,"within 0.035 .. 0.008")
				if seg.branch then
					local a=seg.angle
					assert(a>=W.branchMin-1e-9 and a<=W.branchMax+1e-9,"a fork at "..math.deg(a))
					branches[seg.stage..":"..seg.run]=(branches[seg.stage..":"..seg.run]or 0)+Paths.chord(seg.a,seg.b)
				end
			end
			assert(widest>W.widthTap*.9 and narrowest<=W.widthTip+1e-9,"tapers from the tap to the tips")
			-- the runs from the tap get narrower outward
			local first=segs[1]
			for _,seg in ipairs(segs)do
				if seg.run==first.run and seg.stage==1 and not seg.branch then assert(seg.width<=first.width+1e-9)end
			end
			local n=0
			for key,length in pairs(branches)do
				n+=1
				local stage=tonumber(string.sub(key,1,1))
				local parent=if stage==1 then W.run1 else W.run2
				assert(math.abs(length-parent*W.branchLength)<.05,"40% of the parent: "..length)
			end
			assert(n==4 and #chips==4,"a fork on taps 1 and 2 each way, a chip at each")
			assert(W.branchWidth==.6)
		end
	end)
	test("growth outward from the tap; the leak on tap 2 only; the ring only on tap 3, all the way round",function()
		local segs=Paths.build({math.pi,S.seamV},3)
		local one,two,three=Paths.stage(segs,1),Paths.stage(segs,2),Paths.stage(segs,3)
		assert(#one>0 and #two>0 and #three>0)
		for _,seg in ipairs(segs)do
			assert(seg.order>=0 and seg.order<=1)
			assert((seg.leak==true)==(seg.stage==2 and not seg.branch),"the leak rides tap 2's runs")
			assert((seg.ring==true)==(seg.stage==3),"the ring is tap 3's")
		end
		-- order grows along each run (outward)
		local last={}
		for _,seg in ipairs(segs)do
			if not seg.branch and not seg.join then
				local key=seg.stage..":"..seg.run
				if last[key]then assert(seg.order>=last[key]-1e-9,"outward")end
				last[key]=seg.order
			end
		end
		-- before tap 3 the crack does not go round; after it, it does (the two sides meet at the back)
		local function span(list)
			local covered=0
			for _,seg in ipairs(list)do covered+=math.abs(wrap(seg.b[1]-seg.a[1]))end
			return covered
		end
		assert(span(one)+span(two)<math.pi,"taps 1 and 2: open")
		local join
		for _,seg in ipairs(three)do if seg.join then join=seg end end
		assert(join and Paths.chord(join.a,join.b)<=.2,"the two sides meet at the back: "..(join and string.format("%.3f %.2f,%.2f %.2f,%.2f",Paths.chord(join.a,join.b),join.a[1],join.a[2],join.b[1],join.b[2])or"none"))
		assert(span(one)+span(two)+span(three)>=math.pi*2*.9,"tap 3 rings it")
		assert(one[1].a[1]==math.pi and one[1].a[2]==S.seamV,"from the tap point")
		for _,seed in ipairs(SEEDS)do
			for _,seg in ipairs(Paths.build(Paths.tapPoint((seed%5-2)*.3,(seed%3-1)*.4,math.pi),seed))do
				if seg.join then assert(Paths.chord(seg.a,seg.b)<=.2,"seed "..seed.." meets at the back")end
			end
		end
	end)
	test("seeded; a tap lands where it was made",function()
		local a,b,c=Paths.build(nil,11),Paths.build(nil,11),Paths.build(nil,12)
		assert(#a==#b)
		for i=1,#a do assert(a[i].b[1]==b[i].b[1]and a[i].b[2]==b[i].b[2])end
		local differs=#a~=#c
		for i=1,math.min(#a,#c)do if a[i].b[2]~=c[i].b[2]then differs=true end end
		assert(differs,"another seed, another crack")
		local mid=Paths.tapPoint(0,0,math.pi)
		assert(mid[1]==math.pi and mid[2]==S.seamV)
		local right=Paths.tapPoint(.5,0,math.pi)
		assert(Paths.point(right[1],right[2]).X<0,"right of centre (the egg's -X, seen from the camera)")
		assert(Paths.tapPoint(0,-.6,math.pi)[2]>S.seamV and Paths.tapPoint(0,.6,math.pi)[2]<S.seamV)
		assert(Paths.build(right,5)[1].a[1]==right[1],"the crack starts where the tap landed")
	end)
	test("the look, to Fable's numbers: brown core, a light twin edge, the leak, the chips, the shards",function()
		local function hex(c)return string.format("%02X%02X%02X",math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
		assert(hex(Look.Core)=="4A3524","never black")
		assert(hex(Look.Edge)=="FFFDF0"and Look.EdgeAlpha==.45 and Look.EdgeOffset==.012 and Look.EdgeWidth==.6)
		assert(hex(Look.Leak)=="FFF3C4")
		assert(hex(Look.Chip)=="3A2A1C"and Look.ChipSize==.05)
		assert(Look.Lift==.004 and Look.Grow==.09)
		assert(hex(Look.Outer)=="FBF8DC"and hex(Look.Inner)=="FFFFFF"and hex(Look.Spot)=="2F6BFF")
		local Sh=Look.Shard
		assert(Sh.min==.12 and Sh.max==.35 and Sh.thick==.03 and Sh.shrinkAfter==1.2 and Sh.shrink==.3 and Sh.spotEvery==4)
	end)
	return{passed=#cases,cases=cases}
end
