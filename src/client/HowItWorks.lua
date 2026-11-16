-- "How it works" cards (QA 2026-11-13 v2, R3.8). Every machine screen's header
-- carries a ? circle (Kit.header, from the screen's tint family) that opens two to
-- four short illustrated cards for that machine, side by side, in the house voice
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
-- Notice cards (QA v735 H5): HowItWorks.openNotice(id, {vars, run, onClosed}) shows a
-- NoticeCards entry in the same panel: two cards (what it means, what to do next) and,
-- when the notice leads somewhere, one primary button that goes there (HowItWorks.go /
-- canGo, set by init.client; `run` overrides them). A / Enter / Space take that button.
-- The first-session tour is the `garden` set (CoachCards opens it once).
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
local Notices=require(script.Parent.NoticeCards)
local How={}

-- Card sets. `icon` is a Kit.icon name; `art` names a special picture ("stamps").
How.Sets=table.freeze({
 hatch=table.freeze({tint="hatch",cards=table.freeze({
  table.freeze({key="a",icon="star"}),table.freeze({key="b",icon="egg"}),table.freeze({key="c",icon="sparkle"})})}),
 style=table.freeze({tint="style",cards=table.freeze({
  table.freeze({key="a",icon="faceplate"}),table.freeze({key="b",icon="pattern"}),table.freeze({key="c",icon="ball"})})}),
 companions=table.freeze({tint="companions",cards=table.freeze({
  table.freeze({key="a",icon="paw"}),table.freeze({key="b",icon="shirt"}),table.freeze({key="c",icon="wand"}),
  -- QA v735 H4: where the things Customize uses come from.
  table.freeze({key="d",icon="egg"})})}),
 quests=table.freeze({tint="quests",cards=table.freeze({
  table.freeze({key="a",icon="quests"}),table.freeze({key="b",art="stamps"}),table.freeze({key="c",icon="trophy"})})}),
 book=table.freeze({tint="book",cards=table.freeze({
  table.freeze({key="a",icon="book"}),table.freeze({key="b",icon="star"}),table.freeze({key="c",icon="trophy"})})}),
 park=table.freeze({tint="companions",cards=table.freeze({
  table.freeze({key="a",icon="paw"}),table.freeze({key="b",icon="smiley"})})}),
 -- QA v735 H5: the first-session tour. Where the machines are, where Quests and dailies
 -- are, how to customize, and the Menu. Not in Order: it is not a machine's ? set.
 garden=table.freeze({tint="quests",cards=table.freeze({
  table.freeze({key="a",icon="target"}),table.freeze({key="b",icon="quests"}),table.freeze({key="c",icon="wand"}),
  table.freeze({key="d",icon="settings"})})}),
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
 local n=math.max(1,#cards);local columns=if W<600 and H>420 then 1 else n
 local pad=if compact then 16 else 24;local gap=if compact then 10 else 16
 local panelW=math.floor(math.min(W-(if compact then 24 else 48),if n<=2 then 640 elseif n==3 then 820 else 1000))
 local cardW=math.floor((panelW-pad*2-gap*(columns-1))/columns)
 local cardPad=if compact then 12 else 16;local inner=cardW-cardPad*2
 local titleSize=if compact then 15 else 18;local lineSize=if compact then 13 else 15
 local lineH,titleH=0,0
 for _,card in ipairs(cards)do
  -- Labels draw LineHeight1.25; GetTextSize does not include that spacing.
  lineH=math.max(lineH,math.ceil(Kit.measure(card.line,"Small",lineSize,inner).Y*Kit.LineHeight)+3)
  titleH=math.max(titleH,math.ceil(Kit.measure(card.title,"Name",titleSize,inner).Y*Kit.LineHeight)+3)
 end
 local pictureH=32
 for _,card in ipairs(cards)do if card.art=="stamps"then pictureH=math.max(pictureH,require(script.Parent.StampCardView).height(true))end end
 local cardH=cardPad+pictureH+8+titleH+4+lineH+cardPad
 local headerH=if compact then 52 else 72;local footerH=if compact then 64 else 80
 local contentH=math.ceil(n/columns)*(cardH+gap)-gap
 local panelH=math.min(headerH+contentH+footerH,H-(if compact then 12 else 48))
 return{compact=compact,pad=pad,gap=gap,headerH=headerH,footerH=footerH,panelW=panelW,panelH=panelH,cardW=cardW,cardH=cardH,
  picture=32,pictureH=pictureH,cardPad=cardPad,titleSize=titleSize,titleH=titleH,lineSize=lineSize,lineH=lineH,inner=inner,
  columns=columns,contentH=contentH,viewportH=math.max(40,panelH-headerH-footerH)}
end

-- ── Overlay ──────────────────────────────────────────────────────────────────
local state={open=false,id=nil,gui=nil,root=nil,shade=nil,panel=nil,onClosed=nil,previous=nil,connections={},stamp=nil,notice=nil}
-- May the open notice's button show? Its own `run`, or the client's route to the target.
local function noticeGo()
 local notice=state.notice
 if not notice or not notice.go then return nil end
 if notice.run then return notice.go end
 if How.go and(How.canGo==nil or How.canGo(notice.go.target)==true)then return notice.go end
 return nil
end
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
 GuiService:GetPropertyChangedSignal("PreferredTextSize"):Connect(function()if state.open then How.build()end end)
 return gui
end

local function txt(parent,role,content,color,props)return Kit.text(parent,role,content,color,props)end

-- Builds the panel for the open set at the current size.
function How.build()
 local root=state.root;if not root or not state.id then return nil end
 if state.panel then state.panel:Destroy();state.panel=nil end
 if state.stamp then state.stamp:destroy();state.stamp=nil end
 local notice=state.notice
 local cards=if notice then Notices.cards(notice.id,notice.vars)else How.cards(state.id)
 local size=root.AbsoluteSize
 local g=How.layout(math.max(320,size.X),math.max(240,size.Y),cards)
 local set=if notice then Notices.ById[notice.id]else How.Sets[state.id]
 local panel=Kit.frame(root,"HowItWorks","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(g.panelW,g.panelH),if g.compact then 16 else 24)
 panel.AnchorPoint=Vector2.new(.5,.5);panel.Active=true;panel.ZIndex=20;Kit.stroke(panel)
 panel:SetAttribute("HelpId",state.id);panel:SetAttribute("Layout",if g.compact then "phone"else "regular")
 state.panel=panel
 -- Header: eyebrow "How it works" with the family tint, the machine's name, close circle.
 local eyebrow=txt(panel,"Label",string.upper(UICopy.get("r3.help.eyebrow")),"dim",{Name="Eyebrow",Position=UDim2.fromOffset(g.pad,if g.compact then 8 else 14),
  Size=UDim2.fromOffset(g.panelW-g.pad*2-56,16),Visible=not g.compact})
 Kit.tintEyebrow(eyebrow,set.tint)
 local titleY=if g.compact then 14 else 32
 local title=txt(panel,"Title",if notice then Notices.title(notice.id,notice.vars)else How.title(state.id),"text",{Name="Title",Position=UDim2.fromOffset(g.pad,titleY),Size=UDim2.fromOffset(g.panelW-g.pad*2-56,if g.compact then 24 else 30),
  TextSize=if g.compact then 20 else 24,TextTruncate=Enum.TextTruncate.AtEnd})
 Kit.squiggle(panel,title,set.tint)
 local close=Kit.backArrow(panel,g.compact,{header=true});close.root.AnchorPoint=Vector2.new(1,0)
 close.root.Position=UDim2.fromOffset(g.panelW-(if g.compact then 10 else 16),if g.compact then 4 else 14);close.root.ZIndex=panel.ZIndex+5
 close.root:SetAttribute("AccessibleLabel",UICopy.get("r3.help.close"))
 close.root.Activated:Connect(function()How.close("back")end)
 -- Text is fully allocated inside a scrolling body; the footer never scrolls.
 local body=make("ScrollingFrame",panel,{Name="Cards",BackgroundTransparency=1,BorderSizePixel=0,
  Position=UDim2.fromOffset(g.pad-2,g.headerH-2),Size=UDim2.fromOffset(g.panelW-g.pad*2+4,g.viewportH+4),
  CanvasSize=UDim2.fromOffset(0,g.contentH+4),ScrollBarThickness=3,ScrollingDirection=Enum.ScrollingDirection.Y,
  ZIndex=panel.ZIndex+1,ClipsDescendants=true})
 state.body=body
 for index,card in ipairs(cards)do
  local x=2+((index-1)%g.columns)*(g.cardW+g.gap)
  local y=2+math.floor((index-1)/g.columns)*(g.cardH+g.gap)
  local tile=Kit.card(body,"Card_"..card.key,nil,{role="raised",radius=14})
  tile.Position=UDim2.fromOffset(x,y);tile.Size=UDim2.fromOffset(g.cardW,g.cardH);tile.ZIndex=panel.ZIndex+1
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
   local icon=Kit.icon(well,card.icon,24,if card.icon=="star"then "stars"else "text")
   icon.AnchorPoint,icon.Position=Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
   if tint and card.icon~="star"then Kit.tintIcon(icon,function()return tint end)end
  end
  py+=g.pictureH+8
  local th=g.titleH
  txt(tile,"Name",card.title,"text",{Name="CardTitle",Position=UDim2.fromOffset(g.cardPad,py),Size=UDim2.fromOffset(g.inner,th),TextSize=g.titleSize,TextTruncate=Enum.TextTruncate.None,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
  py+=th+4
  txt(tile,"Small",card.line,"soft",{Name="CardLine",Position=UDim2.fromOffset(g.cardPad,py),Size=UDim2.fromOffset(g.inner,g.lineH),TextSize=g.lineSize,
   TextWrapped=true,TextTruncate=Enum.TextTruncate.None,TextYAlignment=Enum.TextYAlignment.Top})
 end
 -- Footer: one line in voice and "Got it".
 local fy=g.panelH-g.footerH+(if g.compact then 10 else 16)
 local bw,bh=if g.compact then 140 else 180,if g.compact then 44 else 48
 -- A notice that leads somewhere: its button is the primary one, "Got it" sits beside it.
 local go=noticeGo()
 state.goButton=nil
 if go then
  local gw=math.min(if g.compact then 190 else 230,g.panelW-g.pad*2-bw-12)
  local button=Kit.button(panel,"Go",{variant="primary",text=go.text,glyph="A",size=Vector2.new(gw,bh),textSize=if g.compact then 15 else 17})
  button.Position=UDim2.fromOffset(g.panelW-g.pad-gw,fy);button.ZIndex=panel.ZIndex+2
  button:SetAttribute("GoTarget",go.target)
  button.Activated:Connect(function()How.accept()end)
  state.goButton=button
  local done=Kit.button(panel,"GotIt",{variant="ghost",text=UICopy.get("r3.help.done"),size=Vector2.new(bw,bh),textSize=if g.compact then 14 else 15,selectable=true})
  done.Position=UDim2.fromOffset(g.panelW-g.pad-gw-12-bw,fy);done.ZIndex=panel.ZIndex+2
  done.Activated:Connect(function()How.close("done")end)
  state.done=button
  if not Kit.reduced()then
   local scale=make("UIScale",panel,{Scale=.96})
   Kit.tween(scale,Kit.Motion.screen,{Scale=1})
  end
  return panel
 end
 local done=Kit.button(panel,"GotIt",{variant="primary",text=UICopy.get("r3.help.done"),glyph="A",size=Vector2.new(bw,bh),textSize=if g.compact then 15 else 17})
 done.Position=UDim2.fromOffset(g.panelW-g.pad-bw,fy);done.ZIndex=panel.ZIndex+2
 done.Activated:Connect(function()How.close("done")end)
 state.done=done
 local lineX=g.pad
 -- "Show tips again" (R1's coach-tip replay, set by init.client as How.replayTips).
 if How.replayTips and not notice then
  local tw=if g.compact then 150 else 180
  local tips=Kit.button(panel,"ShowTips",{variant="ghost",text=UICopy.get("r3.tips"),size=Vector2.new(tw,bh),textSize=if g.compact then 14 else 15,selectable=true})
  tips.Position=UDim2.fromOffset(g.panelW-g.pad-bw-12-tw,fy);tips.ZIndex=panel.ZIndex+2
  tips.Activated:Connect(function()How.close("tips");task.defer(How.replayTips)end)
  state.tips=tips
  lineX=g.pad;bw+=12+tw
 end
 txt(panel,"Small",if notice then "" else UICopy.get("r3.help.replay"),"dim",{Name="Replay",Position=UDim2.fromOffset(lineX,fy),Size=UDim2.fromOffset(math.max(0,g.panelW-g.pad*3-bw),bh),
  TextSize=if g.compact then 12 else 14,TextTruncate=Enum.TextTruncate.AtEnd})
 if not Kit.reduced()then
  local scale=make("UIScale",panel,{Scale=.96})
  Kit.tween(scale,Kit.Motion.screen,{Scale=1})
 end
 return panel
end

local function gamepad()return string.match(UserInputService:GetLastInputType().Name,"^Gamepad")~=nil end

function How.scroll(direction)
 local body=state.body
 if not state.open or not body or not body.Parent then return false end
 local maximum=math.max(0,body.CanvasSize.Y.Offset-body.AbsoluteSize.Y)
 body.CanvasPosition=Vector2.new(0,math.clamp(body.CanvasPosition.Y+math.sign(direction)*math.max(48,body.AbsoluteSize.Y*.6),0,maximum))
 return true
end

local function bind()
 ContextActionService:BindActionAtPriority(How.Action,function(_,inputState,input)
  if not state.open then return Enum.ContextActionResult.Pass end
  if inputState~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
  local key=input.KeyCode
  if key==Enum.KeyCode.Up or key==Enum.KeyCode.W or key==Enum.KeyCode.DPadUp then How.scroll(-1)
  elseif key==Enum.KeyCode.Down or key==Enum.KeyCode.S or key==Enum.KeyCode.DPadDown then How.scroll(1)
  elseif key==Enum.KeyCode.ButtonB or key==Enum.KeyCode.Backspace then How.close("back")
  elseif key==Enum.KeyCode.Return or key==Enum.KeyCode.Space or key==Enum.KeyCode.KeypadEnter then How.accept()
  elseif key==Enum.KeyCode.ButtonA then How.accept()end
  return Enum.ContextActionResult.Sink
 end,false,Enum.ContextActionPriority.High.Value+2000,
  Enum.KeyCode.ButtonB,Enum.KeyCode.Backspace,Enum.KeyCode.Return,Enum.KeyCode.Space,Enum.KeyCode.KeypadEnter,Enum.KeyCode.ButtonA,
  -- Everything else a menu listens for is swallowed while the cards are up.
  Enum.KeyCode.DPadLeft,Enum.KeyCode.DPadRight,Enum.KeyCode.DPadUp,Enum.KeyCode.DPadDown,Enum.KeyCode.ButtonL1,Enum.KeyCode.ButtonR1,
  Enum.KeyCode.Left,Enum.KeyCode.Right,Enum.KeyCode.Up,Enum.KeyCode.Down,Enum.KeyCode.Q,Enum.KeyCode.E,Enum.KeyCode.A,Enum.KeyCode.D,
  Enum.KeyCode.W,Enum.KeyCode.S,Enum.KeyCode.ButtonX,Enum.KeyCode.ButtonY)
end

-- The primary button: a notice's "go there" when it has one, else "Got it".
function How.accept()
 if not state.open then return false end
 local go=noticeGo()
 if not go then return How.close("done")end
 local run=state.notice.run
 How.close("go")
 -- After the close, so the screen it opens is not under this overlay's shade or keys.
 task.defer(function()
  if run then run(go.target)elseif How.go then How.go(go.target)end
 end)
 return true
end
-- Opens the notice `id` (a NoticeCards id). options: vars (fills the copy), run (the
-- button's own action; default HowItWorks.go(target)), onClosed. True when it shows.
function How.openNotice(id,options)
 if not Notices.has(id)then return false end
 options=options or {}
 return How.open("notice:"..id,{onClosed=options.onClosed,
  notice={id=id,vars=options.vars,run=options.run,go=Notices.go(id)}})
end
-- Opens the set `id` (a HowItWorks.Sets key). Returns true when the cards show.
function How.open(id,options)
 options=options or {}
 if not options.notice and not How.has(id)then return false end
 if not ensureGui()then return false end
 if state.open and state.id==id and not options.notice then return true end
 state.id=id;state.onClosed=options.onClosed;state.notice=options.notice
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
 state.done=nil;state.body=nil;state.goButton=nil;state.notice=nil
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
-- The open notice's id (nil for a machine's set, or when closed).
function How.noticeId()return if state.open and state.notice then state.notice.id else nil end
-- Notice buttons (set by init.client): go(target) takes the player to "quests" | "hatch" |
-- "companions" | "menu"; canGo(target) says whether that is possible right now (not in a
-- round, not before the first pet). Without them a notice shows "Got it" only.
How.go=nil
How.canGo=nil
-- Specs: the live panel (nil when closed).
function How.panel()return state.panel end
-- Optional notification hook (onOpened(id)); R1's onboarding may listen.
How.onOpened=nil
-- Set by init.client to R1's clientUI.replayCoachTips: adds "Show tips again" to the cards.
How.replayTips=nil
return How
