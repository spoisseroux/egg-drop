-- The pet screen's carry icons (beta 42 D14): CareIcons' id table and its rules. Pure.
-- Usage (Client): require(<client>.ZZSpecs.CareIcons)(<client>); offline in scripts/run_dash_server_specs.py.
return function(client)
	local Icons=require(client.CareIcons)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end

	test("the four ids are in the table, whole numbers, 0 until uploaded",function()
		for _,name in ipairs({"pickUp","setDown","pickUpWhite","setDownWhite"})do
			local id=Icons.Ids[name]
			assert(type(id)=="number"and id>=0 and id%1==0,name)
		end
		local count=0;for _ in pairs(Icons.Ids)do count+=1 end
		assert(count==4,"only the carry icons")
	end)

	test("an id of 0 (or a missing or odd one) is no image, so the key keeps its arrow; an uploaded id is its asset",function()
		local saved=table.clone(Icons.Ids)
		local ok,err=pcall(function()
			Icons.Ids.pickUp=0;assert(Icons.image("pickUp")==nil)
			assert(Icons.image("nothing")==nil)
			Icons.Ids.pickUp=-4;assert(Icons.image("pickUp")==nil)
			Icons.Ids.pickUp=1.5;assert(Icons.image("pickUp")==nil)
			Icons.Ids.pickUp="123";assert(Icons.image("pickUp")==nil)
			Icons.Ids.pickUp=97429349017697;assert(Icons.image("pickUp")=="rbxassetid://97429349017697")
		end)
		for k,v in pairs(saved)do Icons.Ids[k]=v end
		assert(ok,err)
	end)

	test("Pick up shows pickUp, Set down shows setDown, at 30 px",function()
		assert(Icons.nameFor(true)=="pickUp"and Icons.nameFor(false)=="setDown"and Icons.Size==30)
	end)

	return{passed=#cases,cases=cases}
end
