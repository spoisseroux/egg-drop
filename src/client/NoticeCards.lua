-- Notice cards (QA v735 H5): what a top-bar pill means and what to do next. Every quest
-- ticker and onboarding pill on the notification rail names one of these; a tap on the pill
-- opens it as a two-card "How it works" panel (HowItWorks.openNotice), with one button that
-- takes the player there when it can. Pure: ids, pictures and copy (UICopy `notice`).
--   rail data:  detail={id="questReady",vars={quest="Merge 10",reward=3},run=function()...end}
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local UICopy=require(Shared:WaitForChild("UICopy"))
local Notice={}
-- tint: a Kit.Tint family; icon / nextIcon: Kit.icon names for the two cards; go: where the
-- button leads ("quests" | "hatch" | "companions" | "menu"), nil for no button.
-- nextFrom: another notice whose `next` line this one reuses (G2: firstToy keeps firstSpend's, no new string).
local function define(tint,icon,nextIcon,go,nextFrom)return table.freeze({tint=tint,icon=icon,nextIcon=nextIcon,go=go,nextFrom=nextFrom})end
Notice.ById=table.freeze({
 -- The Welcome round and its Stars.
 welcome=define("results","egg","target",nil),
 firstStars=define("results","star","egg","hatch"),
 locked=define("results","egg","target",nil),
 -- The guided garden step.
 machines=define("hatch","target","settings","menu"),
 hub=define("quests","settings","target","menu"),
 quest=define("quests","quests","check","quests"),
 customize=define("companions","wand","shirt","companions"),
 -- On the deck.
 fillLine=define("hatch","target","sparkle",nil),
 item=define("results","sparkle","target",nil),
 -- Quest tickers.
 questDone=define("quests","check","star","quests"),
 questReady=define("quests","check","star","quests"),
 questClaimed=define("quests","star","egg","hatch"),
 -- The first egg, and bond.
 firstSpend=define("hatch","star","egg","hatch"),
 -- G2 (ToyPillCopy): the same card in the new words.
 firstToy=define("hatch","star","egg","hatch","firstSpend"),
 bond=define("companions","paw","smiley","companions"),
 -- Growth cuts (2026-11-25): the garden's Tomorrow line (TomorrowStrip).
 tomorrow=define("quests","check","quests","quests"),
})
Notice.Order=table.freeze({"welcome","firstStars","locked","machines","hub","quest","customize","fillLine","item",
 "questDone","questReady","questClaimed","firstSpend","firstToy","bond","tomorrow"})
Notice.Targets=table.freeze({"quests","hatch","companions","menu"})
-- Values every line can be filled from when the caller has none.
Notice.Defaults=table.freeze({pet="your pet",reward="",quest="A quest"})
function Notice.has(id)return type(id)=="string"and Notice.ById[id]~=nil end
local function fill(vars)
 local out=table.clone(Notice.Defaults)
 if type(vars)=="table"then for key,value in pairs(vars)do if value~=nil then out[key]=value end end end
 return out
end
function Notice.title(id,vars)return UICopy.get("notice."..id..".title",fill(vars))end
-- The two cards: {{key="what", icon, title, line}, {key="next", ...}}.
function Notice.cards(id,vars)
 local row=Notice.ById[id];if not row then return {}end
 local values=fill(vars)
 return{
  {key="what",icon=row.icon,title=UICopy.get("notice.label.what"),line=UICopy.get("notice."..id..".what",values)},
  {key="next",icon=row.nextIcon,title=UICopy.get("notice.label.next"),line=UICopy.get("notice."..(row.nextFrom or id)..".next",values)},
 }
end
-- The button: {target, text}, or nil when the notice leads nowhere.
function Notice.go(id)
 local row=Notice.ById[id]
 if not row or not row.go then return nil end
 return{target=row.go,text=UICopy.get("notice.go."..row.go)}
end
-- A rail `detail` for `id` (nil for an unknown id, so a caller can pass it straight on).
function Notice.detail(id,vars,run)
 if not Notice.has(id)then return nil end
 return{id=id,vars=vars,run=run}
end
return table.freeze(Notice)
