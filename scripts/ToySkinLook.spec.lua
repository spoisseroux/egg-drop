-- Toy colours, the client half (rotation slice 2 lane C; ROTATION-2-BRIEF 1, ARCH-REVIEW-ROTATION-2 8). ToySkinLook is
-- the client's one reader of Shared.ToySkins: the 24 rows as the brief's table (the one tinted part, the hexes, the
-- names), a skin drawn only on its own toy, the sparkler's spark colours, the snapshot readers (switch, owned, worn), the
-- public field's whitelist for other players, the swatch row (the original first, owned colours only), and the wear
-- queue: one wear in flight, the last tap wins, a Retrying answer frees the queue, a refusal says so and still sends the
-- tap waiting behind it, a saved colour stays shown until the snapshot catches up.
-- Offline: scripts/run_dash_server_specs.py (client). Studio: require(PlayerScripts.Client.ZZSpecs.ToySkinLook)(Client).
return function(client)
	local Look=require(client.ToySkinLook)
	local Skins=require(game:GetService("ReplicatedStorage").Shared.ToySkins)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end

	local brief={
		ball={"FeltBall",{sky="#5CBEF5",bubblegum="#FF86C8",midnight="#2F2C7C",gold="#F0B429"}},
		bone={"BoneBody",{mint="#7FE0CF",grape="#9B7BE8",midnight="#2F2C7C",gold="#F0B429"}},
		sparkler={"IndigoGrip",{cherry="#E9574C",mint="#7FE0CF",grape="#9B7BE8",rosegold="#F2A0A8"}},
		wobble_top={"TealBody",{cherry="#E9574C",grape="#9B7BE8",midnight="#2F2C7C",gold="#F0B429"}},
		squeaky_carrot={"CarrotBody",{butter="#FFD86B",grape="#9B7BE8",snow="#F4F6FB",gold="#F0B429"}},
		pocket_deck={"DeckShell",{sky="#5CBEF5",bubblegum="#FF86C8",midnight="#2F2C7C",gold="#F0B429"}},
	}

	test("the rows: 6 toys x 4 colours, the brief's part and hex, valid ids, '<Colour> <Toy>' names",function()
		local count,perToy=0,{}
		for _,id in ipairs(Skins.Order)do
			local row=assert(Look.row(id),id)
			count+=1;perToy[row.toy]=(perToy[row.toy]or 0)+1
			local want=assert(brief[row.toy],row.toy)
			assert(row.part==want[1]and Look.Parts[row.toy]==want[1],"one named part: "..id)
			local colour=string.sub(id,#row.toy+2)
			assert(want[2][colour]==row.hex,"hex "..id.." "..row.hex)
			assert(Look.validId(id)and #id<=32)
			assert(Look.Original[row.toy],"the original is the first swatch, never a row")
		end
		assert(count==24)
		for toy in pairs(brief)do assert(perToy[toy]==4,toy)end
		assert(Look.row("ball_sky").name=="Sky Ball"and Look.row("squeaky_carrot_grape").name=="Purple Carrot")
		assert(Look.row("sparkler_rosegold").name=="Rose Gold Sparkler")
	end)

	test("a skin draws only on its own toy and only on its named part; anything else is the original",function()
		local sky=assert(Look.skin("ball","ball_sky"))
		assert(Look.skin("pocket_deck","ball_sky")==nil,"another toy's skin")
		assert(Look.skin("ball","none")==nil and Look.skin("ball","ball_plaid")==nil and Look.skin("ball",nil)==nil)
		assert(Look.skin("ball","Ball_Sky")==nil and Look.skin("ball",string.rep("a",33))==nil and Look.skin("ball",7)==nil)
		local base=Color3.fromHex("#D0E83A");local seam=Color3.fromHex("#FCFBEF")
		assert(Look.tint(sky,"FeltBall",base)==sky.color,"the felt takes the colour")
		assert(Look.tint(sky,"Seam",seam)==seam,"the seam keeps its white")
		assert(Look.tint(nil,"FeltBall",base)==base)
		local deck=assert(Look.skin("pocket_deck","pocket_deck_midnight"))
		for _,name in ipairs({"DeckBezel","DeckScreen","DeckPad","DeckButtonA","DeckButtonB"})do
			assert(Look.tint(deck,name,base)==base,"the deck keeps its "..name)
		end
	end)

	test("the sparkler's sparks: the skin colour toward white, then the colour; the original keeps its warm sparks",function()
		assert(Look.sparks(nil)==nil)
		local first,last=Look.sparks(Look.skin("sparkler","sparkler_cherry"))
		assert(typeof(first)=="Color3"and typeof(last)=="Color3")
		local cherry=Color3.fromHex("#E9574C")
		assert(math.abs(last.R-cherry.R)<1e-6 and math.abs(last.G-cherry.G)<1e-6 and math.abs(last.B-cherry.B)<1e-6 and Look.SparkWhite==.6)
	end)

	local function state(owned,worn,off)
		return {rack={toy={owned=owned,worn=worn,off=off}},toyUnlocks={ball=true,sparkler=true}}
	end
	test("the snapshot: on only with rack.toy, owned as a map or a list, worn only as a skin of that toy",function()
		assert(not Look.on({})and not Look.on({rack={}})and not Look.on(state({},{},true)))
		local s=state({ball_sky=true,ball_gold=true,ball_midnight=false},{ball="ball_gold",sparkler="ball_sky",bone="nope"})
		assert(Look.on(s))
		local owned=Look.owned(s);assert(owned.ball_sky and owned.ball_gold and not owned.ball_midnight)
		assert(Look.owned(state({"bone_mint"},{})).bone_mint,"a list is read too")
		assert(Look.worn(s,"ball")=="ball_gold")
		assert(Look.worn(s,"sparkler")==nil and Look.worn(s,"bone")==nil,"another toy's skin or an unknown id: the original")
		local map=Look.wornMap(s);assert(map.ball=="ball_gold"and map.sparkler==nil)
		assert(Look.worn({},"ball")==nil)
	end)

	test("appearances: the owner's toySkins map first, the public toySkin only for its own toy",function()
		assert(Look.forAppearance({toyId="ball",toySkin="ball_sky"},"ball")=="ball_sky")
		assert(Look.forAppearance({toyId="ball",toySkin="ball_sky"},"bone")==nil,"a preview of another toy")
		assert(Look.forAppearance({toyId="ball",toySkin="ball_sky",toySkins={bone="bone_mint"}},"bone")=="bone_mint")
		assert(Look.forAppearance({toyId="ball",toySkins={ball="bone_mint"}},"ball")==nil)
		assert(Look.forAppearance(nil,"ball")==nil)
		-- GardenClient's whitelist (other players' toys).
		assert(Look.publicSkin("ball","ball_midnight")=="ball_midnight")
		assert(Look.publicSkin("ball","bone_mint")==nil and Look.publicSkin("none","ball_sky")==nil and Look.publicSkin("ball","none")==nil)
		assert(Look.publicSkin("ball","<script>")==nil and Look.publicSkin("ball",{})==nil and Look.publicSkin("ball",string.rep("b",40))==nil)
	end)

	test("the swatch row: none while off, the original first, then owned colours of this toy in ToySkins order",function()
		assert(Look.swatches({},"ball")==nil)
		assert(Look.swatches(state({},{}),"none")==nil,"no colours for None")
		local s=state({ball_gold=true,ball_sky=true,bone_mint=true},{})
		local row=assert(Look.swatches(s,"ball","Original"))
		assert(#row==3 and row[1].id=="none"and row[1].original and row[1].name=="Original")
		assert(row[1].hex==Look.Original.ball)
		assert(row[2].id=="ball_sky"and row[3].id=="ball_gold","ToySkins order, owned only")
		assert(#Look.swatches(state({},{}),"ball")==1,"no owned colour: the original alone (the panel hides a row of one)")
	end)

	test("the wear queue: one in flight, the last tap wins, a Retrying answer frees it, a refusal still sends the waiting tap",function()
		local sent,n={},0
		local q=Look.queue({id=function()n+=1;return "w"..n end,send=function(o)table.insert(sent,o)end})
		local worn={}
		assert(q:tap("ball","ball_sky",worn)and #sent==1 and sent[1].action=="toySkinWear"and sent[1].toyId=="ball"and sent[1].skinId=="ball_sky")
		assert(q:busy())
		assert(q:tap("ball","ball_gold",worn)and #sent==1,"waits")
		assert(q:tap("ball","none",worn)and #sent==1,"replaces the waiting tap")
		assert(q:shown(worn).ball==nil,"shown: the last tap (the original)")
		q:tap("ball","ball_gold",worn) -- the last tap
		assert(q:shown(worn).ball=="ball_gold")
		assert(not q:result({action="wearableEquip",id="w1",status="Saved"},worn),"another action")
		assert(not q:result({action="toySkinWear",id="nope",status="Saved"},worn),"not the one in flight")
		assert(q:result({action="toySkinWear",id="w1",status="Retrying"},worn),"Retrying: the server's last word")
		assert(#sent==2 and sent[2].skinId=="ball_gold","the waiting tap goes out")
		assert(q:result({action="toySkinWear",id=sent[2].id,status="Saved"},worn)and not q:busy())
		assert(q:shown(worn).ball=="ball_gold","saved: shown before the snapshot")
		q:sync({ball="ball_gold"});assert(next(q.saved)==nil,"caught up")
		worn={ball="ball_gold"}
		assert(not q:tap("ball","ball_gold",worn),"wearing it already: nothing sent")
		assert(not q:tap("ball","bone_mint",worn)and not q:tap("ball","ball_plaid",worn),"not a skin of this toy")
		-- A refusal: the message, the colour back, the waiting tap still sent.
		q:tap("ball","ball_sky",worn);q:tap("sparkler","sparkler_grape",worn)
		local refused=sent[#sent]
		assert(q:result({action="toySkinWear",id=refused.id,status="Refused",reason="NotOwned"},worn))
		assert(q.message=="NotOwned"and sent[#sent].toyId=="sparkler")
		assert(q:shown(worn).ball=="ball_gold","the refused colour is undone")
		-- A waiting tap that changes nothing by the time it would go is dropped.
		q:clear();local before=#sent
		q:tap("ball","ball_sky",worn);q:tap("ball","ball_gold",worn)
		assert(q:shown(worn).ball=="ball_gold")
		q:tap("ball","ball_sky",worn) -- shown is ball_gold, so this is a change: it waits
		q:tap("ball","ball_gold",worn) -- back: replaces the waiting tap with a no-op
		assert(q:result({action="toySkinWear",id=sent[before+1].id,status="Refused"},worn))
		assert(#sent==before+1 and not q:busy(),"back to what is worn: nothing sent")
	end)
	return {passed=#cases,cases=cases}
end
