-- In-game bug reports and suggestions (v1 track B; ONBOARDING-V1-SCOPE-2026-11-13
-- section 4, Spencer's decisions: UserId only, purged at 30 days, DataStore queue).
--
-- Storage: its own DataStore (`EggDropReportsV1`, never the economy save). One key per
-- UTC day, `day_<n>` = {v=1, reports={...}}, appended with UpdateAsync. The per-player
-- daily and 10-minute limits are counted inside that transform, so they hold across
-- servers without a second key. A sweep (at most once a day across all servers, gated
-- by the `sweep` key) lists `day_` keys and removes every day 30 or more days old.
--
-- Privacy (Roblox policy, children's privacy): the only identifier kept is the UserId
-- (to match a "my Stars are gone" report to a save and to erase on request). No names,
-- chat, friends, locale or avatar data. The optional note goes through
-- TextService:FilterStringAsync + GetNonChatStringForBroadcastAsync for the reporter;
-- if the filter fails or hides anything, the note is dropped and the rest is kept.
-- Notes are never shown to another player. Log lines are scrubbed of every name in the
-- server and limited to printable ASCII.
--
-- Everything that touches Roblox services goes through an adapter, so the spec runs
-- the real limits, filter path, validation, purge selection and owner check offline.
local Reports={}
Reports.StoreName="EggDropReportsV1"
Reports.Owner=10716920546
Reports.RetentionDays=30
Reports.NoteMax=200
Reports.Kinds={"bug","suggestion"}
Reports.Categories={"deck","garden","park","menus","pets","stars","other"}
Reports.Devices={"touch","keyboard","gamepad","vr","unknown"}
Reports.Limits={
	minGap=20,          -- seconds between two sends from one player (the client greys Send as long)
	window=600,         -- 10 minutes...
	windowCount=3,      -- ...3 reports
	dailyCount=20,      -- per player per UTC day (counted in the day key, across servers)
	serverHourly=60,    -- per server per hour
	dayCap=400,         -- reports per day key (about 1 KB each, far under the 4 MB value limit)
	duplicateWindow=600,-- same kind + category + note from one player within 10 min: not stored again
	eventGap=1,         -- remote events closer than this are dropped before any work
}
Reports.MaxErrors=5
Reports.ErrorLength=160
Reports.MaxRecordBytes=2000
Reports.PendingAttempts=3

local KindSet,CategorySet,DeviceSet={},{},{}
for _,id in ipairs(Reports.Kinds)do KindSet[id]=true end
for _,id in ipairs(Reports.Categories)do CategorySet[id]=true end
for _,id in ipairs(Reports.Devices)do DeviceSet[id]=true end

function Reports.dayOf(t)return math.floor(t/86400)end
function Reports.dayKey(day)return "day_"..tostring(day)end
function Reports.canRead(userId)return type(userId)=="number"and userId==Reports.Owner end

-- Pure: a player's note, trimmed and cleaned, or nil when empty / not text.
-- Control characters become spaces, runs of space collapse, invalid UTF-8 is refused,
-- and anything past NoteMax characters is cut.
function Reports.cleanNote(text)
	if type(text)~="string"then return nil end
	if #text>Reports.NoteMax*4 then text=string.sub(text,1,Reports.NoteMax*4)end
	-- Cut mid-character by the byte cap above, or not UTF-8 at all: keep the valid prefix.
	local valid,bad=utf8.len(text)
	if valid==nil and bad then text=string.sub(text,1,bad-1)end
	text=string.gsub(text,"%c"," ")
	text=string.gsub(text,"%s+"," ")
	text=string.match(text,"^%s*(.-)%s*$")or ""
	if text==""then return nil end
	if utf8.len(text)>Reports.NoteMax then text=string.sub(text,1,utf8.offset(text,Reports.NoteMax+1)-1)end
	return text
end

local function token(value,maxLength)
	if type(value)~="string"or value==""or #value>maxLength then return nil end
	return if string.match(value,"^[%w_%-%.]+$")then value else nil
end
local function whole(value,low,high)
	if type(value)~="number"or value~=value then return nil end
	return math.clamp(math.floor(value+.5),low,high)
end

-- Pure: one log line, cut to ErrorLength, printable ASCII only, with every name in
-- `names` (the server's players' names and display names) replaced by <player>.
function Reports.scrubLine(line,names)
	if type(line)~="string"then return nil end
	line=string.sub(line,1,Reports.ErrorLength*2)
	if names then
		for _,name in ipairs(names)do
			if type(name)=="string"and #name>=3 then
				local pattern=string.gsub(name,"[%^%$%(%)%%%.%[%]%*%+%-%?]","%%%0")
				line=string.gsub(line,pattern,"<player>")
			end
		end
	end
	line=string.gsub(line,"[^\32-\126]","?")
	line=string.sub(line,1,Reports.ErrorLength)
	return if line==""then nil else line
end

-- Pure: the client packet checked field by field. Returns a clean table or nil, reason.
-- Unknown fields are ignored; nothing the client sends is stored without a check.
function Reports.validate(packet,names)
	if type(packet)~="table"then return nil,"Malformed"end
	local nonce=token(packet.nonce,40)
	if not nonce then return nil,"Malformed"end
	if not KindSet[packet.kind]then return nil,"Kind",nonce end
	if not CategorySet[packet.category]then return nil,"Category",nonce end
	if packet.note~=nil and type(packet.note)~="string"then return nil,"Note",nonce end
	if type(packet.note)=="string"and #packet.note>Reports.NoteMax*4 then return nil,"Note",nonce end
	local context=packet.context
	if context~=nil and type(context)~="table"then return nil,"Context",nonce end
	context=context or {}
	local clean={nonce=nonce,kind=packet.kind,cat=packet.category,note=Reports.cleanNote(packet.note)}
	clean.dev=if DeviceSet[context.device]then context.device else "unknown"
	clean.vw=whole(context.width,0,10000)
	clean.vh=whole(context.height,0,10000)
	clean.mode=token(context.mode,24)
	clean.scr=token(context.screen,32)
	clean.from=token(context.from,24)
	clean.text=token(context.textSize,24)
	clean.rm=if context.reducedMotion==true then true else nil
	local errors={}
	if type(context.errors)=="table"then
		for index=1,math.min(#context.errors,Reports.MaxErrors)do
			local line=Reports.scrubLine(context.errors[index],names)
			if line then table.insert(errors,line)end
		end
	end
	clean.errs=if #errors>0 then errors else nil
	return clean
end

-- Pure: may `userId` add a report to this day's list at `now`? Counts the stored list.
-- Returns "ok" | "Daily" | "Window" | "Duplicate" | "Full", and seconds to wait.
function Reports.checkStored(reports,userId,now,record)
	local L=Reports.Limits
	if #reports>=L.dayCap then return "Full",0 end
	local daily,inWindow,oldest=0,0,nil
	for _,report in ipairs(reports)do
		if report.uid==userId then
			daily+=1
			if now-report.t<L.window then
				inWindow+=1
				if oldest==nil or report.t<oldest then oldest=report.t end
			end
			if record and now-report.t<L.duplicateWindow and report.kind==record.kind and report.cat==record.cat and report.note==record.note then
				return "Duplicate",0
			end
		end
	end
	if daily>=L.dailyCount then return "Daily",math.max(1,(Reports.dayOf(now)+1)*86400-now)end
	if inWindow>=L.windowCount then return "Window",math.max(1,(oldest or now)+L.window-now)end
	return "ok",0
end

-- Pure: the same limits on one server's memory (cheap, before any DataStore call).
-- `sent` = this player's send times this session, `server` = this server's send times.
function Reports.checkSession(sent,server,now)
	local L=Reports.Limits
	local last=sent[#sent]
	if last and now-last<L.minGap then return "Gap",math.ceil(last+L.minGap-now)end
	local inWindow,oldest=0,nil
	for _,t in ipairs(sent)do
		if now-t<L.window then inWindow+=1;if oldest==nil or t<oldest then oldest=t end end
	end
	if inWindow>=L.windowCount then return "Window",math.ceil(oldest+L.window-now)end
	local hourly=0
	for _,t in ipairs(server)do if now-t<3600 then hourly+=1 end end
	if hourly>=L.serverHourly then return "Server",60 end
	return "ok",0
end

-- Pure: which `day_` keys the sweep removes on `today` (30 or more days old).
function Reports.expiredKeys(keys,today)
	local out={}
	for _,key in ipairs(keys)do
		local day=tonumber(string.match(key,"^day_(%d+)$"))
		if day and today-day>=Reports.RetentionDays then table.insert(out,key)end
	end
	table.sort(out)
	return out
end

local function trimTimes(list,now,keep)
	for index=#list,1,-1 do if now-list[index]>=keep then table.remove(list,index)end end
end

local Service={}
Service.__index=Service

-- adapter = {
--   now() -> unix seconds, guid() -> string, placeVersion() -> number,
--   filter(userId, text) -> ok, filteredText   (may yield; errors are caught by the caller)
--   update(key, transform) -> value             (UpdateAsync; may error)
--   get(key) -> value, remove(key), listKeys(prefix) -> {key names}
--   encode(value) -> string (JSON, for the size cap), log(line)
-- }
function Reports.new(adapter)
	return setmetatable({adapter=adapter,sessionSent={},serverSent={},inFlight={},pendingQueue={},lastEvent={},lastSweepDay=nil},Service)
end

-- Filter the note for the reporter (adapter.filter returns ok, text and may error).
-- Returns the note to store (or nil) and its state: "none" (no note), "kept",
-- "hidden" (the filter changed something: the whole note is dropped), "failed" (dropped).
local function filterWith(adapter,userId,note)
	if not note then return nil,"none"end
	local called,ok,text=pcall(adapter.filter,userId,note)
	if not called or ok~=true or type(text)~="string"then return nil,"failed"end
	if text~=note then return nil,"hidden"end
	return text,"kept"
end
Reports.filterWith=filterWith

-- Try to append `record` to its day key. Returns status ("Sent", "Duplicate", "Daily",
-- "Window", "Full") or nil, error when the store call fails.
function Service:append(record)
	local status,wait="Sent",0
	local key=Reports.dayKey(Reports.dayOf(record.t))
	local ok,problem=pcall(self.adapter.update,key,function(old)
		local value=if type(old)=="table"and type(old.reports)=="table"then old else {v=1,reports={}}
		local verdict,seconds=Reports.checkStored(value.reports,record.uid,record.t,record)
		if verdict~="ok"then
			status=verdict;wait=seconds
			return nil
		end
		status,wait="Sent",0
		table.insert(value.reports,record)
		return value
	end)
	if not ok then return nil,problem end
	return status,wait
end

local function logLine(record,status)
	local note=if record.note then string.format(" note=%q",string.sub(record.note,1,80))else (if record.noteState~="none"then " note="..record.noteState else "")
	return string.format("[EggDropReport] %s %s/%s pv=%s %s %sx%s mode=%s screen=%s errs=%d id=%s%s",
		status,record.kind,record.cat,tostring(record.pv),record.dev,tostring(record.vw or "?"),tostring(record.vh or "?"),
		tostring(record.mode or "-"),tostring(record.scr or "-"),record.errs and #record.errs or 0,record.id,note)
end
Reports.logLine=logLine

-- Fit the record under MaxRecordBytes by dropping log lines, then the note.
local function fit(adapter,record)
	if not adapter.encode then return record end
	while #adapter.encode(record)>Reports.MaxRecordBytes do
		if record.errs and #record.errs>0 then
			table.remove(record.errs,1)
			if #record.errs==0 then record.errs=nil end
		elseif record.note then record.note=nil;record.noteState="size"
		else break end
	end
	return record
end

-- One report from one player. Returns a reply {nonce, status, wait?, id?}.
-- status: Sent | Duplicate | Queued | Limited | Invalid | Busy | Full
function Service:submit(userId,packet,names)
	local now=self.adapter.now()
	local clean,reason,nonce=Reports.validate(packet,names)
	if not clean then
		return{nonce=nonce,status="Invalid",reason=reason}
	end
	if self.inFlight[userId]then return{nonce=clean.nonce,status="Busy"}end
	local sent=self.sessionSent[userId]or {}
	self.sessionSent[userId]=sent
	trimTimes(sent,now,86400);trimTimes(self.serverSent,now,3600)
	local verdict,wait=Reports.checkSession(sent,self.serverSent,now)
	if verdict~="ok"then return{nonce=clean.nonce,status="Limited",reason=verdict,wait=wait}end
	self.inFlight[userId]=true
	-- Counted from here on: a refused or failed store call still spends the session slot.
	table.insert(sent,now);table.insert(self.serverSent,now)
	local note,noteState=filterWith(self.adapter,userId,clean.note)
	local record={id=string.sub(string.gsub(self.adapter.guid(),"[^%w]",""),1,12),uid=userId,t=now,pv=self.adapter.placeVersion(),
		kind=clean.kind,cat=clean.cat,note=note,noteState=noteState,dev=clean.dev,vw=clean.vw,vh=clean.vh,
		mode=clean.mode,scr=clean.scr,from=clean.from,text=clean.text,rm=clean.rm,errs=clean.errs}
	fit(self.adapter,record)
	local status,detail=self:append(record)
	self.inFlight[userId]=nil
	if status==nil then
		table.insert(self.pendingQueue,{record=record,attempts=1})
		if self.adapter.log then self.adapter.log(logLine(record,"QUEUED")..(" ("..tostring(detail)..")"))end
		return{nonce=clean.nonce,status="Queued",id=record.id,noteState=noteState}
	end
	if status=="Sent"then
		if self.adapter.log then self.adapter.log(logLine(record,"NEW"))end
		return{nonce=clean.nonce,status="Sent",id=record.id,noteState=noteState}
	end
	if status=="Duplicate"then return{nonce=clean.nonce,status="Duplicate",noteState=noteState}end
	if status=="Full"then return{nonce=clean.nonce,status="Full"}end
	return{nonce=clean.nonce,status="Limited",reason=status,wait=detail}
end

-- Retry reports a failed store call left on this server. Returns how many landed.
function Service:retryPending()
	local landed=0
	for index=#self.pendingQueue,1,-1 do
		local entry=self.pendingQueue[index]
		local status=self:append(entry.record)
		if status~=nil then
			table.remove(self.pendingQueue,index);landed+=if status=="Sent"then 1 else 0
			if self.adapter.log and status=="Sent"then self.adapter.log(logLine(entry.record,"NEW"))end
		else
			entry.attempts+=1
			if entry.attempts>Reports.PendingAttempts then
				table.remove(self.pendingQueue,index)
				if self.adapter.log then self.adapter.log(logLine(entry.record,"LOST"))end
			end
		end
	end
	return landed
end

-- Purge: once a day across all servers (the `sweep` key holds the last swept day).
-- Returns the removed keys, or nil and a reason ("Swept", "Throttled", or an error).
function Service:sweep(force)
	local today=Reports.dayOf(self.adapter.now())
	if not force and self.lastSweepDay==today then return nil,"Throttled"end
	self.lastSweepDay=today
	local claimed=false
	local ok,problem=pcall(self.adapter.update,"sweep",function(old)
		if not force and type(old)=="table"and old.day==today then claimed=false;return nil end
		claimed=true
		return{day=today}
	end)
	if not ok then return nil,problem end
	if not claimed then return nil,"Swept"end
	local listed,keys=pcall(self.adapter.listKeys,"day_")
	if not listed then return nil,keys end
	local removed={}
	for _,key in ipairs(Reports.expiredKeys(keys,today))do
		if pcall(self.adapter.remove,key)then table.insert(removed,key)end
	end
	if #removed>0 and self.adapter.log then self.adapter.log("[EggDropReport] purged "..#removed.." day key(s) older than "..Reports.RetentionDays.." days")end
	return removed
end

-- Owner only: recent reports, newest first.
-- options = {days = 1..30 (7), kind?, category?, limit = 1..200 (50)}
function Service:recent(requesterId,options)
	if not Reports.canRead(requesterId)then return nil,"NotOwner"end
	options=if type(options)=="table"then options else {}
	local now=self.adapter.now()
	local today=Reports.dayOf(now)
	local days=math.clamp(math.floor(tonumber(options.days)or 7),1,Reports.RetentionDays)
	local limit=math.clamp(math.floor(tonumber(options.limit)or 50),1,200)
	local out={}
	for day=today,today-days+1,-1 do
		local ok,value=pcall(self.adapter.get,Reports.dayKey(day))
		if ok and type(value)=="table"and type(value.reports)=="table"then
			for index=#value.reports,1,-1 do
				local report=value.reports[index]
				local fresh=now-report.t<Reports.RetentionDays*86400
				if fresh and(options.kind==nil or report.kind==options.kind)and(options.category==nil or report.cat==options.category)then
					table.insert(out,report)
				end
			end
		end
	end
	table.sort(out,function(a,b)return a.t>b.t end)
	while #out>limit do table.remove(out)end
	return out
end

-- Owner only: remove every report from one UserId (an erasure request). Returns the count.
function Service:eraseUser(requesterId,userId)
	if not Reports.canRead(requesterId)then return nil,"NotOwner"end
	if type(userId)~="number"then return nil,"UserId"end
	local listed,keys=pcall(self.adapter.listKeys,"day_")
	if not listed then return nil,keys end
	local total=0
	for _,key in ipairs(keys)do
		local removed=0
		local ok=pcall(self.adapter.update,key,function(old)
			removed=0
			if type(old)~="table"or type(old.reports)~="table"then return nil end
			for index=#old.reports,1,-1 do
				if old.reports[index].uid==userId then table.remove(old.reports,index);removed+=1 end
			end
			return if removed>0 then old else nil
		end)
		if ok then total+=removed end
	end
	return total
end

-- Owner only: plain-text lines for the command bar / developer console.
function Reports.format(reports)
	local lines={}
	for _,r in ipairs(reports or {})do
		table.insert(lines,string.format("%s  %s/%s  uid=%d  pv=%s  %s %sx%s  mode=%s screen=%s from=%s  id=%s",
			os.date("!%Y-%m-%d %H:%M",r.t),r.kind,r.cat,r.uid,tostring(r.pv),tostring(r.dev),tostring(r.vw or "?"),tostring(r.vh or "?"),
			tostring(r.mode or "-"),tostring(r.scr or "-"),tostring(r.from or "-"),tostring(r.id)))
		if r.note then table.insert(lines,"    note: "..r.note)
		elseif r.noteState and r.noteState~="none"then table.insert(lines,"    note: ("..r.noteState..")")end
		for _,e in ipairs(r.errs or {})do table.insert(lines,"    log: "..e)end
	end
	return table.concat(lines,"\n")
end

-- ── Roblox adapters and host ────────────────────────────────────────────────

-- The production adapter for `storeName` (a real DataStore), or an in-memory one.
function Reports.adapterFor(storeName,useMemory)
	local HttpService=game:GetService("HttpService")
	local TextService=game:GetService("TextService")
	local memory={}
	local store=nil
	local DataStoreService=nil
	if not useMemory then
		DataStoreService=game:GetService("DataStoreService")
		store=DataStoreService:GetDataStore(storeName)
	end
	local function copy(value)
		if type(value)~="table"then return value end
		local out={};for k,v in pairs(value)do out[k]=copy(v)end;return out
	end
	local function budget(kind)
		if not DataStoreService then return end
		local deadline=os.clock()+3
		while os.clock()<deadline do
			local ok,left=pcall(DataStoreService.GetRequestBudgetForRequestType,DataStoreService,kind)
			if not ok or left>0 then return end
			task.wait(.25)
		end
	end
	return{
		memory=memory,live=store~=nil,
		now=function()return os.time()end,
		guid=function()return HttpService:GenerateGUID(false)end,
		placeVersion=function()return game.PlaceVersion end,
		encode=function(value)return HttpService:JSONEncode(value)end,
		log=function(line)print(line)end,
		filter=function(userId,text)
			local result=TextService:FilterStringAsync(text,userId,Enum.TextFilterContext.PublicChat)
			return true,result:GetNonChatStringForBroadcastAsync()
		end,
		update=function(key,transform)
			if not store then
				local value=transform(copy(memory[key]))
				if value~=nil then memory[key]=copy(value)end
				return copy(value)
			end
			budget(Enum.DataStoreRequestType.UpdateAsync)
			return store:UpdateAsync(key,transform)
		end,
		get=function(key)
			if not store then return copy(memory[key])end
			budget(Enum.DataStoreRequestType.GetAsync)
			return store:GetAsync(key)
		end,
		remove=function(key)
			if not store then memory[key]=nil;return end
			store:RemoveAsync(key)
		end,
		listKeys=function(prefix)
			local out={}
			if not store then
				for key in pairs(memory)do if string.sub(key,1,#prefix)==prefix then table.insert(out,key)end end
				return out
			end
			local pages=store:ListKeysAsync(prefix,100)
			while true do
				for _,entry in ipairs(pages:GetCurrentPage())do table.insert(out,entry.KeyName)end
				if pages.IsFinished then break end
				pages:AdvanceToNextPageAsync()
			end
			return out
		end,
	}
end

-- Studio Edit command bar (Game Settings > Security > Studio access to API services on):
--   print(require(game.ServerScriptService.Server.BugReportStore).readLive(10716920546, {days = 7}))
-- Reads the live store directly. Owner UserId only.
function Reports.readLive(requesterId,options)
	if not Reports.canRead(requesterId)then return "NotOwner"end
	local ok,result=pcall(function()
		local service=Reports.new(Reports.adapterFor(Reports.StoreName,false))
		return Reports.format(service:recent(requesterId,options))
	end)
	return if ok then result else "Could not read reports: "..tostring(result)
end

-- Server host: the `BugReport` remote, the owner tool, the retry + sweep loop.
-- Studio writes go to memory (test reports never reach the live queue); the tool's
-- `live = true` option reads the live store from a Studio Play server.
function Reports.mount(remotes)
	local Players=game:GetService("Players")
	local RunService=game:GetService("RunService")
	local studio=RunService:IsStudio()
	local adapter=Reports.adapterFor(Reports.StoreName,studio)
	local service=Reports.new(adapter)
	Reports.service=service
	local remote=Instance.new("RemoteEvent");remote.Name="BugReport";remote.Parent=remotes
	local function names()
		local out={}
		for _,player in ipairs(Players:GetPlayers())do table.insert(out,player.Name);table.insert(out,player.DisplayName)end
		return out
	end
	remote.OnServerEvent:Connect(function(player,packet)
		local now=os.clock()
		local last=service.lastEvent[player.UserId]
		if last and now-last<Reports.Limits.eventGap then return end
		service.lastEvent[player.UserId]=now
		if type(packet)~="table"then return end
		local reply=service:submit(player.UserId,packet,names())
		if reply.nonce and player.Parent then remote:FireClient(player,reply)end
	end)
	Players.PlayerRemoving:Connect(function(player)
		service.lastEvent[player.UserId]=nil;service.inFlight[player.UserId]=nil
	end)
	-- Owner-only read helper (server-side only: clients cannot reach ServerStorage).
	--   local tool = game.ServerStorage.EggDropReportsTool
	--   print(tool:Invoke(game.Players:GetPlayers()[1], "list", {days = 7}))
	--   tool:Invoke(owner, "erase", {userId = 123})   tool:Invoke(owner, "sweep")
	local tool=Instance.new("BindableFunction");tool.Name="EggDropReportsTool"
	tool.OnInvoke=function(requester,action,options)
		local id=if typeof(requester)=="Instance"and requester:IsA("Player")then requester.UserId else requester
		if not Reports.canRead(id)then return "NotOwner"end
		options=if type(options)=="table"then options else {}
		if action=="list"or action==nil then
			local source=service
			if options.live==true and studio then source=Reports.new(Reports.adapterFor(Reports.StoreName,false))end
			local ok,result=pcall(function()return Reports.format(source:recent(id,options))end)
			return if ok then result else "Could not read reports: "..tostring(result)
		elseif action=="raw"then
			return service:recent(id,options)
		elseif action=="erase"then
			return service:eraseUser(id,tonumber(options.userId))
		elseif action=="sweep"then
			return service:sweep(true)
		elseif action=="pending"then
			return #service.pendingQueue
		end
		return "UnknownAction"
	end
	tool.Parent=game:GetService("ServerStorage")
	task.spawn(function()
		task.wait(30)
		while true do
			service:retryPending()
			if not studio then service:sweep(false)end
			task.wait(60)
		end
	end)
	game:BindToClose(function()if #service.pendingQueue>0 then service:retryPending()end end)
	return service
end

return Reports
