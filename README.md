# ProjectRack

A Flutter app for **construction and field project work**: track projects, material costs, inventory, tasks, expenses, receipts, and reports—with local-first SQLite storage, optional Google Drive backup, and an interface tuned for real-world use.

## Maintainer

**Nelson Apidi** — [nelsonapidi75@gmail.com](mailto:nelsonapidi75@gmail.com)

For questions, contributions, or commercial use, reach out at the address above.

## Features

- **Projects** — Create and manage projects with budget, progress, status, tags, and imagery.
- **Tasks** — Per-project task lists with status (`pending` / `in_progress` / `done` / `blocked`), priority, due dates, assignees, filters, and overdue highlighting.
- **Expenses & materials** — Log spending with quantities, **units**, and smart unit suggestions; tie entries to projects.
- **Inventory** — Track on-hand materials per project, log usage, low-stock alerts; purchases from daily material entries add stock automatically.
- **Receipts** — Capture and attach receipts with on-device OCR (ML Kit); gallery and detail views.
- **Dashboard** — Reactive at-a-glance stats (projects, spend, open tasks, spending trends) driven by Drift table watches—no polling timer.
- **Reports & analytics** — Charts (category and project breakdowns, material trends), friendly time-period filtering (presets, rolling windows, custom ranges), export-friendly summaries.
- **Data** — **Drift** (SQLite) with schema migrations (current schema version **4**).
- **Backup & export** — Local JSON backup/restore; Excel / CSV / PDF exports; optional **Google Drive** app-data sync (see Settings).
- **Security** — Local accounts with **bcrypt** password hashing (legacy SHA-256 upgraded on login), biometric app lock, secure storage for session data.
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
| Cloud backup | google_sign_in + Google Drive `appDataFolder` |

Dart package name in code remains `projectrack1` (imports / `pubspec.yaml`); store and OAuth identity use `com.projectrack.app`.

## Requirements

- Flutter SDK matching `pubspec.yaml` (`sdk: ^3.10.8`)
- Android Studio / Xcode (or compatible tooling) for mobile targets

## Getting started

```bash
flutter pub get
flutter run
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
| `lib/main.dart` | App bootstrap, providers, lifecycle biometric lock |
| `lib/database/` | Drift schema, migrations, generated `database.g.dart` |
| `lib/providers/` | Auth, Drift DB, theme, currency, dashboard snapshot types |
| `lib/service/` | Auth (bcrypt), inventory, backup, Google sync, export, units, biometrics |
| `lib/routes/` | go_router routes and auth redirects |
| `lib/ui/projects/` | Projects, overview, daily material entry, logs |
| `lib/ui/tasks/` | Task list, form, detail |
| `lib/ui/inventory/` | Material inventory and usage |
| `lib/ui/receipts/` | OCR upload, gallery, detail |
| `lib/ui/screens/` | Dashboard, expenses, reports, settings, profile |
| `lib/ui/auth/` | Login, register, biometric unlock |
| `lib/constants/models/` | Domain models (project, expense, task, inventory, …) |
| `lib/themes/` | Light/dark theme and brand colors |
| `test/` | Unit tests (auth, tasks, inventory, dashboard, colors) |
| `docs/` | Google OAuth setup |

## Core flows

### Material purchase → inventory

1. Open a project → **Add Entry** (daily material entry).
2. Save materials with quantity and unit.
3. Each successful expense also **adds stock** (matched by material name).
4. Open **Inventory** to set reorder levels, log usage, or view history.

### Tasks

1. Project overview → **Tasks** (or project options → Manage Tasks).
2. Create tasks, filter by status/overdue, update status from the list or detail screen.

### Dashboard

Stats and spending trends refresh when projects, expenses, or tasks change in SQLite (Drift watches), including after inventory-related expense updates that affect totals.

## Security notes

- New passwords are hashed with **bcrypt** (cost 12; salt embedded in the hash).
- Existing SHA-256 hashes are verified once, then upgraded to bcrypt on successful login.
- Plaintext password storage is **not** accepted.
- Biometric lock protects local access after backgrounding; it is not a remote account system.

## Documentation

- [docs/GOOGLE_OAUTH_SETUP.md](docs/GOOGLE_OAUTH_SETUP.md) — Google Drive backup / OAuth client setup for `com.projectrack.app`

## License / usage

Specify your license in this repository if you open-source or distribute the app. Until then, all rights reserved unless otherwise agreed with the maintainer.

---

*README maintained for production documentation. Contact: nelsonapidi75@gmail.com*
