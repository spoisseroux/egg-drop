-- Real protocol + actual PlayerProgress source, isolated storage and fixed clock.
return function(server,progressSource)
	assert(type(progressSource)=="string","Pass the actual PlayerProgress source")
	local Intent=require(server.AppearanceIntent)
	local realRequire=require
	local shared=game.ReplicatedStorage.Shared:Clone();shared.Name="_BackgroundAppearanceShared";shared.Parent=server
	local freshIntent=server.AppearanceIntent:Clone();freshIntent.Parent=server
	Intent=realRequire(freshIntent);freshIntent:Destroy()
	local Catalog=realRequire(shared.AppearanceCatalog)
	local cases={}
	local function copy(value)
		if type(value)~="table"then return value end
		local result={};for k,v in pairs(value)do result[k]=copy(v)end;return result
	end
	local function test(name,run)run();table.insert(cases,name)end
	local function fixture()
		local f={now=1000,db={theme="sherbet",sticker="none",themeAt=900,themeWriter="old",
			hatching={nectar=37,revision=4},customSibling="preserved"},saved={},writes=0}
		local store={persistent=false}
		function store:UpdateAsync(_,transform)
			f.writes+=1
			if f.before then local hook=f.before;f.before=nil;hook()end
			f.db=transform(copy(f.db))
			if f.after then local hook=f.after;f.after=nil;hook()end
			return copy(f.db)
		end
		local realGame=game
		local fakeGame={JobId="appearance-test-writer"}
		function fakeGame:GetService(name)if name=="ReplicatedStorage"then return{Shared=shared}end;return realGame:GetService(name)end
		function fakeGame:BindToClose()end
		local module=Instance.new("ModuleScript");module.Name="_AppearanceProgressFixture"
		module.Source="return function(e) local game,script,task,require,DateTime=e.game,e.script,e.task,e.require,e.DateTime\n"..progressSource.."\nend"
		module.Parent=server
		local ok,run=pcall(realRequire,module);module:Destroy();assert(ok,run)
		f.api=run({game=fakeGame,script=server.PlayerProgress,task={spawn=function()end,defer=function()end},
			DateTime={now=function()return{UnixTimestampMillis=f.now}end},
			require=function(target)if target==server.ProgressStore then return store end;return realRequire(target)end})
		f.profile=f.api.fromRecord(1,copy(f.db),true);f.state=Intent.new()
		f.facts={rank=0,trials=0,inventoryMask=1,totalWins=0,masteryRanks={pip=0}}
		f.profile.resolveAppearance=function(theme,sticker,background)
			return if Catalog.canEquip("theme",theme,f.facts)then theme else "sherbet",
				if Catalog.canEquip("sticker",sticker,f.facts)then sticker else "none",
				if Catalog.canEquip("background",background,f.facts)then background else "canopy"
		end
		f.profile.onAppearanceSaved=function(candidate)
			for _,result in ipairs(Intent.saved(f.state,f.profile,candidate))do table.insert(f.saved,result)end
		end
		f.superseded={}
		f.profile.onAppearanceSuperseded=function(candidate)
			for _,result in ipairs(Intent.superseded(f.state,f.profile,candidate))do table.insert(f.superseded,result)end
		end
		function f:request(slot,id,seq,time,usable)
			return Intent.request(self.state,self.profile,{slot=slot,id=id,seq=seq},time,usable~=false,
				function(s,v)
					local rule=Catalog.describeRequirement(s,v,self.facts)
					return if rule.rule=="invalid"then "Invalid"elseif rule.unlocked then nil else "Locked"
				end,self.api.equip)
		end
		return f
	end
	-- Stickers are retired, so the second slot in these protocol tests is the background.
	test("rapid cross-slot intents explicitly throttle and same-sequence latest retry preserves both slots",function()
		local f=fixture();f.facts.trials=2
		assert(f:request("theme","brick",1,1).status=="Applied")
		local blocked=f:request("background","creek",1,1.05)
		assert(blocked.reason=="Throttled"and blocked.retryAfter>0 and blocked.lastSeq==0)
		assert(f:request("background","creek",1,1.26).status=="Applied")
		assert(f:request("theme","ice",2,1.52).status=="Applied")
		assert(f.profile.theme=="ice"and f.profile.background=="creek"and f.state.revision==3)
		assert(f.api.flushOnce(f.profile));assert(f.db.theme=="ice"and f.db.background=="creek")
		assert(#f.saved==2 and f.saved[1].status=="Saved"and f.saved[2].status=="Saved")
	end)
	test("duplicate accepted packet replays without reapplying and stale/conflicting packets expose watermark",function()
		local f=fixture();local first=f:request("theme","brick",4,1)
		local candidate=f.profile.appearanceChange
		assert(f:request("theme","brick",4,2)==first and f.profile.appearanceChange==candidate)
		local stale=f:request("theme","ice",3,2);assert(stale.reason=="Stale"and stale.lastSeq==4)
		local conflict=f:request("theme","ice",4,2);assert(conflict.reason=="SeqConflict"and conflict.lastSeq==4)
	end)
	test("no-op loaded selection is durably known without a write",function()
		local f=fixture();assert(f:request("theme","sherbet",1,1).status=="Saved")
		assert(f.state.revision==0 and f.writes==0 and f.profile.appearanceChange==nil)
	end)
	test("no-op pending selection remains Applied until persistence proof",function()
		local f=fixture();f:request("theme","brick",1,1)
		assert(f:request("theme","brick",2,2).status=="Applied")
		assert(f.api.flushOnce(f.profile)and #f.saved==1 and f.saved[1].seq==2)
	end)
	test("locked invalid and unavailable terminal rejects preserve pair and cache their sequence",function()
		local f=fixture()
		for i,entry in ipairs({{"sticker","wick","Invalid"},{"theme","bogus","Invalid"},{"theme","ice","Unavailable"}})do
			local result=f:request(entry[1],entry[2],i,i,entry[3]~="Unavailable")
			assert(result.reason==entry[3]and result.status=="Rejected")
			assert(f:request(entry[1],entry[2],i,i+.5)==result)
		end
		assert(f.profile.theme=="sherbet"and f.profile.sticker=="none"and f.writes==0)
	end)
	test("malformed replies are bounded and closing returns an explicit correlated rejection",function()
		local f=fixture()
		local result=Intent.request(f.state,f.profile,{},1,true,function()end,f.api.equip)
		assert(result.reason=="Malformed")
		assert(Intent.request(f.state,f.profile,{slot="theme",id="brick",seq=math.huge},1.1,true,function()end,f.api.equip)==nil)
		result=Intent.request(f.state,f.profile,{slot="theme",id="brick",seq=1},2,"Closing",function()end,f.api.equip)
		assert(result.reason=="Closing"and result.seq==1)
	end)
	test("same-millisecond A B A during a suspended flush cannot clear or confirm the newer A",function()
		local f=fixture();f:request("theme","brick",1,1)
		local first=f.profile.appearanceChange
		f.before=function()f:request("theme","ice",2,2);f:request("theme","brick",3,3)end
		assert(not f.api.flushOnce(f.profile))
		assert(f.profile.appearanceChange and f.profile.appearanceChange.generation==3 and #f.saved==0)
		assert(f.profile.appearanceChange.at>first.at and f.profile.themeAt~=nil)
		assert(f.api.flushOnce(f.profile)and #f.saved==1 and f.saved[1].seq==3)
	end)
	test("accepted timestamp remains increasing after dirty state is cleared",function()
		local f=fixture();f:request("theme","brick",1,1);local first=f.profile.themeAt
		assert(f.api.flushOnce(f.profile)and f.profile.themeAt==nil)
		f:request("theme","ice",2,2);assert(f.profile.themeAt>first)
	end)
	test("commit followed by error retains exact immutable candidate for retry",function()
		local f=fixture();f:request("theme","brick",1,1);local candidate=f.profile.appearanceChange
		f.after=function()error("fixture timeout after commit")end
		assert(not f.api.flushOnce(f.profile)and f.profile.appearanceChange==candidate and #f.saved==0)
		assert(f.db.theme=="brick"and f.api.flushOnce(f.profile)and #f.saved==1)
		assert(f.db.themeAt==candidate.at)
	end)
	test("newer foreign writer causes retained latest intent retry, never a false Saved",function()
		local f=fixture();f.facts.trials=2;f:request("theme","brick",1,1)
		f.before=function()
			f:request("background","creek",1,2)
			f.db.theme="moss";f.db.sticker="none";f.db.themeAt=10000;f.db.themeWriter="foreign"
		end
		assert(not f.api.flushOnce(f.profile)and #f.saved==0)
		assert(f.profile.theme=="brick"and f.profile.background=="creek"and f.profile.themeAt>10000)
		assert(f.api.flushOnce(f.profile)and f.db.theme=="brick"and f.db.background=="creek")
	end)
	test("legitimate newer foreign winner supersedes an older click without an automatic rewrite",function()
		local f=fixture();f:request("theme","brick",1,1)
		f.before=function()f.db.theme="moss";f.db.sticker="star";f.db.themeAt=10000;f.db.themeWriter="foreign"end
		assert(f.api.flushOnce(f.profile) and #f.saved==0 and #f.superseded==1)
		assert(f.profile.theme=="moss"and f.profile.sticker=="none"and f.profile.appearanceChange==nil)
		assert(f.state.revision==2 and f.superseded[1].reason=="Superseded"and f.superseded[1].seq==1)
		assert(f.superseded[1].themeId=="moss"and f.superseded[1].stickerId=="none")
		assert(f.api.flushOnce(f.profile)and f.writes==1 and f.db.themeAt==10000)
	end)
	test("equal stamp higher writer wins and live eligibility validates the adopted sticker",function()
		local f=fixture();f:request("theme","brick",1,1)
		local stamp=f.profile.themeAt
		f.profile.resolveAppearance=function(theme,sticker)return theme,if sticker=="wick"then "none"else sticker end
		f.before=function()f.db.theme="moss";f.db.sticker="wick";f.db.themeAt=stamp;f.db.themeWriter="zz-foreign"end
		assert(f.api.flushOnce(f.profile)and f.profile.theme=="moss"and f.profile.sticker=="none")
		assert(#f.superseded==1 and #f.saved==0 and f.profile.appearanceChange==nil)
		assert(f:request("sticker","none",1,2).status=="Applied","fallback is not falsely claimed durable")
	end)
	test("writer mismatch with matching pair and stamp still requires retry",function()
		local f=fixture();f:request("theme","brick",1,1)
		f.after=function()f.db.themeWriter="a-lower-writer"end
		assert(not f.api.flushOnce(f.profile)and #f.saved==0)
		assert(f.api.flushOnce(f.profile)and #f.saved==1)
	end)
	test("appearance writes preserve siblings and hatch subtree and reload durable IDs",function()
		local f=fixture();f:request("theme","brick",1,1);assert(f.api.flushOnce(f.profile))
		assert(f.db.customSibling=="preserved"and f.db.hatching.nectar==37 and f.db.hatching.revision==4)
		local loaded=f.api.fromRecord(1,f.db,true)
		assert(loaded.theme=="brick"and loaded.sticker=="none"and loaded.appearanceSaved.theme=="brick")
	end)
	test("missing background is a factual default; malformed stored ID is not proof of fallback",function()
		local f=fixture();assert(f.profile.background=="canopy"and f.profile.appearanceSaved.background=="canopy")
		assert(f:request("background","canopy",1,1).status=="Saved"and f.writes==0)
		f.db.background="unknown";f.profile=f.api.fromRecord(1,f.db,true)
		assert(f.profile.background=="canopy"and f.profile.appearanceFallbacks.background=="Unknown")
		assert(f:request("background","canopy",2,2).status=="Applied")
	end)
	test("third slot saves atomically with theme and sticker and legacy equip preserves it",function()
		local f=fixture();f.facts.trials=2
		assert(f:request("background","creek",1,1).status=="Applied")
		assert(f:request("theme","brick",1,2).backgroundId=="creek")
		assert(f.api.flushOnce(f.profile)and f.db.background=="creek"and f.db.theme=="brick"and f.db.sticker=="none")
		local loaded=f.api.fromRecord(1,f.db,true);assert(loaded.background=="creek")
		f.api.equip(loaded,"ice","none");assert(loaded.appearanceChange.background=="creek")
		assert(f.api.flushOnce(loaded)and f.db.background=="creek")
	end)
	test("background A B A during save cannot inherit earlier A proof",function()
		local f=fixture();f.facts.trials=2;f.facts.masteryRanks.pip=2
		f:request("background","creek",1,1)
		f.before=function()f:request("background","lantern",2,2);f:request("background","creek",3,3)end
		assert(not f.api.flushOnce(f.profile)and #f.saved==0 and f.profile.background=="creek")
		assert(f.api.flushOnce(f.profile)and #f.saved==1 and f.saved[1].seq==3 and f.saved[1].backgroundId=="creek")
	end)
	test("wrong returned background cannot prove Saved even with matching pair stamp and writer",function()
		local f=fixture();f.facts.trials=2;f:request("background","creek",1,1)
		f.after=function()f.db.background="canopy"end
		assert(not f.api.flushOnce(f.profile)and #f.saved==0)
		assert(f.api.flushOnce(f.profile)and f.db.background=="creek"and #f.saved==1)
	end)
	test("foreign triple wins only without a newer local intent",function()
		local f=fixture();f.facts.trials=2;f.facts.masteryRanks.pip=2;f:request("background","creek",1,1)
		f.before=function()f.db.theme="moss";f.db.sticker="star";f.db.background="lantern";f.db.themeAt=10000;f.db.themeWriter="foreign"end
		assert(f.api.flushOnce(f.profile)and f.profile.background=="lantern"and #f.superseded==1)
		assert(f.superseded[1].backgroundId=="lantern"and #f.saved==0 and f.writes==1)
	end)
	test("verified triple clears an old fallback warning even when another slot triggered its write",function()
		local f=fixture();f.db.background="unknown";f.profile=f.api.fromRecord(1,f.db,true)
		assert(f.profile.appearanceFallbacks.background=="Unknown"and f.profile.appearanceSaved.background=="unknown")
		f:request("theme","brick",1,1)
		assert(f.profile.appearanceFallbacks.background=="Unknown")
		assert(f.api.flushOnce(f.profile)and f.db.background=="canopy")
		assert(f.profile.appearanceSaved.background=="canopy"and f.profile.appearanceFallbacks.background==nil)
	end)
	shared:Destroy()
	return {passed=#cases,cases=cases,persistentWrites=false,evidence="fresh cloned shared/protocol plus real PlayerProgress source; isolated logical reload"}
end
