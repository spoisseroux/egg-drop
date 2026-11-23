-- Garden Dash camera (DashCamera, slice S7): the rail it rides, the stones, the ends, Reduced Motion, the caps.
-- Usage (Client): require(ZZSpecs.DashCamera)(StarterPlayerScripts.Client)
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Course=require(Shared.DashCourse)
	local Camera=require(client.DashCamera)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function run(stones,reduced)
		local camera=Camera.new()
		local worst,low,frames=0,math.huge,0
		local total=Course.Length-(if stones then Course.Saving else 0)
		local px,pz
		for pos=0,total,13 do -- about 7.8 studs a second at 60 frames
			local cs,on=pos,false
			if stones and pos>=Course.Fork then
				if pos<Course.Fork+Course.StonesLength then cs,on=pos-Course.Fork,true else cs=pos+Course.Saving end
			end
			camera:step(1/60,cs,on,3,stones and pos>=Course.Fork,false,reduced)
			frames+=1
			local _,y=Course.at(cs,on,3)
			low=math.min(low,camera.ey-y)
			if px then worst=math.max(worst,math.sqrt((camera.ex-px)^2+(camera.ez-pz)^2))end
			px,pz=camera.ex,camera.ez
		end
		return worst,low,camera
	end
	test("the whole course, both ways: no jump between frames, always above the pet",function()
		for _,stones in ipairs({false,true})do
			local worst,low=run(stones,false)
			assert(worst<.45,"a frame moves "..worst.." studs");assert(low>4,"height "..low)
		end
	end)
	test("it is behind the pet and looks ahead, also before the start and past the finish",function()
		for _,cs in ipairs({0,500,9000,Course.Length})do
			local camera=Camera.new()
			camera:step(1/60,cs,false,4,false,false,false)
			local x,_,z,yaw=Course.at(cs,false,4)
			local hx,hz=math.sin(yaw),math.cos(yaw)
			local back=(camera.ex-x)*hx+(camera.ez-z)*hz
			local ahead=(camera.lx-x)*hx+(camera.lz-z)*hz
			local far=if cs<800 then cs/100+6 else 14
			assert(back<-.6*far and back> -far-.1,"behind "..back);assert(ahead>1.8,"ahead "..ahead)
			assert(camera.ey>camera.ly+3)
		end
	end)
	test("the rail is one line through the fork and the rejoin",function()
		local x,_,z=Camera.rail(0,true,true,-300,nil)
		local mx,_,mz=Course.at(Course.Fork-300)
		assert(math.abs(x-mx)<.01 and math.abs(z-mz)<.01)
		local bx,_,bz=Camera.rail(Course.Rejoin+100,false,true,-300,nil)
		local wx,_,wz=Course.at(Course.StonesLength-200,true)
		assert(math.abs(bx-wx)<.01 and math.abs(bz-wz)<.01)
		local nx,_,nz=Camera.rail(Course.Rejoin+100,false,false,-300,nil)
		local ox,_,oz=Course.at(Course.Rejoin-200)
		assert(math.abs(nx-ox)<.01 and math.abs(nz-oz)<.01)
	end)
	test("about 14 back, 9 up, 25 degrees down; closer behind the start line, at the same angle",function()
		for _,cs in ipairs({0,300,800,3000,17000})do
			local camera=Camera.new()
			camera:step(1/60,cs,false,4,false,false,false)
			local back=Camera.back(cs,false,false)/100
			assert(back==math.min(14,6+cs/100))
			local pitch=math.deg(math.atan2(Camera.LookHeight+(Camera.EyeHeight-Camera.LookHeight)*(back+2.5)/16.5-Camera.LookHeight,back+2.5))
			assert(math.abs(pitch-25)<.2,pitch)
			local ex,ey=camera.ex,camera.ey
			local _,gy=Camera.rail(cs,false,false,-back*100,4)
			assert(ey-gy<=9.01)
			if cs==0 then assert(ex<79 and ey-gy<5.6,"clear of the cliff behind the start")end
			if back==14 then assert(math.abs(ey-gy-9)<.01)end
		end
		assert(Camera.back(0,true,true)==Camera.Back and Camera.back(Course.Rejoin,false,true)==Camera.Back)
	end)
	test("the pet is always in the middle of the picture: the camera looks at it, not at the avatar",function()
		for cs=0,Course.Length,50 do
			local camera=Camera.new();camera:step(1/60,cs,false,4,false,false,false)
			local x,_,z=Course.at(cs,false,4)
			local fx,fz=camera.lx-camera.ex,camera.lz-camera.ez
			local run=math.sqrt(fx*fx+fz*fz)
			local side=((x-camera.ex)*fz-(z-camera.ez)*fx)/run
			local along=((x-camera.ex)*fx+(z-camera.ez)*fz)/run
			assert(math.abs(side)/along<.3 and along>4,cs)
		end
	end)
	test("a dash widens the view; Reduced Motion never does; a snap never swoops",function()
		local camera=Camera.new()
		for _=1,120 do camera:step(1/60,500,false,1,false,true,false)end
		assert(camera.fov>Camera.DashFov-.5)
		for _=1,120 do camera:step(1/60,500,false,1,false,true,true)end
		assert(camera.fov==Camera.Fov)
		camera:step(1/60,9000,false,1,false,false,true)
		local x=Camera.rail(9000,false,false,-Camera.Back,1)
		assert(camera.ex==x)
		camera:step(0,9000,false,1,false,false,true);camera:step(30,9100,false,1,false,false,true)
		assert(camera.ex==camera.ex)
		camera:reset();assert(not camera.ready and camera.fov==Camera.Fov)
	end)
	test("FABLE-REVIEW-R1 6: the line-up fits the racers present: eight as before, four at .56, never under half",function()
		local Grid=require(Shared.DashGrid)
		local x,y,z=Course.at(0)
		assert(Camera.lineupScale(8)==1 and Camera.lineupScale(nil)==1 and math.abs(Camera.lineupScale(4)-7.5/13.5)<1e-9)
		assert(Camera.lineupScale(1)==.5 and Camera.lineupScale(2)==.5 and Camera.lineupScale(12)==1)
		for _,aspect in ipairs({874/402,16/9,4/3})do
			local e8={Camera.lineup(aspect,8)};local e4={Camera.lineup(aspect,4)};local base={Camera.lineup(aspect)}
			for i=1,6 do assert(e8[i]==base[i],"eight is today's shot")end
			local s=Camera.lineupScale(4)
			assert(math.abs((e4[1]-x)-(e8[1]-x)*s)<1e-6 and math.abs((e4[3]-z)-(e8[3]-z)*s)<1e-6,"back scales")
			assert(math.abs((e4[2]-y-Camera.LookHeight)-(e8[2]-y-Camera.LookHeight)*s)<1e-6,"height scales")
			-- Four racers fill 55 to 65% of the width at their depth.
			local depth=math.sqrt((e4[1]-x)^2+(e4[2]-y-Camera.LookHeight)^2+(e4[3]-z)^2)
			local half=math.tan(math.rad(Camera.Fov)/2)*aspect*depth
			local row=(1.5*Grid.StartStep/100+.6)/half
			assert(row>=.55 and row<=.65,"four racers: "..row)
			print(string.format("line-up row of four at %.2f: %.0f%% of the width",aspect,row*100))
		end
	end)
	test("the line-up shot (beta 12 U5): the whole row of eight in at most 70% of the width, behind the line by no more than the cliff allows",function()
		local Grid=require(Shared.DashGrid)
		local x,y,z,yaw=Course.at(0)
		local fx,fz=math.sin(yaw),math.cos(yaw)
		for _,size in ipairs({{874,402},{667,375},{568,320},{1024,768},{1920,1080}})do
			local aspect=size[1]/size[2]
			local ex,ey,ez,lx,ly,lz=Camera.lineup(aspect)
			local back=-((ex-x)*fx+(ez-z)*fz)
			assert(back>0 and back<=Camera.LineupBack+1e-6,"behind the line, never over the cliff")
			assert(math.abs((ex-x)*fz-(ez-z)*fx)<1e-6,"straight behind the middle")
			assert(ey>y+Camera.LookHeight+2.9 and ey<y+Camera.LookHeight+Camera.LineupHigh+1e-6)
			-- The outer racers' centres plus most of a pet, as a share of the width the eye sees at their depth.
			local depth=math.sqrt((ex-x)^2+(ey-y-Camera.LookHeight)^2+(ez-z)^2)
			local half=math.tan(math.rad(Camera.Fov)/2)*aspect*depth
			local row=(3.5*Grid.StartStep/100+.6)/half
			assert(row<=Camera.RowShare+1e-6,size[1].."x"..size[2]..": "..row)
			assert((Vector3.new(lx,ly,lz)-Vector3.new(x,y+Camera.LookHeight,z)).Magnitude<1.01)
		end
		assert(Camera.lineupBlend(-1,false)==0 and Camera.lineupBlend(0,false)==0 and Camera.lineupBlend(.3,false)>0 and Camera.lineupBlend(.3,false)<1)
		assert(Camera.lineupBlend(.6,false)==1 and Camera.lineupBlend(.01,true)==1 and Camera.lineupBlend(0,true)==0,"Reduced Motion: a cut at GO")
	end)
	return{passed=#cases,cases=cases}
end
