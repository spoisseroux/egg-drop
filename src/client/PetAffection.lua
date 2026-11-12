local Stars=require(script.Parent.StarText)
-- One Room-owned presentation pool, outside every pet's physical/framing hull.
local GuiService=game:GetService("GuiService")
local EggArt=require(script.Parent.EggArt)
local Pico8=require(game:GetService("ReplicatedStorage").Shared.Pico8)
local Affection={};Affection.__index=Affection
function Affection.new(parent,onVariation)
 local folder=Instance.new("Folder");folder.Name="PetAffectionPresentation";folder.Parent=parent
 local self=setmetatable({folder=folder,petals={},elapsed=0,nextVariation=3,index=0,onVariation=onVariation},Affection)
 for i=1,3 do
  local p=Instance.new("Part");p.Name="AffectionPetal";p.Shape=Enum.PartType.Ball;p.Size=Vector3.new(.08,.08,.08)
  p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Material=Enum.Material.Neon
  p.Color=Pico8.Heart;p.Transparency=1;p.Parent=folder;self.petals[i]=p
  -- Each petal carries one pooled PICO-8 pink heart; the part is its small glow.
  local heart=Instance.new("BillboardGui");heart.Name="Heart";heart.Size=UDim2.fromOffset(48,48);heart.LightInfluence=0;heart.AlwaysOnTop=false
  heart.MaxDistance=40;heart.Enabled=false;heart.Adornee=p;heart.Parent=p
  local glyph=Instance.new("TextLabel");glyph.Name="Glyph";glyph.BackgroundTransparency=1;glyph.Size=UDim2.fromScale(1,1);glyph.Text="♥"
  glyph.Font=Enum.Font.GothamBlack;glyph.TextSize=42;glyph.TextColor3=Pico8.Heart;glyph.TextStrokeColor3=Pico8[2];glyph.TextStrokeTransparency=.35
  glyph.Active=false;glyph.Selectable=false;glyph.Parent=heart
  self.hearts=self.hearts or {};self.hearts[i]={gui=heart,glyph=glyph}
 end
 local award=Instance.new("BillboardGui");award.Name="SavedPetNectar";award.AlwaysOnTop=false;award.LightInfluence=0;award.MaxDistance=30;award.Enabled=false;award.Parent=folder
 local plate=Instance.new("Frame");plate.Name="Plate";plate.BackgroundColor3=Color3.fromHex("#282722");plate.BackgroundTransparency=.18;plate.BorderSizePixel=0
 plate.Size=UDim2.fromScale(1,1);plate.Active=false;plate.Selectable=false;plate.Parent=award
 local glyph=EggArt.nectar(plate,UDim2.new(0,5,.5,-12),UDim2.fromOffset(20,24),2)
 local label=Instance.new("TextLabel");label.Name="Amount";label.Text="+1";label:SetAttribute("AccessibleLabel","1 Star saved");label.Font=Enum.Font.GothamBold;label.TextSize=14
 label.TextColor3=Color3.fromHex("#FFBF50");label.BackgroundTransparency=1
 label.BorderSizePixel=0;label.Position=UDim2.fromOffset(29,0);label.Size=UDim2.new(1,-33,1,0);label.Active=false;label.Selectable=false;label.Parent=plate
 local round=Instance.new("UICorner");round.CornerRadius=UDim.new(0,8);round.Parent=plate
 self.award,self.label,self.plate=award,label,plate
 self.glyphBits={};for _,bit in ipairs(glyph:GetDescendants())do if bit:IsA("GuiObject")and bit.BackgroundTransparency<1 then table.insert(self.glyphBits,{node=bit,alpha=bit.BackgroundTransparency})end end
 local function measure()
  if self.destroyed then return end
  local size=game:GetService("TextService"):GetTextSize(label.Text,14,Enum.Font.GothamBold,Vector2.new(10000,10000))
  award.Size=UDim2.fromOffset(math.max(70,math.ceil(size.X)+40),math.max(36,math.ceil(size.Y)+8))
 end
 measure();self.preference=GuiService:GetPropertyChangedSignal("PreferredTextSize"):Connect(measure)
 return self
end
function Affection:setPet(pet)
 if self.destroyed then return end
 self:clear();self.pet=pet;self.award.Adornee=pet and pet.model.PrimaryPart or nil
end
function Affection:rebind(pet)
 -- A complete-rig swap changes only the attachment, never its Saved cue/clock.
 if not self.destroyed and self.pet==pet then self.award.Adornee=pet.model.PrimaryPart end
end
function Affection:clear()
 if self.cleared then return end;self.cleared=true
 if self.pet then self.pet.affectionTilt,self.pet.affectionBlush,self.pet.pettingHeld=0,0,nil end
 self.elapsed,self.nextVariation,self.index,self.variationAge,self.startAge=0,3,0,nil,nil
 for _,p in ipairs(self.petals)do p.Transparency=1 end
 for _,h in ipairs(self.hearts)do h.gui.Enabled=false end
 self.award.Enabled=false;self.awardUntil=nil
end
function Affection:begin(reduced)
 if self.destroyed or not self.pet or not self.pet.model.Parent then return end
 local now=if self.clock then self.clock()else os.clock()
 local bloom=not reduced and now-(self.lastStartAt or -math.huge)>=1.5
 if bloom then self.lastStartAt=now end
 self.cleared=false;self.startAge=if bloom then 0 else nil
 self.pet.affection=.9;self.pet.affectionBlush=.55;self.pet.pettingHeld=0
end
-- Holding past this many seconds turns the pose affectionate and keeps hearts rising.
Affection.HeartsAfter=1
Affection.HeartCycle=1.2
function Affection:showSaved(reduced)
 if self.destroyed or not self.pet or not self.pet.model.Parent then return false end
 self.cleared=false;self.awardUntil=1.4;self.awardReduced=reduced==true
 local body=self.pet.model.PrimaryPart;local scale=self.pet.worldScale or 1
 self.award.StudsOffsetWorldSpace=body.CFrame.RightVector*(1.8*scale)+Vector3.new(0,.6*scale,0)
 self.label.TextTransparency=0;self.plate.BackgroundTransparency=.18
 for _,bit in ipairs(self.glyphBits)do bit.node.BackgroundTransparency=bit.alpha end
 self.award.Enabled=true;return true
end
function Affection:step(dt,active,reduced)
 if self.destroyed then return end
 local pet=self.pet
 if not pet or not pet.model.Parent then self:clear();return end
 if not active then self:clear();return end
 dt=math.clamp(dt,0,.1)
 if active then
  self.cleared=false
  self.elapsed+=dt
  if self.elapsed>=self.nextVariation then
   self.index=self.index%3+1;self.variationAge=0;self.nextVariation=self.elapsed+3+(self.index%3)
   if self.onVariation then self.onVariation(self.index)end
  end
 elseif self.elapsed>0 then self:clear()end
 if self.variationAge then self.variationAge+=dt end
 if self.startAge then self.startAge+=dt;if self.startAge>=.9 then self.startAge=nil end end
 local wave=if self.variationAge and self.variationAge<.9 then math.max(0,math.sin(self.variationAge/.9*math.pi))else 0
 local welcome=if self.startAge then math.max(0,1-self.startAge/.9)else 0
 pet.affectionTilt=if active and not reduced and self.index==1 then math.sin((self.variationAge or 0)*6)*wave*.045 else 0
 pet.affectionBlush=if active and reduced then .55 elseif active then math.max(welcome*.55,if self.index==2 then wave*.7 else 0)else 0
 pet.pettingHeld=if active then self.elapsed else nil
 -- Past the first second of a hold, hearts keep rising in a 1.2 s loop.
 local held=if active and self.elapsed>=Affection.HeartsAfter then(self.elapsed-Affection.HeartsAfter)%Affection.HeartCycle else nil
 local body=pet.model.PrimaryPart;local scale=pet.worldScale or 1
 for i,p in ipairs(self.petals)do
  local stagger=if held then(held+(i-1)*.4)%Affection.HeartCycle else nil
  local strength=math.max(welcome,if self.index==3 then wave else 0,if stagger then math.sin(stagger/Affection.HeartCycle*math.pi)else 0)
  local show=active and not reduced and strength>0
  p.Transparency=if show then 1-strength*.8 else 1
  local heart=self.hearts[i];if heart.gui.Enabled~=show then heart.gui.Enabled=show end
  if show then heart.glyph.TextTransparency=1-strength;heart.glyph.TextStrokeTransparency=1-strength*.65 end
  if show and body then
   local age=stagger or self.startAge or self.variationAge or 0
   p.CFrame=body.CFrame*CFrame.new((i-2)*.6*scale,(.95+age*.7)*scale,(.8+math.sin(age*4+i)*.08)*scale)*CFrame.Angles(0,0,(i-2)*.4+age)
  end
 end
 if self.awardUntil then
  self.awardUntil-=dt
  if self.awardUntil<=0 or not active then self.award.Enabled=false;self.awardUntil=nil
  elseif body then
   local t=(1.4-self.awardUntil)/1.4;local fade=if self.awardReduced or reduced then 0 else t
   self.award.StudsOffsetWorldSpace=body.CFrame.RightVector*(1.8*scale)+Vector3.new(0,.6*scale+(if self.awardReduced or reduced then 0 else .35*t),0)
   self.label.TextTransparency=fade;self.plate.BackgroundTransparency=.18+.82*fade
   for _,bit in ipairs(self.glyphBits)do bit.node.BackgroundTransparency=bit.alpha+(1-bit.alpha)*fade end
  end
 end
end
function Affection:destroy()
 if self.destroyed then return end;self:clear();self.destroyed=true;self.preference:Disconnect();self.folder:Destroy()
end
return Affection
