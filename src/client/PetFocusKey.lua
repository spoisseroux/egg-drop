-- One viewer-local raking key, active only during nearby night petting.
local Clock=require(script.Parent.HollowClock)
local Key={};Key.__index=Key
function Key.new()return setmetatable({},Key)end
function Key:disable()if self.light and self.light.Parent then self.light.Enabled=false end end
function Key:update(camera,visual,active,daylight)
 if self.destroyed then return end
 daylight=daylight or Clock.lastDaylight or 1
 local center=visual and visual.bodyBoundsFrame and visual.bodyBoundsFrame.Position or visual and visual.origin
 if not active or not camera or camera~=workspace.CurrentCamera or not visual or not visual.model.Parent or not center
  or visual.nightTreatment=="groupedRoleFill"or daylight>=.5 or(camera.CFrame.Position-center).Magnitude>14 then self:disable();return end
 if self.camera and self.camera~=camera then self:disable();self.camera=camera;return end
 self.camera=camera
 if self.part and self.part.Parent and self.part.Parent~=camera then self.part.Parent=camera end
 if not self.part or not self.part.Parent then
  local part=Instance.new("Part");part.Name="LocalPetFocusKey";part.Anchored=true;part.Transparency=1;part.Size=Vector3.new(.1,.1,.1);part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false;part.Parent=camera;self.part=part
  local light=Instance.new("SpotLight");light.Name="PettingRake";light.Range=14;light.Angle=70;light.Shadows=false;light.Color=Color3.fromRGB(245,249,242);light.Face=Enum.NormalId.Front;light.Parent=part;self.light=light
 end
 local position=center-camera.CFrame.RightVector*3+Vector3.new(0,2.2,0)-camera.CFrame.LookVector*3
 self.part.CFrame=CFrame.lookAt(position,center)
 local dusk=math.clamp((.5-daylight)/.5,0,1);dusk=dusk*dusk*(3-2*dusk)
 self.light.Brightness=.6*dusk;self.light.Enabled=true
end
function Key:destroy()if self.destroyed then return end;self.destroyed=true;if self.part then self.part:Destroy()end;self.part,self.light=nil,nil end
return Key
