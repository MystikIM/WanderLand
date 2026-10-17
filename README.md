# WanderLand

**InnerWorlds** · *A multi plural system manager / chaos crunch.*

A free Android app for plural and DID systems. It works fully **offline**: no
ads, no tracking, no account needed, and your data stays on your phone.

**Friend chat (new in 0.2.0, optional):** chat with people you add, end to end
scrambled, off until you switch it on. It is the only thing that uses the internet.
Versions before 0.2.0 have no internet permission at all.

**Real art (new in 0.3.0):** the released app uses hand-made pictures for the Inner World
pieces, the buddy and its care props, avatar frames, badges, the dedication card and the
empty screens. Those pictures are (c) MystikIM and are **not** in this repository. Without
them the app still runs and shows the drawn placeholder art, so you can build it yourself
or add your own pictures to `assets/art/` (names are in `docs/ART_PROMPTS.md`).

Made by [MystikIM](https://mystikim.com). Early test builds: see the build page
on mystikim.com.

## What it does

- **Alters:** profiles with names, pronouns, pictures, colors, tags, groups, and
  "what are they?" (fox, dragon, witch, a star... with cartoony avatar frames).
- **Front tracker:** who is out, co-front, notes, history, quick switching,
  a private lock-screen notification, app-icon shortcuts and a home-screen widget.
- **Activity:** a weekly view and soft, dismissable pattern heads-ups.
- **Inner World:** a diary that grows a little scene from your words. You move,
  resize, recolor or remove anything. Names of your alters become links.
- **Buddy:** a gentle pet with care actions and badges. It can never die unless
  you turn on Classic mode yourself.
- **Journal** (optional PIN screen lock) and an internal **chat** between alters.
- **Little mode:** a softer look and a safety guard when a little is out.
- **Friend chat** (0.2.0): add a friend with a code or a photo of their QR,
  chat, and choose, friend by friend, whether they can see who is out. Littles can
  use it with the friends a grown-up allows.
- **Backup and restore:** one zip file with everything except friend chat, which
  stays on the phone it was made on.
- Full theming, your own fonts, and your own words for things.

## Honest notes

- The journal PIN is a **screen lock, not encryption**.
- Backups are plain zip files, so keep them somewhere private.
- Friend chat messages are scrambled so only you and your friend can read them.
  A small relay server passes them along; it can see how big a message is and when
  it was sent, nothing else. There is no forward secrecy yet. The relay (in
  `relay/`, with `docs/RELAY_DEPLOY.md`) is open source, so you can run your own.
- Early builds: see each release's "tested / not tested yet" list. Nothing is
  claimed to work unless it was checked.

## Build it yourself

You need [Flutter](https://flutter.dev) (3.47+), the Android SDK and JDK 17.

```
flutter pub get
flutter test
flutter build apk --release
```

Without a `android/key.properties` file the release build falls back to the
debug key, so it still builds for you. (The real release key is private and
not in this repo.)

## License

MIT, see [LICENSE](LICENSE). Bundled fonts keep their own licenses in
`assets/fonts/licenses`.
