-- The welcome gift across versions (ONBOARDING-V3-BRIEF section 3): old builds load the flag. Offline only
-- (scripts/run_dash_server_specs.py), where `offline` holds the new tree, the base commit and the live build.
-- A save owed the gift (welcomeGift = 0) and one already paid (5) load on the live build and on the base commit with
-- their Stars intact; they save over it and keep the field; this build loads it back: the owed one still pays once,
-- the paid one never pays again.
return function(_,offline)
	local new,base,live=offline.new,offline.base,offline.live
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function open(tree,db,c)
		local H=tree.require(tree.server.HatchProgress)
		local adapter={now=function()return c.now end,guid=function()c.serial+=1;return "wx"..c.serial end,random=function()return .37 end,wait=function()end,
			update=function(key,transform)local value=transform(copy(db[key]));if value then db[key]=copy(value)end;return copy(value)end}
		return H.load(1,{},adapter),H
	end
	local function later(db,c)c.now+=200;db.player_1.hatching.lease.expiresAt=0 end
	local function facts(db)
		local s=db.player_1.hatching
		s.coachMask=2^20 -- needHi
		s.nest={at=1700000000,n=0,tucked=true,pet="pip"}
		s.stats.rounds=1 -- one field round after the Bear (the Welcome round is not counted)
	end

	for _,pair in ipairs({{"live",live},{"base",base}})do
		local label,old=pair[1],pair[2]
		for _,paidFirst in ipairs({false,true})do
			local what=if paidFirst then "a paid gift (5)"else "an owed gift (0)"
			test(what.." loads on the "..label.." build, which saves over it and keeps the field; this build pays it at most once",function()
				local db,c={},{now=1700000000,serial=0}
				local h,H=open(new,db,c)
				assert(h.status=="Ready")
				assert(H.grantStarter(h,true)and h.state.welcomeGift==0)
				assert(H.command(h,"ack",h.state.lastHatch.id,h.state.revision))
				H.release(h);later(db,c);facts(db)
				if paidFirst then
					h,H=open(new,db,c)
					assert(H.welcomeGift(h,{nest=true})and h.state.welcomeGift==5)
					H.release(h);later(db,c)
				end
				local stars=db.player_1.hatching.nectar
				local o,OH=open(old,db,c)
				assert(o.status=="Ready",label.." loads it: "..tostring(o.status))
				assert(o.state.nectar==stars,label.." keeps the Stars")
				assert(OH.grantPurchase(o,"fund-old",3,false),label.." saves over it")
				assert(db.player_1.hatching.welcomeGift==(if paidFirst then 5 else 0),label.." keeps the field")
				OH.release(o);later(db,c)
				local back,BH=open(new,db,c)
				assert(back.status=="Ready"and back.state.nectar==stars+3)
				local ok,why=BH.welcomeGift(back,{nest=true})
				if paidFirst then assert(ok and why=="AlreadyGranted"and back.state.nectar==stars+3,"never again")
				else assert(ok and why=="Saved"and back.state.nectar==stars+8 and back.state.welcomeGift==5,"owed: paid now, once")end
				local again,whyAgain=BH.welcomeGift(back,{nest=true})
				assert(again and whyAgain=="AlreadyGranted")
			end)
		end
	end
	return {passed=#cases,cases=cases}
end
