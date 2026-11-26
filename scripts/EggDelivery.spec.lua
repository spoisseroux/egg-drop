-- Beta (35), Spencer's standing rule: "we need all eggs to have the crank animation, even in the future for eggs".
-- Every egg type (EggModels.Order) is either sold by the machine (EggCorner.Eggs) or named in NotMachine with the reason;
-- every `"...Buy"` send in src is an egg buy (EggCorner.BuyActions, from Eggs) or named in OtherBuys; every egg's
-- reveal goes through EggMachineClient:deliver (the cinematic ones by HatchCinematic.onPlay, the deferred ones by
-- their host); and, played for every type, action and version (the shot, Hatch another, Reduced Motion, the pocket,
-- the capsule off), the crank turns and the egg lands before its reveal is on the screen. A future egg type with no
-- row still comes out of the machine. The tree scan (EggEntryScan) is built by scripts/run_dash_server_specs.py, so
-- that part runs offline only.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.EggDelivery)(PlayerScripts.Client); offline in
-- scripts/run_dash_server_specs.py.
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Corner=require(Shared.EggCorner)
	local Models=require(Shared.EggModels)
	local Machine=require(client.EggMachineClient)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-6)end

	test("every EggModels egg type is sold by the machine or named as not, with the reason; each row is whole",function()
		local data=Corner.machineData()
		for _,id in ipairs(Models.Order)do
			local row,why=Corner.Eggs[id],Corner.NotMachine[id]
			assert((row~=nil)~=(why~=nil),"the egg type "..id.." must be in EggCorner.Eggs or EggCorner.NotMachine (once)")
			if why then assert(type(why)=="string"and #why>20,"the reason for "..id)end
		end
		for id,row in pairs(Corner.Eggs)do
			assert(table.find(Models.Order,id),id.." is not an EggModels type")
			assert(Corner.eggType(row.drop)==id and Machine.dropName(id)==row.drop,id)
			assert(data.eggTypes[row.drop],"the machine has no colour for "..row.drop)
			assert(Models.Types[id]and Models.Types[id].colorMap,"no shell texture for "..id)
			assert(#row.actions>=1,id)
			assert(row.reveal=="cinematic"or row.reveal=="deferred",id..": "..tostring(row.reveal))
			if row.reveal=="deferred"then assert(type(row.host)=="string","a deferred reveal names its host: "..id)end
			for _,action in ipairs(row.actions)do
				assert(Corner.BuyActions[action]==row.drop and Machine.dropName(action)==row.drop,action)
			end
			assert((Machine.Unclaimed[row.drop]==true)==(row.reveal=="deferred"),id)
		end
		for action,drop in pairs(Corner.BuyActions)do assert(Corner.eggRow(drop),action)end
		for action in pairs(Corner.OtherBuys)do assert(Corner.BuyActions[action]==nil,action)end
		-- Medal eggs are Stat Eggs (HatchProgress.statEggBuy, free): the Stat row.
		assert(Corner.BuyActions.statEggBuy=="Stat")
	end)

	local scanNode=client:FindFirstChild("EggEntryScan")
	if scanNode then
		local scan=require(scanNode)
		test("the tree: every \"...Buy\" send is an egg the machine sells or named in OtherBuys (a new egg buy fails here)",function()
			local seen=0
			for action,paths in pairs(scan.buys)do
				seen+=1
				assert(Corner.BuyActions[action]or Corner.OtherBuys[action],
					action.." ("..table.concat(paths,", ")..") is a new buy: an egg goes in EggCorner.Eggs, anything else in OtherBuys")
			end
			assert(seen>=8,"the scan found the buys: "..seen)
			for action in pairs(Corner.BuyActions)do assert(scan.buys[action],action.." is sent nowhere")end
		end)
		test("the tree: every cinematic egg's buy arms the crank (its intent sends through clientUI.sendNursery -> eggPressed)",function()
			local init=scan.sources.init
			local at=string.find(init,"function clientUI.sendNursery(action,value,revision)",1,true)
			assert(at,"clientUI.sendNursery")
			local body=string.sub(init,at,(string.find(init,"\nend",at,true)))
			assert(string.find(body,"clientUI.eggPressed",1,true),"sendNursery tells the machine first")
			for id,row in pairs(Corner.Eggs)do
				if row.reveal=="cinematic"then
					local from=string.find(init,"clientUI."..id.."Intent=",1,true)
					assert(from,"clientUI."..id.."Intent")
					local block=string.sub(init,from,from+420)
					assert(string.find(block,"send=function(action,value,revision)clientUI.sendNursery(action,value,revision)end",1,true),
						id.."'s buys go through sendNursery")
				end
			end
			-- HatchCinematic hands every reveal it plays to the machine (claim -> deliver).
			assert(string.find(scan.sources.HatchCinematic,"if Cinematic.onPlay then pcall(Cinematic.onPlay,self)end",1,true))
		end)
		test("the tree: every deferred egg's reveal opens through the machine (its host's every show goes through present)",function()
			local init=scan.sources.init
			for id,row in pairs(Corner.Eggs)do
				if row.reveal=="deferred"then
					local host=scan.sources[row.host]
					assert(host,id..": its host "..row.host.." is not in the scan (add it to egg_entry_scan)")
					local shows,routed=0,0
					for _ in string.gmatch(host,"reveal:show%(")do shows+=1 end
					for _ in string.gmatch(host,"present%(function%(%)%s*\n[^\n]*\n?[^\n]*reveal:show%(")do routed+=1 end
					assert(shows>=2 and routed==shows,id..": "..routed.." of "..shows.." shows go through present")
					assert(string.find(host,"local ok,took=pcall(deliver,show)",1,true),"present hands the show to deliver")
				end
			end
			assert(string.find(init,'snacks.deliver=function(show)return on()and machine:deliver("Stat",show,statReveal)end',1,true),
				"init gives the Stat Egg's host the machine's deliver")
		end)
	end

	-- ── Played ───────────────────────────────────────────────────────────────────────────────────────────────────────
	local function rig(options)
		options=options or {}
		local r={now=100,sounds={},opened={},veils={},capsule=options.capsule~=false,reduced=options.reduced==true,on=true,
			root=options.root or Vector3.new(-41,4.13,8),first={}}
		r.cinematic={}
		r.statReveal={}
		r.camera={CameraType="Custom",CFrame=CFrame.new(-30,10,20)}
		local lounge=Instance.new("Folder");lounge.Name="EggDropLounge"
		local model=Instance.new("Model");model.Name="EggMachine"
		local body=Instance.new("Part");body.Name="Body";body.Position=Vector3.new(-41,4.13+3.56,2);body.Size=Vector3.new(4.2,7.12,4.3);body.Parent=model
		local dial=Instance.new("Part");dial.Name="Dial";dial.CFrame=CFrame.new(-41,6,3.7);dial.Parent=model
		local pivot=Instance.new("Attachment");pivot.Name="DialPivot";pivot.WorldCFrame=CFrame.new(-41,6,3.7);pivot.Parent=body
		model.Parent=lounge
		local held={}
		r.held=held
		r.machine=Machine.new({step=false,clock=function()return r.now end,cinematic=r.cinematic,statReveal=r.statReveal,corner=function()return r.on end,
			room=function()return lounge end,tagged=function()return{}end,random=Random.new(3),reduced=function()return r.reduced end,
			root=function()return r.root end,capsule=function()return r.capsule end,cameraObject=function()return r.camera end,
			hud=function()end,ghost=function()end,blocked=function()return false end,pocket=function()end,warn=function()end,
			stageHold=function(amount)table.insert(held,amount)end,firstOfType=function(kind)return r.first[kind]==true end,
			audio={play=function(_,name)table.insert(r.sounds,{name=name,at=r.now});return true end}})
		function r.advance(seconds)
			local left=seconds
			while left>1e-9 do local dt=math.min(1/60,left);r.now+=dt;left-=dt;r.machine:step(dt)end
		end
		function r.heard(name)for _,s in ipairs(r.sounds)do if s.name==name and s.at>=r.at-1e-9 then return s.at-r.at end end;return nil end
		function r.count(prefix)local n=0;for _,s in ipairs(r.sounds)do if s.at>=r.at-1e-9 and string.sub(s.name,1,#prefix)==prefix then n+=1 end end;return n end
		-- A buy of `action` (nil: a grant, no press) for a row; returns the reveal.
		function r.egg(row,action)
			r.at=r.now
			local reveal={isOpen=function()return false end,veil=function(_,on)table.insert(r.veils,{on=on,at=r.now-r.at})end}
			if action then assert(r.machine:bought(action,"id-"..action.."-"..r.now),action)end
			if row.reveal=="cinematic"then
				r.cinematic.onPlay(reveal)
			else
				assert(r.machine:deliver(row.drop,function()table.insert(r.opened,{reveal=reveal,at=r.now-r.at})end,reveal))
			end
			return reveal
		end
		return r
	end
	-- Plays one egg to its reveal and checks the rule: the crank turns, the egg lands once, and the reveal is not on the
	-- screen before the landing (cinematic: its clock held, its covering stages away; deferred: not opened).
	local function check(r,row,reveal,label)
		local s=(r.machine.shot and r.machine.shot.sched)or r.machine.crank.sched
		local mode=r.machine.shot and r.machine.shot.mode or "crank"
		local land=s.land
		local opensAt=Machine.openTime(s)
		assert(opensAt>=land-1e-9,label)
		local before=#r.opened
		while r.now-r.at<land-1/60 do
			r.advance(1/60)
			local t=r.now-r.at
			if row.reveal=="cinematic"then
				assert(r.cinematic.gate(reveal),label..": the reveal's clock is held at "..t)
				if mode=="shot"and t>=s.tuck then assert(r.machine:stageAmount()==1,label..": tucked at "..t)end
				if mode=="pocket"or mode=="reduced"then assert(r.machine:stageAmount()==1,label..": its stages away at "..t)end
			else
				assert(#r.opened==before,label..": opened at "..t)
			end
		end
		r.advance(opensAt-(r.now-r.at)+.05)
		assert(r.count("crank_click")>=1,label..": the crank turned")
		local lands=0;for _,x in ipairs(r.sounds)do if x.name=="land"and x.at>=r.at-1e-9 then lands+=1 end end
		assert(lands==1,label..": one landing ("..lands..")")
		local landed=r.heard("land")
		assert(landed and near(landed,land,.03),label..": the egg lands at "..tostring(landed))
		if row.reveal=="deferred"then
			local opened=r.opened[#r.opened]
			assert(#r.opened==before+1 and opened and opened.reveal==reveal and opened.at>=landed-1e-9
				and opened.at>=opensAt-1e-9 and opened.at<=math.max(opensAt,landed)+2/60+1e-9,label..": opened at "..tostring(opened and opened.at))
		else
			r.advance(.3)
			assert(not r.cinematic.gate(reveal),label..": the reveal goes on")
			assert(r.machine:stageAmount()==0,label..": its stages are back")
		end
		return mode
	end

	test("every egg type and every buy of it: the crank, the egg in the cup, then the reveal (at the machine: the shot)",function()
		for id,row in pairs(Corner.Eggs)do
			for _,action in ipairs(row.actions)do
				local r=rig()
				local reveal=r.egg(row,action)
				assert(check(r,row,reveal,id.."/"..action)=="shot",id)
				assert(r.machine.shot.sched==Machine.Shots.first)
			end
		end
	end)
	test("Hatch another (2nd, 3rd in a row from Shot B), Reduced Motion, the pocket version and the capsule off: the same rule",function()
		for id,row in pairs(Corner.Eggs)do
			local action=row.actions[1]
			local r=rig()
			check(r,row,r.egg(row,action),id.." first")
			r.advance(.5)
			check(r,row,r.egg(row,action),id.." second")
			assert(r.machine.shot.sched==Machine.Shots.second,id)
			r.advance(.5)
			check(r,row,r.egg(row,action),id.." third")
			assert(r.machine.shot.sched==Machine.Shots.third,id)
			local reduced=rig({reduced=true})
			assert(check(reduced,row,reduced.egg(row,action),id.." reduced")=="reduced")
			local pocket=rig({root=Vector3.new(-41,4,60)})
			assert(check(pocket,row,pocket.egg(row,action),id.." pocket")=="pocket")
			local off=rig({capsule=false})
			assert(check(off,row,off.egg(row,action),id.." capsule off")=="crank")
		end
	end)
	test("a grant or a late answer (no press, or one that lapsed) still comes out of the machine; the corner off opens at once",function()
		local row=Corner.Eggs.stat
		local r=rig()
		check(r,row,r.egg(row,nil),"a medal egg, no press")
		local late=rig()
		late.machine:bought("statEggBuy",nil);late.advance(Machine.ConfirmWindow+1)
		check(late,row,late.egg(row,nil),"a late answer")
		local off=rig();off.on=false
		assert(not off.machine:deliver("Stat",function()end,{}),"the corner off: the caller opens it at once")
	end)
	test("a future egg type with no row still gets the crank and the landing before its reveal (white until coloured)",function()
		local r=rig()
		local row={drop=Machine.dropName("sparkle"),reveal="deferred"}
		assert(row.drop=="Sparkle")
		local reveal=r.egg(row,nil)
		assert(check(r,row,reveal,"sparkle")=="shot")
	end)
	test("a skip jumps to the landing; the deferred reveal opens .12 s later, never before the thud; never the first of a type",function()
		local row=Corner.Eggs.stat
		local r=rig()
		r.first.stat=true
		r.egg(row,"statEggBuy")
		r.advance(.3)
		assert(not r.machine:skipShot(),"the first Stat Egg plays in full")
		r.first.stat=false
		assert(r.machine:skipShot())
		r.advance(.05)
		assert(#r.opened==0 and r.heard("land"),"the thud first")
		r.advance(.1)
		assert(#r.opened==1,"then the reveal")
	end)
	test("Hatch another on an open result card: the card is veiled for the shot and unveiled as the next reveal opens",function()
		local row=Corner.Eggs.stat
		local r=rig()
		r.egg(row,"statEggBuy");r.advance(2.5)
		r.egg(row,"statEggBuy")
		assert(r.veils[#r.veils].on==true and r.veils[#r.veils].at==0,"hidden with the shot's start")
		r.advance(1.0)
		assert(r.veils[#r.veils].on==true and #r.opened==1,"still hidden at 1.0 (the 2nd shot's panel rises at 1.07)")
		r.advance(.4)
		assert(r.veils[#r.veils].on==false and #r.opened==2,"shown again with the new reveal")
		-- Destroyed mid-shot: the waiting reveal still opens (never lost).
		r.egg(row,"statEggBuy")
		r.machine:destroy()
		assert(#r.opened==3)
	end)
	return{passed=#cases,cases=cases}
end
