# Risinge Jagt App — Status

**Version**: 1.7.1+8
**Sidst opdateret**: 2026-05-13
**Platform**: Android (iOS planlagt)

## Features — Implementeret

### Kort & Geofencing
- [x] Interaktivt kort med OpenStreetMap (flutter_map)
- [x] Jagtomraader med cirkulaer radius og geofencing
- [x] Automatisk GPS tracking (starter naar kort aabnes)
- [x] Smart geofencing — kun for tilmeldte events paa eventdagen
- [x] Geofence advarsler med throttled admin log (max 1/min/omraade)
- [x] Android foreground service for baggrunds-GPS
- [x] Event-graenser som polygoner tegnet af admin
- [x] Auto-checkin naar bruger er inden for 50m af event

### Live overvaagning (admin)
- [x] Bruger-positioner uploades hvert 15 sek til Supabase
- [x] Admin kan se alle brugere paa live-kort i realtid
- [x] Aktiv/inaktiv status (5 min timeout)
- [x] Tap for detaljer (navn, sidst set, position, nojagtighed)

### Kalender & Events
- [x] Kalender med events markeret
- [x] Event-oprettelse med polygon-tegning for jagtgraenser
- [x] Event tilmelding/afmelding med realtime
- [x] Deltager-antal og navne

### Chat
- [x] Generelle kanaler (synlige for member/admin)
- [x] Private chats — tryk paa person, samtale oprettes automatisk
- [x] Gruppe-chats med navnefelt
- [x] Realtime beskeder + kanal-opdateringer

### Notifikationer
- [x] In-app notifikationer med klokkeikonet
- [x] Broadcast fra admin med event-link og scheduling
- [x] FCM push via Supabase Edge Function + database triggers
- [x] Automatisk push ved chat-beskeder og broadcasts
- [x] FCM token management

### Taarntjeneste
- [x] Reservation af jagttaarne
- [x] Kalender-visning

### Admin
- [x] Admin panel: Omraader, Brugere, Broadcast, Live overvaagning, Admin Log
- [x] Admin log med 11+ logtyper inkl. checkin

### Profil & Auth
- [x] Login/registrering via Supabase Auth
- [x] Profil, rolleskift, logout med FCM cleanup

## Kendte begraensninger

| Problem | Beskrivelse |
|---------|-------------|
| TC26 push | FCM virker ikke — Google Play Services 21.15 er for gammel |
| Push test | Ikke testet end-to-end mellem 2 brugere |
| iOS | Kraever Mac + Xcode, se `docs/ios_plan.md` |
| Default rolle | Ny bruger faar muligvis `guest` — saet til `member` i profiles |

## Arkitektur

### Frontend: Flutter 3.41.5
- Riverpod 3.x (AsyncNotifier), GoRouter, Material 3, Dansk lokalisering

### Backend: Supabase
- Auth, PostgreSQL med RLS, Realtime, Edge Function `send-push`

### Push: Firebase Cloud Messaging V1
- Edge Function + database triggers paa chat_messages og app_notifications

### Android
- Foreground service (LocationForegroundService.kt)
- MethodChannel `dk.jagtapp/foreground_service`
- JDK 17 (`org.gradle.java.home=/home/ex/jdk17`)

## Supabase SQL-filer

| Fil | Formaal | Status |
|-----|---------|--------|
| `schema.sql` | Hoved-schema | Baseline |
| `fcm_tokens.sql` | FCM tokens | Koert |
| `push_triggers.sql` | Auto-push triggers | Koert (fixet) |
| `user_locations.sql` | Live positioner + checkins | Koert |
| `event_boundaries.sql` | Event polygon-graenser | Koert |
| `fix_chat_rls.sql` | Chat channels SELECT fix | Koert |
| `fix_chat_realtime.sql` | Realtime for chat-tabeller | Koert |
| `fix_private_chat_v2.sql` | Admin channel_members policy | Koert |

## Naeste skridt

1. **Test alle features** paa 2 telefoner
2. **Test push-notifikationer** end-to-end
3. **iOS build** naar Mac er tilgaengelig
4. **Email confirmation** slaa til naar klar til produktion
