-- The bug report / suggestion form's rules (v1 track B), pure so the spec runs them
-- offline. The sheet (client/BugReportSheet) draws them; the server
-- (server/BugReportStore) re-checks everything and owns the real limits. The ids
-- here must match BugReportStore.Kinds / .Categories (the spec checks).
local Form={}
Form.Kinds={"bug","suggestion"}
Form.Categories={"deck","garden","park","menus","pets","stars","other"}
Form.NoteMax=200
Form.Cooldown=20      -- seconds Send stays grey after a send (BugReportStore.Limits.minGap)
Form.ReplyTimeout=12  -- seconds before "no reply" shows
Form.MaxErrors=5
Form.ErrorLength=160

local CategorySet={}
for _,id in ipairs(Form.Categories)do CategorySet[id]=true end

-- Characters in a note (UTF-8 aware); invalid text counts its bytes.
function Form.length(text)
	if type(text)~="string"then return 0 end
	return utf8.len(text)or #text
end
-- The note cut to NoteMax characters (the TextBox calls this on every change).
function Form.clip(text)
	if type(text)~="string"then return ""end
	local valid,bad=utf8.len(text)
	if valid==nil and bad then text=string.sub(text,1,bad-1)end
	if utf8.len(text)>Form.NoteMax then text=string.sub(text,1,utf8.offset(text,Form.NoteMax+1)-1)end
	return text
end

-- The category a fresh form starts on, from where it was opened. nil = none chosen.
function Form.defaultCategory(context)
	if type(context)~="table"then return nil end
	if context.from=="pocket"or context.mode=="Board"then return "deck"end
	if context.park==true then return "park"end
	return nil
end

-- Send is allowed with a kind and a category, not while one is in flight, and not
-- inside the cooldown.
function Form.canSend(state,now)
	if type(state)~="table"or state.sending then return false end
	if state.kind~="bug"and state.kind~="suggestion"then return false end
	if not CategorySet[state.category]then return false end
	if state.sentAt and now-state.sentAt<Form.Cooldown then return false end
	return true
end

-- Last `count` warnings and errors from a LogService:GetLogHistory() list, oldest
-- first, cut to ErrorLength, with the local player's names replaced by <player>.
-- `history` items: {message=string, messageType=string ("MessageError"...)}.
function Form.recentErrors(history,names,count)
	count=count or Form.MaxErrors
	local out={}
	if type(history)~="table"then return out end
	for index=#history,1,-1 do
		local item=history[index]
		local kind=item and tostring(item.messageType)
		if kind and(string.find(kind,"Error",1,true)or string.find(kind,"Warning",1,true))and type(item.message)=="string"then
			local line=item.message
			for _,name in ipairs(names or {})do
				if type(name)=="string"and #name>=3 then
					line=string.gsub(line,(string.gsub(name,"[%^%$%(%)%%%.%[%]%*%+%-%?]","%%%0")),"<player>")
				end
			end
			table.insert(out,1,string.sub(line,1,Form.ErrorLength))
			if #out>=count then break end
		end
	end
	return out
end

-- The packet for the BugReport remote.
function Form.packet(state,context,errors,nonce)
	context=type(context)=="table"and context or {}
	local note=Form.clip(state.note or "")
	note=string.match(note,"^%s*(.-)%s*$")or ""
	return{nonce=nonce,kind=state.kind,category=state.category,note=if note~=""then note else nil,
		context={device=context.device,width=context.width,height=context.height,mode=context.mode,screen=context.screen,
			from=context.from,textSize=context.textSize,reducedMotion=context.reducedMotion,errors=errors}}
end

-- Chip rows: positions for chips of `widths` inside `maxWidth`, wrapping, `gap` apart.
-- Returns {{x, y}...} and the total height for rows `height` tall.
function Form.flow(widths,maxWidth,gap,height)
	local out,x,y={},0,0
	for index,w in ipairs(widths)do
		if x>0 and x+w>maxWidth then x=0;y+=height+gap end
		out[index]={x=x,y=y}
		x+=w+gap
	end
	return out,(if #widths>0 then y+height else 0)
end

-- UICopy key for a server reply (nil while waiting). Sent and Duplicate both thank.
function Form.replyKey(reply,kind)
	if type(reply)~="table"then return "report.reply.timeout"end
	local status=reply.status
	if status=="Queued"then return "report.thanks.queued"end
	if status=="Sent"or status=="Duplicate"then
		return if kind=="suggestion"then "report.thanks.suggestion"else "report.thanks.bug"
	end
	if status=="Limited"then return "report.reply.limited"end
	if status=="Full"then return "report.reply.full"end
	if status=="Busy"then return "report.reply.busy"end
	return "report.reply.invalid"
end

return Form
