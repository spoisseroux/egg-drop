return function(client)
	local Notice=require(client.SaveNotice)
	local cases={};local function test(name,run)run();table.insert(cases,name)end
	test("retryable load states promise automatic retry without asking for rejoin",function()
		for _,status in ipairs({"Temporary","Unavailable"})do
			local notice=Notice.resolve(nil,status)
			assert(notice.short=="Retrying load" and notice.detail:find("automatically",1,true) and not notice.detail:lower():find("rejoin",1,true))
		end
	end)
	test("session wait save retry and terminal states keep distinct truthful instructions",function()
		assert(Notice.resolve(nil,"Locked").detail:find("previous session",1,true))
		assert(Notice.resolve(nil,"Retrying").short=="Retrying save")
		local moved=Notice.resolve(nil,"SessionLost");assert(moved.terminal and moved.detail:find("Rejoin",1,true))
		local unreadable=Notice.resolve(nil,"InvalidData");assert(unreadable.terminal and not unreadable.detail:find("retry",1,true) and not unreadable.detail:find("Rejoin",1,true))
	end)
	test("blocking hatch status wins without discarding the profile source",function()
		local notice=Notice.resolve("Temporary",{status="Retrying"})
		assert(notice.origin=="hatch" and notice.code=="Retrying")
		assert(Notice.resolve("SessionLost",{status="Locked"}).code=="Locked")
	end)
	test("unknown hatch status cannot hide a recognized profile retry instruction",function()
		for _,status in ipairs({"Temporary","Retrying"})do
			local notice=Notice.resolve(status,{status="FutureStatus"})
			assert(notice.origin=="profile" and notice.code==status)
		end
		assert(Notice.resolve(nil,{status="FutureStatus"}).short=="Save unavailable")
	end)
	test("neutral hatch states never suppress profile load or save retry",function()
		for _,profile in ipairs({"Temporary","Retrying"})do for _,status in ipairs({"Busy","Ready","Pending","Released"})do
			local notice=Notice.resolve(profile,{status=status})
			assert(notice.origin=="profile" and notice.code==profile,status)
		end end
	end)
	test("recovery clears derived notice and never rewrites wallet result ID selection or command feedback",function()
		local state={status="Unavailable",nectar=6,revision=12,lastHatch={id="notice-pending",petId="pip"},selected="sprout",message="RevisionChanged"}
		assert(Notice.resolve(nil,state));state.status="Ready";assert(Notice.resolve(nil,state)==nil)
		assert(state.nectar==6 and state.revision==12 and state.lastHatch.id=="notice-pending" and state.selected=="sprout" and state.message=="RevisionChanged")
	end)
	test("terminal notices persist until an explicit source change without invented timers",function()
		for _,status in ipairs({"SessionLost","InvalidData"})do
			local key=Notice.resolve(nil,status).key
			for _=1,12 do assert(Notice.resolve(nil,status).key==key)end
		end
	end)
	test("one modal or room owner excludes every covered presentation",function()
		assert(Notice.owner({eggs=true,menu=true,modal=true})=="eggs")
		assert(Notice.owner({style=true,journal=true,mode="Room"})=="style")
		assert(Notice.owner({journal=true,menu=true})=="journal")
		assert(Notice.owner({menu=true,modal=true,recap=true})=="menu")
		assert(Notice.owner({modal=true,recap=true})=="recap" and Notice.owner({modal=true})=="welcome")
		assert(Notice.owner({mode="Room",focusing=true})=="focus" and Notice.owner({mode="Room"})=="roam")
		assert(Notice.owner({mode="Board"})=="board" and Notice.owner({native=true,eggs=true})==nil)
	end)
	test("compact wording changes copy without changing text size or save semantics",function()
		local notice=Notice.resolve(nil,"Retrying")
		local caption=Notice.caption(notice,function(value)return #value<=10 end)
		assert(caption=="Save retry" and notice.short=="Retrying save")
		assert(Notice.resolve(nil,{status="Ready",message="One moment…"})==nil)
	end)
	return{passed=#cases,cases=cases}
end
