-- Runs the actual server entry source with isolated remotes and deterministic
-- services. Session fixtures test real persistence transforms separately.
return function(server, hostSource, sessionSource)
	local ActualHatch = require(server.HatchProgress)
	local ActualProgress = require(server.PlayerProgress)
	local realRequire, realGame = require, game
	local cases = {}
	local function copy(value)
		if type(value) ~= "table" then return value end
		local result = {}; for k,v in pairs(value) do result[k]=copy(v) end; return result
	end
	local function factory(source, env, name)
		local module=Instance.new("ModuleScript");module.Name="_SessionHost_"..name
		module.Source="return function(e) local game,script,task,require=e.game,e.script,e.task,e.require\n"..source.."\nend"
		module.Parent=server;local ok,run=pcall(realRequire,module);module:Destroy();assert(ok,run)
		return run(env)
	end
	local function signal()
		local listeners={};return{Connect=function(_,callback)table.insert(listeners,callback);return{Disconnect=function()end}end,
			Fire=function(_,...)for _,callback in ipairs(listeners)do callback(...)end end}
	end
	for caseIndex,initialFailure in ipairs({"Temporary","Locked"})do
		local folder=Instance.new("Folder");folder.Name="_SessionHostFixture";folder.Parent=server
		local replicated=Instance.new("Folder");replicated.Parent=folder
		local shared=realGame.ReplicatedStorage.Shared:Clone();shared.Parent=replicated
		local remotes=Instance.new("Folder");remotes.Name="Remotes";remotes.Parent=replicated
		local db,serial={},0;local id=72000+caseIndex
		local function adapter()
			return{now=function()return 1700000000 end,guid=function()serial+=1;return"host-"..serial end,
				random=function()return .96 end,wait=function()end,update=function(key,transform)
				local result=transform(copy(db[key]));if result~=nil then db[key]=copy(result)end;return copy(result)
			end}
		end
		local owner=ActualHatch.load(id,{rank=1},adapter())
		assert(ActualHatch.award(owner,1,8));assert(ActualHatch.award(owner,2,8))
		assert(ActualHatch.command(owner,"hatch","meadow",owner.state.revision))
		local key="player_"..id;local hatchId=owner.state.lastHatch.id
		db[key].companionId="foxfire_wick";db[key].theme="ice";db[key].sticker="star"
		db[key].sound="Quiet";db[key].reduced=true
		if initialFailure=="Temporary"then assert(ActualHatch.release(owner))end
		local trace={loads=0,dirty=0,releases=0,appearance=0,mode=0};local heart=signal()
		local players={PlayerAdded=signal(),PlayerRemoving=signal()}
		local player={UserId=id,Parent=players,CharacterAdded=signal(),Character=nil}
		function players:GetPlayers()return{player}end
		local profileApi={hydrate=ActualProgress.hydrate,fromRecord=ActualProgress.fromRecord}
		function profileApi.load(userId)
			trace.loads+=1
			return ActualProgress.fromRecord(userId,db[key],not(initialFailure=="Temporary"and trace.loads==1))
		end
		for _,name in ipairs({"equip","equipCompanion","setSetting","recordScore","recordTrials","chargeHatch"})do
			profileApi[name]=function()trace.dirty+=1 end
		end
		function profileApi.flushOnce()return true end
		local hatch={RenewSeconds=20,public=ActualHatch.public,retry=ActualHatch.retry,renew=ActualHatch.renew,
			award=ActualHatch.award,command=ActualHatch.command,grantStarter=ActualHatch.grantStarter}
		function hatch.load(userId,profile)return ActualHatch.load(userId,profile,adapter())end
		function hatch.release(handle)trace.releases+=1;return ActualHatch.release(handle)end
		local tasks,shutdown,requests={},{},{}
		local function resume(thread,...)
			local ok,problem=coroutine.resume(thread,...);assert(ok,problem)
		end
		local taskShim={wait=function(dt)return coroutine.yield(dt)end,defer=function(callback,...)callback(...)end}
		function taskShim.spawn(callback,...)
			local thread=coroutine.create(callback);resume(thread,...)
			if coroutine.status(thread)~="dead"then table.insert(tasks,thread)end
			return thread
		end
		local fakeGame={JobId="fixture-host",GameId=0}
		function fakeGame:GetService(name)
			if name=="Players"then return players elseif name=="ReplicatedStorage"then return replicated
			elseif name=="RunService"then return{Heartbeat=heart,IsStudio=function()return true end}
			else return realGame:GetService(name)end
		end
		function fakeGame:BindToClose(callback)table.insert(shutdown,callback)end
		local session=factory(sessionSource,{game=realGame,script=server.SessionProfile,task=taskShim,
			require=function(module)if module==server.PlayerProgress then return profileApi end;return realRequire(module)end},"profile")
		local lounge={create=function()end,spawn=function()end,setMode=function()trace.mode+=1 end,
			setAppearance=function()trace.appearance+=1 end}
		local nativeInstance=Instance
		local instanceShim={new=function(class)
			if class~="RemoteEvent"then return nativeInstance.new(class)end
			local event={OnServerEvent=signal(),FireClient=function()end};requests[#requests+1]=event
			return event
		end}
		-- RemoteEvent substitutes need no real parenting; folders/parts are isolated.
		local wrapped="local Instance=e.Instance\n"..hostSource
		factory(wrapped,{game=fakeGame,script=server,task=taskShim,Instance=instanceShim,require=function(module)
			if module==server.PlayerProgress then return profileApi elseif module==server.HatchProgress then return hatch
			elseif module==server.SessionProfile then return session elseif module==server.Lounge then return lounge
			elseif module==server.FirstSession then return{new=function()return nil end}end
			return realRequire(module)
		end},"entry")
		local board=replicated.EggDropBoards[tostring(id)]
		assert(game.HttpService:JSONDecode(board:GetAttribute("HatchState")).status==initialFailure)
		assert(not board:GetAttribute("FieldReady"))
		for _,args in ipairs({{"appearance","sherbet","none"},{"sound"},{"motion"},{"companion","pip"},{"family","pip"},{"drop",.5}})do
			requests[1].OnServerEvent:Fire(player,table.unpack(args))
		end
		for _=1,30 do heart:Fire(1/30)end
		assert(trace.dirty==0 and board:GetAttribute("Drops")==0,"provisional session mutated progress")
		if initialFailure=="Locked"then assert(ActualHatch.release(owner))end
		-- The host registered retry and maintenance loops in this order.
		assert(#tasks==2);resume(tasks[2])
		local snapshot=game.HttpService:JSONDecode(board:GetAttribute("HatchState"))
		assert(snapshot.status=="Ready"and snapshot.lastHatch.id==hatchId)
		assert(board:GetAttribute("Mode")=="Room"and board:GetAttribute("CompanionId")=="foxfire_wick")
		assert(board:GetAttribute("SelectedFamily")=="wick"and board:GetAttribute("DeckThemeId")=="ice")
		assert(board:GetAttribute("DeckStickerId")=="star"and board:GetAttribute("SoundLevel")=="Quiet")
		assert(board:GetAttribute("ReducedEffects")==true and board:GetAttribute("SaveStatus")==nil)
		assert(trace.appearance==1 and trace.mode==1 and trace.dirty==0)
		requests[1].OnServerEvent:Fire(player,"mode","Board")
		requests[1].OnServerEvent:Fire(player,"drop",.1)
		assert(board:GetAttribute("FieldBudget")==24 and board:GetAttribute("Drops")==1,"recovered A/drop blocked")
		local thread=coroutine.create(shutdown[1]);resume(thread)
		assert(trace.releases==1)
		players.PlayerRemoving:Fire(player);assert(trace.releases==1,"duplicate shutdown/removal release")
		folder:Destroy();table.insert(cases,initialFailure.." host gates progress, hydrates all attrs, resumes field and closes once")
	end
	return{passed=#cases,cases=cases,persistentWrites=false}
end
