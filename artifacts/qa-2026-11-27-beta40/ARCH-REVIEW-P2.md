# Architect review: free eggs through the shop + onboarding part 2 (2026-11-27)

Plan: `ONBOARDING-P2-BRIEF.md`. Decision: the three lit taps Paint lesson, with the one-tap fallback and Later.
Verdict: **GO WITH CHANGES**. No server change; one new saved fact (lesson C).

## 1. Save facts
- A (Dress up): `public.gifts.granted.paint` + any non-empty pet hue count. A colour cleared with `hueClear` shows it again (acceptable).
- B (Deck): `stats.rounds >= 2` (the Welcome round is 1).
- D (Park): `stats.fetches > 0`.
- E (Dash): the ribbons in `public.dash`.
- C (Menu) needs `menuSeen`: `Coach.Bits.menuSeen=28`, append to `Coach.Order` (`src/shared/CoachMarks.lua`), `Gated.menuSeen="teach"`, `GateOwner.teach="Onboard"`; set it on any Things page open, not only the lesson's.
- Safe for live and older betas: `Coach.sanitize` keeps unknown bits; older servers' `validId` refuses the id, only a beta 41 client sends it; `FeatureFlags.OnboardingV3` keeps `teach` off on live. Bits 29 and 30 are the last two: plan a second mask field before spending them.

## 2. Shop gift mode
The server cannot give twice (`giftEgg` writes inside UpdateAsync, refuses `Pending`/`RevealPending`). The risks are client-side: a second press before the publish gets "Saved / AlreadyGranted" (`GiftEggHost.lua:18`) and `present()` shows the card again; or the press drops into `onOpenHue(true)`, a paid buy. Required:
- The gift branch first in `EggHatchView:actPrimary` (`:218`); it never calls `send` or `onOpen*`; latched until the chain's `done`.
- Gift mode only when `gifts.ready==kind`, the chain is not cranking/revealing, `granted[kind]` false; re-checked on every `update`.
- `Chain:shopCrank(kind)` in GiftChain.lua: takes `Chain.parked(f)` without a lead, then runs the existing `Chain:crank` (the shop uses the same function the chip used). `crank` needs `self.active`, so a shop opened from the Menu builds one first.
- A client watcher on the `TurnEggs` prompt re-applies "Free egg!" if streaming rebuilds it, and puts "Hatch eggs" back when no gift waits.

## 3. Camera
- `present()` (init.client.lua:6225) passes `{isOpen=Reveal.isOpen}` as the owner instead of nil.
- The fallback at EggMachineClient.lua:1088 generalised from `Unclaimed[kind]` to any shot: return when the owner is not open, no `d.screens()` screen is visible, no gap, and `t>=start+StatWatch`.
- The card's `closed` (:6222) calls `revealClosed("gift")`.
- Lesson A calls `machine:returnCamera(true)` (instant) and waits one Heartbeat before RoomView's focus (else focus records Scriptable at RoomView.lua:961 and restores it on exit). Belt and braces: RoomView stores Scriptable as Custom, as `FirstHatchStory.lua:874` does.
- The wipe's FOV punch skips itself on a Scriptable camera (`GiftPaintWipe.lua:69`): fine.

## 4. Edge cases
- Unseen gift, shop opened from the Menu: replay the card, no "Hatch free!".
- Lesson A mid-way on rejoin: paint gift seen, nothing painted: the Dress up pointer once that session.
- Out of order: derived facts close the lesson; `TeachPointer` re-checks the fact every step and hides when it holds.
- `teach` off, `gifts` on: "Paint {pet}!" stays one tap, with the camera fix.
- `gifts` off mid-chain: gift mode drops on the next `update`; the latch clears.

## 5. Cut order if too big
D and E, the Dress up dot, gamepad/keyboard labels, then C. Keep the shop free egg, the camera fix, `TeachPointer`, A and B.

## Required changes
1. Gift branch, latch, per-update gift mode in `EggHatchView.lua`.
2. `Chain:shopCrank`; remove "Turn it!" and the chip (`GiftChain.lua`, `GiftBubble.lua`).
3. Owner on `present()` and `revealClosed` in `closed` (`init.client.lua`).
4. The generalised fallback (`EggMachineClient.lua`).
5. Lesson A's instant return then focus; RoomView stores Scriptable as Custom.
6. `menuSeen` + the `teach` gate (`CoachMarks.lua`, `Onboard.lua`) + the `CoachMask` spec.
7. Specs: shop latch, AlreadyGranted shows no second card, an owner-less shot returns the camera.
