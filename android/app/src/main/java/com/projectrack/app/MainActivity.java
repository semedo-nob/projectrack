package com.projectrack.app;

import io.flutter.embedding.android.FlutterFragmentActivity;

/**
 * Must extend FlutterFragmentActivity (not FlutterActivity) so local_auth / BiometricPrompt
 * can attach to a FragmentActivity. Required for fingerprint / face unlock.
 */
public class MainActivity extends FlutterFragmentActivity {
}
