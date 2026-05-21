# Risinge Jagt v1.5.0

Jagtkoordineringsapp til Risinge Herregaard. Flutter + Supabase.

## Funktioner

### Kort (map)
- OpenStreetMap kort med jagtomraader (cirkel-overlay)
- Taarn/post-markorer med farvekoder (ledig/optaget/din)
- GPS-tracking med geofencing — advarsler naer graense og uden for omraade
- **Baggrunds-tracking**: Android foreground service holder GPS aktiv naar appen minimeres
- Smart geofencing: kun aktiv for tilmeldte events paa eventdagen
- Geofence-overtraedelser logges automatisk til admin log

### Kalender
- Maanedsvisning med event-markorer
- Event-kort med titel, beskrivelse, tid, omraade
- Tilmeld/Afmeld knapper for medlemmer og admins
- Deltager-antal og navne synlige paa hvert event
- "Poster" knap til taarn-reservation naar event har omraade

### Taarn-reservation
- Kort med farvekodede taarne (groen=ledig, roed=optaget, blaa=din)
- Reserver/annuller poster pr. event
- Admin kan se hvem der har reserveret og annullere

### Chat
- Kanal-baseret chat med realtime (Supabase Realtime)
- Admin kan oprette kanaler

### Notifikationer
- In-app notifikationer med realtime-opdatering
- Ulaesteantal paa klokke-ikon
- Marker alle laest
- Broadcast til alle medlemmer (fra admin) med valgfri event-tilknytning og tidsplanlaegning

### Admin Panel
- **Jagtomraader**: opret og administrer omraader med kort, radius, alarm-tekst
- **Brugere**: se alle brugere, aendr roller (gaest/medlem/admin)
- **Broadcast**: send besked til alle, valgfrit tilknyt event, planlaeg tidspunkt
- **Admin Log**: komplet aktivitetslog med 11 farvekodede typer

### Admin Log typer
| Type | Ikon | Beskrivelse |
|------|------|-------------|
| new_user | Blaa | Ny bruger oprettet |
| event_signup | Groen | Medlem tilmeldt event |
| event_unsignup | Orange | Medlem afmeldt event |
| geofence_warning | Gul | Naer jagtomraadets graense |
| geofence_outside | Roed | Uden for jagtomraadet |
| reservation | Lilla | Taarn reserveret |
| reservation_cancel | Lilla lys | Reservation annulleret |
| event_created | Teal | Nyt event oprettet |
| area_created | Moerkegroen | Nyt jagtomraade oprettet |
| broadcast | Indigo | Broadcast sendt |
| role_change | Dyb orange | Brugerrolle aendret |

### Profil
- Vis navn, email, rolle
- Rediger visningsnavn
- Admin panel (kun admin)
- Log ud

## Roller
- **Guest**: kan se kort og jagtomraader
- **Member**: kan tilmelde events, reservere poster, chatte, modtage notifikationer
- **Admin**: alt ovenfor + opret events/omraader, administrer brugere, send broadcast, se admin log

## Tech stack
- Flutter 3.x med Riverpod 3 (AsyncNotifier)
- Supabase (Auth, PostgreSQL, Realtime)
- GoRouter med auth redirect
- flutter_map + OpenStreetMap
- Geolocator (GPS tracking) + Android Foreground Service
- flutter_local_notifications
- table_calendar
- Package: dk.jagtapp.jagt_app

## Build
```bash
flutter build apk --release
```
Kraever JDK 17 (gradle.properties: org.gradle.java.home=/home/ex/jdk17)

## Supabase SQL
Koer i raekkefoelge:
1. `supabase/notifications.sql`
2. `supabase/event_signups_and_log.sql`
3. `supabase/fix_dummy_data.sql` (testdata)

## Versionshistorik

### v1.5.0 (2026-05-12)
- Baggrunds-geofencing via Android foreground service
- Event tilmelding/afmelding med realtime
- Smart geofencing (kun tilmeldte events paa eventdagen)
- Admin log med 11 typer + dedicated log-side
- Broadcast-side med event-tilknytning og tidsplanlaegning
- Admin panel: 4 menupunkter

### v1.3.0 (2026-05-11/12)
- Taarn-reservation med farvekodede kort
- In-app notifikationer med realtime
- Broadcast fra admin
- Geofencing med alarm-tekst og margin
- Logo i AppBar

### v1.0.0
- Kort med jagtomraader
- Kalender med events
- Chat med kanaler
- Brugerroller (guest/member/admin)
- Profil med admin panel

## Hvad er faerdigt
- [x] Kort med jagtomraader og taarn-markorer
- [x] GPS tracking med geofencing
- [x] Baggrunds-tracking (foreground service)
- [x] Smart geofencing (kun tilmeldte events)
- [x] Kalender med events
- [x] Event tilmelding/afmelding
- [x] Taarn/post-reservation pr. event
- [x] Chat med kanaler (realtime)
- [x] In-app notifikationer (realtime)
- [x] Broadcast med event-tilknytning og tidsplanlaegning
- [x] Admin log (11 typer, logges automatisk)
- [x] Admin panel (omraader, brugere, broadcast, log)
- [x] Rollebaseret adgang (guest/member/admin)
- [x] Profil med navneredigering
- [x] Logo og branding

## Hvad mangler
- [ ] FCM push notifikationer (server-push naar appen er lukket) — kraever Firebase-projekt
- [ ] iOS konfiguration og test — kraever macOS + Xcode + Apple Developer konto
- [ ] Email-bekraeftelse toggle — slaa fra i Supabase Dashboard > Authentication > Providers > Email

## Naeste skridt
1. **FCM push**: Opret Firebase-projekt, hent google-services.json, integrer firebase_messaging
2. **iOS**: Konfigurer Xcode-projekt, tilfoej APNs certifikat, test paa fysisk enhed
3. **Produktion**: Signing key, Play Store / TestFlight distribution
4. **Nice-to-have**: Billedupload i chat, event-redigering, statistik-dashboard for admin
