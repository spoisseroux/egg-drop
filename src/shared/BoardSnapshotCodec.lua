-- Deck network rework S1 (deck-network-plan.md, architect review section 5): one board
-- snapshot as a buffer for the owner's UnreliableRemoteEvent.
-- Header: u16 resetId, u32 tick, u8 flags, u8 count. Per ball: u16 id, i16 x, i16 y,
-- positions in 1/1000 stud (+/-32.767; the board is 11 x 19). 8 + 6 x 32 = 200 bytes.
-- Pure Luau (buffer only): no Roblox types, so specs run offline too.
local Codec={}
Codec.HeaderBytes,Codec.BallBytes=8,6
Codec.Scale=1000
Codec.MaxBalls=140 -- 8 + 6 x 140 = 848 bytes, under the 900-byte unreliable payload limit
Codec.Paused=1 -- flags bit 0: the board is not stepping (menu, round over, not ready)

local function quantize(value)
 local q=math.round(value*Codec.Scale)
 if q>32767 then return 32767 elseif q<-32767 then return -32767 end
 return q
end

-- `scratch` (optional) is reused when it is large enough; returns a buffer sized exactly.
function Codec.encode(resetId,tick,flags,ids,xs,ys,count,scratch)
 count=math.clamp(count,0,Codec.MaxBalls)
 local size=Codec.HeaderBytes+Codec.BallBytes*count
 local b=if scratch and buffer.len(scratch)==size then scratch else buffer.create(size)
 buffer.writeu16(b,0,resetId%65536)
 buffer.writeu32(b,2,tick%4294967296)
 buffer.writeu8(b,6,flags%256)
 buffer.writeu8(b,7,count)
 local offset=Codec.HeaderBytes
 for i=1,count do
  buffer.writeu16(b,offset,ids[i]%65536)
  buffer.writei16(b,offset+2,quantize(xs[i]))
  buffer.writei16(b,offset+4,quantize(ys[i]))
  offset+=Codec.BallBytes
 end
 return b
end

-- Fills ids/xs/ys (reused tables) and returns resetId, tick, flags, count; nil if malformed.
function Codec.decode(b,ids,xs,ys)
 if type(b)~="buffer"then return nil end
 local length=buffer.len(b)
 if length<Codec.HeaderBytes then return nil end
 local count=buffer.readu8(b,7)
 if length~=Codec.HeaderBytes+Codec.BallBytes*count then return nil end
 local offset=Codec.HeaderBytes
 for i=1,count do
  ids[i]=buffer.readu16(b,offset)
  xs[i]=buffer.readi16(b,offset+2)/Codec.Scale
  ys[i]=buffer.readi16(b,offset+4)/Codec.Scale
  offset+=Codec.BallBytes
 end
 return buffer.readu16(b,0),buffer.readu32(b,2),buffer.readu8(b,6),count
end

-- The wire id of a ball (EggId wraps at 65536; two live balls on one board never collide).
function Codec.wireId(eggId)return eggId%65536 end

return Codec
