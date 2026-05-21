# iOS — Problem, loesninger og plan

## Problemet

Flutter-koden er allerede cross-platform — al Dart-kode virker paa baade Android og iOS.
Men for at **bygge og distribuere** til iOS kraeves:

1. **macOS** — Xcode koerer kun paa Mac. Ingen undtagelser.
2. **Xcode** — Apples IDE der kompilerer iOS-apps. Gratis fra App Store.
3. **Apple Developer konto** — $99/aar. Kraeves for at:
   - Teste paa fysisk iPhone/iPad (uden konto kan man kun bruge simulator)
   - Distribuere via TestFlight (beta) eller App Store
   - Generere provisioning profiles og certifikater

Vi arbejder paa Linux, saa vi kan ikke bygge iOS lokalt.

## Hvad skal goeres naar vi har adgang til Mac

### Trin 1: Xcode-projekt konfiguration (30 min)
```bash
cd jagt_app/ios
pod install
open Runner.xcworkspace
```
- Saet Bundle Identifier: `dk.jagtapp.jagtApp`
- Saet Deployment Target: iOS 16.0 (daekker iPhone 8+)
- Tilfoej capabilities: Location (Always + When In Use), Push Notifications, Background Modes (Location)
- Konfigurer Info.plist med danske lokationsbeskeder:
  - `NSLocationWhenInUseUsageDescription`: "Risinge Jagt bruger din placering til at vise dig paa kortet"
  - `NSLocationAlwaysUsageDescription`: "Risinge Jagt bruger din placering i baggrunden til geofencing under jagt"

### Trin 2: Signing og certifikater (15 min)
- Log ind med Apple Developer konto i Xcode
- Aktiver "Automatically manage signing"
- Xcode genererer provisioning profile automatisk

### Trin 3: iOS-specifikke tilpasninger (1-2 timer)
Ting der virker anderledes paa iOS:
- **Baggrundslokation**: iOS har strengere regler. Skal bruge `CLLocationManager` med `allowsBackgroundLocationUpdates`. Vores Geolocator-package haandterer dette, men kraever Background Modes capability.
- **Foreground service**: Eksisterer IKKE paa iOS. I stedet bruges Background Modes med "Location updates". iOS tillader location tracking i baggrunden, men viser en blaa statusbar.
- **Push notifikationer**: iOS bruger APNs (Apple Push Notification service) i stedet for FCM. Hvis vi tilfojer Firebase, haandterer firebase_messaging dette automatisk.
- **Notifikations-permission**: iOS spoerger automatisk ved foerste brug. Vores kode haandterer dette allerede via DarwinInitializationSettings.

### Trin 4: Test (1 time)
- Koer paa iOS Simulator (gratis, ingen konto)
- Koer paa fysisk iPhone (kraever Developer konto)
- Test alle flows: login, kort, kalender, tilmelding, geofencing, chat, notifikationer

### Trin 5: Distribution
**TestFlight (beta-test):**
- Byg med `flutter build ipa`
- Upload via Xcode eller Transporter-app
- Inviter testere via email — de downloader TestFlight-app og faar appen

**App Store (produktion):**
- Kraever app review fra Apple (1-3 dage)
- Screenshots, beskrivelse, privacy policy
- Aldersklassificering

## Loesninger uden egen Mac

### Option A: Cloud build-service (anbefalet)
**Codemagic** (codemagic.io):
- Gratis tier: 500 build-minutter/maaned
- Push kode til GitHub → Codemagic bygger iOS automatisk
- Genererer .ipa fil du kan uploade til TestFlight
- Kraever stadig Apple Developer konto for signing

**GitHub Actions med macOS runner:**
- Gratis for open source, betalt for private repos
- Saet op med fastlane for automatisk build + upload

### Option B: Lej en Mac i skyen
- **MacStadium**, **AWS EC2 Mac**: fra ~$30/maaned
- Fuld macOS adgang via fjernskrivebord
- Kan bruges til alt: Xcode, build, test, upload

### Option C: Laan/koeb en Mac
- Brugt Mac Mini er den billigste vej (~2000-3000 kr)
- M1 Mac Mini er rigelig til Flutter iOS builds
- Kan ogsaa bruges som lokal build-server

## Estimeret tidsforbrug
| Opgave | Tid |
|--------|-----|
| Xcode-projekt setup | 30 min |
| Signing/certifikater | 15 min |
| iOS-specifikke tilpasninger | 1-2 timer |
| Test paa simulator + enhed | 1 time |
| TestFlight upload | 30 min |
| **Total** | **3-4 timer** |

## Pris
| Hvad | Pris |
|------|------|
| Apple Developer konto | $99/aar (~700 kr) |
| Mac Mini M1 (brugt) | ~2500 kr (engangskob) |
| ELLER Codemagic cloud | Gratis (500 min/md) |

## Anbefaling
Billigste vej til iOS: **Apple Developer konto + Codemagic**. Ingen hardware-kob.
Push kode til GitHub, Codemagic bygger, upload til TestFlight, testere faar appen.
