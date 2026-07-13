# Google OAuth Setup

ProjectRack uses `google_sign_in` plus Google Drive `appDataFolder` backup for account sync.

**Android package / applicationId:** `com.projectrack.app`  
**iOS / macOS bundle ID:** `com.projectrack.app`

## Android

1. Open [Google Cloud Console](https://console.cloud.google.com).
2. Create or select the project used for ProjectRack.
3. Enable **Google Drive API**.
4. Configure the **OAuth consent screen**.
5. Create an **Android** OAuth 2.0 client.
6. Set package name to: `com.projectrack.app`
7. Add **SHA-1** and **SHA-256** fingerprints for your debug and release keystores:

   ```bash
   # Debug keystore (default Flutter/Android Studio debug key)
   keytool -list -v -alias androiddebugkey \
     -keystore ~/.android/debug.keystore \
     -storepass android -keypass android
   ```

8. Add tester accounts on the consent screen if the app is in testing mode.
9. If Google sign-in throws `ApiException: 10`, the package name or SHA fingerprints do not match the installed app build.

### After changing applicationId

If you previously registered `com.example.projectrack1`:

1. Edit (or recreate) the Android OAuth client.
2. Change the package name to `com.projectrack.app`.
3. Keep the same SHA-1/SHA-256 unless you rotated signing keys.
4. Save, wait a few minutes, uninstall the old app from the device, then install a fresh build.

## iOS

1. Create an **iOS** OAuth client in the same Google Cloud project.
2. Use bundle identifier: `com.projectrack.app`
3. Copy the **reversed client ID** into `ios/Runner/Info.plist` URL types before release.
4. Confirm the Google Drive API is enabled for the same project.
5. Add the `CFBundleURLTypes` entry with the reversed client ID before testing Google sign-in on iOS.

## What This App Expects

- Google Sign-In is used to identify the account.
- Drive backups are written to the private `appDataFolder`.
- Backup files are keyed by the Google account email so they can be restored on a new device.

## Release Checklist

- Confirm Android `applicationId` and iOS bundle ID are both `com.projectrack.app` in Google Cloud.
- Register both debug and release signing keys.
- Test sign-in on Android and iOS physical devices.
- Test backup, reinstall, sign-in, and restore end to end.
- Do not share Google Cloud secrets in chat. The only values you may need to paste into the app are non-secret client IDs or reversed client IDs for iOS configuration.
