package com.tanguyhardion.file_vault

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FragmentActivity is required by local_auth (screen lock prompt).
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Decrypted content must not leak into screenshots or the recents thumbnail.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "file_vault/app_icon")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setAccent" -> {
                        AppIconSwitcher.request(this, call.arguments as String)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onStop() {
        super.onStop()
        // Swap the launcher icon while the app is in the background.
        AppIconSwitcher.applyPending(applicationContext)
    }
}
