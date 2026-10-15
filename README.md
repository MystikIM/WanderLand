# WanderLand

**InnerWorlds** · *A multi plural system manager / chaos crunch.*

A free Android app for plural and DID systems. It works fully **offline**: no
ads, no tracking, no account needed, and your data stays on your phone.

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
- **Backup and restore:** one zip file with everything.
- Full theming, your own fonts, and your own words for things.

## Honest notes

- The journal PIN is a **screen lock, not encryption**.
- Backups are plain zip files, so keep them somewhere private.
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
