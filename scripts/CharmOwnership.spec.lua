-- Customization Egg, slice 2 (plan 2026-11-16 §2.3, §3.4, R2): the charm ownership switch.
--  * PetCharmCatalog.usable: an egg shape is usable only when the save's charmUnlocks holds it,
--    an earned shape when its rule is met, an unknown shape never.
--  * PetAppearance.request: any request that would show a charm (visible=true), including the
--    unmarked visibility-only path that resolves to the stored shape or the Default, must name a
--    usable shape or it is "Locked". Hiding never asks.
--  * PetAppearance.public(..., hatching) masks a saved visible charm the save does not own
--    (stale profile rows, rows an older server wrote during a rollout).
--  * A fresh save owns no egg charm; a save from before this build owns all three.
-- Isolated fixtures only. Usage (Server):
--   require(ServerScriptService.Server.ZZSpecs.CharmOwnership)(ServerScriptService.Server)
return function(server)
	local A=require(server.PetAppearance)
	local RawH=require(server.HatchProgress)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Charms=require(Shared.PetCharmCatalog)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end

	local function writer(target,id,visible,chosen)
		target.petAppearance=target.petAppearance or {}
		local old=target.petAppearance[id]
		target.petAppearance[id]={charmVisible=visible,charmShape=chosen or(old and old.charmShape)or Charms.Default,at=1,writer="spec"}
	end
	-- One request against a hatching save `save` (its charmUnlocks and earned facts).
	local function session(save,profile)
		local s={state=A.new({selectionsEnabled=true}),profile=profile or {petAppearance={}},seq=0,now=0}
		function s.ask(visible,shape,marked)
			s.seq+=1;s.now+=1
			local value={petId="pip",visible=visible,seq=s.seq,shape=shape,shapeVersion=if marked then Charms.Version else nil}
			return A.request(s.state,s.profile,value,s.now,true,function()return true end,writer,function(chosen)return A.earned(chosen,save)end)
		end
		return s
	end

	test("usable: egg shapes need charmUnlocks, earned shapes their rule, unknown shapes never",function()
		for _,id in ipairs(Charms.EggShapes)do
			assert(not Charms.usable(id,{})and not Charms.usable(id,nil)and Charms.usable(id,{},{[id]=true}),id)
			assert(A.earned(id,{charmUnlocks={[id]=true}})and not A.earned(id,{charmUnlocks={}})and not A.earned(id,{}),id)
		end
		assert(Charms.usable("heart",{claimed={"wardrobe.100"}})and not Charms.usable("heart",{charmUnlocks={heart=true}}),"Heart stays rule-earned")
		assert(not Charms.usable("future_kite",{charmUnlocks={future_kite=true}})and not A.earned("future_kite",{charmUnlocks={dot=true}}))
		assert(Charms.Default=="dot"and Charms.renderShape("future_kite")=="dot","Default is only the render fallback")
	end)

	test("a save without the egg charms cannot show one, by any request path",function()
		local s=session({charmUnlocks={}})
		local r=s.ask(true,nil,false);assert(r.status=="Rejected"and r.reason=="Locked","visibility-only show resolves to the Default: Locked")
		r=s.ask(true,"dot",false);assert(r.status=="Rejected"and r.reason=="Locked","the v274 unmarked Dot show: Locked")
		r=s.ask(true,"dot",true);assert(r.reason=="Locked","a marked Snowflake: Locked")
		r=s.ask(false,"ring",true);assert(r.reason=="Locked","a hidden selection cannot store an unowned shape")
		assert(not A.visible(s.profile,"pip")and A.shape(s.profile,"pip")==Charms.Default,"nothing applied")
		r=s.ask(false,nil,false);assert(r.status=="Saved","hiding never asks")
	end)

	test("an owned egg shape is worn, hidden and shown again; a stale stored shape stays locked",function()
		local save={charmUnlocks={ring=true}}
		local s=session(save)
		local r=s.ask(true,"ring",true);assert(r.status=="Saved"and A.visible(s.profile,"pip")and A.shape(s.profile,"pip")=="ring")
		r=s.ask(false,nil,false);assert(r.status=="Saved"and not A.visible(s.profile,"pip"))
		r=s.ask(true,nil,false);assert(r.status=="Saved"and A.visible(s.profile,"pip")and A.shape(s.profile,"pip")=="ring","show resolves to the owned stored shape")
		local stale=session(save,{petAppearance={pip={charmVisible=false,charmShape="dot",at=1,writer="old"}}})
		r=stale.ask(true,nil,false);assert(r.reason=="Locked","a stored Snowflake row is not owned here")
		-- The reply never claims a charm is showing when the save does not own it (code review).
		local maskedReply=stale.ask(false,nil,false);assert(maskedReply.status=="Saved"and maskedReply.visible==false)
		local staleShown=session(save,{petAppearance={pip={charmVisible=true,charmShape="dot",at=1,writer="v775"}}})
		r=staleShown.ask(true,"ring",true);assert(r.status=="Saved"and r.visible==true and r.shape=="ring","owned shape: visible")
		local stuck=session({charmUnlocks={}},{petAppearance={pip={charmVisible=true,charmShape="dot",at=1,writer="v775"}}})
		r=stuck.ask(true,nil,false);assert(r.reason=="Locked"and r.visible==false,"a stale visible row is reported hidden")
		local legacy=session({charmUnlocks={dot=true,ring=true,pebble=true}})
		r=legacy.ask(true,nil,false);assert(r.status=="Saved"and A.shape(legacy.profile,"pip")=="dot","a legacy save keeps its Snowflake")
		-- Callers without the ownership callback (pure specs) behave as before.
		local open=A.request(A.new({selectionsEnabled=true}),{petAppearance={}},{petId="pip",visible=true,seq=1},1,true,function()return true end,writer)
		assert(open.status=="Saved")
	end)

	test("public masks a saved visible charm the save does not own, including rows an old server wrote",function()
		local profile={petAppearanceSaved={
			pip={charmVisible=true,charmShape="ring",at=5,writer="v775-server"},
			puddle={charmVisible=true,at=5,writer="v775-server"}, -- no shape: the Default Snowflake
			wick={charmVisible=true,charmShape="heart",at=5,writer="old"},
			orbit={charmVisible=true,charmShape="future_kite",at=5,writer="newer-server"},
		}}
		local fresh=A.public(profile,nil,nil,nil,nil,nil,"pip",nil,{charmUnlocks={}})
		assert(not fresh.pip.charmVisible and not fresh.puddle.charmVisible and not fresh.wick.charmVisible and not fresh.orbit.charmVisible)
		assert(fresh.pip.charmShape=="ring","the stored shape is kept; only its visibility is masked")
		local owned=A.public(profile,nil,nil,nil,nil,nil,"pip",nil,{charmUnlocks={ring=true,dot=true},book={claimed={"wardrobe.100"}}})
		assert(owned.pip.charmVisible and owned.puddle.charmVisible and owned.wick.charmVisible and not owned.orbit.charmVisible)
		local unmasked=A.public(profile)
		assert(unmasked.pip.charmVisible and unmasked.orbit.charmVisible,"profile-only callers are unchanged")
		local hidden=A.public({petAppearanceSaved={pip={charmVisible=false,charmShape="ring",at=1,writer="x"}}},nil,nil,nil,nil,nil,"pip",nil,{charmUnlocks={ring=true}})
		assert(not hidden.pip.charmVisible,"masking never shows a hidden charm")
	end)

	test("a fresh save owns no egg charm; a save from before this build owns all three",function()
		local db,c={},{now=1700000000,serial=0}
		local adapter={now=function()return c.now end,guid=function()c.serial+=1;return "own"..c.serial end,random=function()return .1 end,wait=function()end,
			update=function(key,transform)local value=transform(copy(db[key]));if value then db[key]=copy(value)end;return copy(value)end}
		local h=RawH.load(1,{rank=1},adapter);assert(h.status=="Ready")
		for _,id in ipairs(Charms.EggShapes)do assert(not A.earned(id,h.state),id.." on a fresh save")end
		assert(RawH.release(h));db.player_1.hatching.charmUnlocks=nil
		h=RawH.load(1,{},adapter);assert(h.status=="Ready")
		for _,id in ipairs(Charms.EggShapes)do assert(A.earned(id,h.state),id.." on a legacy save")end
		local p=RawH.public(h);assert(p.charmUnlocks.dot and p.charmUnlocks.ring and p.charmUnlocks.pebble)
		for _,id in ipairs(Charms.EggShapes)do assert(Charms.usable(id,Charms.facts(p)),id.." from the snapshot")end
	end)

	return{passed=#cases,cases=cases}
end
