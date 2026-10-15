# Release checklist: WanderLand (InnerWorlds) v0.1.3

Honest status of each item on a real phone. Nothing is marked PASS unless it was
actually checked. Test phone: Revvl 7 Pro 5G, Android 16.

Legend: PASS = checked and works. NOT TESTED = not checked yet (do not assume).

| # | Item | Status | Note |
|---|------|--------|------|
| 0 | Release APK is signed with the MystikIM key, id `com.mystikim.wanderland`, asks for no internet permission | PASS | checked with apksigner and aapt |
| 0 | Installs and opens on the phone | PASS | debug and release both opened, no crash in the log |
| 0 | About 300 automated tests pass, analyze clean | PASS | `flutter test`, `flutter analyze` |
| 1 | First run: setup screen, name, color, font, word for "alter", greeting | NOT TESTED | |
| 2 | Alters: add 3 (emoji name, picture + banner, age 6), pronoun chips, tags, custom fields, archive, delete | NOT TESTED | |
| 2b | Non-human alters: pick a kind, see the avatar frame | NOT TESTED | frames only seen in rendered previews |
| 3 | Front: switch, co-front, note, "nobody", quick-switch; accent follows who is out | PARTLY | front tab seen working; the rest not checked |
| 4 | Little mode and guard | NOT TESTED | |
| 5 | Activity tab | NOT TESTED | |
| 6 | Buddy: all 7 care buttons, cooldowns, animations, clothes | PARTLY | used by hand; owner asked for animations, which were added afterwards and not re-checked on the phone |
| 7 | Daily kind note | NOT TESTED | |
| 8 | Notifications: permission, lock-screen privacy, tap opens switch sheet, reminders, survive restart | NOT TESTED | |
| 9 | App-icon shortcuts and home widget | NOT TESTED | |
| 10 | Journal: write, PIN with hint, forgot-PIN 24 h wait | NOT TESTED | |
| 11 | Chat | NOT TESTED | |
| 12 | Inner World: grow from words, "I don't have a house" adds none, drag, resize, recolor, remove, add piece, background photo, tap to giggle | PARTLY | opened and viewed by hand; the rest not checked |
| 12b | Dedication shows once after setup, and under More > About | NOT TESTED | |
| 13 | Backup: make a backup, clear app data, restore | NOT TESTED | |
| 14 | Airplane mode run-through | NOT TESTED | the release app has no internet permission, so it cannot go online anyway |
| 15 | Import your own font | NOT TESTED | |

Anything NOT TESTED goes into the release notes as "not tested yet", exactly as
written here.

## Release files

- `dist/wanderland-0.1.0.apk` (git-ignored)
- SHA-256: `5cf51796b6d00086cda533ebfd36afd93ddde41604d45fa9025733332b556e62`
- Size: 58.9 MB, minimum Android 7.0
- Signing certificate SHA-256: `c67f0036fe4e9a8fb683e054e7ca7e78119bb8e0074f31942aa16e79d74b9367`

## Before going public

- [x] App id decided: `com.mystikim.wanderland` (permanent)
- [x] License: MIT
- [x] Signing key created; stored in the credentials vault; a second copy is still needed
- [ ] Name clearance reviewed (see notes in the handoff memory)
- [ ] Public GitHub repo created and the code pushed (code only: no keystore, no
      `key.properties`, no APK in git)
- [ ] GitHub release v0.1.3 created with the APK attached (hosted there because
      the website host limits single files to about 25 MB)
- [ ] Website page checked on a preview, then shipped
- [ ] Phone checklist above run, results updated here and on the build page

## Before publishing a build with friend chat (blocks the next release)

The table above is the truth for v0.1.3, which has no internet permission. A build with
friend chat has the internet permission, so these must be done first:

| # | Item | Status | Note |
|---|------|--------|------|
| B1 | The website and README no longer say "no internet permission" / "nothing leaves your phone", and the site has a plain "How friend chat works" section (scrambled end to end, relay sees only size and time, off by default, only people you add, block, no forward secrecy yet) | NOT DONE | blocks release |
| B2 | Release notes say chat uses the internet only after it is switched on, and list the exact permission list of the APK (checked with aapt) | NOT DONE | blocks release |
| B3 | Relay is running and `https://chat.mystikim.com/v1/health` answers `ok` | PASS 2026-10-15 | home server box, Cloudflare Tunnel |
| B4 | Live smoke test against the real relay passes (`RELAY_SMOKE=1 flutter test test/ui/friends/live_relay_smoke_test.dart`) | PASS 2026-10-15 | from the PC, two pretend phones |
| B5 | Two REAL phones, different networks (one on home Wi-Fi, one on mobile data), become friends and chat both ways | NOT TESTED | needs a second Android phone |
| B6 | Airplane mode: a message shows "Waiting to send", then sends when back online | NOT TESTED | |
| B7 | Littles: with the guard on and a little out, cannot add or remove friends or change sharing; can chat only with friends marked okay | NOT TESTED | covered by widget tests only |
