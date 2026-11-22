-- Garden Dash switches (V3-DASH-BUILD-PLAN-2026-11-22, S6): the ceiling, the two runtime keys, the spec seam.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.Dash)(ServerScriptService.Server)
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Dash=require(Shared.Dash)
	local Flags=require(Shared.FeatureFlags)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local ON={GardenDash=true}
	local BETA=107705084891479
	local ok,problem=pcall(function()
		test("the ceiling: the flag, and the beta place or Studio; live is never on",function()
			assert(Dash.ceiling({flags=ON,place=BETA,studio=false})and Dash.ceiling({flags=ON,place=1,studio=true}))
			assert(not Dash.ceiling({flags=ON,place=96451847774961,studio=false}))
			for _,flags in ipairs({{},{GardenDash=false},{GardenDash="true"},{GardenDash=1}})do assert(not Dash.ceiling({flags=flags,place=BETA,studio=true}))end
			assert(Flags.GardenDash==true,"the shipped flag (the place and the switch decide)")
		end)
		test("a value: boolean override, then boolean config, then on; nothing beats the ceiling",function()
			for _,case in ipairs({{nil,nil,true},{false,nil,false},{true,nil,true},{"false",nil,true},{0,nil,true},{false,true,true},{true,false,false},{nil,"off",true}})do
				assert(Dash.resolve(case[1],case[2],true)==case[3])
				assert(Dash.resolve(case[1],case[2],false)==false)
			end
		end)
		test("both keys: off until the server's value and the attribute say on; prizes need racing",function()
			Dash.inject({flags=ON,studio=true});assert(Dash.on()and Dash.prizes())
			Dash.inject({flags=ON,studio=true,prizes=false});assert(Dash.on()and not Dash.prizes())
			Dash.inject({flags=ON,studio=true,race=false});assert(not Dash.on()and not Dash.prizes())
			Dash.inject({flags={},studio=true});assert(not Dash.on()and not Dash.prizes())
			Dash.inject(nil)
			local race,prizes=workspace:GetAttribute("Dash_race"),workspace:GetAttribute("Dash_prizes")
			Dash.setSwitch("race",false);workspace:SetAttribute("Dash_race",true);assert(not Dash.switch("race"),"an attribute alone never turns it on")
			Dash.setSwitch("race",true);assert(Dash.switch("race"));workspace:SetAttribute("Dash_race",nil);assert(not Dash.switch("race"))
			assert(not Dash.setSwitch("other",true)and not Dash.switch("prizes"))
			Dash.setSwitch("race",race==true);workspace:SetAttribute("Dash_race",race);workspace:SetAttribute("Dash_prizes",prizes)
		end)
	end)
	Dash.inject(nil)
	assert(ok,problem)
	return{passed=#cases,cases=cases}
end
