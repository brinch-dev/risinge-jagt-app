# Risinge Jagtvæsen - Dokumentation

**Version:** 2.0  
**Platforme:** Android (Flutter) + Web (Flutter Web)  
**Backend:** Supabase (PostgreSQL, Auth, Realtime, Edge Functions)  
**Web URL:** https://risinge-jagt.web.app  
**Firebase projekt:** risinge-jagt

---

## Oversigt

Risinge Jagtvæsen er en jagtkoordineringsapp til Risinge Herregaard. Appen giver jaegere, gaester og administratorer et faelles vaerktoj til at koordinere jagter, kommunikere, og holde styr paa jagtomraader og poster.

Appen findes som **Android APK** og som **web-version** hostet paa Firebase Hosting. Web-versionen har samme funktionalitet, bortset fra GPS/geofencing og push notifications.

---

## Platform-forskelle

| Funktion | Android | Web |
|----------|---------|-----|
| Login/profil | X | X |
| Forside (hero, info-kort, blokke) | X | X |
| Kort med taarne og omraader | X | X |
| Taarn-reservationer | X | X |
| Kalender og events | X | X |
| Chat (realtime) | X | X |
| Admin panel | X | X |
| Rolle-administration | X | X |
| Forside-redigering | X | X |
| GPS/live position | X | - |
| Geofencing/graense-alarm | X | - |
| Auto check-in (proximity) | X | - |
| Push notifications (FCM) | X | - |
| Lokale notifikationer | X | - |

---

## Rollesystem

Roller er dynamisk styret fra databasen via `roles`-tabellen. Admin kan oprette, redigere og slette roller via admin panelet.

### Standard-roller

| Rolle | DB-vaerdi | Beskrivelse |
|-------|-----------|-------------|
| **Admin** | `admin` | Fuld adgang til alt |
| **Jaeger Medlem** | `jaeger_medlem` | Fast jaeger med fulde jagtrettigheder |
| **Ejer** | `ejer` | Ejer af omraadet |
| **Forvalter** | `forvalter` | Forvalter af omraadet |
| **B&B Direktoer** | `bb_direktoer` | Bed & Breakfast direktoer |
| **Jagt Gaest** | `jagt_gaest` | Gaest inviteret til jagt |
| **Gaest** | `gaest` | Generel gaest (mindste rettigheder) |

### Rettigheder per rolle

| Funktion | Admin | Jaeger M. | Ejer | Forvalter | B&B Dir. | Jagt G. | Gaest |
|----------|-------|-----------|------|-----------|----------|---------|-------|
| Se alle events | X | X | X | X | X | | |
| Oprette events | X | X | X | X | X | | |
| Redigere alle events | X | X | | | X | | |
| Redigere egne events | | | X | X | | | |
| Se taarne/poster | X | X | X | X | X | X | |
| Reservere taarne | X | X | | | | X | |
| Live overvagning | X | | | X | | | |
| Admin panel | X | | | | | | |
| Tilmelde sig events | X | X | X | X | X | X | |

### Rolle-administration (Admin)

- Opret nye roller med label og sortering
- Rediger eksisterende roller
- Slet roller (system-roller som admin/gaest kan ikke slettes)
- Styr chat-kanal adgang per rolle via checkboxes
- Naar en rolle slettes, saettes alle brugere med den rolle til 'gaest'

---

## Funktioner

### 1. Forside (Hjem)

Moderne forside med SliverAppBar hero-billede af Risinge Herregaard.

**Bloktyper (admin-redigerbare):**
- **Hero** - Stort billede med titel og gradient overlay
- **Welcome** - Velkomst-tekst med brugerens navn
- **Info Cards** - 4 automatiske kort: naeste event, antal events, chat-kanaler, jagtkort
- **Text** - Fri tekst-blok med titel og indhold
- **Announcement** - Fremhaevet meddelelse med ikon
- **Image** - Billede-blok med valgfri billedtekst

**Admin-funktioner:**
- Rediger forsideblokke via admin-panelet
- Aktiver/deaktiver blokke
- Aendr sortering og synlighed per rolle
- Opret nye blokke af alle typer

### 2. Kort (Jagtkort)

Hovedkortet viser jagtomraadet med folgende lag:

- **Jagtomraade polygon** (gron) - omraadets graenser
- **Event-graenser** (rod) - specifikke jagtgraenser for aktive events
- **Jagttaarne** - custom jagttaarn-ikon med farvekodning:
  - Gron = Ledig
  - Blaa = Reserveret af dig
  - Rod = Reserveret af anden
- **Live positioner** - andre jaegeres positioner (kun Android, for admin/forvalter)
- **Din position** - blaa prik (kun Android)

**Kortknapper (hoejre side):**
- **+** Zoom ind
- **-** Zoom ud
- **Lag-ikon** Skift mellem Standard, Satellit og Topografisk kort
- **Min position** Center kortet paa din GPS-position (kun Android)

**Taarn-reservationer paa hovedkort:**
- Vises KUN naar et event er aktivt (i dag + inden for start/slut-tid)
- Event-detalje-kort viser altid reservationer

**Geofencing (kun Android):**
- Automatisk advarsler naar du naermer dig jagtomraadets graense
- Dual geofencing: event-deltagere bruger event-polygon, andre bruger hoved-omraade
- Push-notifikation ved graenseoverskridelse
- Admin logges naar brugere er taet paa graensen

**Taarn-administration (Admin):**
- Tryk paa kort for at placere ny post
- Angiv navn, beskrivelse og type (jagttaarn, skydestige, skudlinje)
- Rediger eksisterende poster (navn, beskrivelse, type)
- Slet poster med bekraeftelse

### 3. Check-in/Check-out (kun Android)

- **Tidsvindue:** 1 time foer event start til 1 time efter event slut
- **Check-in:** Automatisk popup naar du er inden for jagtomraadet
- **Check-out:** Orange knap efter check-in, registrerer `checked_out_at`
- Begge handlinger logges i admin log

### 4. Kalender

- Maanedsvisning med farvede datoer for events
- Tryk paa dato for at se events den dag
- Jagt Gaest og Gaest kan kun se events de er tilmeldt
- Opret event (for berettigede roller)

**Event detaljer viser:**
- Titel, beskrivelse, dato, start/sluttid
- Jagtomraade (automatisk tilknyttet)
- Tilmeldte deltagere
- Kommentarfelt
- Rediger/slet (for berettigede roller)

### 5. Chat

Kanaler styres dynamisk med rolle-baseret adgang.

**Standard chatkanaler:**
1. **Admin Chat** - Admin, Ejer, Forvalter
2. **Jaegermedlems Chat** - Admin, Jaeger Medlem
3. **Jaeger Gaest Chat** - Admin, B&B Direktoer, Jagt Gaest
4. **B&B Chat** - B&B Direktoer, Gaest
5. **Generel Chat** - Admin, Jaeger Medlem, Ejer, Forvalter, B&B Direktoer

Kanaler er kun synlige for brugere med den rette rolle. Adgang styres via `required_roles` paa chat_channels.

**Admin kan:**
- Oprette nye kanaler
- Redigere kanal-navn og rolle-adgang
- Slette kanaler

**Private/gruppe chats:**
- Opret nye samtaler med valgte medlemmer
- Swipe til venstre for at slette
- Realtids-besked via Supabase Realtime

### 6. Profil

- Vis brugerinfo (navn, email, rolle)
- Rolleikon og -farve
- Link til Admin Panel (kun admin)
- Log ud

### 7. Admin Panel (kun admin)

| Sektion | Ikon | Beskrivelse |
|---------|------|-------------|
| Jagtomraader | Kort (gron) | Opret og administrer jagtomraader |
| Brugere | People (blaa) | Administrer brugerroller |
| Forside | Dashboard (indigo) | Rediger forsideblokke og synlighed |
| Roller | Shield (lilla) | Opret, rediger, slet roller + chat adgang |
| Chat-kanaler | Chat (teal) | Opret, rediger, slet kanaler + rolle-adgang |
| Broadcast | Megafon (orange) | Send besked til alle medlemmer |
| Live overvagning | Satellit (teal) | Se medlemmers positioner i realtid |
| Admin Log | Liste (deep orange) | Se al aktivitet i appen |

### 8. Notifikationer (kun Android push)

- Klokke-ikon i app bar viser antal ulaeste
- Push-notifikationer for nye events
- Graense-advarsler via lokale notifikationer
- Event-paamindelser (dagen foer kl. 10)
- Marker alle som laest

---

## Teknisk Arkitektur

### Frontend
- **Flutter** 3.41.5
- **Riverpod** 3.x (AsyncNotifier pattern)
- **flutter_map** med OpenStreetMap, ArcGIS Satellit, OpenTopoMap
- **GoRouter** med push notification navigation

### Backend (Supabase)
- **Auth** - Email/password authentication
- **PostgreSQL** - Alle data med Row Level Security (RLS)
- **Realtime** - Chat beskeder og notifikationer
- **Edge Functions** - FCM push notifications

### Web-specifikke tilpasninger
- `kIsWeb` guards paa Firebase, push notifications, GPS og geofencing
- Supabase credentials via `String.fromEnvironment` (compile-time) paa web
- `.env` fil bruges kun paa Android

### Database tabeller
- `profiles` - Brugerprofiler med rolle
- `roles` - Dynamiske roller (label, sort_order, is_system)
- `hunt_areas` - Jagtomraader
- `area_boundaries` - Polygon-punkter for omraader
- `hunt_events` - Jagt-events
- `event_boundaries` - Polygon-punkter for events
- `event_signups` - Event-tilmeldinger
- `event_checkins` - Check-in/check-out registreringer
- `event_comments` - Event-kommentarer
- `towers` - Poster/taarne (med type: jagttaarn, skydestige, skudlinje)
- `tower_reservations` - Post-reservationer
- `chat_channels` - Chatkanaler (med required_roles array)
- `channel_members` - Kanal-medlemskaber
- `chat_messages` - Chatbeskeder
- `homepage_blocks` - Forsideblokke (hero, welcome, text, announcement, info_cards, image)
- `app_notifications` - Notifikationer
- `notification_reads` - Laest-status
- `admin_log` - Admin aktivitetslog
- `user_locations` - Live GPS-positioner
- `fcm_tokens` - Push notification tokens

---

## Build & Deploy

### Android APK
```bash
cd jagt_app
JAVA_HOME=/home/ex/jdk17 flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Web (Firebase Hosting)
```bash
cd jagt_app
flutter build web --release
firebase deploy --only hosting
```

Web-versionen deployes til: **https://risinge-jagt.web.app**

### Samlet build og deploy (begge platforme)
```bash
cd jagt_app
JAVA_HOME=/home/ex/jdk17 flutter build apk --release && flutter build web --release && firebase deploy --only hosting
```

### Supabase setup
1. Koer `supabase/schema.sql` for grundlaeggende tabeller
2. Koer migrations i raekkefoelge
3. Koer `supabase/roles_table.sql` for rolle-tabellen
4. Koer `supabase/homepage_blocks.sql` for forside-blokke
5. Deploy Edge Function for FCM push

---

## Konfiguration

### .env fil (kun Android)
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

### Web credentials
Hardcoded i `bootstrap.dart` via `String.fromEnvironment` med default values.

### Firebase
- `google-services.json` i `android/app/`
- FCM konfigureret via Supabase Edge Function
- Firebase Hosting konfigureret i `firebase.json`

### Firebase Hosting config (`firebase.json`)
```json
{
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [
      { "source": "**", "destination": "/index.html" }
    ]
  }
}
```
