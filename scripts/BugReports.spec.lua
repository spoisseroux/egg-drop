-- v1 track B: in-game bug reports and suggestions. Rate limits, the filtering path
-- (injected filter), field validation, purge selection, owner-only read, the form
-- rules and the copy. Every Roblox service is behind an adapter, so this runs in
-- Studio or offline.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.BugReports)(ServerScriptService.Server, ReplicatedStorage.Shared)
-- Offline:        luau.exe harness passing modules = {Reports=..., Form=..., UICopy=...}
return function(server,shared,modules)
	modules=modules or {}
	local Reports=modules.Reports or require(server.BugReportStore)
	local Form=modules.Form or require(shared.BugReportForm)
	local UICopy=modules.UICopy or require(shared.UICopy)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local START=1699923600 -- 01:00 UTC, so a test day has room
	local OWNER=Reports.Owner
	-- A rough JSON size (the real adapter uses HttpService:JSONEncode).
	local function size(v)
		if type(v)=="string"then return #v+2 elseif type(v)=="table"then
			local n=2;for k,x in pairs(v)do n+=size(k)+size(x)+2 end;return n
		end
		return #tostring(v)
	end
	local function fixture(db)
		db=db or {}
		local c={now=START,serial=0,filterCalls=0,fail=false,logs={},filter=function(_,text)return true,text end}
		local adapter={
			now=function()return c.now end,
			guid=function()c.serial+=1;return "guid-"..c.serial end,
			placeVersion=function()return 590 end,
			encode=function(value)return string.rep("x",size(value))end,
			log=function(line)table.insert(c.logs,line)end,
			filter=function(userId,text)c.filterCalls+=1;c.filterUser=userId;return c.filter(userId,text)end,
			update=function(key,transform)
				if c.fail then error("store down")end
				local value=transform(copy(db[key]))
				if value~=nil then db[key]=copy(value)end
				return copy(value)
			end,
			get=function(key)if c.fail then error("store down")end;return copy(db[key])end,
			remove=function(key)db[key]=nil end,
			listKeys=function(prefix)
				local out={}
				for key in pairs(db)do if string.sub(key,1,#prefix)==prefix then table.insert(out,key)end end
				table.sort(out);return out
			end,
		}
		return Reports.new(adapter),db,c
	end
	local serial=0
	local function packet(fields)
		serial+=1
		local p={nonce="n"..serial,kind="bug",category="garden",context={device="touch",width=812,height=354,mode="Room",screen="settings",from="hub"}}
		for k,v in pairs(fields or {})do p[k]=v end
		return p
	end
	local function stored(db,day)
		local value=db[Reports.dayKey(day or Reports.dayOf(START))]
		return if value then value.reports else {}
	end

	test("form ids match the server, and every label and reply line exists in UICopy",function()
		assert(table.concat(Form.Kinds,",")==table.concat(Reports.Kinds,","),"kinds")
		assert(table.concat(Form.Categories,",")==table.concat(Reports.Categories,","),"categories")
		assert(Form.NoteMax==Reports.NoteMax and Form.Cooldown==Reports.Limits.minGap and Form.MaxErrors==Reports.MaxErrors and Form.ErrorLength==Reports.ErrorLength)
		assert(#Reports.Categories==7 and table.find(Reports.Categories,"deck")and table.find(Reports.Categories,"park")and table.find(Reports.Categories,"stars"))
		for _,id in ipairs(Form.Kinds)do assert(UICopy.has("report.kind."..id),id)end
		for _,id in ipairs(Form.Categories)do assert(UICopy.has("report.category."..id),id)end
		for _,key in ipairs({"report.entry","report.title","report.about","report.note.placeholder","report.note.privacy","report.send","report.sending","report.wait","report.pick"})do
			assert(UICopy.has(key),key)
		end
		for _,status in ipairs({"Timeout","Sent","Duplicate","Queued","Limited","Full","Busy","Invalid"})do
			local reply=if status=="Timeout"then nil else {status=status}
			for _,kind in ipairs(Form.Kinds)do local key=Form.replyKey(reply,kind);assert(UICopy.has(key),tostring(key))end
		end
		assert(Form.replyKey({status="Sent"},"suggestion")=="report.thanks.suggestion"and Form.replyKey({status="Duplicate"},"bug")=="report.thanks.bug")
		assert(Form.replyKey(nil,"bug")=="report.reply.timeout"and Form.replyKey({status="Queued"},"bug")=="report.thanks.queued")
		assert(UICopy.get("report.note.count",{count=12})=="12/200")
		local privacy=string.lower(UICopy.get("report.note.privacy"))
		assert(string.find(privacy,"names",1,true)and string.find(privacy,"personal",1,true),"the box warns against personal details")
	end)

	test("validation: malformed packets drop, every field is checked, unknown fields ignored",function()
		local clean,reason,nonce=Reports.validate("x")
		assert(clean==nil and reason=="Malformed"and nonce==nil)
		assert(select(2,Reports.validate({kind="bug",category="garden"}))=="Malformed","no nonce")
		assert(select(2,Reports.validate({nonce="bad nonce!",kind="bug",category="garden"}))=="Malformed")
		assert(select(2,Reports.validate({nonce=string.rep("a",41),kind="bug",category="garden"}))=="Malformed")
		clean,reason,nonce=Reports.validate({nonce="abc-1",kind="praise",category="garden"})
		assert(clean==nil and reason=="Kind"and nonce=="abc-1","bad kind keeps the nonce for the reply")
		assert(select(2,Reports.validate({nonce="a",kind="bug",category="Garden"}))=="Category")
		assert(select(2,Reports.validate({nonce="a",kind="bug",category="garden",note=5}))=="Note")
		assert(select(2,Reports.validate({nonce="a",kind="bug",category="garden",note=string.rep("a",801)}))=="Note")
		assert(select(2,Reports.validate({nonce="a",kind="bug",category="garden",context="x"}))=="Context")
		clean=Reports.validate({nonce="a",kind="suggestion",category="stars",userName="Somebody",email="x@y.z",context={
			device="toaster",width=1e9,height=-5,mode="Room Garden",screen=string.rep("s",33),from="pocket",textSize="Large",reducedMotion="yes",
			errors={"one","two","three","four","five","six"},chat="hi"}})
		assert(clean.kind=="suggestion"and clean.cat=="stars"and clean.note==nil)
		assert(clean.dev=="unknown"and clean.vw==10000 and clean.vh==0,"device whitelisted, sizes clamped")
		assert(clean.mode==nil and clean.scr==nil and clean.from=="pocket"and clean.text=="Large"and clean.rm==nil,"tokens only")
		assert(#clean.errs==5 and clean.errs[5]=="five","five log lines at most")
		for key in pairs(clean)do
			assert(table.find({"nonce","kind","cat","note","dev","vw","vh","mode","scr","from","text","rm","errs"},key),"unexpected field "..key)
		end
		local scrubbed=Reports.scrubLine("Players.SkunkDev.PlayerGui error for Skunky (é) "..string.rep("z",300),{"SkunkDev","Skunky","ab"})
		assert(string.find(scrubbed,"Players.<player>.PlayerGui error for <player> (??)",1,true),scrubbed)
		assert(#scrubbed==Reports.ErrorLength and not string.find(scrubbed,"Skunk"),"cut and scrubbed")
		assert(Reports.scrubLine("",{})==nil and Reports.scrubLine(4,{})==nil)
	end)

	test("notes: trimmed, control characters and runs of space collapsed, 200 characters, UTF-8 safe",function()
		assert(Reports.cleanNote("   ")==nil and Reports.cleanNote(nil)==nil and Reports.cleanNote(3)==nil)
		assert(Reports.cleanNote("  stuck \n\n on   the\tbridge  ")=="stuck on the bridge")
		local long=string.rep("é",250)
		local cut=Reports.cleanNote(long)
		assert(utf8.len(cut)==200 and cut==string.rep("é",200),"cut on a character boundary")
		assert(Reports.cleanNote("ok\255\254")=="ok","invalid UTF-8 tail dropped")
		assert(Form.clip(string.rep("é",201))==string.rep("é",200)and Form.length(string.rep("é",3))==3 and Form.clip(nil)=="")
	end)

	test("filtering: the note goes through the injected filter for the reporter; anything hidden or failed is not stored",function()
		local service,db,c=fixture()
		local reply=service:submit(42,packet({note="  the egg  never hatched "}))
		assert(reply.status=="Sent"and reply.noteState=="kept"and c.filterCalls==1 and c.filterUser==42)
		assert(stored(db)[1].note=="the egg never hatched","the cleaned text is what gets filtered and kept")
		c.now+=30;c.filter=function(_,text)return true,(string.gsub(text,"%d","#"))end
		reply=service:submit(42,packet({note="my number is 5551234",category="pets"}))
		assert(reply.status=="Sent"and reply.noteState=="hidden")
		local second=stored(db)[2];assert(second.note==nil and second.noteState=="hidden","a changed note is dropped entirely")
		local service2,db2,c2=fixture()
		c2.filter=function()error("filter down")end
		reply=service2:submit(7,packet({note="hello"}))
		assert(reply.status=="Sent"and reply.noteState=="failed"and stored(db2)[1].note==nil,"filter error: rest kept, note dropped")
		c2.now+=30;c2.filter=function()return false,"hello"end
		reply=service2:submit(7,packet({note="hello again",category="menus"}))
		assert(reply.noteState=="failed"and stored(db2)[2].note==nil,"filter says no: dropped")
		c2.now+=30;local before=c2.filterCalls
		reply=service2:submit(7,packet({note="   ",category="other"}))
		assert(reply.noteState=="none"and c2.filterCalls==before,"no note, no filter call")
		assert(Reports.filterWith({filter=function(_,t)return true,t end},1,nil)==nil)
	end)

	test("records hold the UserId and checked context only; size is capped; one console line per report",function()
		local service,db,c=fixture()
		local reply=service:submit(42,packet({note="hi",context={device="gamepad",width=1920,height=1080,mode="Board",screen="settings",from="pocket",
			errors={string.rep("a",200),string.rep("b",200),string.rep("c",200),string.rep("d",200),string.rep("e",200)}}}))
		assert(reply.status=="Sent"and type(reply.id)=="string"and #reply.id<=12)
		local record=stored(db)[1]
		assert(record.uid==42 and record.t==START and record.pv==590 and record.kind=="bug"and record.cat=="garden"and record.dev=="gamepad")
		assert(record.name==nil and record.displayName==nil and record.nonce==nil,"no names, no nonce")
		assert(size(record)<=Reports.MaxRecordBytes,"under the size cap")
		Reports.MaxRecordBytes=500
		c.now+=30
		service:submit(42,packet({note="hi",category="pets",context={errors={string.rep("a",160),string.rep("b",160),string.rep("c",160),string.rep("d",160)}}}))
		local small=stored(db)[2]
		assert(size(small)<=500 and(small.errs==nil or #small.errs<4),"oldest log lines dropped first")
		Reports.MaxRecordBytes=2000
		assert(#c.logs==2 and string.find(c.logs[1],"[EggDropReport] NEW bug/garden pv=590 gamepad 1920x1080 mode=Board screen=settings errs=",1,true),c.logs[1])
		assert(not string.find(c.logs[1],"42",1,true),"the console line has no UserId")
	end)

	test("rate limits: 20 s gap, 3 per 10 minutes, 20 per day across servers, server hourly cap, duplicates, one in flight",function()
		local service,db,c=fixture()
		assert(service:submit(1,packet()).status=="Sent")
		local reply=service:submit(1,packet({category="pets"}))
		assert(reply.status=="Limited"and reply.reason=="Gap"and reply.wait==20)
		c.now+=20;assert(service:submit(1,packet({category="pets"})).status=="Sent")
		c.now+=20;assert(service:submit(1,packet({category="menus"})).status=="Sent")
		c.now+=20;reply=service:submit(1,packet({category="stars"}))
		assert(reply.status=="Limited"and reply.reason=="Window"and reply.wait==600-60,"3 per 10 minutes")
		assert(#stored(db)==3)
		c.now=START+600;assert(service:submit(1,packet({category="stars"})).status=="Sent","window slides")
		assert(service:submit(2,packet()).status=="Sent","other players unaffected")
		-- Daily: 19 more from "other servers" already in the day key -> refused here.
		local other,db2,c2=fixture()
		for i=1,20 do c2.now=START+i*700;assert(other:submit(5,packet({category=Reports.Categories[i%7+1],note="n"..i})).status=="Sent",i)end
		local fresh=Reports.new(other.adapter) -- a second server reading the same store
		c2.now+=700
		reply=fresh:submit(5,packet({category="other",note="once more"}))
		assert(reply.status=="Limited"and reply.reason=="Daily"and reply.wait>0,"20 per day, counted in the store")
		assert(#stored(db2)==20)
		-- Duplicate: same kind + category + note within 10 minutes, from another server.
		local s3,db3,c3=fixture()
		assert(s3:submit(9,packet({note="same"})).status=="Sent")
		c3.now+=30
		local s3b=Reports.new(s3.adapter)
		assert(s3b:submit(9,packet({note="same"})).status=="Duplicate"and #stored(db3)==1)
		-- Server hourly cap.
		local s4,_,c4=fixture()
		for user=1,Reports.Limits.serverHourly do assert(s4:submit(1000+user,packet()).status=="Sent")end
		reply=s4:submit(5000,packet());assert(reply.status=="Limited"and reply.reason=="Server")
		c4.now+=3600;assert(s4:submit(5000,packet()).status=="Sent","hour slides")
		-- One in flight per player.
		local s5=fixture();s5.inFlight[3]=true
		assert(s5:submit(3,packet()).status=="Busy")
		-- Day cap.
		local s6,db6=fixture();db6[Reports.dayKey(Reports.dayOf(START))]={v=1,reports=table.create(Reports.Limits.dayCap,{uid=0,t=0})}
		assert(s6:submit(4,packet()).status=="Full")
		-- Pure checks.
		assert(Reports.checkSession({},{},START)=="ok")
		assert(Reports.checkStored({},1,START)=="ok")
	end)

	test("store failure: the player is thanked, the report waits on the server and lands on retry, or is dropped after 3 tries",function()
		local service,db,c=fixture()
		c.fail=true
		local reply=service:submit(8,packet({note="offline"}))
		assert(reply.status=="Queued"and #service.pendingQueue==1 and #stored(db)==0)
		assert(string.find(c.logs[1],"QUEUED",1,true))
		assert(service:retryPending()==0 and service.pendingQueue[1].attempts==2)
		c.fail=false
		assert(service:retryPending()==1 and #service.pendingQueue==0 and stored(db)[1].note=="offline")
		c.fail=true;c.now+=30
		service:submit(8,packet({category="pets"}))
		service:retryPending();service:retryPending();service:retryPending()
		assert(#service.pendingQueue==0 and string.find(c.logs[#c.logs],"LOST",1,true),"dropped after "..Reports.PendingAttempts.." tries")
		assert(service.inFlight[8]==nil,"never stuck in flight")
	end)

	test("purge: day keys 30 or more days old are removed, once a day across servers",function()
		local today=Reports.dayOf(START)
		local keys={Reports.dayKey(today),Reports.dayKey(today-29),Reports.dayKey(today-30),Reports.dayKey(today-31),Reports.dayKey(today-400),"sweep","day_x","day_12a"}
		local expired=Reports.expiredKeys(keys,today)
		assert(#expired==3 and table.find(expired,Reports.dayKey(today-30))and table.find(expired,Reports.dayKey(today-31))and table.find(expired,Reports.dayKey(today-400)))
		assert(not table.find(expired,Reports.dayKey(today-29))and not table.find(expired,"sweep"))
		local service,db,c=fixture()
		for _,key in ipairs(keys)do db[key]={v=1,reports={}}end
		local removed=service:sweep(false)
		assert(#removed==3 and db[Reports.dayKey(today-29)]and db[Reports.dayKey(today)]and not db[Reports.dayKey(today-30)])
		assert(db.sweep.day==today)
		local _,why=service:sweep(false);assert(why=="Throttled","once per server per day")
		local other=Reports.new(service.adapter)
		local none,swept=other:sweep(false);assert(none==nil and swept=="Swept","another server skips today's sweep")
		c.now+=86400;db[Reports.dayKey(today-29)]={v=1,reports={}}
		removed=other:sweep(false);assert(#removed==1,"the next day the 29-day key ages out")
		c.fail=true;local failed=service:sweep(true);assert(failed==nil,"a failed sweep removes nothing")
	end)

	test("owner-only read: recent reports newest first, filters, 30-day window, erase by UserId",function()
		local service,db,c=fixture()
		service:submit(11,packet({kind="bug"}));c.now+=30
		service:submit(12,packet({kind="suggestion",category="park"}));c.now+=86400
		service:submit(11,packet({kind="bug",category="menus"}))
		assert(not Reports.canRead(12345)and not Reports.canRead(tostring(OWNER))and not Reports.canRead(nil)and Reports.canRead(OWNER))
		local list,why=service:recent(12345,{});assert(list==nil and why=="NotOwner")
		list=service:recent(OWNER,{days=7})
		assert(#list==3 and list[1].cat=="menus"and list[3].uid==11,"newest first")
		assert(#service:recent(OWNER,{kind="suggestion"})==1 and #service:recent(OWNER,{category="menus"})==1 and #service:recent(OWNER,{days=1})==1)
		assert(#service:recent(OWNER,{limit=2})==2)
		db[Reports.dayKey(Reports.dayOf(c.now)-2)]={v=1,reports={{uid=1,t=c.now-31*86400,kind="bug",cat="other"}}}
		assert(#service:recent(OWNER,{days=30})==3,"anything older than 30 days is never returned")
		local text=Reports.format(list)
		assert(string.find(text,"bug/menus",1,true)and string.find(text,"uid=11",1,true))
		assert(service:eraseUser(12345,11)==nil)
		assert(service:eraseUser(OWNER,11)==2 and #service:recent(OWNER,{days=7})==1)
		assert(Reports.readLive(12345)=="NotOwner","the live reader refuses everyone else before touching a service")
	end)

	test("form: send needs a kind and a category, waits out the cooldown; defaults; chip flow; log lines; packet",function()
		local state={kind="bug",category=nil,note="",sending=false}
		assert(not Form.canSend(state,0))
		state.category="garden";assert(Form.canSend(state,0))
		state.sending=true;assert(not Form.canSend(state,0));state.sending=false
		state.sentAt=100;assert(not Form.canSend(state,119)and Form.canSend(state,120))
		state.kind="praise";assert(not Form.canSend(state,200))
		assert(Form.defaultCategory({from="pocket"})=="deck"and Form.defaultCategory({mode="Board"})=="deck"and Form.defaultCategory({mode="Room",from="hub"})==nil)
		local spots,height=Form.flow({100,100,100},250,8,36)
		assert(spots[1].x==0 and spots[2].x==108 and spots[3].x==0 and spots[3].y==44 and height==80)
		assert(select(2,Form.flow({},250,8,36))==0)
		local history={{message="fine",messageType="Enum.MessageType.MessageOutput"},{message="warn SkunkDev",messageType="Enum.MessageType.MessageWarning"},
			{message="boom",messageType="Enum.MessageType.MessageError"},{message="info",messageType="Enum.MessageType.MessageInfo"},{message=string.rep("e",300),messageType="Enum.MessageType.MessageError"}}
		local lines=Form.recentErrors(history,{"SkunkDev"},2)
		assert(#lines==2 and lines[1]=="boom"and #lines[2]==160,"newest two, oldest first, cut")
		lines=Form.recentErrors(history,{"SkunkDev"})
		assert(#lines==3 and lines[1]=="warn <player>")
		local p=Form.packet({kind="suggestion",category="pets",note="  hi  "},{device="touch",width=812,height=354,mode="Room",screen="settings",from="hub",extra=1},lines,"nonce-1")
		assert(p.nonce=="nonce-1"and p.note=="hi"and p.context.device=="touch"and p.context.extra==nil and #p.context.errors==3)
		assert(Form.packet({kind="bug",category="pets",note="   "},nil,{},"n").note==nil)
		local clean=Reports.validate(p,{});assert(clean and clean.kind=="suggestion"and clean.note=="hi","the form's packet passes validation")
	end)

	return cases
end
