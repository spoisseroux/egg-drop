local Stars=require(script.Parent.StarText)
-- One Room-owned presentation pool, outside every pet's physical/framing hull.
local GuiService=game:GetService("GuiService")
local EggArt=require(script.Parent.EggArt)
local Pico8=require(game:GetService("ReplicatedStorage").Shared.Pico8)
local UICopy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
local Affection={};Affection.__index=Affection
-- PLACEHOLDER chime: BoardAudio's star_land placeholder (assets/audio/placeholder), pitched up.
-- Spencer's own sound replaces it (swap ChimeId). It plays through the EggDropSFX group, so the
-- Sound setting mutes it like every other effect.
Affection.ChimeId=134977919634272
Affection.ChimeVolume=.5
Affection.ChimeSpeed=1.2
Affection.BurstCount=22
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
 -- QA Q2.7: the plate reads "+1 ★" in Stars gold (the old nectar drop glyph is hidden).
 local label=Instance.new("TextLabel");label.Name="Amount";label.Text=UICopy.get("pet.star");label:SetAttribute("AccessibleLabel","1 Star saved");label.Font=Enum.Font.BuilderSansBold;label.TextSize=20
 label.TextColor3=Color3.fromHex("#FFBF50");label.BackgroundTransparency=1;label.TextStrokeTransparency=.4;label.TextStrokeColor3=Color3.fromHex("#282722")
 label.BorderSizePixel=0;label.Position=UDim2.fromOffset(8,0);label.Size=UDim2.new(1,-16,1,0);label.Active=false;label.Selectable=false;label.Parent=plate
 glyph.Visible=false
 local round=Instance.new("UICorner");round.CornerRadius=UDim.new(0,8);round.Parent=plate
 self.award,self.label,self.plate=award,label,plate
 -- QA v2 R5.5: when a +1 Star lands, a gold sparkle burst pops off the pet and a chime plays.
 -- One pooled anchor (moved to the pet), one emitter (Emit only, never Enabled), one Sound.
 local burstPart=Instance.new("Part");burstPart.Name="StarBurst";burstPart.Size=Vector3.new(.2,.2,.2);burstPart.Transparency=1
 burstPart.Anchored=true;burstPart.CanCollide=false;burstPart.CanTouch=false;burstPart.CanQuery=false;burstPart.CastShadow=false;burstPart.Parent=folder
 local sparkles=Instance.new("ParticleEmitter");sparkles.Name="StarSparkles";sparkles.Enabled=false;sparkles.Rate=0
 sparkles.Texture="rbxasset://textures/particles/sparkles_main.dds";sparkles.LightEmission=1;sparkles.LightInfluence=0
 sparkles.Color=ColorSequence.new(Color3.fromHex("#FFE38A"),Color3.fromHex("#FFBF50"))
 sparkles.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.45),NumberSequenceKeypoint.new(.6,.3),NumberSequenceKeypoint.new(1,0)})
 sparkles.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.7,.2),NumberSequenceKeypoint.new(1,1)})
 sparkles.Lifetime=NumberRange.new(.55,.95);sparkles.Speed=NumberRange.new(5,9);sparkles.SpreadAngle=Vector2.new(180,180)
 sparkles.Drag=4;sparkles.Acceleration=Vector3.new(0,-4,0);sparkles.Rotation=NumberRange.new(0,360);sparkles.RotSpeed=NumberRange.new(-200,200)
 sparkles.Parent=burstPart
 local chime=Instance.new("Sound");chime.Name="StarChime";chime.SoundId="rbxassetid://"..Affection.ChimeId
 chime.Volume=Affection.ChimeVolume;chime.PlaybackSpeed=Affection.ChimeSpeed;chime.RollOffMaxDistance=80;chime.RollOffMinDistance=8;chime.Parent=burstPart
 self.burstPart,self.sparkles,self.chime=burstPart,sparkles,chime
 self.glyphBits={};for _,bit in ipairs(glyph:GetDescendants())do if bit:IsA("GuiObject")and bit.BackgroundTransparency<1 then table.insert(self.glyphBits,{node=bit,alpha=bit.BackgroundTransparency})end end
 local function measure()
  if self.destroyed then return end
  local size=game:GetService("TextService"):GetTextSize(label.Text,label.TextSize,Enum.Font.BuilderSansBold,Vector2.new(10000,10000))
  award.Size=UDim2.fromOffset(math.max(70,math.ceil(size.X)+24),math.max(36,math.ceil(size.Y)+12))
 end
 self.measure=measure
 measure();self.preference=GuiService:GetPropertyChangedSignal("PreferredTextSize"):Connect(measure)
 return self
end
function Affection:setPet(pet)
 if self.destroyed then return end
 self:clear();self:hideAward();self.pet=pet;self.award.Adornee=pet and pet.model.PrimaryPart or nil
end
function Affection:hideAward()
 if self.destroyed then return end
 self.award.Enabled=false;self.awardUntil=nil
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
 -- QA Q2.7: letting go ends the petting cue but not a "+1 ★" already on its way up;
 -- it finishes its own rise (setPet / destroy hide it).
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
Affection.AwardSeconds=1.8
Affection.NoticeSeconds=2.6
function Affection:showPlate(text,seconds,reduced)
 if self.destroyed or not self.pet or not self.pet.model.Parent then return false end
 self.awardSeconds=seconds;self.awardUntil=seconds;self.awardReduced=reduced==true
 if self.label.Text~=text then self.label.Text=text;self.measure()end
 self.label:SetAttribute("AccessibleLabel",text)
 local body=self.pet.model.PrimaryPart;local scale=self.pet.worldScale or 1
 self.award.StudsOffsetWorldSpace=body.CFrame.RightVector*(1.8*scale)+Vector3.new(0,.6*scale,0)
 self.label.TextTransparency=0;self.label.TextStrokeTransparency=.4;self.plate.BackgroundTransparency=.18
 self.award.Enabled=true;return true
end
-- The day's five pets are used: one plate in words, no Star.
function Affection:showCapped(text,reduced)
 return self:showPlate(text,Affection.NoticeSeconds,reduced)
end
-- The landing: a gold sparkle burst at the pet (skipped under Reduced Motion) and the chime.
-- Returns the number of sparkles emitted and whether the chime started.
function Affection:burst(reduced)
 if self.destroyed or not self.pet or not self.pet.model.Parent then return 0,false end
 local body=self.pet.model.PrimaryPart;if not body then return 0,false end
 local scale=self.pet.worldScale or 1
 self.burstPart.CFrame=CFrame.new(body.Position+Vector3.new(0,.9*scale,0))
 local count=if reduced then 0 else math.max(8,math.floor(Affection.BurstCount*math.clamp(scale,.6,1.4)+.5))
 if count>0 then self.sparkles:Emit(count)end
 local group=game:GetService("SoundService"):FindFirstChild("EggDropSFX")
 local played=false
 if group and group:IsA("SoundGroup")then
  self.chime.SoundGroup=group
  if group.Volume>0 then self.chime.TimePosition=0;self.chime:Play();played=true end
 end
 return count,played
end
function Affection:showSaved(reduced)
 if self.destroyed or not self.pet or not self.pet.model.Parent then return false end
 local shown=self:showPlate(UICopy.get("pet.star"),Affection.AwardSeconds,reduced)
 self.label:SetAttribute("AccessibleLabel","1 Star saved")
 if shown then self.lastBurst=self:burst(reduced)end
 return shown
end
-- The "+1 ★" / notice plate: rises and holds, then fades over its last 40%.
function Affection:stepAward(dt,reduced)
 if not self.awardUntil then return end
 local pet=self.pet;local body=pet and pet.model.Parent and pet.model.PrimaryPart
 self.awardUntil-=dt
 if self.awardUntil<=0 or not body then self:hideAward();return end
 local total=self.awardSeconds or Affection.AwardSeconds
 local t=(total-self.awardUntil)/total;local still=self.awardReduced or reduced
 local fade=if still then 0 else math.max(0,(t-.6)/.4)
 local scale=pet.worldScale or 1
 self.award.StudsOffsetWorldSpace=body.CFrame.RightVector*(1.8*scale)+Vector3.new(0,.6*scale+(if still then 0 else .35*t),0)
 self.label.TextTransparency=fade;self.label.TextStrokeTransparency=.4+.6*fade;self.plate.BackgroundTransparency=.18+.82*fade
end
function Affection:step(dt,active,reduced)
 if self.destroyed then return end
 local pet=self.pet
 if not pet or not pet.model.Parent then self:clear();self:hideAward();return end
 dt=math.clamp(dt,0,.1)
 if not active then self:clear();self:stepAward(dt,reduced);return end
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
 self:stepAward(dt,reduced)
end
function Affection:destroy()
 if self.destroyed then return end;self:clear();self.destroyed=true;self.preference:Disconnect();self.folder:Destroy()
end
return Affection
