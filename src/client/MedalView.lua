-- Stat medals, client side (V3-LEVELS-BUILD-PLAN-2026-11-22 S4, artifacts/levels-2026-11-22/art.json).
-- One drawing for every place a medal shows (the six slots on the stats panel, the Marks row on the
-- inspect card, the reward guide, the medal moment), and the moment itself. Derived from levels:
-- nothing here is saved, claimed or granted.
--   View.new(parent,size) -> {root, set(stat, count)}   count 0 (unearned) .. 4 (Starbloom)
--   View.Moment.new(playerGui, audio):show(crossed, info, callbacks)
local ContextActionService=game:GetService("ContextActionService")
local GuiService=game:GetService("GuiService")
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Medals=require(Shared.Medals)
local Stats=require(Shared.StatCatalog)
local UICopy=require(Shared.UICopy)
local View={}
-- The uploaded images (assets/ui/levels/medal-<level>-<tint|trim>.png, 256 px), by tier level:
-- [25]={tint="rbxassetid://...",trim="rbxassetid://..."}. A tier with no row (or half a row) draws
-- the discs below instead. The tint layer takes the stat's colour; the trim is never tinted.
View.Art={
 [25]={tint="rbxassetid://90236769323715",trim="rbxassetid://136852142964634"},
 [50]={tint="rbxassetid://102026866321678",trim="rbxassetid://80587895341395"},
 [75]={tint="rbxassetid://96749218944985",trim="rbxassetid://72046428689012"},
 [99]={tint="rbxassetid://80652233269995",trim="rbxassetid://85722125258746"}}
-- Shares of the 256 px canvas (art.json): the medal's centre, its cream well, the icon, and the
-- drawn fallback's discs.
View.Centre=Vector2.new(128/256,138/256)
View.Share=table.freeze({well=104/256,icon=92/256,disc=160/256,ring=194/256,petals=232/256,star=66/256})
View.StarAt=Vector2.new(128/256,38/256)
View.UnearnedTrim=.65 -- transparency (35% opacity)

-- Pure ---------------------------------------------------------------------------
function View.art(count)
 local tier=Medals.Tiers[count]
 local row=tier and View.Art[tier.level]
 if type(row)~="table"or type(row.tint)~="string"or row.tint==""or type(row.trim)~="string"or row.trim==""then return nil end
 return row
end
-- Which drawn parts a medal of `count` shows: the disc, the cream ring, the second ring, the star.
function View.parts(count)
 local tier=Medals.Tiers[count]
 return{disc=true,icon=tier~=nil,ring=tier~=nil and tier.rings>=1,petals=tier~=nil and tier.rings>=2,star=tier~=nil and tier.star==true}
end
-- "Jump: Sprout medal" / "Jump: Level 25" (the first medal waits).
function View.label(stat,count)
 local name=UICopy.get("stats.name."..stat)
 local tier=Medals.Tiers[count]
 return name..": "..(if tier then UICopy.get("medal."..tier.id)else UICopy.get("stats.guide.at",{level=Medals.Levels[1]}))
end
-- The words of a moment for one or several medals crossed together (Medals.crossed rows).
-- {name, effect, sticker, line, stat, count}: the highest tier leads; the rest share its stage.
function View.words(crossed,waiting)
 local lead,best=nil,0
 local parts={}
 for _,row in ipairs(type(crossed)=="table"and crossed or {})do
  local index=Medals.index(row.tier)
  if index and Stats.ById[row.stat]then
   table.insert(parts,UICopy.get("stats.levelUp",{name=UICopy.get("stats.name."..row.stat),count=row.level}))
   if index>best then lead,best=row,index end
  end
 end
 if not lead then return nil end
 local eggs=if type(waiting)=="number"and waiting>=1 then math.floor(waiting)else #parts
 return{stat=lead.stat,count=best,tier=lead.tier,name=UICopy.get("medal."..lead.tier),effect=table.concat(parts," · "),
  sticker=UICopy.get("stats.tier."..lead.tier),line=if eggs==1 then UICopy.get("medal.eggOne")else UICopy.get("medal.eggs",{count=eggs})}
end
-- The rail line when the moment cannot play, and at join while credit waits.
function View.ticket(crossed)
 local words=View.words(crossed)
 return words and UICopy.get("medal.earned",{name=UICopy.get("stats.tier."..words.tier)})or nil
end
function View.waitingText(count)
 if type(count)~="number"or count<1 then return nil end
 return if count==1 then UICopy.get("medal.eggOne")else UICopy.get("medal.eggs",{count=math.floor(count)})
end
-- The stat whose colour trims an inspect card (75 and up), or nil: the highest level, panel order first.
function View.trimStat(levels)
 local best,at=nil,0
 for _,slot in ipairs(Medals.forPet(levels))do
  local level=type(levels)=="table"and levels[slot.stat]or 0
  if slot.tier and slot.tier.trim and level>at then best,at=slot.stat,level end
 end
 return best
end
-- The tier's sting (the existing hatch stings) until the medal stings are uploaded.
View.Sting=table.freeze({sprout="Common",bloom="Uncommon",fullBloom="Rare",starbloom="Rare"})

-- Drawing ------------------------------------------------------------------------
function View.new(parent,size)
 local Kit=require(script.Parent.DeckKit)
 local root=Kit.frame(parent,"Medal",nil,UDim2.new(),UDim2.fromOffset(size,size))
 local z=root.ZIndex
 local stroke=math.max(1,math.floor(size*.02+.5))
 local function disc(name,share,order)
  local d=Kit.frame(root,name,nil,UDim2.fromScale(View.Centre.X,View.Centre.Y),UDim2.fromScale(share,share),999)
  d.AnchorPoint=Vector2.new(.5,.5);d.BackgroundTransparency=0;d.ZIndex=z+order
  local edge=Kit.node("UIStroke",d,{Name="Edge",Thickness=stroke,Color=Kit.Color.ink,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
  return d,edge
 end
 local api={root=root}
 local drawn,images,icon
 local function drawnParts()
  if drawn then return drawn end
  local S=View.Share
  drawn={}
  drawn.petals,drawn.petalsEdge=disc("Petals",S.petals,1)
  drawn.ring,drawn.ringEdge=disc("Ring",S.ring,2);drawn.ring.BackgroundColor3=Kit.Color.cream
  drawn.disc,drawn.discEdge=disc("Disc",S.disc,3)
  drawn.well,drawn.wellEdge=disc("Well",S.well,4);drawn.well.BackgroundColor3=Kit.Color.cream
  drawn.star=Kit.icon(root,"star",math.max(8,math.floor(size*S.star)),"stars")
  drawn.star.AnchorPoint=Vector2.new(.5,.5);drawn.star.Position=UDim2.fromScale(View.StarAt.X,View.StarAt.Y);drawn.star.Size=UDim2.fromScale(S.star,S.star);drawn.star.ZIndex=z+6
  return drawn
 end
 local function imageParts()
  if images then return images end
  images={}
  for index,name in ipairs({"Tint","Trim"})do
   images[name]=Kit.node("ImageLabel",root,{Name=name,BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=z+index,Active=false})
  end
  return images
 end
 function api.set(stat,count)
  count=if type(count)=="number"then math.clamp(math.floor(count),0,#Medals.Tiers)else 0
  local row=Stats.ById[stat]
  local earned=count>0 and row~=nil
  local art=View.art(math.max(1,count))
  if art then
   local parts=imageParts()
   parts.Tint.Image,parts.Trim.Image=art.tint,art.trim
   Kit.paint(parts.Tint,"ImageColor3",if earned then function()return row.color end else "wellDot")
   parts.Trim.ImageTransparency=if earned then 0 else View.UnearnedTrim
  end
  if images then images.Tint.Visible=art~=nil;images.Trim.Visible=art~=nil end
  if not art then drawnParts()end
  if drawn then
   local show=View.parts(count)
   local on=art==nil
   drawn.disc.Visible=on;drawn.well.Visible=on
   drawn.ring.Visible=on and show.ring;drawn.petals.Visible=on and show.petals;drawn.star.Visible=on and show.star
   Kit.paint(drawn.disc,"BackgroundColor3",if earned then function()return row.color end else "wellDot")
   if earned then drawn.petals.BackgroundColor3=row.color end
   drawn.well.BackgroundTransparency=if earned then 0 else View.UnearnedTrim
   drawn.discEdge.Transparency=if earned then 0 else View.UnearnedTrim
   drawn.wellEdge.Transparency=if earned then 0 else View.UnearnedTrim
  end
  if icon and(not earned or icon:GetAttribute("Stat")~=stat)then icon:Destroy();icon=nil end
  if earned and not icon then
   icon=require(script.Parent.StatsPanel).icon(root,stat,math.max(8,math.floor(size*View.Share.icon)))
   icon:SetAttribute("Stat",stat)
   icon.AnchorPoint=Vector2.new(.5,.5);icon.Position=UDim2.fromScale(View.Centre.X,View.Centre.Y);icon.Size=UDim2.fromScale(View.Share.icon,View.Share.icon);icon.ZIndex=z+5
  end
  root:SetAttribute("Stat",stat);root:SetAttribute("Count",count)
  root:SetAttribute("AccessibleLabel",if row then View.label(stat,count)else nil)
 end
 return api
end

-- The moment ---------------------------------------------------------------------
-- Medals crossed together, on the item hatch's own stage (HatchItemStage, as the Names Egg does):
-- the dark medal rocks, bursts in the stat's colour and settles. Reduced Motion: the stage's own
-- cross-fade, no rocking. Its own ScreenGui above the menus and its own ContextAction while it shows.
local Moment={};Moment.__index=Moment
View.Moment=Moment
Moment.Max=4 -- medals drawn on one stage (the words name every one)

local function medalScene(crossed)
 local root=Instance.new("Frame");root.Name="MedalScene";root.BackgroundTransparency=1;root.Size=UDim2.fromScale(1,1)
 local function group(name)
  local g=Instance.new("CanvasGroup");g.Name=name;g.BackgroundTransparency=1;g.Size=UDim2.fromScale(1,1);g.Parent=root
  return g
 end
 local dark,bright=group("Dark"),group("Bright")
 local scale=Instance.new("UIScale");scale.Parent=bright
 bright.AnchorPoint=Vector2.new(.5,.5);bright.Position=UDim2.fromScale(.5,.5)
 local shown=math.min(Moment.Max,#crossed)
 local share=if shown==1 then .62 elseif shown==2 then .46 else .36
 local darks={}
 for index=1,shown do
  local row=crossed[index]
  local x=.5+(index-(shown+1)/2)*(if shown==1 then 0 else math.min(share,.92/shown))
  for layer,parent in ipairs({dark,bright})do
   local medal=View.new(parent,160)
   medal.root.AnchorPoint=Vector2.new(.5,.5);medal.root.Position=UDim2.fromScale(x,.52);medal.root.Size=UDim2.fromScale(share,share)
   local ratio=Instance.new("UIAspectRatioConstraint");ratio.Parent=medal.root
   medal.set(row.stat,if layer==1 then 0 else Medals.index(row.tier)or 1)
   if layer==1 then table.insert(darks,medal.root)end
  end
 end
 local scene={ready=true,root=root}
 function scene:borrow(seat)root.Parent=seat;return root end
 function scene:release(token)if token==root then root.Parent=nil end end
 function scene:setBare()end
 function scene:setVeil()end
 function scene:layout()end
 function scene:setSpin()return false end
 function scene:render(sample)
  local before=sample.shellAlpha or 0
  dark.Visible=before>.01;dark.GroupTransparency=1-before
  for _,medal in ipairs(darks)do medal.Rotation=math.deg(sample.rock or 0)*.6 end
  local after=sample.heroAlpha or 0
  bright.Visible=after>.01;bright.GroupTransparency=1-after
  scale.Scale=math.max(.01,sample.heroScale or 1)
 end
 function scene:destroy()self.destroyed=true;root:Destroy()end
 return scene
end
Moment.scene=medalScene

function Moment.new(playerGui,audio)
 local gui=Instance.new("ScreenGui");gui.Name="EggDropMedal";gui.ResetOnSpawn=false;gui.DisplayOrder=16
 gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.ScreenInsets=Enum.ScreenInsets.None;gui.IgnoreGuiInset=true;gui.Enabled=false;gui.Parent=playerGui
 local host=Instance.new("Frame");host.Name="StageHost";host.BackgroundTransparency=1;host.Size=UDim2.fromScale(1,1);host.Parent=gui
 local function source(name,text)
  local b=Instance.new("TextButton");b.Name=name;b.Size=UDim2.fromOffset(0,0);b.BackgroundTransparency=1;b.TextTransparency=1;b.Text=text;b.Parent=gui
  return b
 end
 return setmetatable({gui=gui,host=host,doneSource=source("Done",UICopy.get("names.reveal.done")),eggsSource=source("Eggs",UICopy.get("stats.snacks.eggs")),audio=audio,open=false},Moment)
end
function Moment:isOpen()return self.open end
-- crossed: Medals.crossed rows. info: {waiting = medal eggs waiting}. callbacks: eggs(), done().
-- False when there is nothing to show or the stage could not be built: then nothing is left open (the
-- host says it with a rail ticket; the egg is the server's and does not depend on this).
function Moment:show(crossed,info,callbacks)
 self:close("replaced")
 info=info or {}
 local words=View.words(crossed,info.waiting)
 if not words then return false end
 self.callbacks=callbacks or {}
 self.building=true
 local ok,problem=pcall(self.build,self,crossed,words)
 self.building=false
 if ok then
  self.open=true
  ok,problem=pcall(self.begin,self)
 end
 if ok then return true end
 warn("[Levels] medal moment: "..tostring(problem))
 -- A stage that died half built never reached self.stage: take what it left.
 local half=self.stage==nil
 self.open=true;self:close("failed")
 if half then self.host:ClearAllChildren()end
 return false
end
function Moment:build(crossed,words)
 local Kit=require(script.Parent.DeckKit)
 local Stage=require(script.Parent.HatchItemStage)
 local Rarity=require(script.Parent.HatchRarityCue)
 self.gui.Enabled=true
 self.reducedStart=Kit.reduced()
 self.scene=medalScene(crossed)
 self.age=0
 self.timing=Rarity.timing("Neutral","medal",self.reducedStart)
 self.sting=Rarity.Sting and Rarity.Sting[View.Sting[words.tier]or "Common"]or nil
 self.stingAt=if self.reducedStart then 0 else math.max(0,self.timing.burst-(self.sting and self.sting.hit or 0))
 self.owner={}
 self.eggsSource.Visible=self.callbacks.eggs~=nil
 local color=Stats.ById[words.stat].color
 local stage=Stage.show(self.host,{scene=self.scene,kind="medal",tier="Neutral",result={medal=words.tier},cover=false,fullScreen=true,zIndex=20,lid=false,
  reduced=function()return self.reducedStart end,owns=function()return self.open or self.building==true end,skippable=function()return true end,
  name=function()return words.name end,effect=function()return words.effect end,description=function()return words.line end,
  sticker=function()return words.sticker end,accent=function()return color end,
  stoneColors=function()return {color,Kit.Color.lemon,Kit.Color.cream}end,
  actions=function()
   local list={{source=self.doneSource,primary=self.callbacks.eggs==nil,act=function()self:choose("done")end}}
   if self.callbacks.eggs then table.insert(list,{source=self.eggsSource,primary=true,act=function()self:choose("eggs")end})end
   return list
  end,
  onSkip=function()self:skip()end,onClose=function()self:choose("done")end})
 self.stage=stage
 stage.root:SetAttribute("Medal",words.tier);stage.root:SetAttribute("MedalStat",words.stat);stage.root:SetAttribute("MedalCount",#crossed)
end
function Moment:begin()
 self:step(0)
 self.clock=RunService.RenderStepped:Connect(function(dt)
  local ok,problem=pcall(self.step,self,dt)
  if not ok then warn("[Levels] medal moment: "..tostring(problem));self:close("failed")end
 end)
 local K=Enum.KeyCode
 ContextActionService:BindActionAtPriority("EggDropMedal",function(_,state,input)
  if not self.open or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
  if state==Enum.UserInputState.Begin then
   local k=input.KeyCode
   local settled=self.stage and self.stage:inputOpen()
   if not settled then self:skip()
   elseif k==K.ButtonB or k==K.Escape or k==K.Backspace then self:choose("done")
   else self:choose(if self.callbacks.eggs then "eggs"else "done")end
  end
  return Enum.ContextActionResult.Sink
 end,false,Enum.ContextActionPriority.High.Value+835,K.ButtonA,K.ButtonB,K.Return,K.KeypadEnter,K.Space,K.Escape,K.Backspace)
end
function Moment:step(dt)
 local stage=self.stage;if not stage or stage.destroyed or not self.open then return end
 if not stage:holdsClock()then self.age+=math.clamp(dt,0,.1)end
 if self.age>self.timing.duration then self.age=self.timing.duration end
 local sample=require(script.Parent.HatchDisplayPose).sample(self.age,"medal",self.reducedStart,"Neutral")
 self.scene:render(sample)
 stage:updateExternal(self.age,sample)
 if self.sting and not self.stung and self.age>=self.stingAt then
  self.stung=true
  if self.audio then pcall(function()self.audio:play(self.sting.cue,1,self.sting.gain,self.owner)end)end
 end
end
function Moment:skip()
 if not self.stage or self.stage:inputOpen()or not self.stage.skippable then return false end
 self.stung=true
 self.age=self.timing.duration
 return true
end
function Moment:choose(choice)
 if not self.open then return end
 local callbacks=self.callbacks
 self:close(choice)
 local callback=callbacks and callbacks[choice]
 if callback then callback()end
end
function Moment:close(reason)
 if not self.open then return false end
 self.open=false;self.stung=nil
 ContextActionService:UnbindAction("EggDropMedal")
 if self.clock then self.clock:Disconnect();self.clock=nil end
 if self.audio and self.audio.stopOwner and self.owner then pcall(function()self.audio:stopOwner(self.owner)end)end
 local stage,scene=self.stage,self.scene
 self.stage,self.scene=nil,nil
 if stage then
  local function gone()if scene then scene:destroy()end end
  local ok,problem=pcall(function()if not stage:dismiss(gone,{})then stage:destroy();gone()end end)
  if not ok then warn("[Levels] medal moment: "..tostring(problem));pcall(stage.destroy,stage);pcall(gone)end
 elseif scene then pcall(scene.destroy,scene)end
 self.gui.Enabled=false
 if self.callbacks and self.callbacks.closed then self.callbacks.closed(reason)end
 return true
end
function Moment:destroy()self:close("destroy");self.gui:Destroy()end
return View
