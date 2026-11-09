-- The actual Room mode runner must wake a hatch opened under its busy owner.
return function(client,parent)
    local Room=require(client.RoomView)
    local Hatch=require(client.EggHatchView)
    local root=Instance.new("Frame");root.Size=UDim2.fromOffset(600,500);root.Parent=parent
    local view=Hatch.new(root,{play=function()end},function()return false end,function()error("no purchase or acknowledgment")end)
    local room=setmetatable({mode="Board",target="Room",shownPet={cue="pet"},audio={play=function()end},
        overlayOpen=function()return false end,updateControls=function()end,
        transition={begin=function()return nil end,hide=function()end}},Room)
    local covered=false
    view.ownsPresentation=function()return not room.busy end
    room.onPresentationOwnerChanged=function()view.cinematic:refreshOwner()end
    room.show=function()
        view:open({status="Ready",revision=1,nectar=6,lastHatch={id="busy-owned-starter",petId="pip",starter=true}})
        covered=room.busy and view.lastPresentedId==nil and view.cinematic.connection==nil
    end
    room:driveModes(true)
    for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end
    assert(covered,"first visible hatch must wait for the active transition owner")
    assert(not room.busy and view.lastPresentedId=="busy-owned-starter" and view.cinematic.active and view.cinematic.connection,
        "busy completion must start the deferred reveal without a later attribute update")
    local epoch=view.cinematic.epoch;room:setBusy(false);assert(view.cinematic.epoch==epoch)
    view:close();view.shade:Destroy();root:Destroy()
    return {passed=1,cases={"mode runner publishes busy owner edges and wakes deferred first hatch once"}}
end
