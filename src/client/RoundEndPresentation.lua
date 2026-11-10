-- A witnessed run end owns decoration only. No simulation, reward or input writes.
local Art=require(script.Parent.DeckArt)
local Copy=require(script.Parent.FieldQuestText)
local Config=require(game:GetService("ReplicatedStorage").Shared.BoardConfig)
local Palette=require(game:GetService("ReplicatedStorage").Shared.JellyPalette)
local End={};End.__index=End;End.Duration=.65
local function clone(value)
 if type(value)~="table"then return value end
 local result={};for k,v in pairs(value)do result[k]=clone(v)end;return result
end
local function freeze(value)
 if type(value)=="table"then for _,v in pairs(value)do freeze(v)end;table.freeze(value)end;return value
end
function End.snapshotBalls(board,serial)
 local parts={}
 for _,part in ipairs(board:GetChildren())do
  if part:IsA("BasePart")and part:GetAttribute("BoardSerial")==serial and part:GetAttribute("Tier")and part.Transparency<1 then table.insert(parts,part)end
 end
 table.sort(parts,function(a,b)return (a:GetAttribute("EggId")or 0)<(b:GetAttribute("EggId")or 0)end)
 local balls={}
 for _,p in ipairs(parts)do
  local x=.5+p.Position.X/(Config.Width+.8);local y=.5-(p.Position.Y-Config.Height/2)/(Config.Height+.8)
  if x>=0 and x<=1 and y>=0 and y<=1 then
   table.insert(balls,{x=x,y=y,radius=p.Size.X/(Config.Width+.8)/2,color=Palette.resolve(p:GetAttribute("Tier")).body})
   if #balls==6 then break end
  end
 end
 return balls
end
function End.confirmed(board,view)
 local sequence=board:GetAttribute("RunSequence");local stage=board:GetAttribute("FieldFinalStage")
 local success,reason=board:GetAttribute("FieldSuccess"),board:GetAttribute("FieldReason")
 if type(sequence)~="number"or not view or view.empty or not Copy.valid(view,sequence)or board:GetAttribute("FieldPhase")~="Complete"
  or type(stage)~="number"or stage<0 or stage>2 or stage%1~=0 or view.step~=stage+1 or type(success)~="boolean"then return false end
 local expected=if reason=="Overflow"then false elseif reason==view.title.." complete"then true elseif reason==view.title.." incomplete"then false else nil
 return expected~=nil and success==expected and(not success or stage==2)
end
function End.new(board,options)
 return setmetatable({board=board,options=options or {},cache={},seen={},epoch=0,starts=0},End)
end
function End:clearArt()
 if self.layer then self.layer:Destroy();self.layer=nil end
 self.nodes=nil;self.pieces=nil
end
function End:cancel()
 self.epoch+=1;self.active=false;self:clearArt()
end
function End:observe()
 if self.destroyed then return end
 local b=self.board;local serial,sequence=b:GetAttribute("ResetId"),b:GetAttribute("RunSequence")
 local key=tostring(serial)..":"..tostring(sequence)
 if self.key~=key then self:cancel();self.key=key;self.frozen=nil;self.pendingBalls=nil;self.witness=nil end
 local over=b:GetAttribute("RoundOver")==true
 if not over then
  if self.frozen then self:cancel();self.frozen=nil end
  self.pendingBalls=nil
  self.witness=if b:GetAttribute("Mode")=="Board"then key else nil
  return
 end
 if not self.pendingBalls then self.pendingBalls=(self.options.snapshot or End.snapshotBalls)(b,serial)end
 if self.frozen then return self.frozen end
 local view=if self.options.readView then self.options.readView()else Copy.read(b,self.cache)
 if not End.confirmed(b,view)then return end
 self.frozen=freeze({resetId=serial,sequence=sequence,objective=clone(view),stage=b:GetAttribute("FieldFinalStage"),
  success=b:GetAttribute("FieldSuccess"),reason=b:GetAttribute("FieldReason"),balls=clone(self.pendingBalls)})
 local witnessed=self.witness==key and not self.seen[key];self.seen[key]=true
 -- Sequence history stays bounded. A historical over=true never gets an intro.
 self.history=self.history or {};table.insert(self.history,key)
 if #self.history>32 then self.seen[table.remove(self.history,1)]=nil end
 self.active=witnessed and(not self.options.owns or self.options.owns())and not(self.options.reduced and self.options.reduced())
 self.age=if self.active then 0 else End.Duration
 if self.active then self.starts+=1 end
 return self.frozen
end
function End:build(target)
 self:clearArt();self.target=target
 local layer=Art.frame(target,"RoundEndArt",Art.Ink,UDim2.fromScale(0,0),UDim2.fromScale(1,1),target.ZIndex+2)
 layer.BackgroundTransparency=1;layer.ClipsDescendants=true;layer.Active,layer.Selectable=false,false;self.layer=layer
 self.nodes={};self.pieces={}
 for index,ball in ipairs(self.frozen.balls)do
  local node=Art.frame(layer,"FinalBall"..index,ball.color,UDim2.fromScale(0,0),UDim2.fromOffset(1,1),layer.ZIndex+1)
  node.AnchorPoint=Vector2.new(.5,.5);Art.corner(node,100)
  table.insert(self.nodes,{node=node,ball=ball,index=index})
 end
 local count=if self.frozen.success then 12 else 3
 for index=1,count do
  local seed=Art.frame(layer,if index%3==0 then "Ribbon"..index else "Seed"..index,if index%2==0 then Art.Amber else Art.Leaf,UDim2.fromOffset(0,0),UDim2.fromOffset(4,8),layer.ZIndex+2)
  seed.AnchorPoint=Vector2.new(.5,.5);Art.corner(seed,if index%3==0 then 1 else 5);table.insert(self.pieces,seed)
 end
end
function End:paint()
 if not self.layer then return end
 local w,h=self.layer.AbsoluteSize.X,self.layer.AbsoluteSize.Y;local strip=self.target:GetAttribute("RoundEndStrip")==true
 for _,entry in ipairs(self.nodes)do
  local ball,node=entry.ball,entry.node;local delay=(entry.index-1)*.018
  local t=math.clamp((self.age-delay)/(.45-delay),0,1)
  local rise=if self.active then math.sin(t*math.pi)*(18+(entry.index%3)*5)*(if self.frozen.success then 1 else .28)else 0
  local squash=if self.active and t>.78 then math.sin((t-.78)/.22*math.pi)*.12 else 0
  local diameter=if strip then math.min(26,math.max(12,h*.44))else math.max(6,ball.radius*w*2)
  node.Size=UDim2.fromOffset(diameter*(1+squash),diameter*(1-squash))
  node.Position=if strip then UDim2.fromOffset(w*(entry.index/(#self.nodes+1)),h*.70-rise)else UDim2.fromOffset(w*ball.x,h*ball.y-rise)
 end
 for index,node in ipairs(self.pieces)do
  local t=math.clamp(self.age/End.Duration,0,1);node.Visible=self.active and t<1
  local side=if index%2==0 then 1 else -1;local spread=(index+1)/13
  node.Position=UDim2.fromOffset(w*.5+side*w*.40*spread*t,h*.52-(if self.frozen.success then 26 else 0)*math.sin(t*math.pi)+h*.38*t*t)
  node.Rotation=side*(20+index*17+t*90);node.BackgroundTransparency=math.clamp((t-.55)/.45,0,1)
 end
end
function End:step(dt)
 if self.destroyed then return end
 local owns=not self.options.owns or self.options.owns()
 if not owns then self:cancel();return end
 local target=self.options.target and self.options.target()
 if not self.frozen or not target or not target.Parent then self:clearArt();return end
 if self.active then
  if dt~=dt or dt>.25 or(self.options.reduced and self.options.reduced())then self.active=false;self.age=End.Duration
  else self.age=math.min(End.Duration,self.age+math.max(0,dt));if self.age>=End.Duration then self.active=false end end
 end
 if not self.layer or self.target~=target then self:build(target)end
 self:paint()
end
function End:destroy()if self.destroyed then return end;self:cancel();self.destroyed=true end
return End
