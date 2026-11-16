-- Customization Egg catalogue (plan 2026-11-16 §1, §4, §7): the integer odds tables, the roll
-- edges, pity, restricted fixed order, finish steps and the frozen stored bounds. Pure, no saves.
-- Usage (Server or Client): require(<...>.ZZSpecs.LookEggCatalog)()
return function()
	local Shared=game:GetService("ReplicatedStorage").Shared
	local C=require(Shared.LookEggCatalog)
	local Charms=require(Shared.PetCharmCatalog)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local EPS=1e-9

	test("published order, unique ids and frozen lookFound bits",function()
		assert(table.concat(C.ItemOrder,",")=="rose,tide,citrus,iris,gloss,matte,jelly,charm_dot,charm_ring,charm_pebble")
		assert(table.concat(C.EggShapes,",")=="dot,ring,pebble"and C.EggShapes==Charms.EggShapes)
		for index,id in ipairs(C.ItemOrder)do assert(C.bit(id)==bit32.lshift(1,index-1),id)end
		assert(C.bit("charm_pebble")==512 and C.FoundLimit==1023)
		assert(C.kind("rose")=="hue"and C.kind("gloss")=="finish"and C.kind("jelly")=="finish"and C.kind("charm_ring")=="charm")
		assert(C.kind("heart")==nil and C.kind("charm_heart")==nil and C.kind("charm_star")==nil and C.kind("reset")==nil,"Heart, Star, Leaf and Reset are never in the pool")
		assert(C.shape("charm_dot")=="dot"and C.charmItem("pebble")=="charm_pebble"and C.charmItem("heart")==nil)
		assert(C.EnablePurchases==true,"slice 4: on sale, gated by verified templates")
	end)

	test("every table has integer cells and sums to exactly 100",function()
		for m=0,3 do
			local missing={};for i=1,m do missing[i]=C.EggShapes[i]end
			local rows=C.odds(missing);local total=0
			assert(#rows==7+m,"rows for M="..m)
			for _,row in ipairs(rows)do assert(row.percent%1==0 and row.percent>=0,row.id);total+=row.percent end
			assert(total==100,"M="..m.." sums to "..total)
		end
		local three=C.odds({"dot","ring","pebble"})
		assert(three[1].id=="rose"and three[1].percent==17 and three[5].id=="gloss"and three[5].percent==10 and three[7].id=="jelly"and three[7].percent==6)
		assert(three[8].id=="charm_dot"and three[8].percent==2 and three[10].id=="charm_pebble")
		local none=C.odds({});assert(#none==7 and none[5].percent==13 and none[6].percent==13)
		local ring=C.odds({"ring"});assert(#ring==8 and ring[8].id=="charm_ring"and ring[5].percent==12)
	end)

	test("odds rows never list an owned charm; malformed missing lists are refused",function()
		for _,bad in ipairs({{"ring","dot"},{"dot","dot"},{"heart"},{"dot","ring","pebble","dot"},"dot",{[2]="ring"}})do
			assert(C.odds(bad)==nil and not C.validMissing(bad),"refused")
		end
		assert(table.concat(C.missing({dot=true}),",")=="ring,pebble")
		assert(#C.missing({dot=true,ring=true,pebble=true})==0 and #C.missing(nil)==3 and #C.missing({heart=true})==3)
	end)

	test("roll boundaries at every cumulative edge, unit 0 and 1-eps",function()
		for m=0,3 do
			local missing={};for i=1,m do missing[i]=C.EggShapes[i]end
			local rows=C.odds(missing);local cumulative=0
			for _,row in ipairs(rows)do
				if row.percent>0 then
					assert(C.roll(cumulative/100+EPS,missing,0)==row.id,"start of "..row.id.." M="..m)
					assert(C.roll((cumulative+row.percent)/100-EPS,missing,0)==row.id,"end of "..row.id.." M="..m)
				end
				cumulative+=row.percent
			end
			assert(C.roll(0,missing,0)=="rose"and C.roll(1-EPS,missing,0)==rows[#rows].id)
		end
		assert(C.roll(1,{},0)==nil and C.roll(-.1,{},0)==nil and C.roll(0/0,{},0)==nil and C.roll(.5,{"ring","dot"},0)==nil and C.roll(.5,{},-1)==nil)
	end)

	test("pity forces a charm after 14 misses, uniform over missing shapes, never when M = 0",function()
		assert(C.PityAt==15)
		local all={"dot","ring","pebble"}
		assert(not C.pityDue(all,13)and C.pityDue(all,14)and C.pityDue(all,20)and not C.pityDue({},14))
		assert(C.roll(0,all,13)=="rose","13 misses still rolls the table")
		assert(C.roll(0,all,14)=="charm_dot"and C.roll(.34,all,14)=="charm_ring"and C.roll(1-EPS,all,14)=="charm_pebble")
		assert(C.roll(.9,{"pebble"},14)=="charm_pebble")
		assert(C.roll(0,{},14)=="rose"and C.roll(.99,{},40)=="jelly","no charm once all are owned")
		assert(C.pityLeft(all,0)==15 and C.pityLeft(all,14)==1 and C.pityLeft({},3)==nil)
	end)

	test("restricted fixed order: every 12th egg is the first missing charm, else the fewest-held jar",function()
		local all={"dot","ring","pebble"}
		assert(C.fixedNext(all,10,{},{})=="rose")
		assert(C.fixedNext(all,11,{},{})=="charm_dot"and C.fixedNext({"ring","pebble"},11,{},{})=="charm_ring")
		assert(C.fixedNext({},11,{},{})=="rose","no charm once all are owned")
		local hue={rose=2,tide=1,citrus=1,iris=3};local finish={gloss=1,matte=0,jelly=0}
		assert(C.fixedNext(all,0,hue,finish)=="matte","fewest held, ties to the first in JarOrder")
		finish.matte=1;finish.jelly=1;assert(C.fixedNext(all,0,hue,finish)=="tide")
		local full={rose=C.StackLimit,tide=C.StackLimit,citrus=C.StackLimit,iris=C.StackLimit}
		assert(C.fixedNext({},0,full,{gloss=C.StackLimit,matte=C.StackLimit,jelly=C.StackLimit})==nil)
		assert(C.fixedNext({"ring"},0,full,{gloss=C.StackLimit,matte=C.StackLimit,jelly=C.StackLimit})=="charm_ring")
	end)

	test("finish steps: Gloss and Matte cancel on one axis, Jelly is a second axis, refusals at the caps",function()
		local function row(s,j)return {sheen=s,jelly=j}end
		assert(C.step(row(0,0),"gloss").sheen==1 and C.step(row(-2,1),"gloss").sheen==-1 and C.step(row(-2,1),"gloss").jelly==1)
		assert(C.step(row(1,0),"matte").sheen==0 and C.step(row(0,2),"jelly").jelly==3)
		local after,why=C.step(row(3,0),"gloss");assert(after==nil and why=="MaxSheen")
		after,why=C.step(row(-3,0),"matte");assert(after==nil and why=="MaxSheen")
		after,why=C.step(row(0,3),"jelly");assert(after==nil and why=="MaxJelly")
		-- A display cap of 2 clamps a stored 3 at use: it is never rejected.
		after,why=C.step(row(3,0),"gloss",2);assert(after==nil and why=="MaxSheen")
		assert(C.step(row(3,0),"matte",2).sheen==1)
		assert(C.stepValid(row(3,0),row(1,0),"matte"),"a capped step written by another build stays valid")
		assert(C.stepValid(row(0,0),row(1,0),"gloss")and not C.stepValid(row(0,0),row(2,0),"gloss")and not C.stepValid(row(0,0),row(0,1),"gloss"))
		local looks=0;for s=-3,3 do for j=0,3 do assert(C.validFinish(row(s,j)));looks+=1 end end;assert(looks==28)
		for _,bad in ipairs({row(4,0),row(0,4),row(-4,0),row(0,-1),row(.5,0),{sheen=0},{sheen=0,jelly=0,gloss=1}})do assert(not C.validFinish(bad))end
	end)

	test("stored bounds are frozen and separate from the tunables",function()
		assert(C.MissesLimit==63 and C.SheenLimit==3 and C.JellyLimit==3 and C.FoundLimit==1023)
		assert(C.MissesLimit>=C.PityAt-1 and C.SheenStops<=C.SheenLimit and C.JellyStops<=C.JellyLimit)
		assert(C.Prices[C.Price]==true and C.PoolVersions[C.PoolVersion]==true)
		assert(C.validMisses(0)and C.validMisses(63)and not C.validMisses(64)and not C.validMisses(-1)and not C.validMisses(1.5))
		assert(C.selectionMode(false)=="random"and C.selectionMode(true)=="fixed"and C.selectionMode(nil)=="fixed","unknown policy fails closed")
	end)

	test("the egg is available only when every sheen stop and the Jelly pair are verified",function()
		local pack=Instance.new("Folder");local two=Instance.new("Folder")
		local function add(folder,name)
			local s=Instance.new("SurfaceAppearance");s.Name=name;s:SetAttribute("NativeVerified",true);s:SetAttribute("MaterialVersion",1);s:SetAttribute("MaterialProfile",name);s.Parent=folder
		end
		assert(not C.capable(pack,two))
		for stop=-C.SheenStops,C.SheenStops do
			local profile=C.SheenProfiles[stop]
			if stop~=0 then add(pack,profile);add(two,"BodyTwoTone"..string.sub(profile,5))end
		end
		assert(not C.capable(pack,two),"Jelly templates still missing")
		add(pack,C.JellyProfile);add(two,C.JellyTwoToneProfile)
		assert(C.capable(pack,two)and C.available(pack,two),"capable and on sale")
		pack:FindFirstChild(C.SheenProfiles[-1]):SetAttribute("NativeVerified",false)
		assert(not C.available(pack,two),"one unverified stop closes the whole egg")
		pack:Destroy();two:Destroy()
	end)

	return{passed=#cases,cases=cases}
end
