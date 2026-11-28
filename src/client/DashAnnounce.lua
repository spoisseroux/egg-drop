-- Garden Dash server messages on this screen (beta 44 note 22; DashWire's DashAnnounce). The server sends ids, never
-- words: {kind="soon"} when a race opens, {kind="won", userId, name (the winner's Roblox DisplayName), petId, pieces?}
-- when a player's pet wins. The words come from UICopy `dash.say` (through the cloud table's translator when it has
-- them); a pet's name from NameCatalog pieces (authored, never typed), unknown or none: "<name>'s pet".
-- Where it shows: a system message in the chat window (TextChatService, RBXGeneral), which every player in the server
-- reads and which never covers the race. Legacy chat, the chat window off or no RBXGeneral: the Dash notification
-- rail instead (held during this player's own race like every notice). Nothing here can reach the race: every step
-- is protected and a message that fails is dropped with one warning.
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage").Shared
local UICopy=require(Shared.UICopy)
local Names=require(Shared.NameCatalog)

local Announce={}
Announce.Colour="#FFD166" -- a warm gold, so the line reads as the garden's, not a player's
Announce.RailSeconds=5
Announce.MaxName=40

-- The UICopy key and its plain vars for a packet, or nil for anything malformed.
function Announce.words(packet)
	if type(packet)~="table"then return nil end
	if packet.kind=="soon"then return "dash.say.soon",nil end
	if packet.kind~="won"then return nil end
	local player=packet.name
	if type(player)~="string"or player==""or #player>Announce.MaxName then return nil end
	local pet=Names.display(if type(packet.pieces)=="table"then packet.pieces else nil,nil)
	if pet then return "dash.say.won",{player=player,pet=pet}end
	return "dash.say.wonPet",{player=player}
end
-- Rich text is on in the chat window: a name can never open a tag.
function Announce.escape(text)
	return(string.gsub(text,"[&<>\"']",{["&"]="&amp;",["<"]="&lt;",[">"]="&gt;",["\""]="&quot;",["'"]="&apos;"}))
end
-- The words in this player's language: the cloud table's own entry (`ui.<key>`) when it has one, else UICopy.
function Announce.format(key,vars,translator)
	if translator then
		local ok,text=pcall(translator.FormatByKey,translator,"ui."..key,vars or {})
		if ok and type(text)=="string"and text~=""then return text end
	end
	return UICopy.get(key,vars)
end
function Announce.text(packet,translator)
	local key,vars=Announce.words(packet)
	if not key then return nil end
	return Announce.format(key,vars,translator),key
end

-- The chat window's system line; false where there is no TextChatService chat to post in.
function Announce.chat(text)
	local TextChatService=game:GetService("TextChatService")
	if TextChatService.ChatVersion~=Enum.ChatVersion.TextChatService then return false end
	local window=TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	if window and window.Enabled==false then return false end
	local channels=TextChatService:FindFirstChild("TextChannels")
	local general=channels and channels:FindFirstChild("RBXGeneral")
	if not general or not general:IsA("TextChannel")then return false end
	general:DisplaySystemMessage('<font color="'..Announce.Colour..'">'..Announce.escape(text).."</font>")
	return true
end

-- deps: owner (the rail's owner folder), rail (NotificationRail; optional), translator (optional),
-- chat(text) -> bool (specs replace it). Answers "chat", "rail" or nil.
function Announce.post(packet,deps)
	deps=deps or {}
	local text,key=Announce.text(packet,deps.translator)
	if not text then return nil end
	local ok,posted=pcall(deps.chat or Announce.chat,text)
	if ok and posted==true then return "chat"end
	if not ok then warn("[Dash] chat message: "..tostring(posted))end
	if deps.rail and deps.owner then
		local sent=pcall(deps.rail.enqueue,deps.owner,key,{text=text,icon="•",duration=Announce.RailSeconds})
		if sent then return "rail"end
	end
	return nil
end

-- This player's translator for the cloud table, asked for once (it yields); nil until it answers or if it cannot.
local translator,asked=nil,false
function Announce.translator()
	if not asked then
		asked=true
		task.spawn(function()
			local ok,found=pcall(function()
				return game:GetService("LocalizationService"):GetTranslatorForPlayerAsync(Players.LocalPlayer)
			end)
			if ok then translator=found end
		end)
	end
	return translator
end

return Announce
