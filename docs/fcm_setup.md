# FCM Push Notification Setup

## 1. Firebase Console (allerede gjort)

1. Gaa til https://console.firebase.google.com
2. Projekt: "Risinge Jagt" (risinge-jagt)
3. Android app: `dk.jagtapp.jagt_app`
4. `google-services.json` ligger i `android/app/`

## 2. Firebase Service Account Key

1. Firebase Console → Project Settings → Service Accounts
2. Klik "Generate new private key" → download JSON-filen
3. Gem hele JSON-indholdet som Supabase secret (se trin 4)

## 3. Supabase SQL

Koer disse SQL-filer i Supabase SQL Editor (i raekkefoelge):
1. `supabase/fcm_tokens.sql` — opretter fcm_tokens tabel (allerede koert)
2. `supabase/push_triggers.sql` — opretter database triggers for automatisk push

## 4. Deploy Edge Function

### Installer Supabase CLI (hvis ikke installeret):
```bash
npm install -g supabase
```

### Login og link projekt:
```bash
cd jagt_app
supabase login
supabase link --project-ref zbmpptfddowmchuyrrea
```

### Gem Firebase service account som secret:
```bash
# Kopier HELE indholdet af din Firebase service account JSON-fil
# og gem det som en secret (paa een linje, escaped):
supabase secrets set FIREBASE_SERVICE_ACCOUNT='{ hele json indholdet her }'
```

### Deploy funktionen:
```bash
supabase functions deploy send-push --no-verify-jwt
```

`--no-verify-jwt` tillader at database triggers kan kalde funktionen uden auth token.

## 5. Hvad der sender push automatisk

### Chat-beskeder (database trigger)
- Naar en bruger sender en besked i en kanal
- Push sendes til alle andre medlemmer i kanalen
- Titel: kanal-navn, Besked: "Afsender: besked-tekst"

### Broadcasts (database trigger)
- Naar admin opretter en broadcast-notifikation
- Push sendes til alle brugere (undtagen afsender)
- Titel og besked fra notifikationen

### Event-notifikationer (database trigger)
- Naar der oprettes en event-notifikation
- Push sendes til alle brugere

## 6. Hvad Flutter-koden goer

- `bootstrap.dart`: Initialiserer Firebase + FCM ved app-start
- `push_notification_service.dart`:
  - Beder om notifikations-permission
  - Gemmer FCM token i Supabase `fcm_tokens` tabel
  - Opdaterer token ved refresh
  - Viser lokal notifikation naar push modtages i forgrunden
  - Fjerner token ved logout
- `firebaseMessagingBackgroundHandler`: Haandterer push i baggrunden

## 7. Flow

1. Bruger aabner app → FCM token gemmes i `fcm_tokens`
2. Bruger sender chat-besked → trigger kalder Edge Function → FCM push til andre
3. Admin sender broadcast → trigger kalder Edge Function → FCM push til alle
4. Modtager faar push paa telefonen — ogsaa naar appen er lukket
5. Ved logout fjernes FCM token

## 8. Test

1. Koer `push_triggers.sql` i Supabase SQL Editor
2. Deploy Edge Function (se trin 4)
3. Log ind paa 2 telefoner med forskellige brugere
4. Send en chat-besked → den anden telefon skal faa push
5. Send broadcast fra admin → alle faar push

## 9. Fejlsoegning

- Tjek Edge Function logs: `supabase functions logs send-push`
- Tjek at FCM tokens findes i `fcm_tokens` tabel
- Tjek at triggers er oprettet: `SELECT * FROM pg_trigger WHERE tgname LIKE 'on_new_%';`
- TC26 har gammel Google Play Services — push virker muligvis ikke paa den
