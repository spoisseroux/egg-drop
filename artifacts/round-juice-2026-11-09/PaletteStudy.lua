-- Client-only lighting study. Mount this ModuleScript beside ItemEggsVisualStudy.
-- local trial = require(studyModule)(client)
-- trial:show("ink", "main", 0, "blink"); trial:destroy()
-- Capture eight open-eye sheets (two hues × two channels × two hours), then
-- Ink Main blink at each hour and neutral controls at the same settings.
-- Keep the other channel undyed, production Standard surfaces and dot equipped.
-- Inspect dark pupil silhouettes separately from the catchlights. A closed lid,
-- mouth corners, feet/contact edge and body silhouette must survive at garden
-- and thumbnail scale. Keep Garnet distinct from Rose and Ink neutral-black.
-- Rendered pixel values vary with material/light. RGB readbacks in the returned
-- stats verify assignment; only the captures can establish readability.
local RunService = game:GetService("RunService")
local pigments = {garnet = Color3.fromHex("#8C1835"), ink = Color3.fromHex("#17171B")}
local pets = {"pip", "puddle", "wick", "orbit"}
local origin = Vector3.new(-9, 4.025, 70)

return function(client)
    local driver = require(assert(script.Parent:FindFirstChild("ItemEggsVisualStudy"), "Mount ItemEggsVisualStudy beside PaletteStudy"))
    local owner = driver(client, {
        pets = pets, origin = origin, view = "lineup", motion = "idle",
        preset = "neutral", hour = 12, frozen = true, reduced = false, cadence = 0,
        markers = false, cameraTarget = origin + Vector3.new(0, .75, 0),
        cameraOffset = Vector3.new(0, .65, 9.25), fov = 37,
    })
    local trial = {owner = owner}
    function trial:show(pigment, channel, hour, pose)
        assert(pigments[pigment] or pigment == "neutral", "Expected garnet, ink or neutral")
        assert(channel == "main" or channel == "secondary", "Expected main or secondary")
        assert(hour == 0 or hour == 12, "Expected garden hour 0 or 12")
        pose = pose or "open"
        assert(pose == "open" or pose == "blink", "Expected open or blink")
        local t = if pose == "blink" then .075 else .7
        local ok, reason = owner:set({hour = hour, at = t})
        assert(ok, reason)
        local deadline = os.clock() + 30
        for _, visual in ipairs(owner.visuals) do
            while visual.backend ~= "AuthoredMesh" do
                assert(os.clock() < deadline, "Authored pet mesh did not become ready")
                visual:update(0)
                RunService.Heartbeat:Wait()
            end
            -- Align production blink phases, including Ovelle's seed offset.
            visual.cosmeticSeed = if visual.definition.id == "ovelle" then 680 else 0
            visual.greeting = 2
            local colors = table.clone(visual.colors)
            local role = if channel == "main" then "body" else "secondary"
            if pigments[pigment] then colors[role] = pigments[pigment] end
            visual.colors, visual.secondaryColor = colors, colors.secondary
            for _, entry in ipairs(visual.pieces) do
                if entry.colorRole == role then
                    entry.color, entry.part.Color = colors[role], colors[role]
                end
            end
            visual.poseDirty = true
            visual:update(0)
        end
        RunService.RenderStepped:Wait()
        RunService.RenderStepped:Wait()
        assert(owner:lightingIsControlled(), "Garden lighting changed during trial")
        owner.gui.FixtureMetadata.Text = string.format("COLOR TRIAL   %s %s   %02d:00   %s   |   Zivvi    Ovelle    Tikket    Nuum", pigment, channel, hour, pose)
        return {pigment = pigment, assignedHex = pigments[pigment] and pigments[pigment]:ToHex() or "neutral",
            channel = channel, hour = hour, pose = pose, world = owner:stats()}
    end
    function trial:destroy()
        owner:destroy()
    end
    return trial
end
