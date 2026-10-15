# WanderLand (InnerWorlds): what to generate (plain list)

This is the short, "what do I actually need to make" list. The longer wishlist with
sizes and file names for everything else is `ART_ASSET_LIST.md`.

Everything is drawn in code right now, so nothing is blocked. When a file exists
the app can use it, and the code drawing stays as the fallback.

**Paste this at the top of every prompt (style brief):**
Cartoony kawaii sticker, thick dark-violet outline (#2B1B3D), glossy white
highlights, flat saturated fills, tiny blush cheeks, big shiny eyes, neon violet
(#9B30FF) and magenta (#FF29B4) with warm yellow accents, hand-inked slightly
wobbly lines, no photoreal, no 3D, no AI sheen. Transparent background, centered,
square, 1024 x 1024. Same line thickness and same style across the whole set.
No real names, faces or photos of real people.

**Naming:** save as `assets/art/<name>.png` and tell me. Each Inner World piece
wants TWO pictures: **calm** (relaxed face) and **giggle** (eyes squeezed shut,
big happy smile, it plays when you tap the piece).

---

## A. Inner World: every piece (12 pieces x 2 = 24 images) + 1 backdrop

The app grows a piece when your writing mentions its words. Pieces sit on the
scene, can be dragged, resized, recolored (tinted) and removed, so draw each one
in **soft light colors** so a tint still looks good. Each has a tiny face.

| # | Piece | Words that grow it | What it looks like now (placeholder) | Files |
|---|-------|--------------------|--------------------------------------|-------|
| 1 | Tree | tree, oak, willow, forest, woods | round leafy crown, thick trunk, smiling face | `piece_tree`, `piece_tree_giggle` |
| 2 | Lake | lake, pond, water, river, ocean, sea | blob of water, ripples, a shy little creature peeking out | `piece_lake`, `piece_lake_giggle` |
| 3 | House | house, home, cabin, cottage, room | cozy cottage, round window "eyes", little door mouth, chimney | `piece_house`, `piece_house_giggle` |
| 4 | Mountain | mountain, hill, cliff | sleepy snow-capped peak | `piece_mountain`, `piece_mountain_giggle` |
| 5 | Sun | sun, sunny, sunrise, sunset | happy sun with rays and blush | `piece_sun`, `piece_sun_giggle` |
| 6 | Moon | moon, night, stars | crescent moon in a little nightcap | `piece_moon`, `piece_moon_giggle` |
| 7 | Flower | flower, garden, meadow | big bloom with a friendly bee | `piece_flower`, `piece_flower_giggle` |
| 8 | Door | door, gate, portal | magic door, glowing, a little mysterious | `piece_door`, `piece_door_giggle` |
| 9 | Den | den, burrow, lair, cave | cozy cave/burrow opening, a pair of eyes inside | `piece_den`, `piece_den_giggle` |
| 10 | Nest | nest | twig nest, tiny eggs | `piece_nest`, `piece_nest_giggle` |
| 11 | Cauldron | cauldron, potion, brew | bubbling pot, green potion, bubbles | `piece_cauldron`, `piece_cauldron_giggle` |
| 12 | Castle | castle, tower, palace | little towers and flags | `piece_castle`, `piece_castle_giggle` |

Also for Inner World:
- [ ] **Default backdrop** `world_backdrop.png`, 1600 x 1200, opaque: dusk sky,
      stars, soft hills along the bottom, empty middle.
- [ ] **Empty-world picture** (shown before you write anything): a seed with a
      little glow, 512.
- [ ] **Alter chip pictures** (optional): the "who lives here" row uses each
      alter's avatar, so nothing new is needed.

### Inner World pieces the app can't draw yet (future, optional)
cloud, star, heart, bridge, staircase, fountain, lantern, bookshelf, treehouse,
campfire, boat, library, throne, mirror, garden gate. (Tell me which words should
grow each one and I'll add them to the app.)

---

## B. App identity (do these first)

- [ ] `app_icon.png` 1024, full square, opaque (gradient fine)
- [ ] `app_icon_foreground.png` 1024, transparent, main shape in the middle 66%
- [ ] `notification_icon.png` 96 x 96, white silhouette on transparent (moon or heart)
- [ ] `splash_logo.png` 1024, transparent
- [ ] `widget_icon.png` 256
- [ ] `feature_graphic.png` 1024 x 500, opaque banner
- [ ] Logo lockup: icon + "WanderLand", "InnerWorlds" small underneath, horizontal
- [ ] Social card 1200 x 630, opaque

## C. Buddy (companion)

10 species: blob, cat, dog, bunny (upright ears), rabbit (floppy ears), frog,
turtle, butterfly, fairy, unicorn. Draw each in **soft lavender / grey-white** so
the app can tint it to the current alter's color.

Per species (10 sets): idle happy, idle content, idle sleepy, eating mouth open,
eating mouth closed (cheeks puffed, for chewing), cuddle (deep red cheeks, eyes
closed), wash (eyes scrunched `> <`, foam on head), jump (mid-air).
= **8 images x 10 species = 80 images**.

Shared, once:
- [ ] 5 accessories: bow, scarf, crown, star, glasses
- [ ] 5 outfits: shirt, hoodie, dress, cape, pajamas
- [ ] Care props: apple, cookie, balloon, petting hand, soap bubble (3 sizes),
      foam puff, floating heart, sparkle star, dust puff, crumbs
- [ ] Egg, cracking egg, hatching
- [ ] Memorial star (gentle "went to the stars" picture)

## D. Alters

- [ ] Default avatars, neutral and friendly, not a gendered person: 3 to 6 variants
- [ ] **Avatar frames (17)**, overlay on a round avatar, 512, transparent:
      fox, wolf, cat, dog, bunny, bear, bird, dragon, demon, witch, vampire, fae,
      ghost, unicorn, angel, robot, plant. (Parts behind the head and parts in
      front: e.g. ears behind, fangs in front. One image is fine to start.)

## E. Dedication page (About + first launch)

The drawn row is: cat, bunny, **Joker_Wolf**, frog, dog (the wolf is the big one
in the middle, with mismatched eyes and tongue out).
- [ ] 5 characters, one image each, calm + happy
- [ ] Optional backdrop: dusk sky with soft hills and a few floating hearts

## F. Badges (10 icons, 512, round sticker)

first-alter (sprout), alters-5 (small tree), alters-10 (cozy house),
first-checkin (waving hand), checkin-3 (star), checkin-7 (rainbow),
checkin-14 (sunflower), checkin-30 (medal), care-10 (teddy bear),
care-50 (two hearts).

## G. Empty-state pictures (8, about 512, one character each)

Front (calm sleeping creature), Alters (open door with a lantern), Activity
(tiny sprout or empty calendar), Journal (open book and feather pen), Chat (two
speech bubbles with faces), Inner World (seed with a glow), Onboarding welcome
(wide, 1200 x 800, a few friendly characters), "Make it yours" step (paint
palette character).

## H. Tab icons (optional, 96, same line weight)

Front (lightning), Activity (calendar), Alters (people), Inner World (cloud or
door), Chat (bubble), More (dots).

---

## Counts

| Group | Images |
|-------|--------|
| A. Inner World pieces (12 x 2) + backdrop + empty-world | 26 |
| B. App identity | 8 |
| C. Buddy (80 + 5 + 5 + about 12 props + 3 egg + 1 star) | about 106 |
| D. Alters (4 default + 17 frames) | about 21 |
| E. Dedication | 5 to 10 |
| F. Badges | 10 |
| G. Empty states | 8 |
| H. Tab icons | 6 |

**Best order if you want the app to look different fastest:** B (icon) first, then
A (Inner World), then the Buddy species you use most, then D frames.
