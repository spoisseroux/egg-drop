-- Pure ownership fixture: no Instances, remotes, sound or profile writes.
return function(client)
	local Policy=require(client.PresentationPolicy)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local state={mode="Board"}
	local policy=Policy.new(function()return state end)
	test("fresh initial board and deliberate arrival may own one boot",function()
		for _,route in ipairs({"initial","arrival"}) do
			local token=policy:begin(true,route);assert(token and policy:owns(token));policy:finish(token)
		end
	end)
	test("HUD refresh resize replay and sheet close never manufacture boot",function()
		for _,route in ipairs({"refresh","resize","replay","close"}) do assert(policy:begin(true,route)==nil) end
	end)
	test("ended board pending reveal and each interactive owner suppress initial boot",function()
		for _,key in ipairs({"ended","pendingHatch","overlay","reduced"}) do
			state[key]=true;assert(policy:begin(true,"initial")==nil);state[key]=nil
		end
	end)
	test("ended board arrival leaves recap in charge",function()
		state.ended=true;assert(not policy:begin(true,"arrival"));state.ended=nil
	end)
	test("overlay arriving mid boot revokes dots visuals and sound with same predicate",function()
		local token=policy:begin(true,"initial")
		local guardedSound=function()return policy:owns(token)end
		assert(guardedSound());state.overlay=true;assert(not guardedSound() and not policy:owns(token))
		policy:cancel();state.overlay=nil;assert(not guardedSound())
	end)
	test("old completion cannot release or hide a newer presentation",function()
		local old=policy:begin(true,"initial");policy:cancel()
		local successor=policy:begin(true,"arrival")
		assert(not policy:finish(old) and not policy:owns(old) and policy:owns(successor))
		assert(policy:finish(successor) and not policy:owns(successor))
	end)
	test("route changes reduced motion and teardown revoke delayed work",function()
		local token=policy:begin(true,"initial");state.mode="Room";assert(not policy:owns(token))
		state.mode="Board";token=policy:begin(true,"arrival");state.reduced=true;assert(not policy:owns(token))
		state.reduced=nil;policy:cancel();assert(not policy:owns(token))
	end)
	test("ended board under menu passes gamepad A to the visible sheet",function()
		assert(not Policy.ownsRecap({modal=false,recap=true,overlay=true}))
		assert(not Policy.ownsRecap({modal=true,recap=true,busy=true}))
		assert(not Policy.ownsRecap({modal=true,recap=true,coreMenu=true}))
		assert(Policy.ownsRecap({modal=true,recap=true}))
	end)
	test("native menu and text capture retain Back instead of closing covered sheets",function()
		assert(Policy.canSheetBack({}))
		assert(not Policy.canSheetBack({coreMenu=true}))
		assert(not Policy.canSheetBack({textCapture=true}))
		assert(not Policy.canSheetBack({busy=true}))
	end)
	test("late committed hatch preempts Menu in order and never acknowledges or purchases",function()
		local current={generation=7,id="saved-result",mode="Room",ready=true}
		local menu,roomFlag,shop=true,true,false;local calls={}
		local function close()menu,roomFlag=false,false;table.insert(calls,"close")end
		local function open()assert(not menu and not roomFlag);shop=true;table.insert(calls,"open")end
		assert(Policy.presentCommittedHatch("saved-result",7,current,close,open))
		assert(not menu and not roomFlag and shop and table.concat(calls,",")=="close,open" and current.id=="saved-result")
		shop=false;assert(Policy.presentCommittedHatch("saved-result",7,current,close,open) and current.id=="saved-result")
		local count=#calls
		assert(not Policy.presentCommittedHatch("old-result",7,current,close,open))
		assert(not Policy.presentCommittedHatch("saved-result",6,current,close,open) and #calls==count)
	end)
	return{passed=#cases,cases=cases}
end
