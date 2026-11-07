# Adjusting the Pocket Deck UI

The durable layout source is `src/client/DeckLayout.lua`. Open the Egg Drop folder in VS Code and edit the named values in `Layout.Settings` at the top. Save, let the connected Egg Drop Rojo session sync, then stop/start Studio Play to load the new client script.

```lua
UtilityWidth = 104,       -- menu/lounge hit area width
UtilityCapHeight = 32,    -- visible cap height; touch target remains 44
ControlCenter = .74,     -- regular control cluster center as a fraction of shell height
MaxTrayHeight = 700,      -- tray is solved first; spare viewport stays outside shell
RailMin = 150,            -- regular rail bounds; narrow roots use actual control width
RailMax = 205,
MenuOffsetX = 0,          -- negative left, positive right
MenuOffsetY = 0,          -- negative up, positive down
LoungeOffsetX = 0,
LoungeOffsetY = 0,
```

Try `MenuOffsetY = -6` to raise Menu slightly. Change one value at a time. The layout clamps controls into their grips to keep the LCD clear, but large offsets can still collide with another grip control. Check landscape and portrait after changes. `QuestHeight` changes the left instruction area; `ScreenGap` changes the gap between the screen and the grips. `ShellPadding` reserves the casing edge. Keep the desktop tray at 48–55% of total shell width; narrow roots can spend more width on their fixed 44px targets. The rocker well participates in the minimum rail width. The 160px-high root uses a separate shallow arrangement.

The main layout is code generated. In Studio Play you can expand **Players → your player → PlayerGui → EggDrop → Backdrop**, select a button and change its Position/Size in Properties to experiment. Those instance edits are temporary and the responsive layout may overwrite them. Record useful values in `DeckLayout.lua`; changes made during Play disappear when you stop.

Shell/background colors live in `src/shared/DeckThemes.lua`. Theme IDs are saved, so change their colors without renaming IDs. Menu graphics live in `src/client/DeckMenu.lua`; avoid changing reward or hatch transaction code for a visual adjustment.

Minimum touch targets remain 44 UI pixels even when the visible physical button cap is smaller. Use Studio's Device Emulator to inspect phone landscape and portrait; a physical-phone comfort test is still needed.
