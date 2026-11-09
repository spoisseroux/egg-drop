-- An opaque owner-local cut. The token owns every reveal and input release.
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local Transition={};Transition.__index=Transition
function Transition.new(parent,reduced)
    local gui=Instance.new("ScreenGui")
    gui.Name="PetFocusTransition";gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.DisplayOrder=50;gui.Parent=parent.Parent
    local shade=Instance.new("TextButton")
    shade.Name="OpaqueCover";shade.Size=UDim2.fromScale(1,1);shade.Text="";shade.BackgroundColor3=Color3.fromHex("18222A")
    shade.BorderSizePixel=0;shade.AutoButtonColor=false;shade.Modal=true;shade.Selectable=false;shade.Visible=false;shade.BackgroundTransparency=1;shade.Parent=gui
    return setmetatable({gui=gui,shade=shade,reduced=reduced,epoch=0},Transition)
end
function Transition:begin()
    self.epoch+=1
    if self.motion then self.motion:Cancel();self.motion=nil end
    self.shade.Visible=true;self.shade.Active=true
    return self.epoch
end
function Transition:owns(token)return not self.destroyed and token==self.epoch end
function Transition:fade(token,alpha,duration)
    if not self:owns(token)then return false end
    if self.reduced()then self.shade.BackgroundTransparency=alpha
    else
        local motion=TweenService:Create(self.shade,TweenInfo.new(duration,Enum.EasingStyle.Quad),{BackgroundTransparency=alpha})
        self.motion=motion;motion:Play();motion.Completed:Wait()
        if self.motion==motion then self.motion=nil end
    end
    return self:owns(token)
end
function Transition:cover(token)
    if not self:fade(token,0,.10)then return false end
    -- RenderStepped resumes before drawing. Cross two boundaries so the first
    -- opaque frame is presented before callers can mutate or uncover the shot.
    RunService.RenderStepped:Wait()
    RunService.RenderStepped:Wait()
    return self:owns(token)
end
function Transition:reveal(token)
    if not self:fade(token,1,.14)then return false end
    if self:owns(token)then self.shade.Visible=false;self.shade.Active=false end
    return true
end
function Transition:cancel()
    self.epoch+=1
    if self.motion then self.motion:Cancel();self.motion=nil end
    self.shade.Visible=false;self.shade.Active=false;self.shade.BackgroundTransparency=1
end
function Transition:destroy()
    self.epoch+=1;self.destroyed=true
    if self.motion then self.motion:Cancel()end
    self.gui:Destroy()
end
return Transition
