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
  Functions (Deno)
- **Firebase Cloud Messaging** — push notifications
- **RevenueCat** — subscriptions (SDK wired, no paywall UI yet)
- **AdMob** — ads (SDK wired, no ad units placed yet)
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
      auth/                 # AuthService + Riverpod providers
      notifications/        # FCM device registration
      router/                # go_router config, route path constants
      theme/
      ads/                  # AdMob init
      billing/               # RevenueCat init
    features/
      groups/                 # groups, membership, invite codes
      live_quiz/               # join window, live Q&A, realtime leaderboard
      reading_plans/           # plans, daily readings, streaks
      devotions/                # feed + detail + likes
      studies/                  # weekly stories
      study_manuals/            # manuals with chapters + progress
      treasure_hunts/           # hunts, tasks, grading, rewards
    shared/widgets/            # HomeShell (bottom nav)
    main.dart
```

Each feature folder follows the same shape: `models/` (plain Dart
classes with `fromJson`), `services/` (a class wrapping the relevant
Supabase queries/RPCs/realtime channels), `screens/`, `providers/`
(Riverpod `FutureProvider`/`StreamProvider` wrappers around the
service), and `widgets/` for anything reused across screens in that
feature.

## 1. Set up Supabase

1. Create a project at [supabase.com](https://supabase.com).
2. In the SQL Editor, run **`supabase/schema.sql`** — this creates every
   table, RLS policy, helper function/RPC, and the 3 `pg_cron` jobs. It
   assumes a fresh database; don't run it twice against the same
   project (it isn't idempotent — use Supabase migrations for changes
   after this baseline).
3. Run **`supabase/seed/verse_pool.sql`** to populate `verse_pool`
   (empty by default otherwise). It's safe to re-run.
4. Deploy the edge functions (requires the [Supabase
   CLI](https://supabase.com/docs/guides/cli)):
   ```bash
   supabase link --project-ref <your-project-ref>
   supabase functions deploy join_quiz
   supabase functions deploy submit_hunt_answer
   supabase functions deploy send_push
   ```
5. `send_push` needs a Firebase service account with the "Firebase
   Cloud Messaging API" role:
   ```bash
   supabase secrets set FCM_SERVICE_ACCOUNT_JSON='<paste the full JSON as one line>'
   ```
6. (Optional, for real content) create at least one `is_admin = true`
   profile so you can write `devotions`, `reading_plans`,
   `weekly_stories`, and `study_manuals` — these tables are
   read-for-everyone / write-for-admins only:
   ```sql
   update public.profiles set is_admin = true where id = '<your user id>';
   ```

### Storage buckets

Not created by `schema.sql` (Storage buckets aren't part of a SQL
migration). If you want images for devotions/manuals/groups, create
buckets from the dashboard (Storage → New bucket) and point the
relevant `*_image_url` / `*_url` columns at the public URLs.

## 2. Set up Firebase (push notifications)

1. Create a Firebase project, add Android/iOS apps.
2. Install the [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup)
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
3. Download a service account JSON (Project settings → Service
   accounts → Generate new private key) and use it for
   `FCM_SERVICE_ACCOUNT_JSON` above.

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
ones) and empty RevenueCat keys (billing init silently no-ops without
them).

## What's built

- **Schema**: every table described in the brief, RLS on all of them,
  invite-code group joins, server-graded quiz answers
  (`submit_quiz_answer` RPC — clients never see `correct_option`), and
  3 cron jobs (`advance-quiz-status` every minute, `reset-stale-streaks`
  daily, `close-expired-hunts` every 5 minutes).
- **Auth**: email/password sign up & sign in.
- **Groups**: create, join by invite code, member list, per-group quiz
  and hunt lists.
- **Live quiz**: join-window countdown → live participant list → timed
  question flow (question/timing derived purely from
  `starts_at` + each question's `time_limit_seconds`, matching the
  server's cron logic) → realtime leaderboard via Supabase Realtime on
  `quiz_participants`.
- **Reading plans**: enroll, mark days read, streak banner
  (current + longest), streak-break cron job.
- **Devotions**: feed, detail view, likes.
- **Study manuals**: chapter-by-chapter viewer with per-chapter
  progress.
- **Treasure hunts + rewards**: task list with hints, answer submission
  graded server-side (`submit_hunt_answer` edge function —
  `hunt_tasks.answer` is not selectable by clients at the database
  level, closing the gap called out in the original brief), points
  balance, rewards screen.

## Known gaps (carried over / still open)

- **Quiz & hunt content authoring**: there's a minimal "schedule a
  quiz" form (title/time/join window) for testing the participant flow,
  but no UI to author quiz questions or hunt tasks — add rows to
  `quiz_questions` / `hunt_tasks` directly for now.
- **Firebase**: `flutterfire configure` hasn't been run against a real
  Firebase project (no such project exists yet), so
  `lib/firebase_options.dart` and the native config files aren't
  present. The app boots fine without them; push just won't register.
- **AdMob/RevenueCat**: SDKs initialize (with Google's test AdMob app
  IDs by default), but no ad units or paywall/entitlement UI are placed
  anywhere yet.
- **No automated tests** beyond a placeholder smoke test — nothing here
  has been exercised against a real Supabase project (this environment
  has no Supabase credentials), so run through the flows manually after
  filling in `.env`.
- **Animations**: Lottie/Rive are installed but unused.

## Useful commands

```bash
flutter analyze     # static analysis (clean as of this commit)
flutter test        # unit/widget tests
flutter pub outdated # see which deps have newer versions than the pinned constraints
```
