# Google OAuth Setup

ProjectRack uses `google_sign_in` plus Google Drive `appDataFolder` backup for account sync.

## Android

1. Open Google Cloud Console.
2. Create or select the project used for ProjectRack.
3. Enable Google Drive API.
4. Configure the OAuth consent screen.
5. Create an Android OAuth client.
6. Use package name: `com.example.projectrack1` unless you have changed it.
7. Add SHA-1 and SHA-256 fingerprints for your debug and release keystores.
8. Add your tester accounts on the consent screen if the app is in testing mode.
9. If Google sign-in throws `ApiException: 10`, the package name or SHA fingerprints do not match the installed app build.

## iOS

1. Create an iOS OAuth client in the same Google Cloud project.
2. Use the app bundle identifier from Xcode.
3. Copy the reversed client ID into `Info.plist` URL types before release.
4. Confirm the Google Drive API is enabled for the same project.
5. Add the `CFBundleURLTypes` entry with the reversed client ID before testing Google sign-in on iOS.

## What This App Expects

- Google Sign-In is used to identify the account.
- Drive backups are written to the private `appDataFolder`.
- Backup files are keyed by the Google account email so they can be restored on a new device.

## Release Checklist

- Replace `com.example.projectrack1` with your real production package if needed.
- Register both debug and release signing keys.
- Test sign-in on Android and iOS physical devices.
- Test backup, reinstall, sign-in, and restore end to end.
- Do not share Google Cloud secrets in chat. The only values you may need to paste into the app are non-secret client IDs or reversed client IDs for iOS configuration.
