-- Edit these UI-pixel values to tune the handheld. Rojo syncs this source.
-- Rectangles are clamped into their grip; moving a control cannot cover the LCD.
local Layout = {}
Layout.Settings = {
	ScreenGap = 12, OuterMargin = 14, TopMargin = 8,
	UtilityWidth = 104, UtilityCapHeight = 30, UtilityGap = 8,
	AimBottom = 12, DropBottom = 12, QuestHeight = 68,
	-- Optional small offsets inside the safe grip (not screen coordinates).
	MenuOffsetX = 0, MenuOffsetY = 0, LoungeOffsetX = 0, LoungeOffsetY = 0,
}
local function rect(x,y,w,h)return{x=x,y=y,w=w,h=h}end
local function inside(r,host)
	r.x=math.clamp(r.x,host.x,math.max(host.x,host.x+host.w-r.w))
	r.y=math.clamp(r.y,host.y,math.max(host.y,host.y+host.h-r.h))
	return r
end
function Layout.resolve(size,ratio)
	local s=Layout.Settings
	local lateral=size.X>=350 and size.X>=size.Y*1.2
	local out={lateral=lateral,short=lateral and size.Y<280}
	if lateral then
		local h=math.min(620,size.Y-16)
		local w=math.min(1150,size.X-s.OuterMargin*2)
		local tw=math.max(1,math.min((h-24)*ratio,w-228-s.ScreenGap*2))
		local th=tw/ratio
		local x,y=(size.X-w)/2,(size.Y-h)/2
		local grip=(w-tw-s.ScreenGap*2)/2
		out.shell=rect(x,y,w,h)
		out.left=rect(x+10,y+4,grip-16,h-8)
		out.right=rect(x+w-grip+6,y+4,grip-16,h-8)
		out.tray=rect(x+grip+s.ScreenGap,y+(h-th)/2,tw,th)
		local aim=math.clamp(math.floor(h*.15),44,60)
		local drop=math.clamp(math.floor(h*.18),54,90)
		out.aimSize,out.dropSize=aim,drop
		local ay=y+h-aim-s.AimBottom-8
		out.dpad=rect(out.left.x+(out.left.w-(aim*2+6))/2,ay,aim*2+6,aim+8)
		out.drop=rect(out.right.x+(out.right.w-drop)/2,y+h-drop-s.DropBottom,drop,drop)
		local buttonW=math.max(44,math.min(s.UtilityWidth,(out.left.w-s.UtilityGap)/2))
		local ux=out.left.x+(out.left.w-buttonW*2-s.UtilityGap)/2
		local uy=if out.short then y+42 else ay-48
		out.menu=inside(rect(ux+s.MenuOffsetX,uy+s.MenuOffsetY,buttonW,44),out.left)
		out.lounge=inside(rect(ux+buttonW+s.UtilityGap+s.LoungeOffsetX,uy+s.LoungeOffsetY,buttonW,44),out.left)
		local walletY=y+(if out.short then 2 elseif h>=280 then 31 else 5)
		out.wallet=rect(out.left.x,walletY,out.left.w,if out.short then 18 else 22)
		local qy=walletY+(if out.short then 20 else 26)
		out.quest=rect(out.left.x,qy,out.left.w,if out.short then 18 else math.max(20,math.min(s.QuestHeight,uy-qy-7)))
		local queueH=if out.short then 27 else 64
		out.queue=rect(out.right.x,y+5,out.right.w,queueH)
		local meterY=out.queue.y+queueH+4
		out.meter=rect(out.right.x,meterY,out.right.w,math.max(34,math.min(56,out.drop.y-meterY-4)))
	else
		local w,h=math.min(366,size.X-24),math.min(680,size.Y-24)
		local x,y=(size.X-w)/2,(size.Y-h)/2
		local th=math.max(60,h-294);local tw=math.min(w-36,th*ratio);th=tw/ratio
		out.shell=rect(x,y,w,h);out.left=rect(x+10,y+4,w-20,h-8);out.right=out.left
		out.tray=rect(x+(w-tw)/2,y+44,tw,th)
		out.wallet=rect(x+14,y+10,(w-36)*.45,22)
		out.queue=rect(x+w*.5,y+6,w*.5-14,30)
		out.quest=rect(x+14,out.tray.y+th+8,w-28,40)
		out.meter=rect(x+14,out.quest.y+44,w-28,36)
		local by=out.meter.y+42
		out.menu=rect(x+(w-216)/2,by,104,44);out.lounge=rect(x+(w-216)/2+112,by,104,44)
		out.aimSize,out.dropSize=44,54
		out.dpad=rect(x+18,by+52,94,52);out.drop=rect(x+w-76,by+52,54,54)
	end
	local t=out.tray;out.bezel=rect(t.x-6,t.y-6,t.w+12,t.h+12)
	return out
end
return Layout
