# ProjectRack

A Flutter app for **construction and project work**: track projects, daily material costs, expenses, receipts, and reports—with local-first storage, optional cloud backup, and an interface tuned for real-world use.

## Maintainer

**Nelson Apidi** — [nelsonapidi75@gmail.com](mailto:nelsonapidi75@gmail.com)

For questions, contributions, or commercial use, reach out at the address above.

## Features

- **Projects** — Create and manage projects with budget, progress, status, tags, and imagery.
- **Expenses & materials** — Log spending with quantities, **units**, and smart unit suggestions; tie entries to projects.
- **Receipts** — Capture and attach receipts; gallery and detail views.
- **Dashboard** — At-a-glance projects, spend, tasks, and spending trends.
- **Reports & analytics** — Charts (e.g. category and project breakdowns, material trends), **friendly time-period filtering** (presets, rolling windows, custom ranges), export-friendly summaries.
- **Data** — **Drift** (SQLite) for structured data; migrations for schema updates.
- **Backup & export** — Local JSON backup/restore, Excel/CSV/PDF exports where implemented; optional **Google** sync/backup flows (see in-app settings).
- **Security** — Biometric app lock, secure storage for sensitive preferences.
- **Settings** — Currency, units and smart suggestions, notifications, theme, and account-related options.

## Documentation

- Google account backup / OAuth setup: [docs/GOOGLE_OAUTH_SETUP.md](docs/GOOGLE_OAUTH_SETUP.md)

## Requirements

- **Flutter** SDK (see `pubspec.yaml` for the Dart SDK constraint, currently `^3.10.8`).
- **Android Studio** / **Xcode** (or compatible tooling) for mobile targets.

## Getting started

From the repository root:

```bash
flutter pub get
```

If you change Drift schemas or run code generation:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Run the app:

```bash
flutter run
```

## Project layout (high level)

| Area | Role |
|------|------|
| `lib/` | App code: UI, providers, routing, services, Drift database |
| `lib/database/` | Drift schema, generated `*.g.dart` files |
| `android/`, `ios/`, `macos/` | Platform projects |

## License / usage

Specify your license in this repository if you open-source or distribute the app. Until then, all rights reserved unless otherwise agreed with the maintainer.

---

*README maintained for production documentation. Contact: nelsonapidi75@gmail.com*
