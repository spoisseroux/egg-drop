-- The Play Den on the client (DenClient, PLAY-DEN-BUILD-PLAN.md, architect verdict 1 and 5): nothing on live; it follows
-- Den_open, never the switch; three prompts at the layout's spots, only while the garden is free; the gate is today's
-- picker (or "Leave line" while waiting in the den); the table and the board run their own paths. The meadow pad's
-- prompt (DashClient.promptState): today's "Race" whenever the den is not open; "Join race" only while a race gathers.
-- Things to do: the den row first only while it is open.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.DenClient)(PlayerScripts.Client); offline in
-- scripts/run_dash_server_specs.py.
return function(client,offline)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Den=require(Shared.PlayDen)
	local Layout=require(Shared.DenLayout)
	local Client=require(client.DenClient)
	local Dash=require(client.DashClient)
	local Page=require(client.ThingsPage)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function signal()
		local s={list={}}
		function s:Connect(fn)
			local c={Connected=true}
			function c:Disconnect()self.Connected=false;local at=table.find(s.list,fn);if at then table.remove(s.list,at)end end
			table.insert(s.list,fn)
			return c
		end
		function s:Fire(...)for _,fn in ipairs(table.clone(s.list))do fn(...)end end
		return s
	end
	-- Offline prompts have no Triggered signal: give them one for these cases.
	local real=Instance.new
	Instance.new=function(class,...)
		local made=real(class,...)
		if class=="ProximityPrompt"then made.Triggered=signal()end
		return made
	end
	local ON={flags={PlayDen=true},studio=true}
	local function rig(options)
		options=options or {}
		Den.inject(options.env or ON)
		local r={open=options.open~=false,free=true,things=true,used={},changed=signal(),beat=signal(),world=real("Folder")}
		r.dash=options.dash
		r.client=Client.mount({world=r.world,heartbeat=r.beat,changed=r.changed,isOpen=function()return r.open end,
			dash=function()return r.dash end,deck=function()table.insert(r.used,"deck")end,things=function()table.insert(r.used,"things")end,
			free=function()return r.free end,thingsOn=function()return r.things end,lounge=function()return nil end})
		function r.step(dt)r.beat:Fire(dt or .3)end
		function r.prompt(id)
			local folder=r.world:FindFirstChild(Client.Folder)
			local anchor=folder and folder:FindFirstChild("Den_"..id)
			return anchor and anchor:FindFirstChild("DenPrompt")
		end
		return r
	end
	local function fakeDash(state)
		state=state or {}
		local d={isOpen=true,dead=false,gated=0}
		function d:held()return state.held==true end
		function d:panelOpen()return state.panel==true end
		function d:waiting()return state.waiting end
		function d:waitAnchor()return state.anchor end
		function d:gate()self.gated+=1 end
		return d,state
	end

	local ok,problem=pcall(function()
		test("live: nothing mounted; a closed den (Den_open missing) builds nothing",function()
			Den.inject({flags={PlayDen=true},studio=false,place=96451847774961})
			assert(Client.mount({world=real("Folder"),heartbeat=signal(),changed=signal()})==nil)
			local r=rig({open=false});r.step();assert(r.world:FindFirstChild(Client.Folder)==nil)
		end)
		test("open: three prompts at the layout's spots, 6 studs, E / ButtonX; gone when the den closes",function()
			local r=rig({dash=fakeDash()});r.step()
			local spots=Layout.prompts(Layout.Pocket)
			for _,id in ipairs({"gate","deck","board"})do
				local p=r.prompt(id);assert(p,id)
				assert(p.MaxActivationDistance==6 and p.Parent.CFrame.Position==spots[id])
			end
			r.open=false;r.changed:Fire();assert(r.world:FindFirstChild(Client.Folder)==nil and r.client.isOpen==false)
			r.open=true;r.step();assert(r.prompt("gate"))
		end)
		test("enabled only while the garden is free; the gate needs Dash and is held off during a race; the board needs Things to do",function()
			local dash,state=fakeDash()
			local r=rig({dash=dash});r.step()
			assert(r.prompt("gate").Enabled and r.prompt("deck").Enabled and r.prompt("board").Enabled)
			r.free=false;r.step();assert(not r.prompt("gate").Enabled and not r.prompt("deck").Enabled and not r.prompt("board").Enabled)
			r.free=true;state.held=true;r.step();assert(not r.prompt("gate").Enabled and not r.prompt("deck").Enabled)
			state.held=false;r.things=false;r.step();assert(r.prompt("deck").Enabled and not r.prompt("board").Enabled)
			r.dash=nil;r.step();assert(not r.prompt("gate").Enabled)
		end)
		test("the gate: today's picker; waiting in the den it reads Leave line (held); waiting at the meadow it is off",function()
			local dash,state=fakeDash()
			local r=rig({dash=dash});r.step()
			r.prompt("gate").Triggered:Fire();assert(dash.gated==1)
			state.waiting,state.anchor="gather","den";r.step()
			local p=r.prompt("gate");assert(p.Enabled and p.HoldDuration==Client.LeaveHold and p.ActionText~=nil)
			p.Triggered:Fire();assert(dash.gated==2,"the leave question is the gate's own")
			state.anchor=nil;r.step();assert(not r.prompt("gate").Enabled)
			r.prompt("deck").Triggered:Fire();r.prompt("board").Triggered:Fire()
			assert(r.used[1]=="deck"and r.used[2]=="things")
			r.free=false;r.step();r.prompt("deck").Triggered:Fire();assert(#r.used==2,"a disabled prompt does nothing")
		end)
		test("the meadow pad: today's Race picker whenever the den is not open; Join race only while a race gathers with room",function()
			local base={canRoam=true,seat=false,queued=false,panel=false,phase="idle",humans=0}
			local function with(more)local t=table.clone(base);for k,v in pairs(more)do t[k]=v end;return t end
			local open,key,hold,hop=Dash.promptState(with({denOpen=false}))
			assert(open and key=="dash.prompt"and hold==0 and not hop)
			open,key,hold,hop=Dash.promptState(with({denOpen=false,phase="gather",humans=3}))
			assert(open and key=="dash.prompt"and not hop)
			open=Dash.promptState(with({denOpen=true,phase="idle"}));assert(not open)
			open=Dash.promptState(with({denOpen=true,phase="race"}));assert(not open)
			open,key,_,hop=Dash.promptState(with({denOpen=true,phase="gather",humans=3}));assert(open and key=="dash.join"and hop)
			open=Dash.promptState(with({denOpen=true,phase="gather",humans=8}));assert(not open)
			open=Dash.promptState(with({denOpen=true,phase="gather",seat=true}));assert(not open)
			open,key,hold=Dash.promptState(with({denOpen=true,waiting="line"}));assert(open and key=="dash.line.prompt"and hold==Dash.LeaveHold)
			open=Dash.promptState(with({denOpen=true,waiting="gather",anchor="den"}));assert(not open,"a den waiter leaves from the den")
			open=Dash.promptState(with({denOpen=false,waiting="line",asking=true}));assert(not open)
		end)
		test("Things to do: the den row first only while it is open; every other row unchanged",function()
			local without=Page.rows({park=true})
			local with=Page.rows({den=true,park=true})
			assert(with[1].id=="den"and #with==#without+1)
			for i,row in ipairs(without)do assert(with[i+1].id==row.id)end
			assert(Page.rows({den=false})[1].id=="deck")
		end)
	end)
	Instance.new=real
	Den.inject(nil)
	assert(ok,problem)
	return{passed=#cases,cases=cases}
end
