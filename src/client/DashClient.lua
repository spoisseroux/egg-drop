-- Garden Dash client (V3-DASH-BUILD-PLAN-2026-11-22, slice S7). mount() answers nil with the build ceiling off; with
-- the runtime switch off it only watches for the switch: no instances, no connections but that one, no per-frame
-- work (RoomView.dash is nil), so the garden is the one before this build. Wire contract: DashWire.
--   * step() runs inside RoomView's RenderStepped and is protected: an error ends the race on this screen, gives the
--     camera, the controls and the pet back, and three of them turn Dash off here until the next join;
--   * the owner's pet is DashPredict; everyone else (pals too) is drawn from the 10 Hz states, at most
--     ExtrapolateTicks on; drive() is the hook RoomView and RoomCompanions put a racing pet through;
--   * held() is true from the countdown to the end of the results: menus, prompts and notices wait for it. Any other
--     screen that opens anyway takes the camera and controls back until it closes.
-- deps: remotes, roomView, playerGui, audio, state() -> nursery snapshot, reduced(), closeMenus(), modalOpen() (any
-- other screen), canRoam().
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local HttpService=game:GetService("HttpService")
local GuiService=game:GetService("GuiService")
local UserInputService=game:GetService("UserInputService")
local Shared=ReplicatedStorage.Shared
local Dash=require(Shared.Dash)
local Wire=require(Shared.DashWire)
local Sim=require(Shared.DashSim)
local Course=require(Shared.DashCourse)
local Stats=require(Shared.DashStats)
local UICopy=require(Shared.UICopy)
local Predict=require(script.Parent.DashPredict)
local RaceCamera=require(script.Parent.DashCamera)
local RaceInput=require(script.Parent.DashInput)
local Pose=require(script.Parent.DashPose)
local Props=require(script.Parent.DashProps)
local Fade=require(script.Parent.DashFade)
local Hints=require(script.Parent.DashHints)
local Results=require(script.Parent.DashResults)
local Client={};Client.__index=Client
Client.MaxErrors=3
Client.ExtrapolateTicks=40
Client.SnapCs=600
Client.Follow=12
Client.SlowEvery=.25
Client.PingEvery=.4
Client.Pings=3
Client.PendingSeconds=4
Client.ResultAfter=1.3
Client.ResultSeconds=20
Client.StaleSeconds=12 -- no result this long after the race must be over: let go
Client.PromptReach=10
Client.LIVE=table.freeze({countdown=true,race=true,results=true})
local CS=Stats.UnitsPerCs
local NONE=table.freeze({})

-- Sim.spot for a plain distance: DashCourse.at's arguments.
function Client.spot(cs,stones)
	if stones then
		if cs<Course.Fork+Course.StonesLength then return math.max(0,cs-Course.Fork),true end
		return cs+Course.Saving,false
	end
	return cs,false
end
-- How far a runner still has to go, in cs.
function Client.left(cs,stones)return Course.Length-(if stones then Course.Saving else 0)-cs end
-- A rival's drawn distance: on from its last state, never more than ExtrapolateTicks.
function Client.ahead(track,tick,unit)
	local flags=track.flags
	if flags.finished or flags.tumble or track.tick<0 then return track.cs end
	local total=Course.Length-(if flags.stones then Course.Saving else 0)
	return math.min(total,track.cs+unit*track.pace/100*math.clamp(tick-track.tick,0,Client.ExtrapolateTicks))
end

-- The gate card's picture: the start arch and the lanes from the side, with the waiting pad behind the arch.
Client.GateEye=Vector3.new(10.5,5,11) -- across the start from the pad, up, and along the course: the waiting players are behind the arch
Client.GateLook=Vector3.new(0,1,2)
function Client.gateView()
	local x,y,z,yaw=Course.at(0)
	local function spot(v)
		local s,c=math.sin(yaw),math.cos(yaw)
		return Vector3.new(x+v.X*c+v.Z*s,y+v.Y,z-v.X*s+v.Z*c)
	end
	return spot(Client.GateEye),spot(Client.GateLook)
end
function Client.mount(deps)
	if not Dash.ceiling()then return nil end
	local self=setmetatable({d=deps,userId=Players.LocalPlayer.UserId,connections={},errors=0,seq=0,isOpen=false,slow=0,pings=0,pingAt=0,rtts={}},Client)
	self.changed=Dash.changed("race"):Connect(function()self:sync()end)
	self:sync()
	return self
end
function Client:sync()
	local on=not self.dead and Dash.on()
	if on==self.isOpen then return end
	if on then
		local ok,problem=pcall(self.open,self)
		if not ok then warn("[Dash] not opened: "..tostring(problem));self.dead=true;pcall(self.close,self)end
	else pcall(self.close,self)end
end
function Client:open()
	self.isOpen=true
	local d=self.d
	local function on(signal,fn)table.insert(self.connections,signal:Connect(fn))end
	local function guarded(fn)
		return function(...)
			local ok,problem=pcall(fn,self,...)
			if not ok then self:fail(problem)end
		end
	end
	local event,state=guarded(self.event),guarded(self.receive)
	local bound={}
	local function bind(remote)
		if bound[remote.Name]then return end
		if remote.Name==Wire.Remotes.event then bound[remote.Name]=true;on(remote.OnClientEvent,event)
		elseif remote.Name==Wire.Remotes.state then bound[remote.Name]=true;on(remote.OnClientEvent,state)
		elseif remote.Name==Wire.Remotes.request then self.requestRemote=remote
		elseif remote.Name==Wire.Remotes.input then self.inputRemote=remote end
	end
	for _,name in pairs(Wire.Remotes)do
		local remote=d.remotes:FindFirstChild(name)
		if remote then bind(remote)end
	end
	on(d.remotes.ChildAdded,bind)
	local roster=guarded(self.readRoster)
	local function folder(item)
		if item.Name~="GardenState"or self.folder then return end
		self.folder=item
		on(item:GetAttributeChangedSignal(Wire.RosterAttribute),roster)
		roster()
	end
	local found=ReplicatedStorage:FindFirstChild("GardenState")
	if found then folder(found)else on(ReplicatedStorage.ChildAdded,folder)end
	self.props=Props.new(workspace)
	self.camera=RaceCamera.new()
	self.fade=Fade.new()
	self.project=function(position)
		local camera=workspace.CurrentCamera
		if not camera or not camera.WorldToViewportPoint then return nil end
		local at,seen=camera:WorldToViewportPoint(position)
		if not seen then return nil end
		return at.X,at.Y
	end
	self.ownFlags={}
	self.owner=Instance.new("Folder");self.owner.Name="DashRailOwner";self.owner.Parent=d.playerGui
	local pad=Course.Pad
	local sign=self.props:make("GateSign",Vector3.new(.2,.2,.2),Props.HoopTop)
	sign.Transparency=1
	sign.CFrame=CFrame.new(pad.x/100,pad.y/100+2.2,pad.z/100)
	self.props:balloon(0,true)
	local eye,look=Client.gateView()
	self.gateFrame=CFrame.lookAt(eye,look)
	local prompt=Instance.new("ProximityPrompt")
	prompt.Name="DashGatePrompt";prompt.ObjectText=UICopy.get("dash.title");prompt.ActionText=UICopy.get("dash.prompt")
	prompt.KeyboardKeyCode,prompt.GamepadKeyCode=Enum.KeyCode.E,Enum.KeyCode.ButtonX
	prompt.RequiresLineOfSight=false;prompt.HoldDuration=0;prompt.MaxActivationDistance=Client.PromptReach;prompt.Enabled=false
	prompt.Parent=sign
	on(prompt.Triggered,guarded(self.gate))
	self.prompt=prompt
	require(script.Parent.NotificationRail).holder=function()return self:held()end
	d.roomView.dash=self
	d.roomView.companions.dash=self
end
function Client:close()
	self.isOpen=false
	pcall(self.endSeat,self)
	local d=self.d
	d.roomView.dash=nil
	d.roomView.companions.dash=nil
	require(script.Parent.NotificationRail).holder=nil
	for _,connection in ipairs(self.connections)do connection:Disconnect()end
	table.clear(self.connections)
	-- Give back every pet a race was drawing.
	local function free(visual)if visual and visual.dashState then visual.dashState=nil;pcall(Pose.clear,visual)end end
	free(d.roomView.pet)
	for _,entry in pairs(d.roomView.companions.active)do free(entry.visual)end
	self:dropHeat()
	if self.input then self.input.destroy();self.input,self.core=nil,nil end
	if self.hud then self.hud:destroy();self.hud=nil end
	if self.props then self.props:destroy();self.props=nil end
	if self.fade then pcall(self.fade.release,self.fade);self.fade=nil end
	if self.rail then pcall(self.rail.cancel,self.rail);self.rail=nil end
	self.lineText=nil
	if self.owner then self.owner:Destroy();self.owner=nil end
	self.folder,self.requestRemote,self.inputRemote,self.roster,self.prompt,self.pending,self.queued=nil,nil,nil,nil,nil,nil,nil
end
function Client:destroy()
	self.dead=true
	self.changed:Disconnect()
	if self.isOpen then self:close()end
end
function Client:fail(problem)
	warn("[Dash] "..tostring(problem))
	self.errors+=1
	pcall(self.send,self,"leave")
	pcall(self.endSeat,self)
	if self.errors>=Client.MaxErrors then
		self.dead=true
		self:sync()
	end
end

-- What the rest of the client asks -----------------------------------------------------------------------------
function Client:held()
	local seat=self.seat
	return seat~=nil and seat.phase~="gather"
end
function Client:panelOpen()return self.card~=nil and not self.card.closed end
-- Things to do asks these two. A seat (waiting too), the line, a request on its way or a card.
function Client:engaged()return self.seat~=nil or self.queued==true or self.pending~=nil or self:panelOpen()end
-- The race as anyone sees it, or nil while Dash is off or has given up here: phase "gather" | "live" | "idle", how many
-- players wait, and whether this player has ever raced.
function Client:summary()
	if not self.isOpen or self.dead then return nil end
	local roster,count=self.roster,0
	local phase=roster and roster.phase
	if phase=="gather"then
		for _,place in ipairs(roster.seats)do if type(place)=="table"and place.pal~=true then count+=1 end end
	end
	return{phase=if phase=="gather"then"gather"elseif phase~=nil and Client.LIVE[phase]then"live"else"idle",count=count,raced=not self:newRacer()}
end
-- Opening the Pocket Deck gives up a seat: ask first. True when the question is up (do nothing else yet).
function Client:askLeave(action)
	if not self.seat or self.seat.phase=="done"then
		if self.queued then self:send("leave");self.queued=nil end
		return false
	end
	local Confirm=require(script.Parent.ConfirmDialog)
	if Confirm.isOpen()then return true end
	if self.core then self.core:loseAll()end
	self.asked=Confirm.ask({title=UICopy.get("dash.ask.title"),line=UICopy.get("dash.ask.line"),confirm=UICopy.get("dash.ask.yes"),cancel=UICopy.get("dash.ask.no"),
		onConfirm=function()
			self:leave()
			if action then action()end
		end})
	return self.asked~=nil
end
function Client:leave()
	self:send("leave")
	self:endSeat()
end
function Client:notify(key)
	local text=UICopy.get(key)
	if text==key then text=UICopy.get("dash.reason.other")end
	if self.owner then require(script.Parent.NotificationRail).enqueue(self.owner,key,{text=text,icon="•",duration=4})end
end
local function first(dash)
	if type(dash)~="table"then return true end
	local ribbons=if type(dash.ribbons)=="table"then dash.ribbons else NONE
	return dash.best==nil and dash.last==nil and(ribbons.gold or 0)+(ribbons.silver or 0)+(ribbons.bronze or 0)+(ribbons.green or 0)==0
end
-- A player who has never raced: nothing saved, and none this session (the helper, Just for Fun picked).
function Client:newRacer()return not self.raced and first(self:saved())end
function Client:saved()
	local state=self.d.state()
	return type(state)=="table"and type(state.dash)=="table"and state.dash or nil
end

-- Requests ---------------------------------------------------------------------------------------------------
function Client:send(kind,mode)
	local remote=self.requestRemote
	if not remote then return false end
	self.seq+=1
	local packet={kind=kind,seq=self.seq}
	if kind=="join"or kind=="trial"then
		local garden=self.d.roomView.garden
		local shown=self.d.roomView.shownPet
		packet.petId,packet.petGeneration,packet.characterId=shown and shown.id,garden.petGeneration(),garden.characterId()
		packet.mode=if kind=="join"then mode else nil
		self.pending={seq=self.seq,at=os.clock(),kind=kind}
	elseif kind=="ping"then self.pingSeq,self.pingSent=self.seq,os.clock()end
	remote:FireServer(packet)
	return true
end
function Client:gate()
	if self.seat or self.queued or self:panelOpen()or not self.d.canRoam()or self.d.modalOpen()then return end
	local function go(kind,mode)
		return function()
			if self.pending then return end
			self.last={kind=kind,mode=mode}
			self:send(kind,mode)
		end
	end
	-- Just for Fun to begin with; after that, whatever this player raced last.
	local picked=1
	if not self:newRacer()and self.last then picked=if self.last.kind=="trial"then 3 elseif self.last.mode=="stats"then 2 else 1 end
	self.card=require(script.Parent.DashCard).open({playerGui=self.d.playerGui,name="Gate",title=UICopy.get("dash.title"),low=true,selected=picked,
		lines={UICopy.get("dash.gate.line"),UICopy.get("dash.gate.modes")},
		buttons={{name="Fun",text=UICopy.get("dash.fun"),primary=picked==1,act=go("join","fun")},
			{name="Stats",text=UICopy.get("dash.stats"),primary=picked==2,act=go("join","stats")},
			{name="Trial",text=UICopy.get("dash.trial"),primary=picked==3,act=go("trial")}}})
	if not self.card then self:notify("dash.reason.other");return end
	self.card.gate=true
end
-- While the gate card is open the camera shows the course from the side. Any way the card goes gives it back.
function Client:gateShot()
	local room,card=self.d.roomView,self.card
	if self.shot and not room.dashHeld then -- RoomView let go by itself: not again for this card
		self.shot=false
		if card then card.shotLost=true end
	end
	local want=card~=nil and card.gate==true and not card.closed and not card.shotLost and self.seat==nil
		and room.mode=="Room"and room.target=="Room"and not self.d.modalOpen()
	if want and not self.shot then self.shot=room:enterDash(true)==true
	elseif self.shot and not want then
		self.shot=false
		room:leaveDash()
	end
	if self.shot then room:dashCamera(self.gateFrame,RaceCamera.Fov)end
end

-- Events -----------------------------------------------------------------------------------------------------
function Client:event(packet)
	if type(packet)~="table"then return end
	local kind,seat=packet.kind,self.seat
	if kind=="reply"then
		if packet.request=="ping"then
			if packet.seq==self.pingSeq and self.pingSent then
				self.pingSeq=nil
				self.rtts[(self.pings-1)%Client.Pings+1]=os.clock()-self.pingSent
			end
			return
		end
		local pending=self.pending
		if not pending or packet.seq~=pending.seq then return end
		self.pending=nil
		if packet.ok~=true then self:notify("dash.reason."..tostring(packet.reason))
		elseif packet.reason=="Queued"or packet.reason=="WrongBand"then
			self.queued=true
			self:notify("dash.reason."..packet.reason)
		end
	elseif kind=="joined"then
		if type(packet.raceId)~="string"then return end
		if seat and seat.phase=="done"then self:endSeat()end
		self.queued=nil
		self.seat={raceId=packet.raceId,mode=packet.mode,trial=packet.trial==true,phase="gather"}
		self.pings,self.pingAt=0,0
		table.clear(self.rtts)
		if packet.closer==true then self:notify("dash.reason.Far")end -- from the line, but too far from the gate
	elseif kind=="locked"then self:lock(packet)
	elseif kind=="refused"then
		self.queued=nil
		if seat and seat.phase~="done"and(packet.raceId==nil or packet.raceId==seat.raceId)then self:endSeat()end
		self:notify("dash.reason."..tostring(packet.reason))
	elseif kind=="aborted"then
		if seat and packet.r==seat.raceId then self:endSeat();self:notify("dash.reason."..tostring(packet.reason))end
	elseif kind=="cup"then self:notify("dash.newCup")
	elseif seat and seat.predict and packet.r==seat.raceId then
		if kind=="refusedInput"then
			seat.predict:refused(packet.n)
			local core=self.core
			if core then
				core.down=self:dashDown(seat)
				if not core.open then core:loseAll()end -- a refused dashUp is sent again: nobody is holding it now
			end
		elseif kind=="zoom"then
			if seat.predict:zoom(packet.tick)then self:say("dash.zoom")end
		elseif kind=="judged"then
			if seat.predict.serverRender then self:say(if packet.result==1 then "dash.perfect"elseif packet.result==2 then "dash.clear"else "dash.trip")end
		elseif kind=="result"then
			seat.phase,seat.result,seat.cardAt="done",packet,os.clock()+Client.ResultAfter
			if self.input then self.input.close()end
			if self.hud then self.hud:rest(true)end
			self:home(seat)
		end
	end
end
-- Whether the log's last word on Dash is down (a refused dashDown must be pressed again).
function Client:dashDown(seat)
	local log=seat.predict.log
	for i=#log,1,-1 do
		if log[i].k=="dashDown"then return true elseif log[i].k=="dashUp"then return false end
	end
	return false
end
function Client:rtt()
	local most=nil
	for _,value in pairs(self.rtts)do most=math.max(most or 0,value)end
	if most then return most end
	local ok,ping=pcall(Players.LocalPlayer.GetNetworkPing,Players.LocalPlayer)
	return if ok and type(ping)=="number"then ping*2 else nil
end
function Client:lock(packet)
	if type(packet.raceId)~="string"or type(packet.seat)~="number"then return end
	local seat=self.seat
	if not seat or seat.raceId~=packet.raceId then
		if seat then self:endSeat()end
		seat={raceId=packet.raceId,mode=packet.mode,trial=packet.trial==true}
		self.seat=seat
	end
	local predict=Predict.new({raceId=packet.raceId,seat=packet.seat,plan=packet.plan,levels=packet.levels,goAt=packet.goAt,lead=Predict.lead(self:rtt())})
	if not predict then
		self:leave()
		self:notify("dash.reason.other")
		return
	end
	seat.phase,seat.predict,seat.index,seat.plan,seat.goAt,seat.tag="countdown",predict,packet.seat,packet.plan,packet.goAt,Wire.tag(packet.raceId)
	seat.lane=predict.plan.lanes[1]
	seat.track={cs=0,pace=0,tick=-1,flags=NONE,draw=0}
	local mine=self:saved()
	seat.before=mine and mine.last and mine.last.op
	seat.first=self:newRacer()
	seat.hints=if seat.first then Hints.new()else nil
	self.raced=true
	if self.card then self.card:close();self.card=nil end
	self.d.closeMenus()
	if not self.heat or self.heat.raceId~=seat.raceId then self.props:show(packet.plan,self.d.reduced())end
	if workspace.StreamingEnabled then
		task.spawn(function()
			for _,share in ipairs({.35,.7,1})do
				local x,y,z=Course.at(Course.Length*share)
				pcall(Players.LocalPlayer.RequestStreamAroundAsync,Players.LocalPlayer,Vector3.new(x,y,z),5)
			end
		end)
	end
end
-- Every way a race leaves this screen. Each step on its own, so nothing can keep the camera or the controls.
function Client:endSeat()
	local seat=self.seat
	if self.input then pcall(self.input.close)end -- lets Dash go while there is still a race to tell
	self.seat,self.holding,self.shot=nil,false,false
	pcall(self.d.roomView.leaveDash,self.d.roomView)
	if self.fade then pcall(self.fade.release,self.fade)end
	if self.hud then pcall(self.hud.hide,self.hud)end
	if self.card then pcall(self.card.close,self.card);self.card=nil end
	if self.asked then pcall(self.asked.cancel);self.asked=nil end
	if seat and seat.predict and self.props then
		local heat=self.heat
		if not heat then pcall(self.props.hide,self.props)
		elseif heat.raceId~=seat.raceId then pcall(self.props.show,self.props,heat.plan,self.d.reduced())end
	end
end

-- The race everyone sees ---------------------------------------------------------------------------------------
function Client:readRoster()
	local raw=self.folder and self.folder:GetAttribute(Wire.RosterAttribute)
	local ok,value=pcall(HttpService.JSONDecode,HttpService,if type(raw)=="string"then raw else"null")
	local roster=if ok then Wire.roster(value)else nil
	self.roster=roster
	if not roster or not Client.LIVE[roster.phase]or type(roster.raceId)~="string"or type(roster.plan)~="table"or type(roster.goAt)~="number"then
		self:dropHeat()
		return
	end
	local heat=self.heat
	if not heat or heat.raceId~=roster.raceId then
		self:dropHeat()
		local level=if roster.mode=="stats"and type(roster.band)=="number"then Stats.bandMiddle(roster.band)else Stats.FunLevel
		heat={raceId=roster.raceId,tag=Wire.tag(roster.raceId),goAt=roster.goAt,plan=roster.plan,tracks={},byUser={},unit=Stats.stride(level)*100/CS}
		self.heat=heat
		if not(self.seat and self.seat.predict)then self.props:show(roster.plan,self.d.reduced())end
	end
	heat.phase=roster.phase
	table.clear(heat.byUser)
	for _,place in ipairs(roster.seats)do
		if type(place)~="table"or type(place.seat)~="number"then continue end
		local track=heat.tracks[place.seat]
		if not track then
			track={seat=place.seat,lane=roster.plan.lanes[place.seat]or place.seat,cs=0,pace=0,tick=-1,flags=NONE,draw=0,state=Pose.state()}
			heat.tracks[place.seat]=track
		end
		track.petId,track.name=place.petId,place.name
		track.pal=place.pal==true
		track.userId=if track.pal then nil else place.userId
		if track.userId then heat.byUser[track.userId]=track end
	end
end
function Client:dropHeat()
	local heat=self.heat
	self.heat=nil
	if not heat then return end
	for _,track in pairs(heat.tracks)do self:dropPal(track)end
	if self.props and not(self.seat and self.seat.predict)then self.props:hide()end
end
function Client:dropPal(track)
	local visual=track.visual
	if not visual then return end
	track.visual=nil
	if self.props then self.props:untag(track.seat)end
	pcall(visual.destroy,visual)
end
local function copy(track,seat,tick)
	if not seat or tick<track.tick then return end
	track.tick,track.cs,track.pace,track.flags=tick,seat.cs,seat.pace,seat.flags
end
function Client:receive(packed)
	local state=Wire.decode(packed)
	if not state then return end
	local seat,heat=self.seat,self.heat
	if seat and seat.predict and state.tag==seat.tag then
		local mine=state.seats[seat.index]
		if mine then
			seat.predict:observe(state.tick,mine.cs)
			copy(seat.track,mine,state.tick)
		end
	end
	if heat and state.tag==heat.tag then
		for index,entry in ipairs(state.seats)do
			local track=heat.tracks[index]
			if track then copy(track,entry,state.tick)end
		end
	end
end
local function follow(track,tick,unit,dt)
	local target=Client.ahead(track,tick,unit)
	if math.abs(target-track.draw)>Client.SnapCs then track.draw=target
	else track.draw+=(target-track.draw)*(1-math.exp(-Client.Follow*dt))end
end
local function palName(pieces)
	local Names=require(Shared.NameCatalog)
	local text=""
	for _,id in ipairs(if type(pieces)=="table"then pieces else NONE)do
		local piece=Names.ById[id]
		if piece then text=if text==""then piece.text else text.." "..piece.text end
	end
	return text
end
function Client:heatStep(dt,now,reduced)
	local heat=self.heat
	if not heat then return end
	local seat=self.seat
	local lead=if seat and seat.predict and seat.raceId==heat.raceId then seat.predict.lead else 0
	local tick=(now-heat.goAt+lead)*Stats.TicksPerSecond
	heat.running=tick>0
	local room=self.d.roomView.mode=="Room"
	local made=false
	for _,track in pairs(heat.tracks)do
		follow(track,tick,heat.unit,dt)
		if track.pal and room then
			local visual=track.visual
			if not visual and not made and not track.failed then
				made=true -- one a frame
				local pet=require(Shared.PetCatalog).byId[track.petId]
				local ok,value=pcall(function()
					local x,y,z=Course.at(0,false,track.lane)
					return require(script.Parent.PetFactory).create(workspace,Vector3.new(x,y,z),pet,0,0,false,nil,{priority=1})
				end)
				if ok then
					visual=value
					track.visual=visual
					visual.cosmeticSeed=track.seat
					Pose.begin(visual,track.state)
					local name=palName(track.name)
					if name~=""then self.props:tag(track.seat,name)end
				else track.failed=true;warn("[Dash] pal: "..tostring(value))end
			end
			if visual then
				local cs,onStones=Client.spot(track.draw,track.flags.stones)
				Pose.step(visual,track.state,cs,onStones,track.lane,track.flags,heat.running,dt,reduced)
				visual.cosmeticTime=now
				visual:update(dt)
				self.props:tagAt(track.seat,visual.origin+Vector3.yAxis*2)
			end
		elseif track.visual then self:dropPal(track)end
	end
end

-- The owner's race ---------------------------------------------------------------------------------------------
function Client:say(key)if self.hud then self.hud:say(UICopy.get(key))end end
function Client:ensureHud()
	if self.hud then return end
	self.hud=require(script.Parent.DashHud).new(self.d.playerGui,{leave=function()self:askLeave()end})
	local Confirm=require(script.Parent.ConfirmDialog)
	self.core=RaceInput.Core.new({
		press=function(kind)
			local seat=self.seat
			local packet=seat and seat.predict and seat.predict:press(kind)
			if not packet or not self.inputRemote then return false end
			self.inputRemote:FireServer(packet)
			if kind=="dashDown"then self.d.audio:play("streak_whoosh",1.1,.3)elseif kind=="jump"then self.d.audio:play("drop",1.2,.3)end
			return true
		end,
		blocked=function()return GuiService.MenuIsOpen or Confirm.isOpen()or UserInputService:GetFocusedTextBox()~=nil end})
	self.input=RaceInput.mount({core=self.core,zones=self.hud.zones,stones=self.hud.stones,leave=function()self:askLeave()end})
end
-- The pet is over the line (the result waits for the others, at most 20 s).
function Client:home(seat)
	if seat.home then return end
	seat.home=true
	self.d.audio:play("quest_complete",1,.5)
end
-- Takes or gives back the camera and controls as this frame needs them.
function Client:hold(seat)
	local room=self.d.roomView
	local want=room.mode=="Room"and room.target=="Room"and not self.d.modalOpen()
	if self.holding and not room.dashHeld then
		-- RoomView let go by itself (a mode switch that came back, a camera restore).
		self.holding=false
		self.input.close()
		self.hud:hide()
		self.fade:release()
	end
	if want and not self.holding then
		if not room:enterDash()then return false end
		self.holding,self.shot=true,false
		self:ensureHud()
		self.camera:reset()
		self.hud:show(seat.first)
		if seat.home then self.hud:rest(seat.phase=="done")end
	elseif not want and self.holding then
		self.holding=false
		self.input.close()
		self.hud:hide()
		self.fade:release()
		room:leaveDash()
	end
	return self.holding
end
local NEWS={perfect={"dash.perfect","spot_on",1},clear={"dash.clear","land",1.1},trip={"dash.trip","land",.8},clover={"dash.clover","spot_on",1.25},puff={"dash.puff","aim",.8}}
function Client:raceStep(seat,dt,now,reduced)
	local room,predict=self.d.roomView,seat.predict
	-- The Deck is opening (or opened): the seat is the server's to give up.
	if room.target~="Room"then
		self:leave()
		return
	end
	-- The lead is set by the pings of the countdown and fixed before GO.
	if not seat.leadSet and now>=seat.goAt-.9 then
		seat.leadSet=true
		if now<seat.goAt-.35 then predict.lead=Predict.lead(self:rtt())end
	end
	predict:step(now,dt)
	if seat.phase=="countdown"and predict:started()then
		seat.phase="race"
		self.d.audio:play("retry",1.1,.35)
	end
	if seat.phase~="done"and now>seat.goAt+Sim.MaxTicks/Stats.TicksPerSecond+Client.StaleSeconds then
		self:leave()
		return
	end
	local r,flags=predict.runner,self.ownFlags
	local raw
	if predict.serverRender then
		follow(seat.track,(now-seat.goAt)*Stats.TicksPerSecond,Stats.stride(Stats.FunLevel)*100/CS,dt)
		local from=seat.track.flags
		flags.air,flags.tumble,flags.stumble,flags.puff,flags.zoom,flags.dash,flags.finished=from.air,from.tumble,from.stumble,from.puff,from.zoom,from.dash,from.finished
		flags.stones=from.stones
		raw=seat.track.draw
	else
		flags.air,flags.tumble,flags.stumble,flags.puff,flags.zoom=r.air>0,r.tumble>0,r.stumble>0,r.puff>0,r.zoom>0
		flags.dash,flags.finished,flags.stones=r.dash and r.puff==0 and r.bar>=Stats.DashTick,r.finishUs~=nil,r.stones
		raw=predict:cs()
	end
	seat.raw=raw
	seat.cs,seat.onStones=Client.spot(raw,flags.stones)
	local news=if predict.serverRender then nil else predict:news()
	if not self:hold(seat)then return end
	local hud=self.hud
	if news and seat.phase=="race"then
		local entry=NEWS[news]
		hud:say(UICopy.get(entry[1]))
		self.d.audio:play(entry[2],entry[3],.4)
		if news=="clover"then self.props:pick(seat.lane)end
	end
	local racing=seat.phase=="race"and not flags.finished
	if racing then self.input.open();self.core:step()else self.input.close()end
	if flags.finished and not seat.home then hud:rest();self:home(seat)end
	-- Countdown digits, then GO.
	local until_=seat.goAt-predict.lead-now
	local digit=if until_>3 or until_<-.8 then 0 elseif until_>0 then math.ceil(until_)else -1
	if seat.digit~=digit then
		seat.digit=digit
		hud:setDigits(if digit>0 then tostring(digit)elseif digit<0 then UICopy.get("dash.go")else nil)
		if digit>0 then self.d.audio:play("count_blip",1,.4)end
	end
	local ticks=if racing and not flags.tumble and not predict.serverRender then Sim.nextJump(r)else nil
	hud:setRing(ticks)
	if seat.hints then
		local hint=seat.hints:step(dt,racing,ticks,r.next,flags.dash,news)
		hud:setHint(if hint then UICopy.get("dash.hint."..hint)else nil)
		if seat.hints.done then seat.hints=nil;hud:setHint(nil)end
	end
	hud:setBar(r.bar/r.cap,flags.puff)
	local gap=Course.Fork*CS-r.pos
	hud:setStones(racing and not r.forked and not r.wants and gap>0 and gap<=r.step*Sim.SignpostTicks)
	hud:setDot(seat.index,1-Client.left(raw,flags.stones)/Course.Length,true)
	local heat=self.heat
	if heat and heat.raceId==seat.raceId then
		local place,mine=1,Client.left(raw,flags.stones)
		for _,track in pairs(heat.tracks)do
			if track.seat~=seat.index then
				local left=Client.left(track.draw,track.flags.stones)
				if left<mine then place+=1 end
				hud:setDot(track.seat,1-left/Course.Length)
			end
		end
		if racing then hud:setPlace(place)end -- home: everyone at 0 left would read 1st
	end
	hud:step(dt)
	self.camera:step(dt,seat.cs,seat.onStones,seat.lane,flags.stones==true,flags.dash==true and seat.phase=="race",reduced)
	local c=self.camera
	local eye=Vector3.new(c.ex,c.ey,c.ez)
	local px,py,pz=Course.at(seat.cs,seat.onStones,seat.lane)
	self.fade:step(dt,eye,Vector3.new(px,py+.8,pz),seat.cs,seat.onStones==true)
	room:dashCamera(CFrame.lookAt(eye,Vector3.new(c.lx,c.ly,c.lz)),c.fov)
end
function Client:showResults(seat)
	seat.cardAt=nil
	seat.closeAt=os.clock()+Client.ResultSeconds
	local title,lines=Results.words(seat.result,self:saved(),seat.before)
	local function done()self:endSeat()end
	-- Onboarding v3 slice E: the See you tomorrow strip (nil with the nest off).
	local strip=nil
	if self.d.strip then local ok,model=pcall(self.d.strip);if ok then strip=model end end
	self.card=require(script.Parent.DashCard).open({playerGui=self.d.playerGui,name="Results",title=title,lines=lines,strip=strip,
		buttons={{name="Again",text=UICopy.get("dash.again"),primary=true,act=function()
			self:endSeat()
			if not self.pending then self:send(if seat.trial then "trial"else "join",if seat.trial then nil else seat.mode)end
		end},{name="Done",text=UICopy.get("dash.done"),act=done}},back=done})
	if self.card then self.card.results=true else done()end -- no card: never a race nobody can put away
end

-- Four times a second: the prompt, the line at the gate, pings, the saved receipt.
function Client:slowStep(now)
	local d,seat=self.d,self.seat
	local clock=os.clock()
	if self.pending and clock-self.pending.at>Client.PendingSeconds then self.pending=nil end
	if seat and seat.phase~="done"and self.pings<Client.Pings and clock>=self.pingAt and not seat.leadSet then
		self.pings+=1
		self.pingAt=clock+Client.PingEvery
		self:send("ping")
	end
	if self.prompt then
		local open=seat==nil and not self.queued and not self:panelOpen()and d.canRoam()==true
		if self.prompt.Enabled~=open then self.prompt.Enabled=open end
	end
	-- The gate card closes with the garden.
	if self.card and not self.card.closed and not self.card.results and(d.roomView.target~="Room"or d.modalOpen())then self.card:close();self.card=nil end
	self:gatherLine(now)
	if not seat or seat.phase~="done"then return end
	if seat.cardAt and clock>=seat.cardAt and not d.modalOpen()then self:showResults(seat)
	elseif self.card and self.card.results and not self.card.closed then
		local _,lines=Results.words(seat.result,self:saved(),seat.before)
		for index,text in ipairs(lines)do self.card:setLine(index,text)end
		if clock>=seat.closeAt then self:endSeat()end
	end
end
-- "Just for Fun · 2 of 8 · 12": a line on the notice rail while a seat waits.
function Client:gatherLine(now)
	local roster,seat=self.roster,self.seat
	local text=""
	if seat and seat.phase=="gather"and roster and roster.phase=="gather"and type(roster.endsAt)=="number"then
		text=UICopy.get("dash.gather",{name=UICopy.get(if roster.mode=="stats"then "dash.stats"else "dash.fun"),count=#roster.seats,left=math.max(0,math.ceil(roster.endsAt-now))})
	elseif self.queued then text=UICopy.get("dash.queue")end
	if self.lineText==text then return end
	self.lineText=text
	if not self.rail then
		if text==""or not self.owner then return end
		self.rail=require(script.Parent.NotificationRail).status(self.owner,"dash-line",{text=text,active=true,priority=2})
	end
	self.rail:update({text=text,active=text~=""})
end
function Client:frame(dt,now)
	local reduced=self.d.reduced()==true
	self.slow-=dt
	if self.slow<=0 then
		self.slow=Client.SlowEvery
		self:slowStep(now)
	end
	self:gateShot()
	self:heatStep(dt,now,reduced)
	local seat=self.seat
	if seat and seat.predict then self:raceStep(seat,dt,now,reduced)end
	if not self.props then return end -- closed by what the race just did
	self.props:step(dt)
	self.props:balloon(now,reduced)
	local pet=self.d.roomView.pet
	if self.heat then self.props:placeTags(pet and pet.origin,self.project)end
end
-- RoomView's RenderStepped, before the pets are posed.
function Client:step(dt,now)
	if not self.isOpen then return end
	local ok,problem=pcall(self.frame,self,dt,now)
	if not ok then self:fail(problem)end
end

-- Pets -------------------------------------------------------------------------------------------------------
function Client:racing(userId)
	local heat=self.heat
	return heat~=nil and heat.byUser[userId]~=nil
end
function Client:place(visual,ownerId,dt,reduced)
	local seat,heat=self.seat,self.heat
	local cs,onStones,lane,flags,running
	if ownerId==self.userId then
		-- The owner's own pet: from the prediction, until the results are put away.
		if not seat or not seat.predict or seat.cs==nil then return false end
		cs,onStones,lane,flags,running=seat.cs,seat.onStones,seat.lane,self.ownFlags,seat.predict:started()
	else
		local track=heat and heat.byUser[ownerId]
		if not track then return false end
		cs,onStones=Client.spot(track.draw,track.flags.stones)
		lane,flags,running=track.lane,track.flags,heat.running==true
	end
	local state=visual.dashState
	if not state then
		state=Pose.state()
		visual.dashState=state
		Pose.begin(visual,state)
	end
	Pose.step(visual,state,cs,onStones,lane,flags,running,dt,reduced)
	return true
end
-- True when the race drew this pet this frame. Anything else, and the garden draws it as before.
function Client:drive(visual,ownerId,dt,reduced)
	local ok,drawn=pcall(self.place,self,visual,ownerId,dt,reduced)
	if not ok then self:fail(drawn);drawn=false end
	if not drawn and visual.dashState then
		visual.dashState=nil
		pcall(Pose.clear,visual)
	end
	return drawn
end
return Client
