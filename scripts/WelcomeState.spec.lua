return function(server,shared,modules)
	modules=modules or {}
	local Welcome=modules.Welcome or require(server.WelcomeState)
	local P=modules.Progress or require(shared.WelcomeProgress)
	local cases={};local function test(name,run)run();table.insert(cases,name)end
	local function active(s,seconds)for _=1,seconds*2 do s:step(.5,true)end end
	test("active time, inactive reset, one replay, input epoch cancels demo",function()
		local s=Welcome.new(7)
		active(s,2.5);assert(not s:canSkip(7));active(s,.5);assert(s:canSkip(7)and not s:canSkip(8))
		active(s,5);assert(s:replayDue()and not s:replayDue())
		s:step(.5,false);assert(s.idleSeconds==0)
		active(s,25);local ticket=s:demoTicket();assert(ticket)
		s:input();local calls=0
		assert(not s:tryDemo(ticket,function()calls+=1;return true end)and calls==0)
		active(s,25);ticket=s:demoTicket()
		assert(not s:tryDemo(ticket,function()return false end)and not s.demoUsed)
		assert(s:tryDemo(ticket,function()calls+=1;return true end)and s.demoUsed and s.drops==1)
		active(s,100);assert(not s:demoTicket()and calls==1)
	end)
	test("grant single flight and refresh-independent state survive retries",function()
		local s=Welcome.new(9);active(s,3)
		assert(not s:requestGrant("other",9)and not s:requestGrant("skip",8))
		assert(s:requestGrant("skip",9)and not s:requestGrant("charge",9))
		local snapshot=s:snapshot();assert(snapshot.grantPending and not snapshot.skipReady)
		s:grantRejected();assert(s:requestGrant("charge",9))
		s:destroy();assert(not s:requestGrant("charge",9)and not s:demoTicket())
	end)
	test("authoritative stages and silent reconstruction",function()
		for charge=0,6 do assert(P.stage(charge,6)==if charge>=6 then 3 elseif charge>=4 then 2 elseif charge>=2 then 1 else 0)end
		assert(P.stage(2,7)==0 and P.stage(3,7)==1 and P.stage(5,7)==2 and P.stage(100,0)==0)
		local state=P.new()
		assert(select(2,P.update(state,1,4,6,true))==nil,"rejoin stage is silent")
		assert(select(2,P.update(state,1,6,6,true))==3)
		assert(select(2,P.update(state,1,6,6,true))==nil)
		assert(select(2,P.update(state,2,6,6,true))==nil,"new run baseline silent")
		assert(select(2,P.update(state,2,2,6,false))==nil)
	end)
	test("Applied reply is terminal across late retry/rebuild; a new run resets it",function()
		local replies={}
		assert(P.reply(replies,7,"Retrying")==true)
		assert(P.reply(replies,7,"Applied")==false)
		assert(P.reply(replies,7,"Retrying")==nil and P.reply(replies,7,"Rejected")==nil)
		assert(P.reply(replies,7,"Applied")==nil,"duplicate terminal reply is inert")
		-- Reply state belongs to the run host, not recreated HUD objects.
		local rebuiltView={pending=false};local late=P.reply(replies,7,"Retrying")
		if late~=nil then rebuiltView.pending=late end
		assert(not rebuiltView.pending)
		assert(P.reply(replies,8,"Retrying")==true and P.reply(replies,8,"Rejected")==false)
	end)
	return {passed=#cases,cases=cases}
end
