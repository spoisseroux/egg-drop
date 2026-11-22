-- Garden Dash off (its flag, or the runtime switch) is the game before it (V3-DASH-BUILD-PLAN-2026-11-22, S6): snapshot
-- and save keys (the goldens LevelsOffParity.spec checks), no remotes, no gate, no tags; a saved dash field is kept.
-- Isolated adapters only; no DataStore or user writes.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.DashOffParity)(ServerScriptService.Server)
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Http=game:GetService("HttpService")
	local Dash=require(Shared.Dash)
	local Levels=require(Shared.Levels)
	local H=require(server.HatchProgress)
	local Garden=require(server.GardenState)
	local Mount=require(server.DashMount)
	local Host=require(server.DashHost)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function keys(t)local out={};for k in pairs(t)do table.insert(out,tostring(k))end;table.sort(out);return table.concat(out," ")end
	local PUBLIC="ballThemes bond book catalogVersion charmUnlocks coachMask dailyAvailable dailyBonus dailyDay faceplates featureCatalogVersion featurePoolVersion featureStock finishInventory hueInventory hueMigrationAcknowledged hues inventoryMask legacyHuePresets lookAvailable lookCharmMisses lookFound lookPoolVersion lookSelectionMode mastery masteryChallenges masteryDetails masteryLegacyMask masteryRanks materialAvailable materialCatalogVersion materialPoolVersion materialSelectionMode materialUnlocks misses names nectar nextFixed petCount petDay petFeatures petFinish petHues petMaterials petStats petToys petWearables playDate quests restricted revision shelfWeek stampCard stampDay stampReward stamps starterClaimed statEgg stats status todayEarned totalWins toyCatalogVersion toyPoolVersion toyUnlocks"
	local SAVED="ballThemes book charmUnlocks dailyClaimDay epoch featureReceiptOrder featureReceipts featureStock hueAssignments hueInventory hueItemReceipts hueMigrationAcknowledged hueReceiptOrder inventoryMask lastAwardSeq lease mastery masteryChallenges masteryLegacyMask materialReceiptOrder materialReceipts materialUnlocks migrated misses names nectar operationSeq petCount petDay petFeatures petHues petMaterials petStats petToys petWearables quests revision stamps stats statsSeed totalWins toyReceiptOrder toyReceipts toyUnlocks version welcomeCredited"
	local function fixture(seed,start)
		local db,c={},{now=start or 1700000000,serial=0}
		local adapter={now=function()return c.now end,guid=function()c.serial+=1;return "op"..c.serial end,random=function()return .1 end,wait=function()end,
			update=function(key,transform)local value=transform(copy(db[key]));if value then db[key]=copy(value)end;return copy(value)end}
		if seed then db.player_1=seed end
		return H.load(1,{rank=1},adapter),db,c
	end
	local RACE={kind="race",mode="fun",place=1,us=35000000,inputs=9,seed=1,prize=true}
	local OFF={{flags={GardenDash=false}},{flags={GardenDash=true},race=false}}
	local ok,problem=pcall(function()
		Levels.inject({flags={LevelsMatter=false},studio=true})
		for index,off in ipairs(OFF)do
			off.studio=true
			local name=if index==1 then "flag"else "switch"
			test("off ("..name.."): snapshot and save keys are the build's before it, and playing saves nothing new",function()
				Dash.inject(off);local h,db=fixture()
				assert(h.status=="Ready"and keys(H.public(h))==PUBLIC,keys(H.public(h)));assert(keys(db.player_1.hatching)==SAVED)
				assert(H.parkPlay(h,"p1",1,"pip")and db.player_1.hatching.dash==nil and H.public(h).dash==nil)
			end)
			test("off ("..name.."): a save with a dash field, good or malformed, loads, plays and keeps it untouched",function()
				Dash.inject(off)
				for _,value in ipairs({{day="19680",paid=3,week=2812,weekRibbons=4,ribbons={gold=1,silver=0,bronze=2,green=1},cups=5,best=31000000,op="x",receipt={op="x",seed=1,place=2,us=1,stars=2,balance=5}},"x",5,{day={}}})do
					local _,db,c=fixture();db.player_1.hatching.dash=copy(value);db.player_1.hatching.lease={token="",expiresAt=0}
					local h,db2=fixture(db.player_1,c.now+200);assert(h.status=="Ready"and H.public(h).dash==nil and H.parkPlay(h,"p2",1,"pip"))
					assert(Http:JSONEncode(db2.player_1.hatching.dash)==Http:JSONEncode(value))
				end
			end)
		end
		test("on: the snapshot adds one key and loading or playing still saves nothing until a race is won",function()
			Dash.inject({flags={GardenDash=true},studio=true});local h,db=fixture()
			local public=H.public(h);assert(public.dash.paid==0 and public.dash.limit==5 and public.dash.last==nil);public.dash=nil;assert(keys(public)==PUBLIC)
			assert(H.parkPlay(h,"p1",1,"pip")and db.player_1.hatching.dash==nil)
			assert(H.dashResults(h,"f",{RACE})and H.public(h).dash.paid==1)
			local before=keys(db.player_1.hatching);assert(string.find(before,"dash",1,true))
		end)
		test("off: nothing is mounted, and with no racer the garden snapshot has no dash key anywhere",function()
			Dash.inject(OFF[1]);assert(Host.mount({})==nil)
			local now=0
			local input={petId="pip",owned=true,alive=true,characterId=1,petGeneration=0,mode="Room",position=Vector3.new(50,7,10),anchor=Vector3.new(50,4,10),yaw=0,charmVisible=true}
			local snapshot;local garden=Garden.new({sharedToyEnabled=false,now=function()return now end,publish=function(s)snapshot=s end})
			for _=1,20 do now+=.5;garden:step(.5,{[1]=input})end
			assert(garden.racers==nil and snapshot.actors["1"]and snapshot.actors["1"].dash==nil and not string.find(Http:JSONEncode(snapshot),"dash",1,true))
		end)
		test("the gate: placeholder props only, under 60, anchored and out of everybody's way; remove leaves nothing",function()
			local room=Instance.new("Folder");local model=Mount.build(room);local parts=0
			for _,node in ipairs(model:GetDescendants())do
				if node.ClassName=="Part"then parts+=1;assert(node.Anchored==true and node.CanCollide==false and node.CanQuery==false and node.CanTouch==false)end
			end
			assert(parts>=15 and parts<=60 and model:GetAttribute("Start")and model:GetAttribute("Finish"))
			Mount.build(room);assert(#room:GetChildren()==1);Mount.remove(room);Mount.remove(room);assert(#room:GetChildren()==0);room:Destroy()
		end)
	end)
	Dash.inject(nil);Levels.inject(nil)
	assert(ok,problem)
	return{passed=#cases,cases=cases}
end
