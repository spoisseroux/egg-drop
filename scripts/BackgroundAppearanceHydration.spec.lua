-- Actual hydration/profile sources with fresh shared modules and no live store.
return function(server,progressSource,sessionSource)
	assert(type(progressSource)=="string"and type(sessionSource)=="string","Actual profile/session sources required")
	local shared=game.ReplicatedStorage.Shared:Clone();shared.Name="_BackgroundHydrationShared";shared.Parent=server
	local actualRequire=require
	local realGame=game
	local fakeGame={JobId="background-hydration"}
	function fakeGame:GetService(name)if name=="ReplicatedStorage"then return{Shared=shared}end;return realGame:GetService(name)end
	function fakeGame:BindToClose()end
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function factory(source,scriptRef,substitute)
		local module=Instance.new("ModuleScript");module.Name="_BackgroundHydrationFactory"
		module.Source="return function(e) local game,script,task,require,DateTime=e.game,e.script,e.task,e.require,e.DateTime\n"..source.."\nend"
		module.Parent=server;local ok,run=pcall(actualRequire,module);module:Destroy();assert(ok,run)
		return run({game=fakeGame,script=scriptRef,task={spawn=function()end,defer=function()end},
			DateTime={now=function()return{UnixTimestampMillis=1000}end},require=substitute})
	end
	local function fixture(record,state)
		local writes=0
		local store={persistent=false,UpdateAsync=function()writes+=1;error("Hydration must not write")end}
		local progress=factory(progressSource,server.PlayerProgress,function(target)
			if target==server.ProgressStore then return store end;return actualRequire(target)
		end)
		local session=factory(sessionSource,server.SessionProfile,function(target)
			if target==server.PlayerProgress then return progress end;return actualRequire(target)
		end)
		local profile=progress.fromRecord(1,{},false)
		local handle={status="Ready",profileRecord=record,state=state or {inventoryMask=1,totalWins=0,mastery={pip=0},masteryChallenges={}}}
		assert(session.hydrate(profile,handle))
		assert(progress.flushOnce(profile)and writes==0)
		return profile
	end
	test("old background-less profile defaults logically without a write or reward mutation",function()
		local record={theme="ice",sticker="none",sound="Quiet"}
		local state={inventoryMask=1,totalWins=0,mastery={pip=0},masteryChallenges={}}
		local profile=fixture(record,state)
		assert(profile.background=="canopy"and profile.appearanceSaved.background=="canopy"and not next(profile.appearanceFallbacks))
		assert(record.background==nil and state.totalWins==0 and state.mastery.pip==0)
	end)
	test("explicit invalid background has Unknown provenance and cannot prove fallback Saved",function()
		for _,invalid in ipairs({"bogus",false,17})do
			local profile=fixture({theme="ice",sticker="none",background=invalid})
			assert(profile.background=="canopy"and profile.appearanceFallbacks.background=="Unknown")
			assert(profile.appearanceSaved.background==invalid and profile.appearanceSaved.background~="canopy")
		end
	end)
	test("locked persisted choices reconcile effectively while retaining actual stored proof",function()
		local profile=fixture({theme="honey",sticker="lantern",background="lantern"})
		assert(profile.theme=="sherbet"and profile.sticker=="none"and profile.background=="canopy")
		assert(profile.appearanceFallbacks.theme=="Locked"and profile.appearanceFallbacks.sticker=="Locked"and profile.appearanceFallbacks.background=="Locked")
		assert(profile.appearanceSaved.theme=="honey"and profile.appearanceSaved.sticker=="lantern"and profile.appearanceSaved.background=="lantern")
	end)
	test("acquired committed facts retain genuinely earned choices",function()
		local state={inventoryMask=1,totalWins=1,mastery={pip=10},masteryChallenges={}}
		local profile=fixture({theme="copperleaf",sticker="lantern",background="lantern",trials=1},state)
		assert(profile.theme=="copperleaf"and profile.sticker=="lantern"and profile.background=="lantern"and not next(profile.appearanceFallbacks))
		assert(state.totalWins==1 and state.mastery.pip==10)
	end)
	test("legacy rank-I points and finish flag do not fabricate rank-II ornament eligibility",function()
		local state={inventoryMask=1,totalWins=0,mastery={pip=3},masteryChallenges={},masteryLegacyMask=1}
		local profile=fixture({theme="gloaming",sticker="none",background="lantern"},state)
		assert(profile.theme=="gloaming"and profile.background=="canopy"and profile.appearanceFallbacks.background=="Locked")
		assert(state.masteryLegacyMask==1 and state.mastery.pip==3 and state.totalWins==0)
	end)
	shared:Destroy()
	return{passed=#cases,cases=cases,persistentWrites=false,evidence="actual acquired-profile hydration; fresh shared modules; zero writes"}
end
