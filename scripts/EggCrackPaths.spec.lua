-- Onboarding v2 step 3, beta (36): the first Bear's egg cracks in 3D, on the shell (Spencer: "not a 2d texture ...
-- shrinkwrapped to the 3d egg mesh"). The crack is data (EggCrackPaths), drawn by EggCrack3D: every segment lies on
-- the shell, three stages grow from the tap, stage 2 forks and leaks light, stage 3 rings the whole egg at the shells'
-- seam; the same seed cracks the same way; a tap lands where it was made.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.EggCrackPaths)(PlayerScripts.Client)
return function(client)
	local Paths=require(client.EggCrackPaths)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local S=Paths.Shape
	-- On the shell: the ellipsoid's equation is 1 at a surface point.
	local function onShell(p)
		local ry=if p.Y>=S.y0 then S.top else S.bottom
		local e=(p.X*p.X+p.Z*p.Z)/(S.rx*S.rx)+((p.Y-S.y0)/ry)^2
		return math.abs(e-1)<1e-6
	end

	test("every point and segment middle lies on the shell, its normal points out, its direction along the shell",function()
		for seed=1,10 do
			for _,seg in ipairs(Paths.build(nil,seed))do
				for _,end_ in ipairs({seg.a,seg.b})do assert(onShell(Paths.point(end_[1],end_[2])),"an end off the shell")end
				local mid,along,normal,length=Paths.segment(seg)
				assert(length>0 and length<.5,"a short segment: "..length)
				local centre=Vector3.new(0,S.y0,0)
				assert((mid-centre):Dot(normal)>0,"the normal points out")
				assert(math.abs(along:Dot(normal))<1e-6 and math.abs(along.Magnitude-1)<1e-6,"along the shell")
			end
		end
	end)
	test("three stages: a crack from the tap, a longer run with forks and a light leak, then a ring all round at the seam",function()
		local list=Paths.build({math.pi,S.seamV},3)
		local one,two,three=Paths.stage(list,1),Paths.stage(list,2),Paths.stage(list,3)
		assert(#one>=Paths.Teeth.stage1*2 and #two>#one and #three>=Paths.Teeth.ring,"each stage more")
		local leaks,forks=0,0
		for _,seg in ipairs(two)do if seg.leak then leaks+=1 else forks+=1 end end
		assert(leaks>=Paths.Teeth.stage2*2 and forks>=2,"stage 2 leaks light along its runs and forks")
		for _,seg in ipairs(list)do assert(seg.order>=0 and seg.order<=1 and seg.width==Paths.Width[seg.stage])end
		-- the ring goes all the way round, at the seam
		local from,to=math.huge,-math.huge
		for _,seg in ipairs(three)do
			from=math.min(from,seg.a[1],seg.b[1]);to=math.max(to,seg.a[1],seg.b[1])
		end
		assert(to-from>=math.pi*2-1e-6,"a full ring")
		for i=1,Paths.Teeth.ring do assert(math.abs(three[i].b[2]-S.seamV)<=Paths.Teeth.amp+1e-9,"at the seam")end
		-- stage 1 starts at the tap
		assert(one[1].a[1]==math.pi and one[1].a[2]==S.seamV,"from the tap point")
		assert(Paths.Width[3]>Paths.Width[1],"the ring is the thickest")
	end)
	test("seeded: the same seed cracks the same way, another seed differently",function()
		local a,b,c=Paths.build(nil,11),Paths.build(nil,11),Paths.build(nil,12)
		assert(#a==#b)
		for i=1,#a do assert(a[i].b[1]==b[i].b[1]and a[i].b[2]==b[i].b[2])end
		local differs=false
		for i=1,math.min(#a,#c)do if a[i].b[2]~=c[i].b[2]then differs=true end end
		assert(differs,"another seed, another crack")
	end)
	test("a screen tap lands on the shell where it was made: the middle is the front, right is right, high is high",function()
		local mid=Paths.tapPoint(0,0,math.pi)
		assert(mid[1]==math.pi and mid[2]==S.seamV,"the middle: the front, at the seam")
		local right=Paths.tapPoint(.5,0,math.pi)
		-- seen from the camera (on the egg's -Z side, looking +Z) screen right is the egg's -X
		assert(Paths.point(right[1],right[2]).X<0,"right of centre")
		assert(Paths.tapPoint(0,-.6,math.pi)[2]>S.seamV and Paths.tapPoint(0,.6,math.pi)[2]<S.seamV,"higher and lower")
		local edge=Paths.tapPoint(9,9,math.pi)
		assert(edge[2]>=-.45 and math.abs(edge[1]-math.pi)<=math.asin(.95)*.9+1e-9,"clamped to the egg")
		local list=Paths.build(right,5)
		assert(list[1].a[1]==right[1],"the crack starts where the tap landed")
	end)
	return{passed=#cases,cases=cases}
end
