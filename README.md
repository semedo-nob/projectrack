# ProjectRack

A Flutter app for **construction, agriculture, and field / SMB project work**: track projects, materials, inventory, tasks, activity logs, schedule milestones, expenses, receipts, and reports—with local-first SQLite storage, optional Google Drive backup, and on-device reminders.

## Maintainer

**Nelson Apidi** — [nelsonapidi75@gmail.com](mailto:nelsonapidi75@gmail.com)

For questions, contributions, or commercial use, reach out at the address above.

## Features

- **Projects** — Create and manage projects with budget, progress, status, tags, imagery, and domains such as **Construction** and **Agriculture**.
- **Tasks** — Per-project task lists with status (`pending` / `in_progress` / `done` / `blocked`), priority, due dates, assignees, filters (overdue / due soon / high priority), and quick status actions. From Profile, **Tasks** asks which project to open.
- **Activity logs** — Record non-financial site work (labour hours, deliveries, inspections, field work) separately from spend.
- **Schedule** — Project milestones with due dates and status; overdue and approaching-deadline alerts tied to milestones and project end dates.
- **Expenses & materials** — Log spending with quantities and flexible **units** (including acre / hectare / crate for agriculture); daily material entry with custom materials, templates, and smart unit suggestions.
- **Inventory** — Track on-hand materials per project, log usage, low-stock alerts; purchases from daily material entries add stock automatically.
- **Receipts** — Capture and attach receipts with on-device OCR (ML Kit); flexible validation scoring; manual override / pending review; **verify** or **reject** from receipt detail; gallery and filters.
- **Dashboard** — Reactive at-a-glance stats (projects, spend, open tasks, spending trends) driven by Drift table watches—no polling timer.
- **Reports & insights** — Charts, period filters, budget and duplicate highlights, missing / pending receipts, overdue tasks.
- **Notifications** — In-app project alerts plus OS local reminders (budget, schedule, receipts, inactivity) and a daily check-in; Android requires core library desugaring (configured in `android/app/build.gradle.kts`).
- **Data** — **Drift** (SQLite) with schema migrations (current schema version **6**: includes `ActivityLogs` and `ProjectMilestones`).
- **Backup & export** — Local JSON backup/restore; Excel / CSV / PDF exports; optional **Google Drive** app-data sync (see Settings).
- **Security** — Local accounts with **bcrypt** password hashing (legacy SHA-256 upgraded on login), biometric app lock (suppressed during camera / biometric prompts so receipt capture is not interrupted), secure storage for session data.
- **Settings** — Currency, units and smart suggestions, notifications, theme, backup/restore, and account options.

## App identity

| Platform | Identifier |
|----------|------------|
| Android `applicationId` / namespace | `com.projectrack.app` |
| iOS / macOS bundle ID | `com.projectrack.app` |
| Linux application ID | `com.projectrack.app` |

> Uninstall any older build that used `com.example.projectrack1` before installing—Android treats them as different apps.

Google Sign-In OAuth clients must use these IDs — see [docs/GOOGLE_OAUTH_SETUP.md](docs/GOOGLE_OAUTH_SETUP.md).

## Tech stack

| Layer | Choice |
|-------|--------|
| UI | Flutter (Dart SDK `^3.10.8`) |
| State | Provider |
| Navigation | go_router |
| Database | Drift + SQLite |
| Auth | Local users + bcrypt; flutter_secure_storage; local_auth |
| Charts | fl_chart |
| OCR | google_mlkit_text_recognition |
| Notifications | flutter_local_notifications + timezone |
| Cloud backup | google_sign_in + Google Drive `appDataFolder` |

Dart package name in code remains `projectrack1` (imports / `pubspec.yaml`); store and OAuth identity use `com.projectrack.app`.

## Requirements

- Flutter SDK matching `pubspec.yaml` (`sdk: ^3.10.8`)
- Android Studio / Xcode (or compatible tooling) for mobile targets
- Android release builds: core library desugaring enabled (already set for local notifications)

## Getting started

```bash
flutter pub get
flutter run
```

Release APK:

```bash
flutter build apk --release
```

After Drift schema changes:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Useful checks:

```bash
flutter test
dart analyze
```

## Project layout

| Path | Role |
|------|------|
| `lib/main.dart` | App bootstrap, providers, lifecycle biometric lock, notification init |
| `lib/database/` | Drift schema, migrations, generated `database.g.dart` |
| `lib/providers/` | Auth, Drift DB, theme, currency, dashboard snapshot types |
| `lib/service/` | Auth (bcrypt), inventory, backup, Google sync, export, units, receipt validation, notifications, biometrics |
| `lib/routes/` | go_router routes and auth redirects |
| `lib/ui/projects/` | Projects, overview, daily material entry, activities, schedule, logs |
| `lib/ui/tasks/` | Task list, form, detail |
| `lib/ui/inventory/` | Material inventory and usage |
| `lib/ui/receipts/` | OCR upload, gallery, detail (verify / reject) |
| `lib/ui/screens/` | Dashboard, expenses, reports, settings, profile |
| `lib/ui/auth/` | Login, register, biometric unlock |
| `lib/constants/models/` | Domain models (project, expense, task, inventory, activity, …) |
| `lib/themes/` | Light/dark theme and brand colors |
| `test/` | Unit tests (auth, tasks, inventory, dashboard, colors) |
| `docs/` | Google OAuth setup |

## Core flows

### Material purchase → inventory

1. Open a project → **Add Entry** (daily material entry).
2. Save materials with quantity and unit (custom names and ag units supported).
3. Each successful expense also **adds stock** (matched by material name).
4. Open **Inventory** to set reorder levels, log usage, or view history.

### Tasks

1. Project overview → **Tasks**, or Profile → **Tasks** (pick a project when you have more than one).
2. Create tasks, filter by status / overdue / due soon, update status from the list or detail screen.

### Activities & schedule

1. Project overview → **Activities** to log site or field work (hours, location, type).
2. Project overview → **Schedule** to add milestones and track completion against due dates.
3. Alerts surface overdue tasks, behind-schedule projects, and milestones needing attention.

### Receipts

1. Capture or pick a receipt image; OCR extracts amount / date / merchant when possible.
2. Weak scans can be saved as **pending review**; open receipt detail to **Verify** or **Reject**.
3. Expenses and reports highlight missing or unverified receipts.

### Dashboard

Stats and spending trends refresh when projects, expenses, tasks, or related data change in SQLite (Drift watches).

## Security notes

- New passwords are hashed with **bcrypt** (cost 12; salt embedded in the hash).
- Existing SHA-256 hashes are verified once, then upgraded to bcrypt on successful login.
- Plaintext password storage is **not** accepted.
- Biometric lock protects local access after backgrounding; it is not a remote account system. Camera / gallery and biometric prompts temporarily suppress re-lock so receipt capture is not interrupted.

## Documentation

- [docs/GOOGLE_OAUTH_SETUP.md](docs/GOOGLE_OAUTH_SETUP.md) — Google Drive backup / OAuth client setup for `com.projectrack.app`

## License / usage

Specify your license in this repository if you open-source or distribute the app. Until then, all rights reserved unless otherwise agreed with the maintainer.

---

*README maintained for production documentation. Contact: nelsonapidi75@gmail.com*
