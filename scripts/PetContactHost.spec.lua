-- Actual host request/receipt wire with isolated services, actors, ground and DB.
-- The test-controlled positive RNG is a fixture, never a production odds claim.
return function(server,hostSource)
	assert(type(hostSource)=="string","Actual init.server source required")
	local H=require(server.HatchProgress);local P=require(server.PlayerProgress)
	local realGame,realRequire=game,require
	local c={now=0,serial=0,writes=0,rolls=0,packets={},tasks={},closed={},groundCalls=0}
	local db={}
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function signal()
		local callbacks={}
		return{Connect=function(_,f)table.insert(callbacks,f);return{Disconnect=function()end}end,
			Fire=function(_,...)for _,f in ipairs(callbacks)do f(...)end end}
	end
	local adapter={now=function()return 1700000000+c.now end,guid=function()c.serial+=1;return"wire-"..c.serial end,
		random=function()return .1 end,wait=function()end,update=function(key,transform)
			c.writes+=1;local value=transform(copy(db[key]));if value then db[key]=copy(value)end
			if c.failAfter then c.failAfter=false;error("fixture committed pet write then timed out")end
			return copy(value)
		end}
	local h=H.load(81001,{rank=1,companionId="pip"},adapter);assert(h.status=="Ready"and h.state.version==4)
	local fixture=Instance.new("Folder");fixture.Name="_PetContactHostFixture";fixture.Parent=server
	local replicated=Instance.new("Folder");replicated.Parent=fixture
	local shared=realGame.ReplicatedStorage.Shared:Clone();shared.Parent=replicated
	local remotes=Instance.new("Folder");remotes.Name="Remotes";remotes.Parent=replicated
	local players={PlayerAdded=signal(),PlayerRemoving=signal()}
	local heart=signal()
	local root={Position=Vector3.new(0,7,0),CFrame=CFrame.new(0,7,0)}
	local humanoid={Health=100}
	local floor={Size=Vector3.new(160,1,128),CFrame=CFrame.new(0,3.5,0)}
	local room={FindFirstChild=function(_,name)return if name=="Floor"then floor else nil end}
	local world={EggDropLounge=room}
	function world:GetServerTimeNow()return 1700000000+c.now end
	function world:FindFirstChild(name)return if name=="EggDropLounge"then room else nil end
	function world:Raycast(origin,direction,params)
		c.groundCalls+=1
		assert(params.RespectCanCollide and params.FilterType==Enum.RaycastFilterType.Include and params.FilterDescendantsInstances[1]==room)
		assert(math.abs(origin.X-2.6)<.0001 and math.abs(origin.Z-3)<.0001,"Anchor must derive from normal server companion offset")
		return{Position=Vector3.new(origin.X,4,origin.Z)}
	end
	local character={attributes={}}
	function character:SetAttribute(key,value)self.attributes[key]=value end
	function character:FindFirstChild(name)return if name=="HumanoidRootPart"then root else nil end
	function character:FindFirstChildOfClass(name)return if name=="Humanoid"then humanoid else nil end
	function character:IsDescendantOf(parent)return parent==world end
	local player={UserId=81001,Parent=players,Character=character,CharacterAdded=signal()}
	function players:GetPlayers()return{player}end
	local function resume(thread,...)
		local ok,err=coroutine.resume(thread,...);assert(ok,err)
	end
	local taskShim={wait=function()return coroutine.yield()end}
	function taskShim.spawn(f,...)
		local thread=coroutine.create(f);resume(thread,...)
		if coroutine.status(thread)=="suspended"then table.insert(c.tasks,thread)end;return thread
	end
	taskShim.defer=taskShim.spawn
	local fakeGame={JobId="pet-wire-fixture",GameId=0}
	function fakeGame:GetService(name)
		if name=="Players"then return players elseif name=="ReplicatedStorage"then return replicated
		elseif name=="RunService"then return{Heartbeat=heart,IsStudio=function()return true end}end
		return realGame:GetService(name)
	end
	function fakeGame:BindToClose(f)table.insert(c.closed,f)end
	local profileApi={hydrate=P.hydrate}
	function profileApi.load(id)return P.fromRecord(id,db.player_81001,true)end
	function profileApi.flushOnce()return true end
	for _,name in ipairs({"equip","equipCompanion","setSetting","recordScore","recordTrials","chargeHatch"})do
		profileApi[name]=function()error("Unexpected profile mutation in Room contact fixture: "..name)end
	end
	local hatch={};for key,value in pairs(H)do hatch[key]=value end
	function hatch.load()return h end
	local events={}
	local instanceShim={new=function(class)
		if class~="RemoteEvent"then return Instance.new(class)end
		local event={OnServerEvent=signal()}
		function event:FireClient(who,packet)
			assert(who==player)
			if self.Name=="PetContact"then
				if packet.status=="Saved"then
					local board=replicated.EggDropBoards[tostring(player.UserId)]
					local public=realGame.HttpService:JSONDecode(board:GetAttribute("HatchState"))
					assert(public.lastPetAward.id==packet.receipt.id and public.nectar==h.state.nectar,"Balance/receipt must publish before glyph wire")
				end
				table.insert(c.packets,packet)
			end
		end
		table.insert(events,event);return event
	end}
	local fakeRandom={new=function()return{NextInteger=function()return 40001 end,NextNumber=function()c.rolls+=1;return .1 end}end}
	local module=Instance.new("ModuleScript");module.Name="_PetContactHostSandbox"
	module.Source="return function(e)local game,script,task,require,Instance,workspace,RaycastParams,os,Random=e.game,e.script,e.task,e.require,e.Instance,e.workspace,e.RaycastParams,e.os,e.Random\n"..hostSource.."\nend"
	module.Parent=server;local ok,run=pcall(realRequire,module);module:Destroy();assert(ok,run)
	local lounge={create=function()end,spawn=function()end,setMode=function()end,setAppearance=function()end}
	run({game=fakeGame,script=server,task=taskShim,Instance=instanceShim,workspace=world,RaycastParams={new=function()return{}end},
		os={clock=function()return c.now end},Random=fakeRandom,require=function(target)
			if target==server.PlayerProgress then return profileApi elseif target==server.HatchProgress then return hatch
			elseif target==server.Lounge then return lounge elseif target==server.FirstSession then return{new=function()return nil end}end
			return realRequire(target)
		end})
	local requests={};for _,event in ipairs(events)do requests[event.Name]=event end
	local cases={}
	local function test(name,check)check();table.insert(cases,name)end
	local function savedCount()local n=0;for _,p in ipairs(c.packets)do if p.status=="Saved"then n+=1 end end;return n end
	local function begin(generation)
		requests.PetContact.OnServerEvent:Fire(player,"begin",{requestGeneration=generation,petId="pip"})
		local packet=c.packets[#c.packets];assert(packet.granted and packet.requestGeneration==generation);return packet.leaseId
	end
	local function pulses(id,seconds)
		for _=1,seconds*2 do c.now+=.5;requests.PetContact.OnServerEvent:Fire(player,"pulse",id);heart:Fire(1/120)end
	end
	test("actual begin pulse and saved wire derive grounded anchor and publish committed balance first",function()
		requests.PetContact.OnServerEvent:Fire(player,"begin",{requestGeneration=1,petId="pip",amount=999})
		assert(not c.packets[#c.packets].granted and h.state.nectar==6)
		c.now=1;c.lease=begin(1);pulses(c.lease,12)
		assert(c.rolls==1 and savedCount()==1 and h.state.nectar==7 and h.state.petCount==1 and c.groundCalls==1)
	end)
	test("a historical receipt cannot display again on a new grant and mode departure cancels pulses",function()
		requests.PetContact.OnServerEvent:Fire(player,"end",c.lease);c.now=14;c.lease=begin(2)
		assert(savedCount()==1)
		c.now=14.5;requests.BoardRequest.OnServerEvent:Fire(player,"mode","Board")
		requests.PetContact.OnServerEvent:Fire(player,"pulse",c.lease)
		assert(savedCount()==1 and c.rolls==1 and h.state.nectar==7)
	end)
	test("wrong equipped pet is rejected through the real host before RNG or storage",function()
		c.now=15.5;requests.BoardRequest.OnServerEvent:Fire(player,"mode","Room")
		local writes=c.writes
		requests.PetContact.OnServerEvent:Fire(player,"begin",{requestGeneration=3,petId="wick"})
		assert(not c.packets[#c.packets].granted and c.rolls==1 and c.writes==writes)
	end)
	test("existing retry worker proves ended committed operation without a second glyph or second worker",function()
		c.now=16.5;c.lease=begin(4);c.failAfter=true;pulses(c.lease,12)
		assert(h.status=="Retrying"and h.pending and savedCount()==1)
		requests.PetContact.OnServerEvent:Fire(player,"end",c.lease)
		assert(#c.tasks==2,"Only the existing retry and renew workers may run")
		c.now+=.5;resume(c.tasks[1])
		assert(h.status=="Ready"and not h.pending and h.state.petCount==2 and h.state.nectar==8 and savedCount()==1)
	end)
	players.PlayerRemoving:Fire(player);fixture:Destroy()
	return{passed=#cases,cases=cases,persistentWrites=false,evidence="actual host remote callbacks with private actor/ground/DB; controlled positive RNG fixture"}
end
