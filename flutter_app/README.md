# HIDEX Bible App

Flutter + Supabase + Firebase church Bible app: groups, live quizzes,
reading plans with streaks, devotions, weekly stories/studies, study
manuals, and treasure hunts with rewards.

This app was built from scratch in this repo — there was no prior
scaffold. Everything below reflects what actually exists today.

## Stack

- **Flutter** (Dart 3.13+) — `flutter_riverpod` for state, `go_router`
  for navigation
- **Supabase** — Postgres + Row Level Security, Auth, Realtime, Edge
  Functions (Deno), Storage (avatars)
- **Google Sign-In only** — no email/password, no RevenueCat/subscriptions
- **Firebase Cloud Messaging** — push notifications
- **AdMob** — the only monetization (ads); no subscriptions
- **bible-api.com** — free, no-key scripture text API for reading plans
  and devotions
- **local_auth** — optional on-device biometric app lock
- **Lottie / Rive** — packages installed, no animations added yet

## Repo layout

```
supabase/
  schema.sql               # full schema, RLS policies, 3 cron jobs
  edge_functions/
    join_quiz.ts            # server-enforced quiz join window
    submit_hunt_answer.ts   # server-side treasure hunt grading
    send_push.ts            # FCM send-side (HTTP v1 API)
    _shared/cors.ts
  seed/
    verse_pool.sql          # curated KJV verses

flutter_app/
  lib/
    core/
      supabase/             # Supabase client bootstrap
      auth/                 # AuthService (Google-only) + GoogleAuthInit + providers
      security/              # optional biometric app-lock
      bible/                  # bible-api.com client + provider
      donation/                # local scheduling for the donation prompt
      notifications/        # FCM device registration
      router/                # go_router config, route path constants
      theme/
      ads/                  # AdMob init
    features/
      groups/                 # groups, membership, invite codes
      live_quiz/               # join window, live Q&A, realtime leaderboard
      reading_plans/           # plans, daily readings, streaks, live Bible text
      devotions/                # feed + detail + likes, live Bible text
      studies/                  # weekly stories
      study_manuals/            # manuals with chapters + progress
      treasure_hunts/           # hunts, tasks, grading, rewards
      profile/                  # Google-sourced name/avatar, edit, biometric toggle
      donation/                 # support/donate screen + periodic prompt dialog
    shared/widgets/            # HomeShell (bottom nav), BiometricLockGate
    main.dart
```

Each feature folder follows the same shape: `models/` (plain Dart
classes with `fromJson`), `services/` (a class wrapping the relevant
Supabase queries/RPCs/realtime channels), `screens/`, `providers/`
(Riverpod `FutureProvider`/`StreamProvider` wrappers around the
service), and `widgets/` for anything reused across screens in that
feature.

## 1. Set up Supabase

**This repo's dev environment has no route to your Supabase project's
domain (`*.supabase.co`) or its Postgres port — outbound network here
is locked to an allowlist that doesn't include it — so the schema has
never actually been executed against a live database. You need to run
these two steps yourself.**

1. Create a project at [supabase.com](https://supabase.com) (or use an
   existing one).
2. Open the **SQL Editor** in the dashboard, paste in the full contents
   of **`supabase/schema.sql`**, and run it. This creates every table,
   RLS policy, helper function/RPC, and the 3 `pg_cron` jobs. It assumes
   a fresh database; don't run it twice against the same project (it
   isn't idempotent — use Supabase migrations for changes after this
   baseline). If it errors partway through, paste the error back and it
   can be fixed and re-verified by reading through the file — just not
   executed from here.
3. Same way, run **`supabase/seed/verse_pool.sql`** to populate
   `verse_pool` (empty by default otherwise). It's safe to re-run.
4. Same way, run **`supabase/storage_policies.sql`** — creates the
   public `avatars` bucket profile photos are uploaded to, and locks it
   down so each user can only write inside their own
   `avatars/<user_id>/` folder. Safe to re-run.
5. Deploy the edge functions (requires the [Supabase
   CLI](https://supabase.com/docs/guides/cli)):
   ```bash
   supabase link --project-ref <your-project-ref>
   supabase functions deploy join_quiz
   supabase functions deploy submit_hunt_answer
   supabase functions deploy send_push
   ```
6. `send_push` needs a Firebase service account with the "Firebase
   Cloud Messaging API" role:
   ```bash
   supabase secrets set FCM_SERVICE_ACCOUNT_JSON='<paste the full JSON as one line>'
   ```
7. (Optional, for real content) create at least one `is_admin = true`
   profile so you can write `devotions`, `reading_plans`,
   `weekly_stories`, and `study_manuals` — these tables are
   read-for-everyone / write-for-admins only:
   ```sql
   update public.profiles set is_admin = true where id = '<your user id>';
   ```

### Storage buckets

The `avatars` bucket (profile photos) is created by
`storage_policies.sql` above. For everything else — devotion images,
study manual covers, group photos — there's no bucket yet; create one
from the dashboard (Storage → New bucket) and point the relevant
`*_image_url` / `*_url` columns at the public URLs.

## 2. Set up Firebase + Google Sign-In

Sign-in is **Google-only** — there's no email/password form. It works
by getting a Google ID token natively (via `google_sign_in`) and
exchanging it for a Supabase session (`supabase.auth.signInWithIdToken`).
That exchange needs a Google **Web** OAuth Client ID that both sides
agree on, and the easiest way to get one is through Firebase, which
also covers push notifications — so do this in one pass:

1. Create a Firebase project, add Android/iOS apps.
2. In the Firebase console: **Authentication → Sign-in method → Google
   → Enable**. This auto-creates a Web OAuth Client ID (Firebase shows
   it right there, and it's also visible in Google Cloud Console →
   APIs & Services → Credentials, listed as "Web client (auto created
   by Google Service)").
3. Install the [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup)
   and run, from `flutter_app/`:
   ```bash
   flutterfire configure
   ```
   This generates `lib/firebase_options.dart` and drops
   `google-services.json` / `GoogleService-Info.plist` into the native
   projects — none of that is checked into this repo, and
   `main.dart`'s Firebase init is wrapped in a try/catch specifically so
   the rest of the app still runs before you've done this step (push
   registration is just skipped until then).
4. Copy the Web Client ID from step 2 into:
   - `flutter_app/.env` → `GOOGLE_WEB_CLIENT_ID`
   - Supabase Dashboard → **Authentication → Providers → Google** →
     enable it and paste the same Client ID (and the matching Client
     Secret, also in Google Cloud Console credentials) — Supabase
     verifies the ID token's `aud` claim against this, so the two must
     match exactly.
5. iOS only: also copy the iOS Client ID (from `GoogleService-Info.plist`,
   key `CLIENT_ID`) into `GOOGLE_IOS_CLIENT_ID`, and add its reversed
   form (`REVERSED_CLIENT_ID` in the same plist) as a URL scheme in
   `ios/Runner/Info.plist` under `CFBundleURLTypes` — FlutterFire's
   `flutterfire configure` does not do this step for you.
6. Android only: add your debug **and** release SHA-1 fingerprints to
   the Firebase project (Project settings → Your apps → Add
   fingerprint) — Google Sign-In fails silently without this.
7. Download a service account JSON (Project settings → Service
   accounts → Generate new private key) and use it for
   `FCM_SERVICE_ACCOUNT_JSON` above (this is unrelated to sign-in —
   it's what lets `send_push` actually call the FCM API).

None of steps 1–2 and 5–7 can be done from this dev environment — they
require a real Google/Firebase account and, for Android/iOS, a real
signing key. Everything on the code side (the `GoogleAuthInit` bootstrap,
`AuthService.signInWithGoogle`, the `.env` keys it reads) is already
wired up and waiting for those values.

### Profile: name, avatar, session behavior

There is no password anywhere in the app — Google sign-in is the only
credential, and the Supabase session it creates persists (auto-refresh
via `supabase_flutter`), so the app never forces a re-login. On first
sign-in, `handle_new_user()` (in `schema.sql`) seeds `profiles.display_name`
and `profiles.avatar_url` straight from the Google ID token's claims. A
user can change their display name or upload a custom avatar afterwards
from the **Profile** tab (`ProfileService.uploadAvatar` → the `avatars`
storage bucket, RLS-scoped so they can only overwrite their own file).

**Biometric app lock** (Profile → toggle, off by default): purely local,
via `local_auth` — has nothing to do with the Google/Supabase session,
which stays signed in either way. When on, `BiometricLockGate` (wrapping
the whole app in `main.dart`) requires Face ID / fingerprint / device
passcode on each cold start before showing any content.

## 3. Configure the Flutter app

```bash
cd flutter_app
cp .env.example .env
# fill in SUPABASE_URL / SUPABASE_ANON_KEY at minimum
flutter pub get
flutter run
```

`.env` is gitignored — `.env.example` documents every key, including
placeholder AdMob test app IDs (safe to leave as-is until you have real
ones), empty Google sign-in keys (the sign-in button shows an in-app
error instead of crashing until those are filled in), and
`DONATION_URL` (see below).

### Native config already handled

A few things a fresh `flutter create` doesn't set up on its own, fixed
in this repo so the relevant plugins actually work instead of crashing
or silently failing in a release build:

- `android/app/.../AndroidManifest.xml`: added the `INTERNET` permission
  (only present in the debug manifest by default — every network call,
  Supabase included, would silently fail in a release build without
  this) and the AdMob `APPLICATION_ID` meta-data entry (required before
  `MobileAds.initialize()` will succeed at all).
- `android/app/.../MainActivity.kt`: changed to extend
  `FlutterFragmentActivity` instead of `FlutterActivity` — `local_auth`'s
  biometric prompt requires a `FragmentActivity` on Android.
- `ios/Runner/Info.plist`: added `NSFaceIDUsageDescription` (required for
  the biometric lock), `NSPhotoLibraryUsageDescription` (required for
  picking an avatar image), and `GADApplicationIdentifier` (AdMob, same
  requirement as Android).

Both AdMob entries currently hold Google's public **test** App IDs —
safe to ship during development, swap for your real ones before release.

## What's built

- **Schema**: every table described in the brief, RLS on all of them,
  invite-code group joins, server-graded quiz answers
  (`submit_quiz_answer` RPC — clients never see `correct_option`), and
  3 cron jobs (`advance-quiz-status` every minute, `reset-stale-streaks`
  daily, `close-expired-hunts` every 5 minutes).
- **Auth**: Google Sign-In only (`google_sign_in` → ID token →
  `supabase.auth.signInWithIdToken`). No password, ever — persistent
  session, optional biometric app-lock as a local convenience layer.
- **Profile**: Google-sourced name/avatar on first sign-in, editable
  name, custom avatar upload to Supabase Storage, biometric lock toggle,
  sign out.
- **Groups**: create, join by invite code, member list, per-group quiz
  and hunt lists.
- **Live quiz**: join-window countdown → live participant list → timed
  question flow (question/timing derived purely from
  `starts_at` + each question's `time_limit_seconds`, matching the
  server's cron logic) → realtime leaderboard via Supabase Realtime on
  `quiz_participants`.
- **Reading plans**: enroll, mark days read, streak banner
  (current + longest), streak-break cron job, live scripture text from
  bible-api.com when a plan day has no admin-entered text.
- **Devotions**: feed, detail view, likes, same live-scripture fallback
  for the verse callout.
- **Study manuals**: chapter-by-chapter viewer with per-chapter
  progress.
- **Treasure hunts + rewards**: task list with hints, answer submission
  graded server-side (`submit_hunt_answer` edge function —
  `hunt_tasks.answer` is not selectable by clients at the database
  level, closing the gap called out in the original brief), points
  balance, rewards screen.
- **Donation prompt**: an in-app dialog (not a push notification) offers
  roughly twice a week, scheduled purely on-device
  (`DonationPromptService`, `shared_preferences`), linking to a
  **Support this app** screen with a `DONATION_URL` you provide.
- **Monetization**: AdMob only — SDK initializes, no RevenueCat/subscriptions
  anywhere in the codebase.

## Known gaps (carried over / still open)

- **`schema.sql` / `verse_pool.sql` / `storage_policies.sql` have not
  been run against any real project** — this dev environment can't
  reach `*.supabase.co` at all (network policy), so this has only ever
  been verified by careful reading, not execution. Run the three SQL
  files yourself per the setup steps above and report back anything
  that errors.
- **`DONATION_URL` is blank** — the donation prompt and Support screen
  work, but show "coming soon" until you provide where donations
  should actually go (PayPal.me, Stripe Payment Link, Buy Me a Coffee,
  Patreon, etc.).
- **Google Sign-In has no real OAuth client yet** — `GOOGLE_WEB_CLIENT_ID`
  / `GOOGLE_IOS_CLIENT_ID` are blank in `.env` until you complete the
  Firebase + Google Cloud steps above. Until then, tapping "Continue
  with Google" shows a clear in-app error instead of crashing.
- **Quiz & hunt content authoring**: there's a minimal "schedule a
  quiz" form (title/time/join window) for testing the participant flow,
  but no UI to author quiz questions or hunt tasks — add rows to
  `quiz_questions` / `hunt_tasks` directly for now.
- **Firebase**: `flutterfire configure` hasn't been run against a real
  Firebase project (no such project exists yet), so
  `lib/firebase_options.dart` and the native config files aren't
  present. The app boots fine without them; push just won't register.
- **AdMob**: SDK initializes (with Google's test App IDs by default),
  but no ad units are placed on any screen yet.
- **No automated tests** beyond a placeholder smoke test, and nothing
  here has run against a real device/emulator or a live Supabase
  project — this dev environment has neither. `flutter analyze` and
  `flutter test` are clean, but that only proves the code compiles, not
  that the flows work end-to-end. Run through them manually once
  Supabase + Firebase are set up.
- **Bible API**: bible-api.com was picked because it's free, keyless,
  and defaults to KJV (matching `verse_pool`'s translation) — swap
  `BibleApiService` for a different provider if you'd rather use one.
  Not reachable from this dev environment either, so the integration is
  unverified beyond `flutter analyze`.
- **Animations**: Lottie/Rive are installed but unused.

## Useful commands

```bash
flutter analyze     # static analysis (clean as of this commit)
flutter test        # unit/widget tests
flutter pub outdated # see which deps have newer versions than the pinned constraints
```
