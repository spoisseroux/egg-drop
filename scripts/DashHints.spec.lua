-- Garden Dash first-race helper (DashHints): three hints at most, gone after one clean jump, never a hint that trips.
-- Usage (Client): require(ZZSpecs.DashHints)(StarterPlayerScripts.Client)
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Stats=require(Shared.DashStats)
	local Sim=require(Shared.DashSim)
	local Hints=require(client.DashHints)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local DT=1/60
	local function race(hints,from,to,jump,dashing)
		local seen={}
		for ticks=from,to,-5/3 do
			local hint=hints:step(DT,true,ticks,jump,dashing==true,nil)
			if hint then seen[hint]=(seen[hint]or 0)+1 end
		end
		return seen
	end
	test("Hold Dash on the first straight, Tap Jump now at the hoop",function()
		local hints=Hints.new()
		for _=1,60 do assert(hints:step(DT,false,200,1,false,nil)==nil,"nothing before GO")end
		local seen=race(hints,200,-5,1)
		assert(seen.dash and seen.jump and hints.shown==2)
		assert(hints:step(DT,true,150,2,false,nil)==nil,"no second straight")
	end)
	test("a pet already dashing is not told to",function()
		local hints=Hints.new()
		local seen=race(hints,200,-5,1,true)
		assert(not seen.dash and seen.jump and hints.shown==1)
	end)
	test("gone after one clean jump, at once",function()
		for _,news in ipairs({"perfect","clear"})do
			local hints=Hints.new();race(hints,200,10,1)
			assert(hints:step(DT,true,5,1,false,news)==nil and hints.done)
			assert(next(race(hints,200,-5,2))==nil)
		end
		local hints=Hints.new();race(hints,200,10,1);hints:step(DT,true,5,1,false,"trip");assert(not hints.done)
	end)
	test("three at most in a race of trips",function()
		local hints=Hints.new()
		local total=0
		for jump=1,6 do for _ in pairs(race(hints,200,-5,jump))do total+=1 end end
		assert(total==3 and hints.shown==3 and hints.done)
	end)
	test("a press the moment Tap Jump now appears clears the hoop at every level",function()
		for level=1,99 do assert(Hints.JumpTicks*10/1000<=Stats.clearWindow(level),level)end
		assert(Hints.JumpTicks<Sim.ReachTicks)
	end)
	return{passed=#cases,cases=cases}
end
