# Pocket Deck clarity and feedback pass — 2026-11-06

## Scope and design decisions

Requested after the overnight checkpoint. Astra reviewed the plan and implementation through review-driven-build. This is an interface and companion interaction pass; the nursery, egg odds, prices, payouts, daily schedule and mastery persistence are unchanged.

- Keep one active bank objective on the board. Show its two matching balls and destination in ordinary language. All three daily contracts remain active and visible in the menu rather than competing for space over the tray.
- Separate all grip panels from the LCD through a pure responsive DeckLayout module. Preserve 44px input targets with smaller physical utility caps. Replace the cryptic three-tier line with labeled Dropping and Next previews. High-contrast LEFT/RIGHT edge badges and differentiated blue/red regions replace the III+ overlays.
- Add an original LCD seed/logo power-on and synth chime when opening the deck. It is inspired by handheld boot timing and uses no Nintendo logo or melody. Reduced-effects mode bypasses the transition.
- Show remaining drops with a preview-ball channel and an exact counter. Each server-accepted drop animates one exiting copy; repeated snapshots, rejected taps and round resets cannot manufacture drops.
- Keep pet focus until Back. Greet repeatedly or hold and rub the companion with a vector glove. Suppress the native prompt over its face. Restore camera and exact movement settings on exit, respawn or teardown. Petting is cosmetic and grants no currency.
- Animate the confirmed round receipt: score/chain/clear counts, nectar hero, reward chips, transfer dots and existing synth cues. Retain a Details view for the complete receipt. Pending or stale receipts cannot show a new reward; balances always remain the canonical saved balance.
- Menu has a distinct wallet, illustrated destinations, compact graphical daily cards and overflow cues. Both egg recipes have foreground artwork. Skin previews recolor the background and cancel restores the saved skin. Stickers get a free grip slot and keep their preview across resizing.

## Review fixes

Astra identified compact root insets clipping 44px recipe choices, sticker preview loss on resize, a rolling ball detached from the train, stale rolling copies on reset, double pointer insets, pet-focus input during other modals, and camera reframing changing the Back snapshot. These were corrected before commit. Focus controls draw above the scene only while focus owns input; otherwise their hint yields to the main UI and menus.

## Verification

Native Studio fixtures: 45 focused cases (DeckExperience 11, PetFocusUI 10, RecapFeedback 14, MenuPolish 6, EggArt 4). Existing client regressions: HatchActions 17, Onboarding 7, RewardPresentation 10, RunGoals 8, HatchNavigation 10, CompactEggShop 8. Existing server regressions: HatchProgress 21, CloseProgress 2, SessionRecovery 8, SessionHost 2, StudioStore 1. Fixtures isolate profile writes; the default Studio store test uses a disposable synthetic ID. Totals: 139 cases.

Actual controls and screenshots are recorded below after integration verification. Layout fixtures are not physical-phone evidence. Studio uses its isolated development store; live-account rejoin and live multiplayer remain unverified. Fun, retention and production readiness are not established by these tests.


### Actual-control integration evidence

- Fresh Play booted once. Reopening from the lounge advanced the boot counter; ordinary HUD updates and 24 accepted field drops left the counter unchanged. Sound uses the existing approved bank and sound group.
- At a 568×160 root safe-area fixture, used Menu → Eggs, selected Sprout (6 nectar showed need 18), selected Meadow (need 12), and closed. Both original recipe drawings and full 44px recipe rows were visible. Opened Lounge Menu → Daily; all three contract cards and the separate claimed gift remained visible. This is a resized GUI fixture with actual mouse controls, not a physical phone.
- At 844×390, theme preview changed full backing to Ember #563125 and cancel restored Scout #284e32. A Star sticker stayed in its reserved grip position after portrait→landscape resizing; cancel restored the saved appearance.
- Actual controls reached welcome Pip and entered persistent pet focus. After more than 3.3 seconds it stayed Scriptable with WalkSpeed0. Repeated Greet stayed in the same view. Holding the projected pet body displayed the glove on the pet. Back restored Custom camera, WalkSpeed16 and AutoRotate true. A later paid hatch's Meet action also reached persistent focus.
- An assisted run used actual tray drag/release controls, beginning after five centered drops. It finished 24 drops with score600, peak chain4, both bank goals completed, base6 + daily6 =12 nectar, saved balance18. The dispenser recorded exactly24 pulses and Drops left0/24; no extra boot. Recap showed the confirmed 600/600, ×4, 0 tier-V clears, +12 nectar, Quest+6/Daily+6, and egg bank18/18. Details and Hatch eggs were clickable.
- Purchased Meadow through the actual hatch button: balance18→0, duplicate Pip, family marks1→2, then Meet Pip. The new artwork and duplicate caption rendered. These were ordinary Studio session transactions; no inventory or currency was granted by a test script to the real player.
- A Studio player-list popup briefly intercepted the top-right lounge clicks. The MCP render capture omitted that CoreGui popup; the native Windows view exposed it. Dismissing it restored the actual Menu button (Activated diagnostic1) and Daily navigation. No game bug was inferred from the obstructed clicks.
- Native failures logged by server fixtures were explicitly injected before/after-commit and profile-load/save failures. Ordinary startup still emits the pre-existing EditableImage-unavailable warning and external asset203785492 type mismatch. No account/security setting was changed to suppress them.

### Remaining validation

Physical phone thumb comfort, tactile rubbing, audio preference, live multiplayer, live DataStore rejoin, performance on low-end devices and voluntary replay remain player tests. Assets remain code-drawn UI graphics; this pass does not implement arbitrary Roblox UI shaders. The content pool and long-term economy remain prototype scope.
