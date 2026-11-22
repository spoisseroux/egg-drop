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
			assert(back<-6 and back> -10,"behind "..back);assert(ahead>2.5,"ahead "..ahead)
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
	return{passed=#cases,cases=cases}
end
