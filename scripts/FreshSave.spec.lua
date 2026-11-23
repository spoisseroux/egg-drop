-- The owner's /freshsave and /freshsave restore (beta (12) QA T1): the parse, the gate (shared with ProgressKey), the
-- throttle, one pointer write and a kick only when it worked. Fake point and kick; no store, no player.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.FreshSave)(ServerScriptService.Server); offline in
-- scripts/run_dash_server_specs.py.
return function(server)
	local Fresh=require(server.FreshSave)
	local Key=require(server.ProgressKey)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end

	test("parse: /freshsave and /freshsave restore, any case and spacing; nothing else",function()
		assert(Fresh.parse("/freshsave")=="fresh"and Fresh.parse("  /FreshSave  ")=="fresh")
		assert(Fresh.parse("/freshsave restore")=="restore"and Fresh.parse("/FRESHSAVE   Restore ")=="restore")
		for _,odd in ipairs({"freshsave","/freshsave now","/freshsaves","/freshsave restore please","/fresh save","/stars 5",5,{},true})do
			assert(Fresh.parse(odd)==nil,tostring(odd))
		end
		assert(Fresh.parse(nil)==nil)
	end)
	test("gate: the same as ProgressKey (never live); closed, a command writes nothing and kicks nobody",function()
		local on={FreshSaveCommand=true}
		assert(Fresh.ceiling({flags=on,persistent=false})and not Fresh.ceiling({flags=on,persistent=true,place=96451847774961,game=Key.BetaUniverse}))
		Key.inject({flags={}})
		local wrote,kicked=0,0
		local ok=Fresh.command({UserId=1},"/freshsave",{now=function()return 0 end,point=function()wrote+=1;return "x"end,kick=function()kicked+=1 end,warn=function()end})
		assert(ok==false and wrote==0 and kicked==0)
		Key.inject(nil)
	end)
	test("open: one write then a kick with the reason; a failed write kicks nobody; one command per Gap",function()
		Key.inject({flags={FreshSaveCommand=true}})
		local log={}
		local t=100
		local deps={now=function()return t end,warn=function()end,
			point=function(id,action)table.insert(log,"point "..id.." "..action);return if log.fail then nil else Key.fresh(id,1),"Down"end,
			kick=function(player,text)table.insert(log,"kick "..player.UserId);log.text=text end}
		local owner={UserId=42}
		local ok,target=Fresh.command(owner,"/freshsave",deps)
		assert(ok and target=="player_42_fs1"and log[1]=="point 42 fresh"and log[2]=="kick 42"and log.text==Fresh.Kick.fresh)
		t+=1;assert(Fresh.command(owner,"/freshsave restore",deps)==false and #log==2,"throttled")
		t+=Fresh.Gap;log.fail=true
		ok=Fresh.command(owner,"/freshsave restore",deps)
		assert(ok==false and log[3]=="point 42 restore"and #log==3,"a failed write: no kick")
		assert(Fresh.command(owner,"hello",deps)==false and #log==3,"not a command")
		Fresh.forget(42);Key.inject(nil)
	end)
	return{passed=#cases,cases=cases}
end
