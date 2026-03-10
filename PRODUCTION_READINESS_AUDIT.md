# Production Readiness Audit

## Fixes Applied (this session)

### Breaking points fixed
1. **Splash screen** – Now checks `AuthProvider.isAuthenticated` after delay: authenticated users go to **home**, others to **onboarding**. Prevents logged-in users from being sent to onboarding on every launch.
2. **Settings sign-out** – Replaced `context.go('/login')` with `context.go(AppRoutes.login)`.
3. **Settings profile tap** – Replaced `context.push('/profile')` with `context.push(AppRoutes.profile)`.
4. **Receipt gallery** – Replaced string `'/receipt-ocr'` with `AppRoutes.receiptOcr` (2 places).
5. **Receipt detail** – "View project" no longer uses hardcoded `/project/downtown-loft`; uses `widget.projectId` when set, otherwise goes to home. Edit receipt now pushes `AppRoutes.receiptOcr`.

### Functionality wired
6. **Profile → Change password** – "Change Password" opens a dialog (current password, new password, confirm), validates, and calls `AuthProvider.changePassword()`.

---

## Routes: status and usage

| Route constant | Path | Wired? | Notes |
|----------------|------|--------|--------|
| splash | `/` | ✅ | Entry; goes to onboarding or home based on auth |
| onboarding, onboarding2, onboarding3 | `/onboarding`, etc. | ✅ | From splash; last goes to login |
| login | `/login` | ✅ | From onboarding, settings sign-out |
| register | `/register` | ✅ | From login |
| home | `/home` | ✅ | Main shell (dashboard, projects, expense, profile) |
| dashboard | `/dashboard` | ⚠️ | Defined but app uses **home** as shell; dashboard is first tab of home |
| projects | `/projects` | ✅ | Dashboard "See All", stats card, bottom bar |
| createProject | `/create-project` | ✅ | Bottom bar FAB, project overview |
| projectOverview | `/project/:id` | ✅ | Project card taps, logs "View project", notifications |
| dailyMaterialEntry | `/project/:id/material-entry` | ✅ | Create project success, project overview, logs |
| dailyLogsHistory | `/project/:id/logs-history` | ✅ | Daily entry after submit, project overview |
| categorizedExpenses | `/project/:id/expenses` | ✅ | Dashboard expense card, project overview |
| receiptOcr | `/receipt-ocr` | ✅ | FAB (camera/gallery), daily entry, receipt detail edit |
| receiptGallery | `/receipt-gallery` | ⚠️ | **No navigation to this route** in app (route exists) |
| receiptDetail | `/receipt/:id` | ⚠️ | **No navigation** with id (receipt gallery pushes receipt-ocr, not receipt/:id) |
| reportsAnalytics | `/reports` | ✅ | Expense screen analytics button |
| projectReports | `/project/:id/reports` | ✅ | Project overview |
| notifications | `/notifications` | ✅ | Dashboard bell |
| profile | `/profile` | ✅ | Dashboard avatar, settings |
| settings | `/settings` | ✅ | Profile "App Settings", settings back |

### Unused route constants (no GoRoute or no navigation)
- **projectDetails** (`/projects/:id`) – Not used; project detail uses `projectOverview` (`/project/:id`).
- **editProject** (`/projects/:id/edit`) – No edit screen in router; not used.
- **projectReceiptOcr** (`/project/:id/receipt-ocr`) – Not used; receipt OCR uses `/receipt-ocr` with extra.
- **projectReceiptGallery** – Not used.
- **projectReceiptDetail** – Not used.

---

## Functionality still missing (empty or placeholder)

### Profile screen
- **Email Preferences** – `onTap: () {}`
- **Help Center** – `onTap: () {}`
- **Terms of Service** – `onTap: () {}`
- **Privacy Policy** – `onTap: () {}`

### Settings screen
- **Security** (password / 2FA) – `onTap: () {}`
- **Email Preferences** – `onTap: () {}`
- **Privacy Policy** – `onTap: () {}`
- **Security Recommendations** – `onTap: () {}`
- **Backup & Restore** – `onTap: () {}`
- **Rate the App** – `onTap: () {}`
- **Share App** – `onTap: () {}`
- **Report a Bug** – `onTap: () {}`

### Project overview screen
- **Settings icon** (app bar) – comment only: "Navigate to project settings"
- **Tasks** quick action – comment: "Navigate to tasks when screen exists"
- **Team / Invite** – comment: "Navigate to team management"
- **Bottom sheet nav items** (e.g. Dashboard, Logs, Expenses, Settings) – several `onTap: () {}`

### Expense screen
- **Filter button** (app bar) – `onPressed: () {}`

### Receipts
- **Receipt detail view** – Still uses **mock** `_receiptData`; not loaded by receipt/expense id from DB.
- **Receipt gallery** – No navigation to this screen from anywhere; receipt list and FAB go to receipt-ocr.

### Other
- **Onboarding** – onboarding2/onboarding3 comments reference "Navigate to login or home"; flow is already to login.
- **Mock helpers** – `Project.getMockProjects()`, `Expense.getMockExpenses()` exist for tests; not used in production UI.

---

## Recommendations

1. **Receipt gallery** – Either add a way to open it (e.g. from expense or project overview "Receipts") or remove the route if not needed.
2. **Receipt detail by id** – If you want "view receipt" from a list, navigate with `context.push('${AppRoutes.receiptDetail.replaceFirst(':id', receiptId)}')` and load receipt/expense by id in the screen (replace mock data).
3. **Project overview** – Wire Tasks to a tasks screen or a placeholder; wire Settings to a project-settings screen or remove.
4. **Profile/Settings placeholders** – For "Help", "Terms", "Privacy", "Rate", "Share", "Report bug": either implement (e.g. in-app WebView or external links) or use a single "Coming soon" snackbar so taps don’t feel broken.
5. **Expense filter** – Implement filter (e.g. by date range, category, project) or remove the button.
