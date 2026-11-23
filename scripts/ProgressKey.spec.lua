-- The save key switch (beta (12) QA T1, ProgressKey): the gate, the pointer rules, resolve (refuses on an unreadable or
-- malformed pointer, never the base key by default), point (one write each way), and the loads that use it
-- (Progress.load's newSave on a fresh key, HatchProgress.load's key). The in-memory ProgressStore only (Studio, offline).
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.ProgressKey)(ServerScriptService.Server); offline in
-- scripts/run_dash_server_specs.py.
return function(server)
	local Key=require(server.ProgressKey)
	local Store=require(server.ProgressStore)
	-- PlayerProgress starts a save loop when required (task.spawn + while true). Offline task.wait does not yield, so the
	-- spec holds that one spawn back while requiring it; in Studio `task` is read-only and the pcall leaves it alone.
	local Progress
	do
		local swapped,spawn=pcall(function()local real=task.spawn;task.spawn=function()end;return real end)
		local ok,result=pcall(require,server.PlayerProgress)
		if swapped then task.spawn=spawn end
		assert(ok,result);Progress=result
	end
	local Hatching=require(server.HatchProgress)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	assert(not Store.persistent,"specs only run on the in-memory store")
	local OPEN={flags={FreshSaveCommand=true}}
	local function clean(id)Key.forget(id);Key.inject(nil)end

	test("gate: the flag, and the in-memory store or the beta place in the beta universe; never live",function()
		local on={FreshSaveCommand=true}
		assert(Key.enabled({flags=on,persistent=false}),"Studio memory store")
		assert(Key.enabled({flags=on,persistent=true,place=Key.BetaPlace,game=Key.BetaUniverse}),"beta")
		assert(not Key.enabled({flags=on,persistent=true,place=96451847774961,game=Key.BetaUniverse}),"live place")
		assert(not Key.enabled({flags=on,persistent=true,place=Key.BetaPlace,game=1}),"another universe")
		assert(not Key.enabled({flags={},persistent=false}),"flag off")
		assert(Key.base(7)=="player_7"and Key.fresh(7,3)=="player_7_fs3"and Key.pointer(7)=="freshsave_7")
	end)
	test("pointer rules: nil is the base key; a suffix is its fresh key; anything else is malformed",function()
		assert(Key.target(5,nil)=="player_5"and Key.target(5,{version=1})=="player_5"and Key.target(5,{version=1,last=4})=="player_5")
		assert(Key.target(5,{version=1,suffix=2,last=2})=="player_5_fs2")
		for _,bad in ipairs({"x",5,{version=2,suffix=1},{version=1,suffix=0},{version=1,suffix=1.5},{version=1,suffix="1"},{version=1,suffix=1e9}})do
			assert(Key.target(5,bad)==nil,tostring(bad))
		end
	end)
	test("resolve: gate closed reads nothing; open reads the pointer; an unreadable or malformed one refuses (no base)",function()
		local reads=0
		local fake={GetAsync=function(_,key)reads+=1;return nil end}
		Key.inject({flags={}})
		assert(Key.resolve(11,fake)=="player_11"and reads==0,"closed: no read")
		Key.inject(OPEN)
		assert(Key.resolve(11,fake)=="player_11"and reads==1 and Key.isBase(11))
		local broken={GetAsync=function()error("DataStore down")end}
		local key,why=Key.resolve(11,broken);assert(key==nil and why=="Locked","a failed read refuses")
		local odd={GetAsync=function()return{version=1,suffix="nope"}end}
		key,why=Key.resolve(11,odd);assert(key==nil and why=="Locked","a malformed pointer refuses")
		local fresh={GetAsync=function()return{version=1,suffix=3,last=3}end}
		assert(Key.resolve(11,fresh)=="player_11_fs3"and Key.of(11)=="player_11_fs3"and not Key.isBase(11))
		clean(11)
		assert(Key.of(11)=="player_11","forgotten: base")
	end)
	test("point: fresh moves to the next suffix each time; restore goes back to the base key; closed or nothing to restore refuses",function()
		local id=990001
		Key.inject({flags={}});local k,why=Key.point(id,"fresh");assert(k==nil and why=="Closed")
		Key.inject(OPEN)
		k,why=Key.point(id,"restore");assert(k==nil and why=="NotFresh","nothing to restore")
		assert(Key.point(id,"fresh")=="player_990001_fs1")
		assert(Key.point(id,"fresh")=="player_990001_fs2","a second fresh save is a new key, never the old test save")
		assert(Key.point(id,"restore")=="player_990001")
		assert(Key.point(id,"fresh")=="player_990001_fs3","after a restore the next fresh key is new again")
		k,why=Key.point(id,"sideways");assert(k==nil and why=="Unknown")
		clean(id)
	end)
	test("loads: a fresh key is a brand-new save (newSave), the base save is untouched and comes back on restore",function()
		local id=990002
		Key.inject(OPEN)
		Store:UpdateAsync(Key.base(id),function()return{bestScore=50,companionId="pip"}end)
		local base=Progress.load(id)
		assert(base.key=="player_990002"and base.newSave==false and base.bestScore==50 and not base.loadFailed)
		assert(Key.point(id,"fresh")=="player_990002_fs1")
		local fresh=Progress.load(id)
		assert(fresh.key=="player_990002_fs1"and fresh.newSave==true and fresh.bestScore==0 and not fresh.loadFailed,"fresh: new save")
		-- HatchProgress takes the same key (its own adapter here: no DataStore).
		local seen={}
		local adapter={now=function()return 1700000000 end,guid=function()return "g"end,random=function()return .1 end,wait=function()end,
			update=function(key,transform)table.insert(seen,key);return transform(nil)end}
		local handle=Hatching.load(id,fresh,adapter)
		assert(handle.key=="player_990002_fs1"and seen[1]=="player_990002_fs1","the hatch save is on the fresh key")
		assert(Store:GetAsync(Key.base(id)).bestScore==50,"the old save is untouched")
		assert(Key.point(id,"restore")=="player_990002")
		local back=Progress.load(id)
		assert(back.key=="player_990002"and back.bestScore==50 and back.newSave==false,"restored")
		clean(id)
	end)
	test("loads: an unreadable pointer refuses the load (loadFailed, nothing saved, not a new save); hydrate takes the resolved key later",function()
		local id=990003
		Key.inject(OPEN)
		Store:UpdateAsync(Key.pointer(id),function()return{version=1,suffix="broken"}end)
		local refused=Progress.load(id)
		assert(refused.loadFailed==true and refused.newSave==false and refused.key=="player_990003")
		local temp=Hatching.load(id,refused,{now=function()return 1 end,guid=function()return "g"end,random=function()return .1 end,wait=function()end,
			update=function()error("a refused load must not write")end})
		assert(temp.status=="Temporary")
		-- The pointer is repaired; the reload resolves it and SessionProfile.hydrate moves the profile onto the handle's key.
		Store:UpdateAsync(Key.pointer(id),function()return{version=1,suffix=1,last=1}end)
		local again=Progress.load(id)
		assert(again.key=="player_990003_fs1"and not again.loadFailed)
		local Session=require(server.SessionProfile)
		local handle={status="Ready",key="player_990003_fs1",profileRecord=nil,state={inventoryMask=0}}
		Session.hydrate(refused,handle)
		assert(refused.key=="player_990003_fs1","the refused profile's placeholder key follows the handle")
		clean(id)
	end)
	return{passed=#cases,cases=cases}
end
