-- Inspect another player's pet (QA v685 R6; VISITOR-PET-SCOPE 2026-11-14), as a
-- profile card. Left: a live, spinnable 3D preview in the pet's real appearance. Right:
-- the name slot (v2 pet names: the chosen name, with the species on the owner line), the owner and bond level, a grid
-- of every wearable slot with the equipped item or Empty, then charm, finish and toy,
-- and Say hello.
--
-- Read-only, one card at a time. It reuses RoomCompanions (the rendered visitor pets)
-- and GardenClient (identity and appearance): nothing here renders a second world pet,
-- and the card reads only the board's public attributes (PetAppearance, CompanionId,
-- PublicBond, GreetingsOff). Opens within 12 studs by a tap or click on the pet, or
-- E / X on the quiet Inspect prompt. Closes on B / Escape / Backspace, the close button,
-- walking away, a menu opening, or when the target leaves or changes.
--
-- v2 S4 (V2-SCOPE-2026-11-19 section 6): two tabs over the right column. Stats (default): six
-- level tiles with stat icon chips (Heart, Power, Energy / Jump, Speed, Smarts), a tier word from 25
-- up, the total level and the Keeper tier chip, read from the board's public PublicStats
-- attribute (levels only; XP, Stars and history stay private). Outfit: the slot grid above.
-- Compare shows the local player's own pet that is out ("You 41") beside each number.
--
-- Say hello sends one request (owner, pet, character and pet generation); the server
-- decides. Reward-free. The wave itself arrives on the owner's board (PetHelloPose).
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local GuiService=game:GetService("GuiService")
local HttpService=game:GetService("HttpService")
local Shared=ReplicatedStorage.Shared
local Kit=require(script.Parent.DeckKit)
local Bounds=require(script.Parent.PetRigBounds)
local ClickTarget=require(script.Parent.PetClickTarget)
local Rules=require(Shared.PetHelloRules)
local UICopy=require(Shared.UICopy)
local Wearables=require(Shared.WearableCatalog)
local Toys=require(Shared.ToyCatalog)
local Materials=require(Shared.MaterialCatalog)
local Charms=require(Shared.PetCharmCatalog)
local StatCatalog=require(Shared.StatCatalog)
local StatsPanel=require(script.Parent.StatsPanel)
-- Levels matter (S4): the Marks row (medals derived from the public levels) and the trim from 75.
local Levels=require(Shared.Levels)
local Medals=require(Shared.Medals)
local MedalView=require(script.Parent.MedalView)

local Inspect={};Inspect.__index=Inspect
Inspect.Action="PetInspectClose"
Inspect.Columns=3
Inspect.GoneHold=1.2
Inspect.SpinPerPixel=.012

-- Pure: the card's rows for a pet and its public appearance.
-- { {key, label, value, empty} ... }: every wearable slot in shop order, then charm,
-- finish and toy. `value` is a display name; `empty` marks a slot with nothing in it.
function Inspect.rows(petId,appearance)
 appearance=type(appearance)=="table"and appearance or {}
 local rows={}
 local worn=type(appearance.wearables)=="table"and appearance.wearables or {}
 for _,tab in ipairs(Wearables.Tabs)do
  local id=Wearables.equippedIn(petId,worn,tab.slot)
  -- A level-gated item still worn while gates are off keeps its name.
  local item=id and(Wearables.item(petId,id)or Wearables.forPet(petId,math.huge).byId[id])
  table.insert(rows,{key=tab.id,label=tab.label,value=if item then item.name else UICopy.get("inspect.empty"),empty=item==nil})
 end
 local shape=Charms.ById[Charms.renderShape(appearance.charmShape)]
 local shown=appearance.charmVisible==true
 table.insert(rows,{key="charm",label=UICopy.get("inspect.slot.charm"),value=if shown and shape then shape.name else UICopy.get("inspect.hidden"),empty=not shown})
 local finish=Materials.ById[appearance.finish]or Materials.ById[Materials.Default]
 table.insert(rows,{key="finish",label=UICopy.get("inspect.slot.finish"),value=finish.name,empty=false})
 local toy=Toys.known(appearance.toyId)and appearance.toyId or Toys.Default
 table.insert(rows,{key="toy",label=UICopy.get("inspect.slot.toy"),value=if toy==Toys.Default then UICopy.get("inspect.empty")else Toys.ById[toy].name,empty=toy==Toys.Default})
 return rows
end
-- Pure: the Say hello button's state. Returns a UICopy key and whether it can be pressed.
function Inspect.helloState(facts)
 if facts.off then return "inspect.off",false end
 if facts.sent then return "inspect.sent",false end
 if facts.cooling then return "inspect.wait",false end
 if facts.distance==nil or facts.distance>Rules.HelloRange then return "inspect.closer",false end
 if not facts.free then return "inspect.busy",false end
 return "inspect.hello",true
end
-- Pure (v2 S4): one pet's public stats from a board's PublicStats JSON, or nil when there is
-- none. Only levels are read; each is clamped to 1..99 and the total is re-added here, so a
-- malformed attribute can never show more than the catalogue allows. Words are localised here
-- (the server's English Keeper word is not shown).
-- {stats = {{id, level, tier}} in StatCatalog.Order, total, keeper}
Inspect.TierFrom=StatCatalog.Tiers[2].level -- the tier word shows from Sprout (25) up
function Inspect.statsModel(raw,petId)
 if type(raw)~="string"or type(petId)~="string"then return nil end
 local ok,data=pcall(HttpService.JSONDecode,HttpService,raw)
 local pets=ok and type(data)=="table"and data.pets
 local entry=type(pets)=="table"and pets[petId]
 if type(entry)~="table"or type(entry.levels)~="table"then return nil end
 local out={stats={},total=0}
 for _,id in ipairs(StatCatalog.Order)do
  local level=entry.levels[id]
  level=if type(level)=="number"and level==level and math.abs(level)~=math.huge then math.clamp(math.floor(level),1,StatCatalog.MaxLevel)else 1
  table.insert(out.stats,{id=id,level=level,tier=if level>=Inspect.TierFrom then StatsPanel.tierWord(level)else ""})
  out.total+=level
 end
 out.keeper=StatsPanel.keeperWord(out.total)
 return out
end
-- v859 phone notes: the button flickered between "Say hello" and "Playing right now" as the
-- pet's garden actor stepped between follow, wander pauses and play. The free/busy fact is now
-- debounced: a change has to hold for FreeHold seconds before the button follows it.
Inspect.FreeHold=1.2
function Inspect.stableFree(memo,raw,now)
 if memo.free==nil then memo.free,memo.since=raw,nil;return raw end
 if raw==memo.free then memo.since=nil;return memo.free end
 memo.since=memo.since or now
 if now-memo.since>=Inspect.FreeHold then memo.free,memo.since=raw,nil end
 return memo.free
end
-- Pure: card geometry for a screen. Compact = a phone-height screen. `marks` (Levels matter S4):
-- room for the medals: a row of their own, or (phones, where the card has no row to spare) the right
-- of the summary strip.
function Inspect.geometry(width,height,marks)
 local compact=height<500
 local pad=if compact then 8 else 12
 local W=math.min(if compact then 460 else 540,width-24)
 local preview=if compact then 156 else 216
 -- v2 S4: the Outfit grid shares its area with the Stats tab under a tab bar, so phone rows
 -- are 26 px (read-only cells; the card still clears the top bar on an 812x354 phone).
 local rowH=if compact then 26 else 34
 local gap=4
 local rows=math.ceil((#Wearables.Tabs+3)/Inspect.Columns)
 local head=if compact then 22 else 26
 local sub=if compact then 16 else 18
 local button=if compact then 38 else 44
 local tabsH=if compact then 26 else 32
 local tabsY=pad+head+sub+2
 local gridY=tabsY+tabsH+4
 local gridH=rows*rowH+(rows-1)*gap
 -- Stats tab: two rows of tiles, the summary strip, the privacy line.
 local tileH=if compact then 46 else 60
 local stripH=if compact then 30 else 40
 local noteH=if compact then 12 else 16
 local marksH=if marks and not compact then 38 else 0
 if marks and compact then stripH=34 end
 local statsH=tileH*2+gap*2+stripH+2+noteH+(if marksH>0 then marksH+gap else 0)
 local bodyH=math.max(gridH,statsH)
 local H=gridY+bodyH+8+button+pad+4
 local x0=pad+preview+pad
 return {compact=compact,pad=pad,W=W,H=H,preview=preview,rowH=rowH,gap=gap,rows=rows,head=head,sub=sub,button=button,gridY=gridY,gridH=gridH,x0=x0,rightW=W-x0-pad,
  tabsH=tabsH,tabsY=tabsY,tileH=tileH,stripH=stripH,noteH=noteH,statsH=statsH,marks=marks==true,marksH=marksH,bodyH=bodyH,compareW=if compact then 96 else 112}
end

-- options:
--   companions   RoomCompanions (active: player -> {visual, pet, board, root})
--   garden       GardenClient (get, appearance, snapshot)
--   createPreview(parent, origin, pet, scale, appearance): the card's viewport pet (default PetFactory.new)
--   reduce()     Reduced Motion / Reduced Effects
--   canOpen()    false while a menu, focus, the deck or anything modal owns the screen
--   ownPet()     the local player's own garden pet visual (a tap nearer to it is not ours)
--   remote       the PetHello RemoteEvent (default ReplicatedStorage.Remotes.PetHello)
--   parent       where the ScreenGui goes (default PlayerGui)
function Inspect.new(options)
 local self=setmetatable({options=options,seq=0,connections={},spin=0},Inspect)
 local gui=Instance.new("ScreenGui")
 gui.Name="PetInspect";gui.ResetOnSpawn=false;gui.DisplayOrder=11;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
 gui.Enabled=true;gui.Parent=options.parent or Players.LocalPlayer:WaitForChild("PlayerGui")
 self.gui=gui
 -- Kit parts take their ZIndex from a GuiObject parent, so cards live in one clear root frame.
 local root=Instance.new("Frame")
 root.Name="Root";root.BackgroundTransparency=1;root.BorderSizePixel=0;root.Size=UDim2.fromScale(1,1);root.Active=false;root.Parent=gui
 self.root=root
 -- The quiet prompt: one small chip over the nearest inspectable pet.
 local chip=Instance.new("BillboardGui")
 chip.Name="InspectPrompt";chip.Size=UDim2.fromOffset(104,28);chip.StudsOffsetWorldSpace=Vector3.new(0,2.1,0)
 chip.AlwaysOnTop=true;chip.Active=true;chip.Enabled=false;chip.ResetOnSpawn=false;chip.MaxDistance=Rules.InspectLeave+8;chip.Parent=gui.Parent
 local pill=Instance.new("TextButton")
 pill.Name="Pill";pill.Text="";pill.AutoButtonColor=false;pill.Size=UDim2.fromScale(1,1);pill.BackgroundColor3=Color3.fromHex("#15171B");pill.BackgroundTransparency=.35
 pill.BorderSizePixel=0;pill.Selectable=false;pill.Parent=chip;Kit.corner(pill,999)
 local key=Kit.text(pill,"Strong","E","text",{Name="Key",Size=UDim2.fromOffset(22,22),Position=UDim2.fromOffset(4,3),TextXAlignment=Enum.TextXAlignment.Center,TextSize=13})
 Kit.fixedText(key)
 local word=Kit.text(pill,"Small",UICopy.get("inspect.prompt"),"soft",{Name="Word",Size=UDim2.new(1,-34,1,0),Position=UDim2.fromOffset(30,0),TextSize=13})
 self.chip,self.chipKey,self.chipWord=chip,key,word
 pill.Activated:Connect(function()if self.candidate then self:open(self.candidate)end end)
 local function watch(signal,fn)table.insert(self.connections,signal:Connect(fn))end
 local function tap(x,y,processed)
  if processed or self.card or not self:allowed()then return end
  local player=self:hit(Vector2.new(x,y))
  if player then self:open(player)end
 end
 watch(UserInputService.TouchTapInWorld,function(position,processed)tap(position.X,position.Y,processed)end)
 watch(UserInputService.InputBegan,function(input,processed)
  if input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
  local at=UserInputService:GetMouseLocation();tap(at.X,at.Y,processed)
 end)
 local remote=options.remote or ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PetHello",5)
 self.remote=remote
 if remote then watch(remote.OnClientEvent,function(result)self:onReply(result)end)end
 watch(GuiService.MenuOpened,function()self:close("menu")end)
 return self
end
function Inspect:allowed()
 local canOpen=self.options.canOpen
 return not self.destroyed and(canOpen==nil or canOpen()==true)and not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox()
end
local function localRoot()
 local character=Players.LocalPlayer.Character
 return character and character:FindFirstChild("HumanoidRootPart")
end
-- A visitor entry that can be inspected from `from`: rendered, in the garden, in range.
function Inspect:reach(entry,from)
 local visual=entry and entry.visual
 if not visual or visual.destroyed or not entry.board or not entry.root or not entry.root.Parent then return nil end
 local mode=entry.board:GetAttribute("Mode")
 if mode~="Room"and mode~="Board"then return nil end
 local d=visual.origin-from
 if math.abs(d.Y)>Rules.HeightReach then return nil end
 return Vector2.new(d.X,d.Z).Magnitude
end
-- The nearest inspectable visitor pet's owner, or nil.
function Inspect:nearest()
 local root=localRoot();if not root then return nil end
 local best,bestDistance=nil,Rules.InspectRange
 for player,entry in pairs(self.options.companions.active)do
  local distance=self:reach(entry,root.Position)
  if distance and distance<=bestDistance then best,bestDistance=player,distance end
 end
 return best,bestDistance
end
-- The owner whose pet a tap at `point` (screen px) lands on, or nil. The same forgiving
-- screen-space radius as the owner's own pet (PetClickTarget); the nearer centre wins.
function Inspect:hit(point)
 local root=localRoot();local camera=workspace.CurrentCamera
 if not root or not camera then return nil end
 local function measure(visual)
  local frame,size=Bounds.get(visual)
  if not frame or not size then return nil end
  local at,onScreen=camera:WorldToViewportPoint(frame.Position)
  if not onScreen or at.Z<=0 then return nil end
  local px=ClickTarget.boxSize(size).Magnitude/2/at.Z*(camera.ViewportSize.Y/2)/math.tan(math.rad(camera.FieldOfView/2))
  local gap=(point-Vector2.new(at.X,at.Y)).Magnitude
  return if gap<=ClickTarget.tapRadius(px)then gap else nil
 end
 local best,bestGap=nil,math.huge
 for player,entry in pairs(self.options.companions.active)do
  local distance=self:reach(entry,root.Position)
  if distance and distance<=Rules.InspectRange then
   local gap=measure(entry.visual)
   if gap and gap<bestGap then best,bestGap=player,gap end
  end
 end
 local own=self.options.ownPet and self.options.ownPet()
 if best and own and not own.destroyed then
  local gap=measure(own)
  if gap and gap<=bestGap then return nil end
 end
 return best
end
-- Identity of the pet behind a card: any change closes it.
function Inspect:identity(player)
 local entry=self.options.companions.active[player]
 local board=entry and entry.board
 if not entry or not board then return nil end
 local character=entry.root and entry.root.Parent
 return {player=player,ownerId=player.UserId,petId=entry.pet.id,pet=entry.pet,board=board,
  petGeneration=board:GetAttribute("CompanionGeneration")or 0,characterId=character and character:GetAttribute("GardenCharacterId")or 0}
end
local function deviceKey()
 local last=UserInputService:GetLastInputType()
 if last==Enum.UserInputType.Touch then return nil end
 if last.Name:sub(1,7)=="Gamepad"then return "X"end
 return "E"
end
function Inspect:setCandidate(player)
 if self.candidate==player then return end
 self.candidate=player
 if self.prompt then self.prompt:Destroy();self.prompt=nil end
 local entry=player and self.options.companions.active[player]
 local body=entry and entry.visual.model and entry.visual.model.PrimaryPart
 if not body then self.chip.Enabled=false;self.chip.Adornee=nil;return end
 -- A custom-style prompt gives E / X and the engine's own one-prompt-per-key choice:
 -- the owner's pet and the stations keep E whenever they are the nearer prompt.
 local prompt=Instance.new("ProximityPrompt")
 prompt.Name="PetInspectPrompt";prompt.ActionText=UICopy.get("inspect.prompt");prompt.ObjectText=entry.pet.name
 prompt.Style=Enum.ProximityPromptStyle.Custom
 prompt.KeyboardKeyCode,prompt.GamepadKeyCode=Enum.KeyCode.E,Enum.KeyCode.ButtonX
 prompt.ClickablePrompt,prompt.RequiresLineOfSight,prompt.HoldDuration=true,false,0
 prompt.MaxActivationDistance=Rules.InspectRange
 prompt.Parent=body
 prompt.PromptShown:Connect(function()if self.prompt==prompt then self.promptShown=true end end)
 prompt.PromptHidden:Connect(function()if self.prompt==prompt then self.promptShown=false end end)
 prompt.Triggered:Connect(function(who)
  if(who==nil or who==Players.LocalPlayer)and self.prompt==prompt and self.candidate==player and self:allowed()then self:open(player)end
 end)
 self.prompt,self.promptShown=prompt,false
 self.chip.Adornee=body
end

function Inspect:build(identity)
 local camera=workspace.CurrentCamera
 local view=camera and camera.ViewportSize or Vector2.new(1280,720)
 local g=Inspect.geometry(view.X,view.Y,Levels.on("medals"))
 local card=Kit.frame(self.root,"InspectCard","panel",nil,UDim2.fromOffset(g.W,g.H),14)
 card.AnchorPoint=Vector2.new(.5,0);card.Active=true;Kit.stroke(card)
 -- Phones: under the top bar, centred, clear of the thumbstick and jump corners.
 -- Desktop: the right side, so the pet itself stays in view.
 card.Position=if g.compact then UDim2.new(.5,0,0,6)else UDim2.new(1,-g.W/2-24,.5,-g.H/2)
 local well=Kit.well(card,"Preview",UDim2.fromOffset(g.pad,g.pad),UDim2.fromOffset(g.preview,g.H-g.pad*2),12)
 well.ClipsDescendants=true;Kit.stage(well) -- Toy Shell R1.2.5: the pet on the berry stage
 local viewport=Instance.new("ViewportFrame")
 viewport.Name="PetViewport";viewport.BackgroundTransparency=1;viewport.BorderSizePixel=0;viewport.Size=UDim2.fromScale(1,1)
 Kit.petLight(viewport)
 viewport.ZIndex=well.ZIndex+1;viewport.Active=true;viewport.Parent=well
 local world=Instance.new("WorldModel");world.Parent=viewport
 local lens=Instance.new("Camera");lens.FieldOfView=30;lens.Parent=viewport;viewport.CurrentCamera=lens
 local hint=Kit.text(well,"Small",UICopy.get("inspect.spin"),"dim",{Name="SpinHint",Size=UDim2.new(1,0,0,16),Position=UDim2.new(0,0,1,-20),TextXAlignment=Enum.TextXAlignment.Center,TextSize=12})
 hint.ZIndex=viewport.ZIndex+1
 -- Right column.
 local name=Kit.text(card,"Name",identity.pet.name,"text",{Name="PetName",Position=UDim2.fromOffset(g.x0,g.pad),Size=UDim2.fromOffset(g.rightW-40,g.head),TextSize=if g.compact then 18 else 22,TextTruncate=Enum.TextTruncate.AtEnd})
 Kit.fixedText(name)
 local sub=Kit.text(card,"Small","","soft",{Name="Owner",Position=UDim2.fromOffset(g.x0,g.pad+g.head),Size=UDim2.fromOffset(g.rightW,g.sub),TextSize=if g.compact then 12 else 13,TextTruncate=Enum.TextTruncate.AtEnd})
 Kit.fixedText(sub)
 local close=Instance.new("TextButton")
 close.Name="Close";close.Text="×";close.AutoButtonColor=false;close.AnchorPoint=Vector2.new(1,0)
 close.Position=UDim2.new(1,-g.pad+4,0,g.pad-4);close.Size=UDim2.fromOffset(36,36);close.BackgroundTransparency=1
 close.TextColor3=Kit.Color.soft;close.TextSize=24;close.FontFace=Kit.Type.Strong[3];close.ZIndex=card.ZIndex+3;close.AutoLocalize=false;close.Parent=card
 close:SetAttribute("AccessibleLabel",UICopy.get("inspect.close"))
 close.Activated:Connect(function()self:close("button")end)
 local grid=Kit.frame(card,"Slots",nil,UDim2.fromOffset(g.x0,g.gridY),UDim2.fromOffset(g.rightW,g.gridH))
 grid.Visible=false
 local cellW=math.floor((g.rightW-(Inspect.Columns-1)*g.gap)/Inspect.Columns)
 local cells={}
 for index,row in ipairs(Inspect.rows(identity.petId,nil))do
  local col,line=(index-1)%Inspect.Columns,math.floor((index-1)/Inspect.Columns)
  local cell=Kit.frame(grid,"Slot_"..row.key,"well",UDim2.fromOffset(col*(cellW+g.gap),line*(g.rowH+g.gap)),UDim2.fromOffset(cellW,g.rowH),8)
  local half=math.floor((g.rowH-4)/2)
  local size=if g.compact then 11 else 12
  local label=Kit.text(cell,"Small",row.label,"dim",{Name="Slot",Position=UDim2.fromOffset(6,2),Size=UDim2.fromOffset(cellW-10,half),TextSize=size,TextTruncate=Enum.TextTruncate.AtEnd})
  local value=Kit.text(cell,"Strong","","text",{Name="Item",Position=UDim2.fromOffset(6,2+half),Size=UDim2.fromOffset(cellW-10,half),TextSize=size,TextTruncate=Enum.TextTruncate.AtEnd})
  cells[row.key]={cell=cell,label=label,value=value}
 end
 local stats=self:buildStats(card,g)
 local tabs=Kit.tabs(card,{UICopy.get("inspect.tab.stats"),UICopy.get("inspect.tab.outfit")},g.rightW,g.tabsH,if g.compact then 14 else 16)
 tabs.root.Name="InspectTabs";tabs.root.Position=UDim2.fromOffset(g.x0,g.tabsY)
 tabs.changed=function(index)self:showTab(index)end
 local buttonY=g.gridY+g.bodyH+8
 local hello=Kit.button(card,"SayHello",{variant="primary",text=UICopy.get("inspect.hello"),size=Vector2.new(g.rightW-g.compareW-6,g.button),textSize=if g.compact then 16 else 18})
 hello.Position=UDim2.fromOffset(g.x0,buttonY)
 hello.Activated:Connect(function()self:hello()end)
 local compare=Kit.button(card,"Compare",{variant="secondary",text=UICopy.get("inspect.compare"),size=Vector2.new(g.compareW,g.button),textSize=if g.compact then 15 else 17})
 compare.Position=UDim2.fromOffset(g.x0+g.rightW-g.compareW,buttonY)
 compare.Activated:Connect(function()self:toggleCompare()end)
 -- Spin: drag on the preview (mouse or touch); the thumbstick turns it too.
 local drag=nil
 viewport.InputBegan:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then drag={input=input,x=input.Position.X}end
 end)
 local moved=UserInputService.InputChanged:Connect(function(input)
  if not drag then return end
  if input.UserInputType==Enum.UserInputType.MouseMovement or input==drag.input then
   self.spin+=(input.Position.X-drag.x)*Inspect.SpinPerPixel;drag.x=input.Position.X;hint.Visible=false
  end
 end)
 local ended=UserInputService.InputEnded:Connect(function(input)
  if drag and(input==drag.input or input.UserInputType==Enum.UserInputType.MouseButton1)then drag=nil end
 end)
 local built={frame=card,geometry=g,viewport=viewport,world=world,lens=lens,name=name,sub=sub,cells=cells,grid=grid,stats=stats,tabs=tabs,tab=1,
  hello=hello,compareButton=compare,compare=false,hint=hint,inputs={moved,ended}}
 Inspect.wireSelection(built)
 return built
end
-- Gamepad: the tabs above, Say hello and Compare below. A disabled Kit button is not
-- interactable (Roblox would skip it and could leave the card), so the links follow what is
-- enabled, and a selection left on a disabled button moves to the Stats tab.
function Inspect.wireSelection(card)
 local tab1,tab2=card.tabs.buttons[1],card.tabs.buttons[2]
 local hello,compare=card.hello,card.compareButton
 local function on(button)local state=Kit.buttonState(button);return state==nil or state.enabled end
 local helloOn,compareOn=on(hello),on(compare)
 tab1.NextSelectionUp,tab1.NextSelectionLeft,tab1.NextSelectionRight=tab1,tab1,tab2
 tab1.NextSelectionDown=if helloOn then hello elseif compareOn then compare else tab1
 tab2.NextSelectionUp,tab2.NextSelectionLeft,tab2.NextSelectionRight=tab2,tab1,tab2
 tab2.NextSelectionDown=if compareOn then compare elseif helloOn then hello else tab2
 hello.NextSelectionUp,hello.NextSelectionDown,hello.NextSelectionLeft=tab1,hello,hello
 hello.NextSelectionRight=if compareOn then compare else hello
 compare.NextSelectionUp,compare.NextSelectionDown,compare.NextSelectionRight=tab2,compare,compare
 compare.NextSelectionLeft=if helloOn then hello else compare
 local selected=GuiService.SelectedObject
 if(selected==hello and not helloOn)or(selected==compare and not compareOn)then GuiService.SelectedObject=tab1 end
end
-- v2 S4: the Stats tab. Six tiles (stat icon chip, name, level, tier word or "You 41"), the summary
-- strip (total level / 594, You, Keeper chip), the privacy line, and a line for no stats.
function Inspect:buildStats(card,g)
 local compact=g.compact
 local pane=Kit.frame(card,"StatsPane",nil,UDim2.fromOffset(g.x0,g.gridY),UDim2.fromOffset(g.rightW,g.statsH))
 local tileW=math.floor((g.rightW-(Inspect.Columns-1)*g.gap)/Inspect.Columns)
 local iconSize=if compact then 18 else 22
 local levelH=if compact then 20 else 26
 local levelW=if compact then 28 else 36
 local tiles={}
 for index,id in ipairs(StatCatalog.Order)do
  local col,line=(index-1)%Inspect.Columns,math.floor((index-1)/Inspect.Columns)
  local tile=Kit.frame(pane,"Stat_"..id,"well",UDim2.fromOffset(col*(tileW+g.gap),line*(g.tileH+g.gap)),UDim2.fromOffset(tileW,g.tileH),10)
  Kit.stroke(tile)
  local icon=StatsPanel.icon(tile,id,iconSize);icon.Position=UDim2.fromOffset(5,4)
  Kit.text(tile,"Label",StatsPanel.statName(id),"soft",{Name="StatName",Position=UDim2.fromOffset(5+iconSize+4,4),Size=UDim2.fromOffset(tileW-iconSize-14,iconSize),
   TextSize=if compact then 10 else 12,TextTruncate=Enum.TextTruncate.AtEnd})
  local y=g.tileH-levelH-3
  local level=Kit.text(tile,"CounterL","1","text",{Name="Level",Position=UDim2.fromOffset(6,y),Size=UDim2.fromOffset(levelW,levelH),TextSize=if compact then 20 else 26})
  local tier=Kit.text(tile,"Label","",StatCatalog.ById[id].color,{Name="Tier",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-5,0,y+(if compact then 3 else 4)),
   Size=UDim2.fromOffset(tileW-levelW-12,levelH-(if compact then 4 else 6)),TextXAlignment=Enum.TextXAlignment.Right,TextSize=if compact then 9 else 11,TextTruncate=Enum.TextTruncate.AtEnd})
  tiles[index]={id=id,tile=tile,level=level,tier=tier}
 end
 local stripY=g.tileH*2+g.gap*2
 local strip=Kit.frame(pane,"Summary","well",UDim2.fromOffset(0,stripY),UDim2.fromOffset(g.rightW,g.stripH),10)
 Kit.stroke(strip)
 Kit.text(strip,"Label",UICopy.get("stats.total"),"dim",{Name="TotalLabel",Position=UDim2.fromOffset(8,2),Size=UDim2.fromOffset(140,if compact then 11 else 14),TextSize=if compact then 9 else 11})
 local totalH=if compact then 17 else 22
 local total=Kit.text(strip,"CounterL","","text",{Name="TotalLevel",Position=UDim2.fromOffset(8,g.stripH-totalH-1),Size=UDim2.fromOffset(40,totalH),TextSize=if compact then 16 else 21})
 local of=Kit.text(strip,"Counter","","dim",{Name="TotalOf",Position=UDim2.fromOffset(48,g.stripH-totalH-1),Size=UDim2.fromOffset(44,totalH),TextSize=if compact then 11 else 13})
 local you=Kit.text(strip,"Label","","soft",{Name="TotalYou",Position=UDim2.fromOffset(92,g.stripH-totalH-1),Size=UDim2.fromOffset(70,totalH),TextSize=if compact then 9 else 11})
 local chip=Kit.chip(strip,"",nil,if compact then 20 else 24)
 chip.root.Name="KeeperChip";chip.root.AnchorPoint=Vector2.new(1,.5);chip.root.Position=UDim2.new(1,-6,.5,0)
 -- S4: Marks, six medals (one a stat, dark until earned).
 local marks
 local noteY=stripY+g.stripH+2
 if g.marks then
  local row,rowW,rowH,pitch
  if g.marksH>0 then
   rowW,rowH=g.rightW,g.marksH
   row=Kit.frame(pane,"Marks","well",UDim2.fromOffset(0,stripY+g.stripH+g.gap),UDim2.fromOffset(rowW,rowH),10)
   Kit.stroke(row)
   pitch=math.min(rowH+8,math.floor((rowW-74)/6))
   Kit.text(row,"Label",UICopy.get("inspect.marks"),"dim",{Name="MarksLabel",Position=UDim2.fromOffset(8,0),Size=UDim2.fromOffset(rowW-pitch*6-18,rowH),TextSize=11,TextTruncate=Enum.TextTruncate.AtEnd})
   noteY+=rowH+g.gap
  else
   pitch=24;rowW,rowH=pitch*6+6,g.stripH
   row=Kit.frame(strip,"Marks",nil,UDim2.fromOffset(g.rightW-rowW-2,0),UDim2.fromOffset(rowW,rowH))
  end
  row:SetAttribute("AccessibleLabel",UICopy.get("inspect.marks"))
  marks={row=row,slots={},inStrip=g.marksH==0}
  for index,id in ipairs(StatCatalog.Order)do
   local medal=MedalView.new(row,math.min(rowH-2,pitch+6))
   medal.root.Name="Mark_"..id;medal.root.AnchorPoint=Vector2.new(.5,.5)
   medal.root.Position=UDim2.fromOffset(rowW-4-math.floor((6-index+.5)*pitch),math.floor(rowH/2))
   marks.slots[index]=medal
  end
 end
 local note=Kit.text(pane,"Small",UICopy.get("inspect.statsPrivate"),"dim",{Name="Private",Position=UDim2.fromOffset(0,noteY),Size=UDim2.fromOffset(g.rightW,g.noteH),
  TextSize=if compact then 10 else 12,TextXAlignment=Enum.TextXAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd})
 local none=Kit.text(pane,"Small",UICopy.get("inspect.statsNone"),"soft",{Name="None",Position=UDim2.new(),Size=UDim2.fromOffset(g.rightW,g.tileH*2+g.gap),
  TextSize=if compact then 13 else 15,TextXAlignment=Enum.TextXAlignment.Center,Visible=false})
 return {pane=pane,tiles=tiles,strip=strip,total=total,of=of,you=you,chip=chip,note=note,none=none,marks=marks}
end
-- S4: from 75 the card's edge is trimmed in the stat's colour (the highest one). Made when first needed.
function Inspect:paintTrim(stat)
 local card=self.card
 if not stat and not card.trim then return end
 if not card.trim then
  local trim=Kit.frame(card.frame,"MedalTrim",nil,UDim2.fromOffset(4,4),UDim2.new(1,-8,1,-8),11)
  trim.ZIndex=card.frame.ZIndex+1
  card.trim=trim;card.trimStroke=Kit.node("UIStroke",trim,{Name="Trim",Thickness=3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 end
 card.trim.Visible=stat~=nil
 if stat then card.trimStroke.Color=StatCatalog.ById[stat].color end
 card.frame:SetAttribute("TrimStat",stat)
end
-- The local player's own board (for Compare), or nil.
function Inspect:ownBoard()
 local boards=self.options.companions and self.options.companions.boards
 return boards and boards:FindFirstChild(tostring(Players.LocalPlayer.UserId))or nil
end
function Inspect:showTab(index)
 local card=self.card;if not card then return end
 card.tab=index
 card.stats.pane.Visible=index==1
 card.grid.Visible=index==2
 if card.tabs.selected~=index then card.tabs.select(index)end
end
function Inspect:toggleCompare()
 local card=self.card;if not card or not card.compareReady then return false end
 card.compare=not card.compare
 Kit.setSelected(card.compareButton,card.compare)
 if card.compare then self:showTab(1)end
 card.statsSeen=nil;self:paintStats()
 return card.compare
end
-- Paint the Stats tab when the public attribute (theirs or ours) or Compare changes.
function Inspect:paintStats()
 local card=self.card;if not card then return end
 local board=card.identity.board
 local raw=board:GetAttribute(StatCatalog.PublicAttribute)
 local own=self:ownBoard()
 local ownRaw=own and own:GetAttribute(StatCatalog.PublicAttribute)
 local ownId=own and own:GetAttribute("CompanionId")
 -- Once a frame from refresh: compare the four inputs as they are (no string building).
 local seen=card.statsSeen
 local medalsOn=Levels.on("medals")
 if seen and seen[1]==raw and seen[2]==ownRaw and seen[3]==ownId and seen[4]==card.compare and seen[5]==medalsOn then return end
 card.statsSeen={raw,ownRaw,ownId,card.compare,medalsOn}
 local view=card.stats
 local model=Inspect.statsModel(raw,card.identity.petId)
 local mine=Inspect.statsModel(ownRaw,ownId)
 card.compareReady=model~=nil and mine~=nil
 if not card.compareReady and card.compare then card.compare=false;Kit.setSelected(card.compareButton,false)end
 Kit.setEnabled(card.compareButton,card.compareReady)
 Inspect.wireSelection(card)
 local compare=card.compare
 view.none.Visible=model==nil
 view.strip.Visible=model~=nil
 for index,t in ipairs(view.tiles)do
  t.tile.Visible=model~=nil
  local s=model and model.stats[index]
  if s then
   t.level.Text=tostring(s.level)
   local yours=if compare then UICopy.get("inspect.you",{count=mine.stats[index].level})else nil
   if yours then
    t.tier.Text=yours;Kit.paint(t.tier,"TextColor3","soft")
   else
    t.tier.Text=string.upper(s.tier);Kit.paint(t.tier,"TextColor3",StatCatalog.ById[s.id].color)
   end
   local label=string.format("%s %d",StatsPanel.statName(s.id),s.level)
   if yours then label..=", "..yours end
   t.tile:SetAttribute("AccessibleLabel",label);t.tile:SetAttribute("Level",s.level)
  end
 end
 if model then
  view.total.Text=tostring(model.total)
  local tw=math.ceil(Kit.measure(view.total.Text,"CounterL",view.total.TextSize).X)
  view.of.Text=UICopy.get("stats.of",{total=StatCatalog.GardenStarTotal})
  view.of.Position=UDim2.fromOffset(8+tw+4,view.total.Position.Y.Offset)
  local ow=math.ceil(Kit.measure(view.of.Text,"Counter",view.of.TextSize).X)
  view.you.Text=if compare then UICopy.get("inspect.you",{count=mine.total})else ""
  view.you.Position=UDim2.fromOffset(8+tw+4+ow+8,view.total.Position.Y.Offset)
  view.chip.set(model.keeper,nil);Kit.paint(view.chip.label,"TextColor3","accent")
  view.chip.root.Visible=StatsPanel.ShowKeeper -- round 3: the Keeper title is hidden for now
  view.pane:SetAttribute("TotalLevel",model.total)
 end
 local levels=if model and medalsOn then StatsPanel.levelsOf(model)else nil
 if view.marks then
  view.marks.row.Visible=levels~=nil
  -- Phones: the "You" total stops before the medals.
  if view.marks.inStrip then view.you.TextTruncate=Enum.TextTruncate.AtEnd;view.you.Size=UDim2.new(0,math.clamp(view.marks.row.Position.X.Offset-view.you.Position.X.Offset-2,20,70),0,view.you.Size.Y.Offset)end
  if levels then for index,medal in ipairs(view.marks.slots)do medal.set(StatCatalog.Order[index],Medals.count(levels[StatCatalog.Order[index]]))end end
 end
 self:paintTrim(levels and MedalView.trimStat(levels)or nil)
 if not model then view.pane:SetAttribute("TotalLevel",nil)end
 view.pane:SetAttribute("Compare",compare)
end
-- v859 phone notes: "Drag to turn" made the pet drift away. The fit re-ran whenever the
-- animated height moved a hundredth, and the axis-aligned width of a turned pet grows up to
-- ~1.4x at 45 degrees, so each refit mid-spin zoomed out. The orbit is now fixed: measured
-- once per rig (and on a real height change past FitSlack), on the spin axis (x=z=0).
Inspect.FitSlack=.15
function Inspect:fitCamera()
 local card=self.card;local v=card and card.visual
 if not v or v.destroyed then return end
 local box,size=Bounds.get(v)
 local rig=v.rigRevision or 0
 local fit=card.fit
 if card.cameraKey==rig and fit and math.abs(size.Y-fit.height)<=fit.height*Inspect.FitSlack then return end
 if card.cameraKey~=rig or not fit then
  -- Width from the unturned pose when the card is fresh; a rig change mid-spin keeps the old
  -- width unless the new one is clearly wider (never a zoom-out from the turn itself).
  local wide=math.max(size.X,size.Z)
  if fit and math.abs(self.spin or 0)%(math.pi/2)>.05 then wide=math.max(fit.wide,wide/math.sqrt(2))end
  fit={wide=wide}
 end
 card.cameraKey=rig;card.fit=fit
 fit.height,fit.centre=size.Y,box.Position.Y
 local half=math.tan(math.rad(card.lens.FieldOfView/2))
 local aspect=card.viewport.AbsoluteSize.X/math.max(1,card.viewport.AbsoluteSize.Y)
 -- Fit the widest turn of the pet (it spins), then the height.
 local wide=fit.wide
 local distance=math.max(size.Y*.5/half,wide*.5/(half*math.max(.2,aspect)))+wide*.5+.3
 card.lens.CFrame=CFrame.lookAt(Vector3.new(0,fit.centre+size.Y*.06,distance*1.08),Vector3.new(0,fit.centre,0))
end
function Inspect:refresh()
 local card=self.card;if not card then return end
 local identity=card.identity;local board=identity.board
 local appearance=self.options.garden:appearance(board,identity.petId)
 local key=tostring(board:GetAttribute("PetAppearance")).."|"..tostring(board:GetAttribute("PetAppearanceRevision"))
 if card.appearanceKey~=key then
  card.appearanceKey=key
  if card.visual and card.visual.applyAppearance then card.visual:applyAppearance(appearance)end
  for _,row in ipairs(Inspect.rows(identity.petId,appearance))do
   local cell=card.cells[row.key]
   if cell then
    cell.value.Text=row.value
    cell.value.TextColor3=if row.empty then Kit.Color.dim else Kit.Color.text
    cell.cell.BackgroundTransparency=if row.empty then .55 else 0
   end
  end
  card.cameraKey=nil
 end
 local player=identity.player
 local owner=if player.DisplayName~=player.Name then player.DisplayName.." @"..player.Name else "@"..player.Name
 local level=board:GetAttribute(Rules.BondAttribute)
 local line=UICopy.get("inspect.owner",{name=owner})
 -- v2 pet names: "Biscuit Sprout" / "Bear · @owner's pet" (ids from the board, text from NameCatalog).
 local NameText=require(script.Parent.PetNameText)
 local display,named=NameText.ofBoard(board,identity.petId)
 if card.name.Text~=display then card.name.Text=display end
 card.frame:SetAttribute("PetName",display)
 if named then line=NameText.species(identity.petId).." · "..line end
 if type(level)=="number"then line=line.." · "..UICopy.get("inspect.bond",{count=level})end
 if card.sub.Text~=line then card.sub.Text=line end
 self:paintStats()
end
function Inspect:open(player)
 if self.destroyed or not self:allowed()then return false end
 if self.card then
  if self.card.identity.player==player then return true end
  self:close("replace")
 end
 local identity=self:identity(player)
 local root=localRoot()
 local entry=self.options.companions.active[player]
 if not identity or not root or not entry then return false end
 local distance=self:reach(entry,root.Position)
 if not distance or distance>Rules.InspectRange then return false end
 local card=self:build(identity)
 card.identity=identity
 card.freeMemo={};self.card=card;self.spin=0
 -- A read-only local clone in the card's own viewport: the published appearance only.
 local appearance=self.options.garden:appearance(identity.board,identity.petId)
 local create=self.options.createPreview or require(script.Parent.PetFactory).new
 local ok,visual=pcall(create,card.world,Vector3.zero,identity.pet,nil,appearance)
 if ok and visual then
  card.visual=visual;visual.cosmeticSeed=identity.ownerId;visual.yaw=0
  visual.holdToyAlways=true -- the card shows the toy in the pet's hand (R8)
  visual.model:SetAttribute("InspectPreview",true)
 end
 self:refresh();self:fitCamera()
 ContextActionService:BindActionAtPriority(Inspect.Action,function(_,state,input)
  if state~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
  -- Escape also opens the Roblox menu, which closes the card by itself.
  self:close("back")
  return if input.KeyCode==Enum.KeyCode.Escape then Enum.ContextActionResult.Pass else Enum.ContextActionResult.Sink
 end,false,3000,Enum.KeyCode.ButtonB,Enum.KeyCode.Backspace,Enum.KeyCode.Escape)
 if UserInputService:GetLastInputType().Name:sub(1,7)=="Gamepad"then
  card.priorSelection=GuiService.SelectedObject;GuiService.SelectedObject=card.hello
 end
 self.chip.Enabled=false
 if self.options.onOpen then self.options.onOpen(identity)end
 return true
end
function Inspect:isOpen()return self.card~=nil end
function Inspect:close(reason)
 local card=self.card;if not card then return false end
 self.card=nil
 ContextActionService:UnbindAction(Inspect.Action)
 for _,connection in ipairs(card.inputs)do connection:Disconnect()end
 if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(card.frame)then
  GuiService.SelectedObject=if card.priorSelection and card.priorSelection.Parent then card.priorSelection else nil
 end
 if card.visual and not card.visual.destroyed then pcall(function()card.visual:destroy()end)end
 card.frame:Destroy()
 if self.options.onClose then self.options.onClose(reason)end
 return true
end
-- The target went away or changed: say so briefly, then close. Nothing stays interactive.
function Inspect:gone()
 local card=self.card
 if not card or card.goneAt then return end
 card.goneAt=os.clock()
 card.name.Text=UICopy.get("inspect.gone")
 Kit.setEnabled(card.hello,false);Kit.setEnabled(card.compareButton,false)
 for _,button in ipairs(card.tabs.buttons)do button.Active=false;button.Interactable=false end
 Inspect.wireSelection(card)
end
function Inspect:hello()
 local card=self.card
 if not card or card.goneAt or not self.remote or not card.helloReady then return false end
 local identity=card.identity
 self.seq+=1
 card.pendingSeq=self.seq;card.pendingAt=os.clock()
 self.remote:FireServer({seq=self.seq,ownerId=identity.ownerId,petId=identity.petId,characterId=identity.characterId,petGeneration=identity.petGeneration})
 return true
end
function Inspect:onReply(result)
 local card=self.card
 if type(result)~="table"or not card or result.seq~=card.pendingSeq then return end
 card.pendingSeq=nil
 local now=os.clock()
 if result.status=="Accepted"then
  card.sentUntil=now+Rules.Duration;card.coolUntil=now+Rules.PairCooldown
 elseif result.reason=="Cooldown"then
  card.coolUntil=now+(if type(result.retryIn)=="number"then math.clamp(result.retryIn,0,Rules.PairCooldown)else Rules.ViewerCooldown)
 elseif result.reason=="Stale"then self:gone()
 elseif result.reason=="Off"then card.offUntil=now+2
 else card.busyUntil=now+1.5 end
end
-- Once a frame from RoomView (Room mode). `serverNow` times the preview's hello wave.
function Inspect:step(dt,serverNow)
 if self.destroyed then return end
 local allowed=self:allowed()
 local card=self.card
 if card then
  local now=os.clock()
  if card.goneAt then
   if now-card.goneAt>=Inspect.GoneHold then self:close("gone")end
  elseif not allowed then self:close("covered")
  else
   local identity=card.identity
   local current=self:identity(identity.player)
   local entry=self.options.companions.active[identity.player]
   local root=localRoot()
   local distance=entry and root and self:reach(entry,root.Position)
   if not current or current.petId~=identity.petId or current.petGeneration~=identity.petGeneration or current.characterId~=identity.characterId or not distance then self:gone()
   elseif distance>Rules.InspectLeave then self:close("far")
   else
    self:refresh()
    local board=identity.board
    local actor=self.options.garden:get(identity.ownerId,identity.petId,entry.root.Parent)
    local key,ready=Inspect.helloState({off=board:GetAttribute(Rules.OffAttribute)==true or now<(card.offUntil or 0),sent=now<(card.sentUntil or 0),
     cooling=now<(card.coolUntil or 0)or(card.pendingSeq~=nil and now-(card.pendingAt or 0)<2),distance=distance,
     free=Inspect.stableFree(card.freeMemo,actor~=nil and Rules.free(actor,serverNow),now)and now>=(card.busyUntil or 0)})
    if card.helloKey~=key then card.helloKey=key;Kit.setText(card.hello,UICopy.get(key))end
    if card.helloReady~=ready then card.helloReady=ready;Kit.setEnabled(card.hello,ready);Inspect.wireSelection(card)end
    -- The preview mirrors the real pet's hello.
    if card.visual then card.visual.hello=entry.visual.hello;card.visual.helloTarget=Vector3.new(0,0,6)end
   end
  end
  card=self.card
  if card and card.visual and not card.visual.destroyed then
   local v=card.visual
   local stick=0
   for _,input in ipairs(UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1))do
    if input.KeyCode==Enum.KeyCode.Thumbstick2 and math.abs(input.Position.X)>.2 then stick=input.Position.X end
   end
   self.spin+=stick*dt*2.4
   v.reducedEffects=self.options.reduce and self.options.reduce()==true
   v.yaw=self.spin;v.cosmeticTime=serverNow;v.poseDirty=true;v:update(dt)
   self:fitCamera()
  end
 end
 -- The quiet prompt, only with no card up.
 local candidate=if allowed and not self.card then self:nearest()else nil
 self:setCandidate(candidate)
 local show=candidate~=nil and self.promptShown==true
 local keyName=deviceKey()
 if show then
  if self.chipKeyName~=keyName then
   self.chipKeyName=keyName
   self.chipKey.Visible=keyName~=nil;self.chipKey.Text=keyName or ""
   self.chipWord.Position=UDim2.fromOffset(if keyName then 30 else 0,0);self.chipWord.Size=UDim2.new(1,if keyName then -34 else 0,1,0)
   self.chipWord.TextXAlignment=if keyName then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
  end
 end
 if self.chip.Enabled~=show then self.chip.Enabled=show end
end
function Inspect:destroy()
 if self.destroyed then return end
 self:close("destroy");self.destroyed=true
 self:setCandidate(nil)
 for _,connection in ipairs(self.connections)do connection:Disconnect()end
 table.clear(self.connections)
 self.chip:Destroy();self.gui:Destroy()
end
return Inspect
