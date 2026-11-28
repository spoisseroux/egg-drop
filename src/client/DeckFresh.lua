-- Fresh reopen (DECK-FEEL-BRIEF 5; Spencer beta 40 note 13: "when opening the pocket deck again the old balls from the
-- last game are briefly visible"). Old balls must never draw.
--
-- The bug (Opus, at 25f0f9a8): the ball sprite views rebuild on a ResetId change, but the pixel LCD keeps its last
-- frame; while the deck is hidden or not presentable the render loop returned early without clearing it, and the
-- transition's lit fade (Boot:fade) runs before RoomView clears `busy`, so the old frame showed through the fade.
-- The fix, ALWAYS ON (a bug fix, not behind the switch): the LCD remembers the serial it last drew; whenever the deck
-- is not presenting and that serial is not the board's current ResetId, the LCD image is hidden; it shows again only
-- after a frame of the new serial has been drawn (JellyLCD:finishFrame).
--
-- Behind Alive "deckfeel" as well: at the end of the close's Sink (under the opaque shade) the LCD forgets its frame,
-- so a reopen always draws fresh; a resumed unfinished round's balls then come in by row, bottom up, 40 ms a row
-- (.3 s at most), with no physics pop; a new round's empty well lets the held ball's drop be the first thing to move.
local Fresh={}

-- Pure: may the LCD image show a frame drawn for `drawnSerial` while the board is on `currentSerial`?
function Fresh.labelVisible(drawnSerial,currentSerial)
 return drawnSerial~=nil and drawnSerial==currentSerial
end

-- The tracker the render loop keeps: which serial the LCD's image holds.
function Fresh.new()return{drawn=nil}end
-- A frame of `serial` has been drawn and shown.
function Fresh.drew(state,serial)state.drawn=serial end
-- The image is gone (closed under the shade, or the LCD was rebuilt).
function Fresh.forget(state)state.drawn=nil end
-- Called on every early return (hidden or not presentable): returns whether the image may stay visible.
function Fresh.keep(state,currentSerial)return Fresh.labelVisible(state.drawn,currentSerial)end

-- ── Resumed round: rows, bottom up ──────────────────────────────────────────────────────────────────────────────
Fresh.RowGap=.04
Fresh.RowMax=.3
-- Pure: a ball whose centre is `y` board units above the floor, with rows `rowHeight` tall: the delay before it shows.
function Fresh.rowDelay(y,rowHeight)
 local row=math.max(0,math.floor((y or 0)/math.max(1e-3,rowHeight or 1)))
 return math.min(row*Fresh.RowGap,Fresh.RowMax)
end
-- Pure: does that ball show `age` seconds into the reveal?
function Fresh.rowShown(y,rowHeight,age)
 return age>=Fresh.rowDelay(y,rowHeight)
end
-- Pure: what an arrival on the deck plays: "resume" (balls already in the well: rows bottom up) or "fresh" (an empty
-- well: the held ball drops in first).
function Fresh.arrival(drops)return if(drops or 0)>0 then "resume"else "fresh"end

return Fresh
