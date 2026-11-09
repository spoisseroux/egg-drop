-- LocalScript evidence only. Install in StarterPlayerScripts in a temporary Studio session.
-- Uses current production modules with private injected data and no remote callbacks.
local Players=game:GetService("Players")
local Gui=game:GetService("GuiService")
local Shared=game:GetService("ReplicatedStorage").Shared
local player=assert(Players.LocalPlayer,"Client VM required")
local source=player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local parent=player:WaitForChild("PlayerGui")
local screen=Instance.new("ScreenGui")
screen.Name="_CompanionUiGallery_FIXTURE"
screen.ResetOnSpawn=false
screen.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets
screen.DisplayOrder=1000
screen.Parent=parent

-- A private module cache keeps preview themes away from the ordinary DeckArt registry.
local modules=Instance.new("Folder")
modules.Name="IsolatedClientModules"
modules.Parent=screen
for _,module in source:GetChildren() do
    if module:IsA("ModuleScript") then module:Clone().Parent=modules end
end
local Art=require(modules.DeckArt)
local Editor=require(modules.HueEggView)
local Intent=require(modules.HueIntent)
local Recap=require(modules.RoundRecap)
local Eggs=require(Shared.EggCatalog)
local Hue=require(Shared.HueCatalog)
local Pets=require(Shared.PetCatalog)
local Themes=require(Shared.DeckThemes)
local previousSelection=Gui.SelectedObject
local backdrop=Instance.new("Frame")
backdrop.Name="FixtureBackdrop"
backdrop.Size=UDim2.fromScale(1,1)
backdrop.BackgroundColor3=Color3.fromHex("#223B37")
backdrop.BackgroundTransparency=.38
backdrop.BorderSizePixel=0
backdrop.Active=true
backdrop.Parent=screen
local safe=Instance.new("Frame")
safe.Name="SafeContent"
safe.BackgroundTransparency=1
safe.Parent=backdrop
local connections={}
local retired=false
local editor,panel
local serial=0
local function remember(connection) table.insert(connections,connection) end
local function clear()
    if editor then editor:destroy();editor=nil end
    if panel then panel:Destroy();panel=nil end
end
local function cleanup()
    if retired then return end
    retired=true
    for _,connection in connections do connection:Disconnect() end
    clear()
    if previousSelection and previousSelection.Parent then Gui.SelectedObject=previousSelection end
    screen:Destroy()
end

local function seed()
    local shapes={"ring","dot","pebble","ring","dot","pebble","ring"}
    local rows,appearances={},{}
    for i,pet in ipairs(Pets.collection) do
        local main,secondary=Hue.emptyCounts(),Hue.emptyCounts()
        if i==1 then main.rose,main.tide,secondary.tide=2,1,2
        elseif i%3==0 then main.iris,secondary.citrus=3,2
        elseif i%3==1 then main.tide,secondary.rose=4,1
        elseif i%3==2 and i>2 then main.citrus=3 end
        rows[pet.id]={main=main,secondary=secondary}
        appearances[pet.id]={mainDoses=main,secondaryDoses=secondary,
            charmVisible=i~=5,charmShape=shapes[i]}
    end
    return {revision=1,status="Ready",nectar=20,inventoryMask=127,companionId="pip",
        petHues=rows,hues={},hueInventory={rose=3,tide=2,citrus=1,iris=1,reset=2}},appearances
end
local state,appearances=seed()
local function showEditor(view)
    local intent=Intent.new({
        id=function()serial+=1;return "fixture-"..serial end,
        send=function()
            screen:SetAttribute("AttemptedWrite",(screen:GetAttribute("AttemptedWrite") or 0)+1)
            -- Isolated gallery never transmits a request or modifies the seed.
        end,
        changed=function()if editor then editor:refresh() end end,
    })
    editor=Editor.new(safe,intent,{
        activePet=function()return "pip" end,
        appearance=function(id)return appearances[id] end,
        shapeSelectionsEnabled=function()return true end,
    })
    editor:open(state,view,"pip")
end
local function showRecap()
    panel=Art.frame(safe,"ReceiptPreview","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(600,400),10)
    panel.AnchorPoint=Vector2.new(.5,.5)
    Art.panel(panel,16)
    local title=Art.text(panel,"FixtureOutcome","Round complete",UDim2.fromOffset(12,4),
        UDim2.new(1,-24,0,32),"text",24,Art.Font.Heading)
    title.ZIndex=17
    title.TextXAlignment=Enum.TextXAlignment.Center
    local function footer(name,primary)
        local n=Instance.new("TextButton")
        n.Name,n.Text,n.Parent,n.ZIndex,n.BorderSizePixel=name,name,panel,17,0
        Art.bind(n,{BackgroundColor3="raised",TextColor3="text"})
        Art.button(n,10)
        Art.type(n,"Action",true)
        Art.control(n,primary,true)
        return n
    end
    local retry,eggs=footer("Try again",true),footer("Hatch eggs",false)
    local ownPanel=panel
    local recap=Recap.new(panel,nil,true)
    recap.frame.Visible=true
    local result={sequence=1,status="Saved",success=true,stage=2,reason="Completed",
        award=14,daily=6,balance=20,recipe=Eggs.ById.meadow,
        reward={sequence=1,total=14,base=8,daily=6,family="pip",masteryPoints=1,promotedTo=0,contracts={}}}
    recap:update(630,4,2,nil,0,nil,0,700)
    recap:updateField(result)
    local function fit()
        if retired or panel~=ownPanel or ownPanel.Parent~=safe then return end
        local wide=math.max(1,math.min(600,safe.AbsoluteSize.X-16))
        local high=math.max(1,math.min(720,safe.AbsoluteSize.Y-16))
        local shallow=safe.AbsoluteSize.Y<220
        Art.type(title,if shallow then "Body" else "Heading",true)
        local titleH=Art.textHeight(title,wide-24,if shallow then 22 else 28)
        local footH=math.max(Art.actionHeight(retry,(wide-36)/2),Art.actionHeight(eggs,(wide-36)/2))
        local margin=if shallow then 6 elseif safe.AbsoluteSize.Y<440 then 8 else 12
        panel.Size=UDim2.fromOffset(wide,high)
        title.Size=UDim2.new(1,-24,0,titleH)
        retry.Size,eggs.Size=UDim2.new(.5,-18,0,footH),UDim2.new(.5,-18,0,footH)
        retry.Position,eggs.Position=UDim2.new(0,12,1,-margin-footH),UDim2.new(.5,6,1,-margin-footH)
        recap.compactLayout=safe.AbsoluteSize.Y<440
        recap.layoutWidth,recap.headerInset,recap.footerInset=wide,titleH+8,footH+margin+4
        recap:layoutField(high)
        local fitted=math.min(high,math.max(recap.headerInset+recap.footerInset+44,recap.bodyContentHeight+recap.headerInset+recap.footerInset))
        panel.Size=UDim2.fromOffset(wide,fitted)
        recap:layoutField(fitted)
    end
    fit()
    recap.onPreferredLayout=fit
end
local function refresh()
    if retired then return end
    local theme=screen:GetAttribute("Theme")
    local view=screen:GetAttribute("View")
    if not Themes.ById[theme] or not ({pet=true,hue=true,charm=true,recap=true})[view] then
        screen:SetAttribute("LastError","Use an existing Deck theme and pet/hue/charm/recap.")
        return
    end
    clear()
    Art.applyTheme(Themes.ById[theme])
    if view=="recap" then showRecap() else showEditor(view) end
    screen:SetAttribute("LastError",nil)
    screen:SetAttribute("Seed","Seven owned, active Zivvi; preview-only. Recap +14 (Quest 8, Daily 6).")
    screen:SetAttribute("SafeWidth",safe.AbsoluteSize.X)
    screen:SetAttribute("SafeHeight",safe.AbsoluteSize.Y)
end
local function resize()
    local margin=if backdrop.AbsoluteSize.Y<280 then 0 else 8
    safe.Position=UDim2.fromOffset(margin,margin)
    safe.Size=UDim2.new(1,-margin*2,1,-margin*2)
end
screen:SetAttribute("View","pet")
screen:SetAttribute("Theme",Themes.Default)
screen:SetAttribute("Cleanup",false)
screen:SetAttribute("AttemptedWrite",0)
resize()
remember(backdrop:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize))
remember(safe:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    if not retired and screen:GetAttribute("View")=="recap" then task.defer(refresh) end
end))
for _,attr in {"View","Theme"} do remember(screen:GetAttributeChangedSignal(attr):Connect(refresh)) end
remember(screen:GetAttributeChangedSignal("Cleanup"):Connect(function()
    if screen:GetAttribute("Cleanup") then cleanup() end
end))
remember(script.Destroying:Connect(cleanup))
remember(screen.Destroying:Connect(cleanup))
task.defer(refresh)
