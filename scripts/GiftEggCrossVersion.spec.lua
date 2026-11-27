-- The gift chain across versions (GiftEggs): old builds load a gifted save. Offline only (scripts/run_dash_server_specs.py),
-- where `offline` holds the new tree, the base commit and the live build. A save owed the chain with the Paint, Toy and
-- Snack gifts given (a pot, a toy unlock and a Stat Egg receipt with source "gift", in fields every build accepts) loads
-- on the live build and on the base commit with its Stars, pot, toy and snack intact; they save over it and keep the
-- `gifts` field as it was; this build loads it back and never gives any of the three again.
return function(_,offline)
	local new,base,live=offline.new,offline.base,offline.live
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function same(a,b)
		if type(a)~=type(b)then return false end
		if type(a)~="table"then return a==b end
		for k,v in pairs(a)do if not same(v,b[k])then return false end end
		for k in pairs(b)do if a[k]==nil then return false end end
		return true
	end
	local function open(tree,db,c)
		local H=tree.require(tree.server.HatchProgress)
		local adapter={now=function()return c.now end,guid=function()c.serial+=1;return "gx"..c.serial end,random=function()return .37 end,wait=function()end,
			update=function(key,transform)local value=transform(copy(db[key]));if value then db[key]=copy(value)end;return copy(value)end}
		local h=H.load(1,{},adapter);h.restricted=false
		return h,H
	end
	local function later(db,c)c.now+=200;db.player_1.hatching.lease.expiresAt=0 end

	for _,pair in ipairs({{"live",live},{"base",base}})do
		local label,old=pair[1],pair[2]
		test("a save with all three gifts loads on the "..label.." build, which saves over it and keeps the field; this build never gives them again",function()
			local db,c={},{now=1700000000,serial=0}
			local h,H=open(new,db,c)
			assert(h.status=="Ready")
			assert(H.grantStarter(h,false,true)and h.state.gifts.v==1)
			assert(H.command(h,"ack",h.state.lastHatch.id,h.state.revision))
			H.release(h);later(db,c)
			local s=db.player_1.hatching
			s.nest={at=c.now,n=0,tucked=true,pet="pip"};s.stats.rounds=3;s.dash={ribbons={gold=0,silver=1,bronze=0,green=0}}
			h,H=open(new,db,c)
			assert(H.giftEgg(h,"paint",{nest=true}))
			assert(H.giftEgg(h,"toy",{nest=true}))
			local Stat=new.require(new.server.StatEggState)
			local K=new.require(new.shared.StatEggCatalog)
			local ok,why=H.statEggBuy(h,"gx-snack","pip",true,Stat.quoteKey(h.state,"pip",K.selectionMode(h.restricted)),true)
			assert(ok,tostring(why))
			H.release(h);later(db,c)
			local saved=copy(db.player_1.hatching)
			local o,OH=open(old,db,c)
			assert(o.status=="Ready",label.." loads it: "..tostring(o.status))
			assert(o.state.nectar==saved.nectar,label.." keeps the Stars")
			assert(same(o.state.hueInventory,saved.hueInventory),label.." keeps the pot")
			assert(same(o.state.toyUnlocks,saved.toyUnlocks),label.." keeps the toy")
			assert(#(o.state.snackPouch or {})==#saved.snackPouch,label.." keeps the snack")
			assert(OH.grantPurchase(o,"fund-old",3,false),label.." saves over it")
			assert(same(db.player_1.hatching.gifts,saved.gifts),label.." keeps the field")
			OH.release(o);later(db,c)
			local back,BH=open(new,db,c)
			assert(back.status=="Ready"and back.state.nectar==saved.nectar+3)
			local pots=copy(back.state.hueInventory)
			for _,kind in ipairs({"paint","toy"})do
				local again,whyAgain=BH.giftEgg(back,kind,{nest=true})
				assert(again and whyAgain=="AlreadyGranted",kind..": "..tostring(whyAgain))
			end
			local okS,whyS=BH.statEggBuy(back,"gx-snack-2","pip",true,Stat.quoteKey(back.state,"pip",K.selectionMode(back.restricted)),true)
			assert(not okS and whyS=="AlreadyGranted",tostring(whyS))
			assert(same(back.state.hueInventory,pots))
		end)
	end
	return {passed=#cases,cases=cases}
end
