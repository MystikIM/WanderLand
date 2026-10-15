# WanderLand InnerWorlds: art wishlist

Everything in the app is **placeholder art drawn in code** right now (so the app
never looks blank). This is the list of real art to generate later. Nothing here
blocks anything: when a file exists, the app uses it; until then the placeholder
stays. Tick boxes as you go.

## Style brief (paste this at the top of every prompt)

> Cartoony kawaii sticker style, thick dark-violet outline (#2B1B3D), glossy
> white highlights, flat saturated fills, tiny blush cheeks, big shiny eyes.
> Neon violet and magenta palette (#9B30FF violet, #FF29B4 magenta) with warm
> yellow accents. Hand-inked, slightly imperfect lines. Not photoreal, not
> 3D-render, no gradients-everywhere "AI sheen". Transparent background, centered,
> square canvas, same line thickness and same character across the whole set.

**Format for everything below:** PNG with transparent background unless it says
otherwise. Generate at **1024 x 1024**, I'll scale down.
**Privacy:** no real names, faces or photos of real people in any art.

---

## 1. App identity (do these first)

- [ ] `app_icon.png`: full-bleed square, 1024. Gradient background is fine (opaque).
- [ ] `app_icon_foreground.png`: same artwork, transparent, with the main shape
      inside the **central 66%** (Android crops the edges into a circle/squircle).
- [ ] `notification_icon.png`: **white silhouette on transparent**, 96 x 96, very
      simple (a moon or a heart). Android tints it.
- [ ] `splash_logo.png`: the logo for the startup screen, transparent, 1024.
- [ ] `widget_icon.png`: small icon for the home-screen "who's out" widget, 256.
- [ ] `feature_graphic.png`: **1024 x 500**, opaque banner (for the build page /
      a future store listing).

## 2. Inner World pieces (8 now)

One image each, transparent, **calm** face. Optional second image per piece with a
**giggling/happy** face (eyes squeezed shut, big smile) for when it's tapped.

- [ ] tree (`piece_tree.png`) / `piece_tree_giggle.png`
- [ ] lake (`piece_lake.png`) / giggle
- [ ] house (`piece_house.png`) / giggle
- [ ] mountain (`piece_mountain.png`) / giggle
- [ ] sun (`piece_sun.png`) / giggle
- [ ] moon (`piece_moon.png`) / giggle
- [ ] flower (`piece_flower.png`) / giggle
- [ ] door (`piece_door.png`) / giggle
- [ ] **Default backdrop**: `world_backdrop.png`, **1600 x 1200**, opaque: dusk sky,
      stars, soft hills along the bottom, empty middle so pieces can sit on it.

**Pieces to add later** (the app can't draw these yet; they're for the
non-human-alters idea and for more keywords): den, nest, cauldron, castle, cloud,
star, heart, bridge, staircase, fountain, lantern, bookshelf, treehouse, cave,
campfire, boat, garden gate, library, throne, mirror.

## 3. Buddy (the care-and-cuddle companion)

**10 species:** blob, cat, dog, bunny (upright ears), rabbit (floppy ears), frog,
turtle, butterfly, fairy, unicorn. The app tints the buddy with the current
alter's color, so generate each in **soft lavender/grey-white** so tinting works
(or tell me and I'll recolor).

Per species (x10):
- [ ] idle **happy**, idle **content**, idle **sleepy** (3 images)
- [ ] **eating open** + **eating closed** (chewing, cheeks puffed)
- [ ] **cuddle** (deep red cheeks, eyes closed, cozy)
- [ ] **wash** (eyes scrunched `> <`, foam on head)
- [ ] **jump** (mid-air, happy)

Shared extras (once):
- [ ] **Accessories** (5): bow, scarf, crown, star, glasses
- [ ] **Outfits** (5): shirt, hoodie, dress, cape, pajamas
- [ ] **Care props** (transparent): apple, cookie, balloon, petting hand, soap
      bubble (x3 sizes), foam puff, floating heart, sparkle star, dust puff,
      crumbs
- [ ] **Egg**, **cracking egg**, **hatching**, and a **memorial star** (the
      gentle "went to the stars" picture)

## 4. Badges (10 icons, 512 x 512, round-ish sticker)

- [ ] `first-alter`: First friend (a little sprout)
- [ ] `alters-5`: Growing system (small tree)
- [ ] `alters-10`: Big family (cozy house)
- [ ] `first-checkin`: Hello! (waving hand)
- [ ] `checkin-3`: Getting into it (star)
- [ ] `checkin-7`: A week of care (rainbow)
- [ ] `checkin-14`: Two weeks strong (sunflower)
- [ ] `checkin-30`: Cozy habit (medal)
- [ ] `care-10`: Buddy buddy (teddy bear)
- [ ] `care-50`: Best friends (two hearts)

## 5. Empty-state and welcome pictures (about 512, one character each)

- [ ] Front tab: "nobody marked as out" (a calm sleeping creature)
- [ ] Alters tab: "no one here yet" (an open door with a lantern)
- [ ] Activity tab: "nothing to show yet" (a tiny sprout / empty calendar)
- [ ] Journal: "write your first entry" (open book and a feather pen)
- [ ] Chat: "say hi" (two little speech bubbles with faces)
- [ ] Inner World: "write about your world" (a seed with a little glow)
- [ ] Onboarding welcome (wide, 1200 x 800): a few friendly characters together
- [ ] "Make it yours" onboarding step (a paint palette character)

## 6. Alters

- [ ] Default avatar (transparent, neutral and friendly, not a gendered person),
      3 to 6 variants to pick from
- [ ] Avatar frames for non-human alters: fox, wolf, dragon, cat, witch hat, vampire
      fangs, fae wings, ghost, unicorn, other (a frame/overlay, 512)
- [ ] Little-mode extras (optional): a rounder, softer set of buttons and stickers

## 7. Tab and menu icons (optional, 96 x 96, white or violet, same line weight)

- [ ] Front (lightning), Activity (calendar), Alters (people), Inner World (cloud
      or door), Chat (bubble), More (dots)

## 8. Dedication page (optional)

- [ ] A warm family-style picture for the About/first-launch dedication. Text is
      still unconfirmed, and it must only use the nicknames, never real names.

## 9. Build page / public site (when we get to the release step)

- [ ] Logo lockup: icon + "WanderLand InnerWorlds" text, horizontal, transparent
- [ ] 4 to 6 phone screenshots (I'll capture these from the real app)
- [ ] Social/preview card, 1200 x 630, opaque

---

### How I'll use them

When you hand me files, drop them in `assets/art/` using the file names above and
tell me. I'll wire each one in with the code-drawn version kept as a fallback, so
a missing file never breaks anything. Tap-to-giggle, chewing, bubbles and cuddle
blush will switch to using the image sets (swapping the `giggle`/`cuddle`
variants) as they arrive.
