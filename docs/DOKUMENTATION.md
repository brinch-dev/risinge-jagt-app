# Risinge Jagtvæsen — App Dokumentation

**Version:** 2.5.6
**Opdateret:** 2026-05-23
**Platforme:** Android (APK) + Web (Firebase Hosting)
**Backend:** Supabase (PostgreSQL, Auth, Realtime, Storage, Edge Functions)

---

## Oversigt

Risinge Jagtvæsen er en jagtkoordineringsapp til Risinge Herregaard. Appen giver jægere, gæster og administratorer et fælles værktøj til at koordinere jagter, kommunikere og holde styr på jagtområder og poster.

- **Web**: https://risinge-jagt.web.app
- **Android APK**: https://github.com/brinch-dev/risinge-jagt-app/releases/latest
- **GitHub**: https://github.com/brinch-dev/risinge-jagt-app

---

## Tech Stack

| Komponent | Teknologi |
|-----------|-----------|
| Frontend | Flutter 3.41.5 (Dart) |
| State Management | Riverpod 3.x (AsyncNotifier) |
| Navigation | GoRouter med auth redirect |
| Backend | Supabase (PostgreSQL, Auth, Realtime, Storage, Edge Functions) |
| Kort | flutter_map + OpenStreetMap/ArcGIS/OpenTopo |
| Lokation | Geolocator + Android Foreground Service |
| Push | Firebase Cloud Messaging via Supabase Edge Function |
| Hosting | Firebase Hosting (web) |
| CI/CD | GitHub Actions |
| Distribution | GitHub Releases med auto-opdatering |

---

## Platform-forskelle

| Funktion | Android | Web |
|----------|---------|-----|
| Login/profil | ✓ | ✓ |
| Forside (hero, info-kort, blokke) | ✓ | ✓ |
| Kort med tårne og områder | ✓ | ✓ |
| Tårn-reservationer | ✓ | ✓ |
| Kalender og events | ✓ | ✓ |
| Chat (realtime + medie) | ✓ | ✓ |
| Admin panel | ✓ | ✓ |
| GPS/live position | ✓ | — |
| Geofencing/grænse-alarm | ✓ | — |
| Check-in/check-ud | ✓ | — |
| Push notifikationer (FCM) | ✓ | — |
| Auto-opdatering | ✓ | — |

---

## Brugerroller

Roller styres dynamisk via `roles`-tabellen. Admin kan oprette, redigere og slette roller.

| Rolle | DB-værdi | Beskrivelse |
|-------|----------|-------------|
| Admin | `admin` | Fuld adgang til alt |
| Jæger Medlem | `jaeger_medlem` | Fast jæger med fulde jagtrettigheder |
| Ejer | `ejer` | Ejer af området |
| Forvalter | `forvalter` | Forvalter af området |
| B&B Direktør | `bb_direktoer` | Bed & Breakfast direktør |
| Jagt Gæst | `jagt_gaest` | Gæst inviteret til jagt |
| Gæst | `gaest` | Generel gæst (mindste rettigheder) |

### Rettigheder

| Funktion | Admin | Jæger M. | Ejer | Forvalter | B&B Dir. | Jagt G. | Gæst |
|----------|-------|----------|------|-----------|----------|---------|------|
| Se alle events | ✓ | ✓ | ✓ | ✓ | ✓ | | |
| Oprette events | ✓ | ✓ | ✓ | ✓ | ✓ | | |
| Redigere alle events | ✓ | ✓ | | | ✓ | | |
| Se tårne/poster | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | |
| Reservere tårne | ✓ | ✓ | | | | ✓ | |
| Live overvågning | ✓ | | | ✓ | | | |
| Admin panel | ✓ | | | | | | |
| Slette chat-beskeder | ✓ | | | | | | |

---

## Funktioner

### Forside
- Dynamisk forside med konfigurerbare blokke (hero, velkomst, tekst, billede, meddelelse)
- Dashboard widgets: næste event, nedtælling, event-statistik, vejrudsigt, mine reservationer, seneste chat
- Sort/hvid tema på alle dashboard widgets (mørke kort med hvid tekst)
- Klikbare widgets: navigerer til kalender, kort eller chat
- Vejrudsigt via Open-Meteo API (temperatur, vind, fugtighed, solopgang/solnedgang)
- Admin kan tilføje/fjerne/aktivere/deaktivere alle widgets med rollebaseret synlighed
- Hero med gradient overlay og hvid tekst

### Kort (Jagtkort)
- 3 kortlag: Standard (OSM), Satellit (ArcGIS), Topografisk (OpenTopo)
- Jagtområder som grønne polygoner
- Tårn-markører med type-ikon (jagttårn/skydestige/skudlinje)
- Farvekoder: grøn=ledig, rød=optaget, blå=din
- Brugerposition som blå prik (Android)
- Afstandsmåler: tryk lineal-ikon, tryk på kort
- Geofencing med grænse-advarsler (Android)
- Check-in/check-ud popup (kun events med checkin aktiveret)

### Kalender
- Ugevisning som standard med event-markører
- Event-kort med titel, beskrivelse, tid, område
- Tilmeld/Afmeld knapper med deltagerantal
- Poster-knap til tårn-reservation

### Chat
- Kanal-baseret med realtime (Supabase Realtime + 3s polling fallback)
- Tekst, billeder (galleri/kamera) og video (galleri/optag)
- Admin kan slette beskeder (long-press)
- Push notifikationer ved nye beskeder (Android)
- Generelle kanaler med rolle-adgang + private/gruppe kanaler
- Chat RLS via SECURITY DEFINER funktion `can_access_channel()`

### Notifikationer
- In-app notifikationer med realtime-opdatering
- FCM push notifikationer (Android)
- Ulæste-antal på klokke-ikon
- Push ved chat, broadcasts og events

### Profil
- Navn, email, rolle med ikon og farve
- Rediger visningsnavn
- Versionsnummer synligt
- Admin panel adgang (kun admin)
- Log ud med FCM cleanup

### Auto-opdatering (Android)
- Tjekker GitHub Releases API ved opstart
- Sammenligner semantisk versionsnummer
- Streaming download af APK
- Husker afvist version (viser ikke igen for samme)
- Browser-fallback hvis installation fejler

### Admin Panel
| Sektion | Beskrivelse |
|---------|-------------|
| Jagtområder | Opret og administrer områder med polygon-grænser |
| Tårne/poster | Opret med navn, beskrivelse, type og billeder |
| Brugere | Se alle brugere, ændr roller |
| Chat kanaler | Opret/rediger/slet kanaler + rolle-adgang |
| Broadcast | Send besked til alle |
| Events | Opret/rediger med check-in/ud toggle |
| Forside | Rediger forsideblokke med rolle-synlighed |
| Roller | CRUD roller + chat-kanal adgang per rolle |
| Live overvågning | Se brugerpositioner i realtid |
| Admin Log | Komplet aktivitetslog |

---

## Database (Supabase)

### Tabeller

| Tabel | Beskrivelse |
|-------|-------------|
| `profiles` | Brugerprofiler med rolle, FCM token |
| `roles` | Dynamiske roller (label, sort_order, is_system) |
| `hunt_areas` | Jagtområder med center, radius, alarm-config |
| `area_boundaries` | Polygon-punkter for områder |
| `towers` | Poster/tårne (3 typer: jagttårn, skydestige, skudlinje) |
| `tower_reservations` | Post-reservationer (UNIQUE per tårn per event) |
| `hunt_events` | Jagt-events med dato, tid, checkin_enabled |
| `event_boundaries` | Polygon-punkter for events |
| `event_signups` | Event-tilmeldinger |
| `event_checkins` | Check-in/check-out registreringer |
| `event_comments` | Event-kommentarer |
| `chat_channels` | Chatkanaler (general/private/group + required_roles) |
| `channel_members` | Kanal-medlemskaber |
| `chat_messages` | Chatbeskeder (tekst, billede, video) |
| `homepage_blocks` | Forsideblokke (hero, welcome, text, etc.) |
| `app_notifications` | In-app notifikationer |
| `notification_reads` | Læst-status |
| `admin_log` | Admin aktivitetslog |
| `user_locations` | Live GPS-positioner |
| `fcm_tokens` | Push notification tokens |

### Vigtige RLS-funktioner
- `get_my_role()` — SECURITY DEFINER funktion der returnerer brugerens rolle (omgår profiles RLS i subqueries)
- `can_access_channel(channel_id, user_id)` — SECURITY DEFINER funktion der tjekker kanal-adgang uden nested RLS
- `create_channel_with_members(p_name, p_type, p_member_ids)` — SECURITY DEFINER funktion til kanal-oprettelse (bypasser channel_members RLS)
- `hunt_events` policies bruger `get_my_role()` til rolle-check i INSERT/UPDATE/DELETE

---

## CI/CD

GitHub Actions bygger og deployer automatisk ved push til `main`:

1. Flutter 3.41.5 + Java 17
2. Bygger Android APK med release-signering
3. Bygger Flutter web
4. Deployer web til Firebase Hosting
5. Opretter GitHub Release med APsK

### Release-signering
- Keystore: `android/app/upload-keystore.jks`
- Config: `android/key.properties`
- CI bruger base64-encoded keystore fra GitHub Secrets
- VIGTIGT: Lokale og CI builds SKAL bruge samme keystore

### GitHub Secrets
| Secret | Beskrivelse |
|--------|-------------|
| `SUPABASE_URL` | Supabase projekt URL |
| `SUPABASE_ANON_KEY` | Supabase anon nøgle |
| `KEYSTORE_BASE64` | Release keystore (base64) |
| `KEYSTORE_PASSWORD` | Keystore password |
| `GOOGLE_SERVICES_JSON` | Firebase config |
| `FIREBASE_TOKEN` | Firebase CI token |

---

## Lokal udvikling

```bash
# Byg APK (kræver key.properties + keystore)
JAVA_HOME=/home/ex/jdk17 flutter build apk --release

# Installer på enhed
adb install -r build/app/outputs/flutter-apk/app-release.apk

# Byg og deploy web
flutter build web --release
firebase deploy --only hosting
```

### Testenheder
- Xiaomi T26: `22005523022854`
- Samsung: `RFCX208T9NH`

### Testbrugere
| Email | Password | Rolle |
|-------|----------|-------|
| brinchanders@gmail.com | (eget) | admin |
| testjager@jagtapp.dk | test1234 | jaeger_medlem |

---

## Konfiguration

### .env (Android)
```
SUPABASE_URL=https://zbmpptfddowmchuyrrea.supabase.co
SUPABASE_ANON_KEY=<anon-key>
```

### Firebase
- `google-services.json` i `android/app/`
- FCM via Supabase Edge Function `send-push` (--no-verify-jwt)
- Firebase service account gemt som Supabase secret `FIREBASE_SERVICE_ACCOUNT`

### Supabase
- Projekt: `zbmpptfddowmchuyrrea`
- Edge Function: `send-push` for FCM push notifications
- Realtime aktiveret for chat_messages og app_notifications

---

## Kendte begrænsninger
- iOS er ikke konfigureret/testet (kræver Mac + Xcode)
- Email-bekræftelse skal være slået fra i Supabase for signup
- Web har ikke GPS, geofencing eller push notifikationer
- Auto-opdatering kræver at appen er release-signeret med samme nøgle
