# Risinge Jagt App — v1.8.0-test Dokumentation

**Version**: 1.8.0-test+10
**Dato**: 2026-05-14
**Platform**: Android (iOS planlagt)
**Package**: dk.jagtapp.jagt_app

---

## Oversigt

Risinge Jagt App er en jagtkoordineringsapp for Risinge Herregaard. Appen haandterer kort med jagtomraader, live overvaagning, events med tilmelding og noter, chat, push-notifikationer og administration.

---

## 1. Arkitektur

### Frontend
- **Flutter 3.41.5** med Dart SDK >=3.0.0
- **Riverpod 3.x** — state management med AsyncNotifier
- **GoRouter** — navigation med auth redirect
- **Material 3** — UI framework
- **Dansk lokalisering** via intl

### Backend
- **Supabase** — Auth, PostgreSQL med RLS, Realtime, Edge Functions
- **Firebase Cloud Messaging V1** — push-notifikationer
- Supabase projekt: `zbmpptfddowmchuyrrea`
- Firebase projekt: `risinge-jagt`

### Android
- **Foreground Service** (`LocationForegroundService.kt`) for baggrunds-GPS
- **MethodChannel** `dk.jagtapp/foreground_service`
- JDK 17 (`org.gradle.java.home=/home/ex/jdk17`)

---

## 2. Features

### 2.1 Kort & Jagtomraader

**Polygon-baserede jagtomraader**
- Admin tegner jagtomraader som polygoner (minimum 3 punkter)
- Omraader vises som groenne polygoner paa kortet
- Adressesoegning via Nominatim (OpenStreetMap)
- Risinge Herregaard omraade: 1900m cirkulaert polygon (36 punkter) fra Risingevej 7, 5540 Ullerslev

**Filer:**
- `lib/features/admin/presentation/pages/create_area_page.dart` — polygon-tegning UI
- `lib/features/admin/presentation/pages/manage_areas_page.dart` — oversigt/sletning
- `lib/providers/area_boundary_provider.dart` — CRUD for polygon-punkter
- `lib/models/hunt_area.dart` — model
- `supabase/area_boundaries.sql` — tabel

### 2.2 GPS & Live Overvaagning

**Automatisk GPS tracking**
- GPS starter automatisk naar bruger er inden for et jagtomraade-polygon
- Foreground service for baggrunds-tracking
- Position uploades til Supabase hvert 15 sekund
- GPS stopper automatisk naar bruger forlader omraadet
- Groen statusbar "GPS aktiv" naar tracking koerer

**Live positioner paa kort**
- Brugere med `can_monitor=true` eller admin ser ALTID alle brugeres positioner
- Normale medlemmer ser kun andre naar de selv er i et jagtomraade
- Gaester ser ingen live positioner
- Orange prikker = aktive brugere (inden for 5 min), graa = inaktive
- Navnelabel over hver bruger-prik

**Admin Live Overvaagning (separat side)**
- Admin panel → "Live overvaagning"
- Viser alle brugere med positioner uanset admin placering
- Blaa prikker = aktiv, graa = inaktiv
- Tap for detaljer (navn, sidst set, position, noejagtighed)

**Visibilitetsregler:**

| Rolle | Ser live positioner | Betingelse |
|-------|-------------------|------------|
| Admin | Alle | Altid |
| can_monitor (Maria, Claus, Daniel, Henrik) | Alle | Altid |
| Member | Alle i omraadet | Kun naar selv i omraadet |
| Guest | Ingen | — |

**Filer:**
- `lib/features/map/presentation/pages/map_page.dart` — hovedkort med GPS logik
- `lib/providers/live_location_provider.dart` — GPS upload + admin location view
- `lib/features/admin/presentation/pages/live_map_page.dart` — admin live kort
- `lib/services/foreground_service.dart` — Android foreground service

### 2.3 Geofencing

**Smart geofencing med polygon**
- Kun aktiv for tilmeldte events paa eventdagen
- Advarsel naar bruger naermer sig graensen (alarm margin, default 150m)
- Roed banner naar bruger er uden for omraadet
- Throttled admin log (max 1 pr. minut pr. omraade)
- Notifikation via flutter_local_notifications

**Point-in-polygon algoritme**
- Ray casting algoritme i `LocationService`
- Distance til polygon boundary via segment-distance beregning

**Filer:**
- `lib/providers/location_provider.dart` — `LocationService` med `isInsidePolygon()`, `isNearPolygonBoundary()`, `distanceToPolygonBoundary()`

### 2.4 Auto-Checkin

- Naar bruger er inden for et event-omraades polygon (tilmeldt, paa eventdagen)
- Groen "Check ind" kort vises automatisk
- Checkin gemmes i `event_checkins` tabel
- Logges i admin log som 'checkin' type
- Bekraeftelsesbesked efter checkin

### 2.5 Event-graenser (Event Boundaries)

- Admin kan tegne praecise jagtgraenser ved event-oprettelse
- Tegne-knap aktiverer tegne-mode paa kortet
- Fortryd og slet knapper
- Minimum 3 punkter for polygon
- Punkt-nummerering med groen start-punkt
- Graenser vises som roede polygoner paa hovedkortet for kommende events

**Filer:**
- `lib/features/admin/presentation/pages/create_event_page.dart` — polygon-tegning
- `lib/providers/event_boundary_provider.dart` — CRUD
- `supabase/event_boundaries.sql` — tabel

### 2.6 Kalender & Events

**Kalendervisning**
- Maanedskalender med events markeret
- Dansk lokalisering
- Tryk paa dato for at se events
- Event-kort med status-oversigt

**Event-detaljer (NY)**
- Tryk paa event → fuld detaljeside
- Aktivitetsnavn, dato, klokkeslet, beskrivelse, omraade
- Link til postreservation

**3-state tilmelding (NY)**
- **Tilmeldt** (groen) — bruger deltager
- **Kommer ikke** (roed) — bruger har set men deltager ikke
- **Ikke reageret** (graa) — bruger har ikke reageret
- Alle medlemmer vises med deres status
- Upsert-baseret saa man kan skifte status

**Event-noter/kommentarer (NY)**
- Alle medlemmer kan skrive noter til et event
- Realtime opdatering
- Slet egne kommentarer
- Viser forfatter og tidspunkt

**Filer:**
- `lib/features/calendar/presentation/pages/calendar_page.dart` — kalender
- `lib/features/calendar/presentation/pages/event_detail_page.dart` — detaljer (NY)
- `lib/features/admin/presentation/pages/create_event_page.dart` — oprettelse
- `lib/models/hunt_event.dart` — model
- `lib/models/event_signup.dart` — med status felt (OPDATERET)
- `lib/models/event_comment.dart` — model (NY)
- `lib/providers/event_signup_provider.dart` — signup/decline/unsignup (OPDATERET)
- `lib/providers/event_comment_provider.dart` — CRUD med realtime (NY)

### 2.7 Chat

**Chattyper:**

| Type | Navn | Synlighed | Beskrivelse |
|------|------|-----------|-------------|
| General | Jaeger Chat | Alle member/admin | Faelles jaeger-chat |
| Group | Admin Chat | Udvalgte | Oprettes manuelt af admin |
| Private | (auto-navn) | 2 brugere | Tryk paa person → samtale |
| Group | (brugernavn) | Udvalgte | Vaelg flere medlemmer |

**Features:**
- Realtime beskeder
- Kanal-opdateringer via Supabase Realtime
- Privat chat: tryk direkte paa person, samtale oprettes automatisk
- Gruppe-chat: navnefelt + checkboxes for medlemmer
- Egen bruger filtreres fra listen
- Dobbelt-klik beskyttelse under loading

**Filer:**
- `lib/features/chat/presentation/pages/chat_list_page.dart` — oversigt
- `lib/features/chat/presentation/pages/chat_page.dart` — besked-visning
- `lib/features/chat/presentation/pages/create_channel_page.dart` — oprettelse
- `lib/providers/chat_provider.dart` — channels + messages med realtime
- `lib/models/chat_channel.dart` — model
- `lib/models/chat_message.dart` — model

### 2.8 Notifikationer

**In-app notifikationer**
- Klokkeikon i appbar
- Broadcast fra admin med event-link og scheduling

**Push-notifikationer (FCM)**
- Edge Function `send-push` haandterer 3 typer:
  - `chat_message` — besked i chat
  - `broadcast` — admin broadcast
  - `event_notification` — nyt event
- Database triggers paa `chat_messages` og `app_notifications`
- Auto-cleanup af ugyldige FCM tokens
- JWT-baseret Firebase auth med RS256

**Filer:**
- `supabase/functions/send-push/index.ts` — Edge Function
- `supabase/push_triggers.sql` — database triggers
- `lib/services/notification_service.dart` — lokal notifikation
- `lib/providers/notification_provider.dart` — in-app

### 2.9 Taarntjeneste (Poster)

- Poster/taarne tilknyttes jagtomraader
- Reservation af poster per event
- Farvekodning: groen (ledig), blaa (din), roed (optaget)
- Synlig paa kort med ikon

### 2.10 Admin Panel

- **Omraader** — opret/slet jagtomraader med polygon
- **Poster** — opret/slet poster i omraader
- **Brugere** — oversigt over registrerede brugere
- **Broadcast** — send beskeder til alle
- **Live overvaagning** — realtids-kort med alle brugere
- **Admin Log** — 11+ logtyper inkl. checkin, geofence, signup

### 2.11 Profil & Auth

- Login/registrering via Supabase Auth
- Profil med visningsnavn
- Rolleskift (admin)
- Logout med FCM token cleanup

---

## 3. Brugerroller

| Rolle | Kort | Kalender | Chat | Admin | Live pos. |
|-------|------|----------|------|-------|-----------|
| Guest | Kun kort | Nej | Nej | Nej | Nej |
| Member | Fuld | Fuld | Fuld | Nej | Kun i omraade |
| Admin | Fuld | Fuld + opret | Fuld | Fuld | Altid |
| can_monitor | Fuld | Fuld | Fuld | Nej | Altid |

**can_monitor brugere:** Maria, Claus, Daniel, Henrik
- Kan se alle brugeres positioner uanset egen placering
- Faar popup naar en bruger ankommer til omraadet (planlagt)

---

## 4. Medlemsliste

Fra adresselisten Risinge Jagtvæsen pr. 22. April 2026:

| # | Navn | Adresse | Mobil | Email | Riffeljagt | Hund |
|---|------|---------|-------|-------|------------|------|
| 1 | Daniel Brohave Hasselstroem | Risingevej 7a, 5540 Ullerslev | 31 66 49 92 | dhasselstrom@gmail.com | X | Springer, Chesapeake |
| 2 | Henrik Staer | | 40 16 31 42 | henrik.staer@colas.dk | X | |
| 3 | Christina Jensen | Sdr. Hoejrupvejen 64, 5750 Ringe | 30 72 00 46 | c616600823@gmail.com | | |
| 4 | Bent Mathiasen | Sdr. Hoejrupvejen 64, 5750 Ringe | 40 16 54 89 | bma@colas.dk | X | |
| 5 | Uffe Kongstad | Torpevænget 12, 5792 Aarslev | 34 48 21 38 | ukongstad@hotmail.com | X | Labrador |
| 6 | Jan Palmgren Nielsen | Risingevej 9, 5540 Ullerslev | 30 70 65 12 | janpalmgren1969@hotmail.com | X | Springer x2 |
| 7 | Rasmus Jensen | Kongshøj Alle 62, 5300 Kerteminde | 20 73 62 95 | twr@hotmail.dk | X | |

**Specielle roller:**

| Rolle | Navn | Adresse | Mobil | Email |
|-------|------|---------|-------|-------|
| Jagtudlejer | Charlotte Bille-Hasselstroem | Fraugdegaard alle 7 | 51 30 30 07 | cbh@fraugdegaard.dk |
| Jagtudlejer | Mathias Bille-Hasselstroem | Fraugdegaard alle 7 | 31 53 01 99 | mbh@fraugdegaard.dk |
| Driftsleder | Claus | Risingevej 4 | 21 43 11 35 | cj@risinge.dk |
| Direktoer B&B | Maria Hasselstroem | Risingevej 7a | 28 79 73 61 | maria@risinge.dk |

---

## 5. Database Schema

### Tabeller

| Tabel | Formaal | Vigtige kolonner |
|-------|---------|-----------------|
| `profiles` | Brugerprofiler | id, email, display_name, role, can_monitor |
| `hunt_areas` | Jagtomraader | id, name, center_lat/lng, radius_meters, alarm_text, alarm_margin_meters |
| `area_boundaries` | Polygon-punkter for omraader | area_id, point_order, latitude, longitude |
| `hunt_events` | Jagtevents | id, title, description, date, start_time, end_time, area_id |
| `event_boundaries` | Polygon-punkter for events | event_id, point_order, latitude, longitude |
| `event_signups` | Tilmeldinger med status | event_id, user_id, status (attending/not_attending) |
| `event_comments` | Noter paa events | event_id, user_id, body |
| `event_checkins` | Auto-checkin | event_id, user_id, latitude, longitude |
| `towers` | Poster/taarne | id, name, lat, lng, area_id |
| `tower_reservations` | Post-reservationer | tower_id, event_id, user_id |
| `chat_channels` | Chat-kanaler | id, name, type (general/private/group) |
| `channel_members` | Kanal-medlemmer | channel_id, user_id |
| `chat_messages` | Beskeder | channel_id, sender_id, content |
| `user_locations` | Live positioner | user_id, latitude, longitude, accuracy |
| `app_notifications` | In-app notifikationer | title, body, type, sender_id |
| `fcm_tokens` | Push tokens | user_id, token |
| `admin_log` | Admin log | type, message, user_id |

### SQL-filer

| Fil | Formaal | Status |
|-----|---------|--------|
| `schema.sql` | Hoved-schema (profiles, areas, towers, events, chat) | Baseline |
| `event_signups_and_log.sql` | Tilmeldinger + admin log | Koert |
| `fcm_tokens.sql` | FCM tokens | Koert |
| `push_triggers.sql` | Auto-push triggers | Koert (fixet) |
| `user_locations.sql` | Live positioner + checkins | Koert |
| `event_boundaries.sql` | Event polygon-graenser | Koert |
| `area_boundaries.sql` | Omraade polygon-graenser | Koert |
| `fix_chat_rls.sql` | Chat channels SELECT fix | Koert |
| `fix_chat_realtime.sql` | Realtime for chat-tabeller | Koert |
| `fix_private_chat_v2.sql` | Admin channel_members policy | Koert |
| `v1.8.0_migration.sql` | can_monitor, status, comments, Risinge omraade | Koert |

---

## 6. Filstruktur

```
lib/
├── app/
│   ├── app.dart                    — MaterialApp opsaetning
│   └── router.dart                 — GoRouter med auth
├── bootstrap.dart                  — Supabase init
├── features/
│   ├── admin/presentation/pages/
│   │   ├── admin_panel_page.dart   — Admin menu
│   │   ├── create_area_page.dart   — Polygon-tegning for omraader
│   │   ├── create_event_page.dart  — Event + polygon-tegning
│   │   ├── live_map_page.dart      — Admin live overvaagning
│   │   ├── manage_areas_page.dart  — Omraade-oversigt
│   │   ├── manage_towers_page.dart — Post-administration
│   │   └── admin_log_page.dart     — Log-visning
│   ├── auth/presentation/pages/
│   │   └── login_page.dart         — Login/registrering
│   ├── calendar/presentation/pages/
│   │   ├── calendar_page.dart      — Maanedskalender
│   │   └── event_detail_page.dart  — Event detaljer + tilmelding + noter
│   ├── chat/presentation/pages/
│   │   ├── chat_list_page.dart     — Kanal-oversigt
│   │   ├── chat_page.dart          — Besked-visning
│   │   └── create_channel_page.dart — Opret samtale
│   ├── home/
│   │   └── home_shell.dart         — Bottom navigation
│   ├── map/presentation/
│   │   ├── pages/map_page.dart     — Hovedkort med GPS
│   │   └── widgets/area_detail_sheet.dart — Omraadedetaljer
│   ├── notifications/presentation/
│   │   └── widgets/notification_bell.dart
│   ├── profile/presentation/pages/
│   │   └── profile_page.dart
│   └── towers/presentation/pages/
│       └── tower_reservation_page.dart
├── models/
│   ├── chat_channel.dart
│   ├── chat_message.dart
│   ├── event_comment.dart          — NY
│   ├── event_signup.dart           — OPDATERET med status
│   ├── hunt_area.dart
│   ├── hunt_event.dart
│   ├── tower.dart
│   ├── tower_reservation.dart
│   └── user_profile.dart           — OPDATERET med can_monitor
├── providers/
│   ├── admin_log_provider.dart
│   ├── area_boundary_provider.dart — NY
│   ├── auth_provider.dart
│   ├── chat_provider.dart
│   ├── event_boundary_provider.dart
│   ├── event_comment_provider.dart — NY
│   ├── event_provider.dart
│   ├── event_signup_provider.dart  — OPDATERET
│   ├── live_location_provider.dart
│   ├── location_provider.dart      — OPDATERET med polygon-metoder
│   ├── map_provider.dart
│   └── notification_provider.dart
├── services/
│   ├── foreground_service.dart
│   └── notification_service.dart
└── main.dart
```

---

## 7. Supabase Edge Function

### send-push (`supabase/functions/send-push/index.ts`)

Haandterer 3 notifikationstyper:
- `chat_message` — sender til alle kanal-medlemmer undtagen afsender
- `broadcast` — sender til alle brugere undtagen afsender
- `event_notification` — sender til alle brugere undtagen afsender

Teknologi:
- Direkte REST calls (ingen externe dependencies pga. Docker DNS)
- JWT-baseret Firebase auth med RS256
- Auto-cleanup af ugyldige FCM tokens
- Deployed med `--no-verify-jwt`

---

## 8. Kendte begraensninger

| Problem | Beskrivelse |
|---------|-------------|
| TC26 push | FCM virker ikke paa TC26 — Google Play Services 21.15 er for gammel |
| Push test | Ikke testet end-to-end mellem 2 brugere |
| iOS | Kraever Mac + Xcode, se `docs/ios_plan.md` |
| Default rolle | Ny bruger faar `guest` — saet til `member` manuelt i profiles |
| Gaester | Kan kun se kort, ikke kalender/chat (RLS begrænsning) |
| Arrival popup | Popup til monitors naar bruger ankommer er planlagt men ikke implementeret |
| Gamle omraader | Cirkel-baserede omraader vises ikke — skal gen-oprettes med polygon |

---

## 9. Opsaetning for ny installation

### 1. Supabase
1. Koer alle SQL-filer i raekkefoelge (se sektion 5)
2. Saet `can_monitor = true` for Maria, Claus, Daniel, Henrik
3. Deploy Edge Function: `supabase functions deploy send-push --no-verify-jwt`
4. Saet Firebase secret: `supabase secrets set FIREBASE_SERVICE_ACCOUNT='...'`

### 2. Firebase
1. Projekt: `risinge-jagt`
2. Android app: `dk.jagtapp.jagt_app`
3. Download `google-services.json` til `android/app/`
4. Generer service account key → gem som Supabase secret

### 3. Flutter
1. `.env` fil med `SUPABASE_URL` og `SUPABASE_ANON_KEY`
2. `flutter pub get`
3. `flutter build apk --release`
4. APK: `releases/jagt-app-v1.8.0-test.apk`

### 4. Brugere
1. Registrer alle jaegere med email fra medlemslisten
2. Saet rolle til `member` i profiles
3. Saet `can_monitor = true` for de 4 specifikke brugere
4. Saet mindst 1 bruger som `admin`

---

## 10. Naeste skridt

1. **Test alle features** paa 2 telefoner
2. **Koer can_monitor UPDATE** naar de 4 brugere har registreret sig
3. **Opret Admin Chat** som gruppe-chat i appen
4. **Test push-notifikationer** end-to-end
5. **Implementer arrival popup** for monitors
6. **iOS build** naar Mac er tilgaengelig
7. **Registrer alle jaegere** fra medlemslisten
