-- QA only. Mount beside PaletteStudy and ItemEggsVisualStudy. Same show/destroy API.
-- Frozen poses come from the production renderer. Only temporary backing meshes
-- are sampled here, outside the rig and its bounds; all original marks stay live.
local RunService = game:GetService("RunService")
local edgeColor = Color3.fromHex("#887B75")
local supported = {EyeL = true, EyeR = true, MouthSmile = true, MouthO = true}

local function underlay(entry, eyeHeight, parent)
    local source = entry.part
    if not source:IsA("MeshPart") or source.Transparency >= .99 then return false end
    local eye = entry.name == "EyeL" or entry.name == "EyeR"
    local s = source.Size
    local closed = eye and s.Y < entry.size.Y * .2
    local offset = if eye then entry.size.Y * (if closed then .055 else .09) else eyeHeight * .065
    local height = if eye then math.max(s.Y * .96, entry.size.Y * .14) else s.Y * .94
    local edge = source:Clone()
    edge:ClearAllChildren()
    edge.Name = "StudyUnderedge_" .. entry.name
    edge.TextureID = ""
    edge.Color = edgeColor
    edge.Material = Enum.Material.SmoothPlastic
    edge.MaterialVariant = ""
    edge.Reflectance = 0
    edge.CastShadow = false
    edge.Anchored = true
    edge.CanCollide, edge.CanTouch, edge.CanQuery = false, false, false
    edge.Size = Vector3.new(s.X * .94, height, s.Z * .95)
    -- Rig-local +Z faces forward. A recessed copy lets the dark front face
    -- occlude the backing everywhere except a narrow strip at the lower lip.
    edge.CFrame = source.CFrame * CFrame.new(0, -offset, -s.Z * .045)
    edge.Parent = parent
    return true
end

return function(client)
    local base = require(assert(script.Parent:FindFirstChild("PaletteStudy"), "Mount PaletteStudy beside this module"))(client)
    local trial = {owner = base.owner}
    local group
    local function clear()
        if group then group:Destroy(); group = nil end
    end
    function trial:show(pigment, channel, hour, pose)
        clear()
        local facts = base:show(pigment, channel, hour, pose)
        if pigment ~= "ink" or channel ~= "main" then return facts end
        group = Instance.new("Folder")
        group.Name = "_InkFaceUnderedge_FIXTURE"
        group.Parent = base.owner.folder
        local count = 0
        for _, visual in ipairs(base.owner.visuals) do
            local eyeHeight = 0
            for _, entry in ipairs(visual.pieces) do
                if entry.name == "EyeL" then eyeHeight = entry.size.Y; break end
            end
            assert(eyeHeight > 0, "Missing authored EyeL anchor")
            for _, entry in ipairs(visual.pieces) do
                if supported[entry.name] and underlay(entry, eyeHeight, group) then count += 1 end
            end
        end
        base.owner.gui.FixtureMetadata.Text ..= "   |   lower-edge trial #887B75"
        RunService.RenderStepped:Wait()
        RunService.RenderStepped:Wait()
        facts.underedgeHex = edgeColor:ToHex()
        facts.underedgePieces = count
        return facts
    end
    function trial:destroy()
        clear()
        base:destroy()
    end
    return trial
end
