"""Morning review contact sheets for Spencer (2026-11-20). One sheet per area, captions from file names."""
import os
from PIL import Image, ImageDraw, ImageFont
A = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.dirname(os.path.abspath(__file__))
F = "C:/Windows/Fonts/"
def font(s):
    for n in ("segoeuib.ttf", "arialbd.ttf"):
        try: return ImageFont.truetype(F + n, s)
        except OSError: pass
    return ImageFont.load_default()
SHEETS = {
 "1-stats-and-icons": ["v2-review-2026-11-20/01-stats-panel-pocket-buddies.jpg", "v2-review-2026-11-20/02-inspect-stats-tab-FIXTURE.jpg",
  "v2-review-2026-11-20/06-level-up-line.jpg", "v2-s3-stats-ui/results-stats-strip-and-levelup-line.png", "v2-naming-build/10-stats-panel-title-with-name.jpg", "v2-s4-inspect-stats/inspect-compare-phone-844x390-FIXTURE.png"],
 "2-stat-eggs-and-feeding": ["v2-review-2026-11-20/03-stat-egg-card-icon-decal-snack.jpg", "v2-hatch-build/23-play-stat-card-no-pet-line-warm-shadow.jpg", "v2-hatch-build/16-stat-rare-card-844x390.png",
  "v2-review-2026-11-20/04-snack-pouch-feeding-pocket-buddies.jpg", "v2-review-2026-11-20/05-feeding-snack-with-icon-decal.jpg", "v2-hatch-build/14-stat-uncommon-card-844x390.png"],
 "3-bunny": ["v2-bunny-wiring/01-pets-adopt-card.jpg", "v2-bunny-wiring/02-adopt-confirm.jpg", "v2-bunny-wiring/08-lineup-wearables.jpg", "v2-bunny-wiring/05-dyed-fixture-tide-citrus-rose-iris-live-white.jpg",
  "v2-bunny-wiring/06-garden-flowercrown-ears-up-smallwide-kittyw.jpg", "v2-bunny-wiring/10-bunny-stats-panel.jpg"],
 "4-toy-shell": ["v2-toy-shell-build/after-01-deck-hud-844x390-scout.png", "v2-toy-shell-build/after-02-customize-844x390-ember.png", "v2-toy-shell-build/after-03-pocket-menu-844x390-creek.png",
  "v2-toy-shell-build/after-03-pocket-menu-844x390-classic.png", "v2-toy-shell-build/after-06-egg-shop-844x390-ember.png", "v2-toy-shell-build/after-08-results-844x390-scout.png", "v2-review-2026-11-20/07-settings-menu-colours.jpg", "v2-toy-shell-build/after-04-companions-844x390-scout.png"],
 "5-hatch": ["v2-hatch-build/01-lid-closing-toy-844x390.png", "v2-hatch-build/03-toy-common-burst-844x390.png", "v2-hatch-build/04-toy-common-card-844x390.png", "v2-hatch-build/07-custom-rare-windup-844x390.png",
  "v2-hatch-build/08-custom-rare-burst-844x390.png", "v2-hatch-build/09-custom-rare-stamp-844x390.png", "v2-hatch-build/10-custom-rare-card-844x390.png", "v2-hatch-build/17-pet-common-shakes-844x390.png",
  "v2-hatch-build/18-pet-common-card-844x390.png", "v2-hatch-build/19-reduced-motion-rare-844x390.png", "v2-hatch-build/20-iris-out-844x390.png", "v2-hatch-build/15-stat-rare-stamp-844x390.png"],
 "6-naming": ["v2-naming-build/01-naming-screen-starters.jpg", "v2-naming-build/02-naming-two-pieces-picked.jpg", "v2-naming-build/03-names-egg-card-random-odds.jpg", "v2-naming-build/04-names-egg-reveal-card.jpg",
  "v2-naming-build/06-level-up-line-heart10-speed25.jpg", "v2-naming-build/07-stats-tab-earned-pieces-unlocked.jpg", "v2-naming-build/08-saved-speedy-cuddle.jpg", "v2-naming-build/11-garden-nameplate-over-pet.jpg"],
}
W, COLS, PAD = 760, 2, 18
for name, files in SHEETS.items():
    tiles = []
    for rel in files:
        p = os.path.join(A, rel)
        if not os.path.exists(p): print("missing", rel); continue
        im = Image.open(p).convert("RGB"); im = im.resize((W, round(im.height * W / im.width)))
        cap = os.path.splitext(os.path.basename(rel))[0]
        t = Image.new("RGB", (W, im.height + 34), (24, 22, 40)); t.paste(im, (0, 34))
        ImageDraw.Draw(t).text((8, 6), cap, font=font(18), fill=(255, 225, 77)); tiles.append(t)
    rows = [tiles[i:i + COLS] for i in range(0, len(tiles), COLS)]
    H = 70 + sum(max(t.height for t in r) + PAD for r in rows)
    sheet = Image.new("RGB", (COLS * W + (COLS + 1) * PAD, H), (16, 15, 30)); d = ImageDraw.Draw(sheet)
    d.text((PAD, 16), name.split("-", 1)[1].replace("-", " ").title() + "  (v2 review, 2026-11-20)", font=font(34), fill=(255, 244, 220))
    y = 70
    for r in rows:
        for i, t in enumerate(r): sheet.paste(t, (PAD + i * (W + PAD), y))
        y += max(t.height for t in r) + PAD
    out = os.path.join(OUT, "sheet-" + name + ".jpg"); sheet.save(out, quality=86); print("wrote", out, sheet.size)
