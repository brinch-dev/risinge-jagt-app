# Risinge Jagtvæsen — Sessionslog

Kronologisk oversigt over alle udviklingssessioner.

---

## Session 1: 2026-05-11 — v1.0.0 (Grundlæggende app)

### Hvad blev lavet
- Projekt-setup med Flutter + Supabase
- Modeller: user_profile, hunt_area, hunt_event, tower, chat_channel, chat_message
- Providers: auth, event, map, chat, location (alle med Riverpod AsyncNotifier)
- UI: login, kort, kalender, chat, profil, admin panel
- OpenStreetMap kort med områdecirkler og tårne
- Geofencing med område-specifik alarm
- Admin: opret områder med kort/adresse-søgning

### Bugs fundet og løst
- Java 25 → JDK 17 (Gradle kræver det)
- Core library desugaring for Android 10
- Riverpod 3.x API ændringer (StateNotifier → AsyncNotifier)
- Emulator for langsom → skiftet til fysisk enhed

---

## Session 2: 2026-05-12 — v1.3.0 → v1.5.0

### v1.3.0: Branding og reservationer
- App-ikon med Risinge Herregaard logo
- Post/tårn-reservationssystem med realtime
- Farvekoder på kort (grøn/rød/blå)
- INTERNET permission fix for release builds (KRITISK)

### v1.4.0: Events og admin log
- Event tilmelding/afmelding med realtime og deltagerliste
- Admin log med 11 logtyper og farvekoder
- Smart geofencing (kun tilmeldte events)
- Broadcast-side med event-tilknytning og tidsplanlægning

### v1.5.0: Baggrunds-geofencing
- Android Foreground Service for GPS tracking i baggrunden
- LocationForegroundService.kt med persistent notifikation
- MethodChannel til start/stop fra Flutter

---

## Session 3: 2026-05-13 — Push notifications og live-overvågning

### Hvad blev lavet
- Chat RLS fix (opretteren kunne ikke se sin egen kanal)
- FCM Push via Supabase Edge Function `send-push`
- Database triggers for automatisk push ved chat og broadcast
- Admin live-overvågning med brugerpositioner hvert 15 sek
- Auto-checkin inden for 50m af event-område
- Event-grænser med polygon-tegning
- Privat chat forenklet (tryk på person → samtale oprettes)

### Bugs fundet og løst
- Chat channels SELECT RLS blokerede opretterens egen kanal
- Push triggers fejlede → fixet med `pg_net` extension

---

## Session 4: 2026-05-16 — v1.9.2 (Kodeaudit)

### Bugfixes (14 stk)
1. Fjernet jagtgrænse-kort fra edit event (unødvendig kompleksitet)
2. Fjernet område-dropdown (kun ét jagtområde)
3. Custom jagttårn-ikon via CustomPainter
4. Zoom og overlay-knapper på kortet (+, -, kortlag, min position)
5. Chat-sletning virkede ikke (manglende DELETE RLS)
6. Chat-kanalernes rækkefølge fixet
7. cancelReservation manglede user_id filter (sikkerhedsbug)
8. Event comment select manglede full_name
9. Notifikation rolle-filtrering manglede
10. writeAdminLog brugte dynamic ref → WidgetRef
11. NotificationService manglede initialize()
12. Chat auto-scroll fixet
13. Diverse UI-forbedringer

---

## Session 5: 2026-05-17 — v1.9.4

### Hvad blev lavet
- Chat-kanal administration i admin panel
- Kort centrerer automatisk på jagtområdets grænser
- Kalender starter i ugevisning med dagens dato valgt
- Post-typer: jagttårn, skydestige, skudlinje (med unikke ikoner)
- Forside velkomst-sektion med stort "Hej, [navn]"
- Afstandsmåler på kort (lineal-ikon)

---

## Session 6: 2026-05-19 — v2.0.0

### Hvad blev lavet
- Web version deployeret til Firebase Hosting
- Medie-support i chat (billeder og video)
- Tårn-billeder og beskrivelser
- Push notifikationer (FCM) fuldt integreret
- Forbedret chat realtime med 3s polling fallback
- kIsWeb guards for platform-specifik kode
- Dynamisk rolle-admin panel
- Moderne forside med SliverAppBar hero

---

## Session 7: 2026-05-21 — v2.3.0

### Hvad blev lavet
- Admin kan slette individuelle chat-beskeder (long-press)
- Video-optagelse direkte fra chat (kamera)
- Check-in/check-ud toggle på events (checkin_enabled felt)
- Chat RLS fix med SECURITY DEFINER funktion `can_access_channel()`

### SQL kørt
- `fix_chat_rls_v3.sql` — SECURITY DEFINER funktion for nested RLS
- `v2.3_checkin_toggle.sql` — checkin_enabled kolonne på hunt_events

---

## Session 8: 2026-05-21/22 — v2.3.1 → v2.3.8

### CI/CD og auto-opdatering
- GitHub Actions pipeline: byg APK + web → deploy → GitHub Release
- Release-signering med keystore
- Auto-opdatering via GitHub Releases API
- Streaming APK-download (undgår memory-problemer)
- Husk afvist opdateringsversion
- Browser-fallback ved fejlet installation
- Versionsnummer synligt på profilsiden

### Bugs fundet og løst
- **Gradle keystore-sti forkert**: `rootProject.file("app/key.properties")` → `rootProject.file("key.properties")`. Release-signering virkede aldrig (hverken lokalt eller CI). Alle APK'er var debug-signeret med forskellige nøgler.
- **Admin slet-besked virkede ikke**: `role == 'admin'` sammenlignede enum med streng (altid false). Ændret til `.isAdmin`.
- **Auto-opdatering viste dialog hver gang**: Tilføjet SharedPreferences til at huske afvist version.
- **APK installation fejlede**: Signerings-mismatch mellem debug og release. Løst ved at fixe keystore-sti og geninstallere med release-signeret APK.

---

## Session 9: 2026-05-22 — v2.3.9 → v2.4.0

### Chat-kanaler
- Træk-og-slip rækkefølge for generelle chatkanaler i admin panel (ReorderableListView)
- `sort_order` opdateres i Supabase ved genordning

### Dashboard widgets
- 6 nye bloktyper: `next_event`, `event_stats`, `weather`, `my_reservations`, `recent_chat`, `countdown`
- Vejrudsigt via Open-Meteo API (gratis, ingen nøgle) med temperatur, vind, fugtighed, solopgang/solnedgang
- Mine reservationer: viser brugerens kommende tårnreservationer
- Seneste chat: viser 5 nyeste beskeder på tværs af kanaler
- Nedtælling: "I DAG", "I MORGEN" eller "X DAGE" til næste event
- Admin kan tilføje/fjerne/aktivere/deaktivere alle widgets via forside-editor
- Rollebaseret synlighed via `visible_roles` på alle blokke
- Info-kort beholdt for bagudkompatibilitet
- Dynamiske blokke viser info-besked i admin ("genereres automatisk")

---

## Session 10: 2026-05-22/23 — v2.4.0 → v2.5.2

### Dashboard redesign
- Sort/hvid tema på alle dashboard widgets (mørke kort 0xFF1A1A1A med hvid tekst)
- Nedtælling: hvidt kort med sort border og sort badge
- Klikbare widgets: næste event/nedtælling/event-statistik → kalender, mine reservationer → kort, seneste chat → chat
- Tab-navigation via Riverpod `tabIndexProvider` (NotifierProvider)
- Fjernet gamle info-kort (info_cards bloktype)

### Bugfixes
- **Events ikke synlige for jægermedlem**: RLS policy på `hunt_events` brugte `role = 'member'` i stedet for `'jaeger_medlem'`. Droppet gammel policy og oprettet ny med `USING (true)` for alle authenticated users.
- **Events skjult mens profil loader**: `canSeeAllEvents ?? false` skjulte events når profil var null. Ændret til `?? true`.
- **Chat kanal-oprettelse fejlede for ikke-admin (42501)**: `channel_members` INSERT blokeret af RLS. Oprettet SECURITY DEFINER funktion `create_channel_with_members()` og opdateret `createChannel` til at bruge `client.rpc()`.
- **Kamera/medie-upload virkede ikke**: Manglende Android permissions (CAMERA, READ_MEDIA_IMAGES, READ_MEDIA_VIDEO). Tilføjet til AndroidManifest.xml.

### Realtime events (v2.4.7)
- Events provider lytter nu på `hunt_events` via Supabase Realtime
- Alle brugere ser oprettede/slettede/redigerede events live uden genstart

### RLS-oprydning (v2.4.8)
- `get_my_role()` SECURITY DEFINER funktion — returnerer brugerens rolle uden at ramme profiles RLS
- Komplet sæt RLS policies for `hunt_events` (SELECT/INSERT/UPDATE/DELETE) via `get_my_role()`
- INSERT tilladt for: admin, jaeger_medlem, ejer, forvalter, bb_direktoer
- UPDATE/DELETE: admin/jaeger_medlem/bb_direktoer (alle), ejer/forvalter (egne)
- Komplet sæt RLS policies for `event_signups` og `event_comments`
- `profiles_select_all` policy tilføjet (brugere kunne ikke læse profiler)
- Verificeret med API-test: SELECT, INSERT, DELETE virker for jaeger_medlem

### Nye features (v2.5.0)
- Næste event widget navigerer til event detaljer i stedet for kalender
- Kommende reservationer: limit 5 og klik åbner det specifikke event
- Chat kanal-beskrivelse: admin kan tilføje beskrivelse til generelle kanaler (nyt `description` felt)
- Event-statistik widget viser kun antal kommende (fjernet tilmeldte-antal)
- Vejrdata på event-oprettelsesside: sol op/ned og temperatur baseret på jagtområdets koordinater

### SQL kørt
- `create_channel_with_members()` — SECURITY DEFINER funktion til kanal-oprettelse
- DROP + CREATE policy på `hunt_events` — åben SELECT for alle authenticated users
- `fix_hunt_events_rls_v2.sql` — komplet RLS oprydning med get_my_role() funktion
- INSERT INTO profiles for testjager@jagtapp.dk (manglede profil-række)
- ALTER TABLE chat_channels ADD COLUMN description TEXT
- Fix app_notifications og notification_reads RLS policies

---

## Session 11: 2026-05-23 — v2.5.3 → v2.5.4

### v2.5.3: Tilmeld event fra postsiden
- "Tilmeld event først"-knap tilmelder bruger direkte og skifter til "Reserver"
- Vejrdata (sol op/ned, temperatur) vises på event detaljesiden

### v2.5.4: Komplet farvetema redesign
- Nyt jagt-inspireret farveskema med forest green, sand/cream og guld accenter
- `theme.dart` omskrevet med komplette light og dark temaer
- Tilføjet Material 3 `surfaceContainer` varianter til begge temaer
- Alle 11 widget-filer opdateret til at bruge `Theme.of(context).colorScheme` i stedet for hardcoded farver
- Dashboard widgets: fjernet hardcoded `#1A1A1A` baggrund → bruger tema card-farve
- Chat: bobler, avatarer og tidsstempler bruger tema-farver
- Kalender: status-farver og event-kort tilpasset
- Admin panel: alle ikoner ensrettet med primary-farve
- Notifications, profil, kort detaljer: alle theme-aware
- Fuld kompatibilitet med både light og dark mode

### Filer ændret
- `lib/app/theme.dart` — komplet omskrivning med jagt-farvepalet
- `lib/features/home/home_page.dart` — alle widgets theme-aware
- `lib/features/calendar/presentation/pages/event_detail_page.dart`
- `lib/features/calendar/presentation/pages/calendar_page.dart`
- `lib/features/chat/presentation/pages/chat_page.dart`
- `lib/features/chat/presentation/pages/chat_list_page.dart`
- `lib/features/profile/presentation/pages/profile_page.dart`
- `lib/features/admin/presentation/pages/admin_panel_page.dart`
- `lib/features/admin/presentation/pages/create_event_page.dart`
- `lib/features/notifications/presentation/pages/notifications_page.dart`
- `lib/features/map/presentation/widgets/area_detail_sheet.dart`

---

## Kendte begrænsninger og fremtidige opgaver

### Begrænsninger
- iOS ikke konfigureret (kræver Mac + Xcode)
- Web mangler GPS, geofencing og push
- TC26 Google Play Services for gammel til FCM

### Mulige fremtidige features
- iOS build
- Tårn-billeder i galleri
- Event-kommentarer udvidet
- Offline-mode
