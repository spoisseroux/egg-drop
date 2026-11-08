-- UI offset pixels inside CoreUISafeInsets. Physics/aiming use the unchanged tray aspect.
local Layout = {}
Layout.Settings = {
	ScreenGap = 14, OuterMargin = 14, ShellPadding = 12, MaxTrayHeight = 700,
	RailMin = 150, RailMax = 205, NarrowRailMin = 102,
	UtilityWidth = 104, UtilityCapHeight = 32, UtilityGap = 8,
	ControlCenter = .74, QuestHeight = 104,
	MenuOffsetX = 0, MenuOffsetY = 0, LoungeOffsetX = 0, LoungeOffsetY = 0,
}
local function rect(x,y,w,h)return{x=x,y=y,w=w,h=h}end
local function inside(r,host)
	r.x=math.clamp(r.x,host.x,math.max(host.x,host.x+host.w-r.w))
	r.y=math.clamp(r.y,host.y,math.max(host.y,host.y+host.h-r.h))
	return r
end
function Layout.resolve(size,ratio,needs)
	needs=needs or {}
	local s=Layout.Settings
	local lateral=size.X>=350 and size.X>=size.Y*1.2
	local out={lateral=lateral,short=lateral and size.Y<280}
	if lateral then
		local availableW=size.X-(if size.X<380 then 16 else s.OuterMargin*2)
		local availableH=size.Y-16
		local th=math.min(s.MaxTrayHeight,availableH-24)
		local tw=th*ratio
		local regular=availableH>=460 and availableW>=tw+s.RailMin*2+s.ScreenGap*2+s.ShellPadding*2
		local h=if regular then th+24 else math.min(460,availableH)
		th=math.min(th,h-24);tw=th*ratio
		local aim=math.clamp(math.floor(h*.15),44,60)
		local drop=math.clamp(math.floor(h*.18),54,90)
		local baseMinimum=math.max(s.NarrowRailMin,aim*2+12)
		local widthCeiling=(availableW-120*ratio-s.ScreenGap*2-s.ShellPadding*2)/2
		local railMaximum=math.max(baseMinimum,math.min(s.RailMax,widthCeiling))
		local utilityRail=(needs.utilityWidth or 44)*2+s.UtilityGap
		local canWiden=utilityRail<=railMaximum
		local minimumRail=math.max(if regular then s.RailMin else baseMinimum,if canWiden then utilityRail else 0)
		local dense=(needs.lineHeight or 0)>18 and h<340 and railMaximum>=math.max(120,(needs.countWidth or 60)+52)
		if dense then minimumRail=railMaximum end
		local roomy=regular and size.X>=1000 and size.Y>=650
  if roomy then
   -- The tray has already been solved. Wider enamel rails spend only surplus
   -- desktop width; compact and portrait cases keep their established geometry.
   local target=(1.52*(th+24)-tw-s.ScreenGap*2-s.ShellPadding*2)/2
   railMaximum=math.max(railMaximum,math.min(target,(availableW-tw-s.ScreenGap*2-s.ShellPadding*2)/2))
  end
  local rail=if roomy then math.clamp((1.52*(th+24)-tw-s.ScreenGap*2-s.ShellPadding*2)/2,minimumRail,railMaximum)else math.clamp(tw*(if regular then .43 else .48),minimumRail,math.max(minimumRail,railMaximum))
  out.roomy=roomy
		tw=math.max(1,math.min(tw,availableW-rail*2-s.ScreenGap*2-s.ShellPadding*2))
		th=tw/ratio
		local w=tw+rail*2+s.ScreenGap*2+s.ShellPadding*2
		h=if regular then th+24 else h
		local x,y=(size.X-w)/2,(size.Y-h)/2
		out.regular=regular;out.dense=dense
		out.shell=rect(x,y,w,h)
		out.left=rect(x+s.ShellPadding,y+4,rail,h-8)
		out.right=rect(x+w-s.ShellPadding-rail,y+4,rail,h-8)
		out.tray=rect(x+s.ShellPadding+rail+s.ScreenGap,y+(h-th)/2,tw,th)
		out.aimSize,out.dropSize=aim,drop
		local center=if out.short then y+h-4-math.max(aim+8,drop)/2 else y+h*s.ControlCenter
		local ay=center-(aim+8)/2
		out.dpad=rect(out.left.x+(rail-(aim*2+6))/2,ay,aim*2+6,aim+8)
		out.drop=rect(out.right.x+(rail-drop)/2,center-drop/2,drop,drop)
		local walletY=y+(if out.short then 2 elseif roomy then 84 else 38)
		out.wallet=rect(out.left.x,walletY,rail,if out.short then math.max(18,needs.lineHeight or 18) else math.max(28,needs.walletLineHeight or 28))
		local qy=walletY+out.wallet.h+(if out.short then 2 else 8)
		local minimumQuest=math.max(if out.short then 18 else 20,needs.lineHeight or 0)
		local minUtilityY=qy+minimumQuest+8
		local utilityHeight=if roomy then math.max(52,(needs.utilityHeight or 44)+8)else 44
  local stackedY=if roomy then ay-utilityHeight*2-12 else ay-108
  local defaultY=if out.short then y+42 elseif roomy then ay-utilityHeight-8 else ay-60
		local sideWidth=math.max(44,math.min(s.UtilityWidth,(rail-s.UtilityGap)/2))
		local needsStack=sideWidth<(needs.utilityWidth or 44)
		local stack=needsStack and rail>=(needs.utilityWidth or 44) and stackedY>=minUtilityY
		out.compactUtilities=needsStack and not stack
		local buttonW=if stack then rail else sideWidth
		local ux=if stack then out.left.x else out.left.x+(rail-buttonW*2-s.UtilityGap)/2
		local uy=if stack then stackedY elseif minUtilityY+utilityHeight<=ay-4 then math.max(defaultY,minUtilityY) else defaultY
		out.menu=inside(rect(ux+s.MenuOffsetX,uy+s.MenuOffsetY,buttonW,utilityHeight),out.left)
		out.lounge=inside(rect((if stack then ux else ux+buttonW+s.UtilityGap)+s.LoungeOffsetX,uy+(if stack then utilityHeight+8 else 0)+s.LoungeOffsetY,buttonW,utilityHeight),out.left)
		out.quest=rect(out.left.x,qy,rail,if out.short then minimumQuest else math.max(minimumQuest,math.min(s.QuestHeight,uy-qy-8)))
		local queueH=if out.short then math.max(27,needs.queueHeight or 27) else math.max(27,needs.queueHeight or 44)
		out.queue=rect(out.right.x,y+8,rail,queueH)
		local meterY=out.queue.y+queueH+6
		out.meter=rect(out.right.x,meterY,rail,math.max(34,math.min(72,out.drop.y-meterY-8)))
		if dense then
			local line=needs.lineHeight
			out.quest=rect(out.left.x,y+4,rail,line)
			local utilityW=(rail-s.UtilityGap)/2
			local utilityY=math.min(y+line+12,out.dpad.y-46)
			out.menu=rect(out.left.x,utilityY,utilityW,44)
			out.lounge=rect(out.left.x+utilityW+s.UtilityGap,utilityY,utilityW,44)
			out.compactUtilities=utilityW<(needs.utilityWidth or 44)
			local denseDrop=if rail<180 then 44 else drop
			out.dropSize=denseDrop;out.drop.w,out.drop.h=denseDrop,denseDrop
			out.drop.x=out.right.x+rail-denseDrop;out.drop.y=y+h-4-denseDrop
			local ledgerW=rail-denseDrop-8
			local bottom=out.drop.y+denseDrop
			out.meter=rect(out.right.x,bottom-line*2-2,ledgerW,line)
			out.wallet=rect(out.right.x,bottom-line,ledgerW,line)
			if out.queue.y+out.queue.h>out.meter.y-4 then out.inlineQueue=true;out.queue.h=line end
		end
	else
		local w,h=math.min(440,size.X-24),math.min(900,size.Y-24)
		local x,y=(size.X-w)/2,(size.Y-h)/2
		local compact=h<440
		local qh=if compact then 40 else 72
		local reserve=226+qh
		local th=math.max(1,h-reserve);local tw=math.min(w-36,th*ratio);th=tw/ratio
		out.shell=rect(x,y,w,h);out.left=rect(x+10,y+4,w-20,h-8);out.right=out.left
		out.tray=rect(x+(w-tw)/2,y+44,tw,th)
		out.wallet=rect(x+14,y+6,(w-36)*.45,math.max(24,needs.lineHeight or 24))
		out.queue=rect(x+w*.5,y+6,w*.5-14,math.max(30,needs.lineHeight or 30))
		out.quest=rect(x+14,out.tray.y+th+8,w-28,qh)
		out.meter=rect(x+14,out.quest.y+qh+4,w-28,40)
		local by=out.meter.y+48
		out.menu=rect(x+(w-216)/2,by,104,44);out.lounge=rect(x+(w-216)/2+112,by,104,44)
		out.aimSize,out.dropSize=44,54
		out.dpad=rect(x+18,by+52,94,52);out.drop=rect(x+w-76,by+52,54,54)
	end
	-- Freeze the authored speaker seat before any passive instrument fitting.
	out.speaker=rect(out.right.x+out.right.w-45,out.shell.y+out.shell.h-36,36,16)
	out.speakerVisible=out.lateral and out.drop.y-(out.meter.y+out.meter.h)>80
	local t=out.tray;out.bezel=rect(t.x-6,t.y-6,t.w+12,t.h+12)
	return out
end
-- Content can consume less than the legacy well without moving any input seat.
-- The caller supplies native measured text heights; this module stays pure.
function Layout.fitFieldQuest(layout,measuredHeight)
	layout.quest.h=math.max(1,math.min(layout.quest.h,measuredHeight))
	return layout
end
-- Recompose only passive rail instruments after their native text is measured.
-- Input seats and LCD geometry from resolve remain byte-for-byte untouched.
function Layout.fitInstruments(layout,meterHeight)
	layout.meter.h=math.max(1,math.min(layout.meter.h,meterHeight or layout.meter.h))
	layout.instrumentShiftLeft,layout.instrumentShiftRight=0,0
	if not layout.lateral or layout.short or layout.dense then return layout end
	local target=math.floor(layout.shell.h*.06+.5)
	local leftBottom=math.max(layout.wallet.y+layout.wallet.h,layout.quest.y+layout.quest.h)
	local leftLimit=math.min(layout.menu.y,layout.lounge.y,layout.dpad.y)-8
	local left=math.max(0,math.min(target,leftLimit-leftBottom))
	local bottom=layout.meter.y+layout.meter.h
	local rightLimit=layout.drop.y-(if layout.roomy then layout.right.w*.92 else 8)
	local right=math.max(0,math.min(target,rightLimit-bottom))
	layout.wallet.y+=left;layout.quest.y+=left
	layout.queue.y+=right;layout.meter.y+=right
	layout.instrumentShiftLeft,layout.instrumentShiftRight=left,right
	return layout
end
return Layout
