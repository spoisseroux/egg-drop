-- Quest log (UI-SPEC-2026-11-12 section 5.4, QA 2026-11-13 Q5 garden host, QA v2
-- R3). Presentation only: the snapshot (`nurseryState.quests`) is the data and the
-- server owns every claim and reroll. Focus is owned here: up / down move between
-- rows, L / R (Q / E) switch tabs, A claims or rerolls the focused row (or stamps
-- the card), B goes back. Touch and mouse use the tabs and row buttons directly.
--
-- QA v2 R3: the shared Kit header (title, the 3D Stars capsule, the ? "How it works"
-- circle and the back arrow) on desktop and phones; rows that say what to do, show a
-- clear progress bar, a status word ("2 to go", "Done! Claim it") and a Stars reward
-- chip that turns into a gold sticker when it is ready; a claim celebrates (boing,
-- star burst, "+N" pop; a plain pop under Reduced Motion). The daily stamp card
-- lives here now (daily things live together): callbacks.stampState() gives the
-- nursery snapshot ({stamps, stampCard, dailyAvailable, dailyDay}) and
-- callbacks.stamp(day) sends the `daily` action.
local Kit=require(script.Parent.DeckKit)
-- Quest titles name a ball size with a colour circle, never a numeral (batch R1).
local BallThemes=require(game:GetService("ReplicatedStorage").Shared.BallThemes)
local UICopy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
local Peek=require(script.Parent.PetPeek)
local StampCardView=require(script.Parent.StampCardView)
local Log={}
Log.__index=Log
Log.Tabs={"daily","weekly","history"}
Log.StampFocus=5 -- the stamp button's focus index on the daily tab (4 is the weekly bonus)
Log.StampPendingSeconds=6
local icons={play="trophy",craft="chain",skill="bars"}

local function txt(parent,role,content,color,x,y,w,h,props)
 local t=Kit.text(parent,role,content,color,props);t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,h);return t
end
-- Pure: "New in 7 h 12 m" / "New in 3 d 7 h".
function Log.resetText(seconds)
 seconds=math.max(0,math.floor(seconds or 0))
 local d,h,m=seconds//86400,(seconds%86400)//3600,(seconds%3600)//60
 if d>0 then return string.format("New in %d d %d h",d,h)end
 return string.format("New in %d h %d m",h,m)
end
-- Pure: where focus lands when a tab opens (first Ready, else first Reroll, else 1).
function Log.initialFocus(rows,bonusReady)
 for i,row in ipairs(rows or {})do if row.ready then return i end end
 if bonusReady then return 4 end
 for i,row in ipairs(rows or {})do if row.canReroll then return i end end
 return 1
end
-- Pure: what A does on a row.
function Log.action(row,rerollLeft)
 if not row or row.claimed then return nil end
 if row.ready then return "claim"end
 if row.canReroll and (rerollLeft or 0)>0 then return "reroll"end
 return nil
end
-- Pure (R3.7): the row's status word and its colour role.
-- "Claimed" / "Done! Claim it" (gold) / "Not started" / "{n} to go".
function Log.status(row)
 if not row then return "","soft"end
 if row.claimed then return UICopy.get("r3.quests.status.claimed"),"dim"end
 if row.ready then return UICopy.get("r3.quests.status.ready"),"stars"end
 local progress,target=tonumber(row.progress)or 0,tonumber(row.target)or 0
 if progress<=0 then return UICopy.get("r3.quests.status.notStarted"),"soft"end
 return UICopy.get("r3.quests.status.toGo",{count=math.max(0,target-progress)}),"text"
end
local function claimedCount(rows)local n=0;for _,r in ipairs(rows or {})do if r.claimed then n+=1 end end;return n end

function Log.new(overlay,callbacks)
 local self=setmetatable({overlay=overlay,callbacks=callbacks or {},tab="daily",focusIndex=1,visible=false,rows={},pendingRows={}},Log)
 self:build(nil)
 overlay.onLayout=function(view)
  local key=if view then string.format("%dx%d:%d",view.W,view.H,view.hx)else "regular"
  if key==self.key then return end
  self:build(view)
  if self.visible then self.tabs.select(table.find(Log.Tabs,self.tab)or 1);self:paint()end
 end
 return self
end

-- Pure (UI-SPEC-COMPACT 8): row height, gap and row tops for a root H.
function Log.compactRows(H)
 local g=if H<340 then 6 else 8
 local rh=math.clamp(math.floor((H-134-2*g)/3),56,76)
 return rh,g,{64,64+rh+g,64+2*(rh+g)}
end
-- Compact type floor: the reward button's 22 px glyph letter goes to 12.
local function glyph12(button)
 local g=Kit.buttonState(button).glyph
 local t=g and g:FindFirstChildWhichIsA("TextLabel")
 if t then t.TextSize=12 end
end
-- Pure: tab track width in the compact header. The header keeps the back circle, a
-- five-digit Stars capsule and the ? circle on the right (231 px with the gaps).
function Log.compactTabsWidth(W,hx)return math.max(180,math.min(312,W-hx-231))end
-- Desktop geometry (848 x 608 content units).
Log.Regular=table.freeze({tabsY=92,rowsY=144,rowH=80,rowGap=8,panelY=410,panelH=104,footerY=524,footerH=44,hintsY=578,width=800,x=24})
-- T4 / T12: with every daily quest claimed the pet peeks up inside the footer strip
-- (desktop only), clear of the footer text.
Log.PeekSlot=table.freeze({x=440,y=0,w=200,h=44})

function Log:clear()
 if self.footer then Peek.hide(self.footer)end
 if self.ring then self.ring.hide();self.ring.root:Destroy()end
 if self.stampView then self.stampView:destroy();self.stampView=nil end
 for _,child in ipairs(self.overlay.content:GetChildren())do if not(child:IsA("UIScale")or child:IsA("UIPadding"))then child:Destroy()end end
 self.rows={};self.title=nil;self.squiggle=nil;self.view=nil;self.header=nil;self.panel=nil;self.stampButton=nil;self.bonusPanel=nil
end

-- One quest row (both layouts). w x h at (x, y) in `parent`; compact = phone type.
function Log:buildRow(parent,index,x,y,w,h,compact)
 local row=Kit.node("TextButton",parent,{Name="Quest"..index,Text="",AutoButtonColor=false,BackgroundTransparency=0,Selectable=false,
  Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),ZIndex=parent.ZIndex+1})
 Kit.corner(row,14);local stroke=Kit.stroke(row)
 local wellS=if compact then 40 else 52
 local well=Kit.frame(row,"IconWell","well",UDim2.fromOffset(if compact then 10 else 14,math.floor((h-wellS)/2)),UDim2.fromOffset(wellS,wellS),12)
 local icon=Kit.icon(well,"trophy",if compact then 20 else 26,"text");icon.AnchorPoint,icon.Position=Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
 local tx=(if compact then 10 else 14)+wellS+(if compact then 10 else 14)
 local buttonW,buttonH=if compact then 100 else 120,if compact then 44 else 40
 local chipW=if compact then 64 else 78
 local right=w-(if compact then 10 else 14)-buttonW-(if compact then 8 else 12)-chipW-(if compact then 8 else 12)
 local textW=math.max(60,right-tx)
 local small=compact and h<64
 local title=txt(row,"Strong","","text",tx,if compact then(if small then 4 else 7)else 10,textW,if compact then 20 else 24,{TextSize=if compact then 15 else 18,TextTruncate=Enum.TextTruncate.AtEnd})
 -- The "what to do" line (the quest's own sub line: "Across any rounds", "Finish below the tidy line").
 local sub=txt(row,"Small","","soft",tx,if compact then(if small then 23 else 27)else 35,textW,if compact then 16 else 18,{TextSize=if compact then 12 else 14,TextTruncate=Enum.TextTruncate.AtEnd})
 local barH=if compact then 8 else 10
 local barY=h-(if compact then(if small then 12 else 15)else 20)
 local countW=if compact then 44 else 52
 local statusW=if compact then 0 else 120
 local barW=math.max(40,textW-countW-8-(if statusW>0 then statusW+8 else 0))
 local bar=Kit.progress(row,barH);bar.root.Position=UDim2.fromOffset(tx,barY);bar.root.Size=UDim2.fromOffset(barW,barH)
 local count=txt(row,"Counter","","soft",tx+barW+8,barY+barH/2-10,countW,20,{TextSize=if compact then 12 else 14})
 local status=txt(row,"Label","","soft",tx+barW+8+countW+8,barY+barH/2-10,math.max(0,statusW),20,{TextSize=13,Visible=statusW>0,TextTruncate=Enum.TextTruncate.AtEnd})
 -- Reward chip: a pill with the gold Star and "+N"; a gold sticker when ready.
 local chipH=if compact then 28 else 32
 local chip=Kit.frame(row,"RewardChip","well",UDim2.fromOffset(right+(if compact then 8 else 12),math.floor((h-chipH)/2)),UDim2.fromOffset(chipW,chipH),999)
 local chipStroke=Kit.stroke(chip)
 local star=Kit.icon(chip,"star",if compact then 16 else 18);star.AnchorPoint=Vector2.new(0,.5);star.Position=UDim2.new(0,if compact then 8 else 10,.5,0)
 local reward=txt(chip,"Counter","","stars",if compact then 26 else 30,0,chipW-(if compact then 30 else 36),chipH,{TextSize=if compact then 14 else 16})
 Kit.fixedText(reward)
 local bx=w-(if compact then 10 else 14)-buttonW
 local by=math.floor((h-buttonH)/2)
 local claim=Kit.button(row,"Claim",{variant="reward",text="Claim",glyph="A",size=Vector2.new(buttonW,buttonH),textSize=if compact then 15 else 16,selectable=false})
 claim.Position=UDim2.fromOffset(bx,by);if compact then glyph12(claim)end
 local reroll=Kit.button(row,"Reroll",{text="Reroll",size=Vector2.new(buttonW,buttonH),textSize=15,selectable=false});reroll.Position=claim.Position
 local done=Kit.chip(row,"CLAIMED",nil,if compact then 24 else 26);done.label.TextSize=12;done.set("CLAIMED","plain")
 done.root.AnchorPoint=Vector2.new(.5,.5);done.root.Position=UDim2.fromOffset(bx+buttonW/2,h/2)
 local slot={row=row,stroke=stroke,well=well,icon=icon,title=title,sub=sub,bar=bar,count=count,status=status,reward=reward,rewardChip=chip,
  rewardStroke=chipStroke,rewardStar=star,claim=claim,reroll=reroll,chip=done,compact=compact}
 self.rows[index]=slot
 claim.Activated:Connect(function()self.focusIndex=index;self:paintFocus();self:act()end)
 reroll.Activated:Connect(function()self.focusIndex=index;self:paintFocus();self:act()end)
 row.Activated:Connect(function()self.focusIndex=index;self:paintFocus()end)
 return slot
end

-- The stamp card block (daily tab): StampCardView on the left, the stamp button on the right.
function Log:buildStampPanel(parent,x,y,w,h,compact)
 local panel=Kit.frame(parent,"StampPanel","raised",UDim2.fromOffset(x,y),UDim2.fromOffset(w,h),14);Kit.stroke(panel)
 panel.ZIndex=parent.ZIndex+1
 local pad=if compact then 10 else 14
 local buttonW=if compact then 128 else 180
 local view=StampCardView.new(panel,{name="StampCard"})
 local cardH=view:layout(w-pad*3-buttonW,compact)
 view.root.Position=UDim2.fromOffset(pad,math.floor((h-cardH)/2))
 self.stampView=view
 local buttonH=if compact then 44 else 48
 local stamp=Kit.button(panel,"Stamp",{variant="reward",text="Stamp",glyph="A",size=Vector2.new(buttonW,buttonH),textSize=if compact then 14 else 16,selectable=false})
 stamp.Position=UDim2.fromOffset(w-pad-buttonW,math.floor((h-buttonH)/2));if compact then glyph12(stamp)end
 stamp.Activated:Connect(function()self.focusIndex=Log.StampFocus;self:paintFocus();self:act()end)
 local doneLine=txt(panel,"Small",UICopy.get("r3.quests.stamp.lineDone"),"soft",w-pad-buttonW,0,buttonW,h,{TextSize=if compact then 12 else 14,
  TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Center,Visible=false})
 self.panel,self.stampButton,self.stampDone=panel,stamp,doneLine
 return panel
end

-- Footer strip (both layouts, 44 high): reroll / bonus line, then the day's Stars.
function Log:buildFooter(parent,x,y,fw,compact)
 local footer=Kit.frame(parent,"Footer","well",UDim2.fromOffset(x,y),UDim2.fromOffset(fw,44),12);Kit.stroke(footer)
 self.footerIcon=Kit.icon(footer,"reroll",18,"accent");self.footerIcon.Position=UDim2.fromOffset(13,13)
 self.footerTitle=txt(footer,"Strong","","text",40,0,220,44,{TextSize=if compact then 14 else 15,AutomaticSize=Enum.AutomaticSize.X})
 self.footerSub=txt(footer,"Small","","soft",0,0,320,44,{TextSize=if compact then 12 else 14,Visible=not compact or fw>=760})
 local menuW=if compact then 84 else 0
 if compact then
  local menu=Kit.button(footer,"PocketMenu",{variant="ghost",text=UICopy.get("r3.quests.menu").." ›",size=Vector2.new(84,44),textSize=15,selectable=false})
  menu.Position=UDim2.fromOffset(fw-84,0)
  menu.Activated:Connect(function()if self.callbacks.menu then self.callbacks.menu()end end)
  local divider=Kit.frame(footer,"Divider",nil,UDim2.fromOffset(fw-86,10),UDim2.fromOffset(1,24));divider.BackgroundTransparency=.88;divider.BackgroundColor3=Color3.new(1,1,1)
 end
 local valueRight=fw-(if compact then menuW+12 else 16)
 self.footerValue=txt(footer,"Counter","","stars",valueRight-90,0,90,44,{TextSize=15,TextXAlignment=Enum.TextXAlignment.Right})
 self.footerLabel=txt(footer,"Label","TODAY","dim",valueRight-90-8-80,0,80,44,{TextSize=12,TextXAlignment=Enum.TextXAlignment.Right})
 self.footerValueRight=valueRight
 self.footer=footer
 return footer
end

-- Compact (phone) quest log: full-screen sheet, the shared compact header with the
-- tabs in its title slot, single-column rows (and the stamp card) that scroll, a
-- pinned footer.
function Log:buildCompact(v)
 local root=self.overlay.content
 local W,H=v.W,v.H
 self.view=v
 local sheet=Kit.sheet(root,W,H)
 local body=Kit.frame(root,"Body",nil,UDim2.new(),UDim2.fromScale(1,1));body.ZIndex=sheet.ZIndex+3
 local header=Kit.header(body,{title="",tint="quests",compact=true,width=W,left=v.hx,onBack=function()if self.callbacks.back then self.callbacks.back()end end})
 header.root.Name="QuestHeader";self.header=header
 self.wallet=header.wallet
 local tw=Log.compactTabsWidth(W,v.hx)
 self.tabs=Kit.tabs(body,{"Daily 0/3","Weekly 0/3","History"},tw,36,14);self.tabs.root.Position=UDim2.fromOffset(v.hx,12)
 self.tabs.root.ZIndex=header.root.ZIndex+2
 self.tabs.changed=function(index)self:setTab(Log.Tabs[index])end
 self.tabsRight=v.hx+tw
 local clock=Kit.icon(body,"clock",15,"soft");self.clock=clock
 self.reset=txt(body,"Small","","soft",0,20,160,20,{TextSize=12,TextXAlignment=Enum.TextXAlignment.Right})
 -- Rows (and the stamp card) in a scrolling frame between the header and the footer.
 local rh,g=Log.compactRows(H)
 local footerY=H-62
 local list=Kit.node("ScrollingFrame",body,{Name="Rows",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(20,64),
  Size=UDim2.fromOffset(W-40,footerY-8-64),CanvasSize=UDim2.fromOffset(0,3*rh+2*g),ScrollBarThickness=4,ZIndex=body.ZIndex+1,Selectable=false,
  ScrollingDirection=Enum.ScrollingDirection.Y,ElasticBehavior=Enum.ElasticBehavior.WhenScrollable})
 -- R3.2: room for the focus stroke and the tile lips of the first and last cards.
 local inset=Kit.scrollInset(list)
 self.rowList,self.rowInset,self.rowPitch,self.rowH=list,inset,rh+g,rh
 local w=W-40-inset*2-6
 for index=1,3 do self:buildRow(list,index,0,(index-1)*(rh+g),w,rh,true)end
 local stampH=StampCardView.height(true)+16
 self.stampH=stampH
 self:buildStampPanel(list,0,3*(rh+g),w,stampH,true)
 self:buildFooter(body,20,footerY,W-40,true)
 self.bonusBar=Kit.progress(self.footer,8,3);self.bonusBar.layout(84,4);self.bonusBar.root.Position=UDim2.fromOffset(W-40-96-90-8-84,18)
 self.bonusClaim=Kit.button(self.footer,"BonusClaim",{variant="reward",text="Claim",glyph="A",size=Vector2.new(104,44),textSize=16,selectable=false})
 self.bonusClaim.Position=UDim2.fromOffset(W-40-96-104,0);glyph12(self.bonusClaim)
 self.bonusClaim.Activated:Connect(function()self.focusIndex=4;self:paintFocus();self:act()end)
 -- History.
 local history=Kit.node("ScrollingFrame",body,{Name="History",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(20,64),
  Size=UDim2.fromOffset(W-40,H-110),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=4,Visible=false,ZIndex=body.ZIndex+1,Selectable=false})
 Kit.node("UIListLayout",history,{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,0)})
 self.history=history
 self.historyFooter=txt(body,"Small","","soft",20,H-40,W-40,20,{TextSize=12,TextXAlignment=Enum.TextXAlignment.Right})
 self.ring=Kit.focusRing(self.overlay.layer)
end

function Log:build(view)
 self:clear()
 self.key=if view then string.format("%dx%d:%d",view.W,view.H,view.hx)else "regular"
 self.phone=view~=nil
 if view then return self:buildCompact(view)end
 local root=self.overlay.content
 local R=Log.Regular
 -- R3.4: the shared header (title, 3D Stars capsule, ? circle, back arrow).
 local header=Kit.header(root,{title="Today",eyebrow=UICopy.get("r3.quests.eyebrow"),tint="quests",width=848,
  onBack=function()if self.callbacks.back then self.callbacks.back()end end})
 header.root.Name="QuestHeader";self.header=header
 header.setTitle("Today",UICopy.get("r3.quests.eyebrow"))
 self.title=header.title;self.squiggle=header.squiggle
 self.wallet=header.wallet
 Kit.halftone(root,"quests",false)
 self.tabs=Kit.tabs(root,{"Daily 0/3","Weekly 0/3","History"},520);self.tabs.root.Position=UDim2.fromOffset(R.x,R.tabsY)
 self.tabs.changed=function(index)self:setTab(Log.Tabs[index])end
 local clock=Kit.icon(root,"clock",18,"dim");clock.Position=UDim2.fromOffset(640,R.tabsY+13);self.clock=clock
 self.reset=txt(root,"Small","","dim",662,R.tabsY,162,44,{TextXAlignment=Enum.TextXAlignment.Right})
 for index=1,3 do self:buildRow(root,index,R.x,R.rowsY+(index-1)*(R.rowH+R.rowGap),R.width,R.rowH,false)end
 -- Daily: the stamp card. Weekly: the bonus card in the same place.
 self:buildStampPanel(root,R.x,R.panelY,R.width,R.panelH,false)
 local bonus=Kit.frame(root,"BonusPanel","raised",UDim2.fromOffset(R.x,R.panelY),UDim2.fromOffset(R.width,R.panelH),14);Kit.stroke(bonus)
 bonus.ZIndex=root.ZIndex+1;self.bonusPanel=bonus
 local bonusWell=Kit.frame(bonus,"IconWell","well",UDim2.fromOffset(14,26),UDim2.fromOffset(52,52),12)
 local trophy=Kit.icon(bonusWell,"trophy",26,"stars");trophy.AnchorPoint,trophy.Position=Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
 self.bonusTitle=txt(bonus,"Strong",UICopy.get("r3.quests.weekly.title"),"text",80,18,420,24,{TextSize=18})
 self.bonusLine=txt(bonus,"Small",UICopy.get("r3.quests.weekly.line"),"soft",80,42,420,18,{TextSize=14,TextTruncate=Enum.TextTruncate.AtEnd})
 self.bonusBar=Kit.progress(bonus,12,3);self.bonusBar.layout(240,6);self.bonusBar.root.Position=UDim2.fromOffset(80,70)
 self.bonusReward=txt(bonus,"Counter","","stars",332,62,110,28,{TextSize=17})
 self.bonusClaim=Kit.button(bonus,"BonusClaim",{variant="reward",text="Claim",glyph="A",size=Vector2.new(140,44),selectable=false})
 self.bonusClaim.Position=UDim2.fromOffset(R.width-14-140,30)
 self.bonusClaim.Activated:Connect(function()self.focusIndex=4;self:paintFocus();self:act()end)
 self.bonusDone=Kit.chip(bonus,"CLAIMED",nil,26);self.bonusDone.root.AnchorPoint=Vector2.new(.5,.5);self.bonusDone.root.Position=UDim2.fromOffset(R.width-14-70,52)
 self:buildFooter(root,R.x,R.footerY,R.width,false)
 -- History.
 local list=Kit.node("ScrollingFrame",root,{Name="History",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(R.x,R.rowsY-2),
  Size=UDim2.fromOffset(R.width,R.footerY-R.rowsY-8),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=6,Visible=false,ZIndex=root.ZIndex+1,Selectable=false})
 Kit.node("UIListLayout",list,{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,2)})
 self.history=list
 self.historyFooter=txt(root,"Small","","dim",R.x,R.footerY,R.width,44,{TextXAlignment=Enum.TextXAlignment.Right})
 -- Hints, and the Menu way back to the machine hub.
 local hints=Kit.frame(root,"Hints",nil,UDim2.fromOffset(R.x,R.hintsY),UDim2.fromOffset(640,24))
 local x=0
 for _,pair in ipairs({{"L","",true},{"R","Tabs"},{"+","Move"},{"A","Claim"},{"B","Back"}})do
  local g=Kit.glyph(hints,pair[1],false,22,true);g.Position=UDim2.fromOffset(x,1)
  local w=g.Size.X.Offset
  if pair[3]then x+=w+4 else
   txt(hints,"Small",pair[2],"soft",x+w+6,0,80,24)
   x+=w+6+Kit.measure(pair[2],"Small",14).X+18
  end
 end
 local menu=Kit.button(root,"PocketMenu",{variant="ghost",text=UICopy.get("r3.quests.menu").." ›",size=Vector2.new(110,36),selectable=false})
 menu.Position=UDim2.fromOffset(R.x+R.width-110,R.hintsY-6);Kit.buttonState(menu).label.TextSize=15
 menu.Activated:Connect(function()if self.callbacks.menu then self.callbacks.menu()end end)
 self.ring=Kit.focusRing(self.overlay.layer)
end

function Log:rowsFor(tab)
 local q=self.quests;if not q then return {}end
 return if tab=="weekly"then q.weekly or {}else q.daily or {}
end
function Log:paintRow(slot,row,scope)
 slot.row.Visible=row~=nil
 if not row then return end
 local q=self.quests
 slot.title.RichText=true;slot.title.Text=BallThemes.questText(row.title,slot.title.TextSize);Kit.localizeRich(slot.title)
 slot.row:SetAttribute("AccessibleLabel",BallThemes.questText(row.title,nil,true))
 slot.sub.Text=row.sub or ""
 local statusText,statusTone=Log.status(row)
 slot.status.Text=statusText;Kit.paint(slot.status,"TextColor3",function()return Kit.Color[statusTone]or Kit.color(statusTone)end)
 slot.row:SetAttribute("Status",statusText)
 -- Compact rows have no status column: the word joins the what-to-do line.
 if slot.compact and statusText~=""then slot.sub.Text=(if slot.sub.Text~=""then slot.sub.Text.."  ·  "else "")..statusText end
 slot.bar.set(row.progress,row.target,true,true)
 -- R3.7: the bar fills in the Quests sky while in progress, gold when ready, mint once claimed.
 Kit.paint(slot.bar.fill,"BackgroundColor3",function()
  if row.claimed then return Kit.color("accent")end
  if row.ready then return Kit.Color.stars end
  return Kit.Tint.quests
 end)
 slot.count.Text=string.format("%d/%d",row.progress,row.target)
 slot.reward.Text="+"..tostring(row.reward)
 slot.rewardChip:SetAttribute("Reward",row.reward)
 -- The reward chip: a well pill; a gold sticker (ink text) while ready to claim.
 local ready=row.ready and not row.claimed
 slot.rewardChip.Rotation=if ready then Kit.Sticker.tilt else 0
 Kit.paint(slot.rewardChip,"BackgroundColor3",function()return if ready then Kit.Color.stars else Kit.color("well")end)
 slot.rewardStroke.Color=if ready then Kit.Sticker.cream else Kit.Stroke.color
 slot.rewardStroke.Thickness=if ready then 2 else 1;slot.rewardStroke.Transparency=if ready then 0 else Kit.Stroke.transparency
 Kit.paint(slot.reward,"TextColor3",function()return if ready then Kit.Color.ink else Kit.Color.stars end)
 Kit.paint(slot.rewardStar,"ImageColor3",function()return if ready then Kit.Color.ink else Kit.Color.stars end)
 if ready and not slot.wasReady then Kit.boing(slot.rewardChip)end
 slot.wasReady=ready
 slot.icon.ImageRectOffset=require(script.Parent.DeckAssets).Icon[if row.claimed then "check"else icons[row.pool]or "quests"]
 Kit.paint(slot.icon,"ImageColor3",if row.claimed then "accent"else "text")
 Kit.paint(slot.well,"BackgroundColor3",function()return Kit.color("well"):Lerp(if row.claimed then Kit.color("accent")else Kit.Tint.quests,if row.claimed then .14 else .16)end)
 local pending=self.pendingRows[scope..":"..row.slot]
 slot.claim.Visible=row.ready and not row.claimed
 Kit.setText(slot.claim,if pending then "…"else "Claim");Kit.setEnabled(slot.claim,not pending)
 slot.reroll.Visible=scope=="daily"and not row.ready and row.canReroll and (q.rerollLeft or 0)>0
 Kit.setEnabled(slot.reroll,not pending)
 slot.chip.root.Visible=row.claimed
 if row.claimed then slot.chip.set("CLAIMED","plain")end
 local alpha=if row.claimed then .4 else 0
 for _,t in ipairs({slot.title,slot.sub,slot.count,slot.status})do t.TextTransparency=alpha end
 Kit.paint(slot.row,"BackgroundColor3",function()return if row.ready and not row.claimed then Kit.color("raised"):Lerp(Kit.Color.stars,.07)else Kit.color("raised")end)
 slot.stroke.Thickness=if ready then 2 else 1;slot.stroke.Transparency=if ready then 0 else .86
 Kit.paint(slot.stroke,"Color",function()return if ready then Kit.Color.stars else Color3.new(1,1,1)end)
end
-- The stamp card block: shows on the daily tab when the snapshot carries the card.
function Log:stampState()
 local source=self.callbacks.stampState
 local state=if source then source()else nil
 return if type(state)=="table"then state else nil
end
function Log:paintStamp()
 local panel=self.panel;if not panel then return false end
 local state=self:stampState()
 local show=self.tab=="daily"and state~=nil
 panel.Visible=show
 if self.view then
  -- Phone: the block sits under the rows inside the scroll list.
  local rows=#self:rowsFor("daily")
  local base=self.rowPitch*math.max(1,rows)
  panel.Position=UDim2.fromOffset(0,base)
  local canvas=if show then base+self.stampH else math.max(0,base-(self.rowPitch-self.rowH))
  self.rowList.CanvasSize=UDim2.fromOffset(0,canvas+self.rowInset*2)
 end
 if not show then return false end
 local stamps=tonumber(state.stamps)or 0
 if self.stampSent and(stamps>self.stampSent.stamps or state.dailyAvailable~=true)then self.stampSent=nil end
 if self.stampSent and os.clock()-self.stampSent.at>Log.StampPendingSeconds then self.stampSent=nil end
 self.stampView:set(state)
 local available=state.dailyAvailable==true
 self.stampButton.Visible=available
 self.stampDone.Visible=not available
 Kit.setText(self.stampButton,if self.stampSent then "…"else StampCardView.buttonText(state))
 Kit.setEnabled(self.stampButton,available and self.stampSent==nil)
 Kit.paint(panel,"BackgroundColor3",function()return if available then Kit.color("raised"):Lerp(Kit.Tint.quests,.06)else Kit.color("raised")end)
 return true
end
function Log:paintHistory()
 for _,child in ipairs(self.history:GetChildren())do if child:IsA("GuiObject")then child:Destroy()end end
 local q=self.quests;if not q then return end
 if self.view then return self:paintCompactHistory(q)end
 local today=tonumber(q.day)or 0
 local lastDay,order,weekStars=nil,0,0
 local week=tonumber(q.week)or 0
 for _,entry in ipairs(q.history or {})do
  local d=tonumber(entry.d)or today
  if (d+3)//7==week then weekStars+=entry.s end
  if d~=lastDay then
   lastDay=d;order+=1
   local ago=today-d
   local header=Kit.text(self.history,"Label",if ago<=0 then "TODAY"elseif ago==1 then "YESTERDAY"else ago.." DAYS AGO","dim",{TextSize=12,Size=UDim2.fromOffset(784,30),LayoutOrder=order})
   header.TextYAlignment=Enum.TextYAlignment.Bottom
  end
  order+=1
  local row=Kit.listRow(self.history,if entry.a then "AUTO"else(if entry.weekly then "WEEK"else "DAY"),(if entry.weekly then "Weekly: "else "")..BallThemes.questText(entry.title,nil,true),entry.s)
  row.LayoutOrder=order;row.Selectable=false
 end
 if #(q.history or {})==0 then
  Kit.text(self.history,"Body","Claimed quests show up here.","soft",{Size=UDim2.fromOffset(784,42),LayoutOrder=1})
 end
 self.historyFooter.Text=weekStars.." Stars from quests this week"
end
-- Compact history (UI-SPEC-COMPACT 8): 44-high rows, 28-high group headers.
function Log:paintCompactHistory(q)
 local w=self.view.W-44
 local today=tonumber(q.day)or 0
 local lastDay,order,weekStars=nil,0,0
 local week=tonumber(q.week)or 0
 for _,entry in ipairs(q.history or {})do
  local d=tonumber(entry.d)or today
  if (d+3)//7==week then weekStars+=entry.s end
  if d~=lastDay then
   lastDay=d;order+=1
   local ago=today-d
   local header=Kit.text(self.history,"Label",if ago<=0 then "TODAY"elseif ago==1 then "YESTERDAY"else ago.." DAYS AGO","dim",{TextSize=12,Size=UDim2.fromOffset(w,28),LayoutOrder=order})
   header.TextYAlignment=Enum.TextYAlignment.Bottom
  end
  order+=1
  local row=Kit.frame(self.history,"ListRow",nil,UDim2.new(),UDim2.fromOffset(w,44));row.LayoutOrder=order
  local hair=Kit.frame(row,"Hairline",nil,UDim2.new(0,0,1,-1),UDim2.new(1,0,0,1));hair.BackgroundColor3,hair.BackgroundTransparency=Color3.new(1,1,1),.95
  txt(row,"Counter",if entry.a then "AUTO"else(if entry.weekly then "WEEK"else "DAY"),"dim",12,0,56,44,{TextSize=12})
  txt(row,"Body",(if entry.weekly then "Weekly: "else "")..BallThemes.questText(entry.title,nil,true),"text",72,0,w-72-120,44,{TextSize=14,TextTruncate=Enum.TextTruncate.AtEnd})
  txt(row,"Counter","★ +"..entry.s,"stars",w-120,0,80,44,{TextSize=14,TextXAlignment=Enum.TextXAlignment.Right})
  local mark=Kit.icon(row,"check",18,"accent");mark.Position=UDim2.fromOffset(w-30,13)
 end
 if #(q.history or {})==0 then
  Kit.text(self.history,"Body","Claimed quests show up here.","soft",{TextSize=14,Size=UDim2.fromOffset(w,44),LayoutOrder=1})
 end
 self.historyFooter.Text=weekStars.." Stars from quests this week"
end
function Log:paint()
 local q=self.quests or {daily={},weekly={},history={}}
 local daily,weekly=q.daily or {},q.weekly or {}
 self.tabs.labels[1].Text=string.format("Daily %d/%d",claimedCount(daily),#daily)
 self.tabs.labels[2].Text=string.format("Weekly %d/%d",claimedCount(weekly),#weekly)
 local dailyDot,weeklyDot=false,q.bonusReady==true
 for _,r in ipairs(daily)do if r.ready and not r.claimed then dailyDot=true end end
 for _,r in ipairs(weekly)do if r.ready and not r.claimed then weeklyDot=true end end
 local stampState=self:stampState()
 if stampState and stampState.dailyAvailable==true then dailyDot=true end
 self.tabs.setDot(1,dailyDot);self.tabs.setDot(2,weeklyDot)
 local tab=self.tab
 if not self.view and self.header then
  self.header.setTitle(if tab=="daily"then "Today"elseif tab=="weekly"then "This week"else "History",UICopy.get("r3.quests.eyebrow"))
 end
 self.reset.Text=if tab=="daily"then Log.resetText(q.resetIn)elseif tab=="weekly"then Log.resetText(q.weekResetIn)else(if #(q.history or {})==1 then "Last claim"else "Last "..#(q.history or {}).." claims")
 local resetWidth=Kit.measure(self.reset.Text,"Small",self.reset.TextSize).X
 if self.wallet then self.wallet.set(self.walletValue or 0)end
 if self.view then
  -- Compact: the timer ends 12 px left of the header's ? circle (or capsule), shown only
  -- with 130+ px of gap after the tabs.
  local g=self.header and self.header.geometry
  local limit=if g then g.title.x+g.title.w else self.view.W-200
  local show=limit-self.tabsRight>=130
  self.reset.Visible,self.clock.Visible=show,show
  self.reset.Position=UDim2.fromOffset(limit-160,20)
  self.clock.Position=UDim2.fromOffset(limit-resetWidth-21,23)
 else
  self.clock.Position=UDim2.fromOffset(824-resetWidth-24,Log.Regular.tabsY+13)
 end
 local list=tab~="history"
 for index,slot in ipairs(self.rows)do
  if list then self:paintRow(slot,self:rowsFor(tab)[index],tab)else slot.row.Visible=false end
 end
 if self.rowList then self.rowList.Visible=list end
 self.footer.Visible=list;self.history.Visible=not list;self.historyFooter.Visible=not list
 self:paintStamp()
 if self.bonusPanel then self.bonusPanel.Visible=tab=="weekly"end
 self.bonusBar.root.Visible=tab=="weekly";self.bonusClaim.Visible=false
 local allDone=tab=="daily"and #daily>0 and claimedCount(daily)==#daily
 local Icon=require(script.Parent.DeckAssets).Icon
 if tab=="daily"then
  self.footerIcon.ImageRectOffset=Icon.reroll;Kit.paint(self.footerIcon,"ImageColor3","accent")
  local left=q.rerollLeft or 0
  self.footerTitle.Text=if left>0 then "1 free reroll left today"else "No reroll left today"
  Kit.paint(self.footerTitle,"TextColor3",if left>0 then "text"else "soft")
  -- T12: every daily quest claimed: one line in voice, with the pet when there is one.
  if allDone then
   local name=Peek.petName()
   self.footerTitle.Text=if name then UICopy.get("quests.allDone",{pet=name})else UICopy.get("quests.allDoneSolo")
   Kit.paint(self.footerTitle,"TextColor3","text")
  end
  self.footerSub.Text="Swaps one quest you have not started."
  local earned,total=0,0;for _,r in ipairs(daily)do total+=r.reward;if r.claimed then earned+=r.reward end end
  self.footerLabel.Text="TODAY";self.footerValue.Text=string.format("★ %d/%d",earned,total);self.footerValue.Visible=true
  self.footerLabel.Visible=true
 elseif tab=="weekly"then
  self.footerIcon.ImageRectOffset=Icon.trophy;Kit.paint(self.footerIcon,"ImageColor3","stars")
  local bonus=q.bonus or {reward=5}
  local done=claimedCount(weekly)
  self.bonusBar.set(done)
  for i,cell in ipairs(self.bonusBar.cells)do if i<=done then Kit.paint(cell,"BackgroundColor3","stars")end end
  self.bonusClaim.Visible=q.bonusReady==true
  Kit.setEnabled(self.bonusClaim,not self.pendingRows["weekly:0"])
  if self.view then
   -- Compact weekly: the bonus lives in the footer: gold segments, ★ +5 or a Claim.
   self.footerTitle.Text=if bonus.claimed then "Weekly bonus claimed"else "Clear all three this week"
   Kit.paint(self.footerTitle,"TextColor3","text")
   self.footerLabel.Visible=false
   self.footerValue.Text="★ +"..(bonus.reward or 5);self.footerValue.Visible=not self.bonusClaim.Visible
   local fw=self.view.W-40
   self.bonusBar.root.Position=UDim2.fromOffset(if self.bonusClaim.Visible then fw-96-104-8-84 else fw-96-90-8-84,18)
  else
   -- Desktop weekly: the bonus card above; the footer sums the week.
   self.bonusReward.Text="★ +"..(bonus.reward or 5)
   self.bonusDone.root.Visible=bonus.claimed==true
   if bonus.claimed then self.bonusDone.set("CLAIMED","plain")end
   self.bonusLine.Text=if bonus.claimed then "Weekly bonus claimed"else UICopy.get("r3.quests.weekly.line")
   Kit.paint(self.bonusPanel,"BackgroundColor3",function()return if q.bonusReady then Kit.color("raised"):Lerp(Kit.Color.stars,.07)else Kit.color("raised")end)
   self.footerTitle.Text=Log.resetText(q.weekResetIn)
   Kit.paint(self.footerTitle,"TextColor3","soft")
   local earned,total=0,0;for _,r in ipairs(weekly)do total+=r.reward;if r.claimed then earned+=r.reward end end
   self.footerLabel.Text="THIS WEEK";self.footerLabel.Visible=true
   self.footerValue.Text=string.format("★ %d/%d",earned,total);self.footerValue.Visible=true
  end
  self.footerSub.Text="Bonus on top of the weekly quests."
 else self:paintHistory()end
 -- The sub line follows the title in the strip; it shows only with room to spare.
 local tw=Kit.measure(self.footerTitle.Text,"Strong",self.footerTitle.TextSize).X
 self.footerSub.Position=UDim2.fromOffset(40+tw+12,0)
 local subW=Kit.measure(self.footerSub.Text,"Small",self.footerSub.TextSize).X
 local labelLeft=self.footerValueRight-90-8-(if self.footerLabel.Visible then 80 else 0)
 self.footerSub.Visible=tab~="history"and not allDone and 40+tw+12+subW<=labelLeft-8 and(tab=="daily"or not self.view)
 self:syncPeek(allDone)
 self:paintFocus()
end
function Log:syncPeek(on)
 local footer=self.footer;if not footer then return false end
 if not on or not self.visible or self.view then Peek.hide(footer);return false end
 local avoid={{x=40,y=0,w=Kit.measure(self.footerTitle.Text,"Strong",self.footerTitle.TextSize).X*1.1,h=44}}
 local right=self.footerValueRight
 table.insert(avoid,{x=right-90-8-80,y=0,w=180,h=44})
 return Peek.show(footer,{rect=Log.PeekSlot,avoid=avoid,align="center",key="quests"})
end
function Log:focusables()
 if self.tab=="history"then return {}end
 local list={}
 for index,slot in ipairs(self.rows)do if slot.row.Visible then list[index]=slot.row end end
 if self.tab=="weekly"and self.bonusClaim.Visible then list[4]=self.bonusClaim end
 if self.tab=="daily"and self.panel and self.panel.Visible and self.stampButton.Visible then list[Log.StampFocus]=self.stampButton end
 return list
end
function Log:paintFocus()
 if not self.visible or self.tab=="history"then self.ring.hide();return end
 local targets=self:focusables()
 local target=targets[self.focusIndex]
 if not target then self.focusIndex=1;target=targets[1]end
 if not target then self.ring.hide();return end
 local slot=self.rows[self.focusIndex]
 local inner=slot and((slot.claim.Visible and slot.claim)or(slot.reroll.Visible and slot.reroll))
 self.ring.attach(inner or target,12)
 -- Phone: keep the focused row (or the stamp card) in view.
 if self.rowList and target:IsDescendantOf(self.rowList)then
  local holder=if target==self.stampButton then self.panel else target
  local top=holder.Position.Y.Offset;local bottom=top+holder.Size.Y.Offset+self.rowInset*2
  local view=self.rowList.AbsoluteWindowSize.Y;if view<=0 then view=self.rowList.Size.Y.Offset end
  local y=self.rowList.CanvasPosition.Y
  if top<y then y=top elseif bottom>y+view then y=bottom-view end
  self.rowList.CanvasPosition=Vector2.new(0,math.max(0,y))
 end
 self.overlay.layer:SetAttribute("FocusIndex",self.focusIndex)
end

function Log:setTab(tab)
 if not table.find(Log.Tabs,tab)then return end
 self.tab=tab;self.tabs.select(table.find(Log.Tabs,tab))
 self.overlay.layer:SetAttribute("Tab",tab)
 self.focusIndex=Log.initialFocus(self:rowsFor(tab),tab=="weekly"and self.quests and self.quests.bonusReady)
 -- Daily: with nothing to claim and today's stamp waiting, focus starts on the stamp.
 if tab=="daily"then
  local rows=self:rowsFor(tab);local anyReady=false
  for _,r in ipairs(rows)do if r.ready and not r.claimed then anyReady=true end end
  local s=self:stampState()
  if not anyReady and s and s.dailyAvailable==true then self.focusIndex=Log.StampFocus end
 end
 if self.rowList then self.rowList.CanvasPosition=Vector2.zero end
 self:paint()
 if self.callbacks.tab then self.callbacks.tab(tab)end
end
function Log:cycleTab(direction)
 local index=math.clamp(table.find(Log.Tabs,self.tab)+direction,1,#Log.Tabs)
 if Log.Tabs[index]~=self.tab then self:setTab(Log.Tabs[index]);return true end
 return false
end
function Log:move(direction)
 if not self.visible or self.tab=="history"then
  if self.visible and self.tab=="history"then self.history.CanvasPosition+=Vector2.new(0,direction*44)end
  return self.visible
 end
 local targets=self:focusables();local index=self.focusIndex
 repeat index+=direction until index<1 or index>Log.StampFocus or targets[index]
 if targets[index]then self.focusIndex=index;self:paintFocus()end
 return true
end

-- quests: the snapshot's `quests`; wallet: Stars.
function Log:update(quests,wallet)
 self.quests=quests;self.walletValue=wallet
 if self.visible then self:paint()end
end
function Log:show(quests,wallet,tab)
 local opening=not self.visible
 self.quests=quests;self.walletValue=wallet;self.visible=true;self.overlay.layer.Visible=true
 if opening then
  self.pendingRows={};self.stampSent=nil
  self:setTab(tab or "daily")
  if not Kit.reduced()then self.overlay.content.Position=UDim2.fromOffset(0,12);Kit.tween(self.overlay.content,Kit.Motion.screen,{Position=UDim2.new()})end
 else self:paint()end
end
function Log:hide()
 if not self.visible then return end
 self.visible=false;self.overlay.layer.Visible=false;self.ring.hide()
 if self.footer then Peek.hide(self.footer)end
end
-- A on the focused row: claim if ready, reroll if allowed; on the stamp, stamp today.
function Log:act()
 if not self.visible or not self.quests then return false end
 local q=self.quests
 if self.tab=="daily"and self.focusIndex==Log.StampFocus then
  local s=self:stampState()
  if not s or s.dailyAvailable~=true or self.stampSent or not s.dailyDay then return false end
  self.stampSent={stamps=tonumber(s.stamps)or 0,at=os.clock()}
  Kit.pulse(self.stampButton)
  if self.callbacks.stamp then self.callbacks.stamp(s.dailyDay)end
  self:paint();return true
 end
 if self.tab=="weekly"and self.focusIndex==4 then
  if not q.bonusReady or self.pendingRows["weekly:0"]then return false end
  self.pendingRows["weekly:0"]=true;Kit.pulse(self.bonusClaim)
  if self.callbacks.claim then self.callbacks.claim("weekly",0,q.week)end
  self:paint();return true
 end
 local scope=self.tab;local row=self:rowsFor(scope)[self.focusIndex]
 local action=Log.action(row,q.rerollLeft)
 if not action or self.pendingRows[scope..":"..row.slot]then return false end
 self.pendingRows[scope..":"..row.slot]=true
 if action=="claim"then
  Kit.pulse(self.rows[self.focusIndex].claim)
  if self.callbacks.claim then self.callbacks.claim(scope,row.slot,if scope=="daily"then q.day else q.week)end
 else
  Kit.pulse(self.rows[self.focusIndex].reroll)
  if self.callbacks.reroll then self.callbacks.reroll(row.slot,q.day)end
 end
 self:paint();return true
end

-- R3.7 celebration on a saved claim: the row boings, little Stars burst from the
-- reward chip and a "+N Stars" pop rises. Reduced Motion: the pop shows and hides.
Log.BurstCount=8
Log.CelebrateSeconds=1.1
function Log:celebrate(anchor,reward)
 if not anchor or not anchor.Parent then return false end
 local host=self.overlay.content
 local origin=anchor.AbsolutePosition-host.AbsolutePosition
 local scale=self.overlay.scale and self.overlay.scale.Scale or 1
 if scale<=0 then scale=1 end
 local cx=math.floor((origin.X+anchor.AbsoluteSize.X/2)/scale)
 local cy=math.floor((origin.Y+anchor.AbsoluteSize.Y/2)/scale)
 local z=host.ZIndex+40
 local pop=Kit.text(host,"Counter",UICopy.get("r3.quests.claimed",{reward=reward or 0}),"stars",{Name="ClaimPop",TextSize=18,
  TextXAlignment=Enum.TextXAlignment.Center,AnchorPoint=Vector2.new(.5,1)})
 local w=math.ceil(Kit.measure(pop.Text,"Counter",18).X)+12
 pop.Size=UDim2.fromOffset(w,24);pop.Position=UDim2.fromOffset(cx,cy-14);pop.ZIndex=z+2
 pop.TextStrokeTransparency=.6
 host:SetAttribute("LastCelebration",reward or 0)
 local parts={pop}
 if not Kit.reduced()then
  Kit.boing(anchor)
  Kit.tween(pop,.5,{Position=UDim2.fromOffset(cx,cy-40)})
  for i=1,Log.BurstCount do
   local star=Kit.icon(host,"star",14);star.Name="ClaimBurst";star.AnchorPoint=Vector2.new(.5,.5);star.ZIndex=z+1
   star.Position=UDim2.fromOffset(cx,cy)
   local angle=(i-1)/Log.BurstCount*math.pi*2+.3
   local reach=34+(i%3)*10
   local goal=UDim2.fromOffset(math.floor(cx+math.cos(angle)*reach),math.floor(cy+math.sin(angle)*reach*.7))
   Kit.tween(star,.45,{Position=goal,Rotation=if i%2==0 then 90 else -90})
   task.delay(.3,function()if star.Parent then Kit.tween(star,.3,{ImageTransparency=1})end end)
   table.insert(parts,star)
  end
 end
 task.delay(Log.CelebrateSeconds,function()
  if not pop.Parent then return end
  if Kit.reduced()then for _,p in ipairs(parts)do p:Destroy()end;return end
  Kit.tween(pop,.2,{TextTransparency=1,TextStrokeTransparency=1})
  task.delay(.22,function()for _,p in ipairs(parts)do if p.Parent then p:Destroy()end end end)
 end)
 return true
end

-- Server reply (QuestResult). Clears the pending mark; on a saved claim the row
-- celebrates and focus moves on to the next Ready row.
function Log:result(message)
 if type(message)~="table"then return false end
 local key=(message.scope or "daily")..":"..tostring(message.slot)
 self.pendingRows[key]=nil
 if self.visible then
  if message.status=="Saved"and message.action=="questClaim"then
   if message.scope==self.tab or(message.scope=="weekly"and message.slot==0 and self.tab=="weekly")then
    if message.slot==0 then
     local bonus=self.quests and self.quests.bonus
     self:celebrate(self.bonusClaim.Visible and self.bonusClaim or self.footer,message.stars or(bonus and bonus.reward))
    else
     for i,r in ipairs(self:rowsFor(self.tab))do
      if r.slot==message.slot and self.rows[i]then self:celebrate(self.rows[i].rewardChip,message.stars or r.reward)end
     end
    end
   end
   local rows=self:rowsFor(self.tab)
   for i,r in ipairs(rows)do if r.ready and not r.claimed and not(message.scope==self.tab and r.slot==message.slot)then self.focusIndex=i;break end end
  end
  self:paint()
 end
 return true
end
-- The snapshot moved on (a new stamp, a new day): repaint the stamp block.
function Log:refreshStamp()
 if self.visible then self:paint()end
end
return Log
