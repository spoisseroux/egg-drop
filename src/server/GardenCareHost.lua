local Shared=game:GetService("ReplicatedStorage").Shared
local Pets=require(Shared.PetCatalog);local Catalog=require(Shared.EggCatalog)
local Care=require(script.Parent.GardenCare)
local Host={};Host.__index=Host
function Host.new(d)
 local result=d.remotes:FindFirstChild("GardenCareResult")or Instance.new("RemoteEvent");result.Name="GardenCareResult";result.Parent=d.remotes
 local self=setmetatable({d=d,result=result},Host)
 self.care=Care.new(d.garden,{now=function()return workspace:GetServerTimeNow()end,place=d.place,validDock=d.validDock,
  result=function(id,packet)for player in pairs(d.boards)do if player.UserId==id then result:FireClient(player,packet);break end end end,
  equip=function(id,packet,entry)
   for player,board in pairs(d.boards)do if player.UserId==id then return self:switch(board,packet.targetId,packet,entry)end end
   return false,"OwnerLeft"
  end})
 d.garden.care=self.care;return self
end
function Host:bind(board)
 if board.careBound then return end;board.careBound=true
 local function complete(candidate,status)
  local pending=board.careEquip
  if not pending or pending.candidate~=candidate or board.closing or self.d.boards[board.player]~=board then return end
  board.careEquip=nil
  if status=="Saved"or status=="Superseded"then
   -- Persistence truth is independent of whether the original bay still exists.
   self.d.publishCompanion(board)
   local input=self.d.gardenInput(board)
   self.d.garden.inputs[board.player.UserId]=input
   if pending.entry then self.care:complete(board.player.UserId,pending.entry,"Saved",board.profile.companionId,board.companionGeneration or 0)
   else
    local actor=self.d.garden.actors[board.player.UserId]
    if actor then
     local point=self.d.place(input,input.anchor)
     self.d.garden:release(actor);actor.petId=board.profile.companionId;actor.petGeneration=board.companionGeneration or 0
     if point then self.care:follow(actor,input,point)else self.care:hold(actor,input,"Carried",input.carryPosition or self.d.garden:position(actor,workspace:GetServerTimeNow()))end
    end
   end
   self.d.garden:syncOne(board.player.UserId,input);self.d.garden:publish()
  elseif pending.entry then self.care:complete(board.player.UserId,pending.entry,"Rejected")end
 end
 board.profile.onCompanionSaved=function(c)complete(c,"Saved")end
 board.profile.onCompanionSuperseded=function(c)complete(c,"Superseded")end
 board.profile.onCompanionRejected=function(c)complete(c,"Rejected")end
end
function Host:switch(board,target,packet,entry)
 self:bind(board)
 if board.closing or board.mode~="Room"or not self.d.canProgress(board)or board.careEquip or board.profile.saving or board.nursery.busy or board.nursery.pending then return false,"Saving"end
 if not Pets.byId[target]or not Catalog.isOwned(self.d.inventory(board),target)then return false,"NotOwned"end
 if target==board.profile.companionId then return false,"AlreadyActive"end
 if packet and packet.revision~=board.nursery.state.revision then return false,"RevisionChanged"end
 local h=board.nursery
 local operation=if packet then "care-"..board.player.UserId.."-"..packet.seq else "shortcut-"..game:GetService("HttpService"):GenerateGUID(false)
 local candidate,reason=self.d.progress.stageCompanion(board.profile,Pets.byId[target],operation,{epoch=h.epoch,token=h.token,revision=h.state.revision,now=h.adapter.now})
 if not candidate then return false,reason end
 board.careEquip={candidate=candidate,entry=entry}
 task.defer(self.d.progress.flushOnce,board.profile)
 return true
end
function Host:request(board,packet)
 if not Care.valid(packet)then return end
 self:bind(board)
 local replay=self.care:replay(board.player.UserId,packet)
 if replay then self.result:FireClient(board.player,replay);return end
 local lane=if packet.kind=="carePulse"then "carePulseAt"else "careRequestAt"
 local now=os.clock();local interval=if packet.kind=="carePulse"then .25 else .1
 if now-(board[lane]or -math.huge)<interval then self.result:FireClient(board.player,{kind=packet.kind,seq=packet.seq,status="Rejected",reason="Throttled"});return end
 board[lane]=now
 if(packet.kind=="carePickup"or packet.kind=="carePlace"or packet.kind=="careEquip")and not self.d.canProgress(board)then
  self.result:FireClient(board.player,{kind=packet.kind,seq=packet.seq,status="Rejected",reason="Saving"});return
 end
 self.d.garden:syncOne(board.player.UserId,self.d.gardenInput(board))
 local response=self.care:request(board.player.UserId,packet)
 if response then
  if response.status=="Accepted"and(packet.kind=="carePickup"or packet.kind=="carePlace")and board.petContact then board.petContact:cancel("Carried")end
  self.d.garden:publish();self.result:FireClient(board.player,response)
 end
end
return Host
