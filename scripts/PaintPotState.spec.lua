-- Paint pots, the pure rules (PAINT-SHINE-DRESS-PLAN, architect review 2026-11-27): the catalogue, the quote, apply's
-- refusals (any open reservation or reveal first), the receipt ring, the tolerant validator and load repair (newer
-- data kept), and the request order (PaintPotHost: a saved receipt replays before the switch, the rate limits and Busy).
-- Offline: scripts/run_dash_server_specs.py. Studio: require(ServerScriptService.Server.ZZSpecs.PaintPotState)(Server).
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Pots=require(Shared.PaintPotCatalog)
	local Hue=require(Shared.HueCatalog)
	local S=require(server.PaintPotState)
	local Host=require(server.PaintPotHost)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function state(extra)
		local s={nectar=100,inventoryMask=1,revision=7,operationSeq=3,hueInventory={rose=0,tide=0,citrus=0,iris=0,reset=0}}
		for k,v in pairs(extra or {})do s[k]=v end
		return s
	end
	local function candidate(item,price,id,seq)
		local q=S.quote("potBuy",{id=id or "7:pot-a",itemId=item or "tide",price=price or Pots.Price},7)
		return {quote=q,operationId="op-1",sequence=seq or 4,digest=S.digest(q)}
	end

	test("catalogue: one price, the four pots, frozen bounds, a short digest",function()
		assert(Pots.Price==15 and Pots.Prices[15]==true and #Pots.Items==4)
		for _,id in ipairs({"rose","tide","citrus","iris"})do assert(Pots.isItem(id),id)end
		assert(not Pots.isItem("reset")and not Pots.isItem("gloss")and not Pots.isItem(nil))
		assert(Pots.StoredLimit>=Pots.ReceiptLimit and Pots.DigestLimit==120 and #Pots.digest("citrus",15)<=120)
		local t={};for i=1,Pots.PerMinute do assert(Pots.allow(t,i*.1))end
		assert(not Pots.allow(t,3),"the cap");assert(Pots.allow(t,61),"the window moves on")
	end)

	test("quote: exact request keys, the id carries the revision, a pot and a whole price",function()
		assert(S.quote("potBuy",{id="7:pot-a",itemId="tide",price=15},7))
		assert(S.quote("potBuy",{id="7:pot-a",itemId="tide",price=15,extra=1},7)==nil,"extra key")
		assert(S.quote("potBuy",{id="6:pot-a",itemId="tide",price=15},7)==nil,"other revision")
		assert(S.quote("potBuy",{id="7:pot-a",itemId="gloss",price=15},7)==nil,"not a pot")
		assert(S.quote("potBuy",{id="7:pot-a",itemId="tide",price=1.5},7)==nil,"price")
		assert(S.quote("hueBuy",{id="7:pot-a",itemId="tide",price=15},7)==nil,"action")
		assert(S.quote("potBuy",{id=string.rep("x",101),itemId="tide",price=15},7)==nil,"id length")
	end)

	test("apply: charges once into hueInventory and keeps a receipt",function()
		local s=state();local c=candidate()
		assert(S.apply(s,c))
		assert(s.nectar==85 and s.hueInventory.tide==1 and s.hueInventory.rose==0)
		local r,same=S.find(s,c.quote);assert(r and same and r.op=="7:pot-a"and r.price==15 and r.inventoryAfter==1 and r.revision==8)
		assert(S.proof(s,c)and not S.proof(s,{quote=c.quote,digest=c.digest,sequence=99}))
		assert(S.valid(s))
		local other=S.quote("potBuy",{id="7:pot-a",itemId="rose",price=15},7)
		local _,again=S.find(s,other);assert(again==false,"same id, other pot: a conflict")
		local p=S.publicReceipt(r);assert(p.id=="7:pot-a"and p.action=="potBuy"and p.outcome=="Applied"and p.revision==8)
		assert(S.public(s).lastPotResult.id=="7:pot-a"and next(S.public(state()))==nil,"no snapshot field before a pot")
	end)

	test("apply: refuses an open reservation or reveal of any kind first (review item 2), then pet, stack and Stars",function()
		for _,field in ipairs({"hueReservation","materialReservation","toyReservation","featureReservation","pendingHueResult","pendingToyResult","lastHatch"})do
			local s=state({[field]={id="x",petId="pip"}})
			local ok,why=S.apply(s,candidate());assert(not ok and why=="RevealPending",field..": "..tostring(why))
			assert(s.nectar==100 and s.hueInventory.tide==0 and s.paintPots==nil,field..": nothing written")
		end
		local ok,why=S.apply(state({inventoryMask=0}),candidate());assert(not ok and why=="MeetPipFirst")
		ok,why=S.apply(state({nectar=14}),candidate());assert(not ok and why=="NeedStars")
		local full=state();full.hueInventory.tide=Hue.StackLimit
		ok,why=S.apply(full,candidate());assert(not ok and why=="StackLimit")
	end)

	test("ring: this build keeps the newest ReceiptLimit receipts",function()
		local s=state({nectar=10000})
		for i=1,Pots.ReceiptLimit+5 do assert(S.apply(s,candidate("rose",15,"7:pot-"..i,3+i)))end
		assert(#s.paintPots.receipts==Pots.ReceiptLimit and s.paintPots.receipts[1].op=="7:pot-6")
		assert(s.hueInventory.rose==Pots.ReceiptLimit+5 and S.valid(s))
	end)

	test("valid accepts newer data (review item 4): unknown keys, items, prices and a longer ring",function()
		local newer={paintPots={version=2,later={1,2},receipts={}}}
		for i=1,Pots.StoredLimit do
			table.insert(newer.paintPots.receipts,{op="9:pot-"..i,digest="pot:gold:40",itemId="gold",price=40,future=true,sequence=i})
		end
		assert(S.valid(newer),"a newer build's save")
		assert(S.valid({})and S.valid({paintPots={}}))
		assert(not S.valid({paintPots=5})and not S.valid({paintPots={receipts={{op=1}}}}))
		local tooMany=copy(newer);table.insert(tooMany.paintPots.receipts,{op="x",digest="y"})
		assert(not S.valid(tooMany),"past the frozen stored bound")
		-- A replay of a newer build's id still proves itself here.
		local r=S.find(newer,{id="9:pot-3",itemId="gold",price=40});assert(r and r.future==true)
	end)

	test("sanitize repairs at load: drops what is not a receipt, keeps unknown keys and the newest StoredLimit",function()
		local s={paintPots={note="kept",receipts={[1]={op="a",digest="pot:rose:15"},[2]="junk",[3]={op=""},[5]={op="b",digest="pot:tide:15",x=1},bad={op="c",digest="d"}}}}
		S.sanitize(s);assert(S.valid(s))
		assert(s.paintPots.note=="kept"and #s.paintPots.receipts==2 and s.paintPots.receipts[2].x==1)
		local t={paintPots="broken"};S.sanitize(t);assert(t.paintPots==nil)
		local u={};S.sanitize(u);assert(u.paintPots==nil,"absent stays absent")
		local long={paintPots={receipts={}}}
		for i=1,Pots.StoredLimit+10 do table.insert(long.paintPots.receipts,{op="o"..i,digest="d"})end
		S.sanitize(long);assert(#long.paintPots.receipts==Pots.StoredLimit and long.paintPots.receipts[1].op=="o11")
	end)

	-- The request order (review item 1).
	local function deps(over)
		local d={log={},calls=0}
		local s=over.state or state()
		d.state=function()return s end
		d.on=function()return over.on~=false end
		d.samePending=function()return over.samePending==true end
		d.busy=function()return over.busy==true end
		d.recent=function()return over.recent==true end
		d.mark=function()table.insert(d.log,"mark")end
		d.allow=function()return over.allow~=false end
		d.command=function()d.calls+=1;return table.unpack(over.result or {true,"Saved",{id="x"}})end
		d.publish=function()table.insert(d.log,"publish")end
		d.reply=function(tag,status,reason,receipt)d.reply_={tag=tag,status=status,reason=reason,receipt=receipt}end
		d.waiting=function(tag)d.waited=tag end
		d.alive=function()return true end
		return d
	end
	local function send(d,id,item)return Host.request(d,"potBuy",{id=id or "7:pot-a",itemId=item or "tide",price=15},7)end

	test("host: a committed id replays Saved before the switch, the gap, the cap and Busy (review item 1)",function()
		local s=state();assert(S.apply(s,candidate()))
		local d=deps({state=s,on=false,recent=true,busy=true,allow=false})
		assert(send(d)=="AlreadySaved"and d.calls==0)
		assert(d.reply_.status=="Saved"and d.reply_.reason=="AlreadySaved"and d.reply_.receipt.id=="7:pot-a"and s.nectar==85)
		local c=deps({state=s,on=false,recent=true,busy=true})
		assert(send(c,"7:pot-a","rose")=="OperationConflict"and c.reply_.status=="Rejected"and c.calls==0)
	end)

	test("host: then pending-and-busy Retrying, the switch, the gap, the cap, Busy, the command",function()
		local d=deps({samePending=true,busy=true});assert(send(d)=="Busy"and d.reply_.status=="Retrying"and d.calls==0)
		d=deps({on=false});assert(send(d)=="NotReady"and d.reply_.status=="Rejected"and d.calls==0)
		d=deps({on=false,samePending=true});assert(send(d)=="Saved"and d.calls==1,"a pending buy finishes after the switch goes off")
		d=deps({recent=true});assert(send(d)=="Throttled"and d.calls==0)
		d=deps({allow=false});assert(send(d)=="Throttled"and d.calls==0)
		d=deps({busy=true});assert(send(d)=="Busy"and d.reply_.status=="Rejected"and d.calls==0)
		d=deps({});assert(send(d)=="Saved"and d.calls==1 and d.reply_.status=="Saved"and d.log[#d.log]=="publish")
		d=deps({result={false,"Retrying"}});assert(send(d)=="Retrying"and d.reply_.status=="Retrying"and d.waited.id=="7:pot-a")
		d=deps({result={false,"NeedStars"}});assert(send(d)=="NeedStars"and d.reply_.status=="Rejected")
		d=deps({});assert(Host.request(d,"potBuy",{id="7:x",itemId="gloss",price=15},7)=="InvalidPot"and d.reply_.status=="Rejected")
	end)

	return {passed=#cases,cases=cases}
end
