-- One snapshot listener and focus intent owner; no independent render clock.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local Activity=require(ReplicatedStorage.Shared.GardenActivity)
local Garden={};Garden.__index=Garden
function Garden.new(boards,options)
    local self=setmetatable({boards=boards,connections={},focusSeq=0,focusPulse=0,playerId=options and options.playerId or Players.LocalPlayer.UserId,remote=options and options.remote,now=options and options.now or function()return workspace:GetServerTimeNow()end,appearanceCache=setmetatable({},{__mode="k"})},Garden)
    local function bind(folder)
        if folder.Name~="GardenState"or self.folder then return end
        self.folder=folder
        local function read()
            local raw=folder:GetAttribute("Snapshot");if type(raw)~="string"then return end
            local ok,snapshot=pcall(Http.JSONDecode,Http,raw)
            if ok and Activity.validSnapshot(snapshot)and(not self.snapshot or snapshot.revision>=self.snapshot.revision)then self.snapshot=snapshot end
        end
        table.insert(self.connections,folder:GetAttributeChangedSignal("Snapshot"):Connect(read));read()
    end
    self.characterId=options and options.characterId or function()
        local character=Players.LocalPlayer.Character
        return character and character:GetAttribute("GardenCharacterId")or 0
    end
    self.petGeneration=options and options.petGeneration or function()
        local board=boards:FindFirstChild(tostring(self.playerId))
        return board and board:GetAttribute("CompanionGeneration")or 0
    end
    local folder=if options and options.folder then options.folder else ReplicatedStorage:FindFirstChild("GardenState");if folder then bind(folder)end
    if not(options and options.folder)then table.insert(self.connections,ReplicatedStorage.ChildAdded:Connect(bind))end
    return self
end
function Garden:get(ownerId,petId,character)
    local actor=self.snapshot and self.snapshot.actors[tostring(ownerId)]
    if not actor or actor.petId~=petId or not character then return nil end
    if ownerId==self.playerId and actor.mode=="Focus"and not self.focusPet then return nil end
    local generation=character:GetAttribute("GardenCharacterId")
    if type(generation)~="number"or generation~=actor.characterId then return nil end
    local board=self.boards:FindFirstChild(tostring(ownerId))
    if not board or type(board:GetAttribute("CompanionGeneration"))~="number"or board:GetAttribute("CompanionGeneration")~=actor.petGeneration then return nil end
    if actor.action=="greet"then
        local peer=self.snapshot.actors[tostring(actor.peerId)]
        local board=self.boards:FindFirstChild(tostring(actor.peerId))
        if not peer or peer.actionId~=actor.actionId or peer.peerId~=actor.ownerId or not board or board:GetAttribute("CompanionId")~=peer.petId
            or type(board:GetAttribute("CompanionGeneration"))~="number"or board:GetAttribute("CompanionGeneration")~=peer.petGeneration
            or type(board:GetAttribute("GardenCharacterId"))~="number"or board:GetAttribute("GardenCharacterId")~=peer.characterId then return nil end
    end
    return actor
end
function Garden:appearance(board,petId)
    local raw=board:GetAttribute("PetAppearance")
    local cached=self.appearanceCache[board]
    if not cached or cached.raw~=raw then
        local ok,value=pcall(Http.JSONDecode,Http,if type(raw)=="string"then raw else "{}")
        cached={raw=raw,value=if ok and type(value)=="table"then value else {}}
        self.appearanceCache[board]=cached
    end
    local item=cached.value[petId]
    return {charmVisible=not(type(item)=="table"and item.charmVisible==false)}
end
function Garden:focus(active,petId,position,yaw)
    local remote=self.remote or ReplicatedStorage.Remotes:FindFirstChild("GardenIntent")
    if not remote then return end
    if not active then
        if self.focusPet then remote:FireServer({kind="focusEnd",seq=self.focusSeq,petId=self.focusPet,characterId=self.focusCharacter,petGeneration=self.focusPetGeneration});self.focusPet=nil end
        return
    end
    if self.focusPet==petId and self.focusPosition and(position-self.focusPosition).Magnitude<.15 and math.abs((yaw or 0)-(self.focusYaw or 0))<.08 then return end
    local now=self.now()
    if now-(self.lastFocusChange or -math.huge)<.30 then return end
    self:focus(false)
    local actor=self.snapshot and self.snapshot.actors[tostring(self.playerId)]
    self.focusSeq=math.max(self.focusSeq+1,(actor and actor.requestGeneration or 0)+1)
    self.focusPet,self.focusPulse,self.focusPosition,self.focusYaw,self.lastFocusChange=petId,0,position,yaw,now
    self.focusAge,self.focusRetried,self.focusCharacter,self.focusPetGeneration=0,false,self.characterId(),self.petGeneration()
    remote:FireServer({kind="focus",seq=self.focusSeq,petId=petId,position=Activity.pack(position),yaw=yaw,characterId=self.focusCharacter,petGeneration=self.focusPetGeneration})
end
function Garden:step(dt)
    if not self.focusPet then return end
    if self.characterId()~=self.focusCharacter or self.petGeneration()~=self.focusPetGeneration then self:focus(false);return end
    self.focusPulse+=dt;self.focusAge+=dt
    local actor=self.snapshot and self.snapshot.actors[tostring(self.playerId)]
    if self.focusAge>=.75 and not self.focusRetried and not(actor and actor.mode=="Focus"and actor.requestGeneration==self.focusSeq)then
        self.focusRetried=true
        local remote=self.remote or ReplicatedStorage.Remotes:FindFirstChild("GardenIntent")
        if remote then remote:FireServer({kind="focus",seq=self.focusSeq,petId=self.focusPet,position=Activity.pack(self.focusPosition),yaw=self.focusYaw,characterId=self.focusCharacter,petGeneration=self.focusPetGeneration})end
    end
    if self.focusPulse>=.5 then
        self.focusPulse%=.5
        local remote=self.remote or ReplicatedStorage.Remotes:FindFirstChild("GardenIntent")
        if remote then remote:FireServer({kind="focusPulse",seq=self.focusSeq,petId=self.focusPet,characterId=self.focusCharacter,petGeneration=self.focusPetGeneration})end
    end
end
function Garden:destroy()
    self:focus(false)
    for _,connection in ipairs(self.connections)do connection:Disconnect()end
    table.clear(self.connections)
end
return Garden
