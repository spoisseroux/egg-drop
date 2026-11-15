local p=game.Players.LocalPlayer;local g=p.PlayerGui;local A=require(p.PlayerScripts.Client.BoardAudio);local a=A.new();a:setMusicEnabled(false);a:setVolume(1)
local rows={};local d;local original=a.play
a.play=function(self,name,speed,volume,owner)
 local accepted=original(self,name,speed,volume,owner)
 if name:find('hatch_')then table.insert(rows,{name=name,speed=speed,gain=volume,accepted=accepted,age=d and d.cinematic and d.cinematic.age or 0});g:SetAttribute('NativeRealAudioEvents',game.HttpService:JSONEncode(rows))end
 return accepted
end
d=require(script.Driver).new(p.PlayerScripts.Client,g,{audio=a})
local deadline=os.clock()+12;repeat task.wait(.05)until(a.voices.hatch_finish[1].IsLoaded and a.voices.hatch_display_material[1].IsLoaded)or os.clock()>deadline
g:SetAttribute('NativeRealAudioReady',a.voices.hatch_finish[1].IsLoaded and a.voices.hatch_display_material[1].IsLoaded)
g:SetAttribute('NativeRealAudioAsset',a.voices.hatch_finish[1].SoundId);g:SetAttribute('NativeRealAudioDuration',a.voices.hatch_finish[1].TimeLength)
script.Destroying:Connect(function()d:destroy();a:destroy()end)