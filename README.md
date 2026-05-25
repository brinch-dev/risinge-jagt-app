# Risinge Jagtvæsen v2.5.9

Jagtkoordineringsapp til Risinge Herregaard. Flutter + Supabase.
Tilgængelig som Android app og web app.

- **Web**: https://risinge-jagt.web.app
- **Android APK**: https://github.com/brinch-dev/risinge-jagt-app/releases/latest

## Funktioner

### Forside
- Dynamisk forside med konfigurerbare blokke (tekst, billede, info)
- Dashboard widgets: næste event, nedtælling, event-statistik, vejrudsigt, mine reservationer, seneste chat
- Admin kan tilføje/fjerne/aktivere/deaktivere widgets med rollebaseret synlighed
- Admin kan redigere forsideindhold via admin panel

### Kort
- OpenStreetMap kort med jagtområder (polygon-grænser)
- Tårn/post-markører med farvekoder (ledig/optaget/din)
- Tårninfo med beskrivelse, type og billedgalleri
- GPS-tracking med geofencing — advarsler nær grænse og uden for område
- Baggrunds-tracking via Android foreground service
- Check-in/check-ud flow (kun events med checkin aktiveret)

### Kalender
- Månedsvisning med event-markører
- Event-kort med titel, beskrivelse, tid, område
- Tilmeld/Afmeld knapper
- Deltager-antal og navne synlige
- Poster-knap til tårn-reservation

### Tårn-reservation
- Kort med farvekodede tårne (grøn=ledig, rød=optaget, blå=din)
- Reserver/annuller poster pr. event
- Admin kan se og annullere reservationer

### Chat
- Kanal-baseret chat med realtime (Supabase Realtime + polling fallback)
- Tekst, billeder og video
- Billede fra galleri eller kamera
- Video fra galleri eller optag direkte
- Admin kan slette enkeltstående beskeder (long-press)
- Push notifikationer ved nye beskeder (Android)
- Generelle kanaler (synlige for alle) og private/gruppe kanaler

### Notifikationer
- In-app notifikationer med realtime-opdatering
- FCM push notifikationer (Android)
- Ulæsteantal på klokke-ikon
- Marker alle læst
- Push ved chat-beskeder, broadcasts og events

### Admin Panel
- **Jagtområder**: opret og administrer områder med polygon-grænser
- **Tårne/poster**: opret med beskrivelse, type og billeder
- **Brugere**: se alle brugere, ændr roller (gæst/medlem/admin)
- **Chat kanaler**: administrer kanaler
- **Broadcast**: send besked til alle
- **Events**: opret/rediger med check-in/ud toggle
- **Forside**: rediger forsideblokke
- **Roller**: administrer tilgængelige roller
- **Admin Log**: komplet aktivitetslog

### Profil
- Vis navn, email, rolle
- Rediger visningsnavn
- Versionsnummer synligt
- Admin panel adgang (kun admin)
- Log ud

### Auto-opdatering
- App tjekker GitHub Releases ved opstart
- Viser dialog hvis nyere version findes
- Streaming download og installation direkte fra appen
- Husker afvist version så dialogen ikke gentages
- Browser-fallback hvis installation fejler

## Roller
- **Gæst**: kan se kort og jagtområder
- **Medlem**: kan tilmelde events, reservere poster, chatte, modtage notifikationer
- **Admin**: alt ovenstående + opret events/områder, administrer brugere, send broadcast, se admin log

## Tech stack
- Flutter 3.41.5 med Riverpod 3 (AsyncNotifier)
- Supabase (Auth, PostgreSQL, Realtime, Storage, Edge Functions)
- Firebase (Push notifikationer, Hosting)
- GoRouter med auth redirect
- flutter_map + OpenStreetMap
- Geolocator + Android Foreground Service
- image_picker + video_player
- Package: dk.jagtapp.jagt_app

## Platforme
- **Android**: APK distribution via GitHub Releases med auto-opdatering
- **Web**: Firebase Hosting (uden GPS, geofencing og push)

## CI/CD
GitHub Actions bygger og deployer automatisk ved push til `main`:
1. Bygger Android APK med release-signering
2. Bygger Flutter web
3. Deployer web til Firebase Hosting
4. Opretter GitHub Release med APK

## Lokal udvikling
```bash
# Byg APK (kræver key.properties + keystore for release-signering)
JAVA_HOME=/path/to/jdk17 flutter build apk --release

# Byg og deploy web
flutter build web --release
firebase deploy --only hosting
```

## Versionshistorik

### v2.5.9 (2026-05-25)
- Vildtudbytte: registrer nedlagt vildt per event med artsliste, antal og samlet skud
- Komplet liste over danske jagtbare og regulerbare vildtarter (kategoriseret)
- Fix: Widget-reorder på forsiden virker nu korrekt (rewritet med direkte index-manipulation)

### v2.5.8 (2026-05-25)
- Fix: Widget-reorder på forsiden virker nu korrekt (alle sort_order opdateres)

### v2.5.7 (2026-05-25)
- Fix: Push notifications virker nu for alle chatkanaler (generelle, private, gruppe)
- Edge Function opdateret: generelle kanaler sender push til alle brugere, ikke kun channel_members
- Array.isArray guard tilføjet for robusthed i Edge Function

### v2.5.6 (2026-05-24)
- Lysere hero-billede i light mode med blødere gradient (billedet lyser mere igennem)
- Dark mode beholder den mørke gradient uændret

### v2.5.5 (2026-05-23)
- Forbedret dark mode: bedre kontrast, lysere tekst, skarpere card-borders
- Komplet dark theme med alle widget-styles (buttons, chips, dialogs, dividers, inputs)
- Fjernet hero-tekst fra forsiden — billedet taler for sig selv

### v2.5.4 (2026-05-23)
- Nyt jagt-inspireret farvetema: forest green, sand/cream, guld accenter
- Komplet theme-aware UI — alle elementer tilpasser sig automatisk til light/dark mode
- Dashboard widgets, chat, kalender, profil, admin og kort bruger nu konsistent farveskema

### v2.5.3 (2026-05-23)
- "Tilmeld event først"-knap på postsiden tilmelder direkte og skifter til "Reserver"
- Sol op/ned og temperatur vises på event detaljesiden (live vejrdata)

### v2.5.1 (2026-05-23)
- Generelle chat-kanaler viser kun beskrivelse (ikke sidst sendte besked)
- Private/gruppe-kanaler viser stadig sidste besked

### v2.5.0 (2026-05-23)
- Næste event widget navigerer til event detaljer (ikke kalender)
- Kommende reservationer: limit 5, klik på reservation åbner event
- Chat: admin kan tilføje beskrivelse til generelle kanaler
- Event-statistik widget viser kun antal kommende (fjernet tilmeldte)
- Vejrdata (sol op/ned, temperatur) på event-oprettelsesside baseret på jagtområdets placering

### v2.4.8 (2026-05-23)
- Realtime events: alle brugere ser oprettede/slettede/redigerede events live uden genstart
- Fix: komplet RLS-oprydning med SECURITY DEFINER `get_my_role()` funktion
- Fix: INSERT/UPDATE/DELETE policies på hunt_events (ikke-admin kunne ikke oprette events)
- Fix: RLS policies for event_signups og event_comments
- Fix: profiles SELECT policy (brugere kunne ikke læse profiler via subqueries)

### v2.4.6 (2026-05-23)
- Fix: events synlige for alle roller (RLS-policy brugte forkert rollenavn 'member' i stedet for 'jaeger_medlem')
- Fix: chat kanal-oprettelse for ikke-admin roller (SECURITY DEFINER funktion)
- Fix: events vises mens profil loader (default til vis-alle)
- Kamera og medie-permissions tilføjet (CAMERA, READ_MEDIA_IMAGES, READ_MEDIA_VIDEO)
- Klikbare dashboard widgets (navigerer til kalender, kort, chat)
- Sort/hvid tema på alle dashboard widgets
- Fjernet gamle info-kort (erstattet af nye widgets)

### v2.4.0 (2026-05-22)
- Dashboard widgets: næste event, event-statistik, vejrudsigt, mine reservationer, seneste chat, nedtælling
- Admin kan tilføje/fjerne/aktivere/deaktivere dashboard-widgets
- Rollebaseret synlighed på alle dashboard-widgets
- Vejrudsigt med temperatur, vind, fugtighed, solopgang/solnedgang (Open-Meteo API)

### v2.3.9 (2026-05-22)
- Træk-og-slip rækkefølge for generelle chatkanaler i admin panel

### v2.3.8 (2026-05-22)
- Fix admin slet-besked i chat (rolle-tjek brugte streng i stedet for enum)

### v2.3.7 (2026-05-22)
- Fix release-signering (keystore-sti rettet i Gradle)
- Streaming APK-download (undgår memory-problemer med store filer)
- Husk afvist opdateringsversion (viser ikke dialog igen for samme version)
- Browser-fallback ved fejlet APK-installation
- Versionsnummer synligt på profilsiden

### v2.3.0 (2026-05-21)
- Admin kan slette individuelle chat-beskeder (long-press)
- Video-optagelse direkte fra chat (kamera)
- Check-in/check-ud toggle på events
- Chat RLS fix med SECURITY DEFINER funktion

### v2.0.0 (2026-05-20)
- Web version (Firebase Hosting)
- Medie-support i chat (billeder og video)
- Tårn-billeder og beskrivelser
- Tårninfo på kort (uden event-data)
- Push notifikationer (FCM)
- Forbedret chat realtime med polling fallback

### v1.9.x (2026-05-13-19)
- Dynamisk forside med blokke
- Rollebaseret kanalvisning
- Polygon-baserede jagtområder
- Push notifikationer opsætning
- Admin log udvidelser

### v1.5.0 (2026-05-12)
- Baggrunds-geofencing via foreground service
- Event tilmelding/afmelding med realtime
- Smart geofencing (kun tilmeldte events)
- Admin log med farvekodede typer
- Broadcast med event-tilknytning

### v1.0.0 (2026-05-10)
- Kort med jagtområder og tårn-markører
- Kalender med events
- Chat med kanaler
- Brugerroller og profil
- Admin panel
