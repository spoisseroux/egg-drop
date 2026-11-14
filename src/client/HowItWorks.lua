-- "How it works" cards (QA 2026-11-13 v2, R3.8). Every machine screen's header
-- carries a ? circle (Kit.header, from the screen's tint family) that opens two or
-- three short illustrated cards for that machine, side by side, in the house voice
-- (UICopy `r3.help`). Replayable any time; nothing is saved. The stamp card is
-- explained on the Quests set (what a stamp is, one a day, what a full card gives),
-- with a live mini stamp card as its picture.
--
-- One overlay for the whole client: its own ScreenGui above every menu, a Kit shade
-- that joins the Q2 shade stack as an *overlay* (it dims over the screen it explains
-- without telling that screen it is covered). B / Backspace closes, A / Enter /
-- Space is "Got it" (the button is also selected for gamepads), and a tap or click
-- outside the panel closes too. Every other menu key is swallowed while it shows.
--
-- Hooks: HowItWorks.open(id, options) (options.onClosed), HowItWorks.close(),
-- HowItWorks.isOpen(), HowItWorks.list() -> {{id, title}} in hub order, for a
-- "Show tips again" row (Settings or the hub, R1) to replay any set.
local Players=game:GetService("Players")
local GuiService=game:GetService("GuiService")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local Shared=game:GetService("ReplicatedStorage").Shared
local UICopy=require(Shared.UICopy)
local Kit=require(script.Parent.DeckKit)
local How={}

-- Card sets. `icon` is a Kit.icon name; `art` names a special picture ("stamps").
How.Sets=table.freeze({
 hatch=table.freeze({tint="hatch",cards=table.freeze({
  table.freeze({key="a",icon="star"}),table.freeze({key="b",icon="egg"}),table.freeze({key="c",icon="sparkle"})})}),
 style=table.freeze({tint="style",cards=table.freeze({
  table.freeze({key="a",icon="faceplate"}),table.freeze({key="b",icon="pattern"}),table.freeze({key="c",icon="ball"})})}),
 companions=table.freeze({tint="companions",cards=table.freeze({
  table.freeze({key="a",icon="paw"}),table.freeze({key="b",icon="shirt"}),table.freeze({key="c",icon="wand"})})}),
 quests=table.freeze({tint="quests",cards=table.freeze({
  table.freeze({key="a",icon="quests"}),table.freeze({key="b",art="stamps"}),table.freeze({key="c",icon="trophy"})})}),
 book=table.freeze({tint="book",cards=table.freeze({
  table.freeze({key="a",icon="book"}),table.freeze({key="b",icon="star"}),table.freeze({key="c",icon="trophy"})})}),
 park=table.freeze({tint="companions",cards=table.freeze({
  table.freeze({key="a",icon="paw"}),table.freeze({key="b",icon="smiley"})})}),
})
How.Order=table.freeze({"hatch","style","companions","quests","book","park"})
How.DisplayOrder=40 -- above every menu ScreenGui (12 to 14) and the coach cards
How.Action="EggDropHowItWorks"
-- The mini stamp card on the Quests set: three stamps down, today's waiting.
How.StampSample=table.freeze({stamps=3,dailyAvailable=true})

-- ── Pure ─────────────────────────────────────────────────────────────────────
function How.has(id)return How.Sets[id]~=nil end
function How.title(id)return UICopy.get("r3.help."..id..".title")end
-- The cards of a set: {{key, icon, art, title, line}}.
function How.cards(id)
 local set=How.Sets[id];if not set then return {}end
 local out={}
 for _,card in ipairs(set.cards)do
  table.insert(out,{key=card.key,icon=card.icon,art=card.art,
   title=UICopy.get("r3.help."..id.."."..card.key..".title"),line=UICopy.get("r3.help."..id.."."..card.key..".line")})
 end
 return out
end
function How.list()
 local out={}
 for _,id in ipairs(How.Order)do table.insert(out,{id=id,title=How.title(id)})end
 return out
end
-- Layout for a host of size W x H and `n` cards. Phones (Kit.compactRule) get the
-- compact type and a smaller picture; the cards always sit side by side.
-- Returns {compact, pad, gap, headerH, footerH, panelW, panelH, cardW, cardH,
-- picture, titleSize, lineSize, lineH}.
function How.layout(W,H,cards)
 local compact=Kit.compactRule(W,H)
 local n=math.max(1,#cards)
 local pad=if compact then 16 else 24
 local gap=if compact then 10 else 16
 local panelW=math.floor(math.min(W-(if compact then 24 else 48),if n<=2 then 640 else 820))
 local cardW=math.floor((panelW-pad*2-gap*(n-1))/n)
 local inner=cardW-(if compact then 24 else 32)
 local titleSize=if compact then 15 else 18
 local lineSize=if compact then 13 else 15
 local lineH=0
 for _,card in ipairs(cards)do
  lineH=math.max(lineH,Kit.measure(card.line,"Small",lineSize,inner).Y)
 end
 lineH=math.ceil(lineH)
 local picture=if compact then 44 else 64
 local hasStamps=false
 for _,card in ipairs(cards)do if card.art=="stamps"then hasStamps=true end end
 local pictureH=picture
 if hasStamps then pictureH=math.max(picture,require(script.Parent.StampCardView).height(true))end
 local cardPad=if compact then 12 else 16
 local cardH=cardPad+pictureH+(if compact then 8 else 12)+math.ceil(titleSize*1.3)+4+lineH+cardPad
 local headerH=if compact then 52 else 72
 local footerH=if compact then 64 else 80
 local panelH=headerH+cardH+footerH
 -- Very short screens: the lines keep their height; the card loses picture room first.
 local room=H-(if compact then 12 else 48)
 if panelH>room then
  local cut=math.min(panelH-room,pictureH-28)
  pictureH-=cut;cardH-=cut;panelH-=cut
 end
 return{compact=compact,pad=pad,gap=gap,headerH=headerH,footerH=footerH,panelW=panelW,panelH=panelH,cardW=cardW,cardH=cardH,
  picture=math.min(picture,pictureH),pictureH=pictureH,cardPad=cardPad,titleSize=titleSize,lineSize=lineSize,lineH=lineH,inner=inner}
end

-- ── Overlay ──────────────────────────────────────────────────────────────────
local state={open=false,id=nil,gui=nil,root=nil,shade=nil,panel=nil,onClosed=nil,previous=nil,connections={},stamp=nil}
local owner={} -- the shade stack key

local function make(class,parent,props)
 local object=Instance.new(class)
 for key,value in pairs(props or {})do object[key]=value end
 object.Parent=parent;return object
end

local function ensureGui()
 if state.gui and state.gui.Parent then return state.gui end
 local player=Players.LocalPlayer
 local playerGui=player and player:FindFirstChildOfClass("PlayerGui")
 if not playerGui then return nil end
 local gui=make("ScreenGui",playerGui,{Name="EggDropHowItWorks",ResetOnSpawn=false,ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets,
  DisplayOrder=How.DisplayOrder,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,ClipToDeviceSafeArea=false,Enabled=true})
 local root=make("Frame",gui,{Name="Root",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Active=false})
 state.gui,state.root=gui,root
 -- The shade: a full-screen TextButton-free Frame; a tap on it closes (below).
 state.shade=Kit.modalShade(root,"HowItWorksShade",10)
 state.shade.InputBegan:Connect(function(input)
  if not state.open then return end
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then How.close("outside")end
 end)
 root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()if state.open then How.build()end end)
 return gui
end

local function txt(parent,role,content,color,props)return Kit.text(parent,role,content,color,props)end

-- Builds the panel for the open set at the current size.
function How.build()
 local root=state.root;if not root or not state.id then return nil end
 if state.panel then state.panel:Destroy();state.panel=nil end
 if state.stamp then state.stamp:destroy();state.stamp=nil end
 local cards=How.cards(state.id)
 local size=root.AbsoluteSize
 local g=How.layout(math.max(320,size.X),math.max(240,size.Y),cards)
 local set=How.Sets[state.id]
 local panel=Kit.frame(root,"HowItWorks","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(g.panelW,g.panelH),if g.compact then 16 else 24)
 panel.AnchorPoint=Vector2.new(.5,.5);panel.Active=true;panel.ZIndex=20;Kit.stroke(panel)
 panel:SetAttribute("HelpId",state.id);panel:SetAttribute("Layout",if g.compact then "phone"else "regular")
 state.panel=panel
 -- Header: eyebrow "How it works" with the family tint, the machine's name, close circle.
 local eyebrow=txt(panel,"Label",string.upper(UICopy.get("r3.help.eyebrow")),"dim",{Name="Eyebrow",Position=UDim2.fromOffset(g.pad,if g.compact then 8 else 14),
  Size=UDim2.fromOffset(g.panelW-g.pad*2-56,16),Visible=not g.compact})
 Kit.tintEyebrow(eyebrow,set.tint)
 local titleY=if g.compact then 14 else 32
 local title=txt(panel,"Title",How.title(state.id),"text",{Name="Title",Position=UDim2.fromOffset(g.pad,titleY),Size=UDim2.fromOffset(g.panelW-g.pad*2-56,if g.compact then 24 else 30),
  TextSize=if g.compact then 20 else 24,TextTruncate=Enum.TextTruncate.AtEnd})
 Kit.squiggle(panel,title,set.tint)
 local close=Kit.backArrow(panel,g.compact,{header=true});close.root.AnchorPoint=Vector2.new(1,0)
 close.root.Position=UDim2.fromOffset(g.panelW-(if g.compact then 10 else 16),if g.compact then 4 else 14);close.root.ZIndex=panel.ZIndex+5
 close.root:SetAttribute("AccessibleLabel",UICopy.get("r3.help.close"))
 close.root.Activated:Connect(function()How.close("back")end)
 -- Cards, side by side.
 for index,card in ipairs(cards)do
  local x=g.pad+(index-1)*(g.cardW+g.gap)
  local tile=Kit.card(panel,"Card_"..card.key,nil,{role="raised",radius=14})
  tile.Position=UDim2.fromOffset(x,g.headerH);tile.Size=UDim2.fromOffset(g.cardW,g.cardH);tile.ZIndex=panel.ZIndex+1
  local step=Kit.chip(tile,tostring(index),nil,22);step.root.AnchorPoint=Vector2.new(1,0);step.root.Position=UDim2.fromOffset(g.cardW-8,8)
  step.label.TextSize=12;Kit.fixedText(step.label)
  local py=g.cardPad
  if card.art=="stamps"then
   local View=require(script.Parent.StampCardView)
   local mini=View.new(tile,{name="StampSample"})
   local h=mini:layout(g.cardW-g.cardPad*2,true);mini.root.Position=UDim2.fromOffset(g.cardPad,py+math.max(0,math.floor((g.pictureH-h)/2)))
   mini:set(How.StampSample);state.stamp=mini
  else
   local well=Kit.frame(tile,"Picture","well",UDim2.fromOffset(g.cardPad,py),UDim2.fromOffset(g.picture,g.picture),14)
   Kit.stroke(well)
   local tint=Kit.tintColor(set.tint)
   well.BackgroundColor3=Kit.color("well"):Lerp(tint or Kit.Color.stars,.18)
   local icon=Kit.icon(well,card.icon,math.floor(g.picture*.56),if card.icon=="star"then "stars"else "text")
   icon.AnchorPoint,icon.Position=Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
   if tint and card.icon~="star"then Kit.tintIcon(icon,function()return tint end)end
  end
  py+=g.pictureH+(if g.compact then 8 else 12)
  local th=math.ceil(g.titleSize*1.3)
  txt(tile,"Name",card.title,"text",{Name="CardTitle",Position=UDim2.fromOffset(g.cardPad,py),Size=UDim2.fromOffset(g.inner,th),TextSize=g.titleSize,TextTruncate=Enum.TextTruncate.AtEnd})
  py+=th+4
  txt(tile,"Small",card.line,"soft",{Name="CardLine",Position=UDim2.fromOffset(g.cardPad,py),Size=UDim2.fromOffset(g.inner,g.lineH),TextSize=g.lineSize,
   TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
 end
 -- Footer: one line in voice and "Got it".
 local fy=g.headerH+g.cardH+(if g.compact then 10 else 16)
 local bw,bh=if g.compact then 140 else 180,if g.compact then 44 else 48
 local done=Kit.button(panel,"GotIt",{variant="primary",text=UICopy.get("r3.help.done"),glyph="A",size=Vector2.new(bw,bh),textSize=if g.compact then 15 else 17})
 done.Position=UDim2.fromOffset(g.panelW-g.pad-bw,fy);done.ZIndex=panel.ZIndex+2
 done.Activated:Connect(function()How.close("done")end)
 state.done=done
 local lineX=g.pad
 -- "Show tips again" (R1's coach-tip replay, set by init.client as How.replayTips).
 if How.replayTips then
  local tw=if g.compact then 150 else 180
  local tips=Kit.button(panel,"ShowTips",{variant="ghost",text=UICopy.get("r3.tips"),size=Vector2.new(tw,bh),textSize=if g.compact then 14 else 15,selectable=true})
  tips.Position=UDim2.fromOffset(g.panelW-g.pad-bw-12-tw,fy);tips.ZIndex=panel.ZIndex+2
  tips.Activated:Connect(function()How.close("tips");task.defer(How.replayTips)end)
  state.tips=tips
  lineX=g.pad;bw+=12+tw
 end
 txt(panel,"Small",UICopy.get("r3.help.replay"),"dim",{Name="Replay",Position=UDim2.fromOffset(lineX,fy),Size=UDim2.fromOffset(math.max(0,g.panelW-g.pad*3-bw),bh),
  TextSize=if g.compact then 12 else 14,TextTruncate=Enum.TextTruncate.AtEnd})
 if not Kit.reduced()then
  local scale=make("UIScale",panel,{Scale=.96})
  Kit.tween(scale,Kit.Motion.screen,{Scale=1})
 end
 return panel
end

local function gamepad()return string.match(UserInputService:GetLastInputType().Name,"^Gamepad")~=nil end

local function bind()
 ContextActionService:BindActionAtPriority(How.Action,function(_,inputState,input)
  if not state.open then return Enum.ContextActionResult.Pass end
  if inputState~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
  local key=input.KeyCode
  if key==Enum.KeyCode.ButtonB or key==Enum.KeyCode.Backspace then How.close("back")
  elseif key==Enum.KeyCode.Return or key==Enum.KeyCode.Space or key==Enum.KeyCode.KeypadEnter then How.close("done")
  elseif key==Enum.KeyCode.ButtonA then How.close("done")end
  return Enum.ContextActionResult.Sink
 end,false,Enum.ContextActionPriority.High.Value+2000,
  Enum.KeyCode.ButtonB,Enum.KeyCode.Backspace,Enum.KeyCode.Return,Enum.KeyCode.Space,Enum.KeyCode.KeypadEnter,Enum.KeyCode.ButtonA,
  -- Everything else a menu listens for is swallowed while the cards are up.
  Enum.KeyCode.DPadLeft,Enum.KeyCode.DPadRight,Enum.KeyCode.DPadUp,Enum.KeyCode.DPadDown,Enum.KeyCode.ButtonL1,Enum.KeyCode.ButtonR1,
  Enum.KeyCode.Left,Enum.KeyCode.Right,Enum.KeyCode.Up,Enum.KeyCode.Down,Enum.KeyCode.Q,Enum.KeyCode.E,Enum.KeyCode.A,Enum.KeyCode.D,
  Enum.KeyCode.W,Enum.KeyCode.S,Enum.KeyCode.ButtonX,Enum.KeyCode.ButtonY)
end

-- Opens the set `id` (a HowItWorks.Sets key). Returns true when the cards show.
function How.open(id,options)
 if not How.has(id)then return false end
 if not ensureGui()then return false end
 options=options or {}
 if state.open and state.id==id then return true end
 state.id=id;state.onClosed=options.onClosed
 if not state.open then
  state.previous=GuiService.SelectedObject
  state.open=true
  bind()
 end
 How.build()
 state.gui.Enabled=true
 Kit.shadeOpen(owner,state.shade,nil,{overlay=true})
 state.root:SetAttribute("HelpId",id)
 if gamepad()and state.done then GuiService.SelectedObject=state.done elseif state.previous then GuiService.SelectedObject=nil end
 if How.onOpened then task.spawn(How.onOpened,id)end
 return true
end

function How.close(reason)
 if not state.open then return false end
 state.open=false
 ContextActionService:UnbindAction(How.Action)
 Kit.shadeClose(owner)
 if state.stamp then state.stamp:destroy();state.stamp=nil end
 if state.panel then state.panel:Destroy();state.panel=nil end
 state.done=nil
 local previous=state.previous;state.previous=nil
 if previous and previous.Parent and gamepad()then GuiService.SelectedObject=previous end
 local id,callback=state.id,state.onClosed
 state.id,state.onClosed=nil,nil
 if state.root then state.root:SetAttribute("HelpId",nil)end
 if callback then task.spawn(callback,id,reason or "close")end
 return true
end

function How.isOpen()return state.open end
function How.openId()return state.id end
-- Specs: the live panel (nil when closed).
function How.panel()return state.panel end
-- Optional notification hook (onOpened(id)); R1's onboarding may listen.
How.onOpened=nil
-- Set by init.client to R1's clientUI.replayCoachTips: adds "Show tips again" to the cards.
How.replayTips=nil
return How
