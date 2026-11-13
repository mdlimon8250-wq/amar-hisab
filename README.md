# Amar Hisab (আমার হিসাব)

Offline Bengali/English income & expense tracker for Android, built with Flutter. BDT (৳) with lakh/crore grouping, local SQLite storage, no internet permission, no servers, no paid APIs.

## Features
- Bengali (default) and English, Bengali digits in Bengali mode
- Income / expense entries: add, edit, delete (swipe or long-press, with Undo)
- Personal, family and business accounts (add / rename / delete) and an "All accounts" view
- Dashboard: balance, this-month summary, spending donut chart, last-7-days chart, recent entries
- Reports: daily / weekly (Saturday–Friday) / monthly with previous/next navigation, bar chart, category chart (tap to highlight)
- Search and income/expense filter on the entries list
- Light, dark or automatic theme
- Backup & restore (copy all data as text, paste to restore; validated before anything is replaced)
- Upgrades from v1.0 keep existing data (database migration)

## Build the APK

### Option A – no installation needed (GitHub Actions)
1. Create a free GitHub account and a new repository.
2. Upload every file of this folder (including the hidden `.github` folder) to it, on the `main` branch.
3. Open the **Actions** tab → **Build Android APK** → wait ~6–10 minutes.
4. Open the finished run → **Artifacts** → download `amar-hisab-apk`. It contains `app-arm64-v8a-release.apk` (most phones), `app-armeabi-v7a-release.apk` (old phones) and `app-release.apk` (works on all).

### Option B – on your own computer
```
flutter create . --platforms=android --org com.amarhisab --project-name amar_hisab
dart run tool/patch_android.dart
flutter pub get
flutter test
flutter build apk --release
```
APK: `build/app/outputs/flutter-apk/app-release.apk`

## Notes
- The APK is signed with Flutter's debug key so it installs directly. For Google Play you need your own release keystore.
- Data lives only on the phone. Uninstalling deletes it, so use *Settings → Copy backup* regularly and paste it somewhere safe.
