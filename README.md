# GoalStat

A private, offline goal and habit tracker for Android, built with Flutter.

- Log goals daily: yes/no toggles or numbers with units
- Evaluate each goal daily, weekly, or monthly against an at-least, at-most,
  or exact target; daily yes/no goals are simply "do it" or "avoid it"
- Live status for weekly/monthly goals: on target, behind pace, or off
- Dashboard with streaks, on-target percentages, and charts; history with CSV export
- Edit any past day from a calendar
- All data stays on the device (SQLite)

## Development

```bash
flutter pub get
flutter run -d linux            # desktop, quickest
flutter run -d emulator-5554    # Android emulator
flutter test                    # unit + widget tests
TZ=America/New_York flutter test  # also exercises DST handling
```

## Project layout

| Path | Contents |
|---|---|
| `lib/models/goal.dart` | Goal model, period math (week start follows the device region) |
| `lib/models/period_status.dart` | On target / behind pace / off rules |
| `lib/data/database.dart` | SQLite schema, migrations, streaks and percentages |
| `lib/screens/` | Today, Dashboard, History, Settings tabs |
| `assets/icon/` | Icon sources; regenerate with `dart run flutter_launcher_icons` |
| `docs/` | Privacy policy (served via GitHub Pages) |
| `store/` | Play Store listing draft and assets |

## Release

1. Create an upload keystore (keep it and its passwords backed up, outside the repo):
   ```bash
   keytool -genkeypair -v -keystore ~/goalstat-upload.jks -keyalg RSA \
     -keysize 2048 -validity 10000 -alias upload
   ```
2. Create `android/key.properties` (git-ignored):
   ```properties
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=/home/<you>/goalstat-upload.jks
   ```
   Without it, release builds are signed with the debug key and can't be uploaded.
3. Bump `version` in `pubspec.yaml` (the `+N` build number must increase every upload).
4. `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`
