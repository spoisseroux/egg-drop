-- Island edges (WORLD-PASS-2026-11-22 item 5, slice 1): the ceiling and switch, the hand-written wall top-ups against the
-- places they must keep clear of (live modules: DashCourse, FindSpots, HollowWorldLayout.V7, ParkLayout), the ring and
-- safe-ground helpers, and the host's walls coming up when on and going completely when off.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.IslandBounds)(ServerScriptService.Server)
-- Offline: DASH_SPECS="IslandBounds" python scripts/run_dash_server_specs.py
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Bounds=require(Shared.IslandBounds)
	local Host=require(server.IslandBoundsHost)
	local Course=require(Shared.DashCourse)
	local Spots=require(Shared.FindSpots)
	local V7=require(Shared.HollowWorldLayout).V7
	local Park=require(Shared.ParkLayout)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local CLEAR=3
	local ON={flags={IslandBounds=true},studio=true}

	test("the ceiling needs the flag and the beta place or Studio; the switch resolves like the others",function()
		local Flags={IslandBounds=true}
		assert(Bounds.ceiling({flags=Flags,studio=false,place=Bounds.PlaceId}))
		assert(not Bounds.ceiling({flags=Flags,studio=false,place=96451847774961}))
		assert(Bounds.ceiling({flags=Flags,studio=true,place=1}))
		assert(not Bounds.ceiling({flags={IslandBounds=false},studio=true})and not Bounds.ceiling({flags={},studio=true}))
		assert(Bounds.resolve(nil,nil,true)==true and Bounds.resolve("x",nil,true)==true and Bounds.resolve(false,nil,true)==false)
		assert(Bounds.resolve(false,true,true)==true and Bounds.resolve(true,false,true)==false and Bounds.resolve(true,true,false)==false)
		assert(Bounds.PlaceId==107705084891479 and Bounds.Key=="island_bounds"and Bounds.Attribute=="Bounds_on")
	end)

	test("owner chat: /bounds on|off|clear, nothing else",function()
		local Config=require(server.IslandBoundsConfig)
		local on,off,clear=Config.parse("/bounds on"),Config.parse("  /BOUNDS off "),Config.parse("/bounds clear")
		assert(on.feature=="bounds"and on.value==true and off.value==false and clear.feature=="bounds"and clear.value==nil)
		for _,text in ipairs({"/bounds","/bounds maybe","/todo on","bounds on","/bounds on now",nil,5})do assert(Config.parse(text)==nil)end
	end)

	test("every wall is a thin, tall, finite box with a unique id, and box() puts it on its centre line",function()
		local seen={}
		assert(#Bounds.Walls>0)
		for _,w in ipairs(Bounds.Walls)do
			assert(type(w.id)=="string"and not seen[w.id],w.id);seen[w.id]=true
			for _,v in ipairs({w.x1,w.z1,w.x2,w.z2,w.base,w.top})do assert(type(v)=="number"and v==v and math.abs(v)<1000,w.id)end
			local length=math.sqrt((w.x2-w.x1)^2+(w.z2-w.z1)^2)
			assert(length>=2 and length<=30,w.id)
			assert(w.top-w.base>=17,w.id.." is not 16 studs over its foot")
			assert(w.base>-5 and w.base<8,w.id.." base")
			local cframe,size=Bounds.box(w)
			assert(math.abs(size.X-length)<1e-6 and size.Z==Bounds.Thick and math.abs(size.Y-(w.top-w.base))<1e-6,w.id)
			local at=cframe.Position
			assert(math.abs(at.X-(w.x1+w.x2)/2)<1e-6 and math.abs(at.Z-(w.z1+w.z2)/2)<1e-6 and math.abs(at.Y-(w.base+w.top)/2)<1e-6,w.id)
			-- Local X runs from one end to the other.
			local tip=cframe:PointToWorldSpace(Vector3.new(size.X/2,0,0))
			assert(math.abs(tip.X-w.x2)<1e-4 and math.abs(tip.Z-w.z2)<1e-4,w.id.." is turned the wrong way")
		end
	end)

	test("no wall within 3 studs of the Dash course, a park kerb, a find spot or a station; none inside a park",function()
		local points={}
		local function add(label,x,z)table.insert(points,{label=label,x=x,z=z})end
		for _,list in ipairs({Course.Main,Course.Branch})do
			for k=1,#list,4 do add("dash d="..list[k],list[k+1]/100,list[k+3]/100)end
		end
		add("dash pad",Course.Pad.x/100,Course.Pad.z/100)
		for k,s in ipairs(Spots)do add("find "..k,s.x/100,s.z/100)end
		for id,cf in pairs(V7.Stations)do add("station "..id,cf.Position.X,cf.Position.Z)end
		for id,at in pairs(V7.Rest)do add("rest "..id,at.X,at.Z)end
		for _,site in ipairs(Park.Sites)do
			for k=0,127 do
				local t=k*math.pi/64
				add("kerb "..site.Id,site.Center.X+site.Radius.X*math.cos(t),site.Center.Z+site.Radius.Y*math.sin(t))
			end
		end
		assert(#points>150)
		for _,w in ipairs(Bounds.Walls)do
			for _,p in ipairs(points)do
				local d=Bounds.distance(w,p.x,p.z)
				assert(d>=CLEAR,string.format("%s is %.2f studs from %s",w.id,d,p.label))
			end
			for _,site in ipairs(Park.Sites)do
				for _,e in ipairs({{w.x1,w.z1},{w.x2,w.z2},{(w.x1+w.x2)/2,(w.z1+w.z2)/2}})do
					local u,v=(e[1]-site.Center.X)/site.Radius.X,(e[2]-site.Center.Z)/site.Radius.Y
					assert(u*u+v*v>=1,w.id.." is inside the park "..site.Id)
				end
			end
		end
	end)

	test("the ring: the dais and every station are inside it; a fall or a walk off the ring has left, the rim has not",function()
		assert(#Bounds.Ring==122)
		assert(Bounds.inside(96,66)and Bounds.inside(0,0)and not Bounds.inside(200,0)and not Bounds.inside(0,-150))
		for id,cf in pairs(V7.Stations)do assert(Bounds.inside(cf.Position.X,cf.Position.Z),id)end
		assert(not Bounds.gone(Vector3.new(96,7,66))and not Bounds.gone(Vector3.new(0,40,0)))
		assert(Bounds.gone(Vector3.new(96,Bounds.FallY-.1,66))and not Bounds.gone(Vector3.new(96,Bounds.FallY+.1,66)))
		assert(Bounds.gone(Vector3.new(200,5,0))and Bounds.gone(Vector3.new(0,5,-150)))
		-- Standing against a ring box (on its centre line, or a little past it) is not leaving. The east-most box: nothing
		-- of the ring lies further east, so a point east of it is exactly that far out.
		local r=Bounds.Ring[1]
		for _,p in ipairs(Bounds.Ring)do if p.X>r.X then r=p end end
		assert(Bounds.ringDistance(r.X,r.Y)<1e-6 and not Bounds.gone(Vector3.new(r.X,5,r.Y)))
		assert(not Bounds.gone(Vector3.new(r.X+Bounds.Margin-.5,5,r.Y)))
		assert(Bounds.gone(Vector3.new(r.X+Bounds.Margin+.5,5,r.Y)))
	end)

	test("extra regions (the Hush while open): gone only below the region's fallY inside it; none is the island alone",function()
		local Hush=require(Shared.Hush)
		local R=Hush.BoundsRegions
		local floor=Hush.at(0,60,3)
		assert(Bounds.gone(floor)and Bounds.gone(floor,nil)and Bounds.gone(floor,{}))
		assert(not Bounds.gone(floor,R)and not Bounds.gone(Hush.at(0,60,Hush.FallY-Hush.FloorY+.1),R))
		assert(Bounds.gone(Vector3.new(floor.X,Hush.FallY-.1,floor.Z),R))
		-- The island's own rules are untouched with the regions given.
		for _,p in ipairs({Vector3.new(96,7,66),Vector3.new(200,5,0),Vector3.new(96,Bounds.FallY-.1,66),Vector3.new(0,5,-150)})do
			assert(Bounds.gone(p,R)==Bounds.gone(p),tostring(p))
		end
		assert(Bounds.regionSafe(R,floor)and not Bounds.regionSafe(nil,floor)and not Bounds.regionSafe(R,Vector3.new(56,7,74)))
		assert(not Bounds.regionSafe(R,Hush.at(77,60,3)))
	end)

	test("safe ground: every find spot's lawn is; the dais, the spur, the east mountain and the void are not",function()
		for k,s in ipairs(Spots)do assert(Bounds.safeCell(s.x/100,s.z/100),"find spot "..k)end
		assert(Bounds.safeCell(56,74)and Bounds.safeCell(0,0)and Bounds.safeCell(69,-14))
		assert(not Bounds.safeCell(96,66)) -- the dais is a structure (M)
		assert(not Bounds.safeCell(18,-60)and not Bounds.safeCell(110,0)and not Bounds.safeCell(-80,-80))
		assert(not Bounds.safeCell(500,500)and not Bounds.safeCell(-500,-500))
	end)

	test("the host: nothing with the ceiling off; walls up when on (collide, no query, no touch, invisible); off removes them all",function()
		local function rig()
			local beat={list={}}
			function beat:Connect(fn)table.insert(self.list,fn);return{Disconnect=function()table.clear(self.list)end}end
			local parent=Instance.new("Folder")
			local now=0
			return{beat=beat,parent=parent,clock=function()now+=1;return now end}
		end
		Bounds.inject({flags={IslandBounds=false},studio=true})
		local r=rig()
		assert(Host.mount({boards={},parent=r.parent,heartbeat=r.beat,clock=r.clock})==nil and #r.beat.list==0)
		Bounds.inject(ON)
		local host=Host.mount({boards={},parent=r.parent,heartbeat=r.beat,clock=r.clock})
		assert(host and #r.beat.list==1)
		r.beat.list[1]()
		local folder=r.parent:FindFirstChild(Bounds.Folder)
		assert(folder and #folder:GetChildren()==#Bounds.Walls)
		for _,part in ipairs(folder:GetChildren())do
			assert(part.Anchored==true and part.CanCollide==true and part.CanQuery==false and part.CanTouch==false,part.Name)
			assert(part.Transparency==1 and part.CastShadow==false,part.Name)
		end
		r.beat.list[1]() -- still on: the same folder, not a second one
		assert(#r.parent:GetChildren()==1 and r.parent:FindFirstChild(Bounds.Folder)==folder)
		Bounds.inject({flags={IslandBounds=true},studio=true,on=false})
		r.beat.list[1]()
		assert(#r.parent:GetChildren()==0 and folder.Parent==nil)
		Bounds.inject(ON)
		r.beat.list[1]()
		assert(#r.parent:GetChildren()==1 and #r.parent:FindFirstChild(Bounds.Folder):GetChildren()==#Bounds.Walls)
		Bounds.inject({flags={IslandBounds=true},studio=true,on=false})
		r.beat.list[1]()
		assert(#r.parent:GetChildren()==0)
	end)

	Bounds.inject(nil)
	return{passed=#cases,cases=cases}
end
