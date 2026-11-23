-- Garden Dash start grid (DashGrid, beta 12 QA U5): 1.5 studs at the line, 0.5 after the funnel, centred on the racers
-- present, odd counts on the slabs at the line, the posts outside everyone. Pure maths.
-- Usage: require(ServerScriptService.Server.ZZSpecs.DashGrid)()
-- Offline: scripts/run_dash_server_specs.py
return function()
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Grid=require(Shared.DashGrid)
	local Course=require(Shared.DashCourse)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b)return math.abs(a-b)<1e-6 end
	local function spread(cs,count)
		local lo,hi=math.huge,-math.huge
		for lane=1,count do
			local o=Grid.offset(cs,false,lane,count)
			lo,hi=math.min(lo,o),math.max(hi,o)
		end
		return lo,hi
	end

	test("eight racers: 1.5 studs apart at the line (10.5 between the outer two), 0.5 once the funnel is done",function()
		local lo,hi=spread(0,8)
		assert(near(hi-lo,1050)and near(lo,-525))
		lo,hi=spread(Grid.FunnelTo,8)
		assert(near(hi-lo,350))
		for lane=1,8 do assert(near(Grid.offset(5000,false,lane,8),Course.laneOffset(lane)),lane)end
	end)
	test("the funnel: still before FunnelFrom, smooth and one way between, still after",function()
		assert(Grid.blend(0,false)==0 and Grid.blend(Grid.FunnelFrom,false)==0 and Grid.blend(Grid.FunnelTo,false)==1 and Grid.blend(-200,false)==0)
		local last=0
		for cs=Grid.FunnelFrom,Grid.FunnelTo,10 do
			local b=Grid.blend(cs,false)
			assert(b>=last and b-last<.03,cs)
			last=b
		end
		assert(Grid.blend(0,true)==1 and Grid.step(0,true)==Grid.RaceStep,"the stones never funnel")
		-- Everyone is on the race lanes before the first hoop can stand.
		local first=math.huge
		for _,layout in pairs(Course.Layouts)do first=math.min(first,layout[1])end
		assert(Grid.FunnelTo<first)
	end)
	test("fewer racers stay centred; two stand side by side in the middle",function()
		for count=1,8 do
			for _,cs in ipairs({Grid.FunnelTo,5000})do
				local lo,hi=spread(cs,count)
				assert(near(lo+hi,0),count)
			end
		end
		assert(near(Grid.offset(0,false,1,2),-75)and near(Grid.offset(0,false,2,2),75))
		assert(Grid.offset(0,false,nil,8)==0)
	end)
	test("an odd count stands on the slabs at the line, half a slot over, and is centred again after the funnel",function()
		local slabs={}
		for lane=1,8 do slabs[Grid.offset(0,false,lane,8)]=true end
		for _,count in ipairs({1,3,5,7})do
			for lane=1,count do
				local o=Grid.offset(0,false,lane,count)
				local on=false
				for at in pairs(slabs)do if near(at,o)then on=true end end
				assert(on,count..":"..lane)
			end
			local lo,hi=spread(Grid.FunnelTo,count)
			assert(near(lo+hi,0))
		end
	end)
	test("at() moves along the course's own normal: lane 1 and lane 8 at 5000 are where DashCourse puts them",function()
		for _,lane in ipairs({1,4,8})do
			local ax,ay,az=Grid.at(5000,false,lane,8)
			local bx,by,bz=Course.at(5000,false,lane)
			assert(math.abs(ax-bx)<1e-6 and ay==by and math.abs(az-bz)<1e-6,lane)
		end
		local cx,_,cz=Course.at(0)
		local ox,_,oz=Grid.at(0,false,8,8)
		assert(math.abs(math.sqrt((ox-cx)^2+(oz-cz)^2)-5.25)<1e-6)
	end)
	test("the posts stand outside the outer racer and most of its pet",function()
		local _,hi=spread(0,8)
		assert(Grid.PostOut-Grid.PostHalf>hi+60)
		assert(near(Grid.halfWidth(0),(Grid.PostOut+Grid.PostHalf)/100)and near(Grid.halfWidth(Grid.FunnelTo),3.5*.5+.6))
	end)
	return{passed=#cases,cases=cases}
end
