-- "Levels matter" switches (V3-LEVELS-BUILD-PLAN-2026-11-22): the ceiling needs the flag and the beta
-- place or Studio; the live place is never on; the runtime switch (LevelsConfig) turns every part off and
-- the server reads its own value, never the attribute; inject is a Studio-only spec seam.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.Levels)(ServerScriptService.Server)
return function(_)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Levels=require(Shared.Levels)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local BETA,LIVE=107705084891479,96451847774961
	local on={LevelsMatter=true}
	local held=Levels.switch()
	local ok,problem=pcall(function()
		test("four parts, the beta place, and a part only counts once its code is in the build",function()
			assert(table.concat(Levels.Parts," ")=="track gates medals juice"and Levels.PlaceId==BETA)
			for _,part in ipairs(Levels.Parts)do assert(type(Levels.Shipped[part])=="boolean",part)end
			assert(table.isfrozen(Levels)and table.isfrozen(Levels.Parts)and table.isfrozen(Levels.Shipped))
		end)
		test("ceiling: flag and (beta place or Studio); never the live place; unknown and unshipped parts are off",function()
			for _,part in ipairs(Levels.Parts)do
				local shipped={[part]=true}
				assert(Levels.ceiling(part,{flags=on,place=BETA,studio=false,shipped=shipped}),part.." on the beta")
				assert(Levels.ceiling(part,{flags=on,place=LIVE,studio=true,shipped=shipped}),part.." in Studio")
				assert(not Levels.ceiling(part,{flags=on,place=LIVE,studio=false,shipped=shipped}),part.." on live")
				assert(not Levels.ceiling(part,{flags={},place=BETA,studio=true,shipped=shipped}),part.." with no flag")
				for _,odd in ipairs({false,"true",1,0})do assert(not Levels.ceiling(part,{flags={LevelsMatter=odd},place=BETA,studio=true,shipped=shipped}))end
				assert(not Levels.ceiling(part,{flags=on,place=BETA,studio=true,shipped={}}),part.." not shipped")
			end
			for _,odd in ipairs({"nope","",1,false})do assert(not Levels.ceiling(odd,{flags=on,place=BETA,studio=true}))end
			assert(not Levels.ceiling(nil,{flags=on,place=BETA,studio=true}))
		end)
		test("inject drives on() and key() until it is cleared; the build's own flag is the default",function()
			local flag=require(Shared.FeatureFlags).LevelsMatter==true
			assert(Levels.inject({flags={},place=BETA,studio=true})and Levels.key()=="0000")
			for _,part in ipairs(Levels.Parts)do assert(Levels.on(part)==false)end
			assert(Levels.inject({flags=on,place=LIVE,studio=true,shipped={track=true,medals=true}}))
			assert(Levels.key()=="1010"and Levels.on("track")and not Levels.on("gates"))
			assert(Levels.inject({flags=on,place=LIVE,studio=false})and Levels.key()=="0000","live stays off with the flag on")
			local env={flags=on,place=BETA,studio=false,shipped={gates=true}}
			Levels.inject(env);env.flags={};assert(Levels.on("gates"),"a copy is kept")
			assert(Levels.inject(nil))
			-- Studio with nothing injected: the build flag and the server's switch.
			for _,value in ipairs({true,false})do
				assert(Levels.setSwitch(value))
				for _,part in ipairs(Levels.Parts)do assert(Levels.on(part)==(flag and value and Levels.Shipped[part]),part)end
			end
		end)
		test("switch: off turns every part off; an injected env is on unless it says so; only a true is on",function()
			local all={track=true,gates=true,medals=true,juice=true}
			Levels.inject({flags=on,place=BETA,studio=true,shipped=all});assert(Levels.key()=="1111")
			Levels.inject({flags=on,place=BETA,studio=true,shipped=all,switch=false});assert(Levels.key()=="0000")
			Levels.inject(nil)
			for _,odd in ipairs({"true",1,{},false})do Levels.setSwitch(odd);assert(Levels.switch()==false)end
			Levels.setSwitch(nil);assert(Levels.switch()==false)
			Levels.setSwitch(true);assert(Levels.switch()==true)
		end)
		test("switch: the server never reads the attribute",function()
			local saved=workspace:GetAttribute(Levels.Attribute)
			Levels.setSwitch(false);workspace:SetAttribute(Levels.Attribute,true)
			local leaked=Levels.switch()or Levels.on("gates")
			workspace:SetAttribute(Levels.Attribute,saved)
			assert(not leaked)
		end)
		test("resolve: ceiling, then override, then config, then on; malformed counts as missing",function()
			assert(Levels.resolve(true,true,false)==false,"the ceiling wins")
			assert(Levels.resolve(true,false,true)==false and Levels.resolve(false,true,true)==true)
			assert(Levels.resolve(false,nil,true)==false and Levels.resolve(nil,nil,true)==true)
			for _,odd in ipairs({"false",0,1,"",{}})do assert(Levels.resolve(odd,odd,true)==true)end
			assert(Levels.Attribute=="Levels_matter"and Levels.Key=="levels_matter")
		end)
		test("allowed: any part's ceiling",function()
			assert(Levels.allowed({flags=on,place=BETA,studio=false,shipped={juice=true}})and not Levels.allowed({flags=on,place=LIVE,studio=false}))
			assert(not Levels.allowed({flags={},place=BETA,studio=true})and not Levels.allowed({flags=on,place=BETA,studio=true,shipped={}}))
		end)
	end)
	Levels.inject(nil);Levels.setSwitch(held)
	assert(ok,problem)
	return{passed=#cases,cases=cases}
end
