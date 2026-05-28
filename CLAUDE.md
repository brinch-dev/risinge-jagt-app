# Risinge Jagt App — Claude Guide

## Projekt
Flutter app til Risinge Jagtvæsen. iOS + Android + Web.
- **Bundle ID (iOS):** `dk.jagtapp.jagtApp`
- **Package (Android):** `dk.jagtapp.jagt_app`
- **Firebase projekt:** `risinge-jagt`
- **Supabase ref:** `zbmpptfddowmchuyrrea`

## Lokalt setup (macOS)
- Flutter: `~/flutter/bin/flutter`
- Xcode 26.5, min iOS deployment target: 15.0
- Firebase CLI logget ind som: exeakreizi@gmail.com
- Simulator: `flutter run -d "iPhone 17"`
- Screenshot: `xcrun simctl io booted screenshot /tmp/sim.png`

## Vigtige filer
| Fil | Beskrivelse |
|-----|-------------|
| `lib/bootstrap.dart` | App initialisering (Firebase, Supabase) |
| `lib/firebase_options.dart` | Genereret af flutterfire — ikke redigér manuelt |
| `ios/Runner/GoogleService-Info.plist` | Firebase iOS config |
| `ios/Runner/Info.plist` | iOS permissions |
| `ios/Podfile` | iOS min platform: 15.0 |
| `.env` | Supabase credentials (ikke i git) |
| `.github/workflows/deploy.yml` | CI/CD: Android + Web + iOS (TestFlight) |

## Kendte iOS-fixes (allerede lavet)
- `DarwinInitializationSettings` tilføjet til flutter_local_notifications
- APNs token fejl fanget i `PushNotificationService._saveToken()`
- Alle `FloatingActionButton` har unikke `heroTag` værdier
- Notifikationsliste overflow fikset med `Flexible` + `ellipsis`
- `DefaultFirebaseOptions.currentPlatform` bruges i Firebase.initializeApp()

## CI/CD
- Push til `main` bygger: Android APK (GitHub Release) + Web (Firebase Hosting) + iOS IPA (TestFlight)
- iOS-job springer automatisk over hvis `APPLE_CERTIFICATE_BASE64` secret ikke er sat
- Node.js 24 aktiveret via `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true`
- Flutter version i workflow: 3.44.0

## Secrets der mangler (tilføjes når Apple Developer konto er aktiv)
- `APPLE_CERTIFICATE_BASE64`
- `APPLE_CERTIFICATE_PASSWORD`
- `APPLE_PROVISIONING_PROFILE_BASE64`
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_BASE64`
- `GOOGLE_SERVICE_INFO_PLIST`
