return function(client,shared,modules)
	modules=modules or {}
	local Guide=modules.Guide or require(client.FirstSpendGuide)
	local Toys=modules.Toys or require(shared.ToyCatalog)
	local cases={};local function test(name,run)run();table.insert(cases,name)end
	local function fresh()return {revision=1,status="Ready",inventoryMask=1,nectar=Toys.Cost,toyUnlocks={},petToys={}}end
	local function purchased()
		local state=fresh();state.revision=2;state.toyUnlocks={ball=true};state.nectar=0
		state.pendingToyResult={id="first",toyId="ball",revision=2,catalogVersion=Toys.CatalogVersion}
		state.lastToyResult={id="first",action="toyBuy",resultId="first",toyId="ball",revision=2,catalogVersion=Toys.CatalogVersion,
			cost=Toys.Cost,balanceBefore=Toys.Cost,balanceAfter=0}
		return state
	end
	test("saved state reconstructs optional stages without timers/daily pet counts",function()
		local state=fresh()
		assert(Guide.stage(state,{eligible=true})=="purchase")
		state.nectar=Toys.Cost-1;assert(Guide.stage(state,{eligible=true})=="earn")
		assert(Guide.stage(state,{eligible=false})=="free")
		state.lastHatch={id="starter",starter=true};assert(Guide.stage(state,{eligible=true})=="reveal")
		state.inventoryMask=0;assert(Guide.stage(state,{eligible=true})=="welcome")
		state=purchased();assert(Guide.stage(state,{eligible=true})=="receipt")
		state.lastToyResult.id="wrong";assert(Guide.stage(state,{eligible=true})=="done","unrelated receipt never authorizes Give")
		state=purchased();state.lastToyResult.revision=nil;assert(not Guide.purchaseProof(state))
		state=purchased();state.lastToyResult.balanceAfter=999;assert(not Guide.purchaseProof(state))
		state=purchased();state.pendingToyResult=nil;state.lastToyResult=nil
		assert(Guide.stage(state,{eligible=true})=="done","old ownership survives bounded receipt eviction")
	end)
	test("QA v760: any earlier hatch ends the first-egg offer, not only an owned toy",function()
		local function offered(change)local state=fresh();change(state);return Guide.stage(state,{eligible=true})end
		assert(offered(function()end)=="purchase","a fresh save with enough Stars is still offered its first egg")
		assert(offered(function(s)s.stats={starsSpent=0};s.hueInventory={rose=0};s.materialUnlocks={};s.petHues={pip={main={rose=0},secondary={rose=0}}};s.featureStock={horns=0}end)=="purchase","empty records are not a hatch")
		assert(offered(function(s)s.hueInventory={rose=1}end)=="done","a stored colour jar")
		assert(offered(function(s)s.petHues={pip={main={rose=1},secondary={rose=0}}}end)=="done","a used colour jar")
		assert(offered(function(s)s.materialUnlocks={gloss=true}end)=="done","a Material Egg finish")
		assert(offered(function(s)s.lastMaterialResult={id="m"}end)=="done","a material receipt")
		assert(offered(function(s)s.stats={starsSpent=8}end)=="done","Stars already spent")
		assert(offered(function(s)s.pendingHueResult={id="h"}end)=="free","a waiting result still frees the player")
	end)
	local function fixture()
		local c={entered=0,played=0,opens=0,serial=0}
		c.intent={status="Ready",equip=function(self,petId,toyId,resultId)
			c.serial+=1;self.pending={action="toyEquip",value={id="equip"..c.serial,petId=petId,toyId=toyId,resultId=resultId}};self.status="Pending";return true
		end}
		c.guide=Guide.new({intent=c.intent,enterRoom=function()c.entered+=1 end,play=function()c.played+=1;return true end,
			openEggs=function(kind)assert(kind=="toy");c.opens+=1;return true end})
		function c:saved(state)
			local pending=self.intent.pending
			self.intent.pending=nil;self.intent.status="Saved"
			state.revision=3;state.pendingToyResult=nil;state.petToys.pip="ball"
			state.lastToyResult={id=pending.value.id,action="toyEquip",petId="pip",toyId="ball",acknowledgedResultId="first"}
			self.guide:update(state,{eligible=true})
		end
		return c
	end
	test("exact saved equip and actor readiness gate one garden handoff",function()
		local c=fixture();c.guide:update(fresh(),{eligible=true});assert(c.guide:openEggs()and c.opens==1)
		local state=purchased();c.guide:update(state,{eligible=true})
		assert(not c.guide:give("unowned")and c.guide:give("pip")and not c.guide:give("pip"))
		assert(c.entered==0 and c.played==0)
		c.intent.status="Retrying";c.guide:update(state,{eligible=true});assert(c.entered==0,"pending/retry never navigates")
		c:saved(state);assert(c.entered==1)
		assert(not c.guide:step({mode="Room",ready=true,petId="pip",actorReady=false}))
		assert(not c.guide:step({mode="Board",ready=true,petId="pip",actorReady=true}))
		assert(c.guide:step({mode="Room",ready=true,petId="pip",actorReady=true}))
		assert(not c.guide:step({mode="Room",ready=true,petId="pip",actorReady=true})and c.played==1)
	end)
	test("explicit same-screen tab navigation, rejection and destruction cancel delayed work",function()
		for _,cancel in ipairs({"tab","destroy","reject"})do
			local c=fixture();local state=purchased();c.guide:update(state,{eligible=true});assert(c.guide:give("pip"))
			if cancel=="tab"then c.guide:routeChanged()
			elseif cancel=="destroy"then c.guide:destroy()
			else c.intent.status="Rejected";c.guide:update(state,{eligible=true})end
			c:saved(state);assert(c.entered==0 and c.played==0,cancel)
		end
	end)
	test("safe host frame does not consume handoff before normal toy owner starts",function()
		local c=fixture();local state=purchased();c.guide:update(state,{eligible=true});assert(c.guide:give("pip"));c:saved(state)
		local attempts=0
		c.guide.d.play=function()attempts+=1;return attempts>=3 end
		local ready={mode="Room",ready=true,petId="pip",actorReady=true}
		assert(not c.guide:step(ready)and c.guide.flight.phase=="room")
		assert(not c.guide:step(ready)and c.guide.flight.phase=="room")
		assert(c.guide:step(ready)and not c.guide.flight and attempts==3)
		assert(not c.guide:step(ready)and attempts==3,"confirmed actual beat runs once")
		c=fixture();state=purchased();c.guide:update(state,{eligible=true});assert(c.guide:give("pip"));c:saved(state)
		c.guide.d.play=function()c.guide:routeChanged();return true end
		assert(not c.guide:step(ready)and c.guide.flight==nil,"navigation wins a yielding/reentrant play confirmation")
		c=fixture();c.guide.d.actorIdentity=function()return "character:pet1"end
		state=purchased();c.guide:update(state,{eligible=true});assert(c.guide:give("pip"));c:saved(state)
		assert(not c.guide:step({mode="Room",ready=true,petId="pip",actorReady=true,actorIdentity="respawn:pet2"})and c.guide.flight==nil and c.played==0,"new character/pet generation cannot inherit Give")
	end)
	test("automatic receipt reconciliation preserves only the exact pending equip flight",function()
		local c=fixture();local state=purchased();c.guide:update(state,{eligible=true});assert(c.guide:give("pip"))
		local flight,generation=c.guide.flight,c.guide.generation
		assert(c.guide:routeChanged("receipt-reconciled","receipt-finished")==generation)
		assert(c.guide.flight==flight and flight.phase=="equip"and c.entered==0,"automatic close advanced or cancelled pending equip")
		c:saved(state);assert(c.entered==1 and c.guide.flight.phase=="room")
		for _,change in ipairs({"id","petId","toyId","resultId","action","missing","explicit","tab","focus"})do
			c=fixture();state=purchased();c.guide:update(state,{eligible=true});assert(c.guide:give("pip"))
			if change=="missing"then c.intent.pending=nil
			elseif change=="action"then c.intent.pending.action="toyAck"
			elseif change~="explicit"and change~="tab"and change~="focus"then c.intent.pending.value[change]="other"end
			local kind=if change=="explicit"then "close"elseif change=="tab"then "tab"elseif change=="focus"then nil else "receipt-reconciled"
			c.guide:routeChanged(kind,"receipt-finished")
			assert(c.guide.flight==nil and c.entered==0,change.." inherited a handoff")
		end
	end)
	return {passed=#cases,cases=cases}
end
