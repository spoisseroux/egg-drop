-- One main preview only. Existing renderer poses supply all geometry; this clock
-- never touches the equipped world actor, card caches, rewards or audio.
local Feedback={};Feedback.__index=Feedback
local UserInputService=game:GetService("UserInputService")
local touches,watching=0,false
-- True while no mouse button and no finger is down. UserInputService has no touch list to
-- read (GetTouches does not exist and threw every frame), so fingers are counted from the
-- touch events; losing the window clears the count.
function Feedback.pointerIdle()
 if not watching then
  watching=true
  UserInputService.TouchStarted:Connect(function()touches+=1 end)
  UserInputService.TouchEnded:Connect(function()touches=math.max(0,touches-1)end)
  UserInputService.WindowFocusReleased:Connect(function()touches=0 end)
 end
 return touches==0 and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
end
function Feedback.new(random)
 return setmetatable({random=random or math.random,nextAt=nil},Feedback)
end
function Feedback:cancel()
 local v=self.visual
 if v and not v.destroyed and v.expression==self.applied then v.expression=self.previous end
 if v and not v.destroyed and self.waving then v.greeting=2 end
 self.visual,self.applied,self.previous,self.untilAt,self.waving=nil,nil,nil,nil,nil
end
function Feedback:step(now,eligible,visual)
 if not eligible or not visual or visual.destroyed then self:cancel();self.nextAt=nil;self.lastVisual=nil;return nil end
 if self.lastVisual~=visual then self:cancel();self.nextAt=nil;self.lastVisual=visual end
 if self.untilAt then
  if now<self.untilAt then return nil end
  self:cancel()
 end
 self.nextAt=self.nextAt or now+7+self.random()*5
 if now<self.nextAt then return nil end
 self.nextAt=now+7+self.random()*5
 local kind=math.min(3,1+math.floor(self.random()*3))
 self.visual,self.previous,self.untilAt=visual,visual.expression,now+1.2
 self.applied=if kind==2 then "curious"elseif kind==3 then "pleased"else "neutral"
 visual.expression=self.applied
 if kind==1 and visual.greet then visual:greet();self.waving=true end
 return if kind==1 then "wave"elseif kind==2 then "tilt"else "smile"
end
return Feedback
