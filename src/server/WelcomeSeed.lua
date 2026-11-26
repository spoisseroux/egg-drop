-- A fixed three-egg opener, normal manual aim/solver, one tested demo aim.
-- No charge or reward is created here. Solver evidence records actual aim coverage.
local Config=require(game:GetService("ReplicatedStorage").Shared.BoardConfig)
local Seed={DemoAim=.5}
local starter=table.freeze({table.freeze({x=-1.5,tier=1}),table.freeze({x=.7,tier=1}),table.freeze({x=2.75,tier=2})})
-- The First Hatch (Onboard "opener", artifacts/onboarding-2026-11-26/PLAN.md): six balls recorded where they come to
-- rest (x and y, so nothing moves before the first drop), whose first drop sets off a three-step chain (1+1, 2+2,
-- 3+3, to tier IV). Found by a search over the real BoardSimulation in Studio (2026-11-26): a 3-chain at 81/81 first
-- aims on Springy (the Welcome preset) and on Gentle, no aim without a merge, dropped at once or after 10 s at rest.
local function at(x,y,tier)return table.freeze({x=x,y=y,tier=tier})end
local opener=table.freeze({at(1.142,.720,1),at(-3.004,.722,1),at(-1.277,1.040,2),at(2.871,1.042,2),at(.486,2.767,3),
	at(2.636,2.781,1)})
Seed.Opener=opener
function Seed.options(useOpener)return {starter=if useOpener then opener else starter,contactGate=true}end
function Seed.create(simulation,preset,serial,drops,useOpener)
	local board=simulation.new(preset,serial,Seed.options(useOpener))
	board.welcomeOpener=useOpener==true or nil
	board.drops=drops or 0
	board.queue=table.clone(Config.Queue)
	-- Preserve absolute drop count on a cap refresh while selecting one matching opener.
	board.queue[board.drops%#board.queue+1]=1
	board.welcomeOpening=true
	return board
end
function Seed.afterMerge(board)
	if not board.welcomeOpening then return false end
	board.welcomeOpening=nil;board.queue=nil;board.contactGate=false;return true
end
function Seed.needsRefresh(board)
	if #board.eggs>=Config.MaxEggs then return true end
	-- Welcome has no loss line: an otherwise legal drop can be blocked at spawn
	-- before MaxEggs. Refresh only after the last falling egg has settled.
	if board.fallingId and(board.dropAge or 0)<1.8 then return false end
	local position=Config.launchPosition()
	local radius=Config.Tiers[(board.queue or Config.Queue)[board.drops%#(board.queue or Config.Queue)+1]].radius
	for _,egg in ipairs(board.eggs)do
		if (egg.position-position).Magnitude<egg.radius+radius then return true end
	end
	return false
end
-- Replacement simulation only: caller retains the same WelcomeState, charge,
-- run sequence, timer, grant latch and score. No reset()/RoundOver/payout call.
function Seed.refresh(simulation,board)
	return Seed.create(simulation,board.preset,board.serial,board.drops,board.welcomeOpener)
end
return Seed
