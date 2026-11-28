-- The lessons remembered across versions (ARCH-REVIEW-TEACH: "the new field must be ignored and preserved by older
-- servers"). Offline only (scripts/run_dash_server_specs.py), where `offline` holds the new tree, the base commit and the
-- live build. A save with `teachMask` (graduated, two latches, a bit from a later build) and `teachParked` loads on the
-- live build and on the base commit, which save over it (a purchase, a coach card) and keep both fields as they were;
-- this build loads it back still graduated, with every bit.
return function(_,offline)
	local new,base,live=offline.new,offline.base,offline.live
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function open(tree,db,c)
		local H=tree.require(tree.server.HatchProgress)
		local adapter={now=function()return c.now end,guid=function()c.serial+=1;return "tx"..c.serial end,random=function()return .37 end,wait=function()end,
			update=function(key,transform)local value=transform(copy(db[key]));if value then db[key]=copy(value)end;return copy(value)end}
		return H.load(1,{},adapter),H
	end
	local function later(db,c)c.now+=200;db.player_1.hatching.lease.expiresAt=0 end
	local Teach=new.require(new.shared.TeachMarks)
	local Onboard=new.require(new.shared.Onboard)
	local mask=Teach.with(Teach.with(Teach.with(0,"done"),"dress"),"deckTour")+2^29
	local parked=2^6+2^7
	for _,pair in ipairs({{"live",live},{"base",base}})do
		local label,old=pair[1],pair[2]
		test("teachMask and teachParked load on the "..label.." build, which saves over them and keeps both; this build reads them back",function()
			Onboard.inject({flags={OnboardingV3=true},studio=true})
			local db,c={},{now=1700000000,serial=0}
			local h,H=open(new,db,c)
			assert(h.status=="Ready"and H.grantStarter(h,true,true))
			assert(H.command(h,"ack",h.state.lastHatch.id,h.state.revision))
			assert(H.coachMark(h,0,mask,parked))
			H.release(h);later(db,c)
			local stars=db.player_1.hatching.nectar
			local o,OH=open(old,db,c)
			assert(o.status=="Ready",label.." loads it: "..tostring(o.status))
			assert(OH.grantPurchase(o,"fund-old",3,false),label.." saves over it")
			assert(OH.coachMark(o,2^5),label.." writes a coach card over it")
			assert(db.player_1.hatching.teachMask==mask and db.player_1.hatching.teachParked==parked,label.." keeps both fields")
			OH.release(o);later(db,c)
			local back,BH=open(new,db,c)
			assert(back.status=="Ready"and back.state.nectar==stars+3)
			assert(Teach.covers(back.state.teachMask,mask)and back.state.teachParked==parked,"every bit back, the later build's too")
			assert(Teach.has(BH.public(back).teachMask,"done"),"still graduated")
			Onboard.inject(nil)
		end)
	end
	return {passed=#cases,cases=cases}
end
