-- Paint pots across versions (PAINT-SHINE-DRESS-PLAN, the "no rollback floor" claim). Offline only
-- (scripts/run_dash_server_specs.py), where `offline` holds the new tree, the base commit and the live build. A save
-- with pots bought on this build loads on the live build and on the base commit with its jars and Stars intact; they
-- save over it and keep the paintPots field; this build loads it back and still replays the old buy as AlreadySaved.
return function(_,offline)
	local new,base,live=offline.new,offline.base,offline.live
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function open(tree,db,c)
		local H=tree.require(tree.server.HatchProgress)
		local adapter={now=function()return c.now end,guid=function()c.serial+=1;return "xv"..c.serial end,random=function()return .37 end,wait=function()end,
			update=function(key,transform)local value=transform(copy(db[key]));if value then db[key]=copy(value)end;return copy(value)end}
		return H.load(1,{rank=1},adapter),H
	end
	local function later(db,c)c.now+=200;db.player_1.hatching.lease.expiresAt=0 end

	for _,pair in ipairs({{"live",live},{"base",base}})do
		local label,old=pair[1],pair[2]
		test("a save with pots loads on the "..label.." build, which saves over it and keeps paintPots; this build replays the buy",function()
			local db,c={},{now=1700000000,serial=0}
			local h,H=open(new,db,c)
			assert(h.status=="Ready")
			assert(H.grantPurchase(h,"fund-xv",60,false))
			local r=h.state.revision
			local v={id=tostring(r)..":pot-xv",itemId="iris",price=15}
			local ok,why=H.potCommand(h,"potBuy",v,r);assert(ok and why=="Saved",tostring(why))
			local stars,jars=h.state.nectar,h.state.hueInventory.iris
			assert(jars==1 and db.player_1.hatching.paintPots and #db.player_1.hatching.paintPots.receipts==1)
			H.release(h);later(db,c)
			local o,OH=open(old,db,c)
			assert(o.status=="Ready",label.." loads it: "..tostring(o.status))
			assert(o.state.nectar==stars and o.state.hueInventory.iris==jars,label.." keeps the Stars and the jar")
			assert(OH.grantPurchase(o,"fund-old",5,false),label.." saves over it")
			assert(db.player_1.hatching.paintPots and db.player_1.hatching.paintPots.receipts[1].op==v.id,label.." keeps the field")
			OH.release(o);later(db,c)
			local back,BH=open(new,db,c)
			assert(back.status=="Ready"and back.state.nectar==stars+5 and back.state.hueInventory.iris==jars)
			local again,whyAgain=BH.potCommand(back,"potBuy",v,r);assert(again and whyAgain=="AlreadySaved"and back.state.nectar==stars+5)
		end)
	end
	return {passed=#cases,cases=cases}
end
