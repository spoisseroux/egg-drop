-- Animated finishes on the Outfit Egg's sparkle picks (lane C of the daily rack; ROTATION-BRIEF 1 "Sparkle picks",
-- ARCH-REVIEW-ROTATION 12). The pure rules of WearableFinish: which rows move (only the five legendary rows, by their
-- finish), the still colour (the row's own mid `color`), the shimmer's 2.4 s sine between its two hexes (smooth, ends
-- at each hex), the rainbow's one pastel hue turn in 6 s (S .55, V 1), the sparkle emitter's mode (live; reduced: in
-- place), Reduced Motion (still colour, a static sparkle), and the stepper's pick (garden pets in the workspace only,
-- never a ViewportFrame clone, at most 24 parts).
-- Offline: scripts/run_dash_server_specs.py (client). Studio: require(PlayerScripts.Client.ZZSpecs.WearableFinish)(Client).
return function(client)
	local Finish=require(client.WearableFinish)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Variants=require(Shared.WearableVariants)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b)return math.abs(a-b)<1e-6 end

	test("only the legendary rows have a finish; every other row is still",function()
		local finishes=0
		for _,row in ipairs(Variants.Rows)do
			local kind=Finish.kind(row)
			if row.rarity=="legendary"then
				finishes+=1;assert(kind==row.finish,"finish "..row.id)
			else assert(kind==nil,"still "..row.id)end
		end
		assert(finishes==5,"five sparkle picks tonight")
		local by=Variants.ById
		assert(Finish.kind(by.beanie_rainbow)=="rainbow"and Finish.kind(by.bowtail_rainbow)=="rainbow")
		assert(Finish.kind(by.hoodie_aurora)=="shimmer"and Finish.kind(by.partyhat_aurora)=="shimmer")
		assert(Finish.kind(by.flowercrown_stardust)=="sparkle")
		assert(Finish.kind(nil)==nil and Finish.kind({finish="neon"})==nil,"an unknown finish is still")
	end)

	test("the still colour is the row's own mid colour",function()
		local still=Finish.still(Variants.ById.hoodie_aurora)
		assert(near(still.R,0x92/255)and near(still.G,0xAE/255)and near(still.B,0xF8/255))
		local bad=Finish.still({color="nope"});assert(bad.R==1 and bad.G==1 and bad.B==1,"a bad hex falls back to white")
	end)

	test("shimmer: a 2.4 s sine from the first hex to the second and back, never a jump",function()
		assert(Finish.ShimmerPeriod==2.4)
		assert(near(Finish.blend(0),0)and near(Finish.blend(1.2),1)and near(Finish.blend(2.4),0),"ends at each hex")
		assert(near(Finish.blend(.6),.5)and near(Finish.blend(1.8),.5))
		local last=Finish.blend(0)
		for i=1,240 do
			local w=Finish.blend(i*.01)
			assert(w>=0 and w<=1 and math.abs(w-last)<.02,"smooth at 10 ms steps");last=w
		end
		assert(near(Finish.blend(0/0),0),"a NaN time is time 0")
	end)

	test("rainbow: one pastel hue turn in 6 s (S .55, V 1), never strobing",function()
		assert(Finish.RainbowPeriod==6 and Finish.RainbowSaturation==.55 and Finish.RainbowValue==1)
		assert(near(Finish.hue(0),0)and near(Finish.hue(3),.5)and near(Finish.hue(6),0)and near(Finish.hue(7.5),.25))
		-- at the stepper's 10 Hz the hue moves 1/60 of a turn a tick
		assert(near(Finish.hue(.1)-Finish.hue(0),1/60))
		local c=Finish.color(Variants.ById.beanie_rainbow,3,false)
		-- (the offline Color3.fromHSV mock keeps h, s, v in R, G, B)
		assert(near(c.R,.5)and near(c.G,.55)and near(c.B,1))
	end)

	test("Reduced Motion: the still colour, nothing moves, the sparkle stays (in place)",function()
		for _,id in ipairs({"beanie_rainbow","hoodie_aurora","flowercrown_stardust"})do
			local row=Variants.ById[id]
			assert(not Finish.moves(row,true),id.." still")
			local c,s=Finish.color(row,1.3,true),Finish.still(row)
			assert(near(c.R,s.R)and near(c.G,s.G)and near(c.B,s.B),id.." still colour")
		end
		assert(Finish.moves(Variants.ById.beanie_rainbow,false)and Finish.moves(Variants.ById.hoodie_aurora,false))
		assert(not Finish.moves(Variants.ById.flowercrown_stardust,false),"sparkle keeps its colour")
		assert(Finish.sparkle(Variants.ById.flowercrown_stardust,false)=="live")
		assert(Finish.sparkle(Variants.ById.flowercrown_stardust,true)=="still","a static sparkle under reduced motion")
		assert(Finish.sparkle(Variants.ById.beanie_rainbow,false)==nil,"no particles on the colour finishes")
		assert(Finish.SparkleRate==3 and Finish.SparkleColor=="#F4F6FB")
	end)

	test("the stepper moves garden pets in the workspace only, never a viewport clone, at most 24 parts",function()
		assert(Finish.MaxParts==24 and Finish.Hz==10)
		local row=Variants.ById.hoodie_aurora
		local entries={
			{row=row,world=false,live=false}, -- a Wardrobe card preview
			{row=row,world=true,live=false}, -- a garden pet not in the workspace yet
			{row=Variants.ById.beanie_sky,world=true,live=true}, -- a still row
		}
		for i=1,30 do table.insert(entries,{row=row,world=true,live=true,n=i})end
		local picked=Finish.pick(entries)
		assert(#picked==24,"capped")
		for i,entry in ipairs(picked)do assert(entry.world and entry.live and entry.n==i,"in order, garden only")end
		assert(#Finish.pick(entries,4)==4 and #Finish.pick({})==0 and #Finish.pick(nil)==0)
	end)

	return {passed=#cases,cases=cases}
end
