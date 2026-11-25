-- Multi-site identity, reservations, membership and snapshot routing. Uses real GardenState,
-- no Players/DataStore/mesh services. Run with existing ParkDirector fixture suite in Edit.
return function(server)
	local Garden=require(server.GardenState)
	local Director=require(server.ParkDirector)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Park=require(Shared.ParkLayout)
	local Data=require(Shared.ParkPoseData)
	local Activities=require(Shared.ParkActivities)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function fixture(count)
		local state={now=1000,inputs={},finished={},busy={}}
		local function set(id,site)
			local at=site.Center+Vector3.new((id%3)-1,0,0)
			state.inputs[id]={petId="pip",owned=true,alive=true,characterId=1,petGeneration=0,mode="Room",yaw=0,charmVisible=true,anchor=at,position=at+Vector3.new(0,3,0)}
		end
		for id=1,count do set(id,if id%2==0 then Park.ById.grove else Park)end
		state.garden=Garden.new({now=function()return state.now end,sharedToyEnabled=false,validFocus=function()return true end})
		state.director=Director.attach(state.garden,{enabled=true,random=function()return .1 end,busy=function(id)return state.busy[id]end,
			finished=function(id,activity,session)table.insert(state.finished,{id=id,session=session,activity=activity})end})
		function state:step(seconds)for _=1,math.floor(seconds/.5)do self.now+=.5;self.garden:step(.5,self.inputs)end end
		state.place=set
		for _,site in pairs(state.director.sites)do site.nextGreetAt=math.huge end
		state:step(.5)
		return state
	end
	test("site data is independent, complete and rotated as one choreography",function()
		assert(#Park.Sites==2 and Park.ById.grove.Id=="grove")
		local g=Park.ById.grove;local d=Data.forSite(g)
		assert(d~=Data and d==Data.forSite("grove"),"immutable data cached per site")
		assert((d.Roots.SwingSet.Position-g.Equipment.swing.position).Magnitude<.001)
		assert(g.Benches[1].position.Z>g.Center.Z,"grove bench opens toward hub")
		if g.Natural then
			-- The Hollow (beta and Studio, ParkSites.spec): its path gap faces the dirt path east, its plaza gap the hub.
			assert(g.Gateways[1].id=="path"and g.Gateways[1].position.X>g.Center.X+13,"path gap opens east")
			assert(g.Gateways[2].id=="plaza"and g.Gateways[2].position.Z>g.Center.Z+13,"plaza gap opens toward the hub")
		else
			assert(g.Gateways[1].position.X>g.Center.X+14,"east path gateway does not rotate west")
		end
		assert(g.Slots.slide.chuteEnd.Z>g.Equipment.slide.position.Z,"slide choreography rotates together")
		for _,site in ipairs(Park.Sites)do
			assert(#site.SlotOrder==9 and site.member(site.Center,false))
			assert(Park.siteAt(site.Center,nil)==site)
			for _,id in ipairs(site.SlotOrder)do assert(site.inside(site.Slots[id].approach,1),id)end
		end
	end)
	test("same local slots have distinct sessions and route into exact site snapshot",function()
		local c=fixture(2);local one,two=c.garden.actors[1],c.garden.actors[2]
		one.park.nextPickAt=math.huge;two.park.nextPickAt=math.huge
		assert(one.park.parkId=="arrival"and two.park.parkId=="grove")
		assert(c.director:start(Activities.ById.swing,{"swing1"},{one},c.now))
		assert(not c.director:start(Activities.ById.swing,{"swing2"},{two},c.now),"wrong-site start refused")
		assert(c.director.sites.grove:start(Activities.ById.swing,{"swing1"},{two},c.now))
		assert(not c.director.sites.grove:start(Activities.ById.swing,{"swing2"},{two},c.now),"existing reservation cannot be overwritten")
		assert(one.park.session~=two.park.session,"session ids namespaced")
		local snapshot=c.garden:snapshot()
		assert(snapshot.actors["2"].parkId=="grove")
		assert(snapshot.park.sites.arrival.slots.swing1.ownerId==1 and snapshot.park.sites.grove.slots.swing1.ownerId==2)
		assert(snapshot.park.slots==snapshot.park.sites.arrival.slots,"legacy alias only arrival")
		assert(not c.director:eligible(two,c.now),"arrival does not schedule grove actor")
		c.place(1,Park.ById.grove);c:step(.5)
		assert(one.park.parkId=="grove"and c.director.sessions["arrival:1"]==nil,"old reservation released before reassignment")
		assert(c.director.sites.grove.sessions[two.park.session],"other site reservation untouched")
	end)
	test("twelve owners progress independently and releases never leak across sites",function()
		local c=fixture(12)
		for _=1,240 do
			c:step(.5)
			local seen={}
			for siteId,director in pairs(c.director.sites)do
				local slots={}
				for _,session in pairs(director.sessions)do
					for _,owner in ipairs(session.ownerIds)do
						local actor=c.garden.actors[owner]
						assert(actor.park.parkId==siteId and not seen[owner],"owner has one site reservation")
						assert(not slots[session.slots[owner]],"one slot per pet within site")
						slots[session.slots[owner]]=true;seen[owner]=true
					end
				end
			end
		end
		local finished={};for _,entry in ipairs(c.finished)do finished[entry.id]=true end
		for id=1,12 do assert(finished[id],"owner starved across sites: "..id)end
		c.busy[2]=true;c:step(.5)
		assert(c.garden.actors[2].park.session==nil,"contact releases grove reservation")
		c.garden:remove(2)
		for _,director in pairs(c.director.sites)do
			for _,session in pairs(director.sessions)do assert(not table.find(session.ownerIds,2))end
		end
	end)
	test("duo transition, focus, care and generation cleanup are confined to the correct site",function()
		local c=fixture(4)
		for _,actor in pairs(c.garden.actors)do actor.park.nextPickAt=math.huge end
		local two,four=c.garden.actors[2],c.garden.actors[4]
		local grove=c.director.sites.grove
		assert(not grove:start(Activities.ById.seesaw,{"seesaw1","seesaw2"},{two,two},c.now),"duplicate owner refused before mutation")
		assert(grove:start(Activities.ById.seesaw,{"seesaw1","seesaw2"},{two,four},c.now))
		local prior=two.park.session
		c.place(2,Park);c:step(.5)
		assert(two.park.parkId=="arrival"and grove.sessions[prior]==nil and four.park.session==nil)
		assert(c.director:start(Activities.ById.swing,{"swing1"},{two},c.now))
		local arrivalSession=two.park.session
		four.park.state="idle";four.park.nextPickAt=0
		assert(grove:start(Activities.ById.swing,{"swing1"},{four},c.now))
		four.generation+=1;c:step(.5)
		assert(four.park.session==nil and c.director.sessions[arrivalSession],"superseded grove actor cannot release arrival session")
		four.park.state="idle";four.park.nextPickAt=0
		assert(grove:start(Activities.ById.swing,{"swing2"},{four},c.now))
		assert(c.garden:focus(4,{kind="focus",seq=1,petId="pip",characterId=1,petGeneration=0}),"real focus intent must release grove slot")
		assert(four.mode=="Focus"and type(four.focusUntil)=="number","focus protocol establishes lease")
		c:step(.5)
		assert(four.park.session==nil and c.director.sessions[arrivalSession],"focus release isolated")
		assert(c.garden:focus(4,{kind="focusEnd",seq=1,petId="pip",characterId=1,petGeneration=0}))
		four.park.state="idle"
		assert(grove:start(Activities.ById.swing,{"swing1"},{four},c.now))
		four.care={state="Docked"};c:step(.5)
		assert(four.park==nil and next(grove.sessions)==nil and c.director.sessions[arrivalSession],"care cleanup isolated")
	end)

	return {passed=#cases,cases=cases}
end
