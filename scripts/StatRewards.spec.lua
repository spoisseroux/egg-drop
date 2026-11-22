-- The reward track (StatRewards; V3-LEVELS-BUILD-PLAN-2026-11-22 S1) and the Heart tricks
-- (BondCatalog.trickLevel): rows per stat from their catalogues, only while their part is on; next,
-- upcoming, earned; scope 2.1's levels; nobody loses a trick. Pure shared data.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.StatRewards)(ServerScriptService.Server)
return function(_)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Rewards=require(Shared.StatRewards)
	local Levels=require(Shared.Levels)
	local Stats=require(Shared.StatCatalog)
	local Bond=require(Shared.BondCatalog)
	local Names=require(Shared.NameCatalog)
	local Plates=require(Shared.DeckThemes)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function set(...)
		local shipped={};for _,part in ipairs({...})do shipped[part]=true end
		Levels.inject({flags={LevelsMatter=true},studio=true,shipped=shipped})
	end
	local function ids(rows)local out={};for _,row in ipairs(rows)do table.insert(out,row.id)end;return table.concat(out,",")end
	local ok,problem=pcall(function()
		test("off: no rows, no next line, no tricks from Heart, no Book hints",function()
			Levels.inject({flags={},studio=true})
			for _,stat in ipairs(Stats.Order)do
				assert(#Rewards.forStat(stat)==0 and Rewards.next(stat,1)==nil and #Rewards.earned(stat,1,99)==0 and #Rewards.upcoming(stat,1,2)==0)
			end
			assert(#Rewards.totals()==0 and not Rewards.bookHints({pip={smarts=99}}))
			for xp=0,1000,25 do assert(Bond.trickLevel(xp,99)==Bond.level(xp),"tricks are Bond's alone")end
		end)
		test("each part brings only its own rows",function()
			for _,part in ipairs(Levels.Parts)do
				set(part)
				local n=0
				for _,stat in ipairs(Stats.Order)do for _,row in ipairs(Rewards.forStat(stat))do assert(row.part==part,row.id);n+=1 end end
				assert(n>0,part)
			end
			set("track");assert(#Rewards.totals()==0)
			set("gates");assert(ids(Rewards.totals())=="wardrobe_hoodie_starbloom,wardrobe_flowercrown_golden"and Rewards.totals()[1].total==150)
		end)
		test("all on: rows are unique, frozen, in level order, and point at a real copy key or name",function()
			set("track","gates","medals","juice")
			local seen,counts={},{}
			for _,stat in ipairs(Stats.Order)do
				local level=0
				for _,row in ipairs(Rewards.forStat(stat))do
					assert(not seen[row.id],"duplicate "..row.id);seen[row.id]=true
					assert(table.isfrozen(row)and row.stat==stat and row.level>=level and row.level>=1 and row.level<=99,row.id)
					assert(table.find(Rewards.Kinds,row.kind)and type(row.copy)=="string"and type(row.ref)=="string"and table.find(Levels.Parts,row.part),row.id)
					assert((row.kind=="gate")==(row.part=="gates"),row.id)
					level=row.level;counts[row.kind]=(counts[row.kind]or 0)+1
				end
				assert(Rewards.forStat(stat)==Rewards.forStat(stat),"cached")
			end
			-- 24 medals, 12 stat-gated recolours + Tangerine Pop (plates wait for textures), 10 tricks, 6 juice,
			-- 6 looks, Book hints, 18 stat name pieces + Champion on each stat.
			assert(counts.medal==24 and counts.gate==13+#Plates.Gated and counts.trick==10 and counts.juice==6 and counts.look==6 and counts.book==1 and counts.name==24)
			assert(Rewards.forStat("nope")[1]==nil and Rewards.next("nope",1)==nil and #Rewards.earned(nil,1,9)==0)
		end)
		test("the track (scope 2.1): a reward at 5 in every stat; each stat has a next line until 99",function()
			set("track","gates","medals","juice")
			for _,stat in ipairs(Stats.Order)do
				assert(Rewards.next(stat,1).level==5,stat.." at 5")
				for level=1,98 do assert(Rewards.next(stat,level),stat.." "..level)end
				assert(Rewards.next(stat,99)==nil and Rewards.next(stat,0/0)==nil)
				for _,medal in ipairs({25,50,75,99})do assert(Rewards.next(stat,medal-1).id=="medal_"..stat..({[25]="_sprout",[50]="_bloom",[75]="_fullBloom",[99]="_starbloom"})[medal],"the medal leads its level")end
			end
			local function at(stat,level)return ids(Rewards.earned(stat,level-1,level))end
			assert(at("heart",5)=="trick_sit"and at("heart",10)=="trick_wiggle,name_cuddle"and at("heart",15)=="wardrobe_beanie_rose"and at("heart",25)=="medal_heart_sprout,trick_cosy,name_sweetpea")
			assert(at("power",5)=="juice_confetti"and at("power",10)=="balls_tangerine_pop,name_bonk"and at("power",15)=="juice_fizz"and at("power",20)=="wardrobe_bands_tangerine"and at("power",30)=="juice_bubble"and at("power",35)=="wardrobe_blush_peach"and at("power",45)=="juice_comet")
			assert(at("energy",5)=="juice_ready"and at("energy",15)=="wardrobe_tee_sky"and at("energy",20)=="juice_lightning"and at("energy",35)=="wardrobe_sunhat_sky")
			assert(at("jump",5)=="swingCheer"and at("jump",10)=="swingHigh,name_boing"and at("jump",15)=="wardrobe_partyhat_lime"and at("jump",20)=="slideSpin"and at("jump",30)=="wardrobe_beanie_lime"and at("jump",40)=="seesawHop")
			assert(at("speed",5)=="longThrow"and at("speed",15)=="wardrobe_tee_periwinkle"and at("speed",20)=="catchHop"and at("speed",30)=="wardrobe_bowtail_periwinkle")
			assert(at("smarts",5)=="bookHints"and at("smarts",10)=="wardrobe_specs_orchid,name_hmm"and at("smarts",20)=="wardrobe_beads_orchid")
			assert(at("jump",99)=="medal_jump_starbloom,name_champion_jump")
			assert(#Rewards.upcoming("jump",1,2)==2 and ids(Rewards.upcoming("jump",1,2))=="swingCheer,swingHigh")
			assert(#Rewards.earned("jump",15,15)==0 and #Rewards.earned("jump",20,10)==0 and #Rewards.earned("jump",4,15)==4)
			-- Every stat name piece in NameCatalog is on the track at its own level.
			for _,piece in ipairs(Names.Pieces)do
				if piece.lane=="stat"then assert(string.find(at(piece.stat,piece.level),"name_"..piece.id,1,true),piece.id)end
			end
		end)
		test("text fills {name} from the catalogue or another copy key",function()
			set("track","gates","medals","juice")
			local function get(key,vars)return key..(if vars then "<"..tostring(vars.name)..">"else "")end
			local function by(stat,id)for _,row in ipairs(Rewards.forStat(stat))do if row.id==id then return row end end;error(id)end
			assert(Rewards.text(by("heart","trick_sit"),get)=="stats.reward.trick<bond.trick.l2>")
			assert(Rewards.text(by("heart","wardrobe_beanie_rose"),get)=="stats.reward.item<Rose Pom Beanie>")
			assert(Rewards.text(by("heart","name_cuddle"),get)=="stats.reward.name<Cuddle>")
			assert(Rewards.text(by("heart","medal_heart_sprout"),get)=="medal.sprout"and Rewards.text(by("speed","longThrow"),get)=="stats.reward.longThrow")
		end)
		test("Book hints: the best owned pet's Smarts 5",function()
			set("track")
			assert(Rewards.bookHints({pip={smarts=5}})and Rewards.bookHints({pip={smarts=1},blip={smarts=7}}))
			assert(not Rewards.bookHints({pip={smarts=4}})and not Rewards.bookHints({pip={smarts="9"}})and not Rewards.bookHints(nil)and not Rewards.bookHints({}))
			set("gates");assert(not Rewards.bookHints({pip={smarts=99}}))
		end)
		test("tricks: the better of Bond and Heart; a prefix, so nobody loses one; only ever rises",function()
			set("track")
			assert(table.concat(Bond.HeartLevels,",")=="1,5,10,14,18,22,25,28,31,33")
			assert(Bond.trickLevel(Bond.Thresholds[10],1)==10,"Bond 10, Heart 1 keeps ten tricks")
			assert(Bond.trickLevel(0,33)==10 and Bond.trickLevel(0,32)==9 and Bond.trickLevel(0,5)==2 and Bond.trickLevel(0,4)==1 and Bond.trickLevel(0,1)==1)
			for xp=0,1000,50 do
				local last=0
				for heart=1,99 do
					local n=Bond.trickLevel(xp,heart)
					assert(n>=Bond.level(xp)and n>=last and n<=Bond.MaxLevelShipped and Bond.unlock(n));last=n
				end
			end
			for _,odd in ipairs({0/0,"x",-3,0})do assert(Bond.trickLevel(75,odd)==Bond.level(75))end
			assert(Bond.trickLevel(75,nil)==Bond.level(75)and Bond.trickLevel(nil,nil)==1)
		end)
	end)
	Levels.inject(nil)
	assert(ok,problem)
	return{passed=#cases,cases=cases}
end
