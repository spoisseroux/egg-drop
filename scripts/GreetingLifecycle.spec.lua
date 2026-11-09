return function(client)
	local Room=require(client.RoomView)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function state(focus)
		return{mode="Room",busy=false,focusing=false,menuOpen=false,pet={},overlayOpen=function()return false end,stationInReach=function()return false end,focusPet=focus}
	end
	test("blocked shot propagates false without spending interaction cooldown",function()
		local value=state(function()return false end)
		assert(not Room.interactPet(value) and value.lastPetAt==nil)
	end)
	test("accepted greeting starts one cooldown and rejects immediate repeat",function()
		local calls=0
		local value=state(function()calls+=1;return true end)
		assert(Room.interactPet(value) and value.lastPetAt)
		assert(not Room.interactPet(value) and calls==1)
	end)
	test("menus and transitions cannot enter a second shot",function()
		for _,key in ipairs({"busy","menuOpen"})do
			local value=state(function()error("must not start another shot")end)
			value[key]=true;assert(not Room.interactPet(value))
		end
	end)
	test("focused greeting delegates reaction without camera recapture or cooldown reset",function()
		local reactions=0
		local value=state(function()error("focused greeting must not recapture camera")end)
		value.focusing,value.lastPetAt=true,123
		value.reactPet=function(_,petting)assert(petting==false);reactions+=1;return true end
		assert(Room.interactPet(value) and Room.interactPet(value) and reactions==2)
		assert(value.focusing and value.lastPetAt==123)
		value.reactPet=function()return false end
		assert(not Room.interactPet(value) and value.lastPetAt==123)
	end)
	return{passed=#cases,cases=cases}
end
