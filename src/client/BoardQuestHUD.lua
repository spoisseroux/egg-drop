local Art=require(script.Parent.DeckArt)
local Copy=require(script.Parent.FieldQuestText)
local Quest={};Quest.__index=Quest
local function snapshot(stage,objective)return if objective==nil then Copy.legacy(stage)elseif objective==false then nil else objective end
local function choices(copy,includeDynamics,includeOrdinal)
 local result={}
 local function add(prefix)
  if includeOrdinal and copy.step then for _,caption in ipairs(copy.candidates)do table.insert(result,prefix..math.min(copy.step,2).."/2 "..caption)end end
  for _,caption in ipairs(copy.candidates)do table.insert(result,prefix..caption)end
 end
 if includeDynamics and copy.dynamics~=""then
  local short=copy.dynamics:match("^%S+")or copy.dynamics
  add(copy.dynamics.." · ");add(short.." · ")
 end
 add("");return result
end
function Quest.new(parent)
 local host=Art.frame(parent,"ActiveQuest",Art.Ink,UDim2.fromScale(0,0),UDim2.fromScale(1,1),parent.ZIndex+3)
 host.ClipsDescendants=true;host.BackgroundTransparency=1;Art.corner(host,8)
 local title=Art.text(host,"Instruction","Match on LEFT",UDim2.fromOffset(4,1),UDim2.new(1,-8,0,21),Art.Silver,14)
 local progress=Art.text(host,"Steps","1 ○   2 ○",UDim2.fromOffset(4,25),UDim2.new(1,-8,0,18),Art.Muted,12)
 local dynamics=Art.text(host,"Dynamics","",UDim2.fromOffset(4,45),UDim2.new(1,-8,0,18),Art.Muted,12)
 Art.type(title,"Body");Art.type(progress,"Supporting",true);Art.type(dynamics,"Supporting",true)
 local self=setmetatable({host=host,title=title,progress=progress,dynamics=dynamics},Quest)
 host:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:update(self.stage or 0,self.phase,self.visible,nil,self.objective)end)
 return self
end
function Quest:preferredHeight(width,available,compact,objective)
 local view=snapshot(0,objective);local copy=Copy.describe(view);local service=game:GetService("TextService")
 local size=if compact then 12 else 16;local h=0
 local samples={copy}
 if view and view.goals then
  for _,goal in ipairs(view.goals)do
   local full,short=Copy.goal(goal,0);local alternatives={full};for _,caption in ipairs(short)do table.insert(alternatives,caption)end
   table.insert(samples,{candidates=alternatives,dynamics=copy.dynamics})
  end
 end
 for _,sample in ipairs(samples)do
  local smallest=math.huge
  for _,caption in ipairs(choices(sample,compact))do
   local bounds=service:GetTextSize(caption,size,Enum.Font.Gotham,Vector2.new(math.max(1,width-8),10000));smallest=math.min(smallest,math.ceil(bounds.Y)+4)
  end
  h=math.max(h,smallest)
 end
 if not compact then
  h+=math.ceil(service:GetTextSize(copy.ticker,12,Enum.Font.Gotham,Vector2.new(math.max(1,width-8),10000)).Y)+10
  if copy.dynamics~=""then h+=math.ceil(service:GetTextSize(copy.dynamics,12,Enum.Font.Gotham,Vector2.new(math.max(1,width-8),10000)).Y)+7 end
 end
 return math.min(available,math.max(20,h))
end
function Quest:update(stage,phase,visible,compactHint,objective)
 if compactHint~=nil then self.compactHint=compactHint end
 self.stage,self.phase,self.visible,self.objective=stage,phase,visible,objective
 self.host.Visible=visible==true
 local height,width=self.host.AbsoluteSize.Y,self.host.AbsoluteSize.X
 local compact=if self.compactHint~=nil then self.compactHint else height<60
 local copy=Copy.describe(snapshot(stage,objective),phase)
 local key=table.concat({stage,phase or "",copy.key,tostring(compact),height,width,game:GetService("GuiService").PreferredTextSize.Name},"|")
 if self.layoutKey==key then return end;self.layoutKey=key
 Art.type(self.title,"Body",compact);if compact then self.title.TextSize=12 end
 self.title.TextWrapped=true
 Art.type(self.progress,"Supporting",true);Art.type(self.dynamics,"Supporting",true)
 local inner=math.max(1,width-8)
 self.progress.Text=copy.ticker;self.dynamics.Text=copy.dynamics
 local line=math.max(22,math.ceil(game:GetService("TextService"):GetTextSize("M",self.title.TextSize,self.title.Font,Vector2.new(10000,10000)).Y)+4)
 local progressH=Art.textHeight(self.progress,inner,18);local dynamicsH=Art.textHeight(self.dynamics,inner,18)
 local progressVisible=not compact and copy.ticker~=""and height>=line+progressH+10
 local dynamicsVisible=not compact and copy.dynamics~=""and progressVisible and height>=line+progressH+dynamicsH+13
 local top=if compact then 0 else 4
 local titleH=math.max(1,height-top-(if compact then 0 else 3)-(if progressVisible then progressH+3 else 0)-(if dynamicsVisible then dynamicsH+3 else 0))
 local candidates=choices(copy,not dynamicsVisible,not progressVisible)
 local selected=candidates[#candidates]
 for _,caption in ipairs(candidates)do
  self.title.Text=caption
  local bounds=game:GetService("TextService"):GetTextSize(caption,self.title.TextSize,self.title.Font,Vector2.new(inner,10000))
  if bounds.X<=inner and bounds.Y+2<=titleH then selected=caption;break end
 end
 self.title.Text=selected;self.title:SetAttribute("AccessibleLabel",copy.title.." · "..copy.instruction..(if copy.dynamics~=""then " · "..copy.dynamics else ""))
 self.title.Position,self.title.Size=UDim2.fromOffset(4,top),UDim2.new(1,-8,0,titleH)
 self.progress.Visible,self.dynamics.Visible=progressVisible,dynamicsVisible
 self.progress.Position,self.progress.Size=UDim2.fromOffset(4,top+titleH+3),UDim2.new(1,-8,0,progressH)
 self.dynamics.Position,self.dynamics.Size=UDim2.fromOffset(4,top+titleH+3+progressH+3),UDim2.new(1,-8,0,dynamicsH)
end
return Quest
