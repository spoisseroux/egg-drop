-- Glow steps (artifacts/qa-2026-11-27-beta37/ONBOARDING-V3-BRIEF.md section 2, switch Onboard "trail2"): the look of
-- every trail (PetTrail's prints to the pet and ThingsTrail's Show me prints). Pure and shared: the numbers, the pulse
-- wave that runs toward the target, the target ring's ripple, the off-screen chip's pulse, Reduced Motion's breathing,
-- the pop in and pop away, and the "when a pet leads" bookkeeping (Glow.lead: the pet's own prints, at most LeadMax).
-- The client view is GlowSteps; the trails ask Glow.on() once when they start, so a mid-trail flip never half-switches
-- it. Off is today's trails exactly. Spec: scripts/TrailGlow.spec.lua (offline and Studio).
local Glow={}
Glow.Feature="trail2"
-- The print: a paw, 1.3 studs (was 1.1), a cream core and a soft gold ring at 1.6x the print, 50% see-through.
Glow.Size=1.3
Glow.Core=Color3.fromHex("#FFF4DC")
Glow.Gold=Color3.fromHex("#FFD86B")
Glow.Halo=1.6         -- the ring's diameter, in prints
Glow.HaloSee=.5       -- the ring's see-through
Glow.HaloThickness=.07 -- the ring's line, in prints
Glow.See=.30          -- the core's see-through at rest
Glow.LightInfluence=0 -- so it reads at night
-- The pulse wave: every Period s a wave runs toward the target, Gap s apart per print. Each print swells 1 to Swell and
-- back and clears to PulseSee over Pulse s; its ring ripples out from Halo to RippleTo prints and fades over Ripple s.
Glow.Period=1.2
Glow.Gap=.10
Glow.Pulse=.30
Glow.Swell=1.35
Glow.PulseSee=.05
Glow.Ripple=.4
Glow.RippleTo=2.2
-- The print's part spans the ripple at its widest, so nothing is clipped: Canvas prints square.
Glow.Canvas=Glow.RippleTo
-- The target ring: gold, radius 2.2 studs, a ripple out to TargetRippleTo over TargetRipple s each time the wave lands.
Glow.TargetRadius=2.2
Glow.TargetThickness=6
Glow.TargetSee=.1
Glow.TargetRipple=.6
Glow.TargetRippleTo=1.35
-- The screen-edge chip pulses 1 to ChipPulse with the wave landing.
Glow.ChipPulse=1.15
-- Reduced Motion: no swell or ripple; the core's see-through breathes See to BreatheLow at BreatheHz.
Glow.BreatheHz=.5
Glow.BreatheLow=.15
Glow.BreatheStep=.02 -- write the breath only when it has moved this much (a few writes a second, not every frame)
-- Prints farther than this from the camera stay at rest (nothing to see swell from there).
Glow.AnimateWithin=110
-- The paw art faces the SurfaceGui's top edge, the part's -Z (as PetTrail.TopFaceYaw).
Glow.TopFaceYaw=0
-- When a pet leads: its own prints pop in under its feet (0 to PopPeak to 1 in PopIn s) every LeadStep studs, left and
-- right of its way, with a soft `pat` tick at most one per PatGap s. Prints the player walks over (within WalkOver
-- studs) pop away (PopAway s) with Sparkles gold sparkles; prints the player has passed go quietly. At most LeadMax.
Glow.PopIn=.15
Glow.PopPeak=1.2
Glow.PopAway=.2
Glow.PopAwayTo=1.3
Glow.Sparkles=2
Glow.LeadMax=12
Glow.LeadStep=2.2
Glow.LeadSide=.35
Glow.WalkOver=1.1
Glow.Behind=4         -- a print this much farther from the pet than the player is has been passed
Glow.FeetDrop=4       -- a leading pet's pivot is at most this far over the ground its print lies on
Glow.PatGap=.18
-- STAND-IN for the new `pat` cue (gain .12): the catalogue's `desc_tick` placeholder (BoardAudio), pitched up. Swap the
-- cue name here when the real `pat` is uploaded. No new upload, no outside asset.
Glow.PatCue=table.freeze({name="desc_tick",speed=1.4,gain=.12})
Glow.SparkleColor=Color3.fromHex("#FFD86B")

-- The switch. `read(feature)` defaults to Onboard.on (specs pass their own).
function Glow.on(read)
	if read==nil then
		local ok,Onboard=pcall(require,script.Parent.Onboard)
		if not ok then return false end
		read=Onboard.on
	end
	local ok,value=pcall(read,Glow.Feature)
	return ok and value==true
end

-- Seconds into print `index`'s own cycle at `t` (index 1 = nearest the player: the wave runs from there to the target).
-- Floating point can leave a hair under 0 (a / b rounding up to a whole number): clamp it.
local function wrap(x)
	local p=x%Glow.Period
	return if p<0 or p>=Glow.Period then 0 else p
end
function Glow.phase(t,index)
	return wrap(t-(index-1)*Glow.Gap)
end
-- Reduced Motion's breath: See at t = 0, BreatheLow half a breath later.
function Glow.breathe(t)
	local w=(1-math.cos(2*math.pi*Glow.BreatheHz*t))*.5
	return Glow.See-(Glow.See-Glow.BreatheLow)*w
end
-- Print `index` at `t`: core scale, core see-through, ring ripple scale (in prints) and ripple see-through (1 = hidden).
function Glow.wave(t,index,reduced)
	if reduced then return 1,Glow.breathe(t),Glow.Halo,1 end
	local p=Glow.phase(t,index)
	local scale,see=1,Glow.See
	if p<Glow.Pulse then
		local s=math.sin(p/Glow.Pulse*math.pi)
		scale=1+(Glow.Swell-1)*s
		see=Glow.See-(Glow.See-Glow.PulseSee)*s
	end
	local rippleScale,rippleSee=Glow.Halo,1
	if p<Glow.Ripple then
		local v=p/Glow.Ripple
		rippleScale=Glow.Halo+(Glow.RippleTo-Glow.Halo)*v
		rippleSee=Glow.HaloSee+(1-Glow.HaloSee)*v
	end
	return scale,see,rippleScale,rippleSee
end
-- Is print `index` moving at `t` (its swell or its ripple)? Outside that window it rests: nothing to write.
function Glow.moving(t,index,reduced)
	if reduced then return false end
	return Glow.phase(t,index)<math.max(Glow.Pulse,Glow.Ripple)
end
-- When the wave lands on the target: as if the target were print count + 1.
function Glow.landing(t,count)
	return wrap(t-math.max(0,count or 0)*Glow.Gap)
end
-- The target ring's ripple at `t` with `count` prints: scale (1 = the ring) and see-through (1 = hidden).
function Glow.target(t,count,reduced)
	if reduced then return 1,1 end
	local p=Glow.landing(t,count)
	if p>=Glow.TargetRipple then return 1,1 end
	local v=p/Glow.TargetRipple
	return 1+(Glow.TargetRippleTo-1)*v,.2+.8*v
end
-- The off-screen chip's scale at `t`: a swell to ChipPulse as the wave lands. Reduced Motion: still.
function Glow.chip(t,count,reduced)
	if reduced then return 1 end
	local p=Glow.landing(t,count)
	if p>=Glow.Pulse then return 1 end
	return 1+(Glow.ChipPulse-1)*math.sin(p/Glow.Pulse*math.pi)
end
-- A lead print `age` s after it was laid: its scale, 0 to PopPeak to 1 in PopIn s. Reduced Motion: there at once.
function Glow.popIn(age,reduced)
	if reduced or age>=Glow.PopIn then return 1 end
	if age<=0 then return 0 end
	local u=age/Glow.PopIn
	if u<.6 then return Glow.PopPeak*math.sin(u/.6*math.pi*.5)end
	return Glow.PopPeak+(1-Glow.PopPeak)*((u-.6)/.4)
end
-- A print the player walked over, `age` s on: scale and see-through; done once see-through reaches 1.
function Glow.popAway(age,reduced)
	local u=math.clamp(age/Glow.PopAway,0,1)
	if reduced then return 1,Glow.See+(1-Glow.See)*u end
	return 1+(Glow.PopAwayTo-1)*u,Glow.See+(1-Glow.See)*u
end
-- A guide trail (its prompt is open) has no time end and hides, not ends, while a menu, the deck or a trip out of the
-- garden is up. `reason` is the end the trail would take today; the answer is the end it takes, "hide", or nil.
function Glow.guideEnd(reason,guide)
	if not guide or reason==nil then return reason end
	if reason=="time"then return nil end
	if reason=="menu"or reason=="deck"or reason=="left"then return "hide"end
	return reason
end

-- ── When a pet leads ────────────────────────────────────────────────────────
-- Glow.lead(max): the pet's prints, a fixed pool of `max` slots (no tables made per frame). lead:step(now, pet, player)
-- with flat-ground Vector3s (the pet's feet, the player's feet) lays, pops and evicts; after it `lead.laid` holds the
-- slot just laid (or 0), `lead.pat` whether to tick, and `lead.popped` the slots the player walked over this step (for
-- the sparkles). A slot: {on, x, y, z, yaw, side, born, seq, gone (nil, or when it began to pop), sparkle}.
local Lead={};Lead.__index=Lead
local function flatDistance(ax,az,bx,bz)local dx,dz=ax-bx,az-bz;return math.sqrt(dx*dx+dz*dz)end
function Glow.lead(max)
	local self=setmetatable({max=max or Glow.LeadMax,slots={},popped={},laid=0,pat=false,patAt=-math.huge,seq=0,side=1,held=false},Lead)
	for i=1,self.max do self.slots[i]={on=false,x=0,y=0,z=0,yaw=0,side=1,born=0,seq=0,gone=nil,sparkle=false}end
	return self
end
-- Live (not popping) prints.
function Lead:count()
	local n=0
	for _,slot in ipairs(self.slots)do if slot.on and slot.gone==nil then n+=1 end end
	return n
end
-- Rank of a slot among the live prints, oldest (nearest the player, the wave's start) first: seq - oldest + 1.
function Lead:oldest()
	local low=math.huge
	for _,slot in ipairs(self.slots)do if slot.on and slot.gone==nil and slot.seq<low then low=slot.seq end end
	return if low==math.huge then 0 else low
end
-- Hold: lay nothing new (the pet runs back to the player for a nudge); pops still happen.
function Lead:hold(on)self.held=on==true end
function Lead:clear()
	for _,slot in ipairs(self.slots)do slot.on=false;slot.gone=nil end
	self.last=nil;self.laid=0;self.pat=false
	table.clear(self.popped)
end
-- Pure: the slot to lay into when every slot is taken: of the live prints (never the one being laid), the one farthest
-- from the player, so the LeadMax kept are the ones nearest the player. A slot still popping is free first.
function Glow.evict(slots,px,pz)
	local pick,far=nil,-1
	for i,slot in ipairs(slots)do
		if not slot.on then return i end
		if slot.gone~=nil then pick,far=i,math.huge end
	end
	if pick then return pick end
	for i,slot in ipairs(slots)do
		local d=flatDistance(slot.x,slot.z,px,pz)
		if d>far then pick,far=i,d end
	end
	return pick
end
function Lead:step(now,pet,player)
	self.laid,self.pat=0,false
	table.clear(self.popped)
	-- Pops finish; walked-over and passed prints begin to pop.
	for i,slot in ipairs(self.slots)do
		if slot.on then
			if slot.gone~=nil then
				if now-slot.gone>=Glow.PopAway then slot.on=false;slot.gone=nil end
			elseif player then
				local mine=flatDistance(slot.x,slot.z,player.X,player.Z)
				if mine<=Glow.WalkOver then
					slot.gone,slot.sparkle=now,true
					table.insert(self.popped,i)
				elseif pet and flatDistance(slot.x,slot.z,pet.X,pet.Z)>flatDistance(player.X,player.Z,pet.X,pet.Z)+Glow.Behind and mine>Glow.WalkOver*2 then
					slot.gone,slot.sparkle=now,false
				end
			end
		end
	end
	if not pet then return self end
	if self.last==nil then self.last=Vector3.new(pet.X,pet.Y,pet.Z);return self end
	local dx,dz=pet.X-self.last.X,pet.Z-self.last.Z
	local moved=math.sqrt(dx*dx+dz*dz)
	if moved<Glow.LeadStep then return self end
	self.last=Vector3.new(pet.X,pet.Y,pet.Z)
	if self.held then return self end
	-- Not under the player's own feet (it would pop at once).
	if player and flatDistance(pet.X,pet.Z,player.X,player.Z)<=Glow.WalkOver*1.5 then return self end
	local ux,uz=dx/moved,dz/moved
	self.side=-self.side
	local at=Glow.evict(self.slots,if player then player.X else pet.X,if player then player.Z else pet.Z)
	local slot=self.slots[at]
	self.seq+=1
	slot.on,slot.gone,slot.sparkle=true,nil,false
	slot.x,slot.y,slot.z=pet.X+(-uz)*Glow.LeadSide*self.side,pet.Y,pet.Z+ux*Glow.LeadSide*self.side
	-- The yaw that turns a part's -Z (the toes) along the way: LookVector of CFrame.Angles(0, yaw, 0) is (-sin, 0, -cos).
	slot.yaw=math.atan2(-ux,-uz)
	slot.side,slot.born,slot.seq=self.side,now,self.seq
	self.laid=at
	if now-self.patAt>=Glow.PatGap then self.pat,self.patAt=true,now end
	return self
end
Glow.Lead=Lead

return table.freeze(Glow)
