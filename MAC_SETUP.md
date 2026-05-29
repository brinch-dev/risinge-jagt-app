# Mac Setup Guide — Risinge Jagtvæsen v2.8.1

Denne guide dækker alt for at sætte udviklingsmiljø op på Mac og bygge iOS-appen.

## 1. Installer prerequisites

### Xcode (KRÆVET for iOS)
```bash
# Installer fra App Store (gratis, ~12 GB)
# Eller via kommandolinje:
xcode-select --install

# Åbn Xcode mindst én gang og accepter licensaftalen
sudo xcodebuild -license accept
```

### Flutter
```bash
# Download Flutter SDK
git clone https://github.com/flutter/flutter.git -b stable ~/flutter

# Tilføj til PATH (tilføj til ~/.zshrc)
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Verificer installation
flutter doctor
```

Flutter skal vise: `Flutter 3.41.x` eller nyere med SDK constraint `>=3.0.0 <4.0.0`.

### CocoaPods (iOS dependency manager)
```bash
sudo gem install cocoapods
# Eller via Homebrew:
brew install cocoapods
```

### Firebase CLI (til web deploy + push notifications)
```bash
npm install -g firebase-tools
firebase login
```

### Supabase CLI (til database queries)
```bash
brew install supabase/tap/supabase
# Eller:
npm install -g supabase
```

## 2. Projekt setup

### Pak projektet ud
```bash
unzip risinge-jagt-v2.8.1-komplet.zip -d ~/jagt-app-flutter
cd ~/jagt-app-flutter/jagt_app
```

### Hent dependencies
```bash
flutter pub get
```

### iOS pods
```bash
cd ios
pod install
cd ..
```

## 3. Hemmelige filer (INKLUDERET i zip)

Disse filer er ALLEREDE inkluderet i zip'en, men de er i .gitignore så de pushes ikke til GitHub:

| Fil | Placering | Indhold |
|-----|-----------|---------|
| `.env` | `jagt_app/.env` | Supabase URL + anon key |
| `key.properties` | `android/key.properties` | Android keystore password |
| `upload-keystore.jks` | `android/app/upload-keystore.jks` | Android signing keystore |
| `google-services.json` | `android/app/google-services.json` | Firebase config (Android) |

### iOS Firebase config (MANGLER — skal oprettes)
Du skal downloade `GoogleService-Info.plist` fra Firebase Console:
1. Gå til https://console.firebase.google.com/project/risinge-jagt
2. Klik på iOS-app (eller tilføj ny iOS-app med bundle ID: `dk.jagtapp.jagtApp`)
3. Download `GoogleService-Info.plist`
4. Placer den i: `ios/Runner/GoogleService-Info.plist`

## 4. iOS konfiguration i Xcode

### Åbn projektet
```bash
open ios/Runner.xcworkspace
```

### Signing
1. Vælg "Runner" i venstre panel → "Signing & Capabilities" tab
2. Vælg dit Team (kræver Apple Developer konto, $99/år)
3. Aktiver "Automatically manage signing"
4. Bundle Identifier er allerede: `dk.jagtapp.jagtApp`

### Capabilities (tilføj via + knap)
- **Push Notifications**
- **Background Modes**: Location updates, Remote notifications
- **Location**: When In Use, Always

### Info.plist (allerede delvist konfigureret)
Tjek at disse keys eksisterer i `ios/Runner/Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Risinge Jagt bruger din placering til at vise dig på kortet</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>Risinge Jagt bruger din placering i baggrunden til geofencing under jagt</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Risinge Jagt bruger din placering til kortet og geofencing</string>
<key>NSCameraUsageDescription</key>
<string>Risinge Jagt bruger kameraet til at tage billeder i chat</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Risinge Jagt bruger dit fotobibliotek til at dele billeder i chat</string>
```

## 5. Byg og kør

### iOS Simulator (ingen Apple Developer konto nødvendig)
```bash
# List tilgængelige simulatorer
flutter devices

# Kør på simulator
flutter run -d "iPhone 16"
```

### Fysisk iPhone (kræver Apple Developer konto)
```bash
# Tilslut iPhone via USB, unlock telefonen
flutter run -d <device-id>
```

### Release build (IPA til TestFlight/App Store)
```bash
flutter build ipa --release \
  --dart-define=SUPABASE_URL=https://zbmpptfddowmchuyrrea.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_pEJ8OVs9W7iK4abQngIq9A_--XKG5iK
```

### Android APK (virker også på Mac)
```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://zbmpptfddowmchuyrrea.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_pEJ8OVs9W7iK4abQngIq9A_--XKG5iK
```

### Web
```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://zbmpptfddowmchuyrrea.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_pEJ8OVs9W7iK4abQngIq9A_--XKG5iK

firebase deploy --only hosting
```

## 6. Distribution via TestFlight

1. Byg IPA: `flutter build ipa --release --dart-define=...`
2. Åbn Xcode → Product → Archive (eller brug den genererede .ipa)
3. Upload via Xcode Organizer eller Transporter app
4. I App Store Connect → TestFlight → inviter testere via email
5. Testere downloader TestFlight app og får appen automatisk

## 7. iOS-specifikke forskelle fra Android

| Feature | Android | iOS |
|---------|---------|-----|
| Baggrundslokation | Foreground Service | Background Modes |
| Push notifications | FCM direkte | FCM → APNs bridge |
| Installation | APK sideload | TestFlight / App Store |
| Auto-update | GitHub Releases | TestFlight auto-update |
| Geofencing | Foreground service | Significant location changes |

Geolocator og firebase_messaging packages håndterer platformforskellene automatisk.

## 8. Vigtige noter

- **Supabase backend er delt** — Android og iOS apps bruger SAMME database og auth
- **Edge Functions** er allerede deployed og virker for begge platforme
- **Realtime channels** virker identisk på iOS
- **Web deploy** kan også gøres fra Mac med `firebase deploy --only hosting`
- **.env filen** er inkluderet men nøglerne sendes også som `--dart-define` ved build
- **Android keystore** er inkluderet — brug samme keystore for at auto-update virker

## 9. Troubleshooting

### "No provisioning profile"
→ Log ind med Apple Developer konto i Xcode → Signing & Capabilities

### "pod install fails"
```bash
cd ios
rm -rf Pods Podfile.lock
pod repo update
pod install
```

### "flutter doctor shows issues"
```bash
flutter doctor -v
# Følg instruktionerne for hvert problem
```

### Supabase CLI auth
```bash
npx supabase login
npx supabase link --project-ref zbmpptfddowmchuyrrea
```

## Kontakt/Links
- **GitHub**: https://github.com/brinch-dev/risinge-jagt-app
- **Web app**: https://risinge-jagt.web.app
- **Supabase**: https://supabase.com/dashboard/project/zbmpptfddowmchuyrrea
- **Firebase**: https://console.firebase.google.com/project/risinge-jagt
