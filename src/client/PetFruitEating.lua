-- Owner-preview-only transient berry. The portrait's existing clock calls step.
local Hues=require(game:GetService("ReplicatedStorage").Shared.HueCatalog)
local Eating={};Eating.__index=Eating
local function smooth(x)x=math.clamp(x,0,1);return 1-(1-x)^3 end
local function anchor(visual,name)
 for _,entry in ipairs(visual.pieces)do if entry.name==name then return entry.part end end
end
local function restore(visual)
 for _,entry in ipairs(visual.pieces)do entry.lastFrame=nil;entry.lastSize=nil;entry.lastTransparency=nil end
 visual.poseDirty=true;visual:update(0)
end
function Eating.new()return setmetatable({},Eating)end
function Eating:cancel()
 local visual=self.visual
 if visual and not visual.destroyed then restore(visual)end
 if self.fruit then self.fruit:Destroy();self.fruit=nil end
 self.visual=nil;self.active=false;self.token=nil
end
function Eating:start(visual,token,reduced)
 self:cancel()
 if not visual or visual.destroyed or visual.worldContext or not token or not Hues.ById[token.itemId]then return false end
 local mouth=anchor(visual,"MouthSmile")or anchor(visual,"MouthO");local head=anchor(visual,"Head")
 if not mouth or not head then return false end
 local berry=Instance.new("Part");berry.Name="ConfirmedHueFruit";berry.Shape=Enum.PartType.Ball;berry.Color=Hues.ById[token.itemId].color
 berry.Material=Enum.Material.SmoothPlastic;berry.Anchored=true;berry.CanCollide=false;berry.CanTouch=false;berry.CanQuery=false;berry.CastShadow=false;berry.Parent=visual.model
 local diameter=math.max(.05,head.Size.X*.13);berry.Size=Vector3.one*diameter
 self.visual,self.token,self.fruit,self.diameter,self.age,self.active,self.reduced=visual,token,berry,diameter,0,true,reduced==true
 self.rigRevision=visual.rigRevision
 self:step(0);return true
end
function Eating:step(dt)
 if not self.active then return false end
 local visual=self.visual
 if not visual or visual.destroyed or not self.fruit or not self.fruit.Parent or visual.rigRevision~=self.rigRevision then self:cancel();return false end
 self.age+=math.max(0,dt);local t=self.age
 if t>=(if self.reduced then .20 else .75)then self:cancel();return false end
 local mouth=anchor(visual,"MouthSmile")or anchor(visual,"MouthO");local head=anchor(visual,"Head")
 if not mouth or not head then self:cancel();return false end
 local bite=if self.reduced then .8 else math.clamp((t-.35)/.13,0,1)
 local nod=if self.reduced then 0 elseif t<.48 then math.rad(5)*smooth((t-.35)/.13)elseif t<.60 then math.rad(5)-math.rad(8)*smooth((t-.48)/.12)else -math.rad(3)*(1-smooth((t-.60)/.15))
 restore(visual)
 local pivot=head.Position;local transform=CFrame.new(pivot)*CFrame.Angles(nod,0,0)*CFrame.new(-pivot)
 for _,entry in ipairs(visual.pieces)do
  local name=entry.name or "";local channel=entry.channel
  if channel=="Head"or channel=="Face"or channel=="Charm"or name:find("Eye")or name:find("Glint")or name:find("Mouth")or name:find("Teeth")or name:find("Cheek")then
   entry.part.CFrame=transform*entry.part.CFrame
   if name:find("Eye")and bite>0 then local size=entry.part.Size;entry.part.Size=Vector3.new(size.X,math.max(.001,size.Y*.12),size.Z)end
   if name:find("Glint")and bite>0 then entry.part.Transparency=1 end
  end
 end
 local cf=mouth.CFrame
 -- Authored recipes face camera-local +Z; the mouth surface's world position
 -- supplies the anchor while head axes keep the berry outside the eyes.
 local approach=if self.reduced then 1 else smooth(t/.23)
 local offset=head.CFrame.RightVector*(head.Size.X*.28*(1-approach))+Vector3.new(0,head.Size.Y*.02,0)+Vector3.new(0,0,self.diameter*.65)
 self.fruit.CFrame=CFrame.new(cf.Position+offset)
 local size=if self.reduced then .75 else math.max(.001,1-bite)
 self.fruit.Size=Vector3.one*math.max(.001,self.diameter*size);self.fruit.Transparency=if bite>=1 then 1 else 0
 return true
end
function Eating:destroy()self:cancel()end
return Eating
