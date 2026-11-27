-- Bumble balls, the look's data (GARDEN-B38-BRIEF section 1, Fable; Spencer's beta 37 note 12): the three plain balls'
-- toy patterns from the band and disc system. Felt: pale sky felt, three meridians 60 degrees apart (coral, teal,
-- mustard), cream caps on the poles where they cross, 6 parts. Wicker (Dot): mustard rubber, fourteen cream dots (six
-- .8 on the axes, eight .6 on the corners), five to seven in any view, 15 parts. Cork (Hoop): deep teal rubber, three
-- cream rings round one axis (-.62, 0, .62; .14, .3, .14 wide), coral pole caps, 6 parts. Every surface matte; every
-- disc sits on the surface over its axis; the ids and homes unchanged; no two bodies alike.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.BumbleBallLook)(PlayerScripts.Client)
-- Offline: python scripts/run_dash_server_specs.py
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Balls=require(Shared.BumbleBalls)
	local Look=require(client.BumbleBallLook)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-6)end
	local R=Balls.Radius

	test("the ids, homes and feel unchanged; five kinds, each drawn; the part counts (felt 6, wicker 15, cork 6, patch 7, stripe 5)",function()
		local ids={}
		for _,entry in ipairs(Balls.List or Balls.Places or {})do table.insert(ids,entry.id)end
		if #ids==0 then for id in pairs(Balls.ById)do table.insert(ids,id)end end
		table.sort(ids)
		assert(table.concat(ids,",")=="cork,felt,patch,stripe,wicker","ids "..table.concat(ids,","))
		for _,id in ipairs(ids)do assert(Look.Kinds[id],id.." has a look")end
		assert(Balls.ById.felt.home==Vector2.new(-30,27)and Balls.ById.wicker.home==Vector2.new(42,-11)and Balls.ById.cork.home==Vector2.new(58,30))
		for _,id in ipairs({"felt","wicker","cork"})do assert(Balls.ById[id].feel=="steady",id)end
		local want={felt=6,wicker=15,cork=6,patch=7,stripe=5}
		for id,n in pairs(want)do assert(Look.partCount(id)==n,id.." parts "..Look.partCount(id))end
	end)

	test("matte only: Fabric, Rubber or SmoothPlastic bodies, bands and discs; no Neon, Glass, Metal or Foil; no two bodies the same colour",function()
		local allowed={Fabric=true,Rubber=true,SmoothPlastic=true}
		local bodies={}
		for id,kind in pairs(Look.Kinds)do
			assert(allowed[kind.material],id.." body "..kind.material)
			for _,band in ipairs(kind.bands)do assert(allowed[band.material],id.." band "..band.material)end
			if kind.discs then assert(allowed[kind.discMaterial],id.." disc "..kind.discMaterial)end
			assert(not bodies[kind.color],id.." shares a body colour with "..tostring(bodies[kind.color]))
			bodies[kind.color]=id
		end
		-- Fable B38: the brown family is gone from the old three; felt's body is pale sky, apart from Patch's cream.
		assert(Look.Kinds.felt.color=="#CFE6F2"and Look.Kinds.wicker.color=="#F2C14E"and Look.Kinds.cork.color=="#3E8E86")
	end)

	test("felt: three meridians through both poles, 60 degrees apart, coral, teal and mustard, .9 wide; cream caps on the poles over the band rims",function()
		local kind=Look.Kinds.felt
		assert(#kind.bands==3)
		local colours,normals={}, {}
		for i,band in ipairs(kind.bands)do
			assert(band.offset==0 and near(band.width,.9)and near(band.across,2.42),"band "..i)
			assert(band.material=="Fabric")
			colours[band.color]=true
			-- The disc's axis (local X turned): horizontal, so its rim passes through both poles.
			local axis=(band.turn or CFrame.identity):VectorToWorldSpace(Vector3.xAxis)
			assert(near(axis.Y,0,1e-9),"a meridian")
			table.insert(normals,axis)
		end
		assert(colours["#E8785A"]and colours["#7FB8A4"]and colours["#F2C14E"],"coral, teal, mustard")
		for i=1,3 do
			for j=i+1,3 do
				local angle=math.deg(math.acos(math.clamp(math.abs(normals[i]:Dot(normals[j])),0,1)))
				assert(near(angle,60,1e-3),"60 apart ("..angle..")")
			end
		end
		assert(#kind.discs==2)
		for _,disc in ipairs(kind.discs)do
			assert(math.abs(disc.axis.Y)==1 and disc.color=="#F4E8CF","a cream cap on each pole")
			local f=Look.discFrame(disc.axis,kind.disc.X,kind.proud)
			assert(near(f.Position.Magnitude+kind.disc.X/2,R+kind.proud,1e-9),"proud .04")
			assert(R+kind.proud>kind.bands[1].across/2,"over the band rims")
		end
	end)

	test("wicker (Dot): fourteen cream dots, six .8 on the axes and eight .6 on the corners, on the surface; any view shows five to seven",function()
		local kind=Look.Kinds.wicker
		assert(#kind.bands==0 and #kind.discs==14)
		local axes,corners=0,0
		for _,disc in ipairs(kind.discs)do
			assert(disc.color=="#F4E8CF"and near(disc.axis.Magnitude,1,1e-9))
			local flat=disc.size or kind.disc
			local onAxis=math.abs(math.abs(disc.axis.X)+math.abs(disc.axis.Y)+math.abs(disc.axis.Z)-1)<1e-9
			if onAxis then axes+=1;assert(near(flat.Y,.8),"axis dot .8")
			else corners+=1;assert(near(flat.Y,.6)and near(math.abs(disc.axis.X),1/math.sqrt(3),1e-9),"corner dot .6")end
			local f=Look.discFrame(disc.axis,flat.X,kind.proud)
			assert(near(f.Position.Magnitude+flat.X/2,R+.02,1e-9),"proud .02")
			assert(near(((f*CFrame.new(1,0,0)).Position-f.Position):Dot(disc.axis),1,1e-9),"faces out")
		end
		assert(axes==6 and corners==8)
		-- No two dots overlap (their rims at least a little apart on the surface).
		for i,a in ipairs(kind.discs)do
			for j=i+1,#kind.discs do
				local b=kind.discs[j]
				local arc=math.acos(math.clamp(a.axis:Dot(b.axis),-1,1))*R
				local ra,rb=(a.size or kind.disc).Y/2,(b.size or kind.disc).Y/2
				assert(arc>ra+rb+.1,"dots "..i.." and "..j.." overlap")
			end
		end
		-- Any view: the dots whose middles face the camera within 80 degrees (the ones right on the rim are edge-on).
		local fewest,most,five,views=math.huge,0,0,0
		local random=Random.new(38)
		for _=1,400 do
			local v=Vector3.new(random:NextNumber(-1,1),random:NextNumber(-1,1),random:NextNumber(-1,1))
			if v.Magnitude>.1 then
				v=v.Unit
				local n=0
				for _,disc in ipairs(kind.discs)do if disc.axis:Dot(v)>math.cos(math.rad(80))then n+=1 end end
				fewest,most=math.min(fewest,n),math.max(most,n)
				views+=1
				if n>=5 then five+=1 end
			end
		end
		-- Fable's "five to seven": seven at most, five or more from most angles, never fewer than four.
		assert(fewest>=4 and most<=7 and five/views>=.75,"in view: "..fewest.." to "..most..", five or more "..five.."/"..views)
	end)

	test("cork (Hoop): three cream rings round one axis (-.62, 0, .62; .14, .3, .14), each sized to its section and just proud; coral caps on that axis's poles",function()
		local kind=Look.Kinds.cork
		assert(#kind.bands==3 and #kind.discs==2)
		local want={{-.62,.14},{0,.3},{.62,.14}}
		for i,band in ipairs(kind.bands)do
			assert(near(band.offset,want[i][1])and near(band.width,want[i][2])and band.color=="#F4E8CF"and band.turn==nil,"ring "..i)
			-- Look.build's section maths: the rim a hair over the surface at its offset.
			local d=band.across or 2*math.sqrt(math.max(0,R*R-band.offset*band.offset))+.05
			local rim=Vector2.new(band.offset,d/2).Magnitude
			assert(rim>R and rim<R+.05,"just proud ("..rim..")")
		end
		for _,disc in ipairs(kind.discs)do
			assert(math.abs(disc.axis.X)==1 and disc.color=="#E8785A","a coral cap on each pole of the rings' axis")
			-- Clear of the outer rings.
			local capEdge=math.asin((kind.disc.Y/2)/R)
			local ringAngle=math.acos((.62+.07)/R)
			assert(capEdge<ringAngle,"the cap clears the outer ring")
		end
	end)

	return{passed=#cases,cases=cases}
end
